--1: trigger para insercao de sessao
CREATE OR REPLACE FUNCTION validar_sessao()
RETURNS TRIGGER AS $$
DECLARE
data_inicio_evento DATE;
data_fim_evento DATE;
capacidade_espaco smallint;
BEGIN

    SELECT e.data_inicio, e.data_fim INTO data_inicio_evento, data_fim_evento
    FROM Atividade a JOIN Evento e ON a.id_evento = e.id_evento
    WHERE a.id_atividade = NEW.id_atividade;
    
    SELECT capacidade INTO capacidade_espaco FROM Espaco
    WHERE id_espaco = NEW.id_espaco;
    
   -- se as vagas de sessão forem maiores que a capacidade do espaço
    IF NEW.vagas IS NOT NULL AND capacidade_espaco < NEW.vagas THEN
        RAISE EXCEPTION 'Erro: A quantidade de vagas da sessão (%) ultrapassa a capacidade máxima do espaço selecionado (%).',
        NEW.vagas, capacidade_espaco;
    END IF;
    
-- se a sessão está dentro da data do evento
    IF (NEW.horario_inicio::DATE) < data_inicio_evento OR (NEW.horario_inicio::DATE) > data_fim_evento 
        OR (NEW.horario_fim::DATE) > data_fim_evento 
        THEN RAISE EXCEPTION 'Erro: programacao de sessão (% ate %) ocorre fora do período do evento (% ate %)',
        NEW.horario_inicio::DATE,NEW.horario_fim::DATE,data_inicio_evento,data_fim_evento;
    END IF;

--espaço ocupado se o espaço já tiver outra sessão no mesmo horário bloqueia
    IF EXISTS( SELECT 1 FROM Sessao WHERE id_espaco=NEW.id_espaco 
        AND NOT (TG_OP = 'UPDATE' AND n_sessao = OLD.n_sessao AND id_atividade = OLD.id_atividade)
        AND (NEW.horario_inicio, NEW.horario_fim ) OVERLAPS (horario_inicio,horario_fim)
        )
        THEN RAISE EXCEPTION 'Erro: outra sessao ja esta com o horario agendado';
    END IF;
-- espaço tem todos os recurss necessarios
    
    IF EXISTS(
        --pega todos os tipos e quantidades deles associados ao espaço que a sessão será inserida
        WITH esp_rec AS(SELECT id_tipo, COUNT(*) AS qtd_rec FROM Recurso
        WHERE id_espaco = NEW.id_espaco GROUP BY id_tipo)
        
        --se qualquer id_tipo de recurso no espaço tiver uma quantidade menor que o necessário
        SELECT 1 FROM Atividade atv LEFT JOIN Ativ_Tipo_Recurso atr on atv.id_atividade = atr.id_atividade
        LEFT JOIN esp_rec er ON atr.id_tipo = er.id_tipo
        WHERE atv.id_atividade=NEW.id_atividade AND COALESCE(er.qtd_rec,0) < atr.quantidade
        ) THEN RAISE EXCEPTION 'Erro: O espaço não possui recursos o suficiente';
    END IF;
    -- sessões de uma mesma atividade não podem se sobrepor no tempo
    IF EXISTS( SELECT 1 FROM Sessao WHERE id_atividade = NEW.id_atividade
        AND NOT (TG_OP = 'UPDATE' AND n_sessao = OLD.n_sessao AND id_atividade = OLD.id_atividade)
        AND (NEW.horario_inicio, NEW.horario_fim) OVERLAPS (horario_inicio, horario_fim)
        )
        THEN RAISE EXCEPTION 'Erro: a sessao (% ate %) se sobrepoe a outra sessao da mesma atividade',
        NEW.horario_inicio, NEW.horario_fim;
    END IF; 
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER check_sessao_valida
BEFORE INSERT OR UPDATE ON Sessao
FOR EACH ROW
EXECUTE FUNCTION validar_sessao();


--2: trigger pra inscricao de participante
CREATE OR REPLACE FUNCTION inscrever_participante()
RETURNS TRIGGER AS $$
DECLARE
vagas_sessao smallint;
qtd_inscritos smallint;
id_atv integer;
BEGIN

    --checa se tem espaço na sessão
    SELECT id_atividade,vagas INTO id_atv,vagas_sessao
    FROM Sessao WHERE n_sessao = NEW.n_sessao AND id_atividade = NEW.id_atividade;
    --se sessão ilimitada, não é pra aparecer em participante_sessão
    IF vagas_sessao IS NULL THEN
        RAISE EXCEPTION 'Erro: Esta sessão possui vagas ilimitadas e não requer inscrição prévia.';
    END IF;
    
    --Participante deve estar inscrito no evento da atividade
    IF NOT EXISTS (
        SELECT 1 FROM Part_Evento PE
        JOIN Atividade A on A.id_atividade = NEW.id_atividade
         WHERE CPF = NEW.CPF 
           AND PE.id_evento = A.id_evento
    ) THEN
        RAISE EXCEPTION 'Erro: Participante não está inscrito no evento da atividade.';
    END IF;

    --Participante não pode ser instrutor da mesma sessão
    IF EXISTS (
        SELECT 1 FROM Inst_Sessao 
         WHERE CPF = NEW.CPF 
           AND n_sessao = NEW.n_sessao 
           AND id_atividade = NEW.id_atividade
    ) THEN
        RAISE EXCEPTION 'Erro: Um instrutor não pode inscrever-se como participante na mesma sessão em que ajuda.';
    END IF;
    
    -- Participante não pode ser palestrante da mesma atividade
    IF EXISTS (
        SELECT 1 FROM Pales_Ativ 
         WHERE CPF = NEW.CPF 
           AND id_atividade = id_atv
    ) THEN
        RAISE EXCEPTION 'Erro: Um palestrante não pode inscrever-se como participante numa sessão de uma atividade que ele próprio apresenta.';
    END IF;
    
    SELECT COUNT(*) INTO qtd_inscritos FROM Part_Sessao
    WHERE n_sessao = NEW.n_sessao AND id_atividade = NEW.id_atividade;
    --se checa se sessão esta cheia ou nao
    IF qtd_inscritos >= vagas_sessao THEN
        INSERT INTO Lista_de_Espera (CPF,n_sessao,id_atividade) VALUES (NEW.CPF,NEW.n_sessao,NEW.id_atividade);
        RAISE NOTICE 'Limite de vagas da sessão já atingido, participante colocado na lista de espera';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;

