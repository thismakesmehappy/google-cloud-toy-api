# Google Cloud Serverless API Implementation Plan

This document outlines the plan to build a serverless API on Google Cloud, leveraging the free tier and best practices. This project will mirror the functionality of the original AWS project, but with a Google Cloud technology stack.

## Phase 1: Project Setup & Google Cloud Configuration

### 1.1. Google Cloud Project Setup

*   Create three Google Cloud projects: `toy-api-dev`, `toy-api-stage`, and `toy-api-prod`.
*   Enable the required APIs for each project:
    *   Cloud Functions API
    *   API Gateway API
    *   Firestore API
    *   Cloud Build API
    *   Firebase Authentication (via Firebase console)
*   Configure billing for each project and set up a budget alert of $10/month, with notifications at 50%, 75%, 85%, and 95% sent to `bernardo+GoogleToyAPI@thismakesmehappy.co`.

### 1.2. Local Environment Setup

*   Install and initialize the Google Cloud SDK (`gcloud`).
*   Install Terraform.
*   Install Python 3.11+.
*   Set up a Python virtual environment.

### 1.3. Project Structure

```
google-cloud-toy-api/
├── terraform/                 # Terraform code for infrastructure
│   ├── dev/
│   ├── stage/
│   └── prod/
├── src/                       # Python source code for Cloud Functions
│   ├── main.py
│   ├── requirements.txt
│   └── ...
├── .github/workflows/         # GitHub Actions CI/CD pipeline
│   └── main.yml
├── .gitignore
└── README.md
```

## Phase 2: Infrastructure as Code with Terraform

### 2.1. Terraform Configuration

*   Create a separate Terraform workspace for each environment (dev, stage, prod).
*   Define the following resources in Terraform:
    *   **Cloud Functions:** For the API backend logic.
    *   **API Gateway:** To expose the Cloud Functions as a REST API.
    *   **Firestore Database:** A NoSQL database for storing data.
    *   **IAM Policies:** To grant necessary permissions to Cloud Functions and other services.

### 2.2. API Gateway Configuration

*   Define an OpenAPI specification (v3) to configure the API Gateway.
*   The spec will include paths for public and authenticated endpoints.
*   Configure JWT authentication using Firebase.

## Phase 3: Backend Development with Python

### 3.1. Cloud Functions

*   Develop Python functions to handle the API requests.
*   Use the Flask framework for routing and request handling within the Cloud Functions.
*   Implement the following logic:
    *   **Public Endpoint:** A simple function that returns a public message.
    *   **Authentication:** Functions to handle user login and registration using the Firebase Admin SDK.
    *   **Authenticated Endpoint:** A function that verifies the Firebase JWT and returns a private message.
    *   **CRUD Operations:** Functions to create, read, update, and delete items in Firestore, with authorization checks.

### 3.2. Firebase Integration

*   Set up a Firebase project and enable Firebase Authentication.
*   Use the Firebase Admin SDK in the Python code to:
    *   Verify JWTs for authenticated requests.
    *   Create and manage users.
    *   Implement role-based access control using custom claims.

## Phase 4: CI/CD with GitHub Actions

### 4.1. GitHub Actions Workflow

*   Create a `main.yml` workflow file.
*   The workflow will be triggered on pushes to the `main` branch.
*   The workflow will have the following jobs:
    1.  **Lint & Test:** Run a linter and unit tests on the Python code.
    2.  **Deploy to Dev:** Deploy the Terraform infrastructure and Cloud Functions to the `toy-api-dev` project.
    3.  **Integration Test (Dev):** Run integration tests against the dev environment.
    4.  **Deploy to Stage:** Deploy to the `toy-api-stage` project.
    5.  **Integration Test (Stage):** Run integration tests against the stage environment.
    6.  **Deploy to Prod:** Deploy to the `toy-api-prod` project.

### 4.2. Secrets Management

*   Store Google Cloud service account keys and other secrets in GitHub Secrets.

## Phase 5: Local Development & Testing

### 5.1. Local Emulators

*   Use the Google Cloud emulators for:
    *   **Cloud Functions:** Test functions locally without deploying.
    *   **Firestore:** Develop against a local Firestore database.
*   Provide documentation on how to start and use the emulators.

### 5.2. Testing Strategy

*   **Unit Tests:** Use `pytest` to test individual functions and business logic.
*   **Integration Tests:** Use `pytest` to test the API endpoints by making HTTP requests to the deployed application.

## Success Criteria

*   ✅ All infrastructure is managed by Terraform.
*   ✅ The API has public and authenticated endpoints.
*   ✅ Authentication is handled by Firebase.
*   ✅ Data is stored in Firestore.
*   ✅ The CI/CD pipeline automatically deploys to all environments.
*   ✅ Local development is possible with emulators.
*   ✅ The project stays within the Google Cloud free tier.