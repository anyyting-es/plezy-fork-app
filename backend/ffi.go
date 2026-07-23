// +build library

package main

import "C"

//export StartServer
func StartServer(downloadDirC *C.char) C.int {
	var downloadDir string
	if downloadDirC != nil {
		downloadDir = C.GoString(downloadDirC)
	}
	return C.int(coreStartServer(downloadDir))
}

//export StopServer
func StopServer() {
	coreStopServer()
}

// En este modo no necesitamos main(), pero Go lo requiere para c-shared
func main() {}
