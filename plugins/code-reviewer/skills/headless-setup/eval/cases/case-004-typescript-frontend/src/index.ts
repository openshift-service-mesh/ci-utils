import express, { Application } from "express";
import { usersRouter } from "./routes/users";

const app: Application = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Mount routers.
app.use("/api/v1/users", usersRouter);

// Health check.
app.get("/healthz", (_req, res) => {
  res.json({ status: "ok" });
});

const PORT = process.env.PORT ?? 3000;

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});

export default app;
