package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"os/user"
	"path/filepath"
	"syscall"

	wfclientset "github.com/argoproj/argo-workflows/v3/pkg/client/clientset/versioned"
	"github.com/vlanx/module-stresser/run-indexer/internal/index/logs"
	"github.com/vlanx/module-stresser/run-indexer/internal/watcher"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	fmt.Println("Starting Argo Workflow runs indexer")
	config, err := loadConfig()
	if err != nil {
		log.Fatalf("Error loading config: %v", err)

	}
	namespace := "stress"

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// TODO: build indexer based on cfg
	idx := logs_indexer.BuildIndexer(ctx, "stdout", "INFO")

	// create the workflow client
	wfClient := wfclientset.NewForConfigOrDie(config)

	w := watcher.NewWorkflowWather(wfClient, idx, namespace)
	// if err != nil {
	//     log.Fatalf("watcher init error: %v", err)
	// }

	// TODO: run watcher
	w.Run(ctx)

}

func loadConfig() (*rest.Config, error) {
	// get current user to determine home directory
	usr, err := user.Current()
	if err != nil {
		log.Fatalf("Error getting user: %v", err)

	}

	// get kubeconfig file location
	kubeconfig := flag.String("kubeconfig", filepath.Join(usr.HomeDir, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	flag.Parse()

	// use the current context in kubeconfig
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)

	return config, err
}
