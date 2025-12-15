package watcher

import (
	"context"
	"fmt"
	"sync"
	"time"

	wfv1 "github.com/argoproj/argo-workflows/v3/pkg/apis/workflow/v1alpha1"
	wfclientset "github.com/argoproj/argo-workflows/v3/pkg/client/clientset/versioned"
	"github.com/argoproj/argo-workflows/v3/pkg/client/informers/externalversions"
	"github.com/vlanx/module-stresser/run-indexer/internal/index"
	"k8s.io/client-go/tools/cache"
)

type runKey struct {
	workflowUID string
	nodeID      string
}

// seenCompleted dedups completed pod nodes.
// - completed: keys we successfully indexed
// - inflight: keys we decided to index but haven't successfully written yet
type seenCompleted struct {
	mu        sync.Mutex
	completed map[runKey]time.Time
	inflight  map[runKey]time.Time
}

func newSeenCompleted() *seenCompleted {
	return &seenCompleted{
		completed: make(map[runKey]time.Time),
		inflight:  make(map[runKey]time.Time),
	}
}

// stage returns true if this (key, finishedAt) should be emitted now.
// It also records it as inflight to prevent concurrent duplicate writes.
func (s *seenCompleted) stage(key runKey, finishedAt time.Time) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if prev, ok := s.completed[key]; ok && prev.Equal(finishedAt) {
		return false
	}
	if prev, ok := s.inflight[key]; ok && prev.Equal(finishedAt) {
		return false
	}

	s.inflight[key] = finishedAt
	return true
}

func (s *seenCompleted) commit(keys []runKey) {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, k := range keys {
		if ts, ok := s.inflight[k]; ok {
			s.completed[k] = ts
			delete(s.inflight, k)
		}
	}
}

func (s *seenCompleted) fail(keys []runKey) {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, k := range keys {
		delete(s.inflight, k)
	}
}

func (s *seenCompleted) forgetWorkflow(workflowUID string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	for k := range s.completed {
		if k.workflowUID == workflowUID {
			delete(s.completed, k)
		}
	}
	for k := range s.inflight {
		if k.workflowUID == workflowUID {
			delete(s.inflight, k)
		}
	}
}

type WorkflowWatcher struct {
	factory      externalversions.SharedInformerFactory
	informer     cache.SharedIndexInformer
	namespace    string
	indexer      indexer.Indexer
	seen         *seenCompleted
	resyncPeriod time.Duration
}

func NewWorkflowWatcher(client wfclientset.Interface, idx indexer.Indexer, namespace string, resyncPeriod time.Duration) *WorkflowWatcher {
	fmt.Println("Creating the Watcher...")
	factory := externalversions.NewSharedInformerFactoryWithOptions(
		client,
		resyncPeriod, // resync (0 = only real events)
		externalversions.WithNamespace(namespace),
	)

	informer := factory.Argoproj().V1alpha1().Workflows().Informer()

	w := &WorkflowWatcher{
		factory:      factory,
		informer:     informer,
		indexer:      idx,
		namespace:    namespace,
		resyncPeriod: resyncPeriod,
		seen:         newSeenCompleted(),
	}

	return w
}

func (w *WorkflowWatcher) Run(ctx context.Context) error {
	fmt.Println("Workflow Watcher Running...")
	stopCh := ctx.Done()

	w.informer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc:    func(obj interface{}) { w.onWorkflow(obj, ctx, "ADDED") },
		UpdateFunc: func(_, newObj interface{}) { w.onWorkflow(newObj, ctx, "UPDATED") },
		DeleteFunc: w.onDelete,
	})

	w.factory.Start(stopCh)

	if ok := cache.WaitForCacheSync(stopCh, w.informer.HasSynced); !ok {
		return fmt.Errorf("failed to sync informer cache")
	}

	<-stopCh
	return nil
}

func (w *WorkflowWatcher) onWorkflow(obj interface{}, ctx context.Context, event string) {
	wf, ok := obj.(*wfv1.Workflow)
	if !ok {
		return
	}

	wfUID := string(wf.UID)

	runs := make([]indexer.TestRun, 0, 4)
	keys := make([]runKey, 0, 4)

	for _, node := range wf.Status.Nodes {
		// Prefer the constant if you want, but string is fine:
		// if node.Type != wfv1.NodeTypePod { continue }
		if node.Type != "Pod" {
			continue
		}
		if node.FinishedAt.IsZero() {
			continue // only index on completion
		}

		nodeID := node.ID
		if nodeID == "" {
			nodeID = node.Name // defensive fallback
		}

		k := runKey{workflowUID: wfUID, nodeID: nodeID}
		finished := node.FinishedAt.Time

		if !w.seen.stage(k, finished) {
			continue
		}

		keys = append(keys, k)
		runs = append(runs, indexer.TestRun{
			WorkflowUID:  wfUID,
			WorkflowName: wf.Name,
			Namespace:    wf.Namespace,
			NodeID:       nodeID,
			DisplayName:  node.DisplayName,
			StartedAt:    node.StartedAt.Time,
			FinishedAt:   finished,
		})
	}

	if len(runs) == 0 {
		return
	}

	//Write
	err := w.indexer.WriteTestRuns(ctx, runs)
	if err != nil {
		w.seen.fail(keys)
		fmt.Printf("indexer error wf=%s uid=%s event=%s err=%v\n", wf.Name, wfUID, event, err)
		return
	}

	w.seen.commit(keys)
}

func (w *WorkflowWatcher) onDelete(obj interface{}) {
	if tomb, ok := obj.(cache.DeletedFinalStateUnknown); ok {
		obj = tomb.Obj
	}
	wf, ok := obj.(*wfv1.Workflow)
	if !ok || wf == nil {
		return
	}

	w.seen.forgetWorkflow(string(wf.UID))
	fmt.Printf("[DELETED] wf=%s uid=%s\n", wf.Name, string(wf.UID))
}
