import os
import sys
import psycopg2
import requests
from psycopg2.extras import RealDictCursor
from psycopg2.pool import SimpleConnectionPool
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from functools import wraps
import logging

# touch: trigger CI GitOps rebuild (2026-05-23 v3)

# Configura o logging
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# Carrega .env para desenvolvimento local
load_dotenv() 

app = Flask(__name__)
CORS(app, resources={
    r"/*": {
        "origins": "*",
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Authorization", "Content-Type", "X-API-Key"]
    }
})

# --- Configuração ---
DATABASE_URL = os.getenv("DATABASE_URL")
AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL")

if not DATABASE_URL or not AUTH_SERVICE_URL:
    log.critical("Erro: DATABASE_URL e AUTH_SERVICE_URL devem ser definidos.")
    sys.exit(1)

# --- Pool de Conexão com o Banco ---
# Inicializa o pool de conexões (Mín: 1, Máx: 5 conexões)
try:
    pool = SimpleConnectionPool(1, 5, dsn=DATABASE_URL)
    log.info("Pool de conexões com o PostgreSQL inicializado.")
except psycopg2.OperationalError as e:
    log.critical(f"Erro fatal ao conectar ao PostgreSQL: {e}")
    sys.exit(1)

def init_db():
    """Inicializa o banco de dados executando o script SQL se necessário"""
    init_sql_path = os.path.join(os.path.dirname(__file__), 'db', 'init.sql')
    if not os.path.exists(init_sql_path):
        log.warning(f"Script de inicialização não encontrado em {init_sql_path}")
        return

    conn = None
    try:
        log.info("Executando scripts de inicialização do banco de dados...")
        conn = pool.getconn()
        with conn.cursor() as cur:
            with open(init_sql_path, 'r') as f:
                cur.execute(f.read())
        conn.commit()
        log.info("Banco de dados inicializado com sucesso.")
    except Exception as e:
        log.error(f"Erro ao inicializar o banco de dados: {e}")
    finally:
        if conn:
            pool.putconn(conn)

# Inicializa o banco ao subir a aplicação
init_db()

# --- Middleware de Autenticação ---
def require_auth(f):
    """ Middleware para validar a chave de API contra o auth-service """
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization")
        if not auth_header:
            return jsonify({"error": "Authorization header obrigatório"}), 401
        
        try:
            # Chama o /validate do auth-service
            validate_url = f"{AUTH_SERVICE_URL}/validate"
            response = requests.get(validate_url, headers={"Authorization": auth_header}, timeout=3)
            
            if response.status_code != 200:
                log.warning(f"Falha na validação da chave (status: {response.status_code})")
                return jsonify({"error": "Chave de API inválida"}), 401
        
        except requests.exceptions.Timeout:
            log.error("Timeout ao conectar com o auth-service")
            return jsonify({"error": "Serviço de autenticação indisponível (timeout)"}), 504 # Gateway Timeout
        except requests.exceptions.RequestException as e:
            log.error(f"Erro ao conectar com o auth-service: {e}")
            return jsonify({"error": "Serviço de autenticação indisponível"}), 503 # Service Unavailable

        # Se a chave for válida, continua para a rota
        return f(*args, **kwargs)
    return decorated

# --- Endpoints da API ---

@app.route('/health')
def health():
    return jsonify({"status": "ok"})

