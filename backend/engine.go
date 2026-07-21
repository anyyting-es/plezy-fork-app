package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/anacrolix/torrent"
	"golang.org/x/time/rate"
)

// ─── Data types ────────────────────────────────────────────────────────────

// TorrentInfo represents a snapshot of an active torrent's state.
type TorrentInfo struct {
	InfoHash      string  `json:"infoHash"`
	Name          string  `json:"name"`
	Size          int64   `json:"size"`
	Downloaded    int64   `json:"downloaded"`
	DownloadSpeed float64 `json:"downloadSpeed"` // bytes/s (EMA smoothed)
	UploadSpeed   float64 `json:"uploadSpeed"`   // bytes/s (EMA smoothed)
	Seeders       int32   `json:"seeders"`
	Leechers      int32   `json:"leechers"`
	Progress      float64 `json:"progress"` // 0–100
	Files         []File  `json:"files"`
	AddedAt       int64   `json:"addedAt"`
}

type lastTorrentStats struct {
	Downloaded int64
	Uploaded   int64
	At         time.Time
}

// File is one item inside a torrent.
type File struct {
	Index      int    `json:"index"`
	Path       string `json:"path"`
	Size       int64  `json:"size"`
	Downloaded int64  `json:"downloaded"`
}

// ─── Manager ───────────────────────────────────────────────────────────────

// TorrentManager handles all active torrents and the underlying anacrolix client.
type TorrentManager struct {
	client      *torrent.Client
	torrents    map[string]*torrent.Torrent
	infoCache   map[string]*TorrentInfo
	lastStats   map[string]lastTorrentStats
	mu          sync.RWMutex
	downloadDir string

	downloadLimiter *rate.Limiter
	uploadLimiter   *rate.Limiter
}

// Global server state
var manager *TorrentManager
var server *http.Server
var serverLn net.Listener
var serverMu sync.Mutex

func NewTorrentManager(downloadDir string) (*TorrentManager, error) {
	if err := os.MkdirAll(downloadDir, 0o755); err != nil {
		return nil, fmt.Errorf("failed to create download directory: %w", err)
	}

	downloadLimiter := rate.NewLimiter(rate.Inf, 10*1024*1024)
	uploadLimiter := rate.NewLimiter(rate.Inf, 10*1024*1024)

	cfg := torrent.NewDefaultClientConfig()
	cfg.DataDir = downloadDir
	cfg.Seed = false
	cfg.DisableUTP = false
	cfg.DisableTCP = false
	cfg.ListenPort = 0 // random port for P2P
	cfg.DownloadRateLimiter = downloadLimiter
	cfg.UploadRateLimiter = uploadLimiter

	client, err := torrent.NewClient(cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to create torrent client: %w", err)
	}

	return &TorrentManager{
		client:          client,
		torrents:        make(map[string]*torrent.Torrent),
		infoCache:       make(map[string]*TorrentInfo),
		lastStats:       make(map[string]lastTorrentStats),
		downloadDir:     downloadDir,
		downloadLimiter: downloadLimiter,
		uploadLimiter:   uploadLimiter,
	}, nil
}

// ─── Core operations ───────────────────────────────────────────────────────

// AddTorrent adds a torrent from a magnet link or plain infohash and waits
// for metadata (up to 60 s). Returns immediately with file list.
func (m *TorrentManager) AddTorrent(magnetOrHash string) (*TorrentInfo, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	var t *torrent.Torrent
	var err error

	if strings.HasPrefix(magnetOrHash, "magnet:") {
		t, err = m.client.AddMagnet(magnetOrHash)
	} else {
		t, err = m.client.AddMagnet(fmt.Sprintf("magnet:?xt=urn:btih:%s", magnetOrHash))
	}
	if err != nil {
		return nil, fmt.Errorf("failed to add torrent: %w", err)
	}

	// Wait for metadata
	select {
	case <-t.GotInfo():
	case <-time.After(60 * time.Second):
		return nil, fmt.Errorf("timeout waiting for torrent metadata")
	}

	info := t.Info()
	if info == nil {
		return nil, fmt.Errorf("failed to get torrent info")
	}

	// Give the runtime file list a moment to populate for single-file torrents
	for retries := 0; len(t.Files()) == 0 && retries < 10; retries++ {
		time.Sleep(300 * time.Millisecond)
	}

	torrentFiles := t.Files()
	infoHash := strings.ToLower(t.InfoHash().String())

	files := make([]File, 0, len(torrentFiles))
	if len(torrentFiles) > 0 {
		for i, f := range torrentFiles {
			path := f.DisplayPath()
			if path == "" {
				path = f.Path()
			}
			files = append(files, File{Index: i, Path: path, Size: f.Length()})
		}
	} else {
		files = append(files, File{Index: 0, Path: info.Name, Size: info.TotalLength()})
	}

	ti := &TorrentInfo{
		InfoHash: infoHash,
		Name:     info.Name,
		Size:     info.TotalLength(),
		AddedAt:  time.Now().Unix(),
		Files:    files,
	}

	m.torrents[infoHash] = t
	m.infoCache[infoHash] = ti

	log.Printf("[torrent] Added %q (%s) — %d file(s)", info.Name, infoHash, len(ti.Files))
	return ti, nil
}

