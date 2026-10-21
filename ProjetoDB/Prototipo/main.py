"""
SCC0540/SCC0640 - Bases de Dados
Projeto de Curso - Sistema de Gestão de Eventos e Espaços

Protótipo em linha de comando que:
  1. Lê os parâmetros de conexão (config.json) e permite ajustá-los;
  2. Conecta ao PostgreSQL;
  3. Executa as consultas definidas em Projeto.txt (quantidade variável);
  4. Apresenta os resultados em formato tabular;
  5. Recebe perguntas em linguagem natural;
  6. Converte a pergunta em SQL via Ollama (modelo local);
  7. Executa o SQL gerado;
  8. Exibe o resultado ou a mensagem de erro.

Execução:
    python main.py
"""

from __future__ import annotations

import importlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from getpass import getpass
from pathlib import Path
from typing import Any

BASE_DIR = Path(__file__).resolve().parent

REQUIREMENTS_FILE_NAME = "requirements.txt"
REQUIRED_MODULES = ("ollama", "psycopg")


def ensure_dependencies() -> None:
    """
    Garante que as bibliotecas de terceiros estejam instaladas.

    Se alguma estiver ausente, executa automaticamente:
        python -m pip install -r requirements.txt
    usando o mesmo interpretador que está rodando este programa.
    """

    def missing_modules() -> list[str]:
        missing = []
        for module_name in REQUIRED_MODULES:
            try:
                importlib.import_module(module_name)
            except ImportError:
                missing.append(module_name)
        return missing

    missing = missing_modules()
    if not missing:
        return

    requirements_path = BASE_DIR / REQUIREMENTS_FILE_NAME
    command = [sys.executable, "-m", "pip", "install", "-r", str(requirements_path)]
    manual_command = "python -m pip install -r requirements.txt"

    print(f"[INFO] Dependências ausentes: {', '.join(missing)}.")
    if not requirements_path.exists():
        print(f"[ERRO] {REQUIREMENTS_FILE_NAME} não encontrado em {BASE_DIR}.")
        raise SystemExit(1)

    print(f"[INFO] Instalando a partir de {REQUIREMENTS_FILE_NAME}...")
    try:
        result = subprocess.run(command, check=False)
    except OSError as exc:
        print(f"[ERRO] Não foi possível executar o pip: {exc}")
        print(f"Instale manualmente com: {manual_command}")
        raise SystemExit(1)

    importlib.invalidate_caches()
    if result.returncode != 0 or missing_modules():
        print("[ERRO] A instalação automática das dependências falhou.")
        print(f"Instale manualmente com: {manual_command}")
        raise SystemExit(1)

    print("[INFO] Dependências instaladas com sucesso.\n")


ensure_dependencies()

import psycopg  # noqa: E402  (importado após garantir a instalação)
from ollama import Client  # noqa: E402

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------

CONFIG_FILE_NAME = "config.json"
PROJECT_FILE_NAME = "Projeto.txt"

# Marcadores das seções do Projeto.txt (conforme template obrigatório)
DDL_SECTION_START = "3. DDL COMPLETO"
DDL_SECTION_END = "4. CONSULTAS"
QUERIES_SECTION_START = "4. CONSULTAS"
QUERIES_SECTION_END = "FIM DO ARQUIVO"

# Apresentação dos resultados
MAX_DISPLAY_ROWS = 50
MAX_CELL_WIDTH = 40
NULL_REPRESENTATION = "NULL"
TRUNCATION_SUFFIX = "…"
BANNER_WIDTH = 70

# Execução de SQL
STATEMENT_TIMEOUT_MS = 30_000

# Quantas vezes o modelo pode tentar corrigir um SQL que falhou (0 = desativado)
MAX_SQL_CORRECTION_ATTEMPTS = 1

# Opções de menu
MENU_RUN_PREDEFINED = "1"
MENU_ASK_NATURAL_LANGUAGE = "2"
MENU_CHANGE_CONNECTION = "3"
MENU_EXIT = "0"

