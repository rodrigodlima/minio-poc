package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type LogEntry struct {
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	Level     string    `json:"level"`
	Message   string    `json:"message"`
	Service   string    `json:"service"`
}

type LogRequest struct {
	Level   string `json:"level"`
	Message string `json:"message"`
}

var (
	minioClient *minio.Client
	bucketName  = "app-logs"
)

func main() {
	endpoint := getEnv("MINIO_ENDPOINT", "minio:9000")
	accessKey := getEnv("MINIO_ACCESS_KEY", "myminio")
	secretKey := getEnv("MINIO_SECRET_KEY", "minio")
	useSSL := getEnv("MINIO_USE_SSL", "false") == "true"

	var err error
	minioClient, err = minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		log.Fatalf("Failed to create MinIO client: %v", err)
	}

	// Wait for MinIO to be ready and create bucket
	ctx := context.Background()
	for i := 0; i < 30; i++ {
		exists, err := minioClient.BucketExists(ctx, bucketName)
		if err == nil {
			if !exists {
				err = minioClient.MakeBucket(ctx, bucketName, minio.MakeBucketOptions{})
				if err != nil {
					log.Printf("Failed to create bucket: %v", err)
				} else {
					log.Printf("Bucket '%s' created successfully", bucketName)
				}
			} else {
				log.Printf("Bucket '%s' already exists", bucketName)
			}
			break
		}
		log.Printf("Waiting for MinIO... (%d/30)", i+1)
		time.Sleep(2 * time.Second)
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/logs", logsHandler)
	http.HandleFunc("/logs/", logByIDHandler)
	http.HandleFunc("/generate", generateLogsHandler)

	port := getEnv("PORT", "8080")
	log.Printf("API server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func logsHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case http.MethodPost:
		var req LogRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "invalid request body"}`, http.StatusBadRequest)
			return
		}

		entry := LogEntry{
			ID:        uuid.New().String(),
			Timestamp: time.Now().UTC(),
			Level:     req.Level,
			Message:   req.Message,
			Service:   "go-api",
		}

		data, _ := json.Marshal(entry)
		objectName := fmt.Sprintf("%s/%s.json", time.Now().Format("2006-01-02"), entry.ID)

		_, err := minioClient.PutObject(ctx, bucketName, objectName, strings.NewReader(string(data)), int64(len(data)), minio.PutObjectOptions{
			ContentType: "application/json",
		})
		if err != nil {
			log.Printf("Failed to store log: %v", err)
			http.Error(w, `{"error": "failed to store log"}`, http.StatusInternalServerError)
			return
		}

		log.Printf("Log stored: %s", objectName)
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(entry)

	case http.MethodGet:
		var logs []LogEntry
		objectCh := minioClient.ListObjects(ctx, bucketName, minio.ListObjectsOptions{
			Recursive: true,
		})

		for object := range objectCh {
			if object.Err != nil {
				continue
			}

			obj, err := minioClient.GetObject(ctx, bucketName, object.Key, minio.GetObjectOptions{})
			if err != nil {
				continue
			}

			var entry LogEntry
			if err := json.NewDecoder(obj).Decode(&entry); err == nil {
				logs = append(logs, entry)
			}
			obj.Close()
		}

		json.NewEncoder(w).Encode(logs)

	default:
		http.Error(w, `{"error": "method not allowed"}`, http.StatusMethodNotAllowed)
	}
}

func logByIDHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	w.Header().Set("Content-Type", "application/json")

	id := strings.TrimPrefix(r.URL.Path, "/logs/")
	if id == "" {
		http.Error(w, `{"error": "id required"}`, http.StatusBadRequest)
		return
	}

	objectCh := minioClient.ListObjects(ctx, bucketName, minio.ListObjectsOptions{
		Recursive: true,
	})

	for object := range objectCh {
		if object.Err != nil || !strings.Contains(object.Key, id) {
			continue
		}

		obj, err := minioClient.GetObject(ctx, bucketName, object.Key, minio.GetObjectOptions{})
		if err != nil {
			continue
		}
		defer obj.Close()

		var entry LogEntry
		if err := json.NewDecoder(obj).Decode(&entry); err == nil {
			json.NewEncoder(w).Encode(entry)
			return
		}
	}

	http.Error(w, `{"error": "log not found"}`, http.StatusNotFound)
}

func generateLogsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error": "method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	ctx := context.Background()
	w.Header().Set("Content-Type", "application/json")

	levels := []string{"INFO", "WARN", "ERROR", "DEBUG"}
	messages := []string{
		"User logged in successfully",
		"Database connection established",
		"Cache miss for key: user_session",
		"API request processed in 45ms",
		"Failed to fetch external resource",
		"Retry attempt 1 for operation",
		"Configuration loaded from environment",
		"Background job completed",
		"Memory usage above threshold",
		"New connection from client",
	}

	count := 10
	var created []LogEntry

	for i := 0; i < count; i++ {
		entry := LogEntry{
			ID:        uuid.New().String(),
			Timestamp: time.Now().UTC(),
			Level:     levels[i%len(levels)],
			Message:   messages[i%len(messages)],
			Service:   "go-api",
		}

		data, _ := json.Marshal(entry)
		objectName := fmt.Sprintf("%s/%s.json", time.Now().Format("2006-01-02"), entry.ID)

		_, err := minioClient.PutObject(ctx, bucketName, objectName, strings.NewReader(string(data)), int64(len(data)), minio.PutObjectOptions{
			ContentType: "application/json",
		})
		if err != nil {
			log.Printf("Failed to store log: %v", err)
			continue
		}

		created = append(created, entry)
		log.Printf("Generated log: %s - %s", entry.Level, entry.Message)
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": fmt.Sprintf("Generated %d logs", len(created)),
		"logs":    created,
	})
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
