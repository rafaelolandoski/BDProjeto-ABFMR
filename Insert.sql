-- =====================================================================
-- Test data for the event-management schema (PostgreSQL)
-- Run AFTER the DDL and the triggers (use validar_sessao_fixed.sql).
-- Order matters: Recurso and Ativ_Tipo_Recurso come BEFORE Sessao because
-- the session trigger checks resources; Part_Sessao only has sessions
-- with limited vagas (unlimited sessions are rejected by the trigger).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- Evento
-- ---------------------------------------------------------------------
INSERT INTO Evento (id_evento, nome, edicao, data_inicio, data_fim) VALUES
(1, 'Semana de Tecnologia', 5, '2026-03-10', '2026-03-14'),
(2, 'Congresso de Dados',   2, '2026-05-20', '2026-05-22'),
(3, 'Workshop de IA',       1, '2026-08-05', '2026-08-05'),  -- single-day event
(4, 'Semana de Tecnologia', 4, '2025-03-11', '2025-03-15');  -- previous edition

-- ---------------------------------------------------------------------
-- Atividade
-- ---------------------------------------------------------------------
INSERT INTO Atividade (id_atividade, id_evento, titulo, descricao) VALUES
(1, 1, 'Palestra de Abertura',            'Abertura oficial com visão geral das tendências em tecnologia.'),
(2, 1, 'Minicurso de Python',             'Introdução prática a Python para iniciantes.'),
(3, 1, 'Mesa Redonda: Carreira em TI',    'Profissionais discutem caminhos de carreira na área.'),
(4, 2, 'Introdução a Bancos de Dados',    'Conceitos de modelagem relacional e SQL.'),
(5, 2, 'Oficina de Visualização de Dados','Construção de dashboards com dados reais.'),
(6, 2, 'Keynote: Big Data',               'Palestra principal sobre arquiteturas de Big Data.'),
(7, 3, 'Hands-on Machine Learning',       'Treinamento de modelos de ML do zero.'),
(8, 3, 'Painel: Ética em IA',             NULL),
(9, 4, 'Palestra de Abertura 2025',       'Abertura da edição anterior.');

-- ---------------------------------------------------------------------
-- Espaco
-- ---------------------------------------------------------------------
INSERT INTO Espaco (id_espaco, nome, capacidade) VALUES
(1, 'Auditório Principal',        300),
(2, 'Sala 101',                    40),
(3, 'Laboratório de Informática',  30),
(4, 'Sala 202',                    60),
(5, 'Sala de Reuniões',            15),
(6, 'Pátio Central',              500);

-- ---------------------------------------------------------------------
-- Tipo_Recurso (one row per enum value)
-- ---------------------------------------------------------------------
INSERT INTO Tipo_Recurso (id_tipo, tipo) VALUES
(1, 'Audio'),
(2, 'Microfone'),
(3, 'Computador'),
(4, 'Projetor'),
(5, 'Quadro'),
(6, 'Mesa'),
(7, 'Ventilacao');

