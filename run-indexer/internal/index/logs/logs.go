package logs

import (
	"context"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/vlanx/module-stresser/run-indexer/internal/index"
)

type LogsIndexer struct {
	out io.Writer
}

func New(out io.Writer) *LogsIndexer {
	if out == nil {
		out = os.Stdout
	}
	return &LogsIndexer{out: out}
}

func (l LogsIndexer) WriteTestRuns(ctx context.Context, runs []indexer.TestRun) error {

	for _, run := range runs {
		if run.FinishedAt.IsZero() {
			continue
		}

		// RFC3339Nano is nice for precise timestamps in logs
		fmt.Fprintf(
			l.out,
			"run workflow=%s uid=%s node=%s name=%q started=%s & finished=%s\n",
			run.WorkflowName,
			run.WorkflowUID,
			run.NodeID,
			run.DisplayName,
			run.StartedAt.Format(time.RFC3339Nano),
			run.FinishedAt.Format(time.RFC3339Nano),
		)
	}
	return nil
}

func (idxer LogsIndexer) Close(ctx context.Context) error {
	fmt.Printf("Closing Logs...\n")
	return nil
}
