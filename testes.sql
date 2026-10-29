
-- teste 1, exceder capacidade do espaço
INSERT INTO Sessao
(n_sessao, id_atividade, id_espaco, horario_inicio, horario_fim, vagas)
VALUES
(3, 27, 3, '2026-12-05 14:00', '2026-12-05 16:00', 31);

-teste 2 conflito de horario
INSERT INTO Sessao
(n_sessao, id_atividade, id_espaco, horario_inicio, horario_fim, vagas)
VALUES
(3, 27, 3, '2026-12-04 15:00', '2026-12-04 16:00', 10);

--teste 3 espaço sem recursos necessários
INSERT INTO Sessao
(n_sessao, id_atividade, id_espaco, horario_inicio, horario_fim, vagas)
VALUES
(3, 27, 2, '2026-12-05 14:00', '2026-12-05 16:00', 10);

--teste 4 participante não inscrito em evento
INSERT INTO Part_Sessao (CPF, n_sessao, id_atividade)
VALUES ('70000000030', 1, 27);

--teste 5 instrutor na propria sessao
INSERT INTO Part_Sessao (CPF, n_sessao, id_atividade)
VALUES ('77788899900', 2, 27);

--Teste 6 — Organização individual com dois organizadores
INSERT INTO Organizador_Organizacao (CPF, CNPJ)
VALUES ('44455566677', '55666777000145');



--Testando o trigger de DELETE
BEGIN;

-- Consultar os inscritos antes da remoção
SELECT CPF
FROM Part_Sessao
WHERE n_sessao = 1 AND id_atividade = 27
ORDER BY CPF;

-- Consultar a fila antes da remoção
SELECT CPF, dataInscricao
FROM Lista_de_Espera
WHERE n_sessao = 1 AND id_atividade = 27
ORDER BY dataInscricao;

-- Remover um participante da sessão lotada
DELETE FROM Part_Sessao
WHERE CPF = '70000000001'
  AND n_sessao = 1
  AND id_atividade = 27;

-- Verificar quem está inscrito depois
SELECT CPF
FROM Part_Sessao
WHERE n_sessao = 1 AND id_atividade = 27
ORDER BY CPF;

-- Verificar a lista de espera depois
SELECT CPF, dataInscricao
FROM Lista_de_Espera
WHERE n_sessao = 1 AND id_atividade = 27
ORDER BY dataInscricao;

-- Desfazer o teste para preservar os dados
ROLLBACK;


--testar preenchimento automatico da lista de espera
BEGIN;

-- Tentar inscrever outra pessoa na sessão lotada
INSERT INTO Part_Sessao (CPF, n_sessao, id_atividade)
VALUES ('70000000023', 1, 27);

-- Conferir se foi colocada na lista de espera
SELECT CPF, dataInscricao
FROM Lista_de_Espera
WHERE n_sessao = 1 AND id_atividade = 27
ORDER BY dataInscricao;

-- Desfazer o teste
ROLLBACK;