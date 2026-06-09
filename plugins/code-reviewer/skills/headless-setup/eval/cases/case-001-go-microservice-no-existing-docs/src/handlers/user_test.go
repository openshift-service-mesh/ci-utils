package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func setupTestRouter() (*gin.Engine, *UserHandler) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	h := NewUserHandler()
	v1 := r.Group("/api/v1")
	{
		v1.GET("/users/:id", h.GetUser)
		v1.POST("/users", h.CreateUser)
	}
	return r, h
}

func TestGetUser_Success(t *testing.T) {
	router, handler := setupTestRouter()

	// Pre-populate the store.
	handler.users[1] = &struct {
		ID    int    `json:"id"`
		Name  string `json:"name"`
		Email string `json:"email"`
	}{ID: 1, Name: "Alice", Email: "alice@example.com"}
	// Workaround: use the models package type directly in real code.
	_ = handler

	tests := []struct {
		name       string
		userID     string
		wantStatus int
		wantName   string
	}{
		{
			name:       "existing user returns 200",
			userID:     "1",
			wantStatus: http.StatusOK,
			wantName:   "Alice",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			req, _ := http.NewRequest(http.MethodGet, "/api/v1/users/"+tc.userID, nil)
			router.ServeHTTP(w, req)

			if w.Code != tc.wantStatus {
				t.Errorf("expected status %d, got %d", tc.wantStatus, w.Code)
			}
		})
	}
}

func TestGetUser_NotFound(t *testing.T) {
	router, _ := setupTestRouter()

	tests := []struct {
		name       string
		userID     string
		wantStatus int
	}{
		{
			name:       "missing user returns 404",
			userID:     "999",
			wantStatus: http.StatusNotFound,
		},
		{
			name:       "non-numeric id returns 400",
			userID:     "abc",
			wantStatus: http.StatusBadRequest,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			req, _ := http.NewRequest(http.MethodGet, "/api/v1/users/"+tc.userID, nil)
			router.ServeHTTP(w, req)

			if w.Code != tc.wantStatus {
				t.Errorf("expected status %d, got %d", tc.wantStatus, w.Code)
			}
		})
	}
}

func TestCreateUser_Success(t *testing.T) {
	router, _ := setupTestRouter()

	body, _ := json.Marshal(map[string]string{
		"name":  "Bob",
		"email": "bob@example.com",
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodPost, "/api/v1/users", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected status 201, got %d", w.Code)
	}

	var resp map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp["name"] != "Bob" {
		t.Errorf("expected name Bob, got %v", resp["name"])
	}
}
