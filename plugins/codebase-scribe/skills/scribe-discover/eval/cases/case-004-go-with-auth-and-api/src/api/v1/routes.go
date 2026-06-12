package apiv1

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/authservice/auth"
)

// RegisterRoutes attaches all v1 API routes to the given router.
func RegisterRoutes(router *gin.Engine, tm *auth.TokenManager) {
	v1 := router.Group("/api/v1")

	// Public endpoints
	router.POST("/api/v1/auth/login", loginHandler(tm))

	// Protected endpoints
	protected := v1.Group("")
	protected.Use(tm.RequireAuth())
	{
		protected.GET("/users", listUsersHandler())
		protected.POST("/api/v1/users", createUserHandler())
		protected.GET("/users/:id", getUserHandler())
	}
}

func loginHandler(tm *auth.TokenManager) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			Username string `json:"username" binding:"required"`
			Password string `json:"password" binding:"required"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// NOTE: replace with real credential check
		if body.Username != "admin" || body.Password != "secret" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
			return
		}

		token, err := tm.Sign(body.Username, "admin", 0)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "could not issue token"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"token": token})
	}
}

func listUsersHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"users": []any{}})
	}
}

func createUserHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusCreated, gin.H{"id": "new-id"})
	}
}

func getUserHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"id": c.Param("id")})
	}
}
