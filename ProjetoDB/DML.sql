BEGIN;
 
-- ---------------------------------------------------------------------
-- 0. Wipe previous data (all tables listed together, so no CASCADE needed)
-- ---------------------------------------------------------------------
TRUNCATE TABLE
    Organizador_Organizacao, Pales_Ativ, Ativ_Tipo_Recurso, Inst_Sessao,
    Lista_de_Espera, Part_Sessao, Part_Evento, Org_Evento, Organizacao,
    Organizador, Instrutor, Participante, Palestrante, Pessoa,
    Recurso, Tipo_Recurso, Sessao, Espaco, Atividade, Evento;
 
-- ---------------------------------------------------------------------
-- Evento (7)
-- ---------------------------------------------------------------------
INSERT INTO Evento (id_evento, nome, edicao, data_inicio, data_fim) VALUES
(1, 'Semana de Tecnologia',     5, '2026-03-10', '2026-03-14'),
(2, 'Congresso de Dados',       2, '2026-05-20', '2026-05-22'),
(3, 'Workshop de IA',           1, '2026-08-05', '2026-08-05'),  -- single day
(4, 'Semana de Tecnologia',     4, '2025-03-11', '2025-03-15'),
(5, 'Congresso de Dados',       1, '2025-05-14', '2025-05-16'),
(6, 'Hackathon Universitário',  3, '2026-10-24', '2026-10-25'),
(7, 'Simpósio de Segurança',    1, '2026-11-16', '2026-11-18'),
(8, 'Feira de Inovação',        1, '2026-12-03', '2026-12-05');
 
-- ---------------------------------------------------------------------
-- Atividade (25)
-- ---------------------------------------------------------------------
INSERT INTO Atividade (id_atividade, id_evento, titulo, descricao) VALUES
(1,  1, 'Palestra de Abertura',               'Abertura oficial com visão geral das tendências em tecnologia.'),
(2,  1, 'Minicurso de Python',                'Introdução prática a Python para iniciantes.'),
(3,  1, 'Mesa Redonda: Carreira em TI',       'Profissionais discutem caminhos de carreira na área.'),
(4,  1, 'Workshop de Git e GitHub',           'Controle de versão na prática, em equipe.'),
(5,  1, 'Palestra de Encerramento',           NULL),
(6,  2, 'Introdução a Bancos de Dados',       'Conceitos de modelagem relacional e SQL.'),
(7,  2, 'Oficina de Visualização de Dados',   'Construção de dashboards com dados reais.'),
(8,  2, 'Keynote: Big Data',                  'Palestra principal sobre arquiteturas de Big Data.'),
(9,  2, 'Modelagem Dimensional',              'Esquemas estrela e flocos de neve.'),
(10, 2, 'Pipelines de Dados na Prática',      'Construção de pipelines ETL/ELT.'),
(11, 3, 'Hands-on Machine Learning',          'Treinamento de modelos de ML do zero.'),
(12, 3, 'Painel: Ética em IA',                NULL),
(13, 3, 'Prompt Engineering',                 'Boas práticas para trabalhar com modelos de linguagem.'),
(14, 3, 'Visão Computacional com Python',     'Classificação de imagens com redes neurais.'),
(15, 4, 'Palestra de Abertura 2025',          'Abertura da edição anterior.'),
(16, 4, 'Introdução a Linux',                 'Linha de comando e administração básica.'),
(17, 5, 'Fundamentos de Estatística',         'Estatística descritiva e inferencial.'),
(18, 5, 'Keynote: Dados e Sociedade',         NULL),
(19, 6, 'Cerimônia de Abertura',              'Abertura do hackathon e apresentação dos desafios.'),
(20, 6, 'Maratona de Código',                 'Dois dias de desenvolvimento intensivo.'),
(21, 6, 'Pitch Final dos Projetos',           'Apresentação dos projetos para a banca.'),
(22, 7, 'Introdução à Segurança da Informação','Princípios de confidencialidade, integridade e disponibilidade.'),
(23, 7, 'Laboratório de Pentest Ético',       'Testes de invasão em ambiente controlado.'),
(24, 7, 'Mesa: Proteção de Dados e LGPD',     'Impactos da LGPD nas organizações.'),
(25, 7, 'Workshop de Criptografia',           'Criptografia simétrica, assimétrica e hashing.'),
(26, 8, 'Palestra de Abertura - Inovação', 'Apresentação das novas tecnologias e projetos.'),
(27, 8, 'Oficina de Python Aplicado', 'Desenvolvimento prático de aplicações com Python.');
 
