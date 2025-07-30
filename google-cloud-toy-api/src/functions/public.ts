import { Request, Response } from 'express';

export const publicMessage = (req: Request, res: Response) => {
  res.status(200).send({ message: 'Hello from the public endpoint!' });
};