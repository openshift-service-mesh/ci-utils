package flags

// EvaluateFlagV2 is the active flag-evaluation entry point. Every current
// call site uses this function, not the deprecated EvaluateFlag.
func EvaluateFlagV2(tenantID, name string) bool {
	return lookupOverride(tenantID, name)
}

func lookupOverride(tenantID, name string) bool {
	return false
}
