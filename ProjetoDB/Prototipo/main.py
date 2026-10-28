"""
main.py - Protótipo do Projeto de Bases de Dados (SCC0540/SCC0640)
Sistema de Gestão de Eventos e Espaços

O que este programa faz:
  1. Lê o config.json (parâmetros do PostgreSQL e do Ollama);
  2. Conecta no banco PostgreSQL;
  3. Oferece um menu para executar as consultas definidas no projeto;
  4. Permite fazer uma pergunta em linguagem natural: o Ollama converte a
     pergunta em SQL, o programa executa o SQL e mostra o resultado.

Execução:  python main.py
"""

# ---------------------------------------------------------------------------
# IMPORTS
# ---------------------------------------------------------------------------
import json                 # ler o config.json
import re                   # expressões regulares (limpar a resposta do modelo)
from pathlib import Path    # manipular caminhos de forma portável (Windows/Linux/Mac)

import psycopg              # driver do PostgreSQL (versão 3)
from ollama import Client   # cliente para conversar com o Ollama


# ---------------------------------------------------------------------------
# 1) CONFIGURAÇÃO  (trecho obrigatório do PDF)
# ---------------------------------------------------------------------------
# __file__ é o caminho deste main.py. .resolve() transforma em caminho absoluto
# e .parent pega a pasta onde o arquivo está. Assim o programa funciona em
# qualquer computador, sem escrever caminhos como C:\Users\aluno\...
BASE_DIR = Path(__file__).resolve().parent

# Abre o config.json (que está na mesma pasta do main.py) e transforma o texto
# JSON em um dicionário Python: config["database"]["host"], etc.
with open(BASE_DIR / "config.json", encoding="utf-8") as f:
    config = json.load(f)


