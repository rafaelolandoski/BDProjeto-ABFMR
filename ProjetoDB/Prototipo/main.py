#print("hello world")
"""
import psycopg

# Configurações de conexão
DB_HOST = "localhost"
DB_PORT = "5432"          # Porta padrão do PostgreSQL
DB_NAME = "postgres"      # Banco padrão que sempre existe
DB_USER = "postgres"      # Usuário padrão
DB_PASS = "sua_senha" # Coloque a senha que quer testar

try:
    print("Tentando conectar ao PostgreSQL...")
    
    # Tenta estabelecer a conexão
    conn = psycopg.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )
    
    print("✅ SUCESSO! Conexão estabelecida com sucesso. A senha está CORRETA!")
    
    # Fecha a conexão
    conn.close()

except psycopg.OperationalError as e:
    print("❌ ERRO DE AUTENTICAÇÃO / CONEXÃO!")
    print("Detalhes do erro:")
    print(e)
"""