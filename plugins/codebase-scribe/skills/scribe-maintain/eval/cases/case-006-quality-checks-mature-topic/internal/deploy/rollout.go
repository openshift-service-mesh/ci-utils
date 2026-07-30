package deploy

// RolloutManager stages a new version behind a feature gate before
// promoting it to all traffic.
type RolloutManager struct {
	gate string
}

func (r *RolloutManager) Promote(version string) error {
	return nil
}
