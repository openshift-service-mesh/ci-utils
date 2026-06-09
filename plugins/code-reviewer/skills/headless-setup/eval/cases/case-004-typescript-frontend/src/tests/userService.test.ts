import {
  getUserById,
  createUser,
  UserNotFoundError,
  _resetStore,
} from "../services/userService";

beforeEach(() => {
  _resetStore();
});

describe("getUserById", () => {
  it("returns the user when it exists", async () => {
    const created = await createUser({ name: "Alice", email: "alice@example.com" });
    const fetched = await getUserById(created.id);

    expect(fetched).toEqual(created);
    expect(fetched.name).toBe("Alice");
  });

  it("throws UserNotFoundError for an unknown id", async () => {
    await expect(getUserById(999)).rejects.toThrow(UserNotFoundError);
    await expect(getUserById(999)).rejects.toThrow("User with id 999 not found");
  });
});

describe("createUser", () => {
  it("creates a user and assigns an auto-incrementing id", async () => {
    const first = await createUser({ name: "Bob", email: "bob@example.com" });
    const second = await createUser({ name: "Carol", email: "carol@example.com" });

    expect(first.id).toBe(1);
    expect(second.id).toBe(2);
  });

  it("trims leading and trailing whitespace from inputs", async () => {
    const user = await createUser({ name: "  Dave  ", email: "  dave@example.com  " });

    expect(user.name).toBe("Dave");
    expect(user.email).toBe("dave@example.com");
  });

  it("throws when name is blank", async () => {
    await expect(createUser({ name: "   ", email: "x@example.com" })).rejects.toThrow(
      "name must not be empty"
    );
  });

  it("throws when email is blank", async () => {
    await expect(createUser({ name: "Eve", email: "" })).rejects.toThrow(
      "email must not be empty"
    );
  });

  it("sets createdAt to the current date", async () => {
    const before = new Date();
    const user = await createUser({ name: "Frank", email: "frank@example.com" });
    const after = new Date();

    expect(user.createdAt.getTime()).toBeGreaterThanOrEqual(before.getTime());
    expect(user.createdAt.getTime()).toBeLessThanOrEqual(after.getTime());
  });
});
