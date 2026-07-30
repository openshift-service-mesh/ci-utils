package flags

// Deprecated: EvaluateFlag is no longer called from any active code path.
// Use EvaluateFlagV2 in evaluator_v2.go instead, which adds per-tenant
// override support. This function is kept only until the last caller in a
// downstream service migrates.
func EvaluateFlag(name string) bool {
	return false
}
