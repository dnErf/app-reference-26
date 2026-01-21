package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/array"
	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/apache/arrow-go/v18/parquet"
	"github.com/apache/arrow-go/v18/parquet/file"
	"github.com/apache/arrow-go/v18/parquet/pqarrow"
)

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Name                    string
	DataDir                 string
	LSMConfig               LSMTreeConfig
	EnableWAL               bool
	WALSyncMode             string // "sync", "async", "batch"
	MaxConcurrentOperations int
	EnableMetrics           bool
}

// NewDatabaseConfig creates a new database configuration
func NewDatabaseConfig(name, dataDir string, lsmConfig LSMTreeConfig) *DatabaseConfig {
	return &DatabaseConfig{
		Name:                    name,
		DataDir:                 dataDir,
		LSMConfig:               lsmConfig,
		EnableWAL:               true,
		WALSyncMode:             "sync",
		MaxConcurrentOperations: 10,
		EnableMetrics:           true,
	}
}

// Validate validates the database configuration
func (dc *DatabaseConfig) Validate() error {
	if dc.MaxConcurrentOperations <= 0 {
		return fmt.Errorf("max_concurrent_operations must be positive")
	}

	validSyncModes := []string{"sync", "async", "batch"}
	valid := false
	for _, mode := range validSyncModes {
		if dc.WALSyncMode == mode {
			valid = true
			break
		}
	}
	if !valid {
		return fmt.Errorf("invalid wal_sync_mode. Valid options: sync, async, batch")
	}

	return nil
}

// LSMTreeConfig holds LSM tree configuration
type LSMTreeConfig struct {
	MemtableType               string
	MaxMemtableSize            int
	DataDir                    string
	EnableBackgroundCompaction bool
	CompactionCheckInterval    time.Duration
}

// NewLSMTreeConfig creates a new LSM tree configuration
func NewLSMTreeConfig(memtableType string, maxMemtableSize int, dataDir string) *LSMTreeConfig {
	return &LSMTreeConfig{
		MemtableType:               memtableType,
		MaxMemtableSize:            maxMemtableSize,
		DataDir:                    dataDir,
		EnableBackgroundCompaction: true,
		CompactionCheckInterval:    5 * time.Second,
	}
}

// WALEntry represents a Write-Ahead Log entry
type WALEntry struct {
	Operation      string `json:"operation"`
	Key            string `json:"key"`
	Value          string `json:"value"`
	Timestamp      int64  `json:"timestamp"`
	SequenceNumber int64  `json:"sequence_number"`
}

// NewWALEntry creates a new WAL entry
func NewWALEntry(operation, key, value string) *WALEntry {
	return &WALEntry{
		Operation:      operation,
		Key:            key,
		Value:          value,
		Timestamp:      time.Now().UnixMicro(),
		SequenceNumber: 0,
	}
}