-- ---------------------------------------------------------------------
-- Espaco (10)
-- ---------------------------------------------------------------------
INSERT INTO Espaco (id_espaco, nome, capacidade) VALUES
(1,  'Auditório Principal',          300),
(2,  'Sala 101',                      40),
(3,  'Laboratório de Informática 1',  30),
(4,  'Sala 202',                      60),
(5,  'Sala de Reuniões',              15),
(6,  'Pátio Central',                500),
(7,  'Laboratório de Informática 2',  40),
(8,  'Auditório Menor',              120),
(9,  'Sala 303',                      50),
(10, 'Espaço Maker',                  25);
 
-- ---------------------------------------------------------------------
-- Tipo_Recurso (one per enum value)
-- ---------------------------------------------------------------------
INSERT INTO Tipo_Recurso (id_tipo, tipo) VALUES
(1, 'Audio'), (2, 'Microfone'), (3, 'Computador'), (4, 'Projetor'),
(5, 'Quadro'), (6, 'Mesa'), (7, 'Ventilacao');
 
-- ---------------------------------------------------------------------
-- Recurso (~145 rows generated from a compact spec)
-- columns of the spec: espaco, tipo, quantidade, nome, marca, preço unitário, data compra, validade (anos)
-- ---------------------------------------------------------------------
INSERT INTO Recurso (id_recurso, id_tipo, id_espaco, nome, marca, preco, dataCompra, validade)
SELECT row_number() OVER (ORDER BY v.id_espaco, v.id_tipo, g),
       v.id_tipo, v.id_espaco,
       v.nome || ' #' || lpad(g::text, 2, '0'),
       v.marca, v.preco, v.data_compra, v.validade
