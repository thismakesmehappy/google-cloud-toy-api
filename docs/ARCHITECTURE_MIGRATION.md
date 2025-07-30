# Architecture Migration: Cloud Functions → Cloud Run

## Migration Decision

After extensive CI/CD pipeline issues, we're migrating from Cloud Functions + API Gateway to Cloud Run for better simplicity and reliability.

## Current Architecture Issues

### Problems Encountered:
1. **TypeScript Compilation Errors**: Cloud Functions build failing on module imports
2. **Resource Import Conflicts**: 409 errors requiring complex import logic
3. **IAM Permission Complexity**: Multiple service account relationships
4. **API Gateway Configuration**: OpenAPI specs and JWT validation complexity
5. **Service Account Key Exposure**: Security vulnerabilities from authentication approach
6. **Local/Production Parity**: Different runtime environments causing issues

### Root Cause Analysis:
- Over-engineered architecture for a toy API
- Fighting against Google Cloud's native patterns
- Complex multi-service dependencies
- Manual resource creation mixed with Infrastructure as Code

## New Cloud Run Architecture

### Benefits:
- ✅ **Simplified Deployment**: Single containerized service
- ✅ **Better Local Development**: Docker containers work everywhere
- ✅ **Reduced Complexity**: No API Gateway layer needed
- ✅ **Standard Patterns**: Industry-standard container deployment
- ✅ **Easier Debugging**: Container logs and direct HTTP access
- ✅ **Cost Effective**: Pay per request, automatic scaling

### Architecture Comparison:

#### BEFORE (Cloud Functions + API Gateway):
```
GitHub Actions → Terraform → Cloud Functions v2 → API Gateway → Users
                          ↓
                        Firestore Database
```

#### AFTER (Cloud Run):
```
GitHub Actions → Docker Build → Cloud Run Service → Users
                              ↓
                            Firestore Database
```

## Migration Plan

### Phase 1: Container Preparation
- [ ] Create Dockerfile for Express application
- [ ] Add docker-compose for local development
- [ ] Test container builds locally

### Phase 2: Terraform Refactoring
- [ ] Replace cloud-function module with cloud-run module
- [ ] Remove api-gateway module completely
- [ ] Simplify IAM configurations

### Phase 3: CI/CD Pipeline Updates
- [ ] Replace function deployment with container deployment
- [ ] Update GitHub Actions to build and push Docker images
- [ ] Simplify environment-specific configurations

### Phase 4: Multi-Environment Setup
- [ ] Deploy to dev environment first
- [ ] Validate staging environment
- [ ] Production deployment with monitoring

## Expected Outcomes

### Development Experience:
- **Faster feedback loops**: Local Docker development
- **Consistent environments**: Same container everywhere
- **Easier debugging**: Standard container tooling

### Operations:
- **Reduced maintenance**: Fewer moving parts
- **Improved reliability**: Proven container patterns
- **Better monitoring**: Container-native observability

### Security:
- **Simplified IAM**: Just Cloud Run invoker permissions
- **No service account keys**: Application Default Credentials
- **Container security**: Standard container scanning

## Migration Timeline

- **Documentation**: ✅ Complete
- **Phase 1**: 1-2 hours (Containerization)
- **Phase 2**: 1-2 hours (Terraform refactoring)
- **Phase 3**: 1 hour (CI/CD updates)
- **Phase 4**: 1 hour (Multi-environment deployment)

**Total estimated time**: 4-6 hours vs. weeks of debugging current approach

## Rollback Plan

If migration encounters issues:
1. Current architecture remains in git history
2. Can revert to previous commit and fix specific issues
3. Terraform state can be imported back if needed

However, given the analysis of current issues, rollback is unlikely to be beneficial.

---

*Migration started: [Current Date]*
*Led by: Claude Code Analysis and Recommendation*