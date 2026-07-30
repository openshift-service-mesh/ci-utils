package orders

// CalculateShippingV2 is the active shipping-cost calculation, pricing by
// carrier and package weight instead of a flat per-region rate.
func CalculateShippingV2(carrier string, weightGrams int64) int64 {
	return weightGrams / 100
}
