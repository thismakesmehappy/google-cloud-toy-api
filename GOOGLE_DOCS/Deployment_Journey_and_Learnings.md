# Google Cloud Serverless API Deployment: Journey & Learnings

This document chronicles the process of deploying a serverless API on Google Cloud, mirroring an existing AWS project. It details the steps taken, challenges encountered, and solutions implemented, serving as a comprehensive guide for future replication.

## 1. Project Goal

The primary objective was to deploy a serverless API on Google Cloud, leveraging Terraform for infrastructure provisioning and a Node.js Express application for the Cloud Function. The API includes public and authenticated endpoints, with Firebase Authentication for user management and Firestore for data storage.

## 2. Technologies Used

*   **Infrastructure as Code:** Terraform
*   **Backend Application:** Node.js (TypeScript) with Express.js
*   **Serverless Compute:** Google Cloud Functions (2nd gen, built on Cloud Run)
*   **Authentication:** Firebase Authentication
*   **Database:** Google Cloud Firestore
*   **API Management:** Google Cloud API Gateway
*   **Build System:** Google Cloud Build

## 3. Deployment Journey: Challenges & Solutions

### 3.1 Initial Deployment & "Container Healthcheck failed"

**Challenge:** Upon initial deployment of the Express application as a Cloud Function, the deployment consistently failed with "Container Healthcheck failed" errors. Local testing of the Express app was successful.

**Investigation & Solution:**
*   **`app.listen()` Conflict:** Cloud Functions (and Cloud Run) manage port binding internally. Express applications deployed to these environments should export the Express app instance directly and *not* call `app.listen()`.
    *   **Action:** Removed `app.listen()` from `google-cloud-toy-api/src/index.ts`.
*   **TypeScript Compilation:** Ensured `main` in `package.json` pointed to `dist/index.js` and that `outDir` in `tsconfig.json` was `./dist`.
    *   **Action:** Verified `package.json` and `tsconfig.json` configurations.
*   **`GOOGLE_FUNCTION_SOURCE` Environment Variable:** Initially, we used `GOOGLE_FUNCTION_SOURCE = "dist"` in Terraform to point the buildpack to the compiled code. This was later removed as it was found to be unnecessary and potentially interfering with module resolution.
    *   **Action:** Removed `GOOGLE_FUNCTION_SOURCE = "dist"` from `google-cloud-toy-api/terraform/dev/main.tf`.

### 3.2 Module Not Found: `firebase-admin`

**Challenge:** After addressing the `app.listen()` issue, the Cloud Function still failed to start, with logs indicating "Cannot find module 'firebase-admin'". This was puzzling as `firebase-admin` was listed in `package.json`.

**Investigation & Solution:**
*   **Dependency Declaration:** Confirmed `firebase-admin` was in the `dependencies` section of `google-cloud-toy-api/package.json`.
    *   **Action:** Added `"firebase-admin": "^11.11.0"` to `dependencies`.
*   **Clean `npm install`:** Suspected a corrupted or incomplete `node_modules` or `package-lock.json`.
    *   **Action:** Performed a deep clean by deleting `node_modules` and `package-lock.json` in `google-cloud-toy-api/`, followed by `npm install`.
*   **TypeScript Rebuild:** Ensured `tsc` was run after `npm install` to recompile with all dependencies.
    *   **Action:** Ran `tsc` in `google-cloud-toy-api/`.

### 3.3 Persistent "Cannot find module '/_HIDDEN/toy-api-dev-firebase-adminsdk-fbsvc-2daa2f3508.json'"

**Challenge:** Despite previous fixes, the Cloud Function continued to fail with the specific error "Cannot find module '/_HIDDEN/toy-api-dev-firebase-adminsdk-fbsvc-2daa2f3508.json'". This indicated that the application was still trying to load a local service account key file, even though the TypeScript source was modified to use Application Default Credentials (ADC).

**Investigation & Solution:**
*   **Source Code Inspection (Local):** Verified `google-cloud-toy-api/src/services/auth.ts` and `google-cloud-toy-api/src/services/firestore.ts` no longer contained `require()` calls for the service account key, and instead used `admin.initializeApp();`.
    *   **Action:** Confirmed the code was correct locally.
*   **Deployment Package Exclusion:** Realized that even if the source code was correct, the `_HIDDEN` directory might still be included in the deployment package.
    *   **Action 1 (`.gcloudignore`):** Added `_HIDDEN/` to `google-cloud-toy-api/.gcloudignore` to prevent the directory from being uploaded.
    *   **Action 2 (`data "archive_file"` excludes):** Explicitly added `_HIDDEN/` to the `excludes` list within the `data "archive_file" "source_zip"` block in `google-cloud-toy-api/terraform/dev/main.tf`. This ensures Terraform's archiving process also excludes the directory.
*   **Node.js Runtime Upgrade:** While not directly related to the `_HIDDEN` issue, upgrading the Node.js runtime is a best practice and can resolve subtle compatibility issues.
    *   **Action:** Updated `runtime` to `"nodejs20"` in `google-cloud-toy-api/terraform/dev/main.tf`.
*   **Aggressive Clean & Re-deploy:** To eliminate any caching or stale state, a full destroy and re-apply was performed.
    *   **Action:** `terraform destroy -auto-approve` followed by `terraform apply -auto-approve`.

### 3.4 API Gateway Permission Error: `iam.serviceAccounts.actAs`

