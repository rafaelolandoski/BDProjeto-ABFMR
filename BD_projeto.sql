
CREATE TYPE proposito AS ENUM ('Audio', 'Microfone', 'Computador', 'Projetor','Quadro','Mesa','Ventilacao');
CREATE TYPE tp AS ENUM ('Individuo', 'Empresa', 'Universidade', "Associacao");

CREATE TABLE Evento(
    id_evento integer PRIMARY KEY,
    nome varchar(50) NOT NULL,
    edicao bigint  NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    CONSTRAINT uq_nome_edicao UNIQUE(nome,edicao)
);

CREATE TABLE Atividade(
    id_atividade integer PRIMARY KEY,
    id_evento integer NOT NULL,
    titulo varchar(50) NOT NULL,
    descricao text,
    CONSTRAINT fk_atv_evento FOREIGN KEY (id_evento)
    REFERENCES evento(id_evento) ON DELETE CASCADE ON UPDATE RESTRICT
);

CREATE TABLE Sessao(
    n_sessao smallint NOT NULL,
    id_atividade integer NOT NULL,
    id_espaco integer NOT NULL,
    horario_inicio timestamp NOT NULL,
    vagas smallint, -- se nulo, não tem limite
    CONSTRAINT pk_sessao PRIMARY KEY (id_atividade,n_sessao),

    CONSTRAINT fk_sessao_espaco FOREIGN KEY (id_espaco) 
    REFERENCES Espaco(id_espaco) ON DELETE CASCADE,

    CONSTRAINT fk_sessao_atv FOREIGN KEY(id_atividade)
    REFERENCES atividade(id_atividade) ON DELETE CASCADE ON UPDATE RESTRICT --sem garantia que nova atividade cabe nos
    --mesmos horarios
);

CREATE TABLE Espaco(
    id_espaco integer PRIMARY KEY,
    nome varchar(50) NOT NULL,
    capacidade smallint,


);
CREATE TABLE Tipo_Recurso(
    id_tipo integer PRIMARY KEY,
    tipo proposito NOT NULL UNIQUE,



);
CREATE TABLE Recurso(
    id_recurso integer PRIMARY KEY,
    id_tipo integer NOT NULL,
    id_espaco integer,
    preco numeric(9,2) NOT NULL,
    dataCompra date NOT NULL,
    validade integer, --anos,
    precisaTrocar boolean,

    CONSTRAINT fk_tipo_recurso FOREIGN KEY (id_tipo) 
    REFERENCES Tipo_Recurso (id_tipo),
    CONSTRAINT fk_rec_espaco FOREIGN KEY (id_espaco)
    REFERENCES Espaco(id_espaco),
    CONSTRAINT ck_validade CHECK(validade > 0)
);

CREATE TABLE Pessoa(
    CPF char (11) PRIMARY KEY,
    nome varchar(50) NOT NULL,
    e_palestrante boolean DEFAULT FALSE,
    e_organizador boolean DEFAULT FALSE,
    e_participante boolean DEFAULT FALSE,
    e_instrutor boolean DEFAULT FALSE,

    CONSTRAINT ck_pelo_menos_um CHECK
    (e_palestrante = TRUE OR e_instrutor = TRUE OR e_organizador = TRUE OR e_participante = TRUE )
);

CREATE TABLE Palestrante(
    CPF char(11) PRIMARY KEY,
    especialidade varchar(30),
    biografia text DEFAULT 'nenhuma',
    CONSTRAINT fk_pales FOREIGN KEY (CPF)
    REFERENCES Pessoa(CPF)

);
CREATE TABLE Participante(
    CPF char(11) PRIMARY KEY,
    inscricoes integer,
    CONSTRAINT fk_parti FOREIGN KEY (CPF)
    REFERENCES Pessoa(CPF)
    

);
CREATE TABLE Instrutor(
    CPF char(11) PRIMARY KEY,
    ajuda text DEFAULT 'geral',
    CONSTRAINT fk_inst FOREIGN KEY (CPF)
    REFERENCES Pessoa(CPF)
    

);
CREATE TABLE Organizador(
    CPF char(11) PRIMARY KEY,
    cargo varchar (30),
    CONSTRAINT fk_org FOREIGN KEY (CPF)
    REFERENCES Pessoa(CPF)
    

);

CREATE TABLE Organizacao(
    CNPJ char(14) PRIMARY KEY,
    nome varchar(50) NOT NULL,
    org_tipo tp
);