# ---------------------------------------------------------------------------
# 2) AS CONSULTAS DO PROJETO
# ---------------------------------------------------------------------------
# Cada consulta é um dicionário com:
#   titulo     -> texto mostrado no menu
#   sql        -> a consulta. Os valores que mudam usam %s (marcador de
#                 parâmetro). NUNCA concatene texto digitado pelo usuário
#                 dentro do SQL: o psycopg substitui os %s com segurança.
#   parametros -> lista de (pergunta ao usuário, valor padrão, tipo).
#                 Se o usuário apertar ENTER, usa-se o valor padrão.
#                 A ordem da lista deve ser a mesma dos %s no SQL.
CONSULTAS = [
    {
        "titulo": "Cronograma de um evento",
        "sql": """
            SELECT  ev.nome AS evento,
                    ev.edicao,
                    a.titulo AS atividade,
                    s.n_sessao,
                    s.horario_inicio,
                    s.horario_fim,
                    s.vagas,
                    e.nome AS espaco
            FROM Evento ev
            JOIN Atividade a ON a.id_evento = ev.id_evento
            LEFT JOIN Sessao s ON a.id_atividade = s.id_atividade
            LEFT JOIN Espaco e ON s.id_espaco = e.id_espaco
            WHERE ev.nome = %s AND ev.edicao = %s
            ORDER BY s.horario_inicio ASC NULLS LAST, a.titulo ASC
        """,
        "parametros": [
            ("Nome do evento", "Semana da Engenharia de Computação", str),
            ("Edição", "2026", int),
        ],
    },
    {
        "titulo": "Participantes de uma atividade",
        "sql": """
            SELECT  E.nome AS evento,
                    E.edicao,
                    A.titulo,
                    S.n_sessao,
                    P.nome AS inscritos,
                    P.CPF,
                    count(PS.CPF) OVER (
                        PARTITION BY S.n_sessao, S.id_atividade
                    ) AS participantes,
                    S.vagas,
                    S.vagas - count(PS.CPF) OVER (
                        PARTITION BY S.n_sessao, S.id_atividade
                    ) AS vagas_remanescentes,
                    S.id_atividade
            FROM Sessao S
            JOIN Part_Sessao PS ON S.n_sessao = PS.n_sessao
                               AND S.id_atividade = PS.id_atividade
            JOIN Pessoa P ON PS.CPF = P.CPF
            JOIN Atividade A ON S.id_atividade = A.id_atividade
            JOIN Evento E ON A.id_evento = E.id_evento
            WHERE E.nome = %s AND E.edicao = %s AND A.titulo = %s
        """,
        "parametros": [
            ("Nome do evento", "Semana de Tecnologia", str),
            ("Edição", "5", int),
            ("Título da atividade", "Minicurso de Python", str),
        ],
    },
    {
        "titulo": "Espaços livres em um intervalo de horário",
        "sql": """
            SELECT  e.id_espaco,
                    e.nome AS nome_espaco,
                    e.capacidade
            FROM Espaco e
            WHERE NOT EXISTS (
                SELECT 1 FROM Sessao s
                WHERE s.id_espaco = e.id_espaco
                  AND (s.horario_inicio, s.horario_fim)
                      OVERLAPS (%s::timestamp, %s::timestamp)
            )
            ORDER BY e.nome ASC
        """,
        "parametros": [
            ("Início (AAAA-MM-DD HH:MM:SS)", "2026-10-20 08:00:00", str),
            ("Fim    (AAAA-MM-DD HH:MM:SS)", "2026-10-20 12:00:00", str),
        ],
    },
    {
        "titulo": "Participantes em lista de espera",
        "sql": """
            SELECT  E.nome AS evento,
                    E.edicao,
                    A.titulo AS titulo_atividade,
                    S.n_sessao,
                    P.nome AS inscritos_lista,
                    P.CPF,
                    ROW_NUMBER() OVER (
                        PARTITION BY S.id_atividade, S.n_sessao
                        ORDER BY L.dataInscricao
                    ) AS posicao_lista,
                    S.vagas,
                    L.dataInscricao,
                    S.id_atividade
            FROM Sessao S
            JOIN Lista_de_Espera L ON S.n_sessao = L.n_sessao
                                  AND S.id_atividade = L.id_atividade
            JOIN Pessoa P ON L.CPF = P.CPF
            JOIN Atividade A ON S.id_atividade = A.id_atividade
            JOIN Evento E ON A.id_evento = E.id_evento
        """,
        "parametros": [],   # esta consulta não precisa de parâmetros
    },
    {
        "titulo": "Quantidade de participantes inscritos por evento",
        "sql": """
            SELECT  E.nome AS evento,
                    E.edicao,
                    COUNT(PE.CPF) AS total_participantes
            FROM Evento E
            LEFT JOIN Part_Evento PE
                   ON E.id_evento = PE.id_evento
            GROUP BY E.id_evento, E.nome, E.edicao
            ORDER BY total_participantes DESC
        """,
        "parametros": [],
    },
    {
        "titulo": "Atividades que possuem mais de uma sessão",
        "sql": """
            SELECT  A.titulo AS atividade,
                    E.nome AS evento,
                    E.edicao,
                    COUNT(S.n_sessao) AS quantidade_sessoes
            FROM Atividade A
            JOIN Evento E ON A.id_evento = E.id_evento
            JOIN Sessao S ON A.id_atividade = S.id_atividade
            GROUP BY A.id_atividade, A.titulo,
                     E.id_evento, E.nome, E.edicao
            HAVING COUNT(S.n_sessao) > 1
            ORDER BY quantidade_sessoes DESC
        """,
        "parametros": [],
    },
    # Para adicionar MAIS consultas, copie um bloco acima e cole aqui:
    # o menu se ajusta sozinho.
]


