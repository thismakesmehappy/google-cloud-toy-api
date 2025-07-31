# Google Cloud Build CI/CD Setup Guide

This guide walks you through setting up automated CI/CD with Google Cloud Build for the Toy API project.

## 🎯 Overview

The Cloud Build pipeline provides:
- ✅ **Automated testing** on every push to main
- ✅ **Docker image building** and registry storage  
- ✅ **Automated deployment** to Cloud Run
- ✅ **Integration testing** against live service
- ✅ **Automatic rollback** on failure

## 🚀 Quick Setup

### 1. Prerequisites

```bash
# Ensure gcloud CLI is installed and authenticated
gcloud auth login
gcloud config set project toy-api-dev
```

### 2. Run Automated Setup

```bash
# Make script executable and run
chmod +x ./setup-cloud-build.sh
./setup-cloud-build.sh
```

### 3. Connect GitHub Repository

1. Go to [Cloud Build Console](https://console.cloud.google.com/cloud-build/triggers)
2. Click "Connect Repository" 
3. Select GitHub and authorize access
4. Choose your repository: `your-username/TestGoogleAPI`

### 4. Create Build Triggers

Update the GitHub owner in `setup-cloud-build.sh`:
```bash
GITHUB_OWNER="your-actual-github-username"
```

Then create triggers for each environment:
```bash
# Dev environment (auto-deploy on main branch)
gcloud builds triggers create github \
  --repo-name=TestGoogleAPI \
  --repo-owner=your-username \
  --branch-pattern=main \
  --build-config=google-cloud-toy-api/cloudbuild.yaml \
  --name=deploy-dev \
  --project=toy-api-dev
```

## 📋 Build Pipeline Steps

The `cloudbuild.yaml` defines these steps:

1. **Install Dependencies** - `npm ci`
2. **Run Unit Tests** - `npm test` (33 tests)
3. **Build TypeScript** - `npm run build` 
4. **Build Docker Image** - Container with SHA tag
5. **Push to Registry** - Store in Container Registry
6. **Deploy to Cloud Run** - Update dev service
7. **Integration Tests** - Test live endpoints
8. **Rollback on Failure** - Automatic revert

## 🔧 Configuration Files

### `cloudbuild.yaml`
```yaml
steps:
  - name: 'gcr.io/cloud-builders/npm'
    args: ['ci']
    dir: 'google-cloud-toy-api'
  
  - name: 'gcr.io/cloud-builders/npm' 
    args: ['test']
    dir: 'google-cloud-toy-api'
    
  # ... additional steps
```

### Environment Variables
- `_API_KEY_DEV` - API key for dev environment
- `PROJECT_ID` - Automatically provided by Cloud Build
- `SHORT_SHA` - Git commit SHA for image tagging

## 🏗️ Manual Build Trigger

Test the pipeline manually:

```bash
# Trigger build manually
gcloud builds submit --config=google-cloud-toy-api/cloudbuild.yaml

# Monitor build progress
gcloud builds log $(gcloud builds list --limit=1 --format="value(id)")
```

## 📊 Monitoring and Logs

### Build Console
- **Builds**: https://console.cloud.google.com/cloud-build/builds
- **Triggers**: https://console.cloud.google.com/cloud-build/triggers
- **History**: View all build attempts and results

### Cloud Run Console  
- **Services**: https://console.cloud.google.com/run
- **Logs**: View application logs and deployment status
- **Revisions**: Track deployments and rollbacks

## 🔄 Deployment Flow

### Successful Deployment
```
Push to main → Build trigger → Tests pass → Deploy → Integration tests → ✅ Success
```

### Failed Deployment  
```
Push to main → Build trigger → Tests fail → ❌ Build stops
Push to main → Build trigger → Tests pass → Deploy → Integration fail → 🔄 Rollback
```

## 🚦 Build Status

Monitor build status:
- **Green**: All tests passed, deployment successful
- **Red**: Tests failed or deployment issues
- **Yellow**: Build in progress

## 🎛️ Advanced Configuration

### Multi-Environment Setup

For staging and production:

```bash
# Create additional triggers
gcloud builds triggers create github \
  --repo-name=TestGoogleAPI \
  --repo-owner=your-username \
  --branch-pattern=release \
  --build-config=google-cloud-toy-api/cloudbuild-staging.yaml \
  --name=deploy-staging \
  --project=toy-api-staging
```

### Custom Build Steps

Add additional steps to `cloudbuild.yaml`:

```yaml
# Add security scanning
- name: 'gcr.io/cloud-builders/gcloud'
  args: ['beta', 'container', 'images', 'scan', 'gcr.io/$PROJECT_ID/toy-api:$SHORT_SHA']

# Add performance testing  
- name: 'gcr.io/cloud-builders/npm'
  args: ['run', 'test:performance']
  dir: 'google-cloud-toy-api'
```

## 🔍 Troubleshooting

### Common Issues

**Build fails on npm install:**
```bash
# Clear npm cache in cloudbuild.yaml
- name: 'gcr.io/cloud-builders/npm'
  args: ['cache', 'clean', '--force']
```

**Permission denied errors:**
```bash
# Verify Cloud Build service account has roles:
# - Cloud Run Admin
# - Service Account User  
# - Storage Admin
```

**Integration tests fail:**
```bash
# Check service URL and API key configuration
SERVICE_URL=$(gcloud run services describe toy-api-service-dev --region=us-central1 --format='value(status.url)')
echo $SERVICE_URL
```

### Build Logs

```bash
# Get recent build logs
gcloud builds log $(gcloud builds list --limit=1 --format="value(id)") --project=toy-api-dev
```

## 💰 Cost Optimization

**Free Tier Limits:**
- **120 build minutes/day** (4000 minutes/month)
- **10 concurrent builds**
- **Standard machine type** recommended

**Cost-Saving Tips:**
- Use `E2_STANDARD_2` machine type (default)
- Enable build caching for faster builds
- Optimize Docker layer caching

## 🎉 Success Criteria

Your Cloud Build setup is successful when:
- ✅ Builds trigger automatically on `git push`
- ✅ All 33 unit tests pass in pipeline
- ✅ Docker images build and push successfully  
- ✅ Cloud Run deployment completes
- ✅ Integration tests verify live service
- ✅ Automatic rollback works on failures

---

**Next Steps**: Once Cloud Build is working, consider adding staging promotion workflows and monitoring alerts for production deployments.