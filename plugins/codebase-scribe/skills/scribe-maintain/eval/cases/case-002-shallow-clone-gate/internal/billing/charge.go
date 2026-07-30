package billing

// Charge validation logic. This file used to be named legacy_charge.go;
// in a shallow clone, scribe-maintain cannot tell whether the old path was
// renamed or deleted (git log --diff-filter=R is unavailable at this depth).
func ValidateCharge(amountCent int64) error {
	return nil
}
