-- selecionar cronograma do evento x

SELECT  ev.nome AS evento,
        ev.edicao, 
        a.titulo AS atividade,
        s.n_sessao,
        s.horario_inicio,
        s.horario_fim,
        s.vagas,
        e.nome AS espaco
FROM Evento ev 
JOIN Atividade a ON a.id_evento=ev.id_evento 
LEFT JOIN Sessao s ON a.id_atividade=s.id_atividade
LEFT JOIN Espaco e ON s.id_espaco=e.id_espaco 
WHERE ev.nome='Semana de Tecnologia' AND ev.edicao=1
ORDER BY s.horario_inicio ASC NULLS LAST, a.titulo ASC;

-- buscar os participantes de uma atividade x

SELECT  E.nome as evento,
        E.edicao,
        A.titulo,  
        S.n_sessao, 
        P.nome as inscritos, P.CPF,  
        count(PS.CPF) over(
                PARTITION BY S.n_sessao, S.id_atividade
        ) AS participantes, 
        S.vagas, 
        S.vagas - count(PS.CPF) over(
            PARTITION BY S.n_sessao, S.id_atividade
        ) as vagas_remanescentes, 
        S.id_atividade 
FROM Sessao S
JOIN Part_Sessao PS ON S.n_sessao = PS.n_sessao AND S.id_atividade = PS.id_atividade
JOIN Pessoa P ON PS.CPF = P.CPF
JOIN Atividade A ON S.id_atividade = A.id_atividade
JOIN Evento E ON A.id_evento = E.id_evento
WHERE E.nome = 'Semana de Tecnologia' AND E.edicao = 5 AND A.titulo = 'Minicurso de Python';

--seleciona todos os espaços livres em determinado horário
SELECT  e.id_espaco,
        e.nome AS nome_espaco,
        e.capacidade FROM Espaco e
WHERE NOT EXISTS( SELECT 1 FROM Sessao s 
    WHERE s.id_espaco = e.id_espaco 
    AND (s.horario_inicio, s.horario_fim) OVERLAPS ('2026-10-20 08:00:00'::timestamp, '2026-10-20 12:00:00'::timestamp)
)
ORDER BY e.nome ASC;

--busca os participantes em lista de espera
SELECT  E.nome as evento, 
        E.edicao, 
        A.titulo as titulo_atividade,  
        S.n_sessao, 
        P.nome as inscritos_lista, 
        P.CPF,
        ROW_NUMBER() OVER (
    		PARTITION BY S.id_atividade, S.n_sessao 
    		ORDER BY L.dataInscricao
		) AS posicao_lista,
        S.vagas,
        L.dataInscricao,
        S.id_atividade 
FROM Sessao S
JOIN Lista_de_Espera L ON S.n_sessao = L.n_sessao AND S.id_atividade = L.id_atividade
JOIN Pessoa P ON L.CPF = P.CPF
JOIN Atividade A ON S.id_atividade = A.id_atividade
JOIN Evento E ON A.id_evento = E.id_evento;

-- quantidade de participantes inscritos por evento
SELECT
    E.nome AS evento,
    E.edicao,
    COUNT(PE.CPF) AS total_participantes
FROM Evento E
LEFT JOIN Part_Evento PE
    ON E.id_evento = PE.id_evento
GROUP BY E.id_evento, E.nome, E.edicao
ORDER BY total_participantes DESC;


-- atividades que possuem mais de uma sessão
SELECT
    A.titulo AS atividade,
    E.nome AS evento,
    E.edicao,
    COUNT(S.n_sessao) AS quantidade_sessoes
FROM Atividade A
JOIN Evento E
    ON A.id_evento = E.id_evento
JOIN Sessao S
    ON A.id_atividade = S.id_atividade
GROUP BY A.id_atividade, A.titulo,
         E.id_evento, E.nome, E.edicao
HAVING COUNT(S.n_sessao) > 1
ORDER BY quantidade_sessoes DESC;
