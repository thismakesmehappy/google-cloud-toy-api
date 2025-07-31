// Test setup and global mocks

// Mock Firebase Admin SDK
const mockFirestore = {
  collection: jest.fn(() => ({
    doc: jest.fn(() => ({
      get: jest.fn().mockResolvedValue({
        exists: true,
        id: 'test-item-id',
        data: jest.fn().mockReturnValue({
          message: 'Test message',
          userId: 'test-user-123',
          createdAt: { toDate: () => new Date() },
          updatedAt: { toDate: () => new Date() },
        }),
      }),
      set: jest.fn(),
      update: jest.fn().mockResolvedValue(undefined),
      delete: jest.fn().mockResolvedValue(undefined),
    })),
    add: jest.fn().mockResolvedValue({ id: 'mock-new-id' }),
    where: jest.fn(() => ({
      get: jest.fn().mockResolvedValue({
        docs: [{
          id: 'test-item-id',
          data: () => ({
            message: 'Test message',
            userId: 'test-user-123',
            createdAt: { toDate: () => new Date() },
            updatedAt: { toDate: () => new Date() },
          }),
        }],
      }),
    })),
    get: jest.fn(),
  })),
};

jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(),
  apps: [{}], // Simulate already initialized
  credential: {
    cert: jest.fn(),
  },
  firestore: jest.fn(() => mockFirestore),
  auth: jest.fn(() => ({
    createCustomToken: jest.fn().mockResolvedValue('mock-token'),
    verifyIdToken: jest.fn().mockResolvedValue({
      uid: 'firebase-user-123',
      email: 'test@example.com',
    }),
  })),
}));

// Add Timestamp mock to the firestore function
Object.assign(jest.requireMock('firebase-admin').firestore, {
  Timestamp: {
    now: jest.fn(() => ({ toDate: () => new Date() })),
  },
});

// Mock environment variables
process.env.NODE_ENV = 'test';
process.env.API_KEY = 'test-api-key';
process.env.API_KEY_DEV = 'test-api-key';
process.env.API_KEY_STAGING = 'test-staging-key';
process.env.API_KEY_PROD = 'test-prod-key';