# ---------------------------------------------------------------------------
# 3) CONEXÃO COM O POSTGRESQL  (trecho obrigatório do PDF)
# ---------------------------------------------------------------------------
def conectar_banco():
    """Abre a conexão com o PostgreSQL usando os dados do config.json."""
    db = config["database"]
    try:
        conn = psycopg.connect(
            host=db["host"],
            port=db["port"],
            dbname=db["dbname"],
            user=db["user"],
            password=db["password"],
        )
    except psycopg.Error as erro:
        # Se o banco estiver desligado ou a senha estiver errada, mostramos
        # uma mensagem clara em vez de uma tela cheia de erros do Python.
        print(f"Erro ao conectar no PostgreSQL: {erro}")
        raise SystemExit(1)

    # Medida de segurança: toda transação desta conexão é SOMENTE LEITURA.
    # Assim, mesmo que o modelo de linguagem gere um DELETE/UPDATE/DROP, o
    # PostgreSQL recusa. (O protótipo só precisa de SELECT.)
    conn.read_only = True
    return conn


# ---------------------------------------------------------------------------
# 4) CONEXÃO COM O OLLAMA  (trecho obrigatório do PDF)
# ---------------------------------------------------------------------------
def criar_cliente_ollama():
    """Cria o cliente que fala com o servidor do Ollama."""
    ollama_config = config["ollama"]
    return Client(host=ollama_config["host"])


# ---------------------------------------------------------------------------
# 5) LEITURA DO DDL DO Projeto.txt  (trecho obrigatório do PDF)
# ---------------------------------------------------------------------------
def carregar_ddl():
    """
    Lê o Projeto.txt (na pasta acima de Prototipo/) e devolve só o trecho
    entre os títulos "3. DDL COMPLETO" e "4. CONSULTAS". Esse texto é enviado
    ao modelo para ele conhecer as tabelas e colunas do banco.
    """
    # BASE_DIR.parent = pasta acima de Prototipo/
    projeto_path = BASE_DIR.parent / "Projeto.txt"
    if not projeto_path.exists():
        print("Erro: Projeto.txt não encontrado.")
        raise SystemExit(1)

    projeto = projeto_path.read_text(encoding="utf-8")
    try:
        # split(texto, 1) corta o conteúdo na PRIMEIRA ocorrência do título.
        # [1] pega o que vem depois; [0] pega o que vem antes.
        ddl = projeto.split("3. DDL COMPLETO", 1)[1]
        ddl = ddl.split("4. CONSULTAS", 1)[0]
        ddl = ddl.strip()
    except IndexError:
        # Acontece se um dos dois títulos não existir no arquivo.
        print('Erro: não foi possível encontrar "3. DDL COMPLETO" e '
              '"4. CONSULTAS" no Projeto.txt.')
        raise SystemExit(1)
    return ddl


# ---------------------------------------------------------------------------
# 6) EXECUTAR SQL E MOSTRAR O RESULTADO
# ---------------------------------------------------------------------------
def executar_sql(conn, sql, parametros=None):
    """
    Executa um SELECT e devolve (colunas, linhas).
    Em caso de erro, devolve (None, mensagem_de_erro).
    """
    try:
        # O cursor é o objeto que envia comandos ao banco e lê as respostas.
        # O "with" garante que ele seja fechado ao final.
        with conn.cursor() as cur:
            cur.execute(sql, parametros)          # %s são trocados por parametros
            # cur.description descreve as colunas do resultado; .name é o
            # nome de cada uma. Usamos isso como cabeçalho da tabela.
            colunas = [col.name for col in cur.description]
            linhas = cur.fetchall()               # lista de tuplas
        return colunas, linhas
    except psycopg.Error as erro:
        return None, str(erro).strip()
    finally:
        # Encerra a transação (mesmo em caso de erro). Sem isso, após um erro
        # o PostgreSQL deixa a conexão "travada" até um rollback.
        conn.rollback()


