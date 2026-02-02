package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/lib/pq"
	"gopkg.in/yaml.v3"
)

type Config struct {
	Database struct {
		Host     string `yaml:"host"`
		Port     string `yaml:"port"`
		User     string `yaml:"user"`
		Password string `yaml:"password"`
		Name     string `yaml:"dbname"`
		SSLMode  string `yaml:"sslmode"`
	} `yaml:"database"`
}

func loadConfig(path string) (*Config, error) {
	file, err := os.ReadFile(path)
	if err != nil {
		return &Config{}, err
	}
	var cfg Config
	if err := yaml.Unmarshal(file, &cfg); err != nil {
		log.Fatalf("Parse error: %v", err)
		return &Config{}, err
	}
	return &cfg, nil
}

func main() {
	// Читаем конфиг-файл
	configPath := os.Getenv("CONFIG_PATH")
	if configPath == "" {
		configPath = "/etc/backend-api/config.yaml"
	}
	log.Printf("CONFIG_PATH = %s", configPath)

	content, err := os.ReadFile(configPath)
	if err != nil {
		log.Printf("ERROR reading file: %v", err)
	} else {
		log.Printf("Raw file (%d bytes): %s", len(content), string(content))
	}

	cfg, _ := loadConfig(configPath)

	// Читаем из окружения, если есть
	dbHost := os.Getenv("DB_HOST")
	if dbHost == "" {
		dbHost = cfg.Database.Host
	}
	dbPort := os.Getenv("DB_PORT")
	if dbPort == "" {
		dbPort = cfg.Database.Port
	}
	dbUser := os.Getenv("DB_USER")
	if dbUser == "" {
		dbUser = cfg.Database.User
	}
	dbPassword := os.Getenv("DB_PASSWORD")
	if dbPassword == "" {
		dbPassword = cfg.Database.Password
	}
	dbName := os.Getenv("DB_NAME")
	if dbName == "" {
		dbName = cfg.Database.Name
	}
	sslMode := os.Getenv("DB_SSLMODE")
	if sslMode == "" {
		sslMode = cfg.Database.SSLMode
	}
	if sslMode == "" {
		sslMode = "disable"
	}

	log.Printf("Parsed Config: host='%s', port='%s', user='%s', dbname='%s', sslmode='%s'",
		cfg.Database.Host, cfg.Database.Port, cfg.Database.User,
		cfg.Database.Name, cfg.Database.SSLMode)

	log.Printf("ENV: DB_HOST='%s', DB_PORT='%s', DB_USER='%s', DB_NAME='%s'",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"),
		os.Getenv("DB_USER"), os.Getenv("DB_NAME"))

	// DSN для PostgreSQL
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		dbHost, dbPort, dbUser, dbPassword, dbName, sslMode,
	)

	log.Println("DSN:", dsn)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("Ошибка подключения к БД: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("БД недоступна: %v", err)
	}

	log.Println("Backend API запущен на :8080")

	http.HandleFunc("/user", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		row := db.QueryRow("SELECT id, name, age FROM users WHERE id = $1", id)
		var u struct {
			ID   int    `json:"id"`
			Name string `json:"name"`
			Age  int    `json:"age"`
		}
		if err := row.Scan(&u.ID, &u.Name, &u.Age); err != nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		json.NewEncoder(w).Encode(u)
	})

	log.Fatal(http.ListenAndServe(":8080", nil))
}