// updateStats refreshes speed/progress on a TorrentInfo in-place.
// Caller must hold at least a read lock.
func (m *TorrentManager) updateStats(infoHash string, info *TorrentInfo, t *torrent.Torrent) {
	stats := t.Stats()
	downloaded := t.BytesCompleted()
	uploaded := stats.BytesReadData.Int64()
	now := time.Now()

	if last, ok := m.lastStats[infoHash]; ok {
		dt := now.Sub(last.At).Seconds()
		if dt > 0.5 {
			ds := float64(downloaded-last.Downloaded) / dt
			us := float64(uploaded-last.Uploaded) / dt
			if info.DownloadSpeed == 0 {
				info.DownloadSpeed = ds
			} else {
				info.DownloadSpeed = 0.3*ds + 0.7*info.DownloadSpeed
			}
			if info.UploadSpeed == 0 {
				info.UploadSpeed = us
			} else {
				info.UploadSpeed = 0.3*us + 0.7*info.UploadSpeed
			}
			m.lastStats[infoHash] = lastTorrentStats{Downloaded: downloaded, Uploaded: uploaded, At: now}
		}
	} else {
		m.lastStats[infoHash] = lastTorrentStats{Downloaded: downloaded, Uploaded: uploaded, At: now}
	}

	info.Downloaded = downloaded
	if info.Size > 0 {
		info.Progress = float64(downloaded) / float64(info.Size) * 100
	}
	info.Seeders = int32(stats.ConnectedSeeders)
	info.Leechers = int32(stats.ActivePeers - stats.ConnectedSeeders)
}

func (m *TorrentManager) GetTorrentInfo(infoHash string) (*TorrentInfo, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	infoHash = strings.ToLower(infoHash)
	info, ok := m.infoCache[infoHash]
	if !ok {
		return nil, fmt.Errorf("torrent not found")
	}
	if t, ok := m.torrents[infoHash]; ok {
		m.updateStats(infoHash, info, t)
	}
	return info, nil
}

func (m *TorrentManager) ListTorrents() []*TorrentInfo {
	m.mu.Lock()
	defer m.mu.Unlock()
	result := make([]*TorrentInfo, 0, len(m.infoCache))
	for hash, info := range m.infoCache {
		if t, ok := m.torrents[hash]; ok {
			m.updateStats(hash, info, t)
		}
		result = append(result, info)
	}
	return result
}

func (m *TorrentManager) RemoveTorrent(infoHash string, deleteFiles bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	infoHash = strings.ToLower(infoHash)
	t, ok := m.torrents[infoHash]
	if !ok {
		return fmt.Errorf("torrent not found")
	}
	t.Drop()
	delete(m.torrents, infoHash)
	delete(m.infoCache, infoHash)
	delete(m.lastStats, infoHash)
	log.Printf("[torrent] Removed %s (deleteFiles=%v)", infoHash, deleteFiles)
	return nil
}

func (m *TorrentManager) UpdateConfig(downloadLimit, uploadLimit int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if downloadLimit > 0 {
		m.downloadLimiter.SetLimit(rate.Limit(downloadLimit))
		m.downloadLimiter.SetBurst(int(downloadLimit))
	} else {
		m.downloadLimiter.SetLimit(rate.Inf)
	}
	if uploadLimit > 0 {
		m.uploadLimiter.SetLimit(rate.Limit(uploadLimit))
		m.uploadLimiter.SetBurst(int(uploadLimit))
	} else {
		m.uploadLimiter.SetLimit(rate.Inf)
	}
}

// StreamFile streams a torrent file over HTTP with proper Range support so
// media players can seek freely. It prioritizes sequential piece downloading
// so playback can start within seconds.
func (m *TorrentManager) StreamFile(infoHash string, fileIndex int, w http.ResponseWriter, r *http.Request) error {
	infoHash = strings.ToLower(infoHash)
	m.mu.RLock()
	t, ok := m.torrents[infoHash]
	m.mu.RUnlock()
	if !ok {
		return fmt.Errorf("torrent not found: %s", infoHash)
	}

	<-t.GotInfo()
	files := t.Files()
	if fileIndex < 0 || fileIndex >= len(files) {
		return fmt.Errorf("file index %d out of range (torrent has %d files)", fileIndex, len(files))
	}

	tf := files[fileIndex]
	if tf.Length() <= 0 {
		return fmt.Errorf("file has zero length")
	}

	// Kick off prioritized download (sequential reads).
	tf.Download()

	reader := tf.NewReader()
	defer reader.Close()

	// Set MIME type from extension
	ext := strings.ToLower(filepath.Ext(tf.Path()))
	ct := map[string]string{
		".mkv":  "video/x-matroska",
		".mp4":  "video/mp4",
		".webm": "video/webm",
		".avi":  "video/x-msvideo",
		".mov":  "video/quicktime",
		".m4v":  "video/x-m4v",
	}[ext]
	if ct == "" {
		ct = "video/mp4"
	}
	w.Header().Set("Content-Type", ct)
	w.Header().Set("Accept-Ranges", "bytes")

	// http.ServeContent handles Range, ETag, conditional GETs.
	http.ServeContent(w, r, tf.DisplayPath(), time.Time{}, reader)
	return nil
}

// ─── HTTP handlers ─────────────────────────────────────────────────────────

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]string{"status": "ok", "time": time.Now().Format(time.RFC3339)})
}

// POST /add  — body: {"magnetLink":"magnet:?..."} or {"infoHash":"abc123"}
func handleAddTorrent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		MagnetLink string `json:"magnetLink"`
		InfoHash   string `json:"infoHash"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	target := req.MagnetLink
	if target == "" {
		target = req.InfoHash
	}
	if target == "" {
		http.Error(w, "magnetLink or infoHash required", http.StatusBadRequest)
		return
	}
	info, err := manager.AddTorrent(target)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to add torrent: %v", err), http.StatusInternalServerError)
		return
	}
	writeJSON(w, info)
}

// GET/DELETE /torrent/{infoHash}
func handleTorrent(w http.ResponseWriter, r *http.Request) {
	infoHash := strings.TrimPrefix(r.URL.Path, "/torrent/")
	if infoHash == "" {
		http.Error(w, "infoHash required", http.StatusBadRequest)
		return
	}
	switch r.Method {
	case http.MethodGet:
		info, err := manager.GetTorrentInfo(infoHash)
		if err != nil {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		writeJSON(w, info)
	case http.MethodDelete:
		var req struct {
			DeleteFiles bool `json:"deleteFiles"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		if err := manager.RemoveTorrent(infoHash, req.DeleteFiles); err != nil {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// GET /stream/{infoHash}/{fileIndex}  — streams the file
func handleStream(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	parts := strings.SplitN(strings.TrimPrefix(r.URL.Path, "/stream/"), "/", 2)
	if len(parts) < 2 {
		http.Error(w, "Usage: /stream/{infoHash}/{fileIndex}", http.StatusBadRequest)
		return
	}
	fileIndex, err := strconv.Atoi(parts[1])
	if err != nil {
		http.Error(w, "Invalid file index", http.StatusBadRequest)
		return
	}
	if err := manager.StreamFile(parts[0], fileIndex, w, r); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// GET /list  — all active torrents
func handleList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, manager.ListTorrents())
}

// POST /settings  — adjust speed limits at runtime
func handleSettings(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		writeJSON(w, map[string]string{"status": "ok"})
	case http.MethodPost:
		var req struct {
			DownloadLimit int64 `json:"downloadLimit"`
			UploadLimit   int64 `json:"uploadLimit"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid request", http.StatusBadRequest)
			return
		}
		manager.UpdateConfig(req.DownloadLimit, req.UploadLimit)
		w.WriteHeader(http.StatusOK)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// GET /network  — local/public IPs and BitTorrent listen port
func handleNetwork(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	localIP := "unknown"
	if addrs, err := net.InterfaceAddrs(); err == nil {
		for _, a := range addrs {
			if ipnet, ok := a.(*net.IPNet); ok && !ipnet.IP.IsLoopback() && ipnet.IP.To4() != nil {
				localIP = ipnet.IP.String()
				break
			}
		}
	}

	publicIP := "unknown"
	c := http.Client{Timeout: 2 * time.Second}
	if resp, err := c.Get("https://api.ipify.org"); err == nil {
		defer resp.Body.Close()
		if body, err := io.ReadAll(resp.Body); err == nil {
			publicIP = string(body)
		}
	}

	p2pPort := "unknown"
	if addrs := manager.client.ListenAddrs(); len(addrs) > 0 {
		if tcp, ok := addrs[0].(*net.TCPAddr); ok {
			p2pPort = strconv.Itoa(tcp.Port)
		} else {
			p2pPort = addrs[0].String()
		}
	}

	writeJSON(w, map[string]string{"localIP": localIP, "publicIP": publicIP, "p2pPort": p2pPort})
}

// ─── Server lifecycle ──────────────────────────────────────────────────────

// corsMiddleware adds permissive CORS headers so Flutter's http client can
// reach the local daemon without restrictions.
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// coreStartServer initialises the TorrentManager and HTTP server.
// port=0 means use 9876 by default.
// Returns the actual port the server is listening on, or <=0 on failure.
func coreStartServer(downloadDir string, port int) int {
	if downloadDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			log.Printf("Failed to get home dir: %v", err)
			return -1
		}
		downloadDir = filepath.Join(home, ".aniting", "torrents")
	}

	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.Printf("[server] Download directory: %s", downloadDir)

	var err error
	manager, err = NewTorrentManager(downloadDir)
	if err != nil {
		log.Printf("[server] Failed to create manager: %v", err)
		return -1
	}

	initExtensionManager()

	mux := http.NewServeMux()
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/add", handleAddTorrent)
	mux.HandleFunc("/torrent/", handleTorrent)
	mux.HandleFunc("/stream/", handleStream)
	mux.HandleFunc("/list", handleList)
	mux.HandleFunc("/settings", handleSettings)
	mux.HandleFunc("/network", handleNetwork)
	mux.HandleFunc("/extensions/list", handleExtensionsList)
	mux.HandleFunc("/extensions/reload", handleExtensionsReload)
	mux.HandleFunc("/extensions/search", handleExtensionsSearch)
	mux.HandleFunc("/extensions/episodes", handleExtensionsEpisodes)
	mux.HandleFunc("/extensions/server", handleExtensionsServer)
	mux.HandleFunc("/extensions/call", handleExtensionsCall)
	mux.HandleFunc("/extensions/install", handleExtensionsInstall)
	mux.HandleFunc("/extensions/uninstall", handleExtensionsUninstall)

	srv := &http.Server{
		Handler:      corsMiddleware(mux),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 0, // streaming — no write timeout
		IdleTimeout:  120 * time.Second,
	}

	listenAddr := fmt.Sprintf("127.0.0.1:%d", port)
	if port == 0 {
		listenAddr = "127.0.0.1:9876"
	}

	ln, err := net.Listen("tcp", listenAddr)
	if err != nil {
		// If 9876 is busy, fall back to a random port
		ln, err = net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			log.Printf("[server] Failed to listen: %v", err)
			manager.client.Close()
			return -1
		}
	}

	actualPort := ln.Addr().(*net.TCPAddr).Port

	serverMu.Lock()
	server = srv
	serverLn = ln
	serverMu.Unlock()

	go func() {
		if err := srv.Serve(ln); err != nil && err != http.ErrServerClosed {
			log.Printf("[server] HTTP error: %v", err)
		}
	}()

	log.Printf("[server] Listening on http://127.0.0.1:%d", actualPort)
	return actualPort
}

func coreStopServer() {
	serverMu.Lock()
	srv := server
	ln := serverLn
	server = nil
	serverLn = nil
	serverMu.Unlock()

	if srv != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		srv.Shutdown(ctx)
	}
	if manager != nil && manager.client != nil {
		manager.client.Close()
		manager = nil
	}
	if ln != nil {
		ln.Close()
	}
}

func handleExtensionsList(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, extManager.List())
}

func handleExtensionsReload(w http.ResponseWriter, r *http.Request) {
	extManager.LoadExtensions()
	writeJSON(w, map[string]string{"status": "ok"})
}

func handleExtensionsSearch(w http.ResponseWriter, r *http.Request) {
	provider := r.URL.Query().Get("provider")
	query := r.URL.Query().Get("query")
	isDubStr := r.URL.Query().Get("isDub")
	isDub := isDubStr == "true" || isDubStr == "1"

	if provider == "" || query == "" {
		http.Error(w, "Missing provider or query", http.StatusBadRequest)
		return
	}

	res, err := extManager.Call(provider, "search", query, isDub)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, res)
}

func handleExtensionsEpisodes(w http.ResponseWriter, r *http.Request) {
	provider := r.URL.Query().Get("provider")
	slug := r.URL.Query().Get("slug")

	if provider == "" || slug == "" {
		http.Error(w, "Missing provider or slug", http.StatusBadRequest)
		return
	}

	res, err := extManager.Call(provider, "findEpisodes", slug)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, res)
}

func handleExtensionsServer(w http.ResponseWriter, r *http.Request) {
	provider := r.URL.Query().Get("provider")
	slug := r.URL.Query().Get("slug")
	episodeStr := r.URL.Query().Get("episode")
	typeVal := r.URL.Query().Get("type")

	if provider == "" || slug == "" || episodeStr == "" {
		http.Error(w, "Missing provider, slug, or episode", http.StatusBadRequest)
		return
	}

	episode, err := strconv.Atoi(episodeStr)
	if err != nil {
		http.Error(w, "Invalid episode number", http.StatusBadRequest)
		return
	}

	res, err := extManager.Call(provider, "findEpisodeServer", slug, episode, typeVal)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var urlStr string
	if str, ok := res.(string); ok {
		urlStr = str
	} else {
		// Attempt to marshal and extract URL
		b, _ := json.Marshal(res)
		var m map[string]interface{}
		_ = json.Unmarshal(b, &m)
		if u, exists := m["url"]; exists {
			urlStr = fmt.Sprintf("%v", u)
		} else {
			urlStr = fmt.Sprintf("%v", res)
		}
	}
	writeJSON(w, map[string]string{"url": urlStr})
}

func handleExtensionsCall(w http.ResponseWriter, r *http.Request) {
	provider := r.URL.Query().Get("provider")
	method := r.URL.Query().Get("method")
	argsJSON := r.URL.Query().Get("args")

	if provider == "" || method == "" {
		http.Error(w, "Missing provider or method", http.StatusBadRequest)
		return
	}

	var args []interface{}
	if argsJSON != "" {
		if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
			http.Error(w, "Invalid args JSON: "+err.Error(), http.StatusBadRequest)
			return
		}
	}

	res, err := extManager.Call(provider, method, args...)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, res)
}

func handleExtensionsInstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		ID  string `json:"id"`
		URL string `json:"url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.ID == "" || req.URL == "" {
		http.Error(w, "Missing id or url", http.StatusBadRequest)
		return
	}

	// Fetch JS code
	resp, err := http.Get(req.URL)
	if err != nil {
		http.Error(w, "Failed to fetch script: "+err.Error(), http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		http.Error(w, fmt.Sprintf("Failed to fetch script: HTTP %d", resp.StatusCode), http.StatusInternalServerError)
		return
	}

	codeBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, "Failed to read script body: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Target save directory: config extensions directory
	home, err := os.UserHomeDir()
	if err != nil {
		http.Error(w, "Failed to get user home dir: "+err.Error(), http.StatusInternalServerError)
		return
	}
	dir := filepath.Join(home, ".aniting", "extensions")
	_ = os.MkdirAll(dir, 0755)

	destPath := filepath.Join(dir, req.ID+".js")
	if err := os.WriteFile(destPath, codeBytes, 0644); err != nil {
		http.Error(w, "Failed to save script: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Reload extensions in runner
	extManager.LoadExtensions()

	writeJSON(w, map[string]string{"status": "ok"})
}

func handleExtensionsUninstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.ID == "" {
		http.Error(w, "Missing id", http.StatusBadRequest)
		return
	}

	// Delete from local extensions folder
	_ = os.Remove(filepath.Join("extensions", req.ID+".js"))

	// Delete from config extensions folder
	home, err := os.UserHomeDir()
	if err == nil {
		dir := filepath.Join(home, ".aniting", "extensions")
		_ = os.Remove(filepath.Join(dir, req.ID+".js"))
	}

	// Reload extensions in runner
	extManager.LoadExtensions()

	writeJSON(w, map[string]string{"status": "ok"})
}
