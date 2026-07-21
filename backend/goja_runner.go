package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/dop251/goja"
)

type ExtensionInfo struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Filename string `json:"filename"`
}

type ExtensionManager struct {
	extensions map[string]string // ID -> script content
	programs   map[string]*goja.Program
	mu         sync.RWMutex
}

var extManager *ExtensionManager

func initExtensionManager() {
	extManager = &ExtensionManager{
		extensions: make(map[string]string),
		programs:   make(map[string]*goja.Program),
	}
	extManager.LoadExtensions()
}

func (em *ExtensionManager) LoadExtensions() {
	em.mu.Lock()
	defer em.mu.Unlock()

	// Clear existing
	em.extensions = make(map[string]string)
	em.programs = make(map[string]*goja.Program)

	dirs := []string{}
	// Local workspace folder
	dirs = append(dirs, "extensions")

	// Global config folder
	home, err := os.UserHomeDir()
	if err == nil {
		dirs = append(dirs, filepath.Join(home, ".aniting", "extensions"))
	}

	for _, dir := range dirs {
		_ = os.MkdirAll(dir, 0755)
		files, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, file := range files {
			if !file.IsDir() && strings.HasSuffix(file.Name(), ".js") {
				path := filepath.Join(dir, file.Name())
				contentBytes, err := os.ReadFile(path)
				if err != nil {
					log.Printf("[extensions] Failed to read %s: %v", path, err)
					continue
				}
				content := string(contentBytes)
				id := strings.TrimSuffix(file.Name(), ".js")

				// Compile script to verify syntax and cache program
				prog, err := goja.Compile(file.Name(), content, false)
				if err != nil {
					log.Printf("[extensions] Failed to compile %s: %v", path, err)
					continue
				}

				em.extensions[id] = content
				em.programs[id] = prog
				log.Printf("[extensions] Loaded extension %q", id)
			}
		}
	}
}

func (em *ExtensionManager) List() []ExtensionInfo {
	em.mu.RLock()
	defer em.mu.RUnlock()

	list := make([]ExtensionInfo, 0, len(em.extensions))
	for id := range em.extensions {
		list = append(list, ExtensionInfo{
			ID:       id,
			Name:     strings.Title(id),
			Filename: id + ".js",
		})
	}
	return list
}

func (em *ExtensionManager) getVM(id string) (*goja.Runtime, goja.Value, error) {
	em.mu.RLock()
	prog, ok := em.programs[id]
	em.mu.RUnlock()

	if !ok {
		return nil, nil, fmt.Errorf("extension %q not found", id)
	}

	vm := goja.New()

	// Expose console
	console := vm.NewObject()
	console.Set("log", func(call goja.FunctionCall) goja.Value {
		args := make([]interface{}, len(call.Arguments))
		for i, arg := range call.Arguments {
			args[i] = arg.Export()
		}
		log.Printf("[JS:%s] %s", id, fmt.Sprint(args...))
		return goja.Undefined()
	})
	console.Set("error", func(call goja.FunctionCall) goja.Value {
		args := make([]interface{}, len(call.Arguments))
		for i, arg := range call.Arguments {
			args[i] = arg.Export()
		}
		log.Printf("[JS:%s ERROR] %s", id, fmt.Sprint(args...))
		return goja.Undefined()
	})
	_ = vm.Set("console", console)

	// Expose fetch
	_ = vm.Set("fetch", func(call goja.FunctionCall) goja.Value {
		return fetchImpl(vm, call)
	})

	// Run compiled script
	_, err := vm.RunProgram(prog)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to execute script: %w", err)
	}

	// Instantiate Provider class
	providerInstance, err := vm.RunString("new Provider()")
	if err != nil {
		return nil, nil, fmt.Errorf("failed to construct Provider: %w", err)
	}

	return vm, providerInstance, nil
}

