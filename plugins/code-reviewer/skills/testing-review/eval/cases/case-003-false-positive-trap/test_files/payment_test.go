package payment_test

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// mockGateway implements Gateway for testing.
type mockGateway struct {
	chargeFunc     func(ctx context.Context, req ChargeRequest) (*ChargeResult, error)
	getBalanceFunc func(ctx context.Context, accountID string) (int64, error)
}

func (m *mockGateway) Charge(ctx context.Context, req ChargeRequest) (*ChargeResult, error) {
	return m.chargeFunc(ctx, req)
}

func (m *mockGateway) GetBalance(ctx context.Context, accountID string) (int64, error) {
	return m.getBalanceFunc(ctx, accountID)
}

func TestProcessPayment_Success(t *testing.T) {
	want := &ChargeResult{TransactionID: "txn-123", Status: "completed"}
	gw := &mockGateway{
		getBalanceFunc: func(_ context.Context, accountID string) (int64, error) {
			assert.Equal(t, "acct-abc", accountID)
			return 10000, nil // balance = $100
		},
		chargeFunc: func(_ context.Context, req ChargeRequest) (*ChargeResult, error) {
			assert.Equal(t, int64(5000), req.AmountCents)
			return want, nil
		},
	}
	proc := NewProcessor(gw)

	req := ChargeRequest{AccountID: "acct-abc", AmountCents: 5000, Currency: "USD"}
	got, err := proc.ProcessPayment(context.Background(), req)

	require.NoError(t, err)
	assert.Equal(t, want, got)
}

func TestProcessPayment_InsufficientFunds(t *testing.T) {
	gw := &mockGateway{
		getBalanceFunc: func(_ context.Context, _ string) (int64, error) {
			return 100, nil // balance = $1
		},
	}
	proc := NewProcessor(gw)

	req := ChargeRequest{AccountID: "acct-abc", AmountCents: 5000, Currency: "USD"}
	_, err := proc.ProcessPayment(context.Background(), req)

	require.Error(t, err)
	assert.ErrorIs(t, err, ErrInsufficientFunds)
}

func TestProcessPayment_InvalidAmount(t *testing.T) {
	proc := NewProcessor(&mockGateway{})

	tests := []struct {
		name        string
		amountCents int64
	}{
		{"zero amount", 0},
		{"negative amount", -100},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := ChargeRequest{AccountID: "acct-abc", AmountCents: tc.amountCents}
			_, err := proc.ProcessPayment(context.Background(), req)
			require.Error(t, err)
			assert.ErrorIs(t, err, ErrInvalidAmount)
		})
	}
}

func TestProcessPayment_EmptyAccountID(t *testing.T) {
	proc := NewProcessor(&mockGateway{})

	req := ChargeRequest{AccountID: "", AmountCents: 500}
	_, err := proc.ProcessPayment(context.Background(), req)

	require.Error(t, err)
	assert.ErrorIs(t, err, ErrInvalidAmount)
}

func TestProcessPayment_GatewayChargeError(t *testing.T) {
	gatewayErr := errors.New("gateway timeout")
	gw := &mockGateway{
		getBalanceFunc: func(_ context.Context, _ string) (int64, error) {
			return 99999, nil
		},
		chargeFunc: func(_ context.Context, _ ChargeRequest) (*ChargeResult, error) {
			return nil, gatewayErr
		},
	}
	proc := NewProcessor(gw)

	req := ChargeRequest{AccountID: "acct-abc", AmountCents: 500}
	_, err := proc.ProcessPayment(context.Background(), req)

	require.Error(t, err)
	assert.ErrorIs(t, err, gatewayErr)
}
