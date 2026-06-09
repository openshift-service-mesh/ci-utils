package user_test

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type mockRepo struct {
	findByIDFunc func(ctx context.Context, id string) (*User, error)
	saveFunc     func(ctx context.Context, u *User) error
}

func (m *mockRepo) FindByID(ctx context.Context, id string) (*User, error) {
	return m.findByIDFunc(ctx, id)
}

func (m *mockRepo) Save(ctx context.Context, u *User) error {
	return m.saveFunc(ctx, u)
}

func TestGetUser_Success(t *testing.T) {
	want := &User{ID: "abc", Name: "Alice", Email: "alice@example.com"}
	repo := &mockRepo{
		findByIDFunc: func(_ context.Context, id string) (*User, error) {
			assert.Equal(t, "abc", id)
			return want, nil
		},
	}
	svc := NewUserService(repo)

	got, err := svc.GetUser(context.Background(), "abc")

	require.NoError(t, err)
	assert.Equal(t, want, got)
}

func TestGetUser_NotFound(t *testing.T) {
	repo := &mockRepo{
		findByIDFunc: func(_ context.Context, _ string) (*User, error) {
			return nil, nil
		},
	}
	svc := NewUserService(repo)

	_, err := svc.GetUser(context.Background(), "missing-id")

	require.Error(t, err)
	assert.ErrorIs(t, err, ErrNotFound)
}

func TestGetUser_EmptyID(t *testing.T) {
	repo := &mockRepo{}
	svc := NewUserService(repo)

	_, err := svc.GetUser(context.Background(), "")

	require.Error(t, err)
	assert.ErrorIs(t, err, ErrInvalidInput)
}

func TestCreateUser_Success(t *testing.T) {
	saved := false
	repo := &mockRepo{
		saveFunc: func(_ context.Context, u *User) error {
			saved = true
			assert.Equal(t, "bob@example.com", u.Email)
			return nil
		},
	}
	svc := NewUserService(repo)

	err := svc.CreateUser(context.Background(), &User{Name: "Bob", Email: "bob@example.com"})

	require.NoError(t, err)
	assert.True(t, saved, "expected repo.Save to be called")
}

func TestCreateUser_InvalidInput(t *testing.T) {
	repo := &mockRepo{}
	svc := NewUserService(repo)

	tests := []struct {
		name string
		user *User
	}{
		{"nil user", nil},
		{"empty email", &User{Name: "Bob", Email: ""}},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			err := svc.CreateUser(context.Background(), tc.user)
			require.Error(t, err)
			assert.ErrorIs(t, err, ErrInvalidInput)
		})
	}
}

// Ensure ErrNotFound and ErrInvalidInput are distinct sentinel errors.
func TestSentinelErrors_AreDistinct(t *testing.T) {
	assert.False(t, errors.Is(ErrNotFound, ErrInvalidInput))
	assert.False(t, errors.Is(ErrInvalidInput, ErrNotFound))
}
