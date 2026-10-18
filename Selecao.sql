-- selecionar cronograma do evento x

SELECT ev.nome AS evento,ev.edicao, a.titulo AS atividade,s.n_sessao,s.horario_inicio,s.horario_fim,s.vagas,e.nome FROM Evento ev 
JOIN Atividade a ON a.id_evento=ev.id_evento LEFT JOIN Sessao s ON a.id_atividade=s.id_atividade
LEFT JOIN Espaco e ON s.id_espaco=e.id_espaco WHERE ev.nome='Semana da Engenharia de Computação' AND ev.edicao=2026
ORDER BY s.horario_inicio ASC NULLS LAST, a.titulo ASC;

-- buscar os participantes de uma atividade x

SELECT E.nome as evento, E.edicao, A.titulo,  S.n_sessao, P.nome as inscritos, P.CPF,  count(PS.CPF) over(PARTITION BY S.n_sessao, S.id_atividade) AS participantes, S.vagas, S.vagas - count(PS.CPF) over(PARTITION BY S.n_sessao, S.id_atividade) as vagas_remanescentes, S.id_atividade 
FROM Sessao S
JOIN Part_Sessao PS ON S.n_sessao = PS.n_sessao AND S.id_atividade = PS.id_atividade
JOIN Pessoa P ON PS.CPF = P.CPF
JOIN Atividade A ON S.id_atividade = A.id_atividade
JOIN Evento E ON A.id_evento = E.id_evento
WHERE E.nome = 'Semana de Tecnologia' AND E.edicao = 5 AND A.titulo = 'Minicurso de Python';
