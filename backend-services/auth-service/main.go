package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/jackc/pgx/v4/stdlib"
	"github.com/joho/godotenv"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

// App struct (para injeção de dependência)
type App struct {
	DB         *sql.DB
	MasterKey  string
}

func main() {
	// Carrega o .env para desenvolvimento local. Em produção, isso não fará nada.
	_ = godotenv.Load()

	// Inicializa OpenTelemetry
	ctxCtx := context.Background()
	shutdown, errOtel := InitTelemetry(ctxCtx, "auth-service")
	if errOtel != nil {
		log.Fatalf("Falha ao iniciar telemetria: %v", errOtel)
	}
	defer shutdown()

	// --- Configuração ---
	port := os.Getenv("PORT")
	if port == "" {
		port = "8001" // Porta padrão
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL deve ser definida")
	}

	masterKey := os.Getenv("MASTER_KEY")
	if masterKey == "" {
		log.Fatal("MASTER_KEY deve ser definida")
	}

	// --- Conexão com o Banco ---
	db, err := connectDB(databaseURL)
	if err != nil {
		log.Fatalf("Não foi possível conectar ao banco de dados: %v", err)
	}
	defer db.Close()

	// --- Executar Migrações ---
	if err := runMigrations(db); err != nil {
		log.Fatalf("Erro ao executar migrações: %v", err)
	}

	app := &App{
		DB:         db,
		MasterKey:  masterKey,
	}

	// --- Rotas da API ---
	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.healthHandler)

	// Endpoint público para validar uma chave
	mux.HandleFunc("/validate", app.validateKeyHandler)

	// Endpoints de "admin" para criar/gerenciar chaves
	// Eles são protegidos pelo middleware de autenticação
	mux.Handle("/admin/keys", app.masterKeyAuthMiddleware(http.HandlerFunc(app.createKeyHandler)))

	log.Printf("Serviço de Autenticação (Go) rodando na porta %s", port)
	handler := corsMiddleware(mux)
	
	// Wrap Handler com OpenTelemetry
	otelHandler := otelhttp.NewHandler(handler, "auth-service")
	if err := http.ListenAndServe(":"+port, otelHandler); err != nil {
		log.Fatal(err)
	}
}

// corsMiddleware adiciona headers CORS para permitir requisições do frontend
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-API-Key")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// connectDB inicializa e tenta a conexão com o PostgreSQL com retentativas
func connectDB(databaseURL string) (*sql.DB, error) {
	var db *sql.DB
	var err error

	for i := 1; i <= 5; i++ {
		db, err = sql.Open("pgx", databaseURL)
		if err == nil {
			err = db.Ping()
			if err == nil {
				log.Println("Conectado ao PostgreSQL com sucesso!")
				return db, nil
			}
		}

		log.Printf("Tentativa %d: Falha ao conectar ao banco de dados (%v). Tentando novamente em 5 segundos...", i, err)
		if db != nil {
			db.Close()
		}
		time.Sleep(5 * time.Second)
	}

	return nil, fmt.Errorf("após 5 tentativas, não foi possível conectar ao banco de dados: %v", err)
}

// runMigrations executa as migrações necessárias no banco de dados
func runMigrations(db *sql.DB) error {
	// Criar tabela api_keys se não existir (mesma estrutura do db/init.sql)
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS api_keys (
		id SERIAL PRIMARY KEY,
		name VARCHAR(100) NOT NULL,
		key_hash VARCHAR(64) NOT NULL UNIQUE,
		is_active BOOLEAN DEFAULT true,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
	);
	`

	_, err := db.Exec(createTableSQL)
	if err != nil {
		return fmt.Errorf("erro ao criar tabela api_keys: %v", err)
	}

	log.Println("Migração executada com sucesso! Tabela api_keys verificada.")
	return nil
}