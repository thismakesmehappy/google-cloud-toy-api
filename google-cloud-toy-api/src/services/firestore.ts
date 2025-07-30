import * as admin from 'firebase-admin';
import { Item } from '../types/index';

// Use Firestore emulator if FIREBASE_FIRESTORE_EMULATOR_HOST is set
if (process.env.FIREBASE_FIRESTORE_EMULATOR_HOST) {
  admin.firestore().settings({
    host: process.env.FIREBASE_FIRESTORE_EMULATOR_HOST,
    ssl: false,
    credentials: {
      client_email: (admin.app().options.credential as any)?.client_email,
      private_key: (admin.app().options.credential as any)?.private_key,
    },
  });
  console.log('Using Firestore emulator at:', process.env.FIREBASE_FIRESTORE_EMULATOR_HOST);
}

const db = admin.firestore();
const itemsCollection = db.collection('items');

export const createItem = async (message: string, userId: string): Promise<Item> => {
  const now = admin.firestore.Timestamp.now();
  const newItem: Item = {
    message,
    userId,
    createdAt: now,
    updatedAt: now,
  };
  const docRef = await itemsCollection.add(newItem);
  return { ...newItem, id: docRef.id };
};

export const getItem = async (id: string, userId: string): Promise<Item | null> => {
  const doc = await itemsCollection.doc(id).get();
  if (!doc.exists || doc.data()?.userId !== userId) {
    return null;
  }
  return { id: doc.id, ...(doc.data() as Omit<Item, 'id'>) };
};

export const getItems = async (userId: string): Promise<Item[]> => {
  const snapshot = await itemsCollection.where('userId', '==', userId).get();
  return snapshot.docs.map(doc => ({ id: doc.id, ...(doc.data() as Omit<Item, 'id'>) }));
};

export const updateItem = async (id: string, userId: string, updates: Partial<Omit<Item, 'id' | 'userId' | 'createdAt'>>): Promise<Item | null> => {
  const docRef = itemsCollection.doc(id);
  const doc = await docRef.get();

  if (!doc.exists || doc.data()?.userId !== userId) {
    return null;
  }

  const now = admin.firestore.Timestamp.now();
  await docRef.update({ ...updates, updatedAt: now });
  const updatedDoc = await docRef.get();
  return { id: updatedDoc.id, ...(updatedDoc.data() as Omit<Item, 'id'>) };
};

export const deleteItem = async (id: string, userId: string): Promise<boolean> => {
  const docRef = itemsCollection.doc(id);
  const doc = await docRef.get();

  if (!doc.exists || doc.data()?.userId !== userId) {
    return false;
  }

  await docRef.delete();
  return true;
};
