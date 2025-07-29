import express from 'express';
import { publicMessage } from './functions/public.js';
import { privateMessage } from './functions/private.js';
import { firebaseAuthMiddleware, simpleAuthMiddleware } from './services/auth.js';
import * as admin from 'firebase-admin';
import { createItem, getItem, getItems, updateItem, deleteItem } from './services/firestore.js';

const expressApp = express();
expressApp.set('trust proxy', true);
const router = express.Router();

expressApp.use(express.json()); // Add this line to parse JSON request bodies

expressApp.use((req, res, next) => {
  console.log('Request Path:', req.path, 'URL:', req.url, 'Original URL:', req.originalUrl);
  next();
});

router.get('/', (req, res) => res.send('Hello World! Clean build'));
router.get('/public', publicMessage);
router.get('/private', simpleAuthMiddleware, privateMessage);

// Authentication Endpoint
router.post('/auth/token', async (req, res) => {
  try {
    const { uid } = req.body;
    if (!uid) {
      return res.status(400).send('UID is required.');
    }
    const customToken = await admin.auth().createCustomToken(uid);
    res.status(200).send({ customToken });
  } catch (error: any) {
    res.status(500).send(`Error creating custom token: ${error.message}`);
  }
});

// Item CRUD Endpoints
router.post('/items', simpleAuthMiddleware, async (req, res) => {
  try {
    const userId = (req as any).user.uid;
    const { message } = req.body;
    if (!message) {
      return res.status(400).send('Message is required.');
    }
    const item = await createItem(message, userId);
    res.status(201).send(item);
  } catch (error: any) {
    res.status(500).send(`Error creating item: ${error.message}`);
  }
});

router.get('/items', simpleAuthMiddleware, async (req, res) => {
  try {
    const userId = (req as any).user.uid;
    const items = await getItems(userId);
    res.status(200).send(items);
  } catch (error: any) {
    res.status(500).send(`Error getting items: ${error.message}`);
  }
});

router.get('/items/:id', simpleAuthMiddleware, async (req, res) => {
  try {
    const userId = (req as any).user.uid;
    const item = await getItem(req.params.id, userId);
    if (!item) {
      return res.status(404).send('Item not found or unauthorized.');
    }
    res.status(200).send(item);
  } catch (error: any) {
    res.status(500).send(`Error getting item: ${error.message}`);
  }
});

router.put('/items/:id', simpleAuthMiddleware, async (req, res) => {
  try {
    const userId = (req as any).user.uid;
    const { message } = req.body;
    if (!message) {
      return res.status(400).send('Message is required for update.');
    }
    const updatedItem = await updateItem(req.params.id, userId, { message });
    if (!updatedItem) {
      return res.status(404).send('Item not found or unauthorized.');
    }
    res.status(200).send(updatedItem);
  } catch (error: any) {
    res.status(500).send(`Error updating item: ${error.message}`);
  }
});

router.delete('/items/:id', simpleAuthMiddleware, async (req, res) => {
  try {
    const userId = (req as any).user.uid;
    const success = await deleteItem(req.params.id, userId);
    if (!success) {
      return res.status(404).send('Item not found or unauthorized.');
    }
    res.status(204).send(); // No content for successful delete
  } catch (error: any) {
    res.status(500).send(`Error deleting item: ${error.message}`);
  }
});

expressApp.use('/', router);

// Export for local development
export { expressApp };

// Google Cloud Functions v2 entry point
import { HttpFunction } from '@google-cloud/functions-framework';

export const app: HttpFunction = (req, res) => {
  return expressApp(req, res);
};