# Opções do submenu de consultas
QUERY_MENU_RUN_ALL = "t"
QUERY_MENU_BACK = "0"

# Comandos aceitos no modo de linguagem natural
NL_EXIT_COMMANDS = {"", "0", "sair", "voltar", "exit", "quit"}

# Parâmetros de conexão que o usuário pode editar: (chave, rótulo, é_senha)
CONNECTION_FIELDS: tuple[tuple[str, str, bool], ...] = (
    ("host", "Host", False),
    ("port", "Porta", False),
    ("dbname", "Banco", False),
    ("user", "Usuário", False),
    ("password", "Senha", True),
)

# Expressões regulares
RE_SEPARATOR_LINE = re.compile(r"^\s*=+\s*$", re.MULTILINE)
RE_QUERY_BLOCK = re.compile(
    r"^CONSULTA\s+(\d+)\s*$(.*?)(?=^CONSULTA\s+\d+\s*$|\Z)",
    re.MULTILINE | re.DOTALL,
)
RE_QUERY_OBJECTIVE = re.compile(
    r"OBJETIVO:\s*(.*?)\s*^SQL:", re.MULTILINE | re.DOTALL
)
RE_QUERY_SQL = re.compile(r"^SQL:\s*(.*)\Z", re.MULTILINE | re.DOTALL)
RE_THINK_BLOCK = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)
RE_CODE_FENCE = re.compile(r"```(?:sql|postgresql|pgsql)?\s*(.*?)```",
                           re.DOTALL | re.IGNORECASE)
RE_SQL_START = re.compile(r"\b(SELECT|WITH)\b", re.IGNORECASE)

SQL_ALLOWED_PREFIXES = ("select", "with")

LLM_PROMPT_TEMPLATE = """\
Você é um especialista em PostgreSQL. Converta a pergunta do usuário em UMA \
única consulta SQL, usando exclusivamente as tabelas e colunas do esquema \
abaixo.

ESQUEMA (DDL):
{ddl}

REGRAS:
- Responda somente com o código SQL, sem explicações e sem comentários.
- Gere apenas uma instrução SELECT (ou WITH ... SELECT) compatível com PostgreSQL.
- Nunca gere INSERT, UPDATE, DELETE, DROP, ALTER, CREATE ou TRUNCATE.
- Não invente tabelas nem colunas que não existam no esquema.
- Use JOINs explícitos quando precisar combinar tabelas.
{correction_block}
PERGUNTA: {question}
"""

LLM_CORRECTION_BLOCK_TEMPLATE = """
A tentativa anterior estava incorreta e precisa ser corrigida.
SQL anterior:
{previous_sql}
Erro retornado pelo PostgreSQL:
{error}
"""


# ---------------------------------------------------------------------------
# Modelos de dados
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class PredefinedQuery:
    """Consulta predefinida lida do Projeto.txt."""

    number: int
    objective: str
    sql: str


@dataclass(frozen=True)
class QueryResult:
    """Resultado de uma execução de SQL."""

    columns: list[str]
    rows: list[tuple[Any, ...]]
    truncated: bool


# ---------------------------------------------------------------------------
# Utilitários de interface
# ---------------------------------------------------------------------------

def print_banner(title: str) -> None:
    line = "=" * BANNER_WIDTH
    print(f"\n{line}\n{title}\n{line}")


def print_error(message: str) -> None:
    print(f"[ERRO] {message}")


def print_info(message: str) -> None:
    print(f"[INFO] {message}")


def read_input(prompt: str) -> str:
    """Lê uma linha do terminal; trata EOF (Ctrl+D / Ctrl+Z) como saída."""
    try:
        return input(prompt).strip()
    except EOFError:
        print()
        raise SystemExit(0)


def format_cell(value: Any) -> str:
    """Converte um valor em texto de célula (uma linha, largura limitada)."""
    text = NULL_REPRESENTATION if value is None else str(value)
    text = " ".join(text.split())
    if len(text) > MAX_CELL_WIDTH:
        text = text[: MAX_CELL_WIDTH - len(TRUNCATION_SUFFIX)] + TRUNCATION_SUFFIX
    return text


