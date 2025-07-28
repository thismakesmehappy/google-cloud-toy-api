# Quick CI/CD Setup Guide

Follow these steps to get your CI/CD pipeline running:

## Step 1: Run the Setup Script

```bash
# Make sure you're authenticated with gcloud
gcloud auth login

# Run the setup script
./setup-cicd.sh
```

This script will:
- ✅ Create service accounts for each environment
- ✅ Grant necessary permissions
- ✅ Generate service account keys
- ✅ Provide next steps

## Step 2: Create GitHub Repository

### Option A: Create new repository on GitHub.com
1. Go to https://github.com/new
2. Create a repository named `google-cloud-toy-api`
3. Don't initialize with README (we already have files)

### Option B: Use GitHub CLI (if you have it)
```bash
gh repo create google-cloud-toy-api --public --source=. --push
```

## Step 3: Add GitHub Secrets

Go to your repository Settings > Secrets and variables > Actions:

### Required Secrets:
- `GCP_SA_KEY_DEV`: Contents of `.github-keys/github-actions-dev-key.json`
- `GCP_PROJECT_ID_DEV`: `toy-api-dev`
- `DEV_API_KEY`: `dev-api-key-123`

### Optional (for staging/prod when ready):
- `GCP_SA_KEY_STAGING`: Contents of staging key file
- `GCP_PROJECT_ID_STAGING`: `toy-api-stage`
- `STAGING_API_KEY`: `staging-api-key-456`
- `GCP_SA_KEY_PROD`: Contents of prod key file
- `GCP_PROJECT_ID_PROD`: `toy-api-prod`

## Step 4: Push to GitHub

```bash
# Add all files
git add .

# Commit changes
git commit -m "feat: Add CI/CD pipeline and modular infrastructure

- Add GitHub Actions workflow for automated deployment
- Create modular Terraform structure for multi-environment
- Add service account setup for CI/CD
- Update package.json with proper build scripts"

# Add remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/google-cloud-toy-api.git

# Push to GitHub
git push -u origin main
```

## Step 5: Watch the Magic! 🎉

1. Go to your GitHub repository
2. Click on "Actions" tab
3. You should see the workflow running automatically
4. The pipeline will:
   - ✅ Run tests and validation
   - ✅ Deploy to dev environment
   - ✅ Run integration tests
   - ✅ (Deploy to staging/prod when those projects exist)

## Troubleshooting

### If the workflow fails:
1. Check the Actions tab for error details
2. Verify all secrets are added correctly
3. Make sure service account has all necessary permissions
4. Check that the project IDs match your actual projects

### To test locally before pushing:
```bash
cd google-cloud-toy-api
npm install
npm run type-check
npm run build
npm test
```

### To validate Terraform:
```bash
cd google-cloud-toy-api/terraform/environments/dev
terraform init
terraform validate
terraform plan
```

## Next Steps

Once the basic CI/CD is working:
1. Create staging and prod GCP projects
2. Run the setup script again to create service accounts for those environments
3. Add the additional secrets to GitHub
4. The pipeline will automatically deploy to all environments!

## Security Notes

🔒 **IMPORTANT**: 
- Service account keys are stored in `.github-keys/` and are gitignored
- Never commit these keys to version control
- Rotate keys regularly for security
- Use least-privilege permissions for service accounts