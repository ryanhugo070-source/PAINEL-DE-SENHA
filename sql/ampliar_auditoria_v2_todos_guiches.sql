-- MONITORAMENTO V2 - AMPLIAR PARA GUICHES DAS UNIDADES ATIVAS
-- Rodar uma vez no SQL Editor do mesmo projeto Supabase.
-- Exige que o SQL piloto V2 ja tenha sido executado.
-- Mantem registros existentes; nao altera historico_chamadas, priorizacao ou permissoes anteriores.
-- Observacoes nao servem para avaliar atendentes.

BEGIN;

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
    -- Apenas unidades ativas e guiches numericos identificados pelo painel.
    -- Dados observacionais; esta funcao NAO autentica a identidade do atendente.
    IF p_evento_id IS NULL OR p_unit_id IS NULL OR p_guiche IS NULL
       OR p_guiche !~ '^Guiche [1-9][0-9]{0,2}$'
       OR NOT EXISTS (
          SELECT 1 FROM public.units u
          WHERE u.id = p_unit_id AND u.active = true
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

COMMIT;

SELECT
  has_function_privilege(
    'anon', 'public.registrar_observacao_v2(uuid,uuid,text,text,text,text,text)', 'EXECUTE'
  ) AS registro_disponivel,
  pg_get_functiondef(
    'public.registrar_observacao_v2(uuid,uuid,text,text,text,text,text)'::regprocedure
  ) LIKE '%p_guiche !~%' AS todos_guiches_habilitados;