def render_table(columns: list[str], rows: list[tuple[Any, ...]]) -> str:
    """Renderiza colunas e linhas como uma tabela em texto."""
    header = [format_cell(column) for column in columns]
    body = [[format_cell(value) for value in row] for row in rows]

    widths = [len(title) for title in header]
    for row in body:
        for index, cell in enumerate(row):
            widths[index] = max(widths[index], len(cell))

    def build_row(cells: list[str]) -> str:
        return "| " + " | ".join(c.ljust(w) for c, w in zip(cells, widths)) + " |"

    separator = "+-" + "-+-".join("-" * width for width in widths) + "-+"
    lines = [separator, build_row(header), separator]
    lines.extend(build_row(row) for row in body)
    lines.append(separator)
    return "\n".join(lines)


def print_result(result: QueryResult) -> None:
    """Exibe o resultado de uma consulta."""
    if not result.columns:
        print_info("A instrução foi executada, mas não retornou linhas.")
        return

    print(render_table(result.columns, result.rows))
    count = len(result.rows)
    if result.truncated:
        print(f"({count} linhas exibidas; resultado limitado a {MAX_DISPLAY_ROWS})")
    else:
        print(f"({count} {'linha' if count == 1 else 'linhas'})")


# ---------------------------------------------------------------------------
# Configuração e leitura do Projeto.txt
# ---------------------------------------------------------------------------

def load_config() -> dict[str, Any]:
    """Carrega o config.json localizado ao lado do main.py."""
    config_path = BASE_DIR / CONFIG_FILE_NAME
    if not config_path.exists():
        print_error(f"{CONFIG_FILE_NAME} não encontrado em {BASE_DIR}.")
        raise SystemExit(1)

    try:
        with open(config_path, encoding="utf-8") as f:
            config = json.load(f)
        _ = config["database"], config["ollama"]["host"], config["ollama"]["model"]
    except (json.JSONDecodeError, KeyError) as exc:
        print_error(f"{CONFIG_FILE_NAME} inválido ou incompleto: {exc!r}")
        raise SystemExit(1)
    return config


def load_project_file() -> str:
    """Lê o Projeto.txt localizado na raiz do projeto (pasta pai de Prototipo)."""
    projeto_path = BASE_DIR.parent / PROJECT_FILE_NAME
    if not projeto_path.exists():
        print("Erro: Projeto.txt não encontrado.")
        raise SystemExit(1)
    return projeto_path.read_text(encoding="utf-8")


def strip_separator_lines(text: str) -> str:
    """Remove linhas compostas apenas por '=' (decoração do template)."""
    return RE_SEPARATOR_LINE.sub("", text).strip()


def extract_ddl(projeto: str) -> str:
    """Extrai a seção '3. DDL COMPLETO' do Projeto.txt."""
    try:
        ddl = projeto.split(DDL_SECTION_START, 1)[1]
        ddl = ddl.split(DDL_SECTION_END, 1)[0]
    except IndexError:
        print_error(
            f"Seções '{DDL_SECTION_START}' / '{DDL_SECTION_END}' não encontradas "
            f"em {PROJECT_FILE_NAME}."
        )
        raise SystemExit(1)

    ddl = strip_separator_lines(ddl)
    if not ddl:
        print_error("A seção de DDL do Projeto.txt está vazia.")
        raise SystemExit(1)
    return ddl


def extract_queries(projeto: str) -> list[PredefinedQuery]:
    """
    Extrai todas as consultas da seção '4. CONSULTAS'.

    Aceita qualquer quantidade de blocos 'CONSULTA N' com os campos
    'OBJETIVO:' e 'SQL:'. Blocos malformados são ignorados com aviso.
    """
    try:
        section = projeto.split(QUERIES_SECTION_START, 1)[1]
    except IndexError:
        print_error(f"Seção '{QUERIES_SECTION_START}' não encontrada.")
        raise SystemExit(1)
    section = section.split(QUERIES_SECTION_END, 1)[0]
    section = RE_SEPARATOR_LINE.sub("", section)

    queries: list[PredefinedQuery] = []
    for match in RE_QUERY_BLOCK.finditer(section):
        number = int(match.group(1))
        block = match.group(2)

        objective_match = RE_QUERY_OBJECTIVE.search(block)
        sql_match = RE_QUERY_SQL.search(block)
        if not objective_match or not sql_match or not sql_match.group(1).strip():
            print_info(f"CONSULTA {number} ignorada: formato OBJETIVO/SQL inválido.")
            continue

        queries.append(
            PredefinedQuery(
                number=number,
                objective=" ".join(objective_match.group(1).split()),
                sql=sql_match.group(1).strip(),
            )
        )
    return queries


