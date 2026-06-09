import { Router, Request, Response } from "express";
import { UserService } from "../services/userService";

export const userRouter = Router();
const userService = new UserService();

userRouter.get("/", async (_req: Request, res: Response): Promise<void> => {
  const users = await userService.findAll();
  res.json({ users, total: users.length });
});

userRouter.get("/:id", async (req: Request, res: Response): Promise<void> => {
  const id = parseInt(req.params.id, 10);
  if (isNaN(id)) {
    res.status(400).json({ error: "Invalid user id" });
    return;
  }

  const user = await userService.findById(id);
  if (!user) {
    res.status(404).json({ error: "User not found" });
    return;
  }

  res.json(user);
});

userRouter.post("/", async (req: Request, res: Response): Promise<void> => {
  const { name, email } = req.body as { name?: string; email?: string };

  if (!name || !email) {
    res.status(400).json({ error: "name and email are required" });
    return;
  }

  const user = await userService.create({ name, email });
  res.status(201).json(user);
});
