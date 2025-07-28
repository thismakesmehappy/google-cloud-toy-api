# 🔐 GitHub Secrets Setup

Your service accounts are ready! Here's exactly what you need to add to GitHub.

## 📝 GitHub Repository Setup

### 1. Create Repository
```bash
# If you haven't already, create a GitHub repository
gh repo create google-cloud-toy-api --public --source=. --push
# OR manually create at https://github.com/new
```

### 2. Add Secrets
Go to your repository: **Settings > Secrets and variables > Actions**

## 🔑 Required Secrets

Copy and paste these exact values into GitHub Secrets:

### Development Environment
**Secret Name**: `GCP_SA_KEY_DEV`  
**Value**: Contents of `.github-keys/github-actions-dev-key.json`
```bash
cat .github-keys/github-actions-dev-key.json
```

**Secret Name**: `GCP_PROJECT_ID_DEV`  
**Value**: `toy-api-dev`

**Secret Name**: `DEV_API_KEY`  
**Value**: `dev-api-key-123`

### Staging Environment  
**Secret Name**: `GCP_SA_KEY_STAGING`  
**Value**: Contents of `.github-keys/github-actions-staging-key.json`
```bash
cat .github-keys/github-actions-staging-key.json
```

**Secret Name**: `GCP_PROJECT_ID_STAGING`  
**Value**: `toy-api-stage`

**Secret Name**: `STAGING_API_KEY`  
**Value**: `staging-api-key-456`

### Production Environment
**Secret Name**: `GCP_SA_KEY_PROD`  
**Value**: Contents of `.github-keys/github-actions-prod-key.json`
```bash
cat .github-keys/github-actions-prod-key.json
```

**Secret Name**: `GCP_PROJECT_ID_PROD`  
**Value**: `toy-api-prod`

## 🛡️ Environment Protection (Optional but Recommended)

### 1. Create Environments
Go to **Settings > Environments** and create:
- `development` 
- `staging`
- `production`

### 2. Add Protection Rules
For **production** environment:
- ✅ Required reviewers (add yourself)
- ✅ Wait timer: 5 minutes  
- ✅ Deployment branches: main only

## 🚀 Test the CI/CD Pipeline

### Option 1: Push Current Changes
```bash
git add .
git commit -m "test: Trigger CI/CD pipeline"
git push origin main
```

### Option 2: Make a Small Change
```bash
echo "# CI/CD Test" >> README.md
git add README.md
git commit -m "test: Trigger CI/CD pipeline" 
git push origin main
```

## 📊 What to Expect

After pushing, go to **Actions** tab in your GitHub repo:

1. **✅ test** - Runs linting, type-checking, build validation
2. **✅ terraform-validate** - Validates all environment configs  
3. **✅ deploy-dev** - Deploys to development, runs integration tests
4. **✅ deploy-staging** - Deploys to staging (auto-triggered after dev)
5. **🛡️ deploy-prod** - Deploys to production (requires approval)

## 🔍 Troubleshooting

### If workflows fail:
1. **Check the Actions tab** for detailed error logs
2. **Verify secrets** are added exactly as shown above
3. **Check service account permissions** with `./fix-service-accounts.sh`

### Common issues:
- **Authentication errors**: Service account key format or permissions
- **Terraform conflicts**: May need to destroy/import existing resources
- **API timeouts**: Normal for first deployment, will succeed on retry

## 🎉 Success Indicators

When everything works, you'll see:
- ✅ Green checkmarks in Actions tab
- 🚀 Deployed applications in all environments
- 📊 Integration test results
- 🔗 Deployment URLs in workflow logs

Your CI/CD pipeline is now **fully automated** and **enterprise-ready**! 🚀