drop table if exists equipamento;
drop table if exists unidade;
drop table if exists roteiro_manobra;
drop table if exists roteiro_manobra_item;
drop table if exists roteiro_comando;
drop table if exists usuario;
drop table if exists execucao;
drop table if exists execucao_item;

PRAGMA foreign_keys = ON;

create table equipamento (
  id integer primary key,
  codigo text not null,
  tipo integer
);

create table unidade(
  id integer primary key autoincrement,
  codigo text not null
);

create table roteiro_manobra (
  id integer primary key,
  id_origem integer not null,
  id_equipamento integer not null,
  configuracao text not null,
  foreign key (id_equipamento) references equipamento(id),
  foreign key (id_origem) references unidade(id)
);


create table roteiro_manobra_item(
  id integer primary key,
  id_roteiro_manobra integer not null,
  descricao text not null,
  id_unidade integer not null,
  procedimento integer not null,
  foreign key (id_roteiro_manobra) references roteiro_manobra(id),
  foreign key (id_unidade) references unidade(id)
);

create table roteiro_comando(
  id integer primary key autoincrement,
  id_roteiro_manobra_item integer not null,
  id_equipamento integer not null,
  comando integer not null,
  foreign key (id_roteiro_manobra_item) references roteiro_manobra_item(id),
  foreign key (id_equipamento) references equipamento(id)
);

create table usuario(
  id integer primary key autoincrement,
  usuario text not null
);

create table execucao(
  id integer primary key autoincrement,
  data date,
  id_roteiro_manobra integer not null,
  id_usuario integer,
  foreign key (id_roteiro_manobra) references roteiro_manobra(id),
  foreign key (id_usuario) references usuario(id)
);

create table execucao_item(
  id integer primary key autoincrement,
  id_execucao integer not null,
  hora_execucao text not null,
  foreign key (id_execucao) references execucao(id)
);


insert into equipamento (id, codigo, tipo) values (1, '14C1','52');
insert into equipamento (id, codigo, tipo) values (2, '14T1','52');
insert into equipamento (id, codigo, tipo) values (3, '12T5','52');
insert into equipamento (id, codigo, tipo) values (4, '13L1','52');
insert into equipamento (id, codigo, tipo) values (5, '14F8','52');
insert into equipamento (id, codigo, tipo) values (6, '34F8-1','89');
insert into equipamento (id, codigo, tipo) values (7, '34F8-2','89');
insert into equipamento (id, codigo, tipo) values (8, '34F8-5','89');
insert into equipamento (id, codigo, tipo) values (9, '34F8-6','89');
insert into equipamento (id, codigo, tipo) values (10, '14C3','52');
insert into equipamento (id, codigo, tipo) values (11, '34C3-1','89');
insert into equipamento (id, codigo, tipo) values (12, '34C3-2','89');
insert into equipamento (id, codigo, tipo) values (13, '34C3-5','89');
insert into equipamento (id, codigo, tipo) values (14, '34C3-6','89');
insert into equipamento (id, codigo, tipo) values (15, '14W1','52');
insert into equipamento (id, codigo, tipo) values (16, '34W1-1','89');
insert into equipamento (id, codigo, tipo) values (17, '34W1-2','89');
insert into equipamento (id, codigo, tipo) values (18, '34W1-5','89');
insert into equipamento (id, codigo, tipo) values (19, '34W1-6','89');
insert into equipamento (id, codigo, tipo) values (20, '14D1','52');
insert into equipamento (id, codigo, tipo) values (21, '34D1-1','89');
insert into equipamento (id, codigo, tipo) values (22, '34D1-2','89');
insert into equipamento (id, codigo, tipo) values (23, '04B1','00');

insert into unidade (id, codigo) values (1, 'JCD');
insert into unidade (id, codigo) values (2, 'CGD');
insert into unidade (id, codigo) values (3, 'CTM');
insert into unidade (id, codigo) values (4, 'CROL');
insert into unidade (id, codigo) values (5, 'COSR-NE');

