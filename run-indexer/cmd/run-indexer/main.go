package main

import (
	"context"
	"flag"
	"fmt"
	// wfv1 "github.com/argoproj/argo-workflows/v3/pkg/apis/workflow/v1alpha1"
	wfclientset "github.com/argoproj/argo-workflows/v3/pkg/client/clientset/versioned"
	// "github.com/argoproj/argo-workflows/v3/util/errors"
	"github.com/vlanx/module-stresser/run-indexer/internal/watcher"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	// "k8s.io/apimachinery/pkg/fields"
	"k8s.io/client-go/tools/clientcmd"
	// "k8s.io/utils/ptr"
	"os/user"
	"path/filepath"
)

func main() {
	fmt.Println("Starting Argo Workflow runs indexer")
	watcher.Start()
	// get current user to determine home directory
	usr, err := user.Current()
	checkErr(err)

	// get kubeconfig file location
	kubeconfig := flag.String("kubeconfig", filepath.Join(usr.HomeDir, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	flag.Parse()

	// use the current context in kubeconfig
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	checkErr(err)
	namespace := "stress"

	// create the workflow client
	wfClient := wfclientset.NewForConfigOrDie(config).ArgoprojV1alpha1().Workflows(namespace)
	ctx := context.Background()
	list, err := wfClient.List(ctx, metav1.ListOptions{})
	checkErr(err)
	for _, wf := range list.Items {
		fmt.Printf("Workflows Name: %v\n", wf.GetName())
		nodes := wf.Status.Nodes

		for idx := range nodes {
			if nodes[idx].Type == "Pod" {
				fmt.Printf("Workflow Node %s, started at %s\n", nodes[idx].DisplayName, nodes[idx].StartedAt)

				if !nodes[idx].FinishedAt.Time.IsZero() {
					fmt.Printf("Workflow Node %s, finished at %s\n", nodes[idx].DisplayName, nodes[idx].FinishedAt)
				} else {
					fmt.Printf("Workflow Node %s, Hasn't finished yet\n", nodes[idx].DisplayName)
				}
			}
		}
	}

	// // wait for the workflow to complete
	// fieldSelector := fields.ParseSelectorOrDie(fmt.Sprintf("metadata.name=%s", "cpu-24worker"))
	// watchIf, err := wfClient.Watch(ctx, metav1.ListOptions{FieldSelector: fieldSelector.String(), TimeoutSeconds: ptr.To(int64(180))})
	// errors.CheckError(err)
	// defer watchIf.Stop()
	// for next := range watchIf.ResultChan() {
	// 	wf, ok := next.Object.(*wfv1.Workflow)
	// 	if !ok {
	// 		continue
	// 	}
	// 	if !wf.Status.FinishedAt.IsZero() {
	// 		fmt.Printf("Workflow %s %s at %v. Message: %s.\n", wf.Name, wf.Status.Phase, wf.Status.FinishedAt, wf.Status.Message)
	// 		break
	// 	}
	// }
}

func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}