def imprimir_tabela(colunas, linhas, max_largura=40):
    """Imprime o resultado como uma tabela alinhada no terminal."""
    def texto(valor):
        # None vira "NULL"; textos longos são cortados com "..."
        s = "NULL" if valor is None else str(valor)
        return s if len(s) <= max_largura else s[: max_largura - 3] + "..."

    cabecalho = [str(c) for c in colunas]
    corpo = [[texto(v) for v in linha] for linha in linhas]

    # Largura de cada coluna = maior texto entre o cabeçalho e as linhas.
    larguras = [len(c) for c in cabecalho]
    for linha in corpo:
        for i, celula in enumerate(linha):
            larguras[i] = max(larguras[i], len(celula))

    def formatar(celulas):
        # ljust preenche com espaços à direita até a largura da coluna
        return " | ".join(c.ljust(larguras[i]) for i, c in enumerate(celulas))

    print()
    print(formatar(cabecalho))
    print("-+-".join("-" * w for w in larguras))
    for linha in corpo:
        print(formatar(linha))
    print(f"\n({len(corpo)} linha{'s' if len(corpo) != 1 else ''})")


# ---------------------------------------------------------------------------
# 7) CONSULTAS FIXAS DO PROJETO (itens 3 e 4 do protótipo)
# ---------------------------------------------------------------------------
def rodar_consulta(conn, consulta):
    """Pede os parâmetros ao usuário, executa a consulta e mostra o resultado."""
    if consulta["sql"] is None:
        print("\nEsta consulta ainda não foi implementada.")
        return

    print(f"\n=== {consulta['titulo']} ===")

    valores = []
    for pergunta, padrao, tipo in consulta["parametros"]:
        digitado = input(f"{pergunta} [{padrao}]: ").strip()
        bruto = digitado if digitado else padrao   # ENTER = usa o padrão
        try:
            valores.append(tipo(bruto))            # converte para int, str...
        except ValueError:
            print(f"Valor inválido para '{pergunta}'.")
            return

    colunas, resultado = executar_sql(conn, consulta["sql"], valores)
    if colunas is None:
        print(f"\nErro ao executar a consulta: {resultado}")
    else:
        imprimir_tabela(colunas, resultado)


# ---------------------------------------------------------------------------
# 8) LINGUAGEM NATURAL -> SQL (itens 5 a 8 do protótipo)
# ---------------------------------------------------------------------------
def apenas_tabelas(ddl):
    """
    O trecho "3. DDL COMPLETO" do Projeto.txt também contém as funções e
    triggers. Para gerar SELECT o modelo só precisa das tabelas, e o texto extra
    deixa o prompt enorme (o que pode estourar o contexto do modelo). Por isso
    cortamos tudo a partir do primeiro CREATE FUNCTION / CREATE TRIGGER.
    """
    corte = re.search(r"CREATE\s+(OR\s+REPLACE\s+)?(FUNCTION|TRIGGER)", ddl, flags=re.IGNORECASE)
    return ddl[: corte.start()].strip() if corte else ddl


def resumir_esquema(ddl):
    """
    Gera uma lista compacta "Tabela(coluna1, coluna2, ...)" a partir dos
    CREATE TABLE. Modelos pequenos erram menos os nomes das colunas quando
    têm essa lista curta à vista, além do DDL completo.
    """
    linhas = []
    for nome, corpo in re.findall(r"CREATE\s+TABLE\s+(\w+)\s*\((.*?)\n\s*\);",
                                  ddl, flags=re.DOTALL | re.IGNORECASE):
        colunas = []
        for linha in corpo.splitlines():
            linha = linha.strip()
            # ignora linhas vazias, comentários e continuações de restrições
            if not linha or linha.startswith(("--", "(", ")")):
                continue
            palavra = linha.split()[0].rstrip(",")
            if palavra.upper() in ("CONSTRAINT", "PRIMARY", "FOREIGN", "REFERENCES",
                                   "ON", "UNIQUE", "CHECK"):
                continue
            colunas.append(re.split(r"[\s(,]", palavra)[0])
        linhas.append(f"{nome}({', '.join(colunas)})")
    return "\n".join(linhas)


