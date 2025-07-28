# CI/CD Pipeline Setup Guide

This guide explains how to set up the GitHub Actions CI/CD pipeline for the Google Cloud Toy API project.

## Prerequisites

1. Three Google Cloud projects: `toy-api-dev`, `toy-api-stage`, `toy-api-prod`
2. GitHub repository for the code
3. Service accounts with appropriate permissions for each environment

## Step 1: Create Service Accounts

For each environment, create a service account with the following roles:

```bash
# Create service accounts
gcloud iam service-accounts create github-actions-dev \
  --display-name="GitHub Actions Dev" \
  --project=toy-api-dev

gcloud iam service-accounts create github-actions-staging \
  --display-name="GitHub Actions Staging" \
  --project=toy-api-stage

gcloud iam service-accounts create github-actions-prod \
  --display-name="GitHub Actions Prod" \
  --project=toy-api-prod
```

## Step 2: Grant Required Permissions

For each service account, grant the necessary roles:

```bash
# Dev environment
gcloud projects add-iam-policy-binding toy-api-dev \
  --member="serviceAccount:github-actions-dev@toy-api-dev.iam.gserviceaccount.com" \
  --role="roles/cloudfunctions.admin"

gcloud projects add-iam-policy-binding toy-api-dev \
  --member="serviceAccount:github-actions-dev@toy-api-dev.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding toy-api-dev \
  --member="serviceAccount:github-actions-dev@toy-api-dev.iam.gserviceaccount.com" \
  --role="roles/apigateway.admin"

gcloud projects add-iam-policy-binding toy-api-dev \
  --member="serviceAccount:github-actions-dev@toy-api-dev.iam.gserviceaccount.com" \
  --role="roles/datastore.owner"

gcloud projects add-iam-policy-binding toy-api-dev \
  --member="serviceAccount:github-actions-dev@toy-api-dev.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageAdmin"

gcloud projects add-iam-policy-binding toy-api-dev \
  --member="serviceAccount:github-actions-dev@toy-api-dev.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountAdmin"

# Repeat for staging and prod with their respective project IDs
```

## Step 3: Generate Service Account Keys

```bash
# Generate keys for each environment
gcloud iam service-accounts keys create github-actions-dev-key.json \
  --iam-account=github-actions-dev@toy-api-dev.iam.gserviceaccount.com

gcloud iam service-accounts keys create github-actions-staging-key.json \
  --iam-account=github-actions-staging@toy-api-stage.iam.gserviceaccount.com

gcloud iam service-accounts keys create github-actions-prod-key.json \
  --iam-account=github-actions-prod@toy-api-prod.iam.gserviceaccount.com
```

## Step 4: Configure GitHub Secrets

In your GitHub repository, go to Settings > Secrets and variables > Actions and add:

### Repository Secrets
- `GCP_SA_KEY_DEV`: Contents of `github-actions-dev-key.json`
- `GCP_SA_KEY_STAGING`: Contents of `github-actions-staging-key.json`
- `GCP_SA_KEY_PROD`: Contents of `github-actions-prod-key.json`
- `GCP_PROJECT_ID_DEV`: `toy-api-dev`
- `GCP_PROJECT_ID_STAGING`: `toy-api-stage`
- `GCP_PROJECT_ID_PROD`: `toy-api-prod`
- `DEV_API_KEY`: `dev-api-key-123` (or your chosen dev API key)
- `STAGING_API_KEY`: `staging-api-key-456` (or your chosen staging API key)

### Environment Secrets

Create GitHub Environments for additional protection:

1. Go to Settings > Environments
2. Create environments: `development`, `staging`, `production`
3. For `production`, add protection rules:
   - Required reviewers
   - Wait timer (optional)
   - Deployment branches (main only)

## Step 5: Pipeline Features

The CI/CD pipeline includes:

### On Pull Request:
- ✅ Code linting and type checking
- ✅ Unit tests
- ✅ Terraform validation for all environments
- ✅ Build verification

### On Push to Main:
1. **Development Deployment**
   - Deploy to dev environment
   - Run integration tests
   - Validate API functionality

2. **Staging Deployment** (after dev success)
   - Deploy to staging environment
   - Run integration tests through API Gateway
   - Validate end-to-end functionality

3. **Production Deployment** (after staging success)
   - Deploy to production environment
   - Run smoke tests
   - Notify deployment success

## Step 6: Testing the Pipeline

1. Create a feature branch
2. Make a change to the code
3. Open a pull request - this will trigger tests and validation
4. Merge to main - this will trigger the full deployment pipeline

## Pipeline Workflow

```
Pull Request → [Tests + Terraform Validation]
     ↓
Merge to Main → [Deploy Dev] → [Test Dev] → [Deploy Staging] → [Test Staging] → [Deploy Prod] → [Smoke Test Prod]
```

## Monitoring and Troubleshooting

### Check Pipeline Status
- GitHub Actions tab shows all workflow runs
- Each step has detailed logs
- Failed steps will block progression

### Common Issues
1. **Authentication errors**: Check service account keys and permissions
2. **Terraform conflicts**: May need to import existing resources
3. **API timeouts**: Increase wait times in integration tests

### Rollback Strategy
- Each environment can be rolled back independently
- Terraform state allows reverting to previous versions
- Feature flags can disable problematic features

## Security Best Practices

1. **Least Privilege**: Service accounts have minimal required permissions
2. **Environment Protection**: Production requires manual approval
3. **Secret Management**: All sensitive data stored in GitHub Secrets
4. **Audit Trail**: All deployments logged and trackable

## Next Steps

1. Test the pipeline with a simple change
2. Add more comprehensive integration tests
3. Implement automated rollback triggers
4. Add Slack/email notifications for deployment status
5. Set up monitoring and alerting for deployed services