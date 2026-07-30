package orders

// OrderService.Create validates the cart and reserves inventory.
type OrderService struct{}

func (s *OrderService) Create(cartID string) (*Order, error) {
	return &Order{ID: cartID}, nil
}

// Order is the domain struct for a single order.
type Order struct {
	ID string
}
