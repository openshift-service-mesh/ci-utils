export interface User {
  id: number;
  name: string;
  email: string;
  createdAt: string;
}

export interface CreateUserDto {
  name: string;
  email: string;
}

export class UserService {
  private users: Map<number, User> = new Map();
  private counter = 0;

  async findAll(): Promise<User[]> {
    return Array.from(this.users.values());
  }

  async findById(id: number): Promise<User | null> {
    return this.users.get(id) ?? null;
  }

  async create(dto: CreateUserDto): Promise<User> {
    this.counter += 1;
    const user: User = {
      id: this.counter,
      name: dto.name,
      email: dto.email,
      createdAt: new Date().toISOString(),
    };
    this.users.set(user.id, user);
    return user;
  }
}
