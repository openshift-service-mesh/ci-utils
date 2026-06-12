import express, { Application } from "express";
import { userRouter } from "./routes/users";

const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3001;

function createApp(): Application {
  const app = express();

  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  app.get("/health", (_req, res) => {
    res.json({ status: "ok", timestamp: new Date().toISOString() });
  });

  app.use("/api/v1/users", userRouter);

  return app;
}

const app = createApp();

app.listen(PORT, () => {
  console.log(`Backend API listening on port ${PORT}`);
});

export { createApp };
