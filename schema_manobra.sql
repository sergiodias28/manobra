-- Banco de dados de manobras baseado no modelo RTM-CTM-14D1
-- PostgreSQL DDL

CREATE SCHEMA IF NOT EXISTS manobra;
SET search_path TO manobra;

-- Agentes executores/autoridades do roteiro (CTM, COOS, COSR-NE, etc.)
CREATE TABLE IF NOT EXISTS agente (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    nome TEXT NOT NULL
);

-- Modelo (template) do roteiro, derivado do arquivo RTM-CTM-14D1
CREATE TABLE IF NOT EXISTS modelo_roteiro (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(100) NOT NULL UNIQUE,         -- ex: RTM-CTM-14D1
    titulo TEXT NOT NULL,                        -- ex: Roteiro de Manobra 14D1
    equipamento_padrao VARCHAR(50),              -- ex: 14D1
    versao INTEGER NOT NULL DEFAULT 1,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS modelo_fase (
    id BIGSERIAL PRIMARY KEY,
    modelo_id BIGINT NOT NULL REFERENCES modelo_roteiro(id) ON DELETE CASCADE,
    numero INTEGER NOT NULL,                     -- 1, 2
    titulo VARCHAR(100) NOT NULL,                -- LIBERAÇÃO, NORMALIZAÇÃO
    UNIQUE (modelo_id, numero)
);

CREATE TABLE IF NOT EXISTS modelo_passo (
    id BIGSERIAL PRIMARY KEY,
    fase_id BIGINT NOT NULL REFERENCES modelo_fase(id) ON DELETE CASCADE,
    codigo VARCHAR(10) NOT NULL,                 -- 1.1, 2.10
    ordem INTEGER NOT NULL,
    agente_id BIGINT REFERENCES agente(id),      -- CTM, COOS, COSR-NE, COOS/CTM
    descricao TEXT NOT NULL,
    UNIQUE (fase_id, codigo),
    UNIQUE (fase_id, ordem)
);

-- Execução (instância) do roteiro
CREATE TABLE IF NOT EXISTS execucao (
    id BIGSERIAL PRIMARY KEY,
    modelo_id BIGINT NOT NULL REFERENCES modelo_roteiro(id),
    equipamento VARCHAR(50) NOT NULL,            -- ex: 14D1
    periodo TEXT,                                -- campo "PERÍODO" do cabeçalho
    referencia TEXT,                             -- campo "REFERÊNCIA"
    responsaveis TEXT,                           -- campo "RESPONSÁVEIS"
    status VARCHAR(30) NOT NULL DEFAULT 'EM_ANDAMENTO',  -- EM_ANDAMENTO, CONCLUIDO, CANCELADO
    inicio TIMESTAMPTZ,
    fim TIMESTAMPTZ,
    origem_arquivo TEXT,                         -- caminho/URL do .txt/.docx de referência
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS execucao_fase (
    id BIGSERIAL PRIMARY KEY,
    execucao_id BIGINT NOT NULL REFERENCES execucao(id) ON DELETE CASCADE,
    numero INTEGER NOT NULL,
    titulo VARCHAR(100) NOT NULL,
    assinatura_nome TEXT,                        -- campo "Assinatura" da seção
    assinatura_data DATE,                        -- campo "Data" da seção
    inicio TIMESTAMPTZ,
    fim TIMESTAMPTZ,
    UNIQUE (execucao_id, numero)
);

CREATE TABLE IF NOT EXISTS execucao_passo (
    id BIGSERIAL PRIMARY KEY,
    execucao_fase_id BIGINT NOT NULL REFERENCES execucao_fase(id) ON DELETE CASCADE,
    modelo_passo_id BIGINT REFERENCES modelo_passo(id), -- referência ao passo do modelo
    codigo VARCHAR(10) NOT NULL,
    ordem INTEGER NOT NULL,
    agente_id BIGINT REFERENCES agente(id),
    descricao TEXT NOT NULL,
    hora TIME,                                   -- hora preenchida no campo "HORA:"
    observacoes TEXT,
    realizado BOOLEAN NOT NULL DEFAULT FALSE,
    realizado_em TIMESTAMPTZ,
    UNIQUE (execucao_fase_id, ordem),
    UNIQUE (execucao_fase_id, codigo)
);

-- Índices auxiliares
CREATE INDEX IF NOT EXISTS idx_modelo_fase_modelo ON modelo_fase(modelo_id);
CREATE INDEX IF NOT EXISTS idx_modelo_passo_fase ON modelo_passo(fase_id);
CREATE INDEX IF NOT EXISTS idx_execucao_modelo ON execucao(modelo_id);
CREATE INDEX IF NOT EXISTS idx_execucao_fase_execucao ON execucao_fase(execucao_id);
CREATE INDEX IF NOT EXISTS idx_execucao_passo_fase ON execucao_passo(execucao_fase_id);

-- Busca textual em descrições (opcional)
ALTER TABLE modelo_passo ADD COLUMN IF NOT EXISTS descricao_tsv tsvector GENERATED ALWAYS AS (
    to_tsvector('portuguese', coalesce(descricao, ''))
) STORED;
CREATE INDEX IF NOT EXISTS idx_modelo_passo_tsv ON modelo_passo USING GIN(descricao_tsv);

ALTER TABLE execucao_passo ADD COLUMN IF NOT EXISTS descricao_tsv tsvector GENERATED ALWAYS AS (
    to_tsvector('portuguese', coalesce(descricao, ''))
) STORED;
CREATE INDEX IF NOT EXISTS idx_execucao_passo_tsv ON execucao_passo USING GIN(descricao_tsv);

-- Trigger para manutenção de atualizado_em
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.atualizado_em = NOW();
  RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS tg_modelo_roteiro_updated ON modelo_roteiro;
CREATE TRIGGER tg_modelo_roteiro_updated
BEFORE UPDATE ON modelo_roteiro
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tg_execucao_updated ON execucao;
CREATE TRIGGER tg_execucao_updated
BEFORE UPDATE ON execucao
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Seed de agentes conforme o arquivo RTM-CTM-14D1
INSERT INTO agente (codigo, nome) VALUES
  ('CTM', 'CTM'),
  ('COOS', 'COOS'),
  ('COSR-NE', 'COSR-NE'),
  ('COOS/CTM', 'COOS/CTM')
ON CONFLICT (codigo) DO NOTHING;

-- Criação do modelo "RTM-CTM-14D1" com fases e passos
WITH m AS (
  INSERT INTO modelo_roteiro (codigo, titulo, equipamento_padrao)
  VALUES ('RTM-CTM-14D1', 'Roteiro de Manobra 14D1', '14D1')
  ON CONFLICT (codigo) DO UPDATE SET titulo = EXCLUDED.titulo, equipamento_padrao = EXCLUDED.equipamento_padrao
  RETURNING id
),
 f1 AS (
  INSERT INTO modelo_fase (modelo_id, numero, titulo)
  SELECT id, 1, 'LIBERAÇÃO' FROM m
  ON CONFLICT (modelo_id, numero) DO UPDATE SET titulo = EXCLUDED.titulo
  RETURNING id
),
 f2 AS (
  INSERT INTO modelo_fase (modelo_id, numero, titulo)
  SELECT id, 2, 'NORMALIZAÇÃO' FROM m
  ON CONFLICT (modelo_id, numero) DO UPDATE SET titulo = EXCLUDED.titulo
  RETURNING id
)
SELECT 1;

-- Passos da fase 1: LIBERAÇÃO
WITH f AS (
  SELECT mf.id AS fase_id
  FROM modelo_roteiro mr
  JOIN modelo_fase mf ON mf.modelo_id = mr.id AND mf.numero = 1
  WHERE mr.codigo = 'RTM-CTM-14D1'
)
INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
VALUES
((SELECT fase_id FROM f), '1.1', 1, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Receber do responsável solicitação liberação 14D1.'),
((SELECT fase_id FROM f), '1.2', 2, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Solicitar COOS liberação 14D1.'),
((SELECT fase_id FROM f), '1.3', 3, (SELECT id FROM agente WHERE codigo = 'COOS'), 'Solicitar COSR-NE liberação 14D1/CTM.'),
((SELECT fase_id FROM f), '1.4', 4, (SELECT id FROM agente WHERE codigo = 'COSR-NE'), 'Autorizar COOS liberação 14D1/CTM.'),
((SELECT fase_id FROM f), '1.5', 5, (SELECT id FROM agente WHERE codigo = 'COOS'), 'Autorizar CTM liberação 14D1.'),
((SELECT fase_id FROM f), '1.6', 6, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Confirmar 14D1 fechado.'),
((SELECT fase_id FROM f), '1.7', 7, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Fechar 34F9-1.'),
((SELECT fase_id FROM f), '1.8', 8, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Abrir 34F9-2.'),
((SELECT fase_id FROM f), '1.9', 9, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Abrir 14D1.'),
((SELECT fase_id FROM f), '1.10', 10, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Abrir 34D1-1 e 34D1-2.'),
((SELECT fase_id FROM f), '1.11', 11, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Bloquear comando elétrico 34D1-1 e 34D1-2.'),
((SELECT fase_id FROM f), '1.12', 12, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Entregar 14D1 isolado ao responsável.'),
((SELECT fase_id FROM f), '1.13', 13, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Informar COOS conclusão liberação 14D1.')
ON CONFLICT (fase_id, codigo) DO UPDATE
SET ordem = EXCLUDED.ordem,
    agente_id = EXCLUDED.agente_id,
    descricao = EXCLUDED.descricao;

-- Passos da fase 2: NORMALIZAÇÃO
WITH f AS (
  SELECT mf.id AS fase_id
  FROM modelo_roteiro mr
  JOIN modelo_fase mf ON mf.modelo_id = mr.id AND mf.numero = 2
  WHERE mr.codigo = 'RTM-CTM-14D1'
)
INSERT INTO modelo_passo (fase_id, codigo, ordem, agente_id, descricao)
VALUES
((SELECT fase_id FROM f), '2.1', 1, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Receber do responsável solicitação para teste de energização 14D1.'),
((SELECT fase_id FROM f), '2.2', 2, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Confirmar ausência de aterramento temporário.'),
((SELECT fase_id FROM f), '2.3', 3, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Solicitar COOS normalização 14D1.'),
((SELECT fase_id FROM f), '2.4', 4, (SELECT id FROM agente WHERE codigo = 'COOS'), 'Autorizar CTM iniciar normalização 14D1.'),
((SELECT fase_id FROM f), '2.5', 5, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Desbloquear comando elétrico 34D1-1 e 34D1-2.'),
((SELECT fase_id FROM f), '2.6', 6, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Fechar 34D1-1 e 34D1-2.'),
((SELECT fase_id FROM f), '2.7', 7, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Informar COOS conclusão manobras.'),
((SELECT fase_id FROM f), '2.8', 8, (SELECT id FROM agente WHERE codigo = 'COOS'), 'Solicitar COSR-NE autorização para teste de energização 14D1/CTM.'),
((SELECT fase_id FROM f), '2.9', 9, (SELECT id FROM agente WHERE codigo = 'COSR-NE'), 'Autorizar COOS efetuar teste de energização 14D1/CTM.'),
((SELECT fase_id FROM f), '2.10', 10, (SELECT id FROM agente WHERE codigo = 'COOS'), 'Fechar 14D1/CTM.'),
((SELECT fase_id FROM f), '2.11', 11, (SELECT id FROM agente WHERE codigo = 'COOS/CTM'), 'Informar ao responsável a energização 14D1.'),
((SELECT fase_id FROM f), '2.12', 12, (SELECT id FROM agente WHERE codigo = 'COOS/CTM'), 'Receber do responsável 14D1 livre para operação.'),
((SELECT fase_id FROM f), '2.13', 13, (SELECT id FROM agente WHERE codigo = 'COOS'), 'Informar COSR-NE disponibilidade 14D1/CTM.'),
((SELECT fase_id FROM f), '2.14', 14, (SELECT id FROM agente WHERE codigo = 'COSR-NE'), 'Autorizar COOS normalização 14D1/CTM.'),
((SELECT fase_id FROM f), '2.15', 15, (SELECT id FROM agente WHERE codigo = 'COOS'), 'Autorizar CTM prosseguir normalização 14D1.'),
((SELECT fase_id FROM f), '2.16', 16, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Fechar 34F9-2.'),
((SELECT fase_id FROM f), '2.17', 17, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Abrir 34F9-1.'),
((SELECT fase_id FROM f), '2.18', 18, (SELECT id FROM agente WHERE codigo = 'CTM'), 'Informar COOS conclusão normalização 14D1.')
ON CONFLICT (fase_id, codigo) DO UPDATE
SET ordem = EXCLUDED.ordem,
    agente_id = EXCLUDED.agente_id,
    descricao = EXCLUDED.descricao;

-- (FIM) Carregamento do modelo RTM-CTM-14D1

-- =============================================
-- Funções de automação
-- =============================================

-- já existem criar_execucao, marcar_passo, assinar_fase acima (se não, adicione-as antes)

-- Finalizar execução quando 100% concluída
CREATE OR REPLACE FUNCTION finalizar_execucao(p_execucao_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
    v_total INTEGER;
    v_realizados INTEGER;
    v_finalizou BOOLEAN := FALSE;
BEGIN
    SELECT COUNT(ep.id) AS total,
           COUNT(ep.id) FILTER (WHERE ep.realizado) AS realizados
    INTO v_total, v_realizados
    FROM execucao_fase ef
    LEFT JOIN execucao_passo ep ON ep.execucao_fase_id = ef.id
    WHERE ef.execucao_id = p_execucao_id;

    IF v_total IS NULL OR v_total = 0 THEN
        -- Sem passos: considerar concluída
        UPDATE execucao SET status = 'CONCLUIDO', fim = COALESCE(fim, NOW())
        WHERE id = p_execucao_id;
        RETURN TRUE;
    END IF;

    IF v_total = v_realizados THEN
        -- Ajusta fim das fases que já têm 100% dos passos concluídos
        UPDATE execucao_fase ef
        SET fim = COALESCE(fim, NOW())
        FROM (
            SELECT ef2.id
            FROM execucao_fase ef2
            LEFT JOIN execucao_passo ep2 ON ep2.execucao_fase_id = ef2.id
            WHERE ef2.execucao_id = p_execucao_id
            GROUP BY ef2.id
            HAVING COUNT(ep2.id) = COUNT(ep2.id) FILTER (WHERE ep2.realizado)
        ) done
        WHERE ef.id = done.id;

        -- Finaliza execução
        UPDATE execucao
        SET status = 'CONCLUIDO', fim = COALESCE(fim, NOW())
        WHERE id = p_execucao_id AND status <> 'CONCLUIDO';
        v_finalizou := TRUE;
    END IF;

    RETURN v_finalizou;
END;$$;

-- Trigger para tentar finalizar automaticamente ao marcar o último passo
CREATE OR REPLACE FUNCTION tg_try_finalize_execucao()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_execucao_id BIGINT;
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.realizado IS TRUE AND (OLD.realizado IS DISTINCT FROM TRUE) THEN
        SELECT ef.execucao_id INTO v_execucao_id FROM execucao_fase ef WHERE ef.id = NEW.execucao_fase_id;
        PERFORM finalizar_execucao(v_execucao_id);
    END IF;
    RETURN NEW;
END;$$;

DROP TRIGGER IF EXISTS trig_execucao_passo_finalize ON execucao_passo;
CREATE TRIGGER trig_execucao_passo_finalize
AFTER UPDATE OF realizado ON execucao_passo
FOR EACH ROW EXECUTE FUNCTION tg_try_finalize_execucao();
