package logs_indexer

import (
	"context"
	"fmt"

	"github.com/vlanx/module-stresser/run-indexer/internal/index"
)

type LogsIndexer struct {
	outputLoc string
	prefix    string
	ctx       context.Context
}

func BuildIndexer(ctx context.Context, outputLoc string, prefix string) LogsIndexer {
	fmt.Printf("Built Indexer")

	li := LogsIndexer{ctx: ctx, outputLoc: outputLoc, prefix: prefix}

	return li
}

func (idxer LogsIndexer) WriteTestRuns(ctx context.Context, runs []indexer.TestRun) error {
	fmt.Printf("Output: %s", idxer.outputLoc)

	for _, run := range runs {
		fmt.Printf("Run %v", run)
	}

	return nil
}

func (idxer LogsIndexer) Close(ctx context.Context) error {
	fmt.Printf("Closing")
	return nil
}