FROM (VALUES
  (1, 1,  2, 'Caixa de Som Auditório',        'JBL',      15990.00, DATE '2022-01-15', 10),
  (1, 2,  4, 'Microfone Sem Fio Auditório',   'Shure',     2450.50, DATE '2023-03-10',  8),
  (1, 4,  2, 'Projetor 4K Auditório',         'Epson',    12800.00, DATE '2021-07-01',  6),
  (1, 7,  2, 'Ventilador Auditório',          'Arno',       620.00, DATE '2022-02-10',  5),
  (2, 5,  1, 'Quadro Branco Sala 101',        'Stalo',      650.00, DATE '2019-02-01', NULL),
  (2, 4,  1, 'Projetor Sala 101',             'Epson',     2800.00, DATE '2022-08-18',  6),
  (2, 7,  1, 'Ventilador Sala 101',           'Arno',       420.00, DATE '2023-11-22',  4),
  (3, 3, 30, 'Notebook Lab 1',                'Dell',      4200.00, DATE '2024-02-20',  5),
  (3, 4,  1, 'Projetor Lab 1',                'BenQ',      3100.00, DATE '2020-09-30',  5),
  (3, 7,  2, 'Ventilador Lab 1',              'Arno',       380.00, DATE '2024-02-25',  4),
  (3, 5,  1, 'Quadro Lab 1',                  'Stalo',      700.00, DATE '2020-09-30', NULL),
  (4, 6,  4, 'Mesa Modular Sala 202',         'Marelli',    980.00, DATE '2021-04-05', NULL),
  (4, 7,  2, 'Ventilador de Teto Sala 202',   'Arno',       420.00, DATE '2023-11-22',  4),
  (4, 1,  1, 'Caixa de Som Portátil 202',     'Bose',      1850.00, DATE '2023-06-14',  7),
  (4, 2,  3, 'Microfone de Mão Sala 202',     'Shure',      890.00, DATE '2024-01-10',  6),
  (4, 4,  1, 'Projetor Sala 202',             'Epson',     3000.00, DATE '2022-08-18',  6),
  (5, 6,  2, 'Mesa de Reunião',               'Marelli',   1500.00, DATE '2020-05-05', NULL),
  (5, 5,  1, 'Quadro de Vidro',               'Stalo',     1100.00, DATE '2021-01-12', NULL),
  (5, 4,  1, 'Projetor Sala de Reuniões',     'Epson',     2500.00, DATE '2021-01-12',  6),
  (6, 1,  2, 'Caixa de Som Pátio',            'JBL',       8900.00, DATE '2025-01-09', 10),
  (6, 7,  4, 'Climatizador Pátio',            'Ventisol',  5400.00, DATE '2025-01-09', 10),
  (6, 2,  2, 'Microfone Sem Fio Pátio',       'Shure',     2100.00, DATE '2025-01-09',  8),
  (7, 3, 40, 'Notebook Lab 2',                'Lenovo',    3890.90, DATE '2025-02-15',  5),
  (7, 4,  1, 'Projetor Lab 2',                'BenQ',      3300.00, DATE '2025-02-15',  5),
  (7, 5,  1, 'Quadro Lab 2',                  'Stalo',      700.00, DATE '2025-02-15', NULL),
  (8, 1,  1, 'Caixa de Som Auditório Menor',  'Bose',      4200.00, DATE '2023-08-01',  8),
  (8, 2,  3, 'Microfone Auditório Menor',     'Shure',     1900.00, DATE '2023-08-01',  8),
  (8, 4,  1, 'Projetor Auditório Menor',      'Epson',     6800.00, DATE '2023-08-01',  6),
  (8, 7,  2, 'Ventilador Auditório Menor',    'Arno',       560.00, DATE '2023-08-01',  5),
  (9, 5,  2, 'Quadro Branco Sala 303',        'Stalo',      650.00, DATE '2022-03-03', NULL),
  (9, 4,  1, 'Projetor Sala 303',             'Epson',     2900.00, DATE '2022-03-03',  6),
  (9, 6,  6, 'Mesa Sala 303',                 'Marelli',    900.00, DATE '2022-03-03', NULL),
  (9, 7,  1, 'Ventilador Sala 303',           'Arno',       420.00, DATE '2022-03-03',  4),
  (10,3, 10, 'Notebook Maker',                'Acer',      3500.00, DATE '2025-06-20',  5),
  (10,6,  4, 'Bancada Maker',                 'Marelli',   1800.00, DATE '2025-06-20', NULL),
  (10,5,  1, 'Quadro Maker',                  'Stalo',      600.00, DATE '2025-06-20', NULL),
  (10,7,  1, 'Ventilador Maker',              'Arno',       450.00, DATE '2025-06-20',  4)
) AS v(id_espaco, id_tipo, qtd, nome, marca, preco, data_compra, validade)
CROSS JOIN LATERAL generate_series(1, v.qtd) AS g;
 
