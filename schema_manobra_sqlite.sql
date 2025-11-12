-- Banco de dados de manobras baseado no modelo RTM-CTM-14D1
-- SQLite DDL

PRAGMA foreign_keys = ON;

-- Agentes executores/autoridades do roteiro (CTM, COOS, COSR-NE, etc.)
CREATE TABLE IF NOT EXISTS agente (
    id INTEGER PRIMARY KEY,
    codigo TEXT NOT NULL UNIQUE,
    nome TEXT NOT NULL
);

-- Modelo (template) do roteiro, derivado do arquivo RTM-CTM-14D1
CREATE TABLE IF NOT EXISTS modelo_roteiro (
    id INTEGER PRIMARY KEY,
    codigo TEXT NOT NULL UNIQUE,                 -- ex: RTM-CTM-14D1
    titulo TEXT NOT NULL,                        -- ex: Roteiro de Manobra 14D1
    equipamento_padrao TEXT,                     -- ex: 14D1
    versao INTEGER NOT NULL DEFAULT 1,
    ativo INTEGER NOT NULL DEFAULT 1,            -- booleano (0/1)
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS modelo_fase (
    id INTEGER PRIMARY KEY,
    modelo_id INTEGER NOT NULL REFERENCES modelo_roteiro(id) ON DELETE CASCADE,
    numero INTEGER NOT NULL,                     -- 1, 2
    titulo TEXT NOT NULL,                        -- LIBERAÇÃO, NORMALIZAÇÃO
    UNIQUE (modelo_id, numero)
);

CREATE TABLE IF NOT EXISTS modelo_passo (
    id INTEGER PRIMARY KEY,
    fase_id INTEGER NOT NULL REFERENCES modelo_fase(id) ON DELETE CASCADE,
    codigo TEXT NOT NULL,                        -- 1.1, 2.10
    ordem INTEGER NOT NULL,
    agente_id INTEGER REFERENCES agente(id),     -- CTM, COOS, COSR-NE, COOS/CTM
    descricao TEXT NOT NULL,
    UNIQUE (fase_id, codigo),
    UNIQUE (fase_id, ordem)
);

-- Execução (instância) do roteiro
CREATE TABLE IF NOT EXISTS execucao (
    id INTEGER PRIMARY KEY,
    modelo_id INTEGER NOT NULL REFERENCES modelo_roteiro(id),
    equipamento TEXT NOT NULL,                   -- ex: 14D1
    periodo TEXT,                                -- campo "PERÍODO" do cabeçalho
    referencia TEXT,                             -- campo "REFERÊNCIA"
    responsaveis TEXT,                           -- campo "RESPONSÁVEIS"
    status TEXT NOT NULL DEFAULT 'EM_ANDAMENTO', -- EM_ANDAMENTO, CONCLUIDO, CANCELADO
    inicio DATETIME,
    fim DATETIME,
    origem_arquivo TEXT,                         -- caminho/URL do .txt/.docx de referência
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS execucao_fase (
    id INTEGER PRIMARY KEY,
    execucao_id INTEGER NOT NULL REFERENCES execucao(id) ON DELETE CASCADE,
    numero INTEGER NOT NULL,
    titulo TEXT NOT NULL,
    assinatura_nome TEXT,                        -- campo "Assinatura" da seção
    assinatura_data DATE,                        -- campo "Data" da seção
    inicio DATETIME,
    fim DATETIME,
    UNIQUE (execucao_id, numero)
);

CREATE TABLE IF NOT EXISTS execucao_passo (
    id INTEGER PRIMARY KEY,
    execucao_fase_id INTEGER NOT NULL REFERENCES execucao_fase(id) ON DELETE CASCADE,
    modelo_passo_id INTEGER REFERENCES modelo_passo(id), -- referência ao passo do modelo
    codigo TEXT NOT NULL,
    ordem INTEGER NOT NULL,
    agente_id INTEGER REFERENCES agente(id),
    descricao TEXT NOT NULL,
    hora TEXT,                                   -- guardar HH:MM
    observacoes TEXT,
    realizado INTEGER NOT NULL DEFAULT 0,        -- booleano (0/1)
    realizado_em DATETIME,
    UNIQUE (execucao_fase_id, ordem),
    UNIQUE (execucao_fase_id, codigo)
);

-- Índices auxiliares
CREATE INDEX IF NOT EXISTS idx_modelo_fase_modelo ON modelo_fase(modelo_id);
CREATE INDEX IF NOT EXISTS idx_modelo_passo_fase ON modelo_passo(fase_id);
CREATE INDEX IF NOT EXISTS idx_execucao_modelo ON execucao(modelo_id);
CREATE INDEX IF NOT EXISTS idx_execucao_fase_execucao ON execucao_fase(execucao_id);
CREATE INDEX IF NOT EXISTS idx_execucao_passo_fase ON execucao_passo(execucao_fase_id);

-- Triggers de atualização de timestamp de forma segura (evita recursão)
CREATE TRIGGER IF NOT EXISTS tg_modelo_roteiro_updated
AFTER UPDATE ON modelo_roteiro
FOR EACH ROW WHEN NEW.atualizado_em = OLD.atualizado_em
BEGIN
  UPDATE modelo_roteiro SET atualizado_em = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS tg_execucao_updated
AFTER UPDATE ON execucao
FOR EACH ROW WHEN NEW.atualizado_em = OLD.atualizado_em
BEGIN
  UPDATE execucao SET atualizado_em = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Seed de agentes conforme o arquivo RTM-CTM-14D1
INSERT INTO agente (codigo, nome) VALUES
  ('CTM', 'CTM'),
  ('COOS', 'COOS'),
  ('COSR-NE', 'COSR-NE'),
  ('COOS/CTM', 'COOS/CTM')
ON CONFLICT(codigo) DO NOTHING;

-- Criação do modelo "RTM-CTM-14D1" com fases e passos
INSERT INTO modelo_roteiro (codigo, titulo, equipamento_padrao)
VALUES ('RTM-CTM-14D1', 'Roteiro de Manobra 14D1', '14D1')
ON CONFLICT(codigo) DO UPDATE SET titulo=excluded.titulo, equipamento_padrao=excluded.equipamento_padrao;

-- Fases
INSERT INTO modelo_fase (modelo_id, numero, titulo)
SELECT id, 1, 'LIBERAÇÃO' FROM modelo_roteiro WHERE codigo='RTM-CTM-14D1'
ON CONFLICT(modelo_id, numero) DO UPDATE SET titulo=excluded.titulo;

INSERT INTO modelo_fase (modelo_id, numero, titulo)
SELECT id, 2, 'NORMALIZAÇÃO' FROM modelo_roteiro WHERE codigo='RTM-CTM-14D1'
ON CONFLICT(modelo_id, numero) DO UPDATE SET titulo=excluded.titulo;

-- Passos da fase 1: LIBERAÇÃO
INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.1', 1, a.id, 'Receber do responsável solicitação liberação 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.2', 2, a.id, 'Solicitar COOS liberação 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.3', 3, a.id, 'Solicitar COSR-NE liberação 14D1/CTM.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COOS'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.4', 4, a.id, 'Autorizar COOS liberação 14D1/CTM.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COSR-NE'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.5', 5, a.id, 'Autorizar CTM liberação 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COOS'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.6', 6, a.id, 'Confirmar 14D1 fechado.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.7', 7, a.id, 'Fechar 34F9-1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.8', 8, a.id, 'Abrir 34F9-2.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.9', 9, a.id, 'Abrir 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.10', 10, a.id, 'Abrir 34D1-1 e 34D1-2.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.11', 11, a.id, 'Bloquear comando elétrico 34D1-1 e 34D1-2.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.12', 12, a.id, 'Entregar 14D1 isolado ao responsável.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '1.13', 13, a.id, 'Informar COOS conclusão liberação 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=1
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

-- Passos da fase 2: NORMALIZAÇÃO
INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.1', 1, a.id, 'Receber do responsável solicitação para teste de energização 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.2', 2, a.id, 'Confirmar ausência de aterramento temporário.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.3', 3, a.id, 'Solicitar COOS normalização 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.4', 4, a.id, 'Autorizar CTM iniciar normalização 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COOS'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.5', 5, a.id, 'Desbloquear comando elétrico 34D1-1 e 34D1-2.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.6', 6, a.id, 'Fechar 34D1-1 e 34D1-2.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.7', 7, a.id, 'Informar COOS conclusão manobras.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.8', 8, a.id, 'Solicitar COSR-NE autorização para teste de energização 14D1/CTM.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COOS'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.9', 9, a.id, 'Autorizar COOS efetuar teste de energização 14D1/CTM.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COSR-NE'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.10', 10, a.id, 'Fechar 14D1/CTM.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COOS'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.11', 11, a.id, 'Informar ao responsável a energização 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COOS/CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.12', 12, a.id, 'Receber do responsável 14D1 livre para operação.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COOS/CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.13', 13, a.id, 'Informar COSR-NE disponibilidade 14D1/CTM.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COOS'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.14', 14, a.id, 'Autorizar COOS normalização 14D1/CTM.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COSR-NE'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.15', 15, a.id, 'Autorizar CTM prosseguir normalização 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='COOS'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.16', 16, a.id, 'Fechar 34F9-2.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.17', 17, a.id, 'Abrir 34F9-1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
SELECT mf.id, '2.18', 18, a.id, 'Informar COOS conclusão normalização 14D1.'
FROM modelo_fase mf JOIN modelo_roteiro mr ON mf.modelo_id=mr.id JOIN agente a ON a.codigo='CTM'
WHERE mr.codigo='RTM-CTM-14D1' AND mf.numero=2
ON CONFLICT(fase_id, codigo) DO UPDATE SET ordem=excluded.ordem, agente_id=excluded.agente_id, descricao=excluded.descricao;

-- Finalização automática quando 100% concluída
CREATE TRIGGER IF NOT EXISTS tg_execucao_passo_finalize
AFTER UPDATE OF realizado ON execucao_passo
FOR EACH ROW
WHEN NEW.realizado = 1 AND (OLD.realizado IS NULL OR OLD.realizado = 0)
BEGIN
  -- Finaliza fases com 100% dos passos realizados
  UPDATE execucao_fase
  SET fim = COALESCE(fim, CURRENT_TIMESTAMP)
  WHERE id IN (
    SELECT ef.id
    FROM execucao_fase ef
    LEFT JOIN execucao_passo ep ON ep.execucao_fase_id = ef.id
    WHERE ef.execucao_id = (SELECT execucao_id FROM execucao_fase WHERE id = NEW.execucao_fase_id)
    GROUP BY ef.id
    HAVING COUNT(ep.id) > 0 AND SUM(CASE WHEN ep.realizado = 1 THEN 0 ELSE 1 END) = 0
  );

  -- Finaliza execução quando 100% dos passos realizados
  UPDATE execucao
  SET status = 'CONCLUIDO', fim = COALESCE(fim, CURRENT_TIMESTAMP)
  WHERE id = (SELECT execucao_id FROM execucao_fase WHERE id = NEW.execucao_fase_id)
    AND NOT EXISTS (
      SELECT 1
      FROM execucao_fase ef
      JOIN execucao_passo ep ON ep.execucao_fase_id = ef.id
      WHERE ef.execucao_id = execucao.id
        AND (ep.realizado IS NULL OR ep.realizado = 0)
    );
END;

-- View de progresso
CREATE VIEW IF NOT EXISTS vw_execucao_progresso AS
SELECT e.id AS execucao_id,
       e.equipamento,
       e.status,
       e.inicio,
       e.fim,
       SUM(CASE WHEN ep.realizado = 1 THEN 1 ELSE 0 END) AS passos_realizados,
       COUNT(ep.id) AS passos_total,
       CASE WHEN COUNT(ep.id) = 0 THEN 100.0
            ELSE ROUND(100.0 * SUM(CASE WHEN ep.realizado = 1 THEN 1 ELSE 0 END) / COUNT(ep.id), 2) END AS progresso_percentual
FROM execucao e
LEFT JOIN execucao_fase ef ON ef.execucao_id = e.id
LEFT JOIN execucao_passo ep ON ep.execucao_fase_id = ef.id
GROUP BY e.id, e.equipamento, e.status, e.inicio, e.fim;

-- (FIM) Carregamento do modelo RTM-CTM-14D1 em SQLite
