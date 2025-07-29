import { Request, Response, NextFunction } from 'express';
import * as admin from 'firebase-admin';
import * as path from 'path';

// Initialize Firebase Admin SDK only if not already initialized
if (!admin.apps.length) {
  // In Cloud Functions, service account credentials are automatically available
  // For local development, use the service account key file
  if (process.env.NODE_ENV === 'development') {
    const serviceAccountPath = path.join(__dirname, '../../firebase-service-account-key.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccountPath),
      projectId: 'toy-api-dev'
    });
  } else {
    // In Cloud Functions, initialize without explicit credentials
    admin.initializeApp({
      projectId: 'toy-api-dev'
    });
  }
}

// Simple API key auth for development/testing
export const simpleAuthMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const apiKey = req.headers['x-api-key'];
  const validApiKey = process.env.API_KEY || 'dev-api-key-123'; // Default for testing
  
  if (apiKey === validApiKey) {
    // Set a mock user for compatibility
    (req as any).user = { uid: 'test-user-123' };
    next();
  } else {
    res.status(401).json({ error: 'Invalid API key. Use x-api-key header.' });
  }
};

// Keep Firebase auth but make it optional
export const firebaseAuthMiddleware = async (req: Request, res: Response, next: NextFunction) => {
  const authorization = req.headers.authorization;
  if (!authorization || !authorization.startsWith('Bearer ')) {
    return res.status(403).send('Unauthorized');
  }

  const idToken = authorization.split('Bearer ')[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    (req as any).user = decodedToken;
    next();
  } catch (error: any) {
    res.status(403).send('Unauthorized');
  }
};