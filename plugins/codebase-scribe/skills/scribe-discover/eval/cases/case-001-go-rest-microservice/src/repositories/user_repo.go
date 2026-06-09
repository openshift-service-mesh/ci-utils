package repositories

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/example/userservice/models"
)

// UserRepository defines the interface for user data access.
type UserRepository interface {
	FindByID(ctx context.Context, id int64) (*models.User, error)
	FindAll(ctx context.Context) ([]*models.User, error)
	Create(ctx context.Context, req models.CreateUserRequest) (*models.User, error)
}

// inMemoryUserRepository is an in-memory implementation of UserRepository.
type inMemoryUserRepository struct {
	mu      sync.RWMutex
	users   map[int64]*models.User
	counter int64
}

// NewUserRepository creates a new in-memory UserRepository.
func NewUserRepository() UserRepository {
	return &inMemoryUserRepository{
		users: make(map[int64]*models.User),
	}
}

// FindByID retrieves a user by their ID.
func (r *inMemoryUserRepository) FindByID(_ context.Context, id int64) (*models.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	user, ok := r.users[id]
	if !ok {
		return nil, errors.New("user not found")
	}
	return user, nil
}

// FindAll returns all users in the store.
func (r *inMemoryUserRepository) FindAll(_ context.Context) ([]*models.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	users := make([]*models.User, 0, len(r.users))
	for _, u := range r.users {
		users = append(users, u)
	}
	return users, nil
}

// Create persists a new user and returns it with an assigned ID.
func (r *inMemoryUserRepository) Create(_ context.Context, req models.CreateUserRequest) (*models.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.counter++
	now := time.Now().UTC()
	user := &models.User{
		ID:        r.counter,
		Name:      req.Name,
		Email:     req.Email,
		CreatedAt: now,
		UpdatedAt: now,
	}
	r.users[user.ID] = user
	return user, nil
}