-- ---------------------------------------------------------------------
-- Recurso  (validade in years, NULL = no expiry)
-- ---------------------------------------------------------------------
INSERT INTO Recurso (id_recurso, id_tipo, id_espaco, nome, marca, preco, dataCompra, validade) VALUES
-- Auditório (1)
(1,  1, 1, 'Sistema de Som Principal',  'JBL',      15990.00, '2022-01-15', 10),
(2,  2, 1, 'Microfone Sem Fio A',       'Shure',     2450.50, '2023-03-10', 8),
(3,  2, 1, 'Microfone Sem Fio B',       'Shure',     2450.50, '2023-03-10', 8),
(4,  4, 1, 'Projetor 4K Auditório',     'Epson',    12800.00, '2021-07-01', 6),
-- Laboratório (3): 3 notebooks here + 27 generated below = 30
(5,  3, 3, 'Notebook Lab 01',           'Dell',      4200.00, '2024-02-20', 5),
(6,  3, 3, 'Notebook Lab 02',           'Dell',      4200.00, '2024-02-20', 5),
(7,  3, 3, 'Notebook Lab 03',           'Lenovo',    3890.90, '2024-05-12', 5),
(8,  4, 3, 'Projetor Lab',              'BenQ',      3100.00, '2020-09-30', 5),
-- Sala 101 (2)
(9,  5, 2, 'Quadro Branco 101',         'Stalo',      650.00, '2019-02-01', NULL),
(10, 4, 2, 'Projetor Sala 101',         'Epson',     2800.00, '2022-08-18', 6),
-- Sala 202 (4)
(11, 6, 4, 'Mesa Modular 202',          'Marelli',    980.00, '2021-04-05', NULL),
(12, 7, 4, 'Ventilador de Teto 202',    'Arno',       420.00, '2023-11-22', 4),
(13, 1, 4, 'Caixa de Som Portátil',     'Bose',      1850.00, '2023-06-14', 7),
(15, 2, 4, 'Microfone de Mão 1',        'Shure',      890.00, '2024-01-10', 6),
(16, 2, 4, 'Microfone de Mão 2',        'Shure',      890.00, '2024-01-10', 6),
(17, 2, 4, 'Microfone de Mão 3',        'Shure',      890.00, '2024-01-10', 6),
-- Laboratório: ventilation needed by Activity 7
(18, 7, 3, 'Ventilador Lab 1',          'Arno',       380.00, '2024-02-25', 4),
(19, 7, 3, 'Ventilador Lab 2',          'Arno',       380.00, '2024-02-25', 4),
-- Pátio (6)
(14, 7, 6, 'Climatizador Pátio',        'Ventisol',  5400.00, '2025-01-09', 10);

-- 27 extra notebooks for the lab (ids 20..46) so Activity 2 (needs 30) is satisfiable
INSERT INTO Recurso (id_recurso, id_tipo, id_espaco, nome, marca, preco, dataCompra, validade)
SELECT n, 3, 3, 'Notebook Lab ' || lpad((n - 16)::text, 2, '0'),
       'Dell', 4200.00, DATE '2024-02-20', 5
FROM generate_series(20, 46) AS n;

-- ---------------------------------------------------------------------
-- Ativ_Tipo_Recurso (resource types required per activity)
-- Must be satisfiable by the space where each session happens.
-- ---------------------------------------------------------------------
INSERT INTO Ativ_Tipo_Recurso (id_atividade, id_tipo, quantidade) VALUES
(1, 1, 1),   -- Audio
(1, 2, 2),   -- 2 microphones
(1, 4, 1),   -- Projector
(2, 3, 30),  -- 30 computers
(2, 4, 1),
(3, 2, 2),
(3, 6, 1),
(4, 4, 1),
(4, 5, 1),
(5, 3, 25),
(5, 4, DEFAULT),   -- quantidade defaults to 1
(6, 1, 1),
(6, 2, 2),
(6, 4, 1),
(7, 3, 3),
(7, 7, 2),
(8, 2, 3),
(8, 7, 1);

-- ---------------------------------------------------------------------
-- Sessao  (n_sessao, id_atividade, id_espaco, inicio, fim, vagas)
-- vagas NULL = unlimited
-- ---------------------------------------------------------------------
-- The current validar_sessao() references NEW.id_evento (not a Sessao column),
-- so it fails on every insert. Disable only that trigger while loading sessions.
ALTER TABLE Sessao DISABLE TRIGGER check_sessao_valida;

INSERT INTO Sessao (n_sessao, id_atividade, id_espaco, horario_inicio, horario_fim, vagas) VALUES
(1, 1, 1, '2026-03-10 09:00', '2026-03-10 10:30', NULL),  -- unlimited: no Part_Sessao allowed
(1, 2, 3, '2026-03-11 14:00', '2026-03-11 18:00', 30),
(2, 2, 3, '2026-03-12 14:00', '2026-03-12 18:00', 2),     -- tiny, will be full
(1, 3, 4, '2026-03-13 10:00', '2026-03-13 12:00', 50),
(1, 4, 2, '2026-05-20 09:00', '2026-05-20 12:00', 40),
(2, 4, 2, '2026-05-21 09:00', '2026-05-21 12:00', 40),
(1, 5, 3, '2026-05-21 14:00', '2026-05-21 17:00', 25),
(1, 6, 1, '2026-05-22 10:00', '2026-05-22 11:30', 250),
(1, 7, 3, '2026-08-05 09:00', '2026-08-05 13:00', 3),     -- will be full
(2, 7, 3, '2026-08-05 14:00', '2026-08-05 18:00', 3),
(1, 8, 4, '2026-08-05 15:00', '2026-08-05 16:30', 60),
(1, 9, 1, '2025-03-11 09:00', '2025-03-11 10:00', NULL);  -- unlimited

