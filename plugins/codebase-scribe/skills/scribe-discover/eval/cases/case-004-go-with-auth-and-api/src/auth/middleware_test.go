package auth_test

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/example/authservice/auth"
)

func TestTokenManagerSignAndValidate(t *testing.T) {
	secret := []byte("test-secret-key")
	tm := auth.NewTokenManager(secret)

	token, err := tm.Sign("user-123", "admin", time.Hour)
	if err != nil {
		t.Fatalf("Sign() error = %v", err)
	}

	claims, err := tm.Validate(token)
	if err != nil {
		t.Fatalf("Validate() error = %v", err)
	}

	if claims.UserID != "user-123" {
		t.Errorf("got UserID = %q, want %q", claims.UserID, "user-123")
	}
	if claims.Role != "admin" {
		t.Errorf("got Role = %q, want %q", claims.Role, "admin")
	}
}

func TestRequireAuthMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)
	secret := []byte("test-secret-key")
	tm := auth.NewTokenManager(secret)

	router := gin.New()
	router.GET("/protected", tm.RequireAuth(), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	t.Run("missing header returns 401", func(t *testing.T) {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
		router.ServeHTTP(w, req)
		if w.Code != http.StatusUnauthorized {
			t.Errorf("expected 401, got %d", w.Code)
		}
	})

	t.Run("valid token returns 200", func(t *testing.T) {
		tok, _ := tm.Sign("user-456", "viewer", time.Hour)
		w := httptest.NewRecorder()
		req, _ := http.NewRequest(http.MethodGet, "/protected", nil)
		req.Header.Set("Authorization", "Bearer "+tok)
		router.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Errorf("expected 200, got %d", w.Code)
		}
	})
}
