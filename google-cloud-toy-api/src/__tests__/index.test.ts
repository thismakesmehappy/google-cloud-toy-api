import request from 'supertest';
import { expressApp } from '../index';

describe('API Endpoints', () => {
  describe('Public Endpoints', () => {
    test('GET / should return hello world', async () => {
      const response = await request(expressApp)
        .get('/')
        .expect(200);
      
      expect(response.text).toBe('Hello World! Clean build');
    });

    test('GET /public should return public message', async () => {
      const response = await request(expressApp)
        .get('/public')
        .expect(200);
      
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toContain('public');
    });

    test('POST /auth/token should create Firebase token', async () => {
      const response = await request(expressApp)
        .post('/auth/token')
        .send({ uid: 'test-user-123' })
        .expect(200);
      
      expect(response.body).toHaveProperty('customToken');
      expect(response.body.customToken).toBe('mock-token');
    });

    test('POST /auth/token should require uid', async () => {
      const response = await request(expressApp)
        .post('/auth/token')
        .send({})
        .expect(400);
      
      expect(response.text).toBe('UID is required.');
    });
  });

  describe('Protected Endpoints', () => {
    const validApiKey = 'test-api-key';

    test('GET /private should reject without API key', async () => {
      await request(expressApp)
        .get('/private')
        .expect(401);
    });

    test('GET /private should reject with invalid API key', async () => {
      await request(expressApp)
        .get('/private')
        .set('x-api-key', 'invalid-key')
        .expect(401);
    });

    test('GET /private should accept valid API key', async () => {
      const response = await request(expressApp)
        .get('/private')
        .set('x-api-key', validApiKey)
        .expect(200);
      
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toContain('private');
    });

    test('GET /items should reject without API key', async () => {
      await request(expressApp)
        .get('/items')
        .expect(401);
    });

    test('GET /items should accept valid API key', async () => {
      const response = await request(expressApp)
        .get('/items')
        .set('x-api-key', validApiKey)
        .expect(200);
      
      expect(Array.isArray(response.body)).toBe(true);
    });

    test('POST /items should create item with valid API key', async () => {
      const response = await request(expressApp)
        .post('/items')
        .set('x-api-key', validApiKey)
        .send({ message: 'Test item message' })
        .expect(201);
      
      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('message', 'Test item message');
      expect(response.body).toHaveProperty('userId', 'test-user-123');
    });

    test('POST /items should require message', async () => {
      const response = await request(expressApp)
        .post('/items')
        .set('x-api-key', validApiKey)
        .send({})
        .expect(400);
      
      expect(response.text).toBe('Message is required.');
    });

    test('GET /items/:id should get specific item', async () => {
      const response = await request(expressApp)
        .get('/items/test-item-id')
        .set('x-api-key', validApiKey)
        .expect(200);
      
      expect(response.body).toHaveProperty('id', 'test-item-id');
      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('userId', 'test-user-123');
    });

    test('PUT /items/:id should update item', async () => {
      const response = await request(expressApp)
        .put('/items/test-item-id')
        .set('x-api-key', validApiKey)
        .send({ message: 'Updated message' })
        .expect(200);
      
      expect(response.body).toHaveProperty('id', 'test-item-id');
      expect(response.body).toHaveProperty('message'); // Mock doesn't actually update
    });

    test('PUT /items/:id should require message', async () => {
      const response = await request(expressApp)
        .put('/items/test-item-id')
        .set('x-api-key', validApiKey)
        .send({})
        .expect(400);
      
      expect(response.text).toBe('Message is required for update.');
    });

    test('DELETE /items/:id should delete item', async () => {
      await request(expressApp)
        .delete('/items/test-item-id')
        .set('x-api-key', validApiKey)
        .expect(204);
    });
  });

  describe('Error Handling', () => {
    test('GET /nonexistent should return 404', async () => {
      await request(expressApp)
        .get('/nonexistent')
        .expect(404);
    });
  });
});