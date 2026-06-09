/** In-memory representation of a user. */
export interface User {
  id: number;
  name: string;
  email: string;
  createdAt: Date;
}

/** Payload required to create a new user. */
export interface CreateUserInput {
  name: string;
  email: string;
}

/** Raised when a user cannot be found by the given ID. */
export class UserNotFoundError extends Error {
  constructor(id: number) {
    super(`User with id ${id} not found`);
    this.name = "UserNotFoundError";
  }
}

/** Simple in-memory user store. Replace with a DB client in production. */
const store = new Map<number, User>();
let nextId = 1;

/**
 * Retrieve a user by their numeric ID.
 *
 * @throws {UserNotFoundError} if no user exists with that ID.
 */
export async function getUserById(id: number): Promise<User> {
  const user = store.get(id);
  if (!user) {
    throw new UserNotFoundError(id);
  }
  return user;
}

/**
 * Persist a new user and return the created record.
 *
 * @throws {Error} if name or email is blank.
 */
export async function createUser(input: CreateUserInput): Promise<User> {
  if (!input.name.trim()) {
    throw new Error("name must not be empty");
  }
  if (!input.email.trim()) {
    throw new Error("email must not be empty");
  }

  const user: User = {
    id: nextId++,
    name: input.name.trim(),
    email: input.email.trim(),
    createdAt: new Date(),
  };

  store.set(user.id, user);
  return user;
}

/** Remove all users — intended for use in tests only. */
export function _resetStore(): void {
  store.clear();
  nextId = 1;
}