@app.route('/flags', methods=['POST'])
@require_auth
def create_flag():
    """ Cria uma nova definição de feature flag """
    data = request.get_json()
    if not data or 'name' not in data:
        return jsonify({"error": "'name' é obrigatório"}), 400
    
    name = data['name']
    description = data.get('description', '')
    is_enabled = data.get('is_enabled', False)
    
    conn = None
    cur = None
    try:
        conn = pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "INSERT INTO flags (name, description, is_enabled, created_at, updated_at) "
            "VALUES (%s, %s, %s, NOW(), NOW()) RETURNING *",
            (name, description, is_enabled)
        )
        new_flag = cur.fetchone()
        conn.commit()
        log.info(f"Flag '{name}' criada com sucesso.")
        return jsonify(new_flag), 201
    except psycopg2.IntegrityError:
        if conn: conn.rollback()
        log.warning(f"Tentativa de criar flag duplicada: '{name}'")
        return jsonify({"error": f"Flag '{name}' já existe"}), 409
    except Exception as e:
        if conn: conn.rollback()
        log.error(f"Erro ao criar flag: {e}")
        return jsonify({"error": "Erro interno do servidor", "details": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: pool.putconn(conn)

@app.route('/flags', methods=['GET'])
@require_auth
def get_flags():
    """ Lista todas as feature flags """
    conn = None
    cur = None
    try:
        conn = pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM flags ORDER BY name")
        flags = cur.fetchall()
        return jsonify(flags)
    except Exception as e:
        log.error(f"Erro ao buscar flags: {e}")
        return jsonify({"error": "Erro interno do servidor", "details": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: pool.putconn(conn)

@app.route('/flags/<string:name>', methods=['GET'])
@require_auth
def get_flag(name):
    """ Busca uma feature flag específica pelo nome """
    conn = None
    cur = None
    try:
        conn = pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM flags WHERE name = %s", (name,))
        flag = cur.fetchone()
        if not flag:
            return jsonify({"error": "Flag não encontrada"}), 404
        return jsonify(flag)
    except Exception as e:
        log.error(f"Erro ao buscar flag '{name}': {e}")
        return jsonify({"error": "Erro interno do servidor", "details": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: pool.putconn(conn)

@app.route('/flags/<string:name>', methods=['PUT'])
@require_auth
def update_flag(name):
    """ Atualiza uma feature flag (descrição ou status 'is_enabled') """
    data = request.get_json()
    if not data:
        return jsonify({"error": "Corpo da requisição obrigatório"}), 400

    fields = []
    values = []
    
    # Constrói a query dinamicamente
    if 'description' in data:
        fields.append("description = %s")
        values.append(data['description'])
    if 'is_enabled' in data:
        fields.append("is_enabled = %s")
        values.append(data['is_enabled'])
    
    if not fields:
        return jsonify({"error": "Pelo menos um campo ('description', 'is_enabled') é obrigatório"}), 400
    
    values.append(name) # Adiciona o 'name' para a cláusula WHERE
    
    query = f"UPDATE flags SET {', '.join(fields)} WHERE name = %s RETURNING *"
    
    conn = None
    cur = None
    try:
        conn = pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(query, tuple(values))
        
        if cur.rowcount == 0:
            return jsonify({"error": "Flag não encontrada"}), 404
            
        updated_flag = cur.fetchone()
        conn.commit()
        log.info(f"Flag '{name}' atualizada com sucesso.")
        return jsonify(updated_flag), 200
    except Exception as e:
        if conn: conn.rollback()
        log.error(f"Erro ao atualizar flag '{name}': {e}")
        return jsonify({"error": "Erro interno do servidor", "details": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: pool.putconn(conn)

@app.route('/flags/<string:name>', methods=['DELETE'])
@require_auth
def delete_flag(name):
    """ Deleta uma feature flag """
    conn = None
    cur = None
    try:
        conn = pool.getconn()
        cur = conn.cursor()
        cur.execute("DELETE FROM flags WHERE name = %s", (name,))
        
        if cur.rowcount == 0:
            return jsonify({"error": "Flag não encontrada"}), 404
            
        conn.commit()
        log.info(f"Flag '{name}' deletada com sucesso.")
        return "", 204 # 204 No Content
    except Exception as e:
        if conn: conn.rollback()
        log.error(f"Erro ao deletar flag '{name}': {e}")
        return jsonify({"error": "Erro interno do servidor", "details": str(e)}), 500
    finally:
        if cur: cur.close()
        if conn: pool.putconn(conn)

if __name__ == '__main__':
    port = int(os.getenv("PORT", 8002))
    app.run(host='0.0.0.0', port=port, debug=False)