$$ LANGUAGE plpgsql;
CREATE OR REPLACE TRIGGER inscricao_participante_sessao
BEFORE INSERT ON Part_Sessao FOR EACH ROW
EXECUTE FUNCTION inscrever_participante();

--3: se algum participante deixa de ser inscrito em uma sessão cheia, inscreve o próximo da lista de espera
CREATE OR REPLACE FUNCTION inscrever_da_espera()
RETURNS TRIGGER AS $$
DECLARE
proximo char(11);
BEGIN
-- se tiver um participante inscrito na lista de espera da seção, pega o mínimo
    
    SELECT CPF INTO proximo FROM Lista_de_Espera
    WHERE n_sessao = OLD.n_sessao AND id_atividade=OLD.id_atividade
    ORDER BY dataInscricao ASC, CPF ASC LIMIT 1;
    
    
    IF proximo IS NOT NULL THEN
        INSERT INTO Part_Sessao VALUES (proximo,OLD.n_sessao,OLD.id_atividade);
        
        DELETE  FROM Lista_de_Espera WHERE CPF = proximo
        AND n_sessao = OLD.n_sessao AND id_atividade=OLD.id_atividade;
        
        RAISE NOTICE 'Participante na fila de espera inscrito sessao';
    END IF;
    
    RETURN OLD;

END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE TRIGGER inscricao_participante_espera
AFTER DELETE ON Part_Sessao FOR EACH ROW
EXECUTE FUNCTION inscrever_da_espera();

--4: valida instrutor
CREATE OR REPLACE FUNCTION validar_instrutor_sessao()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS(SELECT 1 FROM Part_Sessao 
        WHERE CPF = NEW.CPF AND n_sessao = NEW.n_sessao AND id_atividade = NEW.id_atividade
        ) THEN RAISE EXCEPTION 'Erro: Esta pessoa já está inscrita como participante nesta sessão e não pode ser instrutor.';
    END IF; 

    IF EXISTS (SELECT 1 FROM Pales_Ativ 
        WHERE CPF = NEW.CPF AND id_atividade = NEW.id_atividade
        )THEN RAISE EXCEPTION 'Erro: Esta pessoa já está inscrita como palestrante nesta sessão e não pode ser instrutor.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER check_instrutor_sessao
BEFORE INSERT OR UPDATE ON Inst_Sessao
FOR EACH ROW
EXECUTE FUNCTION validar_instrutor_sessao();

--5: valida palestrante
CREATE OR REPLACE FUNCTION validar_palestrante_atividade()
RETURNS TRIGGER AS $$
BEGIN
    -- Validação: Palestrante não pode ter inscrições ativas como participante em sessões desta atividade
    IF EXISTS (
        SELECT 1 FROM Part_Sessao
            WHERE CPF = NEW.CPF AND id_atividade = NEW.id_atividade
        ) THEN RAISE EXCEPTION 'Erro: Este palestrante já possui inscrição como participante em sessões desta atividade.';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM Inst_Sessao
            WHERE CPF = NEW.CPF AND id_atividade = NEW.id_atividade
        ) THEN RAISE EXCEPTION 'Erro: Este palestrante já possui inscrição como instrutor em sessões desta atividade.';
    END IF;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER check_palestrante_atividade
BEFORE INSERT OR UPDATE ON Pales_Ativ
FOR EACH ROW
EXECUTE FUNCTION validar_palestrante_atividade();

--6: valida organização

CREATE OR REPLACE FUNCTION validar_organizacao_organizador()
RETURNS TRIGGER AS $$
BEGIN
    -- Validação: Organização individual não pode ter mais de um organizador
    IF EXISTS (
        SELECT 1 FROM Organizacao
            WHERE CNPJ = NEW.CNPJ AND org_tipo = 'Individuo'
        ) AND EXISTS (
            SELECT 1 FROM Organizador_Organizacao
            WHERE CNPJ = NEW.CNPJ
        ) THEN RAISE EXCEPTION 'Erro: Esta organização individual já possui um organizador.';
    END IF;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER check_organizacao_organizador
BEFORE INSERT OR UPDATE ON Organizador_Organizacao
FOR EACH ROW
EXECUTE FUNCTION validar_organizacao_organizador();