-- ---------------------------------------------------------------------
-- Ativ_Tipo_Recurso (what each activity needs; every session's space
-- holds at least these quantities)
-- ---------------------------------------------------------------------
INSERT INTO Ativ_Tipo_Recurso (id_atividade, id_tipo, quantidade) VALUES
(1, 1, 1), (1, 2, 2), (1, 4, 1),
(2, 3, 30), (2, 4, 1),
(3, 2, 2), (3, 6, 1),
(4, 3, 35), (4, 4, 1),
(5, 1, 1), (5, 2, 2),
(6, 4, 1), (6, 5, 1),
(7, 3, 25), (7, 4, DEFAULT),       -- quantidade defaults to 1
(8, 1, 1), (8, 2, 2), (8, 4, 1),
(9, 5, 2), (9, 6, 6),
(10, 3, 30), (10, 4, 1),
(11, 3, 3), (11, 7, 2),
(12, 2, 3), (12, 7, 1),
(13, 3, 20), (13, 4, 1),
(14, 3, 10), (14, 6, 4),
(15, 1, 1),
(16, 3, 30), (16, 4, 1),
(17, 4, 1), (17, 5, 1),
(18, 1, 1), (18, 2, 2), (18, 4, 1),
(19, 1, 2), (19, 7, 2),
(20, 3, 40), (20, 4, 1),
(21, 1, 1), (21, 2, 2), (21, 4, 1),
(22, 5, 1), (22, 4, 1),
(23, 3, 20), (23, 7, 1),
(24, 2, 2), (24, 6, 2),
(25, 4, 1), (25, 5, 1),
(26, 1, 1), (26, 2, 1), (26, 4, 1),
(27, 3, 25), (27, 4, 1);
 
-- ---------------------------------------------------------------------
-- Sessao (31)  columns: n_sessao, id_atividade, id_espaco, inicio, fim, vagas
-- vagas NULL = unlimited (those sessions cannot have Part_Sessao rows)
-- No two sessions overlap in the same room; vagas <= room capacity.
-- ---------------------------------------------------------------------
INSERT INTO Sessao (n_sessao, id_atividade, id_espaco, horario_inicio, horario_fim, vagas) VALUES
-- Evento 1
(1, 1,  1, '2026-03-10 09:00', '2026-03-10 10:30', NULL),
(1, 2,  3, '2026-03-11 14:00', '2026-03-11 18:00', 30),
(2, 2,  3, '2026-03-12 14:00', '2026-03-12 18:00', 2),     -- will be FULL
(1, 3,  4, '2026-03-13 10:00', '2026-03-13 12:00', 50),
(1, 4,  7, '2026-03-11 09:00', '2026-03-11 12:00', 40),
(1, 5,  1, '2026-03-14 16:00', '2026-03-14 17:30', NULL),
-- Evento 2
(1, 6,  2, '2026-05-20 09:00', '2026-05-20 12:00', 40),
(2, 6,  2, '2026-05-21 09:00', '2026-05-21 12:00', 40),
(1, 7,  3, '2026-05-21 14:00', '2026-05-21 17:00', 25),    -- will be FULL
(1, 8,  1, '2026-05-22 10:00', '2026-05-22 11:30', 250),
(1, 9,  9, '2026-05-20 14:00', '2026-05-20 17:00', 50),
(1, 10, 7, '2026-05-21 09:00', '2026-05-21 12:00', 40),
(2, 10, 7, '2026-05-22 14:00', '2026-05-22 17:00', 6),     -- will be FULL
-- Evento 3
(1, 11, 3, '2026-08-05 09:00', '2026-08-05 13:00', 3),     -- will be FULL
(2, 11, 3, '2026-08-05 14:00', '2026-08-05 18:00', 3),
(1, 12, 4, '2026-08-05 15:00', '2026-08-05 16:30', 60),
(1, 13, 7, '2026-08-05 09:00', '2026-08-05 12:00', 40),
(1, 14, 10,'2026-08-05 10:00', '2026-08-05 14:00', 10),
-- Evento 4 (2025)
(1, 15, 1, '2025-03-11 09:00', '2025-03-11 10:00', NULL),
(1, 16, 3, '2025-03-12 14:00', '2025-03-12 17:00', 30),
-- Evento 5 (2025)
(1, 17, 2, '2025-05-14 09:00', '2025-05-14 12:00', 40),
(1, 18, 8, '2025-05-15 10:00', '2025-05-15 11:30', 100),
-- Evento 6
(1, 19, 6, '2026-10-24 09:00', '2026-10-24 10:00', NULL),
(1, 20, 7, '2026-10-24 10:00', '2026-10-24 18:00', 40),
(2, 20, 7, '2026-10-25 09:00', '2026-10-25 14:00', 40),
(1, 21, 8, '2026-10-25 15:00', '2026-10-25 17:00', 100),
-- Evento 7
(1, 22, 9, '2026-11-16 09:00', '2026-11-16 12:00', 50),
(1, 23, 3, '2026-11-17 14:00', '2026-11-17 18:00', 20),
(2, 23, 3, '2026-11-18 14:00', '2026-11-18 18:00', 20),
(1, 24, 4, '2026-11-17 10:00', '2026-11-17 12:00', 60),
(1, 25, 2, '2026-11-18 09:00', '2026-11-18 12:00', 30),
(1, 26, 1, '2026-12-03 09:00', '2026-12-03 10:30', NULL),
(1, 27, 3, '2026-12-03 14:00', '2026-12-03 17:00', 20),
(2, 27, 3, '2026-12-04 14:00', '2026-12-04 17:00', 15);
 