func (em *ExtensionManager) Call(id string, method string, args ...interface{}) (interface{}, error) {
	vm, provider, err := em.getVM(id)
	if err != nil {
		return nil, err
	}

	methodVal := provider.ToObject(vm).Get(method)
	if methodVal == nil || goja.IsUndefined(methodVal) {
		return nil, fmt.Errorf("method %q not found on Provider", method)
	}

	jsFunc, ok := goja.AssertFunction(methodVal)
	if !ok {
		return nil, fmt.Errorf("property %q is not a function", method)
	}

	jsArgs := make([]goja.Value, len(args))
	for i, arg := range args {
		jsArgs[i] = vm.ToValue(arg)
	}

	result, err := jsFunc(provider, jsArgs...)
	if err != nil {
		return nil, fmt.Errorf("JS error calling %s: %w", method, err)
	}

	// If a Promise is returned, await it
	if promise, ok := result.Export().(*goja.Promise); ok {
		state := promise.State()
		if state == goja.PromiseStateFulfilled {
			return promise.Result().Export(), nil
		} else if state == goja.PromiseStateRejected {
			return nil, fmt.Errorf("Promise rejected: %v", promise.Result().Export())
		}
		return nil, fmt.Errorf("Promise was not settled synchronously")
	}

	return result.Export(), nil
}

func createJsResponse(vm *goja.Runtime, status int, body string, headers map[string]string) goja.Value {
	resObj := vm.NewObject()
	resObj.Set("status", status)

	// Bind headers object
	headersObj := vm.NewObject()
	for k, v := range headers {
		headersObj.Set(strings.ToLower(k), v)
	}
	resObj.Set("headers", headersObj)

	// Bind text() function
	resObj.Set("text", func(call goja.FunctionCall) goja.Value {
		p, resolve, _ := vm.NewPromise()
		resolve(body)
		return vm.ToValue(p)
	})

	// Bind json() function
	resObj.Set("json", func(call goja.FunctionCall) goja.Value {
		p, resolve, reject := vm.NewPromise()
		var parsed interface{}
		if err := json.Unmarshal([]byte(body), &parsed); err != nil {
			reject(vm.NewTypeError("Failed to parse JSON: " + err.Error()))
		} else {
			resolve(parsed)
		}
		return vm.ToValue(p)
	})

	return resObj
}

func fetchImpl(vm *goja.Runtime, call goja.FunctionCall) goja.Value {
	promise, resolve, reject := vm.NewPromise()

	if len(call.Arguments) == 0 {
		reject(vm.NewTypeError("fetch requires at least 1 argument"))
		return vm.ToValue(promise)
	}

	urlStr := call.Arguments[0].String()

	req, err := http.NewRequest("GET", urlStr, nil)
	if err != nil {
		reject(vm.NewTypeError("Failed to create request: " + err.Error()))
		return vm.ToValue(promise)
	}

	// Parse options
	if len(call.Arguments) > 1 {
		optsVal := call.Arguments[1]
		if optsObj := optsVal.ToObject(vm); optsObj != nil {
			// Method
			if methodVal := optsObj.Get("method"); methodVal != nil && !goja.IsUndefined(methodVal) {
				req.Method = strings.ToUpper(methodVal.String())
			}

			// Headers
			if headersVal := optsObj.Get("headers"); headersVal != nil && !goja.IsUndefined(headersVal) {
				if headersObj := headersVal.ToObject(vm); headersObj != nil {
					for _, key := range headersObj.Keys() {
						req.Header.Set(key, headersObj.Get(key).String())
					}
				}
			}

			// Body
			if bodyVal := optsObj.Get("body"); bodyVal != nil && !goja.IsUndefined(bodyVal) {
				req.Body = io.NopCloser(strings.NewReader(bodyVal.String()))
			}
		}
	}

	// Default User-Agent if not set
	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		reject(vm.NewTypeError("Request failed: " + err.Error()))
		return vm.ToValue(promise)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		reject(vm.NewTypeError("Failed to read response body: " + err.Error()))
		return vm.ToValue(promise)
	}

	respHeaders := make(map[string]string)
	for k, v := range resp.Header {
		if len(v) > 0 {
			respHeaders[k] = v[0]
		}
	}

	jsResp := createJsResponse(vm, resp.StatusCode, string(bodyBytes), respHeaders)
	resolve(jsResp)

	return vm.ToValue(promise)
}