# ---------------------------------------------------------------------------
# PostgreSQL
# ---------------------------------------------------------------------------

def mask_password(password: str) -> str:
    return "*" * len(password) if password else "(vazia)"


def show_connection_params(params: dict[str, Any]) -> None:
    print("Parâmetros de conexão com o PostgreSQL:")
    for key, label, is_secret in CONNECTION_FIELDS:
        value = mask_password(str(params[key])) if is_secret else params[key]
        print(f"  {label:<8}: {value}")


def prompt_connection_params(current: dict[str, Any]) -> dict[str, Any]:
    """Pergunta cada parâmetro; Enter mantém o valor atual."""
    updated = dict(current)
    print("Pressione Enter para manter o valor atual.")
    for key, label, is_secret in CONNECTION_FIELDS:
        if is_secret:
            typed = getpass(f"  {label} [{mask_password(str(current[key]))}]: ").strip()
        else:
            typed = read_input(f"  {label} [{current[key]}]: ")
        if not typed:
            continue
        if key == "port":
            if not typed.isdigit():
                print_error("Porta inválida; valor anterior mantido.")
                continue
            updated[key] = int(typed)
        else:
            updated[key] = typed
    return updated


def connect_to_database(params: dict[str, Any]) -> psycopg.Connection:
    """Abre a conexão (somente leitura) com o PostgreSQL."""
    conn = psycopg.connect(
        host=params["host"],
        port=params["port"],
        dbname=params["dbname"],
        user=params["user"],
        password=params["password"],
    )
    # O protótipo só consulta dados; isso protege contra SQL destrutivo do LLM.
    conn.read_only = True
    return conn


def establish_connection(initial_params: dict[str, Any]) -> tuple[psycopg.Connection, dict[str, Any]]:
    """Fluxo interativo de conexão: mostra, permite editar e tenta conectar."""
    params = dict(initial_params)
    while True:
        show_connection_params(params)
        answer = read_input("Deseja alterar algum parâmetro? [s/N]: ").lower()
        if answer in ("s", "sim", "y", "yes"):
            params = prompt_connection_params(params)

        try:
            conn = connect_to_database(params)
        except psycopg.Error as exc:
            print_error(f"Falha ao conectar ao PostgreSQL: {str(exc).strip()}")
            print("Revise os parâmetros e tente novamente.\n")
            # Na próxima volta, força a edição dos parâmetros
            params = prompt_connection_params(params)
            continue

        print_info(f"Conectado a '{params['dbname']}' em {params['host']}:{params['port']}.")
        return conn, params


def execute_sql(conn: psycopg.Connection, sql: str) -> QueryResult:
    """
    Executa um SQL e devolve até MAX_DISPLAY_ROWS linhas.

    Sempre encerra a transação ao final (rollback) para que a conexão
    permaneça utilizável mesmo após erros.
    """
    try:
        with conn.cursor() as cur:
            cur.execute(f"SET LOCAL statement_timeout = {STATEMENT_TIMEOUT_MS}")
            cur.execute(sql)  # type: ignore[arg-type]
            if cur.description is None:
                return QueryResult(columns=[], rows=[], truncated=False)

            columns = [column.name for column in cur.description]
            fetched = cur.fetchmany(MAX_DISPLAY_ROWS + 1)
            truncated = len(fetched) > MAX_DISPLAY_ROWS
            return QueryResult(
                columns=columns,
                rows=[tuple(row) for row in fetched[:MAX_DISPLAY_ROWS]],
                truncated=truncated,
            )
    finally:
        conn.rollback()


