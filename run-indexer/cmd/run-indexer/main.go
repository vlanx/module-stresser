package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/signal"
	"os/user"
	"path/filepath"
	"syscall"
	"time"

	wfclientset "github.com/argoproj/argo-workflows/v3/pkg/client/clientset/versioned"
	"github.com/vlanx/module-stresser/run-indexer/internal/index/logs"
	"github.com/vlanx/module-stresser/run-indexer/internal/watcher"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	namespace := flag.String("namespace", "stress", "namespace to watch")
	logFile := flag.String("log-file", "", "write logs to this file (default: stdout)")
	resyncPeriod := flag.Duration("resync", 30*time.Second, "informer resync period (0 disables)")
	flag.Parse()

	fmt.Printf("Starting Argo Workflow Runs Indexer | Namespace: %s \n", *namespace)
	if *logFile != "" {
		fmt.Printf("Writing to: %s\n", *logFile)
	}

	config, err := loadConfig()
	if err != nil {
		log.Fatalf("Error loading config: %v", err)

	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Assume we will write to stdout
	var out io.Writer = os.Stdout
	var closer func() error = func() error { return nil }

	// If a file is specified, we write to it
	if *logFile != "" {
		if err := os.MkdirAll(filepath.Dir(*logFile), 0o755); err != nil {
			log.Fatalf("failed to create log dir: %v", err)
		}
		f, err := os.OpenFile(*logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
		if err != nil {
			log.Fatalf("failed to open log file: %v", err)
		}
		out = f
		closer = f.Close
	}
	// TODO: build indexer based on cfg
	idx := logs.New(out)
	defer func() {
		_ = idx.Close(ctx)
		_ = closer()
	}()

	// create the workflow client
	wfClient := wfclientset.NewForConfigOrDie(config)

	w := watcher.NewWorkflowWatcher(wfClient, idx, *namespace, *resyncPeriod)

	// TODO: run watcher
	err = w.Run(ctx)
	if err != nil {
		log.Printf("watcher stopped with error: %v", err)
	}
}

func loadConfig() (*rest.Config, error) {
	// 1) In-cluster (ServiceAccount token + CA mounted into the Pod)
	if cfg, err := rest.InClusterConfig(); err == nil {
		return cfg, nil
	}

	// get current user to determine home directory
	usr, err := user.Current()
	if err != nil {
		log.Fatalf("Error getting user: %v", err)

	}

	// get kubeconfig file location
	kubeconfig := filepath.Join(usr.HomeDir, ".kube", "config") //"(optional) absolute path to the kubeconfig file"

	// use the current context in kubeconfig
	return clientcmd.BuildConfigFromFlags("", kubeconfig)
}
