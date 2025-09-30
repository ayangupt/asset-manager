package com.microsoft.migration.assets.service;

import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.models.BlobHttpHeaders;
import com.azure.storage.blob.options.BlobParallelUploadOptions;
import com.microsoft.migration.assets.model.ImageMetadata;
import com.microsoft.migration.assets.model.ImageProcessingMessage;
import com.microsoft.migration.assets.model.S3StorageItem;
import com.microsoft.migration.assets.repository.ImageMetadataRepository;
import com.azure.spring.messaging.servicebus.core.ServiceBusTemplate;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import static com.microsoft.migration.assets.config.RabbitConfig.IMAGE_PROCESSING_QUEUE;

@Service
@ConditionalOnProperty(name = "storage.type", havingValue = "azure")
public class AwsS3Service implements StorageService {

    private final BlobServiceClient blobServiceClient;
    private final ServiceBusTemplate serviceBusTemplate;
    private final ImageMetadataRepository imageMetadataRepository;

    public AwsS3Service(BlobServiceClient blobServiceClient, 
                       ImageMetadataRepository imageMetadataRepository,
                       @Autowired(required = false) ServiceBusTemplate serviceBusTemplate) {
        this.blobServiceClient = blobServiceClient;
        this.imageMetadataRepository = imageMetadataRepository;
        this.serviceBusTemplate = serviceBusTemplate;
    }

    @Value("${azure.storage.blob.container-name}")
    private String containerName;

    @Override
    public List<S3StorageItem> listObjects() {
        return blobServiceClient.getBlobContainerClient(containerName).listBlobs().stream()
                .map(blobItem -> {
                    // Try to get metadata for upload time
                    Instant uploadedAt = imageMetadataRepository.findAll().stream()
                            .filter(metadata -> metadata.getS3Key().equals(blobItem.getName()))
                            .map(metadata -> metadata.getUploadedAt().atZone(java.time.ZoneId.systemDefault()).toInstant())
                            .findFirst()
                            .orElse(blobItem.getProperties().getLastModified().toInstant()); // fallback to lastModified if metadata not found

                    return new S3StorageItem(
                            blobItem.getName(),
                            extractFilename(blobItem.getName()),
                            blobItem.getProperties().getContentLength(),
                            blobItem.getProperties().getLastModified().toInstant(),
                            uploadedAt,
                            generateUrl(blobItem.getName())
                    );
                })
                .collect(Collectors.toList());
    }

    @Override
    public void uploadObject(MultipartFile file) throws IOException {
        String key = generateKey(file.getOriginalFilename());

        var blobClient = blobServiceClient.getBlobContainerClient(containerName).getBlobClient(key);
        BlobHttpHeaders headers = new BlobHttpHeaders().setContentType(file.getContentType());
        BlobParallelUploadOptions options = new BlobParallelUploadOptions(file.getInputStream()).setHeaders(headers);
        blobClient.uploadWithResponse(options, null, null);

        // Send message to queue for thumbnail generation (if Service Bus is available)
        if (serviceBusTemplate != null) {
            ImageProcessingMessage message = new ImageProcessingMessage(
                key,
                file.getContentType(),
                getStorageType(),
                file.getSize()
            );
            serviceBusTemplate.send(IMAGE_PROCESSING_QUEUE, MessageBuilder.withPayload(message).build());
        }

        // Create and save metadata to database
        ImageMetadata metadata = new ImageMetadata();
        metadata.setId(UUID.randomUUID().toString());
        metadata.setFilename(file.getOriginalFilename());
        metadata.setContentType(file.getContentType());
        metadata.setSize(file.getSize());
        metadata.setS3Key(key);
        metadata.setS3Url(generateUrl(key));

        imageMetadataRepository.save(metadata);
    }

    @Override
    public InputStream getObject(String key) throws IOException {
        return blobServiceClient.getBlobContainerClient(containerName)
                .getBlobClient(key)
                .openInputStream();
    }

    @Override
    public void deleteObject(String key) throws IOException {
        // Delete both original and thumbnail if it exists
        blobServiceClient.getBlobContainerClient(containerName)
                .getBlobClient(key)
                .delete();

        try {
            // Try to delete thumbnail if it exists
            blobServiceClient.getBlobContainerClient(containerName)
                    .getBlobClient(getThumbnailKey(key))
                    .delete();
        } catch (Exception e) {
            // Ignore if thumbnail doesn't exist
        }

        // Delete metadata from database
        imageMetadataRepository.findAll().stream()
                .filter(metadata -> metadata.getS3Key().equals(key))
                .findFirst()
                .ifPresent(metadata -> imageMetadataRepository.delete(metadata));
    }

    @Override
    public String getStorageType() {
        return "azure";
    }

    private String extractFilename(String key) {
        // Extract filename from the object key
        int lastSlashIndex = key.lastIndexOf('/');
        return lastSlashIndex >= 0 ? key.substring(lastSlashIndex + 1) : key;
    }

    private String generateUrl(String key) {
        // Generate URL that serves through our application instead of direct blob access
        return "/s3/view/" + key;
    }

    private String generateKey(String filename) {
        return UUID.randomUUID().toString() + "-" + filename;
    }
}