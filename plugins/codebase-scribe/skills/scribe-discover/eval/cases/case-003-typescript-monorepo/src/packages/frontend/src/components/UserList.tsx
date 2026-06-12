import React from "react";

export interface User {
  id: number;
  name: string;
  email: string;
}

interface UserListProps {
  users: User[];
}

export const UserList: React.FC<UserListProps> = ({ users }) => {
  if (users.length === 0) {
    return <p className="empty-state">No users found.</p>;
  }

  return (
    <ul className="user-list">
      {users.map((user) => (
        <li key={user.id} className="user-list-item">
          <span className="user-name">{user.name}</span>
          <span className="user-email">{user.email}</span>
        </li>
      ))}
    </ul>
  );
};
