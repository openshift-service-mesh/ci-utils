package user_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type mockRepo struct {
	findByIDFunc func(ctx context.Context, id string) (*User, error)
	saveFunc     func(ctx context.Context, u *User) error
}

func (m *mockRepo) FindByID(ctx context.Context, id string) (*User, error) {
	if m.findByIDFunc != nil {
		return m.findByIDFunc(ctx, id)
	}
	return nil, nil
}

func (m *mockRepo) Save(ctx context.Context, u *User) error {
	if m.saveFunc != nil {
		return m.saveFunc(ctx, u)
	}
	return nil
}

// TestUpdateUser_Success verifies the happy path: existing user is fetched,
// updated, and persisted with the new name and email.
func TestUpdateUser_Success(t *testing.T) {
	original := &User{ID: "u1", Name: "Alice", Email: "alice@example.com"}
	repo := &mockRepo{
		findByIDFunc: func(_ context.Context, id string) (*User, error) {
			assert.Equal(t, "u1", id)
			return original, nil
		},
		saveFunc: func(_ context.Context, u *User) error {
			assert.Equal(t, "Alice Updated", u.Name)
			assert.Equal(t, "alice2@example.com", u.Email)
			return nil
		},
	}
	svc := NewUserService(repo)

	got, err := svc.UpdateUser(context.Background(), "u1", "Alice Updated", "alice2@example.com")

	require.NoError(t, err)
	assert.Equal(t, "Alice Updated", got.Name)
	assert.Equal(t, "alice2@example.com", got.Email)
}

// NOTE: TestUpdateUser_NotFound is intentionally absent.
// The UpdateUser function documents ErrNotFound as a return value when the
// user ID does not exist, but no test exercises this path.
