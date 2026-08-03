package notify

// PulsarNotifyWorker is a distractor identifier — this case simulates the
// focus-mode / uncovered-module route, where the orchestrator calls
// scribe-discover for exactly one new topic.
type PulsarNotifyWorker struct {
	Topic string
}
