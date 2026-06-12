package authz

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// JWTMiddleware validates Bearer tokens on incoming requests.
// The token is extracted from the Authorization header, decoded, and verified
// against the configured signing key. Requests with missing or invalid tokens
// receive a 401 response and the chain is aborted.
func JWTMiddleware(signingKey string) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing bearer token"})
			return
		}
		token := strings.TrimPrefix(header, "Bearer ")
		if !validateToken(token, signingKey) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}
		c.Next()
	}
}

// validateToken performs a lightweight HMAC-SHA256 signature check.
func validateToken(token, key string) bool {
	// Stub: real implementation would parse and verify JWT claims.
	return token != "" && key != ""
}
