package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// MinIO Event Notification structure
type MinIOEvent struct {
	EventName string    `json:"EventName"`
	Key       string    `json:"Key"`
	Records   []Record  `json:"Records"`
}

type Record struct {
	EventVersion string    `json:"eventVersion"`
	EventSource  string    `json:"eventSource"`
	EventTime    string    `json:"eventTime"`
	EventName    string    `json:"eventName"`
	S3           S3Data    `json:"s3"`
}

type S3Data struct {
	Bucket BucketInfo `json:"bucket"`
	Object ObjectInfo `json:"object"`
}

type BucketInfo struct {
	Name string `json:"name"`
	ARN  string `json:"arn"`
}

type ObjectInfo struct {
	Key         string `json:"key"`
	Size        int64  `json:"size"`
	ETag        string `json:"eTag"`
	ContentType string `json:"contentType"`
}

// Log entry structure (what we store in MinIO)
type LogEntry struct {
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	Level     string    `json:"level"`
	Message   string    `json:"message"`
	Service   string    `json:"service"`
}

// OpenSearch document
type OpenSearchDoc struct {
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	Level     string    `json:"level"`
	Message   string    `json:"message"`
	Service   string    `json:"service"`
	Bucket    string    `json:"bucket"`
	ObjectKey string    `json:"object_key"`
	IndexedAt time.Time `json:"indexed_at"`
}

var (
	minioClient     *minio.Client
	opensearchURL   string
)

func main() {
	endpoint := getEnv("MINIO_ENDPOINT", "minio:9000")
	accessKey := getEnv("MINIO_ACCESS_KEY", "myminio")
	secretKey := getEnv("MINIO_SECRET_KEY", "minio123")
	useSSL := getEnv("MINIO_USE_SSL", "false") == "true"
	opensearchURL = getEnv("OPENSEARCH_URL", "http://opensearch:9200")

	var err error
	minioClient, err = minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		log.Fatalf("Failed to create MinIO client: %v", err)
	}

	// Wait for services to be ready
	waitForServices()

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/webhook", webhookHandler)

	port := getEnv("PORT", "8081")
	log.Printf("Webhook service starting on port %s", port)
	log.Printf("OpenSearch URL: %s", opensearchURL)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func waitForServices() {
	// Wait for MinIO
	ctx := context.Background()
	for i := 0; i < 30; i++ {
		_, err := minioClient.ListBuckets(ctx)
		if err == nil {
			log.Println("MinIO is ready")
			break
		}
		log.Printf("Waiting for MinIO... (%d/30)", i+1)
		time.Sleep(2 * time.Second)
	}

	// Wait for OpenSearch
	for i := 0; i < 30; i++ {
		resp, err := http.Get(opensearchURL + "/_cluster/health")
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			log.Println("OpenSearch is ready")
			break
		}
		if resp != nil {
			resp.Body.Close()
		}
		log.Printf("Waiting for OpenSearch... (%d/30)", i+1)
		time.Sleep(2 * time.Second)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func webhookHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		log.Printf("Error reading body: %v", err)
		http.Error(w, "Error reading body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	log.Printf("Received webhook: %s", string(body))

	var event MinIOEvent
	if err := json.Unmarshal(body, &event); err != nil {
		log.Printf("Error parsing event: %v", err)
		http.Error(w, "Error parsing event", http.StatusBadRequest)
		return
	}

	// Process each record
	for _, record := range event.Records {
		// Only process s3:ObjectCreated events
		if !strings.HasPrefix(record.EventName, "s3:ObjectCreated") {
			log.Printf("Skipping event: %s", record.EventName)
			continue
		}

		bucket := record.S3.Bucket.Name
		objectKey := record.S3.Object.Key

		// Skip non-JSON files
		if !strings.HasSuffix(objectKey, ".json") {
			log.Printf("Skipping non-JSON file: %s", objectKey)
			continue
		}

		log.Printf("Processing: bucket=%s, key=%s", bucket, objectKey)

		// Read object content from MinIO
		if err := processObject(bucket, objectKey); err != nil {
			log.Printf("Error processing object: %v", err)
			continue
		}
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "processed"})
}

func processObject(bucket, objectKey string) error {
	ctx := context.Background()

	// Get object from MinIO
	obj, err := minioClient.GetObject(ctx, bucket, objectKey, minio.GetObjectOptions{})
	if err != nil {
		return fmt.Errorf("failed to get object: %w", err)
	}
	defer obj.Close()

	// Read content
	content, err := io.ReadAll(obj)
	if err != nil {
		return fmt.Errorf("failed to read object: %w", err)
	}

	// Parse log entry
	var logEntry LogEntry
	if err := json.Unmarshal(content, &logEntry); err != nil {
		return fmt.Errorf("failed to parse log entry: %w", err)
	}

	// Create OpenSearch document
	doc := OpenSearchDoc{
		ID:        logEntry.ID,
		Timestamp: logEntry.Timestamp,
		Level:     logEntry.Level,
		Message:   logEntry.Message,
		Service:   logEntry.Service,
		Bucket:    bucket,
		ObjectKey: objectKey,
		IndexedAt: time.Now().UTC(),
	}

	// Index in OpenSearch
	if err := indexDocument(doc); err != nil {
		return fmt.Errorf("failed to index document: %w", err)
	}

	log.Printf("Indexed: id=%s, level=%s, message=%s", doc.ID, doc.Level, doc.Message)
	return nil
}

func indexDocument(doc OpenSearchDoc) error {
	indexName := fmt.Sprintf("app-logs-%s", time.Now().Format("2006.01.02"))

	jsonData, err := json.Marshal(doc)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/%s/_doc/%s", opensearchURL, indexName, doc.ID)
	req, err := http.NewRequest(http.MethodPut, url, bytes.NewReader(jsonData))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("opensearch error: %s - %s", resp.Status, string(body))
	}

	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
