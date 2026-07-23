package report

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sync"
)

var ErrNotFound = errors.New("report not found")
var ErrInvalidState = errors.New("invalid report state")

type Item struct {
	ID             string `json:"id"`
	UserID         string `json:"user_id"`
	LevelID        string `json:"level_id"`
	Category       string `json:"category"`
	Description    string `json:"description"`
	Status         string `json:"status"`
	ResolutionNote string `json:"resolution_note,omitempty"`
}
type Service interface {
	Create(context.Context, Item) (Item, error)
	List(context.Context, string) ([]Item, error)
	Resolve(context.Context, string, string, string) error
}
type MemoryService struct {
	mu    sync.Mutex
	items map[string]Item
}

func NewMemoryService() *MemoryService { return &MemoryService{items: map[string]Item{}} }
func (s *MemoryService) Create(_ context.Context, i Item) (Item, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	i.Status = "open"
	s.items[i.ID] = i
	return i, nil
}
func (s *MemoryService) List(_ context.Context, status string) ([]Item, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := []Item{}
	for _, i := range s.items {
		if status == "" || i.Status == status {
			out = append(out, i)
		}
	}
	return out, nil
}
func (s *MemoryService) Resolve(_ context.Context, id, status, note string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	i, ok := s.items[id]
	if !ok {
		return ErrNotFound
	}
	if status != "reviewing" && status != "resolved" && status != "dismissed" {
		return ErrInvalidState
	}
	i.Status = status
	i.ResolutionNote = note
	s.items[id] = i
	return nil
}

type MySQLService struct{ db *sql.DB }

func NewMySQLService(db *sql.DB) *MySQLService { return &MySQLService{db} }
func (s *MySQLService) Create(ctx context.Context, i Item) (Item, error) {
	_, e := s.db.ExecContext(ctx, `INSERT INTO content_reports(id,user_id,level_id,category,description) VALUES(?,?,?,?,?)`, i.ID, i.UserID, i.LevelID, i.Category, i.Description)
	i.Status = "open"
	return i, e
}
func (s *MySQLService) List(ctx context.Context, status string) ([]Item, error) {
	q := `SELECT id,user_id,level_id,category,description,status,resolution_note FROM content_reports`
	args := []any{}
	if status != "" {
		q += ` WHERE status=?`
		args = append(args, status)
	}
	q += ` ORDER BY created_at DESC LIMIT 500`
	rows, e := s.db.QueryContext(ctx, q, args...)
	if e != nil {
		return nil, e
	}
	defer rows.Close()
	out := []Item{}
	for rows.Next() {
		var i Item
		if e = rows.Scan(&i.ID, &i.UserID, &i.LevelID, &i.Category, &i.Description, &i.Status, &i.ResolutionNote); e != nil {
			return nil, e
		}
		out = append(out, i)
	}
	return out, rows.Err()
}
func (s *MySQLService) Resolve(ctx context.Context, id, status, note string) error {
	if status != "reviewing" && status != "resolved" && status != "dismissed" {
		return ErrInvalidState
	}
	r, e := s.db.ExecContext(ctx, `UPDATE content_reports SET status=?,resolution_note=? WHERE id=?`, status, note, id)
	if e != nil {
		return e
	}
	n, _ := r.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

var _ = fmt.Sprintf
