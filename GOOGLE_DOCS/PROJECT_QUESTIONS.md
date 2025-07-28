# Project Clarification Questions (Google Cloud)

This document outlines clarifying questions to ensure the Google Cloud implementation aligns with your expectations and leverages the best of the platform's free tier.

## 1. Project Core & API Functionality

*   **API Gateway & Endpoints:** The AWS version used API Gateway with specific public and authenticated endpoints. For Google Cloud, we can use **Cloud Functions** (2nd gen) with **API Gateway**. Is the existing endpoint structure (`/public/message`, `/auth/login`, etc.) still what you want?
I'm open to suggestions. I am more concerned with making cure we have an auth endpoint available for the user. regarding the structure of public vs private, these endpoints are exmaples only; my goal is for you to setup the infra and then I'll design the API contract and the services and will pick and chooe the routes.
* 
*   **Backend Logic:** The AWS implementation used Java 17 with Lambda. We can use Java on Cloud Functions. Are you open to other languages like **Python** or **Node.js** for potentially faster development and cold starts, or should we stick with Java?
Open to your recommendation. I am familiar with creating APIs with Java, but open to suggestions. This is a toy project, so I'm not concerned with performance, but my goal is to learn and potentially use this as a base for a future project where performance will be relevant.

## 2. Authentication & Authorization

*   **Authentication:** The AWS project used Cognito. The closest Google Cloud equivalent is **Firebase Authentication** or **Identity Platform**. Both have generous free tiers. Do you have a preference? Firebase is often simpler for web/mobile apps.
Let's use Firebase. Right now I am just playing with the tech, but in the future I plan to build a web/mobile app.


*   **Authorization:** The AWS version had both role-based (admin/user) and resource-based (user sees their own data) access. We can replicate this. For role-based access, we can use custom claims in Firebase Authentication tokens. Is this approach acceptable?
I am not familiar with Google cloud. I trust your judement.

## 3. Database

*   **Database Choice:** The AWS project used DynamoDB. The Google Cloud free tier equivalents are **Firestore** or **Cloud Storage**.
    *   **Firestore:** A NoSQL document database, very similar to DynamoDB in functionality. It's great for structured data like user profiles and items.
    *   **Cloud Storage:** An object store, better for files.
    *   I recommend **Firestore** for this project. Is that okay?
    Yes. I expect the data to be in JSON format.

## 4. Infrastructure & Deployment

*   **Infrastructure as Code (IaC):** The AWS project used CDK. For Google Cloud, we can use **Terraform** or **Google Cloud Deployment Manager**. Terraform is more popular and cloud-agnostic. Would you like to use Terraform for defining our resources (Cloud Functions, API Gateway, Firestore)?
I trust your judement. I want this to be a learning experience for me.

*   **CI/CD:** The AWS project used GitHub Actions. We can do the same for Google Cloud, deploying to different environments (dev, stage, prod). Is the `main` branch pipeline (dev -> stage -> prod) still the desired workflow?
Correct. At Amazon the main branch fed the pipeline and we had to manually push non-main branches to the repo, but they didn't make it into the pipeline. I like this approach.


*   **Environments:** The AWS project had dev, stage, and prod environments in one region. We can replicate this using separate Google Cloud Projects or by prefixing resources (e.g., `dev-my-api`, `prod-my-api`). Using separate projects is a best practice for isolation. Would you like to proceed with that?
If separate projects remain free, then let's do that. For now let's push to dev, but later we will remove dev from the pipeline and I'll push manually to dev.

## 5. Budget & Monitoring

*   **Budget Alerts:** Google Cloud has built-in budget alerts that can be configured to send emails, similar to AWS. I'll set up alerts for 50%, 75%, 85%, and 95% of a $10 monthly budget. Is the email `bernardo+toyAPI@thismakesmehappy.co` still the correct one?
let's use bernardo+GoogleToyAPI@thismakesmehappy.co to differentiate

*   **Monitoring:** We'll use **Google Cloud's operations suite** (formerly Stackdriver) for logging, monitoring, and alerting (error rates, latency). This is the standard for Google Cloud.
sounds good

## 6. Local Development

*   **Local Emulators:** Google Cloud provides local emulators for many services, including Cloud Functions and Firestore. This allows for local development and testing without incurring costs. I will document how to use these. Is this approach acceptable?
Yes. I want to learn from you, so open to this approach.

Please review these questions and provide your answers. Once I have your feedback, I will create a detailed implementation plan for the Google Cloud project.