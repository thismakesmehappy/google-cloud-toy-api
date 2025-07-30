import * as admin from 'firebase-admin';

export interface Item {
  id?: string;
  message: string;
  userId: string;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}