def montar_mensagens(ddl, pergunta):
    """
    Monta a lista de mensagens enviada ao modelo, separando os papéis:
      - "system": quem o modelo é, as regras, dicas do esquema e exemplos;
      - "user":   a pergunta digitada pelo usuário.
    Separar as regras da pergunta ajuda o modelo a segui-las melhor.
    """
    ddl_tabelas = apenas_tabelas(ddl)
    resumo = resumir_esquema(ddl_tabelas)

    system = f"""Você é um assistente especializado em SQL PostgreSQL.

Resumo das tabelas e colunas do banco (use EXATAMENTE estes nomes):

{resumo}

DDL completo (tipos, chaves primárias e estrangeiras):

{ddl_tabelas}

Regras:
- Gere apenas consultas SQL compatíveis com PostgreSQL.
- Não invente tabelas nem atributos: use somente os que existem no esquema.
- Gere apenas comandos SELECT (ou WITH ... SELECT), nunca comandos que alterem dados.
- Gere uma única consulta.
- Retorne apenas o comando SQL, sem explicações e sem comentários.
- Se a pergunta não puder ser respondida com esse esquema, diga que não é possível.
- Para perguntas que começam com "quantos/quantas", use COUNT.

Exemplos:
Pergunta: Quais espaços têm capacidade maior que 100?
SQL: SELECT nome, capacidade FROM Espaco WHERE capacidade > 100 ORDER BY capacidade DESC

Pergunta: Quais atividades pertencem ao evento Semana de Tecnologia?
SQL: SELECT a.titulo FROM Atividade a JOIN Evento e ON e.id_evento = a.id_evento WHERE e.nome = 'Semana de Tecnologia'"""
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": pergunta},
    ]


def limpar_sql(resposta):
    """
    O modelo costuma devolver texto extra. Esta função remove:
      - o bloco <think>...</think> (raciocínio do qwen3);
      - as cercas de código ```sql ... ```;
      - o ponto e vírgula final.
    """
    # re.DOTALL faz o "." casar também com quebras de linha
    resposta = re.sub(r"<think>.*?</think>", "", resposta, flags=re.DOTALL)

    # Se houver um bloco ```...```, fica só com o conteúdo dele
    bloco = re.search(r"```(?:sql)?\s*(.*?)```", resposta, flags=re.DOTALL | re.IGNORECASE)
    if bloco:
        resposta = bloco.group(1)

    return resposta.strip().rstrip(";").strip()


def sql_e_seguro(sql):
    """Aceita só uma instrução que comece com SELECT ou WITH."""
    if not re.match(r"^(select|with)\b", sql, flags=re.IGNORECASE):
        return False
    if ";" in sql:            # mais de uma instrução na mesma resposta
        return False
    return True


def gerar_sql(client, mensagens):
    """Envia as mensagens ao modelo e devolve o SQL já limpo ("" se vier vazio)."""
    try:
        # Chamada ao modelo (trecho obrigatório do PDF)
        response = client.chat(
            model=config["ollama"]["model"],
            messages=mensagens,
            # think=False desliga o "raciocínio" de modelos como o qwen3.5.
            # Com ele ligado, o modelo pode gastar toda a resposta pensando
            # e devolver o campo de conteúdo vazio.
            think=False,
            # temperature 0 = respostas mais determinísticas (melhor para SQL)
            options={"temperature": 0, "num_ctx": 8192},
        )
    except Exception:
        # Plano B: sem o parâmetro think. Cobre biblioteca ollama antiga (que não
        # aceita o argumento) e modelos que não suportam "think". Se o problema
        # for outro (Ollama desligado, modelo não baixado), esta segunda chamada
        # falha de novo e o erro é mostrado ao usuário pela função chamadora.
        response = client.chat(
            model=config["ollama"]["model"],
            messages=mensagens,
            options={"temperature": 0, "num_ctx": 8192},
        )
    resposta = response["message"]["content"] or ""
    return limpar_sql(resposta)