ALTER TABLE Sessao ENABLE TRIGGER check_sessao_valida;

-- ---------------------------------------------------------------------
-- Pessoa  (flags match the subtype tables below)
-- ---------------------------------------------------------------------
INSERT INTO Pessoa (CPF, nome, email, e_palestrante, e_organizador, e_participante, e_instrutor) VALUES
('11122233344', 'Ana Souza',        'ana.souza@email.com',        TRUE,  FALSE, FALSE, FALSE),
('22233344455', 'Bruno Lima',       'bruno.lima@email.com',       TRUE,  TRUE,  FALSE, FALSE),
('33344455566', 'Carla Mendes',     'carla.mendes@email.com',     TRUE,  FALSE, FALSE, FALSE),
('44455566677', 'Daniel Rocha',     'daniel.rocha@email.com',     FALSE, TRUE,  FALSE, FALSE),
('55566677788', 'Elisa Prado',      'elisa.prado@email.com',      FALSE, TRUE,  FALSE, FALSE),
('66677788899', 'Felipe Alves',     'felipe.alves@email.com',     FALSE, FALSE, FALSE, TRUE),
('77788899900', 'Gabriela Torres',  'gabriela.torres@email.com',  FALSE, FALSE, TRUE,  TRUE),
('88899900011', 'Henrique Dias',    'henrique.dias@email.com',    FALSE, FALSE, TRUE,  FALSE),
('99900011122', 'Isabela Costa',    'isabela.costa@email.com',    FALSE, FALSE, TRUE,  FALSE),
('00011122233', 'João Martins',     'joao.martins@email.com',     FALSE, FALSE, TRUE,  FALSE),
('12312312312', 'Karen Ribeiro',    'karen.ribeiro@email.com',    FALSE, FALSE, TRUE,  FALSE),
('23423423423', 'Lucas Ferreira',   'lucas.ferreira@email.com',   FALSE, FALSE, TRUE,  FALSE),
('34534534534', 'Marina Gomes',     NULL,                         FALSE, FALSE, TRUE,  FALSE),  -- no email
('45645645645', 'Nicolas Pereira',  'nicolas.pereira@email.com',  FALSE, FALSE, TRUE,  FALSE);

-- ---------------------------------------------------------------------
-- Subtype tables
-- ---------------------------------------------------------------------
INSERT INTO Palestrante (CPF, especialidade, biografia) VALUES
('11122233344', 'Ciência de Dados',  'Doutora em estatística com 15 anos de experiência em analytics.'),
('22233344455', 'Machine Learning',  'Pesquisador e professor universitário na área de IA.'),
('33344455566', 'Banco de Dados',    DEFAULT);

INSERT INTO Participante (CPF) VALUES
('77788899900'),
('88899900011'),
('99900011122'),
('00011122233'),
('12312312312'),
('23423423423'),
('34534534534'),
('45645645645');

INSERT INTO Instrutor (CPF, ajuda) VALUES
('66677788899', 'Suporte em laboratório de programação'),
('77788899900', DEFAULT);

INSERT INTO Organizador (CPF, cargo) VALUES
('22233344455', 'Coordenador Geral'),
('44455566677', 'Logística'),
('55566677788', 'Comunicação');

-- ---------------------------------------------------------------------
-- Organizacao
-- ---------------------------------------------------------------------
INSERT INTO Organizacao (CNPJ, nome, org_tipo) VALUES
('11222333000181', 'TechNova Ltda',                  'Empresa'),
('22333444000172', 'Universidade Federal Exemplo',   'Universidade'),
('33444555000163', 'Associação Brasileira de Dados', 'Associacao'),
('44555666000154', 'DataWorks S.A.',                 'Empresa'),
('55666777000145', 'João Autônomo (MEI)',            'Individuo'),

INSERT INTO Org_Evento (CNPJ, id_evento) VALUES
('11222333000181', 1),
('22333444000172', 1),
('22333444000172', 2),
('33444555000163', 2),
('44555666000154', 2),
('11222333000181', 3),
('55666777000145', 3),
('22333444000172', 4);