insert into roteiro_manobra (id, id_origem, id_equipamento, configuracao) values (1, 1, 1,'Disjuntor e chaves do C1 fechadas');
insert into roteiro_manobra (id, id_origem, id_equipamento, configuracao) values (2, 1, 2,'Disjuntor e chaves do T1 fechadas');
insert into roteiro_manobra (id, id_origem, id_equipamento, configuracao) values (3, 2, 3,'Disjuntor e chaves de T5 associadas fechadas');
insert into roteiro_manobra (id, id_origem, id_equipamento, configuracao) values (4, 2, 4,'Disjuntor e chaves do L1 associadas fechadas');
insert into roteiro_manobra (id, id_origem, id_equipamento, configuracao) values (5, 3, 5,
'- 14D1 fechado com chaves associadas fechadas e todas as chaves by-pass 230 kV abertas.
- 04B1 e 04B2 acoplados através do 14D1.
- 14W1 e 14C3 conectados ao 04B1.
- 14F8 conectado ao 04B2.');
insert into roteiro_manobra (id, id_origem, id_equipamento, configuracao) values (6, 3, 10,
'- 14D1 fechado com chaves associadas fechadas e todas as chaves by-pass 230 kV abertas.
- 04B1 e 04B2 acoplados através do 14D1.
- 14W1 e 14C3 conectados ao 04B1.
- 14F8 conectado ao 04B2.');
insert into roteiro_manobra (id, id_origem, id_equipamento, configuracao) values (7, 3, 15,'Disjuntor e chaves DO W1 associadas fechadas');
insert into roteiro_manobra (id, id_origem, id_equipamento, configuracao) values (8, 3, 20,'Disjuntor e chaves DO D1 associadas fechadas');
insert into roteiro_manobra (id, id_origem, id_equipamento, configuracao) values (9, 3, 23,'Eventos terminados em impares do B1 conectadas');

insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (1, 5, 'Receber do responsável solicitação liberação 14F8',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (2, 5, 'Solicitar CROL liberação 14F8.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (3, 5, 'Solicitar COSR-NE autorização liberação 14F8/CTM.',4 ,1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (4, 5, 'Autorizar CROL liberação 14F8/CTM.',5, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (5, 5, 'Autorizar CTM liberação 14F8.',4, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (6, 5, 'Colocar operação da SE no nível 2.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (7, 5, 'Colocar proteção 14F8 na posição EM TRANSFERÊNCIA',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (8, 5, 'Confirmar 14D1 fechado',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (9, 5, 'Fechar 34F8-6',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (10, 5, 'Abrir 14F8',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (11, 5, 'Abrir 34F8-2 e 34F8-5',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (12, 5, 'Colocar proteção 14F8 na posição TRANSFERIDO',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (13, 5, 'Bloquear comando elétrico 34F8-1, 34F8-2 e 34F8-5',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (14, 5, 'Entregar 14F8 isolado ao responsável.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (15, 5, 'Retornar operação da SE para o nível 3',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (16, 5, 'Informar CROL conclusão liberação 14F8',3, 1);

insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (17, 5, 'Receber do responsável 14F8 livre para operação.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (18, 5, 'Confirmar ausência de aterramento temporário.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (19, 5, 'Solicitar CROL normalização 14F8.',3 ,2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (20, 5, 'Solicitar COSR-NE autorização normalização 14F8/CTM',4, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (21, 5, 'Autorizar CROL normalização 14F8/CTM',5, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (22, 5, 'Autorizar CTM normalização 14F8',4, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (23, 5, 'Colocar operação da SE no nível 2.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (24, 5, 'Desbloquear comando elétrico 34F8-1, 34F8-2 e 34F8-5.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (25, 5, 'Colocar proteção 14F8 na posição EM TRANSFERÊNCIA',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (26, 5, 'Fechar 34F8-2 e 34F8-5.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (27, 5, 'Fechar 14F8.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (28, 5, 'Abrir 34F8-6.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (29, 5, 'Colocar 14F8 na posição NORMAL',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (30, 5, 'Retornar operação da SE para o nível 3',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (31, 5, 'Informar CROL conclusão normalização 14F8',3, 2);

insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (9, 9, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (10, 5, 0);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (11, 7, 0);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (11, 8, 0);

insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (26, 7, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (26, 8, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (27, 5, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (28, 9, 0);

insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (32, 6, 'Receber do responsável solicitação liberação 14C3',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (33, 6, 'Solicitar CROL liberação 14C3.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (34, 6, 'Solicitar COSR-NE autorização liberação 14C3/CTM.',4 ,1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (35, 6, 'Autorizar CROL liberação 14C3/CTM.',5, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (36, 6, 'Autorizar CTM liberação 14C3.',4, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (37, 6, 'Colocar operação da SE no nível 2.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (38, 6, 'Confirmar 14D1 fechado',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (39, 6, 'Fechar 34F8-1',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (40, 6, 'Abrir 34F8-2.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (41, 6, 'Colocar proteção 14C3 na posição EM TRANSFERÊNCIA',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (42, 6, 'Fechar 34C3-6.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (43, 6, 'Abrir 14C3.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (44, 6, 'Abrir 34C3-1 e 34C3-5.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (45, 6, 'Colocar proteção 14C3 na posição TRANSFERIDO',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (46, 6, 'Bloquear comando elétrico 34C3-1, 34C3-2 e 34C3-5.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (47, 6, 'Entregar 14C3 isolado ao responsável.',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (48, 6, 'Retornar operação da SE para o nível 3',3, 1);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (49, 6, 'Informar CROL conclusão liberação 14C3.',3, 1);

insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (50, 6, 'Receber do responsável 14C3 livre para operação.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (51, 6, 'Confirmar ausência de aterramento temporário.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (52, 6, 'Solicitar CROL normalização 14C3.',3 ,2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (53, 6, 'Solicitar COSR-NE autorização normalização 14C3/CTM.',4, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (54, 6, 'Autorizar CROL normalização 14C3/CTM.',5, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (55, 6, 'Autorizar CTM normalização 14C3.',4, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (56, 6, 'Colocar operação da SE no nível 2.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (57, 6, 'Desbloquear comando elétrico 34C3-1, 34C3-2 e 34C3-5.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (58, 6, 'Colocar proteção 14C3 na posição EM TRANSFERÊNCIA',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (59, 6, 'Fechar 34C3-1 e 34C3-5.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (60, 6, 'Fechar 14C3.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (61, 6, 'Abrir 34C3-6.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (62, 6, 'Colocar proteção 14C3 na posição NORMAL',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (63, 6, 'Fechar 34F8-2.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (64, 6, 'Abrir 34F8-1.',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (65, 6, 'Retornar operação da SE para o nível 3',3, 2);
insert into roteiro_manobra_item (id, id_roteiro_manobra, descricao, id_unidade, procedimento) values (66, 6, 'Informar CROL conclusão normalização 14C3.',3, 2);

insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (39, 6, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (40, 7, 0);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (42, 14, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (43, 10, 0);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (44, 11, 0);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (44, 13, 0);

insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (59, 11, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (59, 13, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (60, 10, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (61, 14, 0);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (63, 7, 1);
insert into roteiro_comando (id_roteiro_manobra_item, id_equipamento, comando) values (64, 6, 0);

insert into usuario (usuario) values ('sergiod');
insert into usuario (usuario) values ('wmbrito');
insert into usuario (usuario) values ('stlira');
insert into usuario (usuario) values ('italofa');
insert into usuario (usuario) values ('darciomj');
insert into usuario (usuario) values ('evandros');
insert into usuario (usuario) values ('pdias');
insert into usuario (usuario) values ('marcals');
insert into usuario (usuario) values ('cesarino');
insert into usuario (usuario) values ('wdenil');
insert into usuario (usuario) values ('halison');
insert into usuario (usuario) values ('eliedesm');
insert into usuario (usuario) values ('canide');
insert into usuario (usuario) values ('manuelpf');



