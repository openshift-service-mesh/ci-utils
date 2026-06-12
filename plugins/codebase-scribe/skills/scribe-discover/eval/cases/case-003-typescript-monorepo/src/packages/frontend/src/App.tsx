import React, { useEffect, useState } from "react";
import { UserList } from "./components/UserList";

interface User {
  id: number;
  name: string;
  email: string;
}

const App: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch("/api/v1/users")
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP error: ${res.status}`);
        return res.json() as Promise<{ users: User[] }>;
      })
      .then(({ users }) => setUsers(users))
      .catch((err: Error) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div className="loading">Loading...</div>;
  if (error) return <div className="error">Error: {error}</div>;

  return (
    <div className="app">
      <header className="app-header">
        <h1>User Directory</h1>
      </header>
      <main>
        <UserList users={users} />
      </main>
    </div>
  );
};

export default App;
