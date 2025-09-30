# Assets Manager - Working Azure Migration

This is a fully functional Java Spring Boot application that demonstrates successful migration from AWS to Azure. The application allows users to upload and manage assets with Azure Blob Storage integration and PostgreSQL database backend.

🚀 **Live Demo**: https://azappxxm5ylfv2vwj6web.azurewebsites.net/

## Features

- **File Upload & Management**: Upload and manage assets/files through web interface
- **Azure Blob Storage Integration**: Seamless cloud storage with Azure Blob Storage
- **Database Integration**: PostgreSQL Flexible Server for metadata storage
- **Worker Service**: Background processing service for file operations
- **Local Development**: H2 in-memory database for rapid local testing
- **Conditional Configurations**: Environment-specific configurations for local/production

## Architecture

- **Web Application**: Spring Boot 3.4.3 with Thymeleaf templates
- **Worker Service**: Background processing service
- **Database**: PostgreSQL Flexible Server (production) / H2 (local)
- **Storage**: Azure Blob Storage (production) / Mock storage (local)
- **Infrastructure**: Azure Bicep templates with Azure Developer CLI (azd)

## Prerequisites

- Java 21
- Maven 3.6+
- Azure CLI (`az`)
- Azure Developer CLI (`azd`)

## Local Development

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ayangupt/asset-manager.git
   cd asset-manager
   ```

2. **Create local configuration** (create `web/src/main/resources/application-local.properties`):
   ```properties
   # H2 Database Configuration
   spring.datasource.url=jdbc:h2:mem:testdb
   spring.datasource.driverClassName=org.h2.Driver
   spring.datasource.username=sa
   spring.datasource.password=password
   spring.h2.console.enabled=true
   spring.h2.console.path=/h2-console
   spring.jpa.database-platform=org.hibernate.dialect.H2Dialect
   spring.jpa.hibernate.ddl-auto=create-drop
   spring.jpa.show-sql=true
   
   # Mock Storage Configuration
   storage.type=mock
   
   # Disable Azure services for local development
   management.health.servicebus.enabled=false
   logging.level.com.microsoft.migration.assets=DEBUG
   ```

3. **Run locally with H2 database**:
   ```bash
   cd web
   ../mvnw spring-boot:run -Dspring-boot.run.profiles=local
   ```

4. **Access the application**:
   - Web UI: http://localhost:8080
   - H2 Console: http://localhost:8080/h2-console
   - Database URL: `jdbc:h2:mem:testdb`

## Azure Deployment

1. **Authenticate with Azure**:
   ```bash
   azd auth login
   ```

2. **Deploy to Azure**:
   ```bash
   azd up
   ```

3. **Access deployed application**:
   - Web: https://[your-app-name].azurewebsites.net/
   - Worker: https://[your-worker-name].azurewebsites.net/

## Key Implementation Details

### Conditional Configurations
- **Production**: Uses Azure Blob Storage, PostgreSQL, optional Service Bus
- **Local**: Uses H2 database, mock storage services for rapid development

### Service Bus Integration
- Optional integration that can be enabled/disabled via configuration
- Graceful handling when Service Bus is not available
- Configurable via `management.health.servicebus.enabled` property

### Database Authentication
- Production: Password-based authentication with PostgreSQL Flexible Server
- Local: H2 in-memory database with auto-generated schema

## Configuration Files

- `application.properties`: Production configuration for Azure deployment
- `application-local.properties`: Local development configuration (create manually)
- `azure.yaml`: Azure Developer CLI configuration
- `infra/main.bicep`: Azure infrastructure as code

## Troubleshooting

### Local Development
- Ensure Java 21 is installed and JAVA_HOME is set
- Create `application-local.properties` file as shown above
- Use the `local` profile: `-Dspring-boot.run.profiles=local`

### Azure Deployment
- Check Azure resource group in portal: https://portal.azure.com
- View application logs: `azd logs`
- Monitor deployment: `azd monitor`

## Project Structure

```
├── web/                          # Web application module
│   ├── src/main/java/           # Java source code
│   └── src/main/resources/      # Configuration and templates
├── worker/                      # Worker service module
│   └── src/main/java/          # Worker service code
├── infra/                      # Azure infrastructure (Bicep)
│   ├── main.bicep             # Main infrastructure template
│   └── main.parameters.json   # Infrastructure parameters
├── azure.yaml                 # Azure Developer CLI configuration
└── pom.xml                    # Maven parent configuration
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test locally using H2 database
4. Deploy to Azure for integration testing
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Migration Notes

This application successfully addresses common Azure migration challenges:

- **Bean Configuration Conflicts**: Resolved with `@ConditionalOnProperty` annotations
- **Database Authentication**: Uses password-based PostgreSQL authentication
- **Optional Service Dependencies**: Graceful handling of missing Azure services
- **Local Development**: Complete H2-based local environment for rapid iteration

The migration maintains full functionality while providing robust local development capabilities.