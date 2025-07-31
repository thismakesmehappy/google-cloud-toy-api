import { Request, Response } from 'express';
import { privateMessage } from '../../functions/private';

describe('Private Function', () => {
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;

  beforeEach(() => {
    mockReq = {};
    mockRes = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
    };
  });

  test('should return private message with 200 status', () => {
    privateMessage(mockReq as Request, mockRes as Response);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(mockRes.send).toHaveBeenCalledWith({
      message: 'Hello from the private endpoint!'
    });
  });

  test('should return consistent message format', () => {
    privateMessage(mockReq as Request, mockRes as Response);

    const sendCall = (mockRes.send as jest.Mock).mock.calls[0][0];
    expect(sendCall).toHaveProperty('message');
    expect(typeof sendCall.message).toBe('string');
    expect(sendCall.message).toContain('private');
  });
});