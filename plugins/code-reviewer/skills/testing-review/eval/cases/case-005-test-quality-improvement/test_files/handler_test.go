package order_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

type mockStore struct {
	createFunc func(o Order) (Order, error)
	listFunc   func() ([]Order, error)
}

func (m *mockStore) Create(o Order) (Order, error) { return m.createFunc(o) }
func (m *mockStore) List() ([]Order, error)        { return m.listFunc() }

// TestCreateOrderHandler tests the happy path for creating an order.
// Quality issues present in this test:
//   1. Uses raw `if err != nil { t.Fatal(err) }` instead of require.NoError
//   2. Uses `if got.ID != "ord-1" { t.Errorf(...) }` instead of assert.Equal
//   3. Test name does not follow TestFuncName_Scenario pattern (missing _Success suffix)
func TestCreateOrderHandler(t *testing.T) {
	store := &mockStore{
		createFunc: func(o Order) (Order, error) {
			o.ID = "ord-1"
			return o, nil
		},
	}
	h := NewHandler(store)

	body, err := json.Marshal(Order{Item: "widget", Quantity: 3})
	if err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(http.MethodPost, "/orders", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()

	h.CreateOrder(rr, req)

	if rr.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d", rr.Code)
	}

	var got Order
	err = json.NewDecoder(rr.Body).Decode(&got)
	if err != nil {
		t.Fatal(err)
	}

	if got.ID != "ord-1" {
		t.Errorf("expected ID ord-1, got %s", got.ID)
	}
}

// TestListOrdersHandler tests the happy path for listing orders.
// Quality issues present in this test:
//   1. Uses raw `if err != nil { t.Fatal(err) }` instead of require.NoError
//   2. Uses `if len(got) != 1 || got[0].ID != "ord-2" { t.Errorf(...) }` instead of assert.Equal
//   3. Test name does not follow TestFuncName_Scenario pattern (missing _NonEmptyStore suffix)
func TestListOrdersHandler(t *testing.T) {
	store := &mockStore{
		listFunc: func() ([]Order, error) {
			return []Order{{ID: "ord-2", Item: "gadget", Quantity: 1}}, nil
		},
	}
	h := NewHandler(store)

	req := httptest.NewRequest(http.MethodGet, "/orders", nil)
	rr := httptest.NewRecorder()

	h.ListOrders(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}

	var got []Order
	err := json.NewDecoder(rr.Body).Decode(&got)
	if err != nil {
		t.Fatal(err)
	}

	if len(got) != 1 || got[0].ID != "ord-2" {
		t.Errorf("unexpected orders: %+v", got)
	}
}