-- ---------------------------------------------------------------------
-- Pessoa
--  a) named staff (speakers, organizers, instructors) + Gabriela (instructor AND participant)
--  b) 40 generated participants, CPF = 70000000001 .. 70000000040
-- ---------------------------------------------------------------------
INSERT INTO Pessoa (CPF, nome, email, e_palestrante, e_organizador, e_participante, e_instrutor) VALUES
-- speakers
('11122233344', 'Ana Souza',         'ana.souza@email.com',       TRUE,  FALSE, FALSE, FALSE),
('22233344455', 'Bruno Lima',        'bruno.lima@email.com',      TRUE,  TRUE,  FALSE, FALSE),  -- speaker + organizer
('33344455566', 'Carla Mendes',      'carla.mendes@email.com',    TRUE,  FALSE, FALSE, FALSE),
('90000000001', 'Diego Cardoso',     'diego.cardoso@email.com',   TRUE,  FALSE, FALSE, FALSE),
('90000000002', 'Eduarda Nunes',     'eduarda.nunes@email.com',   TRUE,  TRUE,  FALSE, FALSE),  -- speaker + organizer
('90000000003', 'Fernando Teixeira', 'fernando.teixeira@email.com', TRUE, FALSE, FALSE, FALSE),
('90000000004', 'Helena Barros',     'helena.barros@email.com',   TRUE,  FALSE, FALSE, FALSE),
('90000000005', 'Igor Monteiro',     NULL,                        TRUE,  FALSE, FALSE, FALSE),
-- organizers
('44455566677', 'Daniel Rocha',      'daniel.rocha@email.com',    FALSE, TRUE,  FALSE, FALSE),
('55566677788', 'Elisa Prado',       'elisa.prado@email.com',     FALSE, TRUE,  FALSE, FALSE),
('91000000001', 'Paulo Vieira',      'paulo.vieira@email.com',    FALSE, TRUE,  FALSE, FALSE),
('91000000002', 'Renata Lopes',      'renata.lopes@email.com',    FALSE, TRUE,  FALSE, FALSE),
('91000000003', 'Sérgio Matos',      'sergio.matos@email.com',    FALSE, TRUE,  FALSE, FALSE),
-- instructors
('66677788899', 'Felipe Alves',      'felipe.alves@email.com',    FALSE, FALSE, FALSE, TRUE),
('77788899900', 'Gabriela Torres',   'gabriela.torres@email.com', FALSE, FALSE, TRUE,  TRUE),   -- instructor + participant
('80000000001', 'Tiago Azevedo',     'tiago.azevedo@email.com',   FALSE, FALSE, FALSE, TRUE),
('80000000002', 'Vanessa Cruz',      'vanessa.cruz@email.com',    FALSE, FALSE, FALSE, TRUE),
('80000000003', 'Wagner Silva',      'wagner.silva@email.com',    FALSE, FALSE, FALSE, TRUE),
('80000000004', 'Yara Freitas',      NULL,                        FALSE, FALSE, FALSE, TRUE);
 
