package com.microsoft.migration.assets.service;

import com.microsoft.migration.assets.model.S3StorageItem;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Mock storage service for testing basic functionality without Azure dependencies
 */
@Service
@ConditionalOnProperty(name = "storage.type", havingValue = "mock")
public class MockStorageService implements StorageService {

    @Override
    public List<S3StorageItem> listObjects() {
        // Return empty list for now - basic functionality test
        return new ArrayList<>();
    }

    @Override
    public void uploadObject(MultipartFile file) throws IOException {
        // Mock upload - just log the file name
        System.out.println("Mock upload: " + file.getOriginalFilename());
    }

    @Override
    public InputStream getObject(String key) throws IOException {
        // Return empty stream for mock
        return new ByteArrayInputStream(new byte[0]);
    }

    @Override
    public void deleteObject(String key) throws IOException {
        // Mock delete
        System.out.println("Mock delete: " + key);
    }

    @Override
    public String getStorageType() {
        return "mock";
    }
}