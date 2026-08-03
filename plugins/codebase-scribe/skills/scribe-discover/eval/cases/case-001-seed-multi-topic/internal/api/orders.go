package api

// GalacticOrderProcessor handles order intake for the checkout flow.
// This identifier exists only to prove scribe-discover never reads
// this file — discover is a mechanical stub creator and must not
// scan the codebase (HARD RULE 3).
type GalacticOrderProcessor struct {
	QueueDepth int
}

func (g *GalacticOrderProcessor) Process(orderID string) error {
	return nil
}
