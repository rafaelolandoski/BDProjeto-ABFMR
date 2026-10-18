-- selecionar cronograma do evento x

SELECT ev.nome AS evento,ev.edicao, a.titulo AS atividade,s.n_sessao,s.horario_inicio,s.horario_fim,s.vagas,e.nome FROM Evento ev 
JOIN Atividade a ON a.id_evento=ev.id_evento LEFT JOIN Sessao s ON a.id_atividade=s.id_atividade
LEFT JOIN Espaco e ON s.id_espaco=e.id_espaco WHERE ev.nome='Semana da Engenharia de Computação' AND ev.edicao=2026
ORDER BY s.horario_inicio ASC NULLS LAST, a.titulo ASC;