**Challenge:** After the Cloud Function started deploying successfully, the API Gateway configuration began failing with `Error 403: Permission 'iam.serviceAccounts.actAs' denied on service account "projects/-/serviceAccounts/service-476766033465@gcp-sa-apigateway.iam.gserviceaccount.com"`.

**Investigation & Solution:**
*   **Firestore Database Persistence:** The `terraform destroy` command did not delete the Firestore database, causing a `Database already exists` error on subsequent `apply`.
    *   **Action:** Manually deleted the Firestore database in the Google Cloud Console.
*   **`iam.serviceAccounts.actAs` Understanding:** This permission is typically needed when one service account impersonates another. The error indicated the API Gateway service account was trying to `actAs` itself, which is unusual for direct Cloud Function invocation.
*   **Granting `roles/iam.serviceAccountUser`:** This role allows a service account to be used by another service account.
    *   **Action:** Added a `google_service_account_iam_member` resource in `google-cloud-toy-api/terraform/dev/main.tf` to grant `roles/iam.serviceAccountUser` to the API Gateway service account (`service-476766033465@gcp-sa-apigateway.iam.gserviceaccount.com`) on the Cloud Function's service account (`PROJECT_NUMBER-compute@developer.gserviceaccount.com`).
    *   **Correction:** Initially, an incorrect `service_account_id` format was used. This was corrected to `projects/${var.project_id}/serviceAccounts/${data.google_project.project.number}-compute@developer.gserviceaccount.com`.
*   **OpenAPI `jwt_audience`/`jwt_issuer` Misconfiguration:** Attempted to define JWT authentication directly in `openapi.yaml`'s `x-google-backend` using `jwt_audience` and `jwt_issuer`. This resulted in `Cannot find field: jwt_issuer` errors.
    *   **Action:** Removed `jwt_audience` and `jwt_issuer` from `x-google-backend` in `google-cloud-toy-api/terraform/dev/openapi.yaml`. These fields are not directly supported for this type of backend authentication. The `google_service_account` in `main.tf` is the correct way to handle API Gateway to Cloud Function authentication.

### 3.5 Authentication Endpoint & User Credentials

**Challenge:** The user requested an authentication endpoint that would allow users to log in with a username and password directly to the Cloud Function.

**Investigation & Solution:**
*   **Security Best Practices:** Directly handling username and password in a Cloud Function is highly discouraged due to significant security risks (e.g., secure storage of credentials, hashing, password resets, protection against various attacks).
*   **Firebase Authentication's Role:** Firebase Authentication is designed to securely manage user credentials and authentication flows. It provides client-side SDKs for various platforms (web, iOS, Android) that handle email/password sign-up and sign-in securely.
*   **Recommended Approach:** The secure and recommended approach is for client-side applications to use the Firebase Authentication SDK to sign in users. Upon successful authentication, the client receives a Firebase ID Token. This ID Token is then sent to the Cloud Function (via API Gateway) in the `Authorization: Bearer <ID_TOKEN>` header.
*   **Cloud Function's Role:** The Cloud Function's role is to *verify* the Firebase ID Token using `firebase-admin`'s `verifyIdToken` method, ensuring the request is from an authenticated and legitimate user. The existing `firebaseAuthMiddleware` already performs this verification.
*   **Custom Token Endpoint (`/auth/token`):** The `/auth/token` endpoint was added to demonstrate how to generate a *custom Firebase token* for a given UID. This is a more advanced feature used when integrating Firebase Authentication with an existing authentication system or creating users from a trusted server environment. It is *not* intended for direct username/password login from a client.

## 4. Key Learnings & Best Practices

*   **Application Default Credentials (ADC):** Always prefer `admin.initializeApp()` for Firebase Admin SDK in Google Cloud environments. Avoid deploying service account key files with your application.
*   **Cloud Run/Functions Port Binding:** Never call `app.listen()` in Express apps deployed to Cloud Run or Cloud Functions. The runtime handles port binding.
*   **Comprehensive Exclusion:** Use both `.gcloudignore` and `data "archive_file"` excludes in Terraform to ensure sensitive files and unnecessary directories are not included in your deployment package.
*   **Debugging Cloud Run/Functions:** The Cloud Run logs are crucial for diagnosing runtime errors. Pay close attention to "Container Healthcheck failed" messages and the detailed stack traces.
*   **IAM Permissions for Inter-Service Communication:** When services interact (e.g., API Gateway invoking a Cloud Function), ensure the invoking service's service account has the necessary IAM roles on the target service or its service account. The `roles/cloudfunctions.invoker` is essential for the API Gateway service account on the Cloud Function. The `roles/iam.serviceAccountUser` role on the Cloud Function's service account for the API Gateway service account can also be necessary for certain authentication flows.
*   **Terraform State Management:** Be aware that `terraform destroy` might not immediately delete all underlying Google Cloud resources, especially for data services like Firestore. Manual cleanup might be required before re-applying.
*   **OpenAPI Specification Accuracy:** Pay close attention to the exact fields and their valid values within OpenAPI extensions like `x-google-backend`. Refer to official documentation for specific authentication methods.

## 5. Next Steps

1.  **User Testing:** Thoroughly test all API endpoints using the provided `API_Testing_Guide.md` document to confirm full functionality and correct authentication.
2.  **Authentication Endpoint:** Implement a dedicated authentication endpoint within the API to handle user login and token generation, streamlining client-side integration.