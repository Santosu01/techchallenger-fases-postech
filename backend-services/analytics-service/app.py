import os
import sys
import threading
import json
import uuid
import time
import logging
import boto3
from botocore.exceptions import NoCredentialsError, ClientError, BotoCoreError
from flask import Flask, jsonify, request
from flask_cors import CORS
from dotenv import load_dotenv

# --- Configuração OpenTelemetry ---
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Configura o logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
log = logging.getLogger(__name__)

# Carrega .env para desenvolvimento local
load_dotenv()

otel_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "otel-collector.monitoring.svc.cluster.local:4317")
if not otel_endpoint.startswith("http"):
    otel_endpoint = f"http://{otel_endpoint}"

resource = Resource.create(attributes={"service.name": "analytics-service"})
provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=otel_endpoint, insecure=True))
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

# Instrumenta chamadas HTTP de saída
RequestsInstrumentor().instrument()

# --- Configuração ---
AWS_REGION = os.getenv("AWS_REGION")
SQS_QUEUE_URL = os.getenv("AWS_SQS_URL")
DYNAMODB_TABLE_NAME = os.getenv("AWS_DYNAMODB_TABLE")
AWS_SQS_ENDPOINT_URL = os.getenv("AWS_SQS_ENDPOINT_URL") or None
AWS_DYNAMODB_ENDPOINT_URL = os.getenv("AWS_DYNAMODB_ENDPOINT_URL") or None

if not all([AWS_REGION, SQS_QUEUE_URL, DYNAMODB_TABLE_NAME]):
    log.critical("Erro: AWS_REGION, AWS_SQS_URL, e AWS_DYNAMODB_TABLE devem ser definidos.")
    sys.exit(1)

# --- Clientes Boto3 (Lazy Initialization) ---
sqs_client = None
dynamodb_client = None
clients_initialized = False

def get_boto3_clients():
    """
    Inicializa clientes boto3 de forma lazy com retry automático.
    Retorna (sqs_client, dynamodb_client) ou (None, None) se falhar.
    """
    global sqs_client, dynamodb_client, clients_initialized

    if clients_initialized and sqs_client and dynamodb_client:
        return sqs_client, dynamodb_client

    try:
        session = boto3.Session(region_name=AWS_REGION)
        sqs_client = session.client("sqs", endpoint_url=AWS_SQS_ENDPOINT_URL)
        dynamodb_client = session.client("dynamodb", endpoint_url=AWS_DYNAMODB_ENDPOINT_URL)
        clients_initialized = True
        log.info(f"Clientes Boto3 inicializados na região {AWS_REGION}")
        return sqs_client, dynamodb_client
    except NoCredentialsError:
        log.warning("Credenciais AWS não encontradas. Tentando novamente mais tarde...")
        return None, None
    except Exception as e:
        log.warning(f"Erro ao inicializar Boto3: {e}. Tentando novamente mais tarde...")
        return None, None

def ensure_table():
    """
    Garante que a tabela do DynamoDB exista.
    Não bloqueia a inicialização se falhar.
    """
    _, db_client = get_boto3_clients()
    if not db_client:
        log.warning("Cliente DynamoDB não disponível. Tabela será verificada posteriormente.")
        return False

    max_retries = 5
    for i in range(max_retries):
        try:
            db_client.create_table(
                TableName=DYNAMODB_TABLE_NAME,
                AttributeDefinitions=[
                    {'AttributeName': 'event_id', 'AttributeType': 'S'}
                ],
                KeySchema=[
                    {'AttributeName': 'event_id', 'KeyType': 'HASH'}
                ],
                ProvisionedThroughput={
                    'ReadCapacityUnits': 5,
                    'WriteCapacityUnits': 5
                }
            )
            log.info(f"Tabela {DYNAMODB_TABLE_NAME} criada com sucesso.")
            return True
        except db_client.exceptions.ResourceInUseException:
            log.info(f"Tabela {DYNAMODB_TABLE_NAME} já existe.")
            return True
        except Exception as e:
            log.warning(f"Tentativa {i+1}/{max_retries} - Erro ao verificar tabela: {e}")
            if i < max_retries - 1:
                time.sleep(2)

    log.warning("Não foi possível verificar a tabela DynamoDB. Continuando mesmo assim...")
    return False

# Tenta inicializar a tabela (não bloqueia se falhar)
ensure_table()


# --- SQS Worker ---

