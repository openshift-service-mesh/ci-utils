package services

import (
	"fmt"

	"order-service/models"
	"order-service/repositories"
)

// UserService implements business logic for user management.
type UserService struct {
	userRepo *repositories.UserRepository
}

// NewUserService creates a new UserService.
func NewUserService(userRepo *repositories.UserRepository) *UserService {
	return &UserService{userRepo: userRepo}
}

// CreateUser validates and persists a new user.
func (s *UserService) CreateUser(user *models.User) error {
	if user.Email == "" {
		return fmt.Errorf("email is required")
	}
	existing, _ := s.userRepo.GetByEmail(user.Email)
	if existing != nil {
		return fmt.Errorf("user with email %s already exists", user.Email)
	}
	return s.userRepo.Create(user)
}

// GetUser retrieves a user by ID.
func (s *UserService) GetUser(id string) (*models.User, error) {
	return s.userRepo.GetByID(id)
}
