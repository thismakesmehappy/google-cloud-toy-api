# API Testing Guide

This document outlines how to test the deployed API Gateway endpoints.

Your API Gateway URL is: `https://toy-api-gateway-dev-630u6ptl.uc.gateway.dev`
Your Cloud Function URL is: `https://us-central1-toy-api-dev.cloudfunctions.net/toy-api-function-dev`

---

### **1. Public Endpoint: `/public` (GET)**

This endpoint should be accessible without any authentication.

**Expected Behavior:** Returns a JSON object with a public message.

**`curl` Command:**

```bash
curl -X GET "https://toy-api-gateway-dev-630u6ptl.uc.gateway.dev/public"
```

**Expected Response (example):**

```json
{
  "message": "Hello from public endpoint!"
}
```

---

### **2. Authenticated Endpoints (Requires Firebase Authentication)**

For the `/private` and `/items` endpoints, you will need an ID Token from Firebase Authentication.

**Steps to get a Firebase ID Token:**

1.  **Set up Firebase Authentication:** Ensure you have Firebase Authentication enabled for your project and have at least one user registered.
2.  **Obtain ID Token:** You can obtain an ID Token by signing in a user using a Firebase SDK (e.g., in a web app, mobile app, or a Node.js script). For quick testing, you can use the Firebase Admin SDK locally or a client-side SDK.

    **Example (Node.js using Firebase Admin SDK locally - for testing purposes):**

    ```javascript
    const admin = require('firebase-admin');
    const serviceAccount = require('./path/to/your/toy-api-dev-firebase-adminsdk.json'); // Your local service account key

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });

    async function generateCustomTokenAndIdToken(uid) {
      try {
        const customToken = await admin.auth().createCustomToken(uid);
        console.log('Custom Token:', customToken);
        // You would typically send this customToken to a client-side app
        // for them to sign in and get an ID Token.
        // For direct testing, you might need a client-side Firebase app
        // or a tool that can simulate the client-side sign-in.
        // For simplicity, if you have a test user, you can use their ID Token directly
        // from a client-side application after they sign in.
      } catch (error) {
        console.error('Error creating custom token:', error);
      }
    }

    // Replace 'some-user-uid' with an actual user UID from your Firebase project
    // generateCustomTokenAndIdToken('some-user-uid');
    ```

    **Alternatively, if you have a web application using Firebase SDK:**
    ```javascript
    // After user signs in
    firebase.auth().currentUser.getIdToken(/* forceRefresh */ true)
      .then(function(idToken) {
        console.log(idToken); // Use this ID Token in your curl commands
      }).catch(function(error) {
        console.error(error);
      });
    ```
    Once you have your `ID_TOKEN`, use it in the `Authorization` header as `Bearer ID_TOKEN`.

---

### **3. Private Endpoint: `/private` (GET)**

This endpoint requires Firebase Authentication.

**Expected Behavior:** Returns a JSON object with a private message if authenticated, otherwise returns `Unauthorized`.

**`curl` Command (replace `YOUR_FIREBASE_ID_TOKEN`):**

```bash
curl -X GET "https://toy-api-gateway-dev-630u6ptl.uc.gateway.dev/private" \
     -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

**Expected Response (authenticated example):**

```json
{
  "message": "Hello from private endpoint!"
}
```

**Expected Response (unauthorized example):**

```
Unauthorized
```

---

### **4. Items Endpoint: `/items` (POST)**

This endpoint requires Firebase Authentication and creates a new item in Firestore.

**Expected Behavior:** Creates a new item and returns its details.

**`curl` Command (replace `YOUR_FIREBASE_ID_TOKEN` and `YOUR_MESSAGE`):**

```bash
curl -X POST "https://toy-api-gateway-dev-630u6ptl.uc.gateway.dev/items" \
     -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"message": "YOUR_MESSAGE"}'
```

**Expected Response (example):**

```json
{
  "message": "YOUR_MESSAGE",
  "userId": "firebase-user-id",
  "createdAt": {
    "_seconds": 1700000000,
    "_nanoseconds": 123000000
  },
  "updatedAt": {
    "_seconds": 1700000000,
    "_nanoseconds": 123000000
  },
  "id": "firestore-document-id"
}
```
**Note down the `id` from the response for subsequent GET, PUT, DELETE operations.**

---

### **5. Items Endpoint: `/items` (GET)**

This endpoint requires Firebase Authentication and lists all items for the authenticated user.

**Expected Behavior:** Returns a list of items.

**`curl` Command (replace `YOUR_FIREBASE_ID_TOKEN`):**

```bash
curl -X GET "https://toy-api-gateway-dev-630u6ptl.uc.gateway.dev/items" \
     -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

**Expected Response (example):**

```json
[
  {
    "message": "My first item",
    "userId": "firebase-user-id",
    "createdAt": {
      "_seconds": 1700000000,
      "_nanoseconds": 123000000
    },
    "updatedAt": {
      "_seconds": 1700000000,
      "_nanoseconds": 123000000
    },
    "id": "firestore-document-id-1"
  },
  {
    "message": "My second item",
    "userId": "firebase-user-id",
    "createdAt": {
      "_seconds": 1700000050,
      "_nanoseconds": 456000000
    },
    "updatedAt": {
      "_seconds": 1700000050,
      "_nanoseconds": 456000000
    },
    "id": "firestore-document-id-2"
  }
]
```

---

### **6. Items Endpoint: `/items/{id}` (GET)**

This endpoint requires Firebase Authentication and retrieves a specific item by its ID.

**Expected Behavior:** Returns the details of the specified item.

**`curl` Command (replace `YOUR_FIREBASE_ID_TOKEN` and `ITEM_ID`):**

```bash
curl -X GET "https://toy-api-gateway-dev-630u6ptl.uc.gateway.dev/items/ITEM_ID" \
     -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

**Expected Response (example):**

```json
{
  "message": "My first item",
  "userId": "firebase-user-id",
  "createdAt": {
    "_seconds": 1700000000,
    "_nanoseconds": 123000000
  },
  "updatedAt": {
    "_seconds": 1700000000,
    "_nanoseconds": 123000000
  },
  "id": "ITEM_ID"
}
```

---

### **7. Items Endpoint: `/items/{id}` (PUT)**

This endpoint requires Firebase Authentication and updates a specific item by its ID.

**Expected Behavior:** Updates the item and returns its new details.

**`curl` Command (replace `YOUR_FIREBASE_ID_TOKEN`, `ITEM_ID`, and `UPDATED_MESSAGE`):**

```bash
curl -X PUT "https://toy-api-gateway-dev-630u6ptl.uc.gateway.dev/items/ITEM_ID" \
     -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"message": "UPDATED_MESSAGE"}'
```

**Expected Response (example):**

```json
{
  "message": "UPDATED_MESSAGE",
  "userId": "firebase-user-id",
  "createdAt": {
    "_seconds": 1700000000,
    "_nanoseconds": 123000000
  },
  "updatedAt": {
    "_seconds": 1700000000,
    "_nanoseconds": 123000000
  },
  "id": "ITEM_ID"
}
```

---

### **8. Items Endpoint: `/items/{id}` (DELETE)**

This endpoint requires Firebase Authentication and deletes a specific item by its ID.

**Expected Behavior:** Deletes the item and returns a 204 No Content status.

**`curl` Command (replace `YOUR_FIREBASE_ID_TOKEN` and `ITEM_ID`):**

```bash
curl -X DELETE "https://toy-api-gateway-dev-630u6ptl.uc.gateway.dev/items/ITEM_ID" \
     -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

**Expected Response:**

(No content, successful HTTP status 204)

```