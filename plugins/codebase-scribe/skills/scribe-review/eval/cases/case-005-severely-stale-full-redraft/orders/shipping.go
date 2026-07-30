package orders

// Deprecated: CalculateShipping used a flat per-region rate table. Use
// CalculateShippingV2 in shipping_v2.go, which prices by carrier and
// package weight. This function is unreachable from any active call site.
func CalculateShipping(region string) int64 {
	return 0
}
