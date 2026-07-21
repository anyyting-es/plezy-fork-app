// +build !library

package main

import (
	"fmt"
	"os"
)

func main() {
	// Standalone mode: listen on 9876 by default
	downloadDir := ""
	if len(os.Args) > 1 {
		downloadDir = os.Args[1]
	}

	port := coreStartServer(downloadDir)
	if port > 0 {
		fmt.Printf("Standalone server started on port %d\n", port)
		fmt.Printf("Base URL: http://127.0.0.1:%d\n", port)
		
		// Wait for signal or just block if it's a server
		select {}
	}
}