def run_and_print(conn: psycopg.Connection, sql: str) -> bool:
    """Executa e imprime. Retorna True em caso de sucesso."""
    try:
        result = execute_sql(conn, sql)
    except psycopg.Error as exc:
        print_error(f"Erro ao executar a consulta: {str(exc).strip()}")
        return False
    print_result(result)
    return True


# ---------------------------------------------------------------------------
# Ollama (linguagem natural -> SQL)
# ---------------------------------------------------------------------------

def check_ollama(client: Client, model: str) -> None:
    """Verificação informativa; não impede o uso das consultas predefinidas."""
    try:
        client.list()
    except Exception as exc:  # noqa: BLE001 - qualquer falha de rede/servidor
        print_error(f"Ollama inacessível: {exc}")
        print("As consultas predefinidas continuam disponíveis; "
              "a opção de linguagem natural dependerá do Ollama.")
        return
    print_info(f"Ollama acessível. Modelo configurado: {model}")


def build_prompt(ddl: str, question: str,
                 previous_sql: str | None = None,
                 error: str | None = None) -> str:
    correction_block = ""
    if previous_sql and error:
        correction_block = LLM_CORRECTION_BLOCK_TEMPLATE.format(
            previous_sql=previous_sql, error=error
        )
    return LLM_PROMPT_TEMPLATE.format(
        ddl=ddl, correction_block=correction_block, question=question
    )


def clean_llm_sql(raw_response: str) -> str:
    """Remove raciocínio (<think>), cercas de código e texto extra da resposta."""
    text = RE_THINK_BLOCK.sub("", raw_response).strip()

    fenced = RE_CODE_FENCE.search(text)
    if fenced:
        text = fenced.group(1).strip()
    else:
        start = RE_SQL_START.search(text)
        if start:
            text = text[start.start():].strip()

    return text.rstrip().rstrip(";").strip()


def is_read_only_sql(sql: str) -> bool:
    return sql.lower().lstrip("( \n\t").startswith(SQL_ALLOWED_PREFIXES)


def generate_sql(client: Client, model: str, ddl: str, question: str,
                 previous_sql: str | None = None,
                 error: str | None = None) -> str:
    """Pede ao modelo um SQL para a pergunta e devolve o texto já limpo."""
    prompt = build_prompt(ddl, question, previous_sql, error)
    response = client.chat(
        model=model,
        messages=[
            {
                "role": "user",
                "content": prompt,
            }
        ],
    )
    resposta = response["message"]["content"]
    return clean_llm_sql(resposta)


def answer_natural_language_question(conn: psycopg.Connection, client: Client,
                                     model: str, ddl: str, question: str) -> None:
    """Converte a pergunta em SQL, executa e mostra resultado ou erro."""
    previous_sql: str | None = None
    last_error: str | None = None

    for attempt in range(MAX_SQL_CORRECTION_ATTEMPTS + 1):
        if attempt == 0:
            print_info("Gerando SQL com o modelo local...")
        else:
            print_info(f"Tentando corrigir o SQL (tentativa {attempt}/"
                       f"{MAX_SQL_CORRECTION_ATTEMPTS})...")

        try:
            sql = generate_sql(client, model, ddl, question, previous_sql, last_error)
        except Exception as exc:  # noqa: BLE001 - erros de rede/modelo do Ollama
            print_error(f"Falha na comunicação com o Ollama: {exc}")
            return

        print("\nSQL gerado:")
        print(sql if sql else "(vazio)")
        print()

        if not sql or not is_read_only_sql(sql):
            last_error = "O modelo não produziu uma consulta SELECT válida."
            print_error(last_error)
            previous_sql = sql or "(vazio)"
            continue

        try:
            result = execute_sql(conn, sql)
        except psycopg.Error as exc:
            last_error = str(exc).strip()
            print_error(f"Consulta incorreta: {last_error}")
            previous_sql = sql
            continue

        print_result(result)
        return

    print_error("Não foi possível obter uma consulta válida para esta pergunta. "
                "Tente reformulá-la com mais detalhes.")


