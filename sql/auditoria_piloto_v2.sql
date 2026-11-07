-- Painel de Senhas Sabin - Auditoria observacional v2 (PILOTO, NAO avaliacao funcional)
-- Execute UMA VEZ no SQL Editor do projeto Supabase. Nenhum computador precisa de configuracao.
-- Esta migracao NAO altera historico_chamadas nem a RPC registrar_chamada.

CREATE TABLE IF NOT EXISTS public.observacoes_chamadas_v2 (
    evento_id uuid PRIMARY KEY,
    unit_id uuid NOT NULL REFERENCES public.units(id),
    guiche text NOT NULL,
    senha_recomendada text,
    senha_chamada text,
    tipo_acao text NOT NULL CHECK (tipo_acao IN ('proxima','manual')),
    situacao text NOT NULL DEFAULT 'pendente'
        CHECK (situacao IN ('pendente','coincide','diverge','nao_verificado')),
    motivo text NOT NULL DEFAULT 'aguardando',
    criado_em timestamptz NOT NULL DEFAULT now(),
    atualizado_em timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS obs_chamadas_v2_unidade_data_idx
  ON public.observacoes_chamadas_v2 (unit_id, criado_em DESC);

ALTER TABLE public.observacoes_chamadas_v2 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.observacoes_chamadas_v2 FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.registrar_observacao_v2(
    p_evento_id uuid,
    p_unit_id uuid,
    p_guiche text,
    p_senha_recomendada text DEFAULT NULL,
    p_senha_chamada text DEFAULT NULL,
    p_tipo_acao text DEFAULT 'manual',
    p_motivo text DEFAULT 'aguardando'
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_modificou integer := 0;
BEGIN
    -- O piloto fica limitado ao Guiche 2 do Shopping Felicitta.
    IF p_evento_id IS NULL OR p_unit_id IS NULL OR p_guiche IS DISTINCT FROM 'Guiche 2'
       OR NOT EXISTS (
          SELECT 1 FROM public.units u
          WHERE u.id = p_unit_id AND u.name = 'Shopping Felicittá' AND u.active = true
       ) THEN RETURN false; END IF;

    IF p_tipo_acao IS NULL OR p_tipo_acao NOT IN ('proxima','manual')
       OR p_motivo IS NULL OR p_motivo NOT IN
          ('aguardando','chamada_confirmada','captura_ambigua','sem_recomendacao',
           'chamada_manual','tempo_esgotado')
       OR (p_senha_recomendada IS NOT NULL AND p_senha_recomendada !~ '^[A-Z]{1,2}[0-9]{3}$')
       OR (p_senha_chamada IS NOT NULL AND p_senha_chamada !~ '^[A-Z]{1,2}[0-9]{3}$')
    THEN RETURN false; END IF;

    IF p_motivo = 'aguardando' THEN
        IF p_senha_chamada IS NOT NULL THEN RETURN false; END IF;
        -- Limite basico contra gravacao em massa; o ID impede repeticoes da mesma captura.
        IF NOT EXISTS (SELECT 1 FROM public.observacoes_chamadas_v2 WHERE evento_id=p_evento_id)
           AND (SELECT count(*) FROM public.observacoes_chamadas_v2
                WHERE unit_id=p_unit_id AND guiche=p_guiche
                  AND criado_em >= now() - interval '1 minute') >= 25
        THEN RETURN false; END IF;

        INSERT INTO public.observacoes_chamadas_v2
          (evento_id,unit_id,guiche,senha_recomendada,tipo_acao,situacao,motivo)
        VALUES (p_evento_id,p_unit_id,p_guiche,p_senha_recomendada,p_tipo_acao,
                'pendente','aguardando')
        ON CONFLICT (evento_id) DO NOTHING;
        RETURN true;
    END IF;

    IF p_motivo = 'tempo_esgotado' THEN
        UPDATE public.observacoes_chamadas_v2 o
           SET situacao='nao_verificado', motivo='tempo_esgotado', atualizado_em=now()
         WHERE o.evento_id=p_evento_id AND o.unit_id=p_unit_id AND o.guiche=p_guiche
           AND o.situacao='pendente' AND o.criado_em >= now()-interval '3 minutes';
        RETURN true;
    END IF;

    IF p_senha_chamada IS NULL THEN RETURN false; END IF;

    UPDATE public.observacoes_chamadas_v2 o SET
        senha_chamada=p_senha_chamada,
        situacao=CASE
            WHEN o.tipo_acao='proxima' AND o.senha_recomendada IS NOT NULL
                 AND p_motivo='chamada_confirmada'
            THEN CASE WHEN o.senha_recomendada=p_senha_chamada
                      THEN 'coincide' ELSE 'diverge' END
            ELSE 'nao_verificado'
        END,
        motivo=p_motivo,
        atualizado_em=now()
    WHERE o.evento_id=p_evento_id AND o.unit_id=p_unit_id AND o.guiche=p_guiche
      AND o.situacao='pendente' AND o.criado_em >= now()-interval '3 minutes';
    GET DIAGNOSTICS v_modificou = ROW_COUNT;
    RETURN v_modificou > 0;
END;
$$;

REVOKE ALL ON FUNCTION public.registrar_observacao_v2(
  uuid,uuid,text,text,text,text,text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_observacao_v2(
  uuid,uuid,text,text,text,text,text
) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.consultar_observacoes_v2(
    p_senha text, p_unit_id uuid, p_data date
)
RETURNS TABLE (
    evento_id uuid,
    guiche text,
    senha_chamada text,
    senha_recomendada text,
    tipo_acao text,
    situacao text,
    motivo text,
    criado_em timestamptz,
    atualizado_em timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF p_senha IS NULL OR p_unit_id IS NULL OR p_data IS NULL
       OR NOT EXISTS (
           SELECT 1 FROM public.unit_passwords up
           WHERE up.unit_id = p_unit_id
             AND up.password_hash = extensions.crypt(p_senha, up.password_hash)
       )
    THEN
        RAISE EXCEPTION 'Senha incorreta ou dados invalidos';
    END IF;
    RETURN QUERY
       SELECT o.evento_id, o.guiche, o.senha_chamada, o.senha_recomendada,
              o.tipo_acao, o.situacao, o.motivo, o.criado_em, o.atualizado_em
       FROM public.observacoes_chamadas_v2 o
       WHERE o.unit_id = p_unit_id
         AND o.criado_em >= (p_data::timestamp AT TIME ZONE 'America/Sao_Paulo')
         AND o.criado_em < ((p_data + 1)::timestamp AT TIME ZONE 'America/Sao_Paulo')
       ORDER BY o.criado_em DESC
       LIMIT 1000;
END;
$$;

REVOKE ALL ON FUNCTION public.consultar_observacoes_v2(text,uuid,date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.consultar_observacoes_v2(text,uuid,date)
  TO anon, authenticated;

-- Conferencia de instalacao, sem expor senhas:
SELECT to_regclass('public.observacoes_chamadas_v2') IS NOT NULL AS tabela_criada,
       has_function_privilege('anon',
         'public.registrar_observacao_v2(uuid,uuid,text,text,text,text,text)',
         'EXECUTE') AS gravacao_piloto_disponivel,
       has_function_privilege('anon',
         'public.consultar_observacoes_v2(text,uuid,date)',
         'EXECUTE') AS relatorio_piloto_disponivel;
