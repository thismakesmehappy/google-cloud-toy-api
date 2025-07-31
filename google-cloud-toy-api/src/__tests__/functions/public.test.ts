import { Request, Response } from 'express';
import { publicMessage } from '../../functions/public';

describe('Public Function', () => {
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;

  beforeEach(() => {
    mockReq = {};
    mockRes = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
    };
  });

  test('should return public message with 200 status', () => {
    publicMessage(mockReq as Request, mockRes as Response);

    expect(mockRes.status).toHaveBeenCalledWith(200);
    expect(mockRes.send).toHaveBeenCalledWith({
      message: 'Hello from the public endpoint!'
    });
  });

  test('should return consistent message format', () => {
    publicMessage(mockReq as Request, mockRes as Response);

    const sendCall = (mockRes.send as jest.Mock).mock.calls[0][0];
    expect(sendCall).toHaveProperty('message');
    expect(typeof sendCall.message).toBe('string');
    expect(sendCall.message).toContain('public');
  });
});