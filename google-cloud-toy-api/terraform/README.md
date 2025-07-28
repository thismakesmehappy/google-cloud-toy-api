# Google Cloud Toy API - Terraform Infrastructure

This directory contains the infrastructure-as-code for the Google Cloud Toy API project, restructured with reusable modules for multi-environment deployment.

## Structure

```
terraform/
├── modules/                    # Reusable infrastructure modules
│   ├── api-gateway/           # API Gateway configuration
│   ├── cloud-function/        # Cloud Functions v2 setup
│   └── firestore/             # Firestore database
├── environments/              # Environment-specific configurations
│   ├── dev/                   # Development environment
│   ├── staging/               # Staging environment
│   └── prod/                  # Production environment
├── shared/                    # Shared resources (APIs, IAM)
└── README.md                  # This file
```

## Modules

### cloud-function
- Creates Cloud Function v2 with configurable settings
- Manages source code packaging and deployment
- Configures IAM permissions for API Gateway and public access
- Supports environment-specific configurations

### api-gateway
- Creates API Gateway with OpenAPI specification
- Supports templated OpenAPI specs for multi-environment deployment
- Manages API configuration and gateway instances

### firestore
- Creates Firestore database with configurable settings
- Supports delete protection configuration per environment

### shared
- Enables necessary Google Cloud APIs
- Sets up IAM permissions for cross-service communication
- Provides project metadata for other modules

## Environments

### Development (`dev`)
- Public access enabled for testing
- Less restrictive ingress settings
- Delete protection disabled
- 256Mi memory allocation

### Staging (`staging`)
- Internal-only access
- More restrictive security settings
- Delete protection enabled
- Standard memory allocation

### Production (`prod`)
- Most restrictive security settings
- Internal-only access
- Delete protection enabled
- 512Mi memory allocation for better performance

## Usage

### Deploy to Development
```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### Deploy to Staging
```bash
cd environments/staging
terraform init
terraform plan -var="project_id=toy-api-stage"
terraform apply -var="project_id=toy-api-stage"
```

### Deploy to Production
```bash
cd environments/prod
terraform init
terraform plan -var="project_id=toy-api-prod"
terraform apply -var="project_id=toy-api-prod"
```

## Environment Variables

Each environment supports the following variables:

- `project_id`: Google Cloud project ID
- `region`: Deployment region (default: us-central1)
- `environment`: Environment name (dev/staging/prod)

## Outputs

Each environment provides:

- `function_url`: Direct Cloud Function URL
- `api_gateway_url`: API Gateway URL
- `function_name`: Name of the deployed function

## Migration from Legacy Structure

The legacy monolithic structure in `terraform/dev/` has been replaced with this modular approach. The new structure provides:

1. **Reusability**: Modules can be shared across environments
2. **Consistency**: Same infrastructure patterns across all environments
3. **Maintainability**: Changes can be made once in modules and applied everywhere
4. **Environment-specific Configuration**: Each environment has its own security and performance settings

## Next Steps

1. Set up CI/CD pipeline to automate deployments
2. Create staging and production GCP projects
3. Configure remote state management
4. Add monitoring and alerting configuration