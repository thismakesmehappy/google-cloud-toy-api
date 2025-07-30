import { Request, Response } from 'express';

export const privateMessage = (req: Request, res: Response) => {
  res.status(200).send({ message: 'Hello from the private endpoint!' });
};