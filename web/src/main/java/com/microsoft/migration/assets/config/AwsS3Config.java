package com.microsoft.migration.assets.config;

import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.BlobServiceClientBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(name = "storage.type", havingValue = "azure")
public class AwsS3Config {

    @Value("${azure.storage.account-name:#{null}}")
    private String accountName;

    @Bean
    @ConditionalOnProperty(name = "azure.storage.account-name")
    public BlobServiceClient blobServiceClient() {
        return new BlobServiceClientBuilder()
                .endpoint("https://" + accountName + ".blob.core.windows.net")
                .credential(new DefaultAzureCredentialBuilder().build())
                .buildClient();
    }
}