// ToString serializes WAL entry to JSON string
func (we *WALEntry) ToString() (string, error) {
	data, err := json.Marshal(we)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// WALEntryFromString deserializes WAL entry from JSON string
func WALEntryFromString(line string) (*WALEntry, error) {
	var entry WALEntry
	err := json.Unmarshal([]byte(line), &entry)
	return &entry, err
}

// WALManager manages Write-Ahead Logging
type WALManager struct {
	WALFile         string
	CurrentSequence int64
	IsEnabled       bool
	mutex           sync.Mutex
}

// NewWALManager creates a new WAL manager
func NewWALManager(dataDir, dbName string, enabled bool) *WALManager {
	walFile := filepath.Join(dataDir, dbName+".wal")
	return &WALManager{
		WALFile:         walFile,
		CurrentSequence: 0,
		IsEnabled:       enabled,
	}
}

// AppendEntry appends a WAL entry to the log file
func (wm *WALManager) AppendEntry(entry *WALEntry) error {
	if !wm.IsEnabled {
		return nil
	}

	wm.mutex.Lock()
	defer wm.mutex.Unlock()

	entry.SequenceNumber = wm.CurrentSequence
	wm.CurrentSequence++

	// Ensure directory exists
	if err := os.MkdirAll(filepath.Dir(wm.WALFile), 0755); err != nil {
		return err
	}

	file, err := os.OpenFile(wm.WALFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	entryStr, err := entry.ToString()
	if err != nil {
		return err
	}

	if _, err := file.WriteString(entryStr + "\n"); err != nil {
		return err
	}

	return nil
}

// GetEntries reads all WAL entries from the log file
func (wm *WALManager) GetEntries() ([]*WALEntry, error) {
	var entries []*WALEntry

	if !wm.IsEnabled {
		return entries, nil
	}

	file, err := os.Open(wm.WALFile)
	if err != nil {
		if os.IsNotExist(err) {
			return entries, nil
		}
		return nil, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		entry, err := WALEntryFromString(line)
		if err != nil {
			log.Printf("Error parsing WAL entry: %v", err)
			continue
		}
		entries = append(entries, entry)
	}

	return entries, scanner.Err()
}

// Clear clears the WAL file after successful checkpoint
func (wm *WALManager) Clear() error {
	if !wm.IsEnabled {
		return nil
	}

	wm.mutex.Lock()
	defer wm.mutex.Unlock()

	return os.Remove(wm.WALFile)
}

// DatabaseMetrics tracks database performance metrics
type DatabaseMetrics struct {
	TotalOperations  int64
	PutOperations    int64
	GetOperations    int64
	DeleteOperations int64
	CacheHits        int64
	CacheMisses      int64
	CompactionCount  int64
	UptimeSeconds    int64
	StartTime        time.Time
	mutex            sync.RWMutex
}

// NewDatabaseMetrics creates new database metrics
func NewDatabaseMetrics() *DatabaseMetrics {
	return &DatabaseMetrics{
		StartTime: time.Now(),
	}
}

// RecordOperation records an operation in metrics
func (dm *DatabaseMetrics) RecordOperation(operation string) {
	dm.mutex.Lock()
	defer dm.mutex.Unlock()

	dm.TotalOperations++

	switch operation {
	case "PUT":
		dm.PutOperations++
	case "GET":
		dm.GetOperations++
	case "DELETE":
		dm.DeleteOperations++
	}
}

// UpdateUptime updates uptime calculation
func (dm *DatabaseMetrics) UpdateUptime() {
	dm.mutex.Lock()
	defer dm.mutex.Unlock()

	dm.UptimeSeconds = int64(time.Since(dm.StartTime).Seconds())
}

// GetStats returns current metrics as a map
func (dm *DatabaseMetrics) GetStats() map[string]int64 {
	dm.mutex.RLock()
	defer dm.mutex.RUnlock()

	return map[string]int64{
		"total_operations":  dm.TotalOperations,
		"put_operations":    dm.PutOperations,
		"get_operations":    dm.GetOperations,
		"delete_operations": dm.DeleteOperations,
		"cache_hits":        dm.CacheHits,
		"cache_misses":      dm.CacheMisses,
		"compaction_count":  dm.CompactionCount,
		"uptime_seconds":    dm.UptimeSeconds,
	}
}

// Memtable represents an in-memory table
type Memtable struct {
	data    map[string]string
	size    int
	maxSize int
	mutex   sync.RWMutex
}

// NewMemtable creates a new memtable
func NewMemtable(maxSize int) *Memtable {
	return &Memtable{
		data:    make(map[string]string),
		size:    0,
		maxSize: maxSize,
	}
}

// Put inserts or updates a key-value pair
func (mt *Memtable) Put(key, value string) {
	mt.mutex.Lock()
	defer mt.mutex.Unlock()

	oldSize := len(mt.data[key])
	mt.data[key] = value
	mt.size += len(value) - oldSize
}

// Get retrieves a value for a key
func (mt *Memtable) Get(key string) (string, bool) {
	mt.mutex.RLock()
	defer mt.mutex.RUnlock()

	value, exists := mt.data[key]
	return value, exists
}

// Delete removes a key
func (mt *Memtable) Delete(key string) {
	mt.mutex.Lock()
	defer mt.mutex.Unlock()

	if _, exists := mt.data[key]; exists {
		delete(mt.data, key)
		mt.size -= len(key) + len(mt.data[key])
	}
}

// Size returns current size
func (mt *Memtable) Size() int {
	mt.mutex.RLock()
	defer mt.mutex.RUnlock()
	return mt.size
}

// IsFull checks if memtable is full
func (mt *Memtable) IsFull() bool {
	mt.mutex.RLock()
	defer mt.mutex.RUnlock()
	return mt.size >= mt.maxSize
}

// GetAllData returns all data (for flushing)
func (mt *Memtable) GetAllData() map[string]string {
	mt.mutex.RLock()
	defer mt.mutex.RUnlock()

	result := make(map[string]string)
	for k, v := range mt.data {
		result[k] = v
	}
	return result
}

// SSTable represents a Sorted String Table using Arrow/Parquet
type SSTable struct {
	Filename string
	Metadata *SSTableMetadata
}

// SSTableMetadata holds SSTable metadata
type SSTableMetadata struct {
	MinKey     string
	MaxKey     string
	NumEntries int64
	FileSize   int64
	CreatedAt  time.Time
}

// NewSSTable creates a new SSTable
func NewSSTable(filename string) *SSTable {
	return &SSTable{
		Filename: filename,
		Metadata: &SSTableMetadata{
			CreatedAt: time.Now(),
		},
	}
}

// WriteSSTable writes memtable data to SSTable using Arrow/Parquet
func WriteSSTable(data map[string]string, filename string) (*SSTable, error) {
	alloc := memory.NewGoAllocator()

	// Create sorted keys
	var keys []string
	for k := range data {
		keys = append(keys, k)
	}
	// Simple sort (in real implementation, use proper sorting)
	for i := 0; i < len(keys)-1; i++ {
		for j := i + 1; j < len(keys); j++ {
			if keys[i] > keys[j] {
				keys[i], keys[j] = keys[j], keys[i]
			}
		}
	}

	// Create Arrow schema
	schema := arrow.NewSchema([]arrow.Field{
		{Name: "key", Type: arrow.BinaryTypes.String},
		{Name: "value", Type: arrow.BinaryTypes.String},
	}, nil)

	// Build record
	builder := array.NewRecordBuilder(alloc, schema)
	defer builder.Release()

	keyBuilder := builder.Field(0).(*array.StringBuilder)
	valueBuilder := builder.Field(1).(*array.StringBuilder)

	for _, key := range keys {
		keyBuilder.Append(key)
		valueBuilder.Append(data[key])
	}

	record := builder.NewRecord()
	defer record.Release()

	// Write to Parquet
	file, err := os.Create(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	writer, err := pqarrow.NewFileWriter(record.Schema(), file, parquet.NewWriterProperties(), pqarrow.NewArrowWriterProperties())
	if err != nil {
		return nil, err
	}
	defer writer.Close()

	if err := writer.Write(record); err != nil {
		return nil, err
	}

	// Create SSTable metadata
	sstable := NewSSTable(filename)
	sstable.Metadata.NumEntries = int64(len(data))
	if len(keys) > 0 {
		sstable.Metadata.MinKey = keys[0]
		sstable.Metadata.MaxKey = keys[len(keys)-1]
	}

	// Get file size
	if info, err := os.Stat(filename); err == nil {
		sstable.Metadata.FileSize = info.Size()
	}

	return sstable, nil
}

// ReadSSTable reads SSTable data
func (sst *SSTable) ReadSSTable() (map[string]string, error) {
	data := make(map[string]string)

	f, err := os.Open(sst.Filename)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	reader, err := file.NewParquetReader(f)
	if err != nil {
		return nil, err
	}
	defer reader.Close()

	arrowReader, err := pqarrow.NewFileReader(reader, pqarrow.ArrowReadProperties{}, memory.DefaultAllocator)
	if err != nil {
		return nil, err
	}

	table, err := arrowReader.ReadTable(context.Background())
	if err != nil {
		return nil, err
	}
	defer table.Release()

	keyCol := table.Column(0).Data()
	valueCol := table.Column(1).Data()

	if keyCol.Len() != valueCol.Len() {
		return nil, fmt.Errorf("key and value columns have different lengths")
	}

	for i := 0; i < keyCol.Len(); i++ {
		keyChunk := keyCol.Chunk(0)
		valueChunk := valueCol.Chunk(0)

		if keyChunk.Len() > i && valueChunk.Len() > i {
			keyArr := keyChunk.(*array.String)
			valueArr := valueChunk.(*array.String)

			key := keyArr.Value(i)
			value := valueArr.Value(i)
			data[key] = value
		}
	}

	return data, nil
}

// LSMTree represents the Log-Structured Merge Tree
type LSMTree struct {
	Config             *LSMTreeConfig
	Memtable           *Memtable
	ImmutableMemtables []*Memtable
	SSTables           []*SSTable
	mutex              sync.RWMutex
}

// NewLSMTree creates a new LSM tree
func NewLSMTree(config *LSMTreeConfig) *LSMTree {
	lsm := &LSMTree{
		Config:   config,
		Memtable: NewMemtable(config.MaxMemtableSize),
		SSTables: make([]*SSTable, 0),
	}

	// Load existing SSTables from disk
	lsm.loadExistingSSTables()

	return lsm
}

// Put inserts or updates a key-value pair
func (lsm *LSMTree) Put(key, value string) {
	lsm.mutex.Lock()
	defer lsm.mutex.Unlock()

	lsm.Memtable.Put(key, value)

	// Check if memtable needs to be flushed
	if lsm.Memtable.IsFull() {
		lsm.flushMemtable()
	}
}

// Get retrieves a value for a key
func (lsm *LSMTree) Get(key string) string {
	lsm.mutex.RLock()
	defer lsm.mutex.RUnlock()

	// Check memtable first
	if value, exists := lsm.Memtable.Get(key); exists {
		return value
	}

	// Check immutable memtables
	for _, imm := range lsm.ImmutableMemtables {
		if value, exists := imm.Get(key); exists {
			return value
		}
	}

	// Check SSTables (simplified - should use binary search)
	for _, sst := range lsm.SSTables {
		data, err := sst.ReadSSTable()
		if err != nil {
			continue
		}
		if value, exists := data[key]; exists {
			return value
		}
	}

	return "" // Not found
}

// Delete removes a key
func (lsm *LSMTree) Delete(key string) {
	lsm.mutex.Lock()
	defer lsm.mutex.Unlock()

	lsm.Memtable.Delete(key)
}

// flushMemtable flushes the current memtable to SSTable
func (lsm *LSMTree) flushMemtable() {
	// Move current memtable to immutable
	lsm.ImmutableMemtables = append(lsm.ImmutableMemtables, lsm.Memtable)

	// Create new memtable
	lsm.Memtable = NewMemtable(lsm.Config.MaxMemtableSize)

	// Flush immutable memtable to SSTable (simplified - only flush the first one)
	if len(lsm.ImmutableMemtables) > 0 {
		imm := lsm.ImmutableMemtables[0]
		lsm.ImmutableMemtables = lsm.ImmutableMemtables[1:]

		data := imm.GetAllData()
		if len(data) > 0 {
			filename := filepath.Join(lsm.Config.DataDir, fmt.Sprintf("sstable_%d.parquet", time.Now().Unix()))
			sstable, err := WriteSSTable(data, filename)
			if err != nil {
				log.Printf("Error writing SSTable: %v", err)
				return
			}
			lsm.SSTables = append(lsm.SSTables, sstable)
		}
	}
}

// loadExistingSSTables loads existing SSTable files from disk
func (lsm *LSMTree) loadExistingSSTables() {
	files, err := os.ReadDir(lsm.Config.DataDir)
	if err != nil {
		return
	}

	for _, file := range files {
		if strings.HasSuffix(file.Name(), ".parquet") && strings.Contains(file.Name(), "sstable") {
			filename := filepath.Join(lsm.Config.DataDir, file.Name())
			sstable := NewSSTable(filename)
			lsm.SSTables = append(lsm.SSTables, sstable)
		}
	}
}

// GetStats returns LSM tree statistics
func (lsm *LSMTree) GetStats() map[string]int64 {
	lsm.mutex.RLock()
	defer lsm.mutex.RUnlock()

	return map[string]int64{
		"memtable_entries":    int64(len(lsm.Memtable.data)),
		"memtable_size_bytes": int64(lsm.Memtable.size),
		"immutable_memtables": int64(len(lsm.ImmutableMemtables)),
		"sstables_count":      int64(len(lsm.SSTables)),
	}
}

// LSMDatabase represents the main LSM database
type LSMDatabase struct {
	Config     *DatabaseConfig
	LSMTree    *LSMTree
	WALManager *WALManager
	Metrics    *DatabaseMetrics
	IsOpen     bool
	mutex      sync.RWMutex
}

// NewLSMDatabase creates a new LSM database
func NewLSMDatabase(config *DatabaseConfig) (*LSMDatabase, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}

	db := &LSMDatabase{
		Config:     config,
		LSMTree:    NewLSMTree(&config.LSMConfig),
		WALManager: NewWALManager(config.DataDir, config.Name, config.EnableWAL),
		Metrics:    NewDatabaseMetrics(),
		IsOpen:     true,
	}

	fmt.Printf("LSM Database '%s' opened successfully\n", config.Name)
	fmt.Printf("Data directory: %s\n", config.DataDir)
	fmt.Printf("Memtable type: %s\n", config.LSMConfig.MemtableType)
	fmt.Printf("WAL enabled: %v\n", config.EnableWAL)

	// Recover from WAL
	if err := db.recoverFromWAL(); err != nil {
		log.Printf("Warning: WAL recovery failed: %v", err)
	}

	return db, nil
}

// Put inserts or updates a key-value pair
func (db *LSMDatabase) Put(key, value string) error {
	db.mutex.Lock()
	defer db.mutex.Unlock()

	if !db.IsOpen {
		return fmt.Errorf("database is closed")
	}

	// Record operation in WAL
	walEntry := NewWALEntry("PUT", key, value)
	if err := db.WALManager.AppendEntry(walEntry); err != nil {
		return err
	}

	// Perform operation
	db.LSMTree.Put(key, value)

	// Update metrics
	if db.Config.EnableMetrics {
		db.Metrics.RecordOperation("PUT")
	}

	return nil
}

// Get retrieves a value for a key
func (db *LSMDatabase) Get(key string) (string, error) {
	db.mutex.RLock()
	defer db.mutex.RUnlock()

	if !db.IsOpen {
		return "", fmt.Errorf("database is closed")
	}

	// Perform operation
	value := db.LSMTree.Get(key)

	// Update metrics
	if db.Config.EnableMetrics {
		db.Metrics.RecordOperation("GET")
	}

	return value, nil
}

// Delete removes a key
func (db *LSMDatabase) Delete(key string) error {
	db.mutex.Lock()
	defer db.mutex.Unlock()

	if !db.IsOpen {
		return fmt.Errorf("database is closed")
	}

	// Record operation in WAL
	walEntry := NewWALEntry("DELETE", key, "")
	if err := db.WALManager.AppendEntry(walEntry); err != nil {
		return err
	}

	// Perform operation
	db.LSMTree.Delete(key)

	// Update metrics
	if db.Config.EnableMetrics {
		db.Metrics.RecordOperation("DELETE")
	}

	return nil
}

// GetStats returns database statistics
func (db *LSMDatabase) GetStats() (map[string]int64, error) {
	db.mutex.RLock()
	defer db.mutex.RUnlock()

	if !db.IsOpen {
		return nil, fmt.Errorf("database is closed")
	}

	// Update uptime
	db.Metrics.UpdateUptime()

	// Get LSM tree stats
	lsmStats := db.LSMTree.GetStats()

	// Combine with database metrics
	combinedStats := db.Metrics.GetStats()
	combinedStats["lsm_memtable_entries"] = lsmStats["memtable_entries"]
	combinedStats["lsm_memtable_size"] = lsmStats["memtable_size_bytes"]
	combinedStats["lsm_sstables_count"] = lsmStats["sstables_count"]

	return combinedStats, nil
}

// Close closes the database
func (db *LSMDatabase) Close() error {
	db.mutex.Lock()
	defer db.mutex.Unlock()

	if !db.IsOpen {
		return nil
	}

	fmt.Printf("Closing LSM Database '%s'...\n", db.Config.Name)

	// Force final memtable flush if needed
	stats := db.LSMTree.GetStats()
	if stats["memtable_entries"] > 0 {
		db.LSMTree.flushMemtable()
	}

	// Clear WAL after successful operations
	if db.Config.EnableWAL {
		if err := db.WALManager.Clear(); err != nil {
			log.Printf("Warning: Failed to clear WAL: %v", err)
		}
	}

	db.IsOpen = false
	fmt.Println("Database closed successfully")
	return nil
}

// recoverFromWAL recovers database state from WAL entries
func (db *LSMDatabase) recoverFromWAL() error {
	if !db.Config.EnableWAL {
		return nil
	}

	fmt.Println("Recovering from WAL...")
	walEntries, err := db.WALManager.GetEntries()
	if err != nil {
		return err
	}

	if len(walEntries) == 0 {
		fmt.Println("No WAL entries to recover")
		return nil
	}

	fmt.Printf("Replaying %d WAL entries...\n", len(walEntries))

	for _, entry := range walEntries {
		switch entry.Operation {
		case "PUT":
			db.LSMTree.Put(entry.Key, entry.Value)
		case "DELETE":
			db.LSMTree.Delete(entry.Key)
		}
	}

	fmt.Println("Recovery complete")
	return nil
}

// Factory functions for different database configurations

// CreateDatabase creates a new LSM database with default configuration
func CreateDatabase(name, dataDir string, memtableType string) (*LSMDatabase, error) {
	lsmConfig := NewLSMTreeConfig(memtableType, 1024*1024, dataDir) // 1MB

	dbConfig := NewDatabaseConfig(name, dataDir, *lsmConfig)
	dbConfig.EnableWAL = true
	dbConfig.WALSyncMode = "sync"
	dbConfig.EnableMetrics = true

	return NewLSMDatabase(dbConfig)
}

// CreateHighPerformanceDatabase creates a high-performance database configuration
func CreateHighPerformanceDatabase(name, dataDir string) (*LSMDatabase, error) {
	lsmConfig := NewLSMTreeConfig("hash_skiplist", 2*1024*1024, dataDir) // 2MB
	lsmConfig.EnableBackgroundCompaction = true
	lsmConfig.CompactionCheckInterval = 2 * time.Second

	dbConfig := NewDatabaseConfig(name, dataDir, *lsmConfig)
	dbConfig.EnableWAL = true
	dbConfig.WALSyncMode = "async"
	dbConfig.MaxConcurrentOperations = 50
	dbConfig.EnableMetrics = true

	return NewLSMDatabase(dbConfig)
}

// CreateMemoryEfficientDatabase creates a memory-efficient database configuration
func CreateMemoryEfficientDatabase(name, dataDir string) (*LSMDatabase, error) {
	lsmConfig := NewLSMTreeConfig("linked_list", 256*1024, dataDir) // 256KB
	lsmConfig.EnableBackgroundCompaction = true
	lsmConfig.CompactionCheckInterval = 10 * time.Second

	dbConfig := NewDatabaseConfig(name, dataDir, *lsmConfig)
	dbConfig.EnableWAL = true
	dbConfig.WALSyncMode = "batch"
	dbConfig.MaxConcurrentOperations = 5
	dbConfig.EnableMetrics = true

	return NewLSMDatabase(dbConfig)
}

// Demonstration functions

func demoBasicDatabaseOperations() error {
	fmt.Println("=== Basic LSM Database Operations ===\n")

	db, err := CreateDatabase("demo_db", "./demo_database", "hash_skiplist")
	if err != nil {
		return err
	}
	defer db.Close()

	fmt.Println("Performing database operations...\n")

	// Insert test data
	testData := []struct{ key, value string }{
		{"user:alice", "Alice Johnson"},
		{"user:bob", "Bob Smith"},
		{"product:laptop", "Gaming Laptop"},
		{"product:mouse", "Wireless Mouse"},
		{"order:1001", "Alice's Order"},
	}

	for _, item := range testData {
		if err := db.Put(item.key, item.value); err != nil {
			return err
		}
		fmt.Printf("PUT: %s = %s\n", item.key, item.value)
	}

	fmt.Println()

	// Read operations
	fmt.Println("Reading data back:")
	for _, item := range testData {
		value, err := db.Get(item.key)
		if err != nil {
			return err
		}
		fmt.Printf("GET: %s = %s\n", item.key, value)
	}

	fmt.Println()

	// Delete operation
	fmt.Println("Deleting user:bob...")
	if err := db.Delete("user:bob"); err != nil {
		return err
	}
	deletedValue, err := db.Get("user:bob")
	if err != nil {
		return err
	}
	fmt.Printf("GET user:bob after delete: %s\n", deletedValue)

	fmt.Println()

	// Get statistics
	fmt.Println("Database Statistics:")
	stats, err := db.GetStats()
	if err != nil {
		return err
	}
	fmt.Printf("Total operations: %d\n", stats["total_operations"])
	fmt.Printf("PUT operations: %d\n", stats["put_operations"])
	fmt.Printf("GET operations: %d\n", stats["get_operations"])
	fmt.Printf("DELETE operations: %d\n", stats["delete_operations"])
	fmt.Printf("Uptime: %d seconds\n", stats["uptime_seconds"])
	fmt.Printf("LSM memtable entries: %d\n", stats["lsm_memtable_entries"])
	fmt.Printf("LSM SSTable count: %d\n", stats["lsm_sstables_count"])

	return nil
}

func demoDatabaseConfigurations() error {
	fmt.Println("=== Database Configuration Comparison ===\n")

	configs := []struct{ name, memtableType string }{
		{"High-Performance", "hash_skiplist"},
		{"Memory-Efficient", "linked_list"},
		{"Balanced", "enhanced_skiplist"},
	}

	for _, config := range configs {
		fmt.Printf("--- %s Configuration ---\n", config.name)

		dbName := "config_test_" + config.memtableType
		dataDir := "./config_test_" + config.memtableType

		var db *LSMDatabase
		var err error

		if config.name == "High-Performance" {
			db, err = CreateHighPerformanceDatabase(dbName, dataDir)
		} else if config.name == "Memory-Efficient" {
			db, err = CreateMemoryEfficientDatabase(dbName, dataDir)
		} else {
			db, err = CreateDatabase(dbName, dataDir, config.memtableType)
		}

		if err != nil {
			return err
		}

		// Quick performance test
		startTime := time.Now()
		for i := 0; i < 100; i++ {
			key := fmt.Sprintf("key%d", i)
			value := fmt.Sprintf("value%d", i)
			if err := db.Put(key, value); err != nil {
				db.Close()
				return err
			}
		}
		endTime := time.Now()

		stats, err := db.GetStats()
		if err != nil {
			db.Close()
			return err
		}

		fmt.Printf("Configuration: %s\n", config.name)
		fmt.Printf("Memtable type: %s\n", config.memtableType)
		fmt.Printf("Operations completed: 100\n")
		fmt.Printf("Time taken: %v\n", endTime.Sub(startTime))
		fmt.Printf("Memtable entries: %d\n", stats["lsm_memtable_entries"])
		fmt.Printf("Memtable size: %d bytes\n", stats["lsm_memtable_size"])

		db.Close()
		fmt.Println()
	}

	return nil
}

func demoWALRecovery() error {
	fmt.Println("=== WAL Recovery Demonstration ===\n")

	dbName := "recovery_test"
	dataDir := "./recovery_test"

	fmt.Println("Phase 1: Create database and add data...")
	db, err := CreateDatabase(dbName, dataDir, "hash_skiplist")
	if err != nil {
		return err
	}

	for i := 0; i < 50; i++ {
		key := fmt.Sprintf("recovery_key%d", i)
		value := fmt.Sprintf("recovery_value%d", i)
		if err := db.Put(key, value); err != nil {
			db.Close()
			return err
		}
	}
	fmt.Println("Added 50 entries to database")
	db.Close() // This should clear WAL

	fmt.Println("\nPhase 2: Simulate crash and recovery...")
	db2, err := CreateDatabase(dbName, dataDir, "hash_skiplist")
	if err != nil {
		return err
	}
	defer db2.Close()
	// Recovery should happen automatically in constructor

	recoveredCount := 0
	for i := 0; i < 50; i++ {
		key := fmt.Sprintf("recovery_key%d", i)
		value, err := db2.Get(key)
		if err != nil {
			return err
		}
		if value != "" {
			recoveredCount++
		}
	}

	fmt.Printf("Recovered entries: %d / 50\n", recoveredCount)

	stats, err := db2.GetStats()
	if err != nil {
		return err
	}
	fmt.Println("Database stats after recovery:")
	fmt.Printf("Total operations: %d\n", stats["total_operations"])
	fmt.Printf("Memtable entries: %d\n", stats["lsm_memtable_entries"])

	fmt.Println("\nRecovery test completed successfully!")
	return nil
}
