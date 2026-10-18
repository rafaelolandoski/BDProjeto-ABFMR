CREATE OR REPLACE FUNCTION validar_sessao();
RETURNS TRIGGER AS $$
DECLARE
data_inicio_evento DATE;
data_fim_evento DATE;
capacidade_espaco smallint;
BEGIN

    SELECT data_inicio,data_fim INTO data_inicio_evento,data_fim_evento
    FROM Evento WHERE id_evento = NEW.id_evento;
    SELECT capacidade INTO capacidade_espaco FROM Espaco
    
-- se a sessão está dentro da data do evento
    IF (NEW.horario_inicio::DATE) < data_inicio_evento OR (NEW.horario_inicio::DATE) > data_fim_evento 
        OR (NEW.horario_fim::DATE) > data_fim_evento 
        THEN RAISE EXCEPTION 'Erro: programacao de sessão (% ate %) ocorre fora do período do evento (% ate %)',
        NEW.horario_inicio::DATE,NEW.horario_fim::DATE,data_inicio_evento,data_fim_evento;
    END IF;

--espaço ocupado se o espaço já tiver outra sessão no mesmo horário bloqueia
    IF EXISTS( SELECT 1 FROM Sessao WHERE id_espaco=NEW.id_espaco 
        AND NOT (TG_OP = 'UPDATE' AND n_sessao = OLD.n_Sessao AND id_atividade = OLD.id_atividade)
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
        SELECT 1 FROM Atividade atv LEFT JOIN esp_rec er ON atv.id_tipo = er.id_tipo
        WHERE atv.id_atividade=NEW.id_atividade AND COALESCE(er.qtd_rec,0) < atv.quantidade
        ) THEN RAISE EXCEPTION 'Erro: O espaço não possui recursos o suficiente';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_sessao_valida
BEFORE INSERT OR UPDATE ON Sessao
FOR EACH ROW
EXECUTE FUNCTION validar_sessao();


--trigger pra inscricao de participante
CREATE OR REPLACE FUNCTION inscrever_participante();
RETURNS TRIGGER AS $$
DECLARE
vagas_sessao smallint;
BEGIN
--checa se tem espaço na sessão
    SELECT vagas INTO vagas_sessao
    FROM Sessao WHERE n_sessao = NEW.n_sessao AND id_atividade = NEW.id_atividade;

    SELECT COUNT(*) AS qtd_inscritos FROM Part_Sessao
    WHERE n_sessao = NEW.n_sessao AND id_atividade = NEW.id_atividade;
    
    IF vagas_sessao IS NOT NULL AND (qtd_inscritos >= vagas_sessao) THEN
        INSERT INTO Lista_de_Espera (CPF,n_sessao,id_atividade) VALUES (NEW.CPF,NEW.n_sessao,NEW.id_atividade);
        RAISE NOTICE 'Limite de vagas da sessão já atingido, participante colocado na lista de espera';
        RETURN NULL;
    END IF;
    RETURN NEW;
END;

$$ LANGUAGE plpgsql
CREATE TRIGGER inscricao_participante_sessao();
BEFORE INSERT ON Part_Sessao FOR EACH ROW
EXECUTE FUNCTION inscrever_participante();