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

// TorrentInfo representa información sobre un torrent activo
type TorrentInfo struct {
	InfoHash      string  `json:"infoHash"`
	Name          string  `json:"name"`
	Size          int64   `json:"size"`
	Downloaded    int64   `json:"downloaded"`
	DownloadSpeed float64 `json:"downloadSpeed"` // bytes per second
	UploadSpeed   float64 `json:"uploadSpeed"`   // bytes per second
	Seeders       int32   `json:"seeders"`
	Leechers      int32   `json:"leechers"`
	Progress      float64 `json:"progress"`
	Files         []File  `json:"files"`
	AddedAt       int64   `json:"addedAt"`
}

type lastTorrentStats struct {
	Downloaded int64
	Uploaded   int64
	At         time.Time
}

type File struct {
	Index      int    `json:"index"`
	Path       string `json:"path"`
	Size       int64  `json:"size"`
	Downloaded int64  `json:"downloaded"`
}

// TorrentManager maneja todos los torrents activos
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

// Global manager instance
var manager *TorrentManager
var server *http.Server
var serverLn net.Listener
var serverMu sync.Mutex

func NewTorrentManager(downloadDir string) (*TorrentManager, error) {
	// Create download directory if it doesn't exist
	if err := os.MkdirAll(downloadDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create download directory: %w", err)
	}

	downloadLimiter := rate.NewLimiter(rate.Inf, 1024*1024*10) // 10MB burst
	uploadLimiter := rate.NewLimiter(rate.Inf, 1024*1024*10)

	cfg := torrent.NewDefaultClientConfig()
	cfg.DataDir = downloadDir
	cfg.Seed = false // Don't seed
	cfg.DisableUTP = false
	cfg.DisableTCP = false
	cfg.ListenPort = 0 // Random port
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

// AddTorrent adds a torrent from magnet link or infohash
func (m *TorrentManager) AddTorrent(magnetOrHash string) (*TorrentInfo, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	var t *torrent.Torrent
	var err error

	// Check if it's a magnet link or just infohash
	if strings.HasPrefix(magnetOrHash, "magnet:") {
		t, err = m.client.AddMagnet(magnetOrHash)
	} else {
		// Assume it's an infohash
		t, err = m.client.AddMagnet(fmt.Sprintf("magnet:?xt=urn:btih:%s", magnetOrHash))
	}

	if err != nil {
		return nil, fmt.Errorf("failed to add torrent: %w", err)
	}

	// Wait for metadata with timeout
	select {
	case <-t.GotInfo():
		// Info received, continue
	case <-time.After(60 * time.Second):
		return nil, fmt.Errorf("timeout waiting for torrent metadata")
	}

	info := t.Info()
	if info == nil {
		return nil, fmt.Errorf("failed to get torrent info")
	}

	// Wait for files to be available from runtime torrent file list.
	// Single-file torrents may not populate info.Files.
	retries := 0
	for len(t.Files()) == 0 && retries < 10 {
		time.Sleep(500 * time.Millisecond)
		retries++
	}

	torrentFiles := t.Files()
	if len(torrentFiles) == 0 {
		if info.TotalLength() <= 0 {
			return nil, fmt.Errorf("no files found in torrent after waiting")
		}
		// Fallback for single-file torrents where runtime list is delayed.
		torrentFiles = []*torrent.File{}
	}

	infoHash := strings.ToLower(t.InfoHash().String())
	files := make([]File, 0, len(torrentFiles))
	if len(torrentFiles) > 0 {
		for i, file := range torrentFiles {
			path := file.DisplayPath()
			if path == "" {
				path = file.Path()
			}
			files = append(files, File{
				Index: i,
				Path:  path,
				Size:  file.Length(),
			})
		}
	} else {
		files = append(files, File{
			Index: 0,
			Path:  info.Name,
			Size:  info.TotalLength(),
		})
	}

	torrentInfo := &TorrentInfo{
		InfoHash: infoHash,
		Name:     info.Name,
		Size:     info.TotalLength(),
		AddedAt:  time.Now().Unix(),
		Files:    files,
	}

	m.torrents[infoHash] = t
	m.infoCache[infoHash] = torrentInfo

	log.Printf("Added torrent: %s (%s) - %d files", info.Name, infoHash, len(torrentInfo.Files))
	return torrentInfo, nil
}

// updateStats updates the statistics for a torrent
func (m *TorrentManager) updateStats(infoHash string, info *TorrentInfo, t *torrent.Torrent) {
	stats := t.Stats()
	currentDownloaded := t.BytesCompleted()
	currentUploaded := stats.BytesReadData.Int64()
	now := time.Now()

	last, ok := m.lastStats[infoHash]
	if ok {
		dt := now.Sub(last.At).Seconds()
		if dt > 0.5 { // Only update speeds if at least 0.5s passed
			instantDSpeed := float64(currentDownloaded-last.Downloaded) / dt
			instantUSpeed := float64(currentUploaded-last.Uploaded) / dt

			// Simple Smoothing (EMA with alpha=0.3)
			if info.DownloadSpeed == 0 {
				info.DownloadSpeed = instantDSpeed
			} else {
				info.DownloadSpeed = (0.3 * instantDSpeed) + (0.7 * info.DownloadSpeed)
			}

			if info.UploadSpeed == 0 {
				info.UploadSpeed = instantUSpeed
			} else {
				info.UploadSpeed = (0.3 * instantUSpeed) + (0.7 * info.UploadSpeed)
			}

			m.lastStats[infoHash] = lastTorrentStats{
				Downloaded: currentDownloaded,
				Uploaded:   currentUploaded,
				At:         now,
			}
		}
	} else {
		m.lastStats[infoHash] = lastTorrentStats{
			Downloaded: currentDownloaded,
			Uploaded:   currentUploaded,
			At:         now,
		}
	}

	info.Downloaded = currentDownloaded
	info.Progress = float64(info.Downloaded) / float64(info.Size) * 100
	info.Seeders = int32(stats.ConnectedSeeders)
	info.Leechers = int32(stats.ActivePeers - stats.ConnectedSeeders)
}

// GetTorrentInfo returns info about a torrent
func (m *TorrentManager) GetTorrentInfo(infoHash string) (*TorrentInfo, error) {
	m.mu.Lock() // Changed to Lock because we update lastStats
	defer m.mu.Unlock()

	infoHash = strings.ToLower(infoHash)
	info, ok := m.infoCache[infoHash]
	if !ok {
		return nil, fmt.Errorf("torrent not found")
	}

	// Update stats
	t, ok := m.torrents[infoHash]
	if ok {
		m.updateStats(infoHash, info, t)
	}

	return info, nil
}

// UpdateConfig updates the client configuration at runtime
func (m *TorrentManager) UpdateConfig(downloadLimit int64, uploadLimit int64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Download Limit
	if downloadLimit > 0 {
		m.downloadLimiter.SetLimit(rate.Limit(downloadLimit))
		m.downloadLimiter.SetBurst(int(downloadLimit))
	} else {
		m.downloadLimiter.SetLimit(rate.Inf)
	}

	// Upload Limit
	if uploadLimit > 0 {
		m.uploadLimiter.SetLimit(rate.Limit(uploadLimit))
		m.uploadLimiter.SetBurst(int(uploadLimit))
	} else {
		m.uploadLimiter.SetLimit(rate.Inf)
	}

	log.Printf("Updated config: DownloadLimit=%d, UploadLimit=%d", downloadLimit, uploadLimit)
}

// StreamFile streams a file from a torrent
func (m *TorrentManager) StreamFile(infoHash string, fileIndex int, w http.ResponseWriter, r *http.Request) error {
	infoHash = strings.ToLower(infoHash)
	m.mu.RLock()
	t, ok := m.torrents[infoHash]
	m.mu.RUnlock()

	if !ok {
		return fmt.Errorf("torrent not found")
	}

	<-t.GotInfo()
	torrentFiles := t.Files()
	if fileIndex < 0 || fileIndex >= len(torrentFiles) {
		return fmt.Errorf("invalid file index")
	}

	torrentFile := torrentFiles[fileIndex]
	fileSize := torrentFile.Length()
	if fileSize <= 0 {
		return fmt.Errorf("invalid file size")
	}

	// Prioritize this file for faster startup.
	torrentFile.Download()

	// Create a reader for the torrent file
	req := torrentFile.NewReader()
	defer req.Close()

	// Set Content-Type based on extension
	ext := filepath.Ext(torrentFile.Path())
	contentType := "video/mp4" // default fallback
	if ext != "" {
		switch strings.ToLower(ext) {
		case ".mkv":
			contentType = "video/x-matroska"
		case ".mp4":
			contentType = "video/mp4"
		case ".webm":
			contentType = "video/webm"
		case ".avi":
			contentType = "video/x-msvideo"
		}
	}
	w.Header().Set("Content-Type", contentType)

	// Stream using http.ServeContent which handles range requests correctly and efficiently.
	http.ServeContent(w, r, torrentFile.DisplayPath(), time.Time{}, req)

	return nil
}

// RemoveTorrent removes a torrent and its files
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

	if deleteFiles {
		// Files will be deleted by the torrent client
	}

	log.Printf("Removed torrent: %s", infoHash)
	return nil
}

