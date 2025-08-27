@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@minLength(1)
@description('Primary location for all resources.')
param location string

@secure()
@description('Password for PostgreSQL administrator.')
param postgresAdminPassword string

// Generate unique token for resource naming
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location, environmentName)

// User-Assigned Managed Identity (MANDATORY)
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'azid${resourceToken}'
  location: location
}

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'azlog${resourceToken}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'azai${resourceToken}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'azcr${resourceToken}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Key Vault for storing secrets
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'azkv${resourceToken}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: userAssignedIdentity.properties.principalId
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
    enableRbacAuthorization: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// Store secrets in Key Vault
resource storageAccountNameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'azure-storage-account-name'
  parent: keyVault
  properties: {
    value: storageAccount.name
  }
}

resource storageContainerNameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'azure-storage-blob-container-name'
  parent: keyVault
  properties: {
    value: 'assets'
  }
}

resource serviceBusNamespaceSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'azure-servicebus-namespace'
  parent: keyVault
  properties: {
    value: '${serviceBusNamespace.name}.servicebus.windows.net'
  }
}

resource clientIdSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'azure-client-id'
  parent: keyVault
  properties: {
    value: userAssignedIdentity.properties.clientId
  }
}

// AcrPull role assignment (MANDATORY - before container apps)
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, userAssignedIdentity.id, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'azst${resourceToken}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

// Storage Blob Container
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/assets'
  properties: {
    publicAccess: 'None'
  }
}

// Service Bus Namespace
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: 'azsb${resourceToken}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

// Service Bus Queue
resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  name: 'image-processing'
  parent: serviceBusNamespace
  properties: {
    maxDeliveryCount: 3
    defaultMessageTimeToLive: 'P1D'
  }
}

// PostgreSQL Flexible Server
resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: 'azpg${resourceToken}'
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: 'azureuser'
    administratorLoginPassword: postgresAdminPassword
    version: '15'
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// PostgreSQL Database
resource postgresqlDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  name: 'assetsdb'
  parent: postgresqlServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Container App Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'azcae${resourceToken}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Web Container App
resource webContainerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'assets-manager-web'
  location: location
  dependsOn: [acrPullRoleAssignment]
  tags: {
    'azd-service-name': 'assets-manager-web'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
        }
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: userAssignedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'azure-storage-account-name'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/azure-storage-account-name'
          identity: userAssignedIdentity.id
        }
        {
          name: 'azure-storage-blob-container-name'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/azure-storage-blob-container-name'
          identity: userAssignedIdentity.id
        }
        {
          name: 'azure-servicebus-namespace'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/azure-servicebus-namespace'
          identity: userAssignedIdentity.id
        }
        {
          name: 'azure-client-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/azure-client-id'
          identity: userAssignedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'assets-manager-web'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          env: [
            {
              name: 'AZURE_STORAGE_ACCOUNT_NAME'
              secretRef: 'azure-storage-account-name'
            }
            {
              name: 'AZURE_STORAGE_BLOB_CONTAINER_NAME'
              secretRef: 'azure-storage-blob-container-name'
            }
            {
              name: 'AZURE_SERVICEBUS_NAMESPACE'
              secretRef: 'azure-servicebus-namespace'
            }
            {
              name: 'AZURE_CLIENT_ID'
              secretRef: 'azure-client-id'
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// Worker Container App
resource workerContainerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'assets-manager-worker'
  location: location
  dependsOn: [acrPullRoleAssignment]
  tags: {
    'azd-service-name': 'assets-manager-worker'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: userAssignedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'azure-storage-account-name'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/azure-storage-account-name'
          identity: userAssignedIdentity.id
        }
        {
          name: 'azure-storage-blob-container-name'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/azure-storage-blob-container-name'
          identity: userAssignedIdentity.id
        }
        {
          name: 'azure-servicebus-namespace'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/azure-servicebus-namespace'
          identity: userAssignedIdentity.id
        }
        {
          name: 'azure-client-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/azure-client-id'
          identity: userAssignedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'assets-manager-worker'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          env: [
            {
              name: 'AZURE_STORAGE_ACCOUNT_NAME'
              secretRef: 'azure-storage-account-name'
            }
            {
              name: 'AZURE_STORAGE_BLOB_CONTAINER_NAME'
              secretRef: 'azure-storage-blob-container-name'
            }
            {
              name: 'AZURE_SERVICEBUS_NAMESPACE'
              secretRef: 'azure-servicebus-namespace'
            }
            {
              name: 'AZURE_CLIENT_ID'
              secretRef: 'azure-client-id'
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// Storage role assignments for managed identity
resource storageDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, userAssignedIdentity.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Service Bus role assignments for managed identity
resource serviceBusDataOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBusNamespace.id, userAssignedIdentity.id, '090c5cfd-751d-490a-894a-3ce6f1109419')
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '090c5cfd-751d-490a-894a-3ce6f1109419')
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output RESOURCE_GROUP_ID string = resourceGroup().id
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = 'https://${containerRegistry.properties.loginServer}'
output WEB_APP_URL string = 'https://${webContainerApp.properties.configuration.ingress.fqdn}'
output AZURE_STORAGE_ACCOUNT_NAME string = storageAccount.name
output AZURE_SERVICEBUS_NAMESPACE string = serviceBusNamespace.name
output AZURE_CLIENT_ID string = userAssignedIdentity.properties.clientId