def process_message(message):
    """Processa uma única mensagem SQS e a insere no DynamoDB"""
    sqs, db = get_boto3_clients()
    if not sqs or not db:
        log.error("Clientes AWS não disponíveis para processar mensagem")
        return False

    try:
        log.info(f"Processando mensagem ID: {message['MessageId']}")
        body = json.loads(message['Body'])

        # Gera um ID único para o item no DynamoDB
        event_id = str(uuid.uuid4())

        # Constrói o item no formato do DynamoDB
        item = {
            'event_id': {'S': event_id},
            'user_id': {'S': body['user_id']},
            'flag_name': {'S': body['flag_name']},
            'result': {'BOOL': body['result']},
            'timestamp': {'S': body['timestamp']}
        }

        # Insere no DynamoDB
        db.put_item(
            TableName=DYNAMODB_TABLE_NAME,
            Item=item
        )

        log.info(f"Evento {event_id} (Flag: {body['flag_name']}) salvo no DynamoDB.")

        # Se tudo deu certo, deleta a mensagem da fila
        sqs.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=message['ReceiptHandle']
        )
        return True

    except json.JSONDecodeError as e:
        log.error(f"JSON inválido na mensagem {message['MessageId']}: {e}. Deletando mensagem inválida.")
        # Deleta mensagem inválida para não travar a fila
        try:
            sqs.delete_message(
                QueueUrl=SQS_QUEUE_URL,
                ReceiptHandle=message['ReceiptHandle']
            )
        except Exception:
            pass
        return False
    except (KeyError, TypeError) as e:
        log.error(f"Estrutura inválida na mensagem {message['MessageId']}: {e}. Deletando mensagem inválida.")
        # Deleta mensagem com estrutura inválida
        try:
            sqs.delete_message(
                QueueUrl=SQS_QUEUE_URL,
                ReceiptHandle=message['ReceiptHandle']
            )
        except Exception:
            pass
        return False
    except ClientError as e:
        log.error(f"Erro do Boto3 ao processar {message['MessageId']}: {e}")
        return False
    except Exception as e:
        log.error(f"Erro inesperado ao processar {message['MessageId']}: {e}")
        return False

def sqs_worker_loop():
    """Loop principal do worker que ouve a fila SQS com reconexão automática"""
    log.info("Iniciando o worker SQS...")

    while True:
        sqs, _ = get_boto3_clients()

        if not sqs:
            log.warning("Cliente SQS não disponível. Aguardando 10s para reconectar...")
            time.sleep(10)
            continue

        try:
            # Long-polling: espera até 20s por mensagens
            response = sqs.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20
            )

            messages = response.get('Messages', [])
            if not messages:
                continue

            log.info(f"Recebidas {len(messages)} mensagens.")

            for message in messages:
                process_message(message)

        except NoCredentialsError:
            log.warning("Credenciais AWS expiradas. Tentando reconectar em 10s...")
            global clients_initialized
            clients_initialized = False
            time.sleep(10)
        except ClientError as e:
            log.error(f"Erro do Boto3 no loop SQS: {e}")
            time.sleep(10)
        except Exception as e:
            log.error(f"Erro inesperado no loop SQS: {e}")
            time.sleep(10)


# --- Servidor Flask (Health Check) ---

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)
CORS(app, resources={
    r"/*": {
        "origins": "*",
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Authorization", "Content-Type", "X-API-Key"]
    }
})

@app.route('/health')
def health():
    """Health check - verifica se o serviço está rodando"""
    sqs, db = get_boto3_clients()
    aws_status = "connected" if sqs and db else "connecting"
    return jsonify({
        "status": "ok",
        "aws": aws_status
    })

@app.route('/events')
def get_events():
    """Lista todos os eventos de avaliação do DynamoDB"""
    _, db = get_boto3_clients()
    if not db:
        return jsonify({"error": "DynamoDB não disponível"}), 503

    try:
        # Parâmetros de paginação
        limit = int(request.args.get('limit', 100))
        flag_name = request.args.get('flag_name')

        response = db.scan(TableName=DYNAMODB_TABLE_NAME, Limit=limit)
        items = response.get('Items', [])

        # Converte do formato DynamoDB para JSON normal
        events = []
        for item in items:
            event = {
                'event_id': item['event_id']['S'],
                'user_id': item['user_id']['S'],
                'flag_name': item['flag_name']['S'],
                'result': item['result']['BOOL'],
                'timestamp': item['timestamp']['S']
            }
            # Filtra por flag_name se especificado
            if flag_name and event['flag_name'] != flag_name:
                continue
            events.append(event)

        # Ordena por timestamp (mais recentes primeiro)
        events.sort(key=lambda x: x['timestamp'], reverse=True)

        return jsonify({
            "events": events,
            "count": len(events)
        })
    except Exception as e:
        log.error(f"Erro ao buscar eventos: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/events/stats')
def get_stats():
    """Retorna estatísticas agregadas dos eventos"""
    _, db = get_boto3_clients()
    if not db:
        return jsonify({"error": "DynamoDB não disponível"}), 503

    try:
        # Escaneia todos os itens
        response = db.scan(TableName=DYNAMODB_TABLE_NAME)
        items = response.get('Items', [])

        # Calcula estatísticas
        total_events = len(items)
        flag_stats = {}
        true_count = 0
        false_count = 0

        for item in items:
            flag_name = item['flag_name']['S']
            result = item['result']['BOOL']

            # Contagem por flag
            if flag_name not in flag_stats:
                flag_stats[flag_name] = {'total': 0, 'true': 0, 'false': 0}
            flag_stats[flag_name]['total'] += 1
            if result:
                flag_stats[flag_name]['true'] += 1
                true_count += 1
            else:
                flag_stats[flag_name]['false'] += 1
                false_count += 1

        return jsonify({
            "total_events": total_events,
            "true_results": true_count,
            "false_results": false_count,
            "flags": flag_stats
        })
    except Exception as e:
        log.error(f"Erro ao calcular estatísticas: {e}")
        return jsonify({"error": str(e)}), 500

# --- Inicialização ---

def start_worker():
    """Inicia o worker SQS em uma thread separada"""
    worker_thread = threading.Thread(target=sqs_worker_loop, daemon=True)
    worker_thread.start()

# Inicia o worker SQS em background
start_worker()

if __name__ == '__main__':
    port = int(os.getenv("PORT", 8005))
    app.run(host='0.0.0.0', port=port, debug=False)
