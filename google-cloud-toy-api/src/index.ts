import express from 'express';
import { publicMessage } from './functions/public';
import { privateMessage } from './functions/private';
import { firebaseAuthMiddleware } from './services/auth';
import * as admin from 'firebase-admin';
import { createItem, getItem, getItems, updateItem, deleteItem } from './services/firestore';

export const app = express();

app.use(express.json()); // Add this line to parse JSON request bodies

app.get('/', (req, res) => res.send('Hello from root!'));
app.get('/public', publicMessage);
app.get('/private', firebaseAuthMiddleware, privateMessage);

// Authentication Endpoint
app.post('/auth/token', async (req, res) => {
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
app.post('/items', firebaseAuthMiddleware, async (req, res) => {
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

app.get('/items', firebaseAuthMiddleware, async (req, res) => {
  try {
    const userId = (req as any).user.uid;
    const items = await getItems(userId);
    res.status(200).send(items);
  } catch (error: any) {
    res.status(500).send(`Error getting items: ${error.message}`);
  }
});

app.get('/items/:id', firebaseAuthMiddleware, async (req, res) => {
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

app.put('/items/:id', firebaseAuthMiddleware, async (req, res) => {
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

app.delete('/items/:id', firebaseAuthMiddleware, async (req, res) => {
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