INSERT INTO Pessoa (CPF, nome, email, e_palestrante, e_organizador, e_participante, e_instrutor)
SELECT (70000000000 + n)::text,
       (ARRAY['Henrique','Isabela','João','Karen','Lucas','Marina','Nicolas','Otávio','Patrícia','Rafael'])[(n - 1) % 10 + 1]
         || ' ' ||
       (ARRAY['Dias','Costa','Martins','Ribeiro'])[(n - 1) / 10 + 1],
       CASE WHEN n % 13 = 0 THEN NULL ELSE 'participante' || n || '@email.com' END,
       FALSE, FALSE, TRUE, FALSE
FROM generate_series(1, 40) AS n;
 
-- ---------------------------------------------------------------------
-- Subtype tables
-- ---------------------------------------------------------------------
INSERT INTO Palestrante (CPF, especialidade, biografia) VALUES
('11122233344', 'Ciência de Dados',        'Doutora em estatística com 15 anos de experiência em analytics.'),
('22233344455', 'Machine Learning',        'Pesquisador e professor universitário na área de IA.'),
('33344455566', 'Banco de Dados',          DEFAULT),
('90000000001', 'Engenharia de Dados',     'Engenheiro de dados sênior, palestrante em eventos internacionais.'),
('90000000002', 'Ética e Sociedade',       'Pesquisadora em ética aplicada à tecnologia.'),
('90000000003', 'Segurança da Informação', 'Consultor de segurança e perito em forense digital.'),
('90000000004', 'Visão Computacional',     DEFAULT),
('90000000005', 'Inteligência Artificial', 'Líder de pesquisa em modelos de linguagem.');
 
INSERT INTO Participante (CPF) VALUES ('77788899900');   -- Gabriela
INSERT INTO Participante (CPF)
SELECT (70000000000 + n)::text FROM generate_series(1, 40) AS n;
 
INSERT INTO Instrutor (CPF, ajuda) VALUES
('66677788899', 'Suporte em laboratório de programação'),
('77788899900', DEFAULT),                                -- 'geral'
('80000000001', 'Monitoria de Git e desenvolvimento'),
('80000000002', 'Suporte em ciência de dados'),
('80000000003', DEFAULT),
('80000000004', 'Suporte em Linux e redes');
 
INSERT INTO Organizador (CPF, cargo) VALUES
('22233344455', 'Coordenador Geral'),
('44455566677', 'Logística'),
('55566677788', 'Comunicação'),
('90000000002', 'Programação Científica'),
('91000000001', 'Patrocínios'),
('91000000002', 'Infraestrutura'),
('91000000003', 'Segurança do Evento');
 
-- ---------------------------------------------------------------------
-- Organizacao (10)
-- Organizations of type 'Individuo' have exactly ONE organizer (rule of trigger 6)
-- ---------------------------------------------------------------------
INSERT INTO Organizacao (CNPJ, nome, org_tipo) VALUES
('11222333000181', 'TechNova Ltda',                       'Empresa'),
('22333444000172', 'Universidade Federal Exemplo',        'Universidade'),
('33444555000163', 'Associação Brasileira de Dados',      'Associacao'),
('44555666000154', 'DataWorks S.A.',                      'Empresa'),
('55666777000145', 'João Autônomo (MEI)',                 'Individuo'),
('66777888000136', 'Instituto Sem Fronteiras',                  'Empresa'),
('77888999000127', 'Universidade Estadual de Tecnologia', 'Universidade'),
('88999000000118', 'Associação de Segurança Digital',     'Associacao'),
('99000111000109', 'Maria Consultoria',                   'Individuo'),
('10111222000190', 'CloudSul Tecnologia',                 'Empresa');
 
