package main

// touch: trigger CI GitOps rebuild (2026-05-23)

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
	"github.com/go-redis/redis/v8"
	"github.com/joho/godotenv"
)

// Contexto global para o Redis
var ctx = context.Background()

// App struct para injeção de dependência
type App struct {
	RedisClient         *redis.Client
	SqsSvc              *sqs.SQS
	SqsQueueURL         string
	HttpClient          *http.Client
	FlagServiceURL      string
	TargetingServiceURL string
}

func main() {
	_ = godotenv.Load() // Carrega .env para dev local

	// --- Configuração ---
	port := os.Getenv("PORT")
	if port == "" {
		port = "8004"
	}

	// Tenta obter a chave automaticamente se não estiver definida
	ensureServiceKey()

	flagSvcURL := os.Getenv("FLAG_SERVICE_URL")
	if flagSvcURL == "" {
		log.Fatal("FLAG_SERVICE_URL deve ser definida")
	}

	targetingSvcURL := os.Getenv("TARGETING_SERVICE_URL")
	if targetingSvcURL == "" {
		log.Fatal("TARGETING_SERVICE_URL deve ser definida")
	}

	// SQS é opcional no dev local, mas obrigatório em prod
	sqsQueueURL := os.Getenv("AWS_SQS_URL")
	awsRegion := os.Getenv("AWS_REGION")
	if sqsQueueURL == "" {
		log.Println("Atenção: AWS_SQS_URL não definida. Eventos não serão enviados.")
	}
	if awsRegion == "" && sqsQueueURL != "" {
		log.Fatal("AWS_REGION deve ser definida para usar SQS")
	}

	// --- Inicializa Clientes ---

	// Cliente Redis
	redisHost := os.Getenv("REDIS_HOST")
	if redisHost == "" {
		log.Fatal("REDIS_HOST deve ser definida")
	}

	log.Printf("Conectando ao Redis em: %s", redisHost)

	// Configura TLS (necessário para ElastiCache Serverless)
	redisTLS := os.Getenv("REDIS_TLS") == "true"

	opts := &redis.Options{
		Addr:         redisHost,
		DialTimeout:  30 * time.Second,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		PoolTimeout:  30 * time.Second,
		PoolSize:     10,
	}

	// Configura TLS ANTES de criar o cliente
	if redisTLS {
		opts.TLSConfig = &tls.Config{
			MinVersion: tls.VersionTLS12,
		}
		log.Println("TLS habilitado para conexão Redis")
	}

	rdb := redis.NewClient(opts)

	// Verifica conexão com Redis
	pingCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	_, err := rdb.Ping(pingCtx).Result()
	cancel()
	if err != nil {
		log.Fatalf("Não foi possível conectar ao Redis: %v", err)
	}
	log.Println("Conectado ao Redis com sucesso!")

	// Cliente SQS (AWS SDK)
	var sqsSvc *sqs.SQS
	if sqsQueueURL != "" {
		endpointURL := os.Getenv("AWS_SQS_ENDPOINT_URL")
		awsConfig := &aws.Config{
			Region: aws.String(awsRegion),
		}

		if endpointURL != "" {
			awsConfig.Endpoint = aws.String(endpointURL)
			// Para LocalStack, geralmente desabilitamos TLS e usamos path-style se necessário,
			// mas para SQS o endpoint direto costuma bastar.
			log.Printf("Usando endpoint AWS customizado: %s", endpointURL)
		}

		sess, err := session.NewSession(awsConfig)
		if err != nil {
			log.Fatalf("Não foi possível criar sessão AWS: %v", err)
		}
		sqsSvc = sqs.New(sess)
		log.Println("Cliente SQS inicializado com sucesso.")
	}

	// Cliente HTTP (com timeout)
	httpClient := &http.Client{
		Timeout: 5 * time.Second,
	}

	// Cria a instância da App
	app := &App{
		RedisClient:         rdb,
		SqsSvc:              sqsSvc,
		SqsQueueURL:         sqsQueueURL,
		HttpClient:          httpClient,
		FlagServiceURL:      flagSvcURL,
		TargetingServiceURL: targetingSvcURL,
	}

	// --- Rotas ---
	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.healthHandler)
	mux.HandleFunc("/evaluate", app.evaluationHandler)

	log.Printf("Serviço de Avaliação (Go) rodando na porta %s", port)
	handler := corsMiddleware(mux)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
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

// ensureServiceKey garante que o serviço tenha uma chave de API válida
func ensureServiceKey() {
	apiKey := os.Getenv("SERVICE_API_KEY")
	if apiKey != "" {
		log.Println("Usando SERVICE_API_KEY fornecida via ambiente.")
		return
	}

	authURL := os.Getenv("AUTH_SERVICE_URL")
	masterKey := os.Getenv("MASTER_KEY")
	if authURL == "" || masterKey == "" {
		log.Println("Aviso: SERVICE_API_KEY não definida e AUTH_SERVICE_URL/MASTER_KEY ausentes. O serviço pode falhar ao chamar outros microsserviços.")
		return
	}

	log.Println("SERVICE_API_KEY não encontrada. Tentando gerar automaticamente via auth-service...")

	client := &http.Client{Timeout: 5 * time.Second}
	maxRetries := 15
	var generatedKey string

	for i := 0; i < maxRetries; i++ {
		key, err := requestNewKey(client, authURL, masterKey)
		if err == nil {
			generatedKey = key
			break
		}
		log.Printf("Tentativa %d/%d: %v. Retentando em 3s...", i+1, maxRetries, err)
		time.Sleep(3 * time.Second)
	}

	if generatedKey == "" {
		log.Fatal("Erro fatal: Não foi possível obter SERVICE_API_KEY após várias tentativas. Verifique se o auth-service está saudável.")
	}

	if err := os.Setenv("SERVICE_API_KEY", generatedKey); err != nil {
		log.Fatalf("Erro ao configurar SERVICE_API_KEY no ambiente: %v", err)
	}
	log.Println("SERVICE_API_KEY obtida e configurada com sucesso!")
}

func requestNewKey(client *http.Client, authURL, masterKey string) (string, error) {
	url := authURL + "/admin/keys"
	body, err := json.Marshal(map[string]string{"name": "evaluation-service-auto"})
	if err != nil {
		return "", fmt.Errorf("erro ao serializar payload para auth-service: %w", err)
	}
	
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(body)) // #nosec G107,G704 -- URL interna controlada por ambiente do serviço
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+masterKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req) // #nosec G704 -- destino restrito ao auth-service interno
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		return "", fmt.Errorf("auth-service retornou status %d", resp.StatusCode)
	}

	var res struct {
		Key string `json:"key"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return "", err
	}

	if res.Key == "" {
		return "", fmt.Errorf("chave vazia retornada pelo auth-service")
	}

	return res.Key, nil
}