# Quantas vezes o modelo pode tentar (1 tentativa + correções após erro do banco)
MAX_TENTATIVAS = 3


def pergunta_linguagem_natural(conn, client, ddl):
    """Fluxo completo: pergunta -> modelo -> SQL -> banco -> resultado."""
    pergunta = input("\nDigite sua pergunta: ").strip()
    if not pergunta:
        return

    mensagens = montar_mensagens(ddl, pergunta)
    print("Consultando o modelo (pode demorar um pouco)...")

    for tentativa in range(1, MAX_TENTATIVAS + 1):
        try:
            sql = gerar_sql(client, mensagens)
        except Exception as erro:
            # Ollama desligado, modelo não baixado, etc.
            print(f"Erro ao se comunicar com o Ollama: {erro}")
            return

        if not sql:
            print("\nErro: o modelo devolveu uma resposta vazia. Tente de novo ou "
                  "troque o modelo no config.json.")
            return

        print(f"\nSQL gerado pelo modelo (tentativa {tentativa}):")
        print(sql)

        if not sql_e_seguro(sql):
            print("\nErro: o modelo não gerou uma consulta SELECT válida. "
                  "Tente reformular a pergunta.")
            return

        colunas, resultado = executar_sql(conn, sql)
        if colunas is not None:
            # Deu certo: mostra o resultado e termina
            if not resultado:
                print("\nA consulta foi executada, mas não retornou nenhuma linha.")
            else:
                imprimir_tabela(colunas, resultado)
            return

        # O banco recusou o SQL: mostra o erro
        print(f"\nErro: a consulta gerada está incorreta.\nDetalhe: {resultado}")

        if tentativa < MAX_TENTATIVAS:
            # Devolve o erro ao modelo para ele corrigir o próprio SQL
            print("Pedindo ao modelo para corrigir a consulta...")
            mensagens = mensagens + [
                {"role": "assistant", "content": sql},
                {"role": "user", "content": (
                    f"Essa consulta gerou o seguinte erro no PostgreSQL:\n{resultado}\n"
                    "Corrija a consulta usando somente tabelas e colunas do esquema. "
                    "Responda apenas com o SQL.")},
            ]

    print("\nNão foi possível gerar uma consulta correta. "
          "Tente reformular a pergunta.")


# ---------------------------------------------------------------------------
# 9) MENU PRINCIPAL
# ---------------------------------------------------------------------------
def main():
    ddl = carregar_ddl()
    conn = conectar_banco()
    client = criar_cliente_ollama()
    print("Conectado ao banco de dados com sucesso!")

    # A opção de linguagem natural vem logo depois da última consulta fixa
    opcao_nl = len(CONSULTAS) + 1

    try:
        while True:
            print("\n========== SISTEMA DE GESTÃO DE EVENTOS E ESPAÇOS ==========")
            for i, consulta in enumerate(CONSULTAS, start=1):
                print(f"  {i}) {consulta['titulo']}")
            print(f"  {opcao_nl}) Fazer uma pergunta em linguagem natural (Ollama)")
            print("  0) Sair")

            escolha = input("Escolha uma opção: ").strip()

            if escolha == "0":
                break
            elif escolha.isdigit() and 1 <= int(escolha) <= len(CONSULTAS):
                rodar_consulta(conn, CONSULTAS[int(escolha) - 1])
            elif escolha == str(opcao_nl):
                pergunta_linguagem_natural(conn, client, ddl)
            else:
                print("Opção inválida.")
    except (KeyboardInterrupt, EOFError):
        # Ctrl+C ou Ctrl+D: sai sem mostrar erro
        print()
    finally:
        conn.close()
        print("Conexão encerrada.")


# Só executa main() quando o arquivo é rodado diretamente (python main.py),
# e não quando é importado por outro arquivo.
if __name__ == "__main__":
    main()