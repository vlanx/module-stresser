package watcher

import (
	"context"
	"fmt"

	wfv1 "github.com/argoproj/argo-workflows/v3/pkg/apis/workflow/v1alpha1"
	wfclientset "github.com/argoproj/argo-workflows/v3/pkg/client/clientset/versioned"
	"github.com/argoproj/argo-workflows/v3/pkg/client/informers/externalversions"
	"github.com/vlanx/module-stresser/run-indexer/internal/index/logs"
	"k8s.io/client-go/tools/cache"
)

type WorkflowWatcher struct {
	factory   externalversions.SharedInformerFactory
	informer  cache.SharedIndexInformer
	namespace string
	indexer   logs_indexer.LogsIndexer
}

func NewWorkflowWather(client wfclientset.Interface, idx logs_indexer.LogsIndexer, namespace string) *WorkflowWatcher {
	fmt.Println("Starting the Watcher")
	factory := externalversions.NewSharedInformerFactoryWithOptions(
		client,
		0, // resync (0 = only real events)
		externalversions.WithNamespace(namespace),
	)

	informer := factory.Argoproj().V1alpha1().Workflows().Informer()

	w := &WorkflowWatcher{
		factory:  factory,
		informer: informer,
		indexer:  idx,
	}

	informer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc:    func(obj interface{}) { w.onWorkflow(obj, "ADDED") },
		UpdateFunc: func(_, newObj interface{}) { w.onWorkflow(newObj, "UPDATED") },
		DeleteFunc: w.onDelete,
	})

	return w
}
func (w *WorkflowWatcher) Run(ctx context.Context) error {
	stopCh := ctx.Done()
	w.factory.Start(stopCh)

	if ok := cache.WaitForCacheSync(stopCh, w.informer.HasSynced); !ok {
		return fmt.Errorf("failed to sync informer cache")
	}

	<-stopCh
	return ctx.Err()
}

func (w *WorkflowWatcher) onWorkflow(obj interface{}, event string) {
	wf, ok := obj.(*wfv1.Workflow)
	if !ok {
		return
	}

	// For now: print directly or map to TestRun and call w.idx.WriteTestRuns(...)
	for _, node := range wf.Status.Nodes {
		if node.Type != "Pod" {
			continue
		}
		fmt.Printf("[%s] wf=%s node=%s started=%s finished=%s\n",
			event, wf.Name, node.DisplayName, node.StartedAt, node.FinishedAt)
	}
}

func (w *WorkflowWatcher) onDelete(obj interface{}) {
	// handle DeletedFinalStateUnknown
	if tomb, ok := obj.(cache.DeletedFinalStateUnknown); ok {
		obj = tomb.Obj
	}
	if wf, ok := obj.(*wfv1.Workflow); ok {
		fmt.Printf("[DELETED] wf=%s\n", wf.Name)
	}
}