INSERT INTO Org_Evento (CNPJ, id_evento) VALUES
('11222333000181', 1), ('22333444000172', 1),
('22333444000172', 2), ('33444555000163', 2), ('44555666000154', 2),
('11222333000181', 3), ('55666777000145', 3),
('22333444000172', 4), ('11222333000181', 4),
('33444555000163', 5), ('77888999000127', 5),
('77888999000127', 6), ('10111222000190', 6), ('11222333000181', 6),
('88999000000118', 7), ('10111222000190', 7), ('99000111000109', 7),
('11222333000181', 8), ('22333444000172', 8);
 
INSERT INTO Organizador_Organizacao (CPF, CNPJ) VALUES
('22233344455', '22333444000172'),
('22233344455', '33444555000163'),
('44455566677', '11222333000181'),
('44455566677', '10111222000190'),
('55566677788', '11222333000181'),
('55566677788', '44555666000154'),
('90000000002', '77888999000127'),
('90000000002', '33444555000163'),
('91000000001', '55666777000145'),   -- Individuo: only organizer
('91000000002', '99000111000109'),   -- Individuo: only organizer
('91000000003', '88999000000118'),
('91000000003', '10111222000190');
 
-- ---------------------------------------------------------------------
-- Part_Evento: participants (n = 1..40 -> CPF 70000000000+n) per event
-- ---------------------------------------------------------------------
INSERT INTO Part_Evento (id_evento, CPF)
SELECT v.e, (70000000000 + n)::text
FROM (VALUES
    (1, 1, 25),
    (2, 6, 35),
    (3, 20, 40),
    (4, 1, 12),
    (5, 5, 20),
    (6, 15, 40),
    (7, 1, 10),
    (7, 30, 40),
    (8, 1, 29)
) AS v(e, lo, hi),
generate_series(v.lo, v.hi) AS n;
 
INSERT INTO Part_Evento (id_evento, CPF) VALUES (1, '77788899900'), (8, '77788899900');   -- Gabriela
 
-- ---------------------------------------------------------------------
-- Part_Sessao: everyone enrolled is registered in the session's event,
-- only limited sessions are used, and nobody exceeds vagas.
-- FULL sessions: (2,2) 2/2, (1,7) 25/25, (2,10) 6/6, (1,11) 3/3.
-- ---------------------------------------------------------------------
INSERT INTO Part_Sessao (CPF, n_sessao, id_atividade)
SELECT (70000000000 + n)::text, v.ns, v.ia
FROM (VALUES
    -- (n_sessao, id_atividade, first n, last n)
    (2, 2,   1,  2),
    (1, 2,   1, 15),
    (1, 3,   3, 22),
    (1, 4,   5, 25),
    (1, 6,   6, 30),
    (2, 6,  21, 35),
    (1, 7,   6, 30),
    (1, 8,   6, 35),
    (1, 9,  10, 35),
    (1, 10,  6, 20),
    (2, 10, 21, 26),
    (1, 11, 20, 22),
    (2, 11, 23, 24),
    (1, 12, 25, 40),
    (1, 13, 25, 35),
    (1, 14, 36, 40),
    (1, 16,  1, 12),
    (1, 17,  5, 20),
    (1, 18,  5, 20),
    (1, 20, 15, 40),
    (2, 20, 15, 40),
    (1, 21, 15, 40),
    (1, 22,  1, 10),
    (1, 22, 30, 40),
    (1, 23,  1, 10),
    (1, 23, 30, 37),
    (2, 23,  1,  5),
    (2, 23, 31, 40),
    (1, 24,  1, 10),
    (1, 24, 30, 40),
    (1, 25,  1, 10),
    (1, 25, 30, 40),
    (1, 27,  1, 20),
    (2, 27, 15, 29)
) AS v(ns, ia, lo, hi),
generate_series(v.lo, v.hi) AS n;
 
