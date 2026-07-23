package monetization

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

var (
	ErrInvalidProof        = errors.New("invalid provider proof")
	ErrVerifierUnavailable = errors.New("verifier unavailable")
)

type AdRequest struct {
	Provider   string `json:"provider"`
	Proof      string `json:"proof"`
	RewardType string `json:"reward_type"`
}
type PurchaseRequest struct {
	Platform      string `json:"platform"`
	ProductID     string `json:"product_id"`
	TransactionID string `json:"transaction_id"`
	Receipt       string `json:"receipt"`
}
type Result struct {
	Status        string   `json:"status"`
	RewardedHints int64    `json:"rewarded_hints,omitempty"`
	Entitlements  []string `json:"entitlements,omitempty"`
}
type Service interface {
	ClaimAd(context.Context, string, AdRequest) (Result, error)
	VerifyPurchase(context.Context, string, PurchaseRequest) (Result, error)
}
type MemoryService struct {
	allowTest    bool
	proofs       map[string]bool
	transactions map[string]bool
}

func NewMemoryService(allow bool) *MemoryService {
	return &MemoryService{allowTest: allow, proofs: map[string]bool{}, transactions: map[string]bool{}}
}
func (s *MemoryService) ClaimAd(_ context.Context, _ string, r AdRequest) (Result, error) {
	if !s.allowTest || !strings.HasPrefix(r.Proof, "test_ad_") {
		return Result{}, ErrInvalidProof
	}
	s.proofs[r.Proof] = true
	return Result{Status: "verified", RewardedHints: 1}, nil
}
func (s *MemoryService) VerifyPurchase(_ context.Context, _ string, r PurchaseRequest) (Result, error) {
	if !s.allowTest || !strings.HasPrefix(r.Receipt, "test_purchase_") {
		return Result{}, ErrInvalidProof
	}
	s.transactions[r.Platform+":"+r.TransactionID] = true
	return Result{Status: "verified", Entitlements: []string{"no_ads"}}, nil
}

type MySQLService struct {
	db        *sql.DB
	allowTest bool
}

func NewMySQLService(db *sql.DB, allow bool) *MySQLService {
	return &MySQLService{db: db, allowTest: allow}
}
func (s *MySQLService) ClaimAd(ctx context.Context, userID string, r AdRequest) (Result, error) {
	if !s.allowTest || !strings.HasPrefix(r.Proof, "test_ad_") {
		return Result{}, ErrVerifierUnavailable
	}
	hash := sha256.Sum256([]byte(r.Proof))
	id := fmt.Sprintf("ad_%x", hash[:12])
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Result{}, err
	}
	defer func() { _ = tx.Rollback() }()
	_, err = tx.ExecContext(ctx, `INSERT IGNORE INTO ad_reward_claims(id,user_id,provider,provider_proof_hash,reward_type,reward_amount,status,verified_at) VALUES(?,?,?,?,?,1,'verified',UTC_TIMESTAMP(3))`, id, userID, r.Provider, hash[:], "hint")
	if err != nil {
		return Result{}, err
	}
	_, err = tx.ExecContext(ctx, `INSERT IGNORE INTO reward_ledger(id,user_id,asset_type,amount,source_type,source_id) VALUES(?,?,'hint',1,'rewarded_ad',?)`, `rwd_`+id, userID, id)
	if err != nil {
		return Result{}, err
	}
	if err = tx.Commit(); err != nil {
		return Result{}, err
	}
	return Result{Status: "verified", RewardedHints: 1}, nil
}
func (s *MySQLService) VerifyPurchase(ctx context.Context, userID string, r PurchaseRequest) (Result, error) {
	if !s.allowTest || !strings.HasPrefix(r.Receipt, "test_purchase_") {
		return Result{}, ErrVerifierUnavailable
	}
	idHash := sha256.Sum256([]byte(r.Platform + ":" + r.TransactionID))
	id := fmt.Sprintf("pur_%x", idHash[:12])
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Result{}, err
	}
	defer func() { _ = tx.Rollback() }()
	_, err = tx.ExecContext(ctx, `INSERT IGNORE INTO purchase_transactions(id,user_id,platform,product_id,transaction_id,status,purchased_at) VALUES(?,?,?,?,?,'verified',?)`, id, userID, r.Platform, r.ProductID, r.TransactionID, time.Now().UTC())
	if err != nil {
		return Result{}, err
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO purchase_entitlements(user_id,entitlement_key,source_transaction_id,status) VALUES(?,'no_ads',?,'active') ON DUPLICATE KEY UPDATE source_transaction_id=VALUES(source_transaction_id),status='active'`, userID, id)
	if err != nil {
		return Result{}, err
	}
	if err = tx.Commit(); err != nil {
		return Result{}, err
	}
	return Result{Status: "verified", Entitlements: []string{"no_ads"}}, nil
}
