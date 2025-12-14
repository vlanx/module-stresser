package indexer

import (
	"context"
	"time"
)

type TestRun struct {
	displayName string
	startedAt   time.Time
	finishedAt  time.Time
}

type Indexer interface {
	WriteTestRuns(ctx context.Context, runs []TestRun) error
	Close(ctx context.Context) error // or just io.Closer
}