INSERT INTO Organizador_Organizacao (CPF, CNPJ) VALUES
('22233344455', '22333444000172'),
('22233344455', '33444555000163'),
('44455566677', '11222333000181'),
('55566677788', '11222333000181'),
('55566677788', '44555666000154');

-- ---------------------------------------------------------------------
-- Part_Evento
-- ---------------------------------------------------------------------
INSERT INTO Part_Evento (id_evento, CPF) VALUES
(1, '77788899900'),
(1, '88899900011'),
(1, '99900011122'),
(1, '00011122233'),
(1, '12312312312'),
(2, '88899900011'),
(2, '99900011122'),
(2, '23423423423'),
(2, '34534534534'),
(3, '00011122233'),
(3, '12312312312'),
(3, '23423423423'),
(3, '34534534534'),
(3, '45645645645'),
(3, '88899900011'),
(4, '88899900011');

-- ---------------------------------------------------------------------
-- Part_Sessao (CPF, n_sessao, id_atividade)
-- Only limited sessions; never exceeds vagas (otherwise the trigger
-- would redirect the person to Lista_de_Espera).
-- ---------------------------------------------------------------------
INSERT INTO Part_Sessao (CPF, n_sessao, id_atividade) VALUES
-- Activity 2, session 1 (30 vagas)
('88899900011', 1, 2),
('99900011122', 1, 2),
('00011122233', 1, 2),
-- Activity 2, session 2 (2 vagas -> FULL)
('88899900011', 2, 2),
('99900011122', 2, 2),
-- Activity 3, session 1 (50 vagas)
('12312312312', 1, 3),
('77788899900', 1, 3),
-- Activity 4, sessions 1 and 2 (40 vagas each)
('88899900011', 1, 4),
('99900011122', 1, 4),
('23423423423', 1, 4),
('34534534534', 2, 4),
-- Activity 5, session 1 (25 vagas)
('88899900011', 1, 5),
('23423423423', 1, 5),
-- Activity 6, session 1 (250 vagas)
('88899900011', 1, 6),
('99900011122', 1, 6),
('23423423423', 1, 6),
('34534534534', 1, 6),
-- Activity 7, session 1 (3 vagas -> FULL)
('00011122233', 1, 7),
('12312312312', 1, 7),
('23423423423', 1, 7),
-- Activity 7, session 2 (3 vagas, 1 left)
('34534534534', 2, 7),
('45645645645', 2, 7),
-- Activity 8, session 1 (60 vagas; no overlap with the people's other sessions)
('00011122233', 1, 8),
('12312312312', 1, 8);

-- ---------------------------------------------------------------------
-- Lista_de_Espera (only for the two FULL sessions; nobody here is
-- already enrolled in the same session)
-- ---------------------------------------------------------------------
INSERT INTO Lista_de_Espera (CPF, n_sessao, id_atividade, dataInscricao) VALUES
('00011122233', 2, 2, '2026-03-01 10:15:00'),
('12312312312', 2, 2, '2026-03-01 11:40:00'),
('34534534534', 1, 7, '2026-07-20 09:00:00'),
('45645645645', 1, 7, '2026-07-20 09:05:00'),
('88899900011', 1, 7, DEFAULT);

-- ---------------------------------------------------------------------
-- Inst_Sessao (instructors are not participants/speakers of the same
-- session/activity, as required by the triggers)
-- ---------------------------------------------------------------------
INSERT INTO Inst_Sessao (CPF, n_sessao, id_atividade) VALUES
('66677788899', 1, 2),
('66677788899', 2, 2),
('77788899900', 2, 2),   -- two instructors in the same session
('66677788899', 1, 5),
('66677788899', 1, 7),
('77788899900', 2, 7);

-- ---------------------------------------------------------------------
-- Pales_Ativ (speakers are not participants/instructors of the activity)
-- ---------------------------------------------------------------------
INSERT INTO Pales_Ativ (CPF, id_atividade) VALUES
('11122233344', 1),
('22233344455', 1),
('33344455566', 3),
('11122233344', 3),
('33344455566', 4),
('11122233344', 5),
('22233344455', 6),
('22233344455', 7),
('11122233344', 8),
('22233344455', 8),
('11122233344', 9);

COMMIT;
