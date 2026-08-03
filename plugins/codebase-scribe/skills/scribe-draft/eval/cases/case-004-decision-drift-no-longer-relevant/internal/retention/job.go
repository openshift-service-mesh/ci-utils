package retention

import "time"

// Job is a scheduled task that purges records older than RetentionDays().
type Job struct {
	Interval time.Duration
}

func (j *Job) Run() {
	// purge logic omitted for the fixture
}
