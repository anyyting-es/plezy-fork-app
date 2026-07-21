package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"strconv"
	"syscall"
)

func main() {
	// Resolve download directory from arg or env
	downloadDir := ""
	if len(os.Args) > 1 {
		downloadDir = os.Args[1]
	}
	if downloadDir == "" {
		downloadDir = os.Getenv("ANITING_DOWNLOAD_DIR")
	}

	// Resolve port from env (default handled inside engine.go)
	portStr := os.Getenv("ANITING_PORT")
	port := 0
	if portStr != "" {
		p, err := strconv.Atoi(portStr)
		if err == nil {
			port = p
		}
	}

	actualPort := coreStartServer(downloadDir, port)
	if actualPort <= 0 {
		log.Fatal("Failed to start torrent server")
	}

	fmt.Printf("ANITING_BACKEND_PORT=%d\n", actualPort)
	fmt.Printf("Aniting torrent backend running on http://127.0.0.1:%d\n", actualPort)

	// Wait for SIGINT or SIGTERM
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down...")
	coreStopServer()
}