# ---------------------------------------------------------------------------
# Fluxos de menu
# ---------------------------------------------------------------------------

def show_main_menu(model: str, dbname: str) -> None:
    print_banner("SISTEMA DE GESTÃO DE EVENTOS E ESPAÇOS")
    print(f"Banco: {dbname} | Modelo Ollama: {model}\n")
    print(f"  [{MENU_RUN_PREDEFINED}] Executar consultas predefinidas")
    print(f"  [{MENU_ASK_NATURAL_LANGUAGE}] Fazer pergunta em linguagem natural")
    print(f"  [{MENU_CHANGE_CONNECTION}] Alterar conexão com o banco")
    print(f"  [{MENU_EXIT}] Sair")


def run_predefined_query(conn: psycopg.Connection, query: PredefinedQuery) -> None:
    print_banner(f"CONSULTA {query.number}")
    print(f"Objetivo: {query.objective}\n")
    print("SQL:")
    print(query.sql)
    print()
    run_and_print(conn, query.sql)


def predefined_queries_menu(conn: psycopg.Connection,
                            queries: list[PredefinedQuery]) -> None:
    if not queries:
        print_error(f"Nenhuma consulta encontrada em {PROJECT_FILE_NAME}.")
        return

    by_number = {str(query.number): query for query in queries}

    while True:
        print_banner("CONSULTAS PREDEFINIDAS")
        for query in queries:
            print(f"  [{query.number}] {query.objective}")
        print(f"  [{QUERY_MENU_RUN_ALL}] Executar todas")
        print(f"  [{QUERY_MENU_BACK}] Voltar")

        choice = read_input("\nEscolha: ").lower()
        if choice == QUERY_MENU_BACK:
            return
        if choice == QUERY_MENU_RUN_ALL:
            for query in queries:
                run_predefined_query(conn, query)
        elif choice in by_number:
            run_predefined_query(conn, by_number[choice])
        else:
            print_error("Opção inválida.")


def natural_language_menu(conn: psycopg.Connection, client: Client,
                          model: str, ddl: str) -> None:
    print_banner("PERGUNTA EM LINGUAGEM NATURAL")
    print("Digite sua pergunta sobre eventos, sessões, espaços e participantes.")
    print("Para voltar ao menu, digite 'sair' ou pressione Enter em branco.\n")

    while True:
        question = read_input("Pergunta> ")
        if question.lower() in NL_EXIT_COMMANDS:
            return
        answer_natural_language_question(conn, client, model, ddl, question)
        print()


# ---------------------------------------------------------------------------
# Programa principal
# ---------------------------------------------------------------------------

def main() -> None:
    config = load_config()
    projeto = load_project_file()
    ddl = extract_ddl(projeto)
    queries = extract_queries(projeto)

    ollama_config = config["ollama"]
    client = Client(
        host=ollama_config["host"]
    )
    model = ollama_config["model"]

    print_banner("SCC0640 - PROTÓTIPO DE BASES DE DADOS")
    print_info(f"{len(queries)} consulta(s) carregada(s) de {PROJECT_FILE_NAME}.")
    check_ollama(client, model)
    print()

    conn, db_params = establish_connection(config["database"])

    try:
        while True:
            show_main_menu(model, db_params["dbname"])
            choice = read_input("\nEscolha: ")

            if choice == MENU_RUN_PREDEFINED:
                predefined_queries_menu(conn, queries)
            elif choice == MENU_ASK_NATURAL_LANGUAGE:
                natural_language_menu(conn, client, model, ddl)
            elif choice == MENU_CHANGE_CONNECTION:
                new_conn, db_params = establish_connection(db_params)
                conn.close()
                conn = new_conn
            elif choice == MENU_EXIT:
                print("Encerrando. Até logo!")
                break
            else:
                print_error("Opção inválida.")
    finally:
        conn.close()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrompido pelo usuário.")
        sys.exit(130)