// ListTorrents returns all active torrents
func (m *TorrentManager) ListTorrents() []*TorrentInfo {
	m.mu.Lock()
	defer m.mu.Unlock()

	infos := make([]*TorrentInfo, 0, len(m.infoCache))
	for infoHash, info := range m.infoCache {
		// Update stats
		t, ok := m.torrents[infoHash]
		if ok {
			m.updateStats(infoHash, info, t)
		}
		infos = append(infos, info)
	}

	return infos
}

// HTTP Handlers

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

	magnetOrHash := req.MagnetLink
	if magnetOrHash == "" {
		magnetOrHash = req.InfoHash
	}

	if magnetOrHash == "" {
		http.Error(w, "magnetLink or infoHash required", http.StatusBadRequest)
		return
	}

	info, err := manager.AddTorrent(magnetOrHash)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to add torrent: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(info)
}

func handleGetTorrentInfo(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodDelete {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	infoHash := strings.TrimPrefix(r.URL.Path, "/torrent/")
	if infoHash == "" {
		http.Error(w, "Info hash required", http.StatusBadRequest)
		return
	}

	if r.Method == http.MethodDelete {
		var req struct {
			DeleteFiles bool `json:"deleteFiles"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)

		err := manager.RemoveTorrent(infoHash, req.DeleteFiles)
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to remove torrent: %v", err), http.StatusNotFound)
			return
		}

		w.WriteHeader(http.StatusNoContent)
		return
	}

	info, err := manager.GetTorrentInfo(infoHash)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get torrent info: %v", err), http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(info)
}

func handleStreamFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse path: /stream/{infoHash}/{fileIndex}
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/stream/"), "/")
	if len(parts) < 2 {
		http.Error(w, "Invalid path", http.StatusBadRequest)
		return
	}

	infoHash := parts[0]
	fileIndex, err := strconv.Atoi(parts[1])
	if err != nil {
		http.Error(w, "Invalid file index", http.StatusBadRequest)
		return
	}

	err = manager.StreamFile(infoHash, fileIndex, w, r)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to stream file: %v", err), http.StatusInternalServerError)
		return
	}
}

func handleListTorrents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	torrents := manager.ListTorrents()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(torrents)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ok",
		"time":   time.Now().Format(time.RFC3339),
	})
}

func handleSettings(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		// Just return current config (we set them to manager if we want to track,
		// but for now we just return ok or a placeholder if we don't track state)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status": "ok",
		})
		return
	}

	if r.Method == http.MethodPost {
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
		return
	}

	http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
}

func handleNetwork(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	localIP := "unknown"
	publicIP := "unknown"

	// Get local IP
	addrs, err := net.InterfaceAddrs()
	if err == nil {
		for _, addr := range addrs {
			if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
				if ipnet.IP.To4() != nil {
					localIP = ipnet.IP.String()
					break
				}
			}
		}
	}

	// Get public IP with timeout
	client := http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("https://api.ipify.org")
	if err == nil {
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		publicIP = string(body)
	}

	currentPort := "unknown"
	if addrs := manager.client.ListenAddrs(); len(addrs) > 0 {
		if tcpAddr, ok := addrs[0].(*net.TCPAddr); ok {
			currentPort = strconv.Itoa(tcpAddr.Port)
		} else {
			currentPort = addrs[0].String()
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"localIP":  localIP,
		"publicIP": publicIP,
		"port":     currentPort,
	})
}

func coreStartServer(downloadDir string) int {
	if downloadDir == "" {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			log.Printf("Failed to get home directory: %v", err)
			return -1
		}
		downloadDir = filepath.Join(homeDir, ".anityng", "torrents")
	}

	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.Printf("StartServer: download directory: %s", downloadDir)

	var err error
	manager, err = NewTorrentManager(downloadDir)
	if err != nil {
		log.Printf("Failed to create torrent manager: %v", err)
		return -1
	}

	// Setup HTTP routes
	mux := http.NewServeMux()

	// Torrent endpoints
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/add", handleAddTorrent)
	mux.HandleFunc("/torrent/", handleGetTorrentInfo)
	mux.HandleFunc("/stream/", handleStreamFile)
	mux.HandleFunc("/list", handleListTorrents)
	mux.HandleFunc("/settings", handleSettings)
	mux.HandleFunc("/network", handleNetwork)

	handler := corsMiddleware(mux)

	srv := &http.Server{
		Handler:      handler,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 0,
		IdleTimeout:  120 * time.Second,
	}

	// Listen on port 9876 (fixed for easier integration)
	ln, err := net.Listen("tcp", ":9876")
	if err != nil {
		log.Printf("Failed to listen on port 9876: %v", err)
		manager.client.Close()
		return -1
	}

	port := ln.Addr().(*net.TCPAddr).Port

	serverMu.Lock()
	server = srv
	serverLn = ln
	serverMu.Unlock()

	go func() {
		if err := srv.Serve(ln); err != nil && err != http.ErrServerClosed {
			log.Printf("HTTP server error: %v", err)
		}
	}()

	return port
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
		if err := srv.Shutdown(ctx); err != nil {
			log.Printf("Server shutdown error: %v", err)
		}
	}

	if manager != nil && manager.client != nil {
		manager.client.Close()
		manager = nil
	}


	if ln != nil {
		ln.Close()
	}
}

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
