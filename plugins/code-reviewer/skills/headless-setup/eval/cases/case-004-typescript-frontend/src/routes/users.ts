import { Router, Request, Response } from "express";
import {
  getUserById,
  createUser,
  UserNotFoundError,
} from "../services/userService";

export const usersRouter = Router();

/**
 * GET /api/v1/users/:id
 * Returns the user with the given numeric ID.
 */
usersRouter.get("/:id", async (req: Request, res: Response): Promise<void> => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    res.status(400).json({ error: "id must be a positive integer" });
    return;
  }

  try {
    const user = await getUserById(id);
    res.json(user);
  } catch (err) {
    if (err instanceof UserNotFoundError) {
      res.status(404).json({ error: err.message });
    } else {
      res.status(500).json({ error: "internal server error" });
    }
  }
});

/**
 * POST /api/v1/users
 * Creates a new user from a JSON body containing { name, email }.
 */
usersRouter.post("/", async (req: Request, res: Response): Promise<void> => {
  const { name, email } = req.body as { name?: string; email?: string };

  if (typeof name !== "string" || typeof email !== "string") {
    res.status(400).json({ error: "name and email are required strings" });
    return;
  }

  try {
    const user = await createUser({ name, email });
    res.status(201).json(user);
  } catch (err) {
    if (err instanceof Error) {
      res.status(400).json({ error: err.message });
    } else {
      res.status(500).json({ error: "internal server error" });
    }
  }
});