INSERT INTO Part_Sessao (CPF, n_sessao, id_atividade) VALUES ('77788899900', 1, 3);   -- Gabriela
 
-- ---------------------------------------------------------------------
-- Lista_de_Espera: only for FULL sessions; nobody here is already
-- enrolled in the same session; all are registered in the event.
-- ---------------------------------------------------------------------
INSERT INTO Lista_de_Espera (CPF, n_sessao, id_atividade, dataInscricao) VALUES
-- (2,2): 2/2
('70000000003', 2, 2,  '2026-03-01 10:00:00'),
('70000000004', 2, 2,  '2026-03-01 10:07:00'),
('70000000005', 2, 2,  '2026-03-01 11:40:00'),
-- (1,7): 25/25
('70000000031', 1, 7,  '2026-05-02 08:15:00'),
('70000000032', 1, 7,  '2026-05-02 09:30:00'),
('70000000033', 1, 7,  '2026-05-03 14:00:00'),
-- (2,10): 6/6
('70000000027', 2, 10, '2026-05-04 16:20:00'),
('70000000028', 2, 10, '2026-05-04 16:45:00'),
-- (1,11): 3/3
('70000000023', 1, 11, '2026-07-20 09:00:00'),
('70000000024', 1, 11, '2026-07-20 09:05:00'),
('70000000025', 1, 11, DEFAULT),
('70000000021', 1, 27, '2026-10-27 09:00:00'),
('70000000022', 1, 27, '2026-10-27 09:10:00');       -- uses CURRENT_TIMESTAMP
 
-- ---------------------------------------------------------------------
-- Inst_Sessao: instructors are never participants or speakers of the
-- same session/activity and are not double-booked.
-- ---------------------------------------------------------------------
INSERT INTO Inst_Sessao (CPF, n_sessao, id_atividade) VALUES
('66677788899', 1, 2),
('66677788899', 2, 2),
('77788899900', 2, 2),     -- two instructors in the same session
('80000000001', 1, 4),
('66677788899', 1, 7),
('80000000002', 1, 10),
('80000000002', 2, 10),
('80000000003', 2, 10),
('66677788899', 1, 11),
('77788899900', 2, 11),
('80000000001', 1, 13),
('80000000003', 1, 14),
('80000000004', 1, 16),
('66677788899', 1, 20),
('80000000001', 1, 20),
('80000000004', 2, 20),
('80000000002', 1, 23),
('80000000002', 2, 23),
('80000000003', 2, 23),
('77788899900', 1, 25),
('66677788899', 1, 27),
('77788899900', 2, 27);
 
-- ---------------------------------------------------------------------
-- Pales_Ativ: speakers are never participants/instructors of the activity
-- ---------------------------------------------------------------------
INSERT INTO Pales_Ativ (CPF, id_atividade) VALUES
('11122233344', 1), ('22233344455', 1),
('90000000001', 2),
('33344455566', 3), ('90000000001', 3), ('90000000004', 3),
('90000000003', 4),
('11122233344', 5),
('33344455566', 6),
('11122233344', 7),
('22233344455', 8), ('90000000002', 8),
('33344455566', 9),
('90000000003', 10),
('22233344455', 11),
('11122233344', 12), ('90000000005', 12), ('90000000004', 12),
('90000000005', 13),
('90000000004', 14),
('11122233344', 15),
('90000000003', 16),
('90000000002', 17),
('90000000002', 18), ('33344455566', 18),
('22233344455', 19),
('90000000001', 20),
('90000000004', 21), ('90000000005', 21),
('90000000003', 22),
('90000000005', 23),
('90000000002', 24), ('33344455566', 24),
('90000000001', 25),
('11122233344', 26),
('90000000001', 27);
 
COMMIT;