CREATE TABLE Org_Evento(
    CNPJ char(14) NOT NULL,
    id_evento integer,
    CONSTRAINT pk_org_evento PRIMARY KEY(CNPJ, id_evento),
    CONSTRAINT fk_org_cnpj FOREIGN KEY(CNPJ)
    REFERENCES Organizacao(CNPJ)
    ON DELETE OR UPDATE CASCADE,
    CONSTRAINT fk_evento_id FOREIGN KEY(id_evento)
    REFERENCES Evento (id_evento)
    ON DELETE OR UPDATE CASCADE
);

CREATE TABLE Part_Evento(
    id_evento integer NOT NULL,
    CPF char(11) NOT NULL,
    CONSTRAINT pk_part_evento PRIMARY KEY(id_evento,CPF),
    CONSTRAINT fk_part_e FOREIGN KEY (CPF) 
    REFERENCES Participante (CPF),
    CONSTRAINT fk_event FOREIGN KEY (id_evento) 
    REFERENCES Evento (id_evento)
);

CREATE TABLE Part_Sessao(
    CPF char (11) NOT NULL,
    n_sessao smallint NOT NULL,
    id_atividade integer NOT NULL,
    CONSTRAINT pk_part_sessao PRIMARY KEY (CPF,n_sessao,id_atividade),
    CONSTRAINT fk_part_ps FOREIGN KEY (CPF) 
    REFERENCES Participante (CPF),
    CONSTRAINT fk_sessao_ps FOREIGN KEY (n_sessao,id_atividade)
    REFERENCES Sessao(n_sessao,id_atividade)
);

CREATE TABLE Lista_de_Espera(
    CPF char (11) NOT NULL,
    n_sessao smallint NOT NULL,
    id_atividade integer NOT NULL,
    dataInscricao timestamp DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_lista_espera PRIMARY KEY (CPF,n_sessao,id_atividade),
    CONSTRAINT fk_part_le FOREIGN KEY (CPF) 
    REFERENCES Participante (CPF),
    CONSTRAINT fk_sessao_le FOREIGN KEY (n_sessao,id_atividade)
    REFERENCES Sessao(n_sessao,id_atividade)
);

CREATE TABLE Inst_Sessao(
    CPF char (11) NOT NULL,
    n_sessao smallint NOT NULL,
    id_atividade integer NOT NULL,
    CONSTRAINT pk_inst_sessao PRIMARY KEY (CPF,n_sessao,id_atividade),
    CONSTRAINT fk_part_is FOREIGN KEY (CPF) 
    REFERENCES Instrutor (CPF),
    CONSTRAINT fk_sessao_is FOREIGN KEY (n_sessao,id_atividade)
    REFERENCES Sessao(n_sessao,id_atividade)
);

CREATE TABLE Ativ_Tipo_Recurso(
    id_atividade integer NOT NULL,
    id_tipo integer NOT NULL,
    quantidade smallint DEFAULT 1,
    CONSTRAINT pk_ativ_tipo_recurso PRIMARY KEY(id_atividade,tipo),
    CONSTRAINT fk_ativ_atr FOREIGN KEY(id_atividade)
    REFERENCES Atividade (id_atividade),
    CONSTRAINT fk_tipo_atr FOREIGN KEY (id_tipo) 
    REFERENCES Tipo_Recurso (id_tipo)
);

CREATE TABLE Pales_Ativ(
    CPF char(11),
    id_atividade integer,
    CONSTRAINT pk_pales_ativ PRIMARY KEY (CPF,id_atividade),
    CONSTRAINT fk_pales_pa FOREIGN KEY (CPF) 
    REFERENCES Palestrante (CPF) ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_ativ_pa FOREIGN KEY (id_atividade)
    REFERENCES Atividade (id_atividade) ON DELETE CASCADE ON UPDATE RESTRICT

);

CREATE TABLE Organizador_Organizacao(
    CPF char(11) NOT NULL,
    CNPJ char(14) NOT NULL,
    CONSTRAINT pk_organizador_organizacao PRIMARY KEY(CPF, CNPJ),
    CONSTRAINT fk_organizador_oo FOREIGN KEY (CPF) REFERENCES Organizador(CPF) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_organizacao_oo FOREIGN KEY (CNPJ) REFERENCES Organizacao(CNPJ) ON UPDATE CASCADE ON DELETE CASCADE
);