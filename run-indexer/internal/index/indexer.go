package indexer

import (
	"context"
	"time"
)

type TestRun struct {
	WorkflowUID  string
	WorkflowName string
	Namespace    string

	NodeID      string
	DisplayName string

	StartedAt  time.Time
	FinishedAt time.Time
}

type Indexer interface {
	WriteTestRuns(ctx context.Context, runs []TestRun) error
	Close(ctx context.Context) error
}
