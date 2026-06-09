package services

import "fmt"

// NotificationService sends notifications to users via email and push.
// It is consumed by AdminHandler for broadcast operations.
type NotificationService struct{}

// NewNotificationService creates a new NotificationService.
func NewNotificationService() *NotificationService {
	return &NotificationService{}
}

// Broadcast sends a message to all active users.
func (s *NotificationService) Broadcast(subject, body string) error {
	fmt.Printf("broadcasting notification: %s\n", subject)
	return nil
}

// SendToUser sends a targeted notification to a single user.
func (s *NotificationService) SendToUser(userID, subject, body string) error {
	fmt.Printf("sending notification to user %s: %s\n", userID, subject)
	return nil
}
