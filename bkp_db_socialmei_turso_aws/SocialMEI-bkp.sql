--
-- PostgreSQL database dump
--

\restrict WiV6jzjX076uKLhK6F0XIC4JXbx6LdOVDMDLsKUrJ1b606h1Qb0qQa90m8j7atH

-- Dumped from database version 17.11 (Debian 17.11-1.pgdg13+2)
-- Dumped by pg_dump version 17.11 (Debian 17.11-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: socialmei; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA socialmei;


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: me_customer_link_revision(); Type: FUNCTION; Schema: socialmei; Owner: -
--

CREATE FUNCTION socialmei.me_customer_link_revision() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.cliente_id IS DISTINCT FROM OLD.cliente_id AND NEW.revision=OLD.revision THEN
        NEW.revision := OLD.revision+1;
    END IF;
    RETURN NEW;
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agenda_appointment_history; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.agenda_appointment_history (
    workspace_id bigint NOT NULL,
    appointment_id uuid NOT NULL,
    revision bigint NOT NULL,
    scheduled_for timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    status text NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT agenda_appointment_history_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'done'::text, 'cancelled'::text])))
);


--
-- Name: agenda_appointments; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.agenda_appointments (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    cliente_id bigint,
    servico_id bigint,
    resource_id uuid NOT NULL,
    client_name character varying(160) NOT NULL,
    service_name character varying(160) NOT NULL,
    duration_minutes integer NOT NULL,
    price numeric NOT NULL,
    scheduled_for timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    notes character varying(1000) DEFAULT ''::character varying NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    creation_fingerprint character(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT agenda_appointments_check CHECK ((ends_at = (scheduled_for + ((duration_minutes)::double precision * '00:01:00'::interval)))),
    CONSTRAINT agenda_appointments_duration_minutes_check CHECK (((duration_minutes >= 1) AND (duration_minutes <= 1440))),
    CONSTRAINT agenda_appointments_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT agenda_appointments_revision_check CHECK (((revision >= 1) AND (revision <= '9007199254740991'::bigint))),
    CONSTRAINT agenda_appointments_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'done'::text, 'cancelled'::text])))
);


--
-- Name: agenda_reminders; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.agenda_reminders (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    title character varying(160) NOT NULL,
    scheduled_for timestamp with time zone NOT NULL,
    notes character varying(1000) DEFAULT ''::character varying NOT NULL,
    cliente_id bigint,
    status text DEFAULT 'pending'::text NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    creation_fingerprint character(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT agenda_reminders_revision_check CHECK (((revision >= 1) AND (revision <= '9007199254740991'::bigint))),
    CONSTRAINT agenda_reminders_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'done'::text, 'cancelled'::text]))),
    CONSTRAINT agenda_reminders_title_check CHECK ((char_length(btrim((title)::text)) > 0))
);


--
-- Name: agenda_resources; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.agenda_resources (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    nome character varying(160) NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    creation_fingerprint character(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT agenda_resources_nome_check CHECK ((char_length(btrim((nome)::text)) > 0)),
    CONSTRAINT agenda_resources_revision_check CHECK (((revision >= 1) AND (revision <= '9007199254740991'::bigint)))
);


--
-- Name: auth_auditoria; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_auditoria (
    id bigint NOT NULL,
    user_id bigint,
    alvo_user_id bigint,
    acao character varying(40) NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: auth_auditoria_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.auth_auditoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auth_auditoria_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.auth_auditoria_id_seq OWNED BY socialmei.auth_auditoria.id;


--
-- Name: auth_convites; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_convites (
    token_hash character(64) NOT NULL,
    email character varying(255) NOT NULL,
    criado_por bigint,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    expira_em timestamp with time zone NOT NULL,
    usado_em timestamp with time zone,
    revogado_em timestamp with time zone,
    user_id bigint,
    CONSTRAINT auth_convites_check CHECK ((expira_em > criado_em)),
    CONSTRAINT auth_convites_token_hash_check CHECK ((token_hash ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: auth_credenciais; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_credenciais (
    user_id bigint NOT NULL,
    senha_hash text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    administrador_plataforma boolean DEFAULT false NOT NULL,
    senha_alterada_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT auth_credenciais_senha_hash_check CHECK ((senha_hash ~~ '$argon2id$%'::text))
);


--
-- Name: auth_email_activation; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_email_activation (
    user_id bigint NOT NULL,
    email character varying(255) NOT NULL,
    verified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: auth_identity_mail; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_identity_mail (
    id uuid NOT NULL,
    purpose character varying(12) NOT NULL,
    user_id bigint,
    workspace_id bigint,
    created_by bigint,
    email character varying(255) NOT NULL,
    role character varying(20),
    status character varying(12) DEFAULT 'pending'::character varying NOT NULL,
    token_hash character(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    expires_at timestamp with time zone DEFAULT (now() + '00:30:00'::interval) NOT NULL,
    finished_at timestamp with time zone,
    CONSTRAINT auth_identity_mail_check CHECK ((expires_at > created_at)),
    CONSTRAINT auth_identity_mail_check1 CHECK (((((purpose)::text = 'verification'::text) AND (user_id IS NOT NULL) AND (workspace_id IS NULL) AND (role IS NULL)) OR (((purpose)::text = 'invitation'::text) AND (workspace_id IS NOT NULL) AND (created_by IS NOT NULL) AND (role IS NOT NULL)))),
    CONSTRAINT auth_identity_mail_purpose_check CHECK (((purpose)::text = ANY ((ARRAY['verification'::character varying, 'invitation'::character varying])::text[]))),
    CONSTRAINT auth_identity_mail_role_check CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'member'::character varying, 'viewer'::character varying, 'report_viewer'::character varying])::text[]))),
    CONSTRAINT auth_identity_mail_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'sent'::character varying, 'uncertain'::character varying, 'expired'::character varying, 'used'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT auth_identity_mail_token_hash_check CHECK ((token_hash ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: auth_limites; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_limites (
    chave character(64) NOT NULL,
    inicio timestamp with time zone DEFAULT now() NOT NULL,
    tentativas integer DEFAULT 1 NOT NULL,
    CONSTRAINT auth_limites_tentativas_check CHECK ((tentativas > 0))
);


--
-- Name: auth_preferences; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_preferences (
    workspace_id bigint NOT NULL,
    user_id bigint NOT NULL,
    schema_version integer DEFAULT 1 NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    preferences jsonb NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT auth_preferences_preferences_check CHECK (((jsonb_typeof(preferences) = 'object'::text) AND (octet_length((preferences)::text) <= 2048))),
    CONSTRAINT auth_preferences_revision_check CHECK (((revision > 0) AND (revision <= '9007199254740991'::bigint))),
    CONSTRAINT auth_preferences_schema_version_check CHECK ((schema_version = 1))
);


--
-- Name: auth_recuperacao_envios; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_recuperacao_envios (
    user_id bigint NOT NULL,
    generation uuid NOT NULL,
    status character varying(12) NOT NULL,
    queued_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    CONSTRAINT auth_recuperacao_envios_status_check CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('processing'::character varying)::text, ('sent'::character varying)::text, ('uncertain'::character varying)::text, ('expired'::character varying)::text])))
);


--
-- Name: auth_recuperacoes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_recuperacoes (
    user_id bigint NOT NULL,
    token_hash character(64) NOT NULL,
    senha_alterada_em timestamp with time zone NOT NULL,
    expira_em timestamp with time zone NOT NULL,
    usado_em timestamp with time zone,
    CONSTRAINT auth_recuperacoes_token_hash_check CHECK ((token_hash ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: auth_sessoes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.auth_sessoes (
    token_hash character(64) NOT NULL,
    user_id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    criada_em timestamp with time zone DEFAULT now() NOT NULL,
    expira_em timestamp with time zone NOT NULL,
    revogada_em timestamp with time zone,
    public_id uuid DEFAULT gen_random_uuid() NOT NULL,
    CONSTRAINT auth_sessoes_check CHECK ((expira_em > criada_em)),
    CONSTRAINT auth_sessoes_token_hash_check CHECK ((token_hash ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: clientes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.clientes (
    id bigint NOT NULL,
    nome character varying(160) NOT NULL,
    telefone character varying(40),
    email character varying(255),
    identificador_externo character varying(255),
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: clientes_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.clientes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clientes_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.clientes_id_seq OWNED BY socialmei.clientes.id;


--
-- Name: content_preparation_events; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.content_preparation_events (
    workspace_id bigint NOT NULL,
    job_id uuid NOT NULL,
    id bigint NOT NULL,
    status character varying(20) NOT NULL,
    code character varying(40),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: content_preparation_events_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.content_preparation_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_preparation_events_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.content_preparation_events_id_seq OWNED BY socialmei.content_preparation_events.id;


--
-- Name: content_preparation_jobs; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.content_preparation_jobs (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    account_id uuid,
    requested_by bigint,
    idempotency_key uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    revision integer DEFAULT 1 NOT NULL,
    title character varying(120) DEFAULT ''::character varying NOT NULL,
    format character varying(10) NOT NULL,
    caption text NOT NULL,
    media_manifest jsonb NOT NULL,
    scheduled_for timestamp with time zone,
    timezone character varying(80) DEFAULT 'America/Fortaleza'::character varying NOT NULL,
    status character varying(20) NOT NULL,
    attempts smallint DEFAULT 0 NOT NULL,
    run_after timestamp with time zone,
    claim_token uuid,
    lease_until timestamp with time zone,
    last_error_code character varying(40),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT content_preparation_jobs_attempts_check CHECK (((attempts >= 0) AND (attempts <= 3))),
    CONSTRAINT content_preparation_jobs_caption_check CHECK ((length(caption) <= 2200)),
    CONSTRAINT content_preparation_jobs_check CHECK ((((status)::text <> ALL (ARRAY[('scheduled'::character varying)::text, ('processing'::character varying)::text, ('simulated'::character varying)::text])) OR ((account_id IS NOT NULL) AND (scheduled_for IS NOT NULL) AND (jsonb_array_length(media_manifest) > 0)))),
    CONSTRAINT content_preparation_jobs_format_check CHECK (((format)::text = ANY (ARRAY[('feed'::character varying)::text, ('story'::character varying)::text, ('reel'::character varying)::text]))),
    CONSTRAINT content_preparation_jobs_media_manifest_check CHECK ((jsonb_typeof(media_manifest) = 'array'::text)),
    CONSTRAINT content_preparation_jobs_revision_check CHECK ((revision > 0)),
    CONSTRAINT content_preparation_jobs_status_check CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('pending_review'::character varying)::text, ('scheduled'::character varying)::text, ('processing'::character varying)::text, ('simulated'::character varying)::text, ('failed'::character varying)::text, ('uncertain'::character varying)::text, ('cancelled'::character varying)::text])))
);


--
-- Name: conversas; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.conversas (
    id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    canal character varying(20) NOT NULL,
    identificador_externo character varying(255),
    status character varying(30) DEFAULT 'aberto'::character varying NOT NULL,
    nao_lidas integer DEFAULT 0 NOT NULL,
    ultima_mensagem_em timestamp with time zone,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT conversas_canal_check CHECK (((canal)::text = ANY (ARRAY[('whatsapp'::character varying)::text, ('instagram'::character varying)::text]))),
    CONSTRAINT conversas_nao_lidas_check CHECK ((nao_lidas >= 0)),
    CONSTRAINT conversas_status_check CHECK (((status)::text = ANY (ARRAY[('aberto'::character varying)::text, ('em_andamento'::character varying)::text, ('aguardando_cliente'::character varying)::text, ('concluido'::character varying)::text])))
);


--
-- Name: conversas_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.conversas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversas_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.conversas_id_seq OWNED BY socialmei.conversas.id;


--
-- Name: crm_canais; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_canais (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    canal character varying(20) DEFAULT 'whatsapp'::character varying NOT NULL,
    provedor character varying(40) DEFAULT 'waha'::character varying NOT NULL,
    instancia character varying(80) NOT NULL,
    sessao character varying(160) NOT NULL,
    nome character varying(160) DEFAULT ''::character varying NOT NULL,
    identificador_conta character varying(255),
    ativo boolean DEFAULT false NOT NULL,
    envio_habilitado boolean DEFAULT false NOT NULL,
    estado_provedor character varying(80),
    verificado_em timestamp with time zone,
    versao bigint DEFAULT 1 NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    ingress_provisioned boolean DEFAULT false NOT NULL,
    CONSTRAINT ck_waha_provisioned_account CHECK (((NOT ingress_provisioned) OR ((identificador_conta IS NOT NULL) AND ((identificador_conta)::text ~ '^[0-9]{1,40}@c[.]us$'::text)))),
    CONSTRAINT crm_canais_canal_check CHECK (((canal)::text = 'whatsapp'::text)),
    CONSTRAINT crm_canais_check CHECK (((NOT envio_habilitado) OR ativo)),
    CONSTRAINT crm_canais_identificador_conta_check CHECK (((identificador_conta IS NULL) OR (length(btrim((identificador_conta)::text)) > 0))),
    CONSTRAINT crm_canais_instancia_check CHECK (((instancia)::text ~ '^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,79}$'::text)),
    CONSTRAINT crm_canais_provedor_check CHECK (((provedor)::text = 'waha'::text)),
    CONSTRAINT crm_canais_sessao_check CHECK (((length(btrim((sessao)::text)) > 0) AND ((sessao)::text = btrim((sessao)::text)))),
    CONSTRAINT crm_canais_versao_check CHECK ((versao > 0))
);


--
-- Name: crm_canais_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.crm_canais_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_canais_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.crm_canais_id_seq OWNED BY socialmei.crm_canais.id;


--
-- Name: crm_cliente_importacoes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_cliente_importacoes (
    workspace_id bigint NOT NULL,
    origem uuid NOT NULL,
    local_id bigint NOT NULL,
    cliente_id bigint,
    fingerprint character(64) NOT NULL,
    snapshot jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT crm_cliente_importacoes_local_id_check CHECK (((local_id >= 0) AND (local_id <= '9007199254740991'::bigint)))
);


--
-- Name: crm_clientes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_clientes (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    nome character varying(160) NOT NULL,
    telefone character varying(40),
    email character varying(255),
    instagram character varying(160),
    status character varying(30) DEFAULT 'Ativo'::character varying NOT NULL,
    observacao text,
    tags jsonb DEFAULT '[]'::jsonb NOT NULL,
    legacy_local_id bigint,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    cidade character varying(160),
    desde character varying(160),
    categoria character varying(160),
    cadastro_original_em timestamp with time zone,
    observacao_atualizada_em timestamp with time zone,
    avatar_url character varying(2048),
    foto character varying(2048),
    ultima character varying(80),
    total numeric,
    pendente numeric,
    versao bigint DEFAULT 1 NOT NULL,
    CONSTRAINT crm_clientes_pendente_check CHECK ((pendente >= (0)::numeric)),
    CONSTRAINT crm_clientes_tags_check CHECK ((jsonb_typeof(tags) = 'array'::text)),
    CONSTRAINT crm_clientes_total_check CHECK ((total >= (0)::numeric)),
    CONSTRAINT crm_clientes_versao_check CHECK ((versao > 0))
);


--
-- Name: crm_clientes_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.crm_clientes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_clientes_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.crm_clientes_id_seq OWNED BY socialmei.crm_clientes.id;


--
-- Name: crm_conversas_canal; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_conversas_canal (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    canal_id bigint NOT NULL,
    identificador_externo character varying(255) NOT NULL,
    tipo character varying(20) DEFAULT 'direta'::character varying NOT NULL,
    cliente_id bigint,
    nome character varying(160) DEFAULT ''::character varying NOT NULL,
    status character varying(30) DEFAULT 'aberto'::character varying NOT NULL,
    nao_lidas integer DEFAULT 0 NOT NULL,
    ultima_mensagem_em timestamp with time zone,
    versao bigint DEFAULT 1 NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT crm_conversas_canal_check CHECK (((cliente_id IS NULL) OR ((tipo)::text = 'direta'::text))),
    CONSTRAINT crm_conversas_canal_identificador_externo_check CHECK ((length(btrim((identificador_externo)::text)) > 0)),
    CONSTRAINT crm_conversas_canal_nao_lidas_check CHECK ((nao_lidas >= 0)),
    CONSTRAINT crm_conversas_canal_status_check CHECK (((status)::text = ANY (ARRAY[('aberto'::character varying)::text, ('em_andamento'::character varying)::text, ('aguardando_cliente'::character varying)::text, ('concluido'::character varying)::text]))),
    CONSTRAINT crm_conversas_canal_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('direta'::character varying)::text, ('grupo'::character varying)::text, ('canal'::character varying)::text, ('outro'::character varying)::text]))),
    CONSTRAINT crm_conversas_canal_versao_check CHECK ((versao > 0))
);


--
-- Name: crm_conversas_canal_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.crm_conversas_canal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_conversas_canal_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.crm_conversas_canal_id_seq OWNED BY socialmei.crm_conversas_canal.id;


--
-- Name: crm_eventos_canal; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_eventos_canal (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    canal_id bigint NOT NULL,
    chave_evento character varying(255) NOT NULL,
    tipo character varying(80) NOT NULL,
    fingerprint character(64) NOT NULL,
    mensagem_externa_id character varying(1024),
    mensagem_id bigint,
    dados_normalizados jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying(20) DEFAULT 'recebido'::character varying NOT NULL,
    tentativas integer DEFAULT 0 NOT NULL,
    codigo_erro character varying(80),
    ocorrida_em timestamp with time zone,
    recebido_em timestamp with time zone DEFAULT now() NOT NULL,
    processado_em timestamp with time zone,
    waha_account_snapshot character varying(255),
    waha_event_key character(64),
    inbox_message_id bigint,
    inbox_origin text,
    CONSTRAINT ck_waha_ingress_event CHECK ((((waha_event_key IS NULL) AND (waha_account_snapshot IS NULL) AND (inbox_message_id IS NULL) AND (inbox_origin IS NULL)) OR ((waha_event_key IS NOT NULL) AND (waha_event_key ~ '^[0-9a-f]{64}$'::text) AND (waha_account_snapshot IS NOT NULL) AND (inbox_origin IS NOT NULL) AND (inbox_origin = 'waha'::text) AND ((status)::text = ANY (ARRAY[('processado'::character varying)::text, ('ignorado'::character varying)::text])) AND (((status)::text = 'processado'::text) = (inbox_message_id IS NOT NULL)) AND (mensagem_id IS NULL)))),
    CONSTRAINT crm_eventos_canal_chave_evento_check CHECK ((length(btrim((chave_evento)::text)) > 0)),
    CONSTRAINT crm_eventos_canal_check CHECK ((((status)::text = ANY (ARRAY[('processado'::character varying)::text, ('ignorado'::character varying)::text])) = (processado_em IS NOT NULL))),
    CONSTRAINT crm_eventos_canal_dados_normalizados_check CHECK (((jsonb_typeof(dados_normalizados) = 'object'::text) AND (octet_length((dados_normalizados)::text) <= 2000000))),
    CONSTRAINT crm_eventos_canal_fingerprint_check CHECK ((fingerprint ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT crm_eventos_canal_status_check CHECK (((status)::text = ANY (ARRAY[('recebido'::character varying)::text, ('processado'::character varying)::text, ('falha'::character varying)::text, ('ignorado'::character varying)::text]))),
    CONSTRAINT crm_eventos_canal_tentativas_check CHECK ((tentativas >= 0)),
    CONSTRAINT crm_eventos_canal_tipo_check CHECK ((length(btrim((tipo)::text)) > 0))
);


--
-- Name: crm_eventos_canal_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.crm_eventos_canal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_eventos_canal_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.crm_eventos_canal_id_seq OWNED BY socialmei.crm_eventos_canal.id;


--
-- Name: crm_financeiro; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_financeiro (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    cliente_id bigint,
    descricao character varying(240) NOT NULL,
    pessoa character varying(160) DEFAULT ''::character varying NOT NULL,
    tipo character varying(20) NOT NULL,
    valor numeric(15,2) NOT NULL,
    vencimento date NOT NULL,
    status character varying(20) NOT NULL,
    data_pagamento date,
    importada boolean DEFAULT false NOT NULL,
    excluida boolean DEFAULT false NOT NULL,
    versao bigint DEFAULT 1 NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT crm_financeiro_check CHECK ((((status)::text = 'pago'::text) OR (data_pagamento IS NULL))),
    CONSTRAINT crm_financeiro_status_check CHECK (((status)::text = ANY (ARRAY[('aberto'::character varying)::text, ('atrasado'::character varying)::text, ('pago'::character varying)::text]))),
    CONSTRAINT crm_financeiro_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('receita'::character varying)::text, ('despesa'::character varying)::text]))),
    CONSTRAINT crm_financeiro_valor_check CHECK ((valor >= (0)::numeric)),
    CONSTRAINT crm_financeiro_versao_check CHECK ((versao > 0))
);


--
-- Name: crm_financeiro_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.crm_financeiro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_financeiro_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.crm_financeiro_id_seq OWNED BY socialmei.crm_financeiro.id;


--
-- Name: crm_financeiro_importacoes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_financeiro_importacoes (
    workspace_id bigint NOT NULL,
    origem uuid NOT NULL,
    local_id bigint NOT NULL,
    lancamento_id bigint NOT NULL,
    fingerprint character(64) NOT NULL,
    snapshot jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT crm_financeiro_importacoes_local_id_check CHECK (((local_id >= 0) AND (local_id <= '9007199254740991'::bigint)))
);


--
-- Name: crm_financeiro_operacoes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_financeiro_operacoes (
    workspace_id bigint NOT NULL,
    operation_id uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    resposta jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: crm_mensagens_canal; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_mensagens_canal (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    canal_id bigint NOT NULL,
    conversa_id bigint NOT NULL,
    identificador_externo character varying(255),
    operation_id uuid,
    operation_fingerprint character(64),
    direcao character varying(10) NOT NULL,
    tipo character varying(20) DEFAULT 'texto'::character varying NOT NULL,
    conteudo text DEFAULT ''::text NOT NULL,
    remetente_externo character varying(255),
    destinatario_externo character varying(255),
    participante_externo character varying(255),
    midia_ref character varying(512),
    midia_mime character varying(160),
    status character varying(20) NOT NULL,
    ocorrida_em timestamp with time zone,
    enviada_em timestamp with time zone,
    entregue_em timestamp with time zone,
    lida_em timestamp with time zone,
    versao bigint DEFAULT 1 NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT crm_mensagens_canal_check CHECK (((operation_id IS NULL) = (operation_fingerprint IS NULL))),
    CONSTRAINT crm_mensagens_canal_check1 CHECK (((((direcao)::text = 'entrada'::text) AND (identificador_externo IS NOT NULL) AND (operation_id IS NULL) AND ((status)::text = 'recebida'::text)) OR (((direcao)::text = 'saida'::text) AND (operation_id IS NOT NULL) AND ((status)::text <> 'recebida'::text)) OR (((direcao)::text = 'saida'::text) AND (operation_id IS NULL) AND (identificador_externo IS NOT NULL) AND ((status)::text = ANY (ARRAY[('enviada'::character varying)::text, ('entregue'::character varying)::text, ('lida'::character varying)::text]))))),
    CONSTRAINT crm_mensagens_canal_check2 CHECK ((((status)::text <> ALL (ARRAY[('enviada'::character varying)::text, ('entregue'::character varying)::text, ('lida'::character varying)::text])) OR ((identificador_externo IS NOT NULL) AND (enviada_em IS NOT NULL)))),
    CONSTRAINT crm_mensagens_canal_check3 CHECK ((((status)::text <> 'entregue'::text) OR (entregue_em IS NOT NULL))),
    CONSTRAINT crm_mensagens_canal_check4 CHECK ((((status)::text <> 'lida'::text) OR (lida_em IS NOT NULL))),
    CONSTRAINT crm_mensagens_canal_check5 CHECK (((entregue_em IS NULL) OR (enviada_em IS NOT NULL))),
    CONSTRAINT crm_mensagens_canal_check6 CHECK ((((direcao)::text = 'saida'::text) OR ((enviada_em IS NULL) AND (entregue_em IS NULL) AND (lida_em IS NULL)))),
    CONSTRAINT crm_mensagens_canal_direcao_check CHECK (((direcao)::text = ANY (ARRAY[('entrada'::character varying)::text, ('saida'::character varying)::text]))),
    CONSTRAINT crm_mensagens_canal_identificador_externo_check CHECK (((identificador_externo IS NULL) OR (length(btrim((identificador_externo)::text)) > 0))),
    CONSTRAINT crm_mensagens_canal_operation_fingerprint_check CHECK (((operation_fingerprint IS NULL) OR (operation_fingerprint ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT crm_mensagens_canal_status_check CHECK (((status)::text = ANY (ARRAY[('recebida'::character varying)::text, ('rascunho'::character varying)::text, ('pendente'::character varying)::text, ('enviada'::character varying)::text, ('entregue'::character varying)::text, ('lida'::character varying)::text, ('falha'::character varying)::text, ('incerta'::character varying)::text, ('cancelada'::character varying)::text]))),
    CONSTRAINT crm_mensagens_canal_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('texto'::character varying)::text, ('imagem'::character varying)::text, ('audio'::character varying)::text, ('video'::character varying)::text, ('documento'::character varying)::text, ('outro'::character varying)::text]))),
    CONSTRAINT crm_mensagens_canal_versao_check CHECK ((versao > 0))
);


--
-- Name: crm_mensagens_canal_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.crm_mensagens_canal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_mensagens_canal_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.crm_mensagens_canal_id_seq OWNED BY socialmei.crm_mensagens_canal.id;


--
-- Name: crm_opportunities; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_opportunities (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    client_id bigint NOT NULL,
    title character varying(160) NOT NULL,
    interest_level character varying(10) NOT NULL,
    outcome character varying(10) DEFAULT 'open'::character varying NOT NULL,
    outcome_reason character varying(30) DEFAULT ''::character varying NOT NULL,
    outcome_note character varying(1000) DEFAULT ''::character varying NOT NULL,
    sale_id bigint,
    revision bigint DEFAULT 1 NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    estimated_amount numeric(12,2) DEFAULT 0 NOT NULL,
    follow_up_date date,
    planning_note text DEFAULT ''::text NOT NULL,
    contacted boolean DEFAULT false NOT NULL,
    planning_initialized boolean DEFAULT false NOT NULL,
    legacy_planning jsonb,
    CONSTRAINT crm_opportunities_check CHECK (((((outcome)::text = 'open'::text) AND ((outcome_reason)::text = ''::text) AND (closed_at IS NULL)) OR (((outcome)::text = 'won'::text) AND ((outcome_reason)::text = 'sale_completed'::text) AND (closed_at IS NOT NULL)) OR (((outcome)::text = 'lost'::text) AND ((outcome_reason)::text = ANY (ARRAY[('gave_up'::character varying)::text, ('other_supplier'::character varying)::text, ('price'::character varying)::text, ('timing'::character varying)::text, ('other'::character varying)::text])) AND (closed_at IS NOT NULL)))),
    CONSTRAINT crm_opportunities_estimated_amount_check CHECK (((estimated_amount >= (0)::numeric) AND (estimated_amount <= (1000000000)::numeric))),
    CONSTRAINT crm_opportunities_interest_level_check CHECK (((interest_level)::text = ANY (ARRAY[('unknown'::character varying)::text, ('cold'::character varying)::text, ('warm'::character varying)::text, ('hot'::character varying)::text]))),
    CONSTRAINT crm_opportunities_legacy_planning_check CHECK (((legacy_planning IS NULL) OR ((jsonb_typeof(legacy_planning) = 'object'::text) AND (octet_length((legacy_planning)::text) <= 32768)))),
    CONSTRAINT crm_opportunities_outcome_check CHECK (((outcome)::text = ANY (ARRAY[('open'::character varying)::text, ('won'::character varying)::text, ('lost'::character varying)::text]))),
    CONSTRAINT crm_opportunities_planning_note_check CHECK (((length(planning_note) + length(regexp_replace(planning_note, '[-￿]'::text, ''::text, 'g'::text))) <= 140)),
    CONSTRAINT crm_opportunities_revision_check CHECK ((revision > 0)),
    CONSTRAINT crm_opportunities_title_check CHECK ((length(btrim((title)::text)) > 0))
);


--
-- Name: crm_opportunity_events; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_opportunity_events (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    opportunity_id uuid NOT NULL,
    actor_id bigint,
    action character varying(10) NOT NULL,
    reason character varying(300) DEFAULT ''::character varying NOT NULL,
    previous jsonb,
    current jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT crm_opportunity_events_action_check CHECK (((action)::text = ANY (ARRAY[('create'::character varying)::text, ('edit'::character varying)::text, ('close'::character varying)::text, ('reopen'::character varying)::text, ('sale'::character varying)::text])))
);


--
-- Name: crm_opportunity_events_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.crm_opportunity_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_opportunity_events_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.crm_opportunity_events_id_seq OWNED BY socialmei.crm_opportunity_events.id;


--
-- Name: crm_opportunity_operations; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_opportunity_operations (
    workspace_id bigint NOT NULL,
    operation_id uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    response jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: crm_produto_importacoes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_produto_importacoes (
    workspace_id bigint NOT NULL,
    origem uuid NOT NULL,
    local_id bigint NOT NULL,
    produto_id bigint,
    fingerprint character(64) NOT NULL,
    snapshot jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT crm_produto_importacoes_local_id_check CHECK (((local_id >= 0) AND (local_id <= '9007199254740991'::bigint)))
);


--
-- Name: crm_produtos; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_produtos (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    nome character varying(160) NOT NULL,
    tipo character varying(20) NOT NULL,
    preco numeric NOT NULL,
    custo numeric DEFAULT 0 NOT NULL,
    estoque bigint,
    minimo bigint,
    status character varying(30) DEFAULT 'Ativo'::character varying NOT NULL,
    versao bigint DEFAULT 1 NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    duracao_minutos integer,
    categoria character varying(80) DEFAULT ''::character varying NOT NULL,
    descricao character varying(2000) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT ck_service_duration CHECK (((duracao_minutos IS NULL) OR (((tipo)::text = 'Serviço'::text) AND ((duracao_minutos >= 1) AND (duracao_minutos <= 1440))))),
    CONSTRAINT crm_produtos_check CHECK (((((tipo)::text = 'Produto'::text) AND (estoque IS NOT NULL) AND (minimo IS NOT NULL)) OR (((tipo)::text = 'Serviço'::text) AND (estoque IS NULL) AND (minimo IS NULL)))),
    CONSTRAINT crm_produtos_custo_check CHECK ((custo >= (0)::numeric)),
    CONSTRAINT crm_produtos_estoque_check CHECK (((estoque >= 0) AND (estoque <= '9007199254740991'::bigint))),
    CONSTRAINT crm_produtos_minimo_check CHECK (((minimo >= 0) AND (minimo <= '9007199254740991'::bigint))),
    CONSTRAINT crm_produtos_preco_check CHECK ((preco >= (0)::numeric)),
    CONSTRAINT crm_produtos_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('Produto'::character varying)::text, ('Serviço'::character varying)::text]))),
    CONSTRAINT crm_produtos_versao_check CHECK ((versao > 0))
);


--
-- Name: crm_produtos_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.crm_produtos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_produtos_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.crm_produtos_id_seq OWNED BY socialmei.crm_produtos.id;


--
-- Name: crm_transferencias; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_transferencias (
    workspace_id bigint NOT NULL,
    origem uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    snapshot jsonb NOT NULL,
    resposta jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: crm_venda_importacoes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_venda_importacoes (
    workspace_id bigint NOT NULL,
    origem uuid NOT NULL,
    local_id bigint NOT NULL,
    venda_id bigint NOT NULL,
    fingerprint character(64) NOT NULL,
    snapshot jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT crm_venda_importacoes_local_id_check CHECK (((local_id >= 0) AND (local_id <= '9007199254740991'::bigint)))
);


--
-- Name: crm_venda_operacoes; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_venda_operacoes (
    workspace_id bigint NOT NULL,
    operation_id uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    resposta jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: crm_vendas; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.crm_vendas (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    cliente_id bigint,
    produto_id bigint,
    cliente character varying(160) NOT NULL,
    item character varying(160) NOT NULL,
    tipo_item character varying(20),
    data date NOT NULL,
    quantidade bigint NOT NULL,
    preco numeric(15,2),
    desconto numeric(15,2) DEFAULT 0 NOT NULL,
    valor numeric(15,2) NOT NULL,
    pagamento character varying(40) NOT NULL,
    observacao text DEFAULT ''::text NOT NULL,
    status character varying(20) NOT NULL,
    estoque_aplicado boolean DEFAULT false NOT NULL,
    importada boolean DEFAULT false NOT NULL,
    excluida boolean DEFAULT false NOT NULL,
    versao bigint DEFAULT 1 NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT crm_vendas_check CHECK ((importada OR (preco IS NOT NULL))),
    CONSTRAINT crm_vendas_check1 CHECK (((NOT estoque_aplicado) OR (((tipo_item)::text = 'Produto'::text) AND ((status)::text = ANY (ARRAY[('Pendente'::character varying)::text, ('Pago'::character varying)::text])) AND (NOT excluida)))),
    CONSTRAINT crm_vendas_desconto_check CHECK ((desconto >= (0)::numeric)),
    CONSTRAINT crm_vendas_preco_check CHECK ((preco >= (0)::numeric)),
    CONSTRAINT crm_vendas_quantidade_check CHECK (((quantidade > 0) AND (quantidade <= '9007199254740991'::bigint))),
    CONSTRAINT crm_vendas_status_check CHECK (((status)::text = ANY (ARRAY[('Rascunho'::character varying)::text, ('Pendente'::character varying)::text, ('Pago'::character varying)::text, ('Cancelado'::character varying)::text]))),
    CONSTRAINT crm_vendas_tipo_item_check CHECK (((tipo_item)::text = ANY (ARRAY[('Produto'::character varying)::text, ('Serviço'::character varying)::text]))),
    CONSTRAINT crm_vendas_valor_check CHECK ((valor >= (0)::numeric)),
    CONSTRAINT crm_vendas_versao_check CHECK ((versao > 0))
);


--
-- Name: crm_vendas_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.crm_vendas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crm_vendas_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.crm_vendas_id_seq OWNED BY socialmei.crm_vendas.id;


--
-- Name: ig_direct_attempts; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_direct_attempts (
    workspace_id bigint NOT NULL,
    job_id uuid NOT NULL,
    attempt smallint NOT NULL,
    claim_token uuid NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    CONSTRAINT ig_direct_attempts_attempt_check CHECK (((attempt >= 1) AND (attempt <= 3))),
    CONSTRAINT ig_direct_attempts_check CHECK (((status = 'dispatching'::text) = (finished_at IS NULL))),
    CONSTRAINT ig_direct_attempts_status_check CHECK ((status = ANY (ARRAY['dispatching'::text, 'confirmed'::text, 'rejected'::text, 'rate_limited'::text, 'uncertain'::text])))
);


--
-- Name: ig_direct_events; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_direct_events (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    job_id uuid NOT NULL,
    actor_id bigint,
    action text NOT NULL,
    revision bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ig_direct_events_action_check CHECK ((action = ANY (ARRAY['created'::text, 'edited'::text, 'approved'::text, 'cancelled'::text, 'dispatching'::text, 'confirmed'::text, 'retry_ready'::text, 'failed'::text, 'uncertain'::text])))
);


--
-- Name: ig_direct_events_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.ig_direct_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ig_direct_events_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.ig_direct_events_id_seq OWNED BY socialmei.ig_direct_events.id;


--
-- Name: ig_direct_jobs; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_direct_jobs (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    conversation_id bigint NOT NULL,
    source_message_id bigint NOT NULL,
    origin text DEFAULT 'instagram'::text NOT NULL,
    connection_id uuid NOT NULL,
    external_account_id character varying(40) NOT NULL,
    recipient_id character varying(40) NOT NULL,
    text text NOT NULL,
    fingerprint character(64) NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    created_by bigint,
    created_session character(64) NOT NULL,
    approved_by bigint,
    approved_session character(64),
    approved_revision bigint,
    approved_fingerprint character(64),
    attempts smallint DEFAULT 0 NOT NULL,
    claim_token uuid,
    lease_until timestamp with time zone,
    run_after timestamp with time zone,
    provider_message_id character varying(1024),
    last_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ig_direct_jobs_approved_fingerprint_check CHECK (((approved_fingerprint IS NULL) OR (approved_fingerprint ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT ig_direct_jobs_approved_session_check CHECK ((approved_session ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT ig_direct_jobs_attempts_check CHECK (((attempts >= 0) AND (attempts <= 3))),
    CONSTRAINT ig_direct_jobs_check CHECK (((status <> ALL (ARRAY['approved'::text, 'dispatching'::text, 'confirmed'::text, 'retry_ready'::text, 'failed'::text, 'uncertain'::text])) OR ((approved_revision IS NOT NULL) AND (approved_fingerprint IS NOT NULL) AND (approved_revision = revision) AND (approved_fingerprint = fingerprint)))),
    CONSTRAINT ig_direct_jobs_check1 CHECK (((status = 'dispatching'::text) = ((claim_token IS NOT NULL) AND (lease_until IS NOT NULL)))),
    CONSTRAINT ig_direct_jobs_check2 CHECK (((status = 'confirmed'::text) = (provider_message_id IS NOT NULL))),
    CONSTRAINT ig_direct_jobs_created_session_check CHECK ((created_session ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT ig_direct_jobs_fingerprint_check CHECK ((fingerprint ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT ig_direct_jobs_last_error_check CHECK ((last_error = ANY (ARRAY['rate_limited'::text, 'rejected'::text, 'outcome_unknown'::text, 'lease_expired'::text]))),
    CONSTRAINT ig_direct_jobs_origin_check CHECK ((origin = 'instagram'::text)),
    CONSTRAINT ig_direct_jobs_provider_message_id_check CHECK (((provider_message_id IS NULL) OR (((provider_message_id)::text ~ '^[!-~]+$'::text) AND (octet_length((provider_message_id)::text) <= 1024)))),
    CONSTRAINT ig_direct_jobs_recipient_id_check CHECK (((recipient_id)::text ~ '^[0-9]{1,40}$'::text)),
    CONSTRAINT ig_direct_jobs_revision_check CHECK ((revision > 0)),
    CONSTRAINT ig_direct_jobs_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'approved'::text, 'dispatching'::text, 'confirmed'::text, 'retry_ready'::text, 'failed'::text, 'uncertain'::text, 'cancelled'::text]))),
    CONSTRAINT ig_direct_jobs_text_check CHECK (((octet_length(text) >= 1) AND (octet_length(text) <= 1000) AND (length(btrim(text)) > 0)))
);


--
-- Name: ig_direct_operations; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_direct_operations (
    workspace_id bigint NOT NULL,
    operation_id uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    response jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ig_direct_operations_response_check CHECK ((jsonb_typeof(response) = 'object'::text))
);


--
-- Name: ig_lab_connections; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_lab_connections (
    workspace_id bigint NOT NULL,
    account_id uuid NOT NULL,
    status text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT ig_lab_connections_status_check CHECK ((status = ANY (ARRAY['connected'::text, 'disconnected'::text, 'expired'::text, 'revoked'::text])))
);


--
-- Name: ig_lab_events; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_lab_events (
    workspace_id bigint NOT NULL,
    event_id uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    result jsonb NOT NULL
);


--
-- Name: ig_lab_publications; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_lab_publications (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    account_id uuid NOT NULL,
    idempotency_key uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    payload jsonb NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    approved_by bigint,
    attempts integer DEFAULT 0 NOT NULL,
    provider_result jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ig_lab_publications_attempts_check CHECK (((attempts >= 0) AND (attempts <= 3))),
    CONSTRAINT ig_lab_publications_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'processing'::text, 'simulated-published'::text, 'failed'::text])))
);


--
-- Name: ig_lab_states; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_lab_states (
    state_hash character(64) NOT NULL,
    workspace_id bigint NOT NULL,
    user_id bigint NOT NULL,
    session_hash character(64) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone
);


--
-- Name: ig_menu_conversations; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_menu_conversations (
    workspace_id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    origin text DEFAULT 'instagram'::text NOT NULL,
    state text DEFAULT 'menu'::text NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    last_message_id bigint,
    last_occurred_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ig_menu_conversations_origin_check CHECK ((origin = 'instagram'::text)),
    CONSTRAINT ig_menu_conversations_revision_check CHECK ((revision >= 0)),
    CONSTRAINT ig_menu_conversations_state_check CHECK ((state = ANY (ARRAY['menu'::text, 'ask_product'::text, 'human'::text])))
);


--
-- Name: ig_menu_replies; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_menu_replies (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    conversation_id bigint NOT NULL,
    source_message_id bigint NOT NULL,
    origin text DEFAULT 'instagram'::text NOT NULL,
    connection_id uuid NOT NULL,
    external_account_id character varying(40) NOT NULL,
    recipient_id character varying(40) NOT NULL,
    text text NOT NULL,
    status text NOT NULL,
    provider_message_id character varying(1024),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    CONSTRAINT ig_menu_replies_check CHECK (((status = 'confirmed'::text) = (provider_message_id IS NOT NULL))),
    CONSTRAINT ig_menu_replies_check1 CHECK (((status = 'dispatching'::text) = (finished_at IS NULL))),
    CONSTRAINT ig_menu_replies_origin_check CHECK ((origin = 'instagram'::text)),
    CONSTRAINT ig_menu_replies_provider_message_id_check CHECK (((provider_message_id IS NULL) OR ((provider_message_id)::text ~ '^[!-~]+$'::text))),
    CONSTRAINT ig_menu_replies_recipient_id_check CHECK (((recipient_id)::text ~ '^[0-9]{1,40}$'::text)),
    CONSTRAINT ig_menu_replies_status_check CHECK ((status = ANY (ARRAY['dispatching'::text, 'confirmed'::text, 'uncertain'::text, 'failed'::text, 'skipped'::text]))),
    CONSTRAINT ig_menu_replies_text_check CHECK ((octet_length(text) <= 1000))
);


--
-- Name: ig_meta_audit; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_meta_audit (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    user_id bigint,
    connection_id uuid,
    action text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ig_meta_audit_action_check CHECK ((action = ANY (ARRAY['started'::text, 'connected'::text, 'failed'::text, 'disconnected'::text, 'expired'::text, 'key_rotated'::text])))
);


--
-- Name: ig_meta_audit_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.ig_meta_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ig_meta_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.ig_meta_audit_id_seq OWNED BY socialmei.ig_meta_audit.id;


--
-- Name: ig_meta_connections; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_meta_connections (
    id uuid NOT NULL,
    workspace_id bigint NOT NULL,
    external_account_id character varying(40) NOT NULL,
    account_type text NOT NULL,
    status text NOT NULL,
    scopes text[] NOT NULL,
    encrypted_token text,
    token_kind text NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    disconnected_at timestamp with time zone,
    CONSTRAINT ig_meta_connections_account_type_check CHECK ((account_type = ANY (ARRAY['BUSINESS'::text, 'MEDIA_CREATOR'::text]))),
    CONSTRAINT ig_meta_connections_check CHECK ((expires_at > issued_at)),
    CONSTRAINT ig_meta_connections_check1 CHECK (((status = 'connected'::text) = (encrypted_token IS NOT NULL))),
    CONSTRAINT ig_meta_connections_check2 CHECK (((status <> 'connected'::text) = (disconnected_at IS NOT NULL))),
    CONSTRAINT ig_meta_connections_encrypted_token_check CHECK (((length(encrypted_token) >= 1) AND (length(encrypted_token) <= 24000))),
    CONSTRAINT ig_meta_connections_external_account_id_check CHECK (((external_account_id)::text ~ '^[0-9]{1,40}$'::text)),
    CONSTRAINT ig_meta_connections_revision_check CHECK ((revision > 0)),
    CONSTRAINT ig_meta_connections_scopes_check CHECK (((cardinality(scopes) >= 1) AND (cardinality(scopes) <= 4))),
    CONSTRAINT ig_meta_connections_status_check CHECK ((status = ANY (ARRAY['connected'::text, 'disconnected'::text, 'expired'::text]))),
    CONSTRAINT ig_meta_connections_token_kind_check CHECK ((token_kind = 'long'::text))
);


--
-- Name: ig_meta_ingress_events; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_meta_ingress_events (
    external_account_id character varying(40) NOT NULL,
    event_key character(64) NOT NULL,
    workspace_id bigint NOT NULL,
    connection_id uuid NOT NULL,
    kind text NOT NULL,
    fingerprint character(64) NOT NULL,
    status text NOT NULL,
    message_id bigint,
    message_origin text DEFAULT 'instagram'::text NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ig_meta_ingress_events_check CHECK (((status = 'processed'::text) = (message_id IS NOT NULL))),
    CONSTRAINT ig_meta_ingress_events_check1 CHECK (((kind = 'message'::text) = (status = 'processed'::text))),
    CONSTRAINT ig_meta_ingress_events_event_key_check CHECK ((event_key ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT ig_meta_ingress_events_external_account_id_check CHECK (((external_account_id)::text ~ '^[0-9]{1,40}$'::text)),
    CONSTRAINT ig_meta_ingress_events_fingerprint_check CHECK ((fingerprint ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT ig_meta_ingress_events_kind_check CHECK ((kind = ANY (ARRAY['message'::text, 'echo'::text, 'receipt'::text, 'unsupported'::text]))),
    CONSTRAINT ig_meta_ingress_events_message_origin_check CHECK ((message_origin = 'instagram'::text)),
    CONSTRAINT ig_meta_ingress_events_status_check CHECK ((status = ANY (ARRAY['processed'::text, 'ignored'::text])))
);


--
-- Name: ig_meta_media; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_meta_media (
    id uuid NOT NULL,
    workspace_id bigint NOT NULL,
    created_by bigint NOT NULL,
    request_id uuid NOT NULL,
    public_key text NOT NULL,
    fingerprint text NOT NULL,
    image_bytes bytea NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '01:00:00'::interval) NOT NULL,
    CONSTRAINT ig_meta_media_image_bytes_check CHECK (((octet_length(image_bytes) >= 1) AND (octet_length(image_bytes) <= 2097152)))
);


--
-- Name: ig_meta_oauth_states; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_meta_oauth_states (
    state_hash character(64) NOT NULL,
    workspace_id bigint NOT NULL,
    user_id bigint NOT NULL,
    session_hash character(64) NOT NULL,
    callback_uri text NOT NULL,
    scopes text[] NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    CONSTRAINT ig_meta_oauth_states_callback_uri_check CHECK (((length(callback_uri) >= 1) AND (length(callback_uri) <= 2048))),
    CONSTRAINT ig_meta_oauth_states_check CHECK ((expires_at > created_at)),
    CONSTRAINT ig_meta_oauth_states_check1 CHECK (((status = 'pending'::text) = (consumed_at IS NULL))),
    CONSTRAINT ig_meta_oauth_states_scopes_check CHECK (((cardinality(scopes) >= 1) AND (cardinality(scopes) <= 4))),
    CONSTRAINT ig_meta_oauth_states_state_hash_check CHECK ((state_hash ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT ig_meta_oauth_states_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'exchanging'::text, 'connected'::text, 'failed'::text, 'cancelled'::text])))
);


--
-- Name: ig_meta_publications; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.ig_meta_publications (
    id uuid NOT NULL,
    workspace_id bigint NOT NULL,
    request_id uuid NOT NULL,
    created_by bigint NOT NULL,
    connection_id uuid NOT NULL,
    external_account_id text NOT NULL,
    image_url text NOT NULL,
    caption text NOT NULL,
    content_fingerprint text NOT NULL,
    status text NOT NULL,
    container_id text,
    media_id text,
    error_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    checked_at timestamp with time zone,
    CONSTRAINT ig_meta_publications_status_check CHECK ((status = ANY (ARRAY['creating'::text, 'created'::text, 'publishing'::text, 'published'::text, 'uncertain'::text])))
);


--
-- Name: instagram_sim_accounts; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.instagram_sim_accounts (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    label character varying(80) NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT instagram_sim_accounts_label_check CHECK ((length(btrim((label)::text)) > 0))
);


--
-- Name: instagram_sim_publications; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.instagram_sim_publications (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    account_id uuid NOT NULL,
    requested_by bigint,
    idempotency_key uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    format character varying(10) NOT NULL,
    caption text NOT NULL,
    media_manifest jsonb NOT NULL,
    scheduled_for timestamp with time zone,
    status character varying(20) DEFAULT 'simulated'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT instagram_sim_publications_caption_check CHECK ((length(caption) <= 2200)),
    CONSTRAINT instagram_sim_publications_format_check CHECK (((format)::text = ANY (ARRAY[('feed'::character varying)::text, ('story'::character varying)::text, ('reel'::character varying)::text]))),
    CONSTRAINT instagram_sim_publications_media_manifest_check CHECK ((jsonb_typeof(media_manifest) = 'array'::text)),
    CONSTRAINT instagram_sim_publications_status_check CHECK (((status)::text = 'simulated'::text))
);


--
-- Name: integration_setup; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.integration_setup (
    workspace_id bigint NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    instagram jsonb NOT NULL,
    updated_by bigint NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT integration_setup_instagram_check CHECK (((jsonb_typeof(instagram) = 'object'::text) AND (octet_length((instagram)::text) <= 8192) AND (instagram ?& ARRAY['username'::text, 'account_type'::text, 'meta_app_status'::text, 'test_participants'::text, 'reply_mode'::text]) AND ((instagram - ARRAY['username'::text, 'account_type'::text, 'meta_app_status'::text, 'test_participants'::text, 'reply_mode'::text]) = '{}'::jsonb) AND ((instagram ->> 'reply_mode'::text) = 'review'::text) AND ((instagram ->> 'account_type'::text) = ANY (ARRAY['unknown'::text, 'business'::text, 'creator'::text])) AND ((instagram ->> 'meta_app_status'::text) = ANY (ARRAY['unknown'::text, 'exists'::text, 'not_created'::text])) AND (jsonb_typeof((instagram -> 'test_participants'::text)) = 'array'::text) AND (jsonb_array_length((instagram -> 'test_participants'::text)) <= 10))),
    CONSTRAINT integration_setup_revision_check CHECK (((revision > 0) AND (revision <= '9007199254740991'::bigint)))
);


--
-- Name: kb_pdf_chunks; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.kb_pdf_chunks (
    workspace_id bigint NOT NULL,
    document_id uuid NOT NULL,
    ordinal integer NOT NULL,
    page_number integer NOT NULL,
    content text NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('portuguese'::regconfig, content)) STORED,
    CONSTRAINT kb_pdf_chunks_content_check CHECK (((length(content) >= 1) AND (length(content) <= 1200))),
    CONSTRAINT kb_pdf_chunks_ordinal_check CHECK (((ordinal >= 0) AND (ordinal <= 10000))),
    CONSTRAINT kb_pdf_chunks_page_number_check CHECK (((page_number >= 1) AND (page_number <= 100)))
);


--
-- Name: kb_pdf_documents; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.kb_pdf_documents (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    filename character varying(160) NOT NULL,
    sha256 character(64) NOT NULL,
    pdf_bytes bytea NOT NULL,
    page_count integer NOT NULL,
    status text NOT NULL,
    uploaded_by bigint,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT kb_pdf_documents_page_count_check CHECK (((page_count >= 1) AND (page_count <= 100))),
    CONSTRAINT kb_pdf_documents_pdf_bytes_check CHECK (((octet_length(pdf_bytes) >= 8) AND (octet_length(pdf_bytes) <= 2097152))),
    CONSTRAINT kb_pdf_documents_sha256_check CHECK ((sha256 ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT kb_pdf_documents_status_check CHECK ((status = ANY (ARRAY['indexed'::text, 'no_text'::text])))
);


--
-- Name: me_citations; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_citations (
    workspace_id bigint NOT NULL,
    job_id uuid NOT NULL,
    document_id bigint NOT NULL,
    document_revision bigint NOT NULL
);


--
-- Name: me_conversations; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_conversations (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    channel text NOT NULL,
    account_ref character varying(110) NOT NULL,
    contact_ref character varying(110) NOT NULL,
    contact_name character varying(120) NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    origin text DEFAULT 'synthetic'::text NOT NULL,
    cliente_id bigint,
    CONSTRAINT ck_me_conversation_origin CHECK ((((origin = 'synthetic'::text) AND ((account_ref)::text ~~ 'synthetic:%'::text) AND ((contact_ref)::text ~~ 'synthetic:%'::text)) OR ((origin = 'instagram'::text) AND (channel = 'instagram'::text) AND ((account_ref)::text ~ '^instagram:[0-9]{1,40}$'::text) AND ((contact_ref)::text ~ '^instagram:[0-9]{1,40}$'::text)) OR ((origin = 'waha'::text) AND (channel = 'whatsapp'::text) AND ((account_ref)::text ~ '^waha:[0-9]{1,40}@c[.]us$'::text) AND ((contact_ref)::text ~ '^waha:([0-9]{1,40}@c[.]us|[A-Za-z0-9][A-Za-z0-9_.:-]{0,79}@lid)$'::text)))),
    CONSTRAINT me_conversations_channel_check CHECK ((channel = ANY (ARRAY['whatsapp'::text, 'instagram'::text]))),
    CONSTRAINT me_conversations_id_check CHECK ((id <= '9007199254740991'::bigint)),
    CONSTRAINT me_conversations_revision_check CHECK (((revision >= 0) AND (revision <= '9007199254740991'::bigint)))
);


--
-- Name: me_conversations_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.me_conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: me_conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.me_conversations_id_seq OWNED BY socialmei.me_conversations.id;


--
-- Name: me_documents; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_documents (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    title character varying(120) NOT NULL,
    content text NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '30 days'::interval) NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT me_documents_content_check CHECK ((octet_length(content) <= 32768)),
    CONSTRAINT me_documents_id_check CHECK ((id <= '9007199254740991'::bigint)),
    CONSTRAINT me_documents_revision_check CHECK (((revision >= 1) AND (revision <= '9007199254740991'::bigint)))
);


--
-- Name: me_documents_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.me_documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: me_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.me_documents_id_seq OWNED BY socialmei.me_documents.id;


--
-- Name: me_events; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_events (
    event_id uuid NOT NULL,
    job_id uuid NOT NULL,
    attempt integer NOT NULL,
    fingerprint character(64) NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT me_events_attempt_check CHECK (((attempt >= 1) AND (attempt <= 3)))
);


--
-- Name: me_external_messages; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_external_messages (
    workspace_id bigint NOT NULL,
    channel text NOT NULL,
    account_ref character varying(110) NOT NULL,
    external_message_id character varying(1024) NOT NULL,
    message_id bigint NOT NULL,
    origin text DEFAULT 'synthetic'::text NOT NULL,
    CONSTRAINT ck_me_external_origin CHECK ((((origin = 'synthetic'::text) AND ((account_ref)::text ~~ 'synthetic:%'::text) AND (length((external_message_id)::text) <= 120)) OR ((origin = 'instagram'::text) AND (channel = 'instagram'::text) AND ((account_ref)::text ~ '^instagram:[0-9]{1,40}$'::text) AND ((octet_length((external_message_id)::text) >= 1) AND (octet_length((external_message_id)::text) <= 1024)) AND ((external_message_id)::text ~ '^[!-~]+$'::text)) OR ((origin = 'waha'::text) AND (channel = 'whatsapp'::text) AND ((account_ref)::text ~ '^waha:[0-9]{1,40}@c[.]us$'::text) AND ((octet_length((external_message_id)::text) >= 1) AND (octet_length((external_message_id)::text) <= 1024)) AND ((external_message_id)::text ~ '^[!-~]+$'::text)))),
    CONSTRAINT me_external_messages_channel_check CHECK ((channel = ANY (ARRAY['whatsapp'::text, 'instagram'::text])))
);


--
-- Name: me_jobs; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_jobs (
    id uuid NOT NULL,
    workspace_id bigint NOT NULL,
    message_id bigint NOT NULL,
    message_revision bigint NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    attempt integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:05:00'::interval) NOT NULL,
    result jsonb,
    CONSTRAINT me_jobs_attempt_check CHECK (((attempt >= 1) AND (attempt <= 3))),
    CONSTRAINT me_jobs_result_check CHECK (((result IS NULL) OR (jsonb_typeof(result) = 'object'::text))),
    CONSTRAINT me_jobs_revision_check CHECK (((revision >= 1) AND (revision <= '9007199254740991'::bigint))),
    CONSTRAINT me_jobs_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'pending_review'::text, 'approved'::text, 'rejected'::text, 'invalidated'::text, 'expired'::text, 'superseded'::text])))
);


--
-- Name: me_limits; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_limits (
    workspace_id bigint NOT NULL,
    bucket timestamp with time zone DEFAULT now() NOT NULL,
    count integer NOT NULL,
    CONSTRAINT me_limits_count_check CHECK (((count >= 1) AND (count <= 60)))
);


--
-- Name: me_messages; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_messages (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    external_message_id character varying(1024) NOT NULL,
    fingerprint character(64) NOT NULL,
    conversation_revision bigint NOT NULL,
    text text NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    origin text DEFAULT 'synthetic'::text NOT NULL,
    CONSTRAINT ck_me_message_origin CHECK ((((origin = 'synthetic'::text) AND (length((external_message_id)::text) <= 120)) OR ((origin = ANY (ARRAY['instagram'::text, 'waha'::text])) AND ((octet_length((external_message_id)::text) >= 1) AND (octet_length((external_message_id)::text) <= 1024)) AND ((external_message_id)::text ~ '^[!-~]+$'::text)))),
    CONSTRAINT me_messages_conversation_revision_check CHECK (((conversation_revision >= 1) AND (conversation_revision <= '9007199254740991'::bigint))),
    CONSTRAINT me_messages_id_check CHECK ((id <= '9007199254740991'::bigint)),
    CONSTRAINT me_messages_revision_check CHECK (((revision >= 1) AND (revision <= '9007199254740991'::bigint))),
    CONSTRAINT me_messages_text_check CHECK ((octet_length(text) <= 8192))
);


--
-- Name: me_messages_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.me_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: me_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.me_messages_id_seq OWNED BY socialmei.me_messages.id;


--
-- Name: me_operations; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_operations (
    workspace_id bigint NOT NULL,
    kind text NOT NULL,
    operation_id uuid NOT NULL,
    fingerprint character(64) NOT NULL,
    response jsonb NOT NULL,
    CONSTRAINT me_operations_kind_check CHECK ((kind = ANY (ARRAY['message'::text, 'enrich'::text, 'document'::text]))),
    CONSTRAINT me_operations_response_check CHECK ((jsonb_typeof(response) = 'object'::text))
);


--
-- Name: me_provider_sentiment_jobs; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.me_provider_sentiment_jobs (
    workspace_id bigint NOT NULL,
    message_id bigint NOT NULL,
    claim_id uuid NOT NULL,
    attempt smallint DEFAULT 1 NOT NULL,
    status text DEFAULT 'processing'::text NOT NULL,
    lease_until timestamp with time zone NOT NULL,
    sentiment text,
    confidence text,
    explanation character varying(500),
    result_fingerprint character(64),
    completed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT me_provider_sentiment_jobs_attempt_check CHECK (((attempt >= 1) AND (attempt <= 3))),
    CONSTRAINT me_provider_sentiment_jobs_check CHECK ((((status = 'processing'::text) AND (sentiment IS NULL) AND (confidence IS NULL) AND (explanation IS NULL) AND (result_fingerprint IS NULL) AND (completed_at IS NULL)) OR ((status = 'completed'::text) AND (sentiment IS NOT NULL) AND (confidence IS NOT NULL) AND (explanation IS NOT NULL) AND (result_fingerprint IS NOT NULL) AND (completed_at IS NOT NULL)))),
    CONSTRAINT me_provider_sentiment_jobs_confidence_check CHECK ((confidence = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text]))),
    CONSTRAINT me_provider_sentiment_jobs_sentiment_check CHECK ((sentiment = ANY (ARRAY['positive'::text, 'negative'::text, 'neutral'::text, 'uncertain'::text]))),
    CONSTRAINT me_provider_sentiment_jobs_status_check CHECK ((status = ANY (ARRAY['processing'::text, 'completed'::text])))
);


--
-- Name: mensagens; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.mensagens (
    id bigint NOT NULL,
    conversa_id bigint NOT NULL,
    identificador_externo character varying(255),
    direcao character varying(10) DEFAULT 'entrada'::character varying NOT NULL,
    conteudo text NOT NULL,
    enviada_em timestamp with time zone DEFAULT now() NOT NULL,
    metadados jsonb DEFAULT '{}'::jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mensagens_direcao_check CHECK (((direcao)::text = ANY (ARRAY[('entrada'::character varying)::text, ('saida'::character varying)::text])))
);


--
-- Name: mensagens_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.mensagens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mensagens_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.mensagens_id_seq OWNED BY socialmei.mensagens.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.schema_migrations (
    version text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.users (
    id bigint NOT NULL,
    email character varying(255) NOT NULL,
    nome character varying(160) NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    telefone character varying(40)
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.users_id_seq OWNED BY socialmei.users.id;


--
-- Name: wa_bot_access; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.wa_bot_access (
    workspace_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    token_hash character(64) NOT NULL,
    binding_hash character(64) NOT NULL,
    issued_by bigint,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wa_bot_access_binding_hash_check CHECK ((binding_hash ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT wa_bot_access_token_hash_check CHECK ((token_hash ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: wa_bot_conversations; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.wa_bot_conversations (
    workspace_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    state text DEFAULT 'menu'::text NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    last_message_id bigint,
    last_occurred_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wa_bot_conversations_revision_check CHECK ((revision >= 0)),
    CONSTRAINT wa_bot_conversations_state_check CHECK ((state = ANY (ARRAY['menu'::text, 'ask_product'::text, 'human'::text])))
);


--
-- Name: wa_bot_decisions; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.wa_bot_decisions (
    id uuid NOT NULL,
    workspace_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    source_message_id bigint NOT NULL,
    binding_hash character(64) NOT NULL,
    state_revision bigint NOT NULL,
    result jsonb NOT NULL,
    status text NOT NULL,
    provider_message_id character varying(1024),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    claimed_at timestamp with time zone,
    finished_at timestamp with time zone,
    CONSTRAINT wa_bot_decisions_binding_hash_check CHECK ((binding_hash ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT wa_bot_decisions_check CHECK (((status = 'confirmed'::text) = (provider_message_id IS NOT NULL))),
    CONSTRAINT wa_bot_decisions_check1 CHECK (((status = ANY (ARRAY['claimed'::text, 'confirmed'::text, 'uncertain'::text])) = (claimed_at IS NOT NULL))),
    CONSTRAINT wa_bot_decisions_check2 CHECK (((status = ANY (ARRAY['confirmed'::text, 'uncertain'::text])) = (finished_at IS NOT NULL))),
    CONSTRAINT wa_bot_decisions_provider_message_id_check CHECK (((provider_message_id IS NULL) OR ((provider_message_id)::text ~ '^[!-~]+$'::text))),
    CONSTRAINT wa_bot_decisions_result_check CHECK (((jsonb_typeof(result) = 'object'::text) AND (octet_length((result)::text) <= 32768))),
    CONSTRAINT wa_bot_decisions_state_revision_check CHECK ((state_revision > 0)),
    CONSTRAINT wa_bot_decisions_status_check CHECK ((status = ANY (ARRAY['planned'::text, 'claimed'::text, 'confirmed'::text, 'uncertain'::text, 'skipped'::text])))
);


--
-- Name: wa_catalog_access; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.wa_catalog_access (
    workspace_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    instance character varying(80) NOT NULL,
    token_hash character(64) NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    issued_by bigint,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wa_catalog_access_token_hash_check CHECK ((token_hash ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: wa_human_replies; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.wa_human_replies (
    workspace_id bigint NOT NULL,
    id uuid NOT NULL,
    channel_id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    source_message_id bigint NOT NULL,
    binding_hash character(64) NOT NULL,
    fingerprint character(64) NOT NULL,
    text text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    created_by bigint,
    provider_message_id character varying(1024),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    claimed_at timestamp with time zone,
    finished_at timestamp with time zone,
    CONSTRAINT wa_human_replies_binding_hash_check CHECK ((binding_hash ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT wa_human_replies_check CHECK (((status = 'confirmed'::text) = (provider_message_id IS NOT NULL))),
    CONSTRAINT wa_human_replies_check1 CHECK (((status <> 'draft'::text) = (claimed_at IS NOT NULL))),
    CONSTRAINT wa_human_replies_check2 CHECK (((status = ANY (ARRAY['confirmed'::text, 'uncertain'::text])) = (finished_at IS NOT NULL))),
    CONSTRAINT wa_human_replies_fingerprint_check CHECK ((fingerprint ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT wa_human_replies_provider_message_id_check CHECK (((provider_message_id IS NULL) OR ((provider_message_id)::text ~ '^[!-~]+$'::text))),
    CONSTRAINT wa_human_replies_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'dispatching'::text, 'confirmed'::text, 'uncertain'::text]))),
    CONSTRAINT wa_human_replies_text_check CHECK (((octet_length(text) >= 1) AND (octet_length(text) <= 4096)))
);


--
-- Name: workspace_members; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.workspace_members (
    workspace_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role character varying(30) DEFAULT 'member'::character varying NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT workspace_members_role_check CHECK (((role)::text = ANY (ARRAY[('owner'::character varying)::text, ('admin'::character varying)::text, ('member'::character varying)::text, ('viewer'::character varying)::text, ('report_viewer'::character varying)::text])))
);


--
-- Name: workspace_profiles; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.workspace_profiles (
    workspace_id bigint NOT NULL,
    schema_version integer DEFAULT 1 NOT NULL,
    revision bigint DEFAULT 1 NOT NULL,
    profile jsonb NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT workspace_profiles_profile_check CHECK (((jsonb_typeof(profile) = 'object'::text) AND (profile ? 'version'::text) AND ((profile -> 'version'::text) = '1'::jsonb) AND (octet_length((profile)::text) <= 65536))),
    CONSTRAINT workspace_profiles_revision_check CHECK (((revision > 0) AND (revision <= '9007199254740991'::bigint))),
    CONSTRAINT workspace_profiles_schema_version_check CHECK ((schema_version = 1))
);


--
-- Name: workspaces; Type: TABLE; Schema: socialmei; Owner: -
--

CREATE TABLE socialmei.workspaces (
    id bigint NOT NULL,
    slug character varying(80) NOT NULL,
    nome character varying(160) NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    configuracao jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT workspaces_configuracao_check CHECK ((jsonb_typeof(configuracao) = 'object'::text))
);


--
-- Name: workspaces_id_seq; Type: SEQUENCE; Schema: socialmei; Owner: -
--

CREATE SEQUENCE socialmei.workspaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workspaces_id_seq; Type: SEQUENCE OWNED BY; Schema: socialmei; Owner: -
--

ALTER SEQUENCE socialmei.workspaces_id_seq OWNED BY socialmei.workspaces.id;


--
-- Name: auth_auditoria id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_auditoria ALTER COLUMN id SET DEFAULT nextval('socialmei.auth_auditoria_id_seq'::regclass);


--
-- Name: clientes id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.clientes ALTER COLUMN id SET DEFAULT nextval('socialmei.clientes_id_seq'::regclass);


--
-- Name: content_preparation_events id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.content_preparation_events ALTER COLUMN id SET DEFAULT nextval('socialmei.content_preparation_events_id_seq'::regclass);


--
-- Name: conversas id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.conversas ALTER COLUMN id SET DEFAULT nextval('socialmei.conversas_id_seq'::regclass);


--
-- Name: crm_canais id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_canais ALTER COLUMN id SET DEFAULT nextval('socialmei.crm_canais_id_seq'::regclass);


--
-- Name: crm_clientes id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_clientes ALTER COLUMN id SET DEFAULT nextval('socialmei.crm_clientes_id_seq'::regclass);


--
-- Name: crm_conversas_canal id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_conversas_canal ALTER COLUMN id SET DEFAULT nextval('socialmei.crm_conversas_canal_id_seq'::regclass);


--
-- Name: crm_eventos_canal id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_eventos_canal ALTER COLUMN id SET DEFAULT nextval('socialmei.crm_eventos_canal_id_seq'::regclass);


--
-- Name: crm_financeiro id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro ALTER COLUMN id SET DEFAULT nextval('socialmei.crm_financeiro_id_seq'::regclass);


--
-- Name: crm_mensagens_canal id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_mensagens_canal ALTER COLUMN id SET DEFAULT nextval('socialmei.crm_mensagens_canal_id_seq'::regclass);


--
-- Name: crm_opportunity_events id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunity_events ALTER COLUMN id SET DEFAULT nextval('socialmei.crm_opportunity_events_id_seq'::regclass);


--
-- Name: crm_produtos id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_produtos ALTER COLUMN id SET DEFAULT nextval('socialmei.crm_produtos_id_seq'::regclass);


--
-- Name: crm_vendas id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_vendas ALTER COLUMN id SET DEFAULT nextval('socialmei.crm_vendas_id_seq'::regclass);


--
-- Name: ig_direct_events id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_events ALTER COLUMN id SET DEFAULT nextval('socialmei.ig_direct_events_id_seq'::regclass);


--
-- Name: ig_meta_audit id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_audit ALTER COLUMN id SET DEFAULT nextval('socialmei.ig_meta_audit_id_seq'::regclass);


--
-- Name: me_conversations id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_conversations ALTER COLUMN id SET DEFAULT nextval('socialmei.me_conversations_id_seq'::regclass);


--
-- Name: me_documents id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_documents ALTER COLUMN id SET DEFAULT nextval('socialmei.me_documents_id_seq'::regclass);


--
-- Name: me_messages id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_messages ALTER COLUMN id SET DEFAULT nextval('socialmei.me_messages_id_seq'::regclass);


--
-- Name: mensagens id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.mensagens ALTER COLUMN id SET DEFAULT nextval('socialmei.mensagens_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.users ALTER COLUMN id SET DEFAULT nextval('socialmei.users_id_seq'::regclass);


--
-- Name: workspaces id; Type: DEFAULT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.workspaces ALTER COLUMN id SET DEFAULT nextval('socialmei.workspaces_id_seq'::regclass);


--
-- Name: agenda_appointment_history agenda_appointment_history_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_appointment_history
    ADD CONSTRAINT agenda_appointment_history_pkey PRIMARY KEY (workspace_id, appointment_id, revision);


--
-- Name: agenda_appointments agenda_appointments_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_appointments
    ADD CONSTRAINT agenda_appointments_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: agenda_reminders agenda_reminders_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_reminders
    ADD CONSTRAINT agenda_reminders_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: agenda_resources agenda_resources_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_resources
    ADD CONSTRAINT agenda_resources_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: auth_auditoria auth_auditoria_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_auditoria
    ADD CONSTRAINT auth_auditoria_pkey PRIMARY KEY (id);


--
-- Name: auth_convites auth_convites_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_convites
    ADD CONSTRAINT auth_convites_pkey PRIMARY KEY (token_hash);


--
-- Name: auth_credenciais auth_credenciais_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_credenciais
    ADD CONSTRAINT auth_credenciais_pkey PRIMARY KEY (user_id);


--
-- Name: auth_email_activation auth_email_activation_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_email_activation
    ADD CONSTRAINT auth_email_activation_pkey PRIMARY KEY (user_id);


--
-- Name: auth_identity_mail auth_identity_mail_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_identity_mail
    ADD CONSTRAINT auth_identity_mail_pkey PRIMARY KEY (id);


--
-- Name: auth_identity_mail auth_identity_mail_token_hash_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_identity_mail
    ADD CONSTRAINT auth_identity_mail_token_hash_key UNIQUE (token_hash);


--
-- Name: auth_limites auth_limites_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_limites
    ADD CONSTRAINT auth_limites_pkey PRIMARY KEY (chave);


--
-- Name: auth_preferences auth_preferences_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_preferences
    ADD CONSTRAINT auth_preferences_pkey PRIMARY KEY (workspace_id, user_id);


--
-- Name: auth_recuperacao_envios auth_recuperacao_envios_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_recuperacao_envios
    ADD CONSTRAINT auth_recuperacao_envios_pkey PRIMARY KEY (user_id);


--
-- Name: auth_recuperacoes auth_recuperacoes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_recuperacoes
    ADD CONSTRAINT auth_recuperacoes_pkey PRIMARY KEY (user_id);


--
-- Name: auth_recuperacoes auth_recuperacoes_token_hash_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_recuperacoes
    ADD CONSTRAINT auth_recuperacoes_token_hash_key UNIQUE (token_hash);


--
-- Name: auth_sessoes auth_sessoes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_sessoes
    ADD CONSTRAINT auth_sessoes_pkey PRIMARY KEY (token_hash);


--
-- Name: clientes clientes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.clientes
    ADD CONSTRAINT clientes_pkey PRIMARY KEY (id);


--
-- Name: content_preparation_events content_preparation_events_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.content_preparation_events
    ADD CONSTRAINT content_preparation_events_pkey PRIMARY KEY (id);


--
-- Name: content_preparation_jobs content_preparation_jobs_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.content_preparation_jobs
    ADD CONSTRAINT content_preparation_jobs_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: content_preparation_jobs content_preparation_jobs_workspace_id_idempotency_key_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.content_preparation_jobs
    ADD CONSTRAINT content_preparation_jobs_workspace_id_idempotency_key_key UNIQUE (workspace_id, idempotency_key);


--
-- Name: conversas conversas_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.conversas
    ADD CONSTRAINT conversas_pkey PRIMARY KEY (id);


--
-- Name: crm_canais crm_canais_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_canais
    ADD CONSTRAINT crm_canais_pkey PRIMARY KEY (id);


--
-- Name: crm_canais crm_canais_provedor_instancia_sessao_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_canais
    ADD CONSTRAINT crm_canais_provedor_instancia_sessao_key UNIQUE (provedor, instancia, sessao);


--
-- Name: crm_canais crm_canais_workspace_id_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_canais
    ADD CONSTRAINT crm_canais_workspace_id_id_key UNIQUE (workspace_id, id);


--
-- Name: crm_cliente_importacoes crm_cliente_importacoes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_cliente_importacoes
    ADD CONSTRAINT crm_cliente_importacoes_pkey PRIMARY KEY (workspace_id, origem, local_id);


--
-- Name: crm_clientes crm_clientes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_clientes
    ADD CONSTRAINT crm_clientes_pkey PRIMARY KEY (id);


--
-- Name: crm_conversas_canal crm_conversas_canal_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_conversas_canal
    ADD CONSTRAINT crm_conversas_canal_pkey PRIMARY KEY (id);


--
-- Name: crm_conversas_canal crm_conversas_canal_workspace_id_canal_id_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_conversas_canal
    ADD CONSTRAINT crm_conversas_canal_workspace_id_canal_id_id_key UNIQUE (workspace_id, canal_id, id);


--
-- Name: crm_conversas_canal crm_conversas_canal_workspace_id_canal_id_identificador_ext_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_conversas_canal
    ADD CONSTRAINT crm_conversas_canal_workspace_id_canal_id_identificador_ext_key UNIQUE (workspace_id, canal_id, identificador_externo);


--
-- Name: crm_eventos_canal crm_eventos_canal_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_eventos_canal
    ADD CONSTRAINT crm_eventos_canal_pkey PRIMARY KEY (id);


--
-- Name: crm_eventos_canal crm_eventos_canal_workspace_id_canal_id_chave_evento_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_eventos_canal
    ADD CONSTRAINT crm_eventos_canal_workspace_id_canal_id_chave_evento_key UNIQUE (workspace_id, canal_id, chave_evento);


--
-- Name: crm_financeiro_importacoes crm_financeiro_importacoes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro_importacoes
    ADD CONSTRAINT crm_financeiro_importacoes_pkey PRIMARY KEY (workspace_id, origem, local_id);


--
-- Name: crm_financeiro_operacoes crm_financeiro_operacoes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro_operacoes
    ADD CONSTRAINT crm_financeiro_operacoes_pkey PRIMARY KEY (workspace_id, operation_id);


--
-- Name: crm_financeiro crm_financeiro_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro
    ADD CONSTRAINT crm_financeiro_pkey PRIMARY KEY (id);


--
-- Name: crm_mensagens_canal crm_mensagens_canal_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_mensagens_canal
    ADD CONSTRAINT crm_mensagens_canal_pkey PRIMARY KEY (id);


--
-- Name: crm_mensagens_canal crm_mensagens_canal_workspace_id_canal_id_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_mensagens_canal
    ADD CONSTRAINT crm_mensagens_canal_workspace_id_canal_id_id_key UNIQUE (workspace_id, canal_id, id);


--
-- Name: crm_mensagens_canal crm_mensagens_canal_workspace_id_canal_id_identificador_ext_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_mensagens_canal
    ADD CONSTRAINT crm_mensagens_canal_workspace_id_canal_id_identificador_ext_key UNIQUE (workspace_id, canal_id, identificador_externo);


--
-- Name: crm_mensagens_canal crm_mensagens_canal_workspace_id_operation_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_mensagens_canal
    ADD CONSTRAINT crm_mensagens_canal_workspace_id_operation_id_key UNIQUE (workspace_id, operation_id);


--
-- Name: crm_opportunities crm_opportunities_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunities
    ADD CONSTRAINT crm_opportunities_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: crm_opportunity_events crm_opportunity_events_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunity_events
    ADD CONSTRAINT crm_opportunity_events_pkey PRIMARY KEY (id);


--
-- Name: crm_opportunity_operations crm_opportunity_operations_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunity_operations
    ADD CONSTRAINT crm_opportunity_operations_pkey PRIMARY KEY (workspace_id, operation_id);


--
-- Name: crm_produto_importacoes crm_produto_importacoes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_produto_importacoes
    ADD CONSTRAINT crm_produto_importacoes_pkey PRIMARY KEY (workspace_id, origem, local_id);


--
-- Name: crm_produtos crm_produtos_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_produtos
    ADD CONSTRAINT crm_produtos_pkey PRIMARY KEY (id);


--
-- Name: crm_transferencias crm_transferencias_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_transferencias
    ADD CONSTRAINT crm_transferencias_pkey PRIMARY KEY (workspace_id);


--
-- Name: crm_venda_importacoes crm_venda_importacoes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_venda_importacoes
    ADD CONSTRAINT crm_venda_importacoes_pkey PRIMARY KEY (workspace_id, origem, local_id);


--
-- Name: crm_venda_operacoes crm_venda_operacoes_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_venda_operacoes
    ADD CONSTRAINT crm_venda_operacoes_pkey PRIMARY KEY (workspace_id, operation_id);


--
-- Name: crm_vendas crm_vendas_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_vendas
    ADD CONSTRAINT crm_vendas_pkey PRIMARY KEY (id);


--
-- Name: ig_direct_attempts ig_direct_attempts_claim_token_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_attempts
    ADD CONSTRAINT ig_direct_attempts_claim_token_key UNIQUE (claim_token);


--
-- Name: ig_direct_attempts ig_direct_attempts_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_attempts
    ADD CONSTRAINT ig_direct_attempts_pkey PRIMARY KEY (workspace_id, job_id, attempt);


--
-- Name: ig_direct_events ig_direct_events_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_events
    ADD CONSTRAINT ig_direct_events_pkey PRIMARY KEY (id);


--
-- Name: ig_direct_jobs ig_direct_jobs_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_jobs
    ADD CONSTRAINT ig_direct_jobs_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: ig_direct_operations ig_direct_operations_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_operations
    ADD CONSTRAINT ig_direct_operations_pkey PRIMARY KEY (workspace_id, operation_id);


--
-- Name: ig_lab_connections ig_lab_connections_account_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_connections
    ADD CONSTRAINT ig_lab_connections_account_id_key UNIQUE (account_id);


--
-- Name: ig_lab_connections ig_lab_connections_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_connections
    ADD CONSTRAINT ig_lab_connections_pkey PRIMARY KEY (workspace_id);


--
-- Name: ig_lab_events ig_lab_events_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_events
    ADD CONSTRAINT ig_lab_events_pkey PRIMARY KEY (workspace_id, event_id);


--
-- Name: ig_lab_publications ig_lab_publications_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_publications
    ADD CONSTRAINT ig_lab_publications_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: ig_lab_publications ig_lab_publications_workspace_id_account_id_idempotency_key_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_publications
    ADD CONSTRAINT ig_lab_publications_workspace_id_account_id_idempotency_key_key UNIQUE (workspace_id, account_id, idempotency_key);


--
-- Name: ig_lab_states ig_lab_states_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_states
    ADD CONSTRAINT ig_lab_states_pkey PRIMARY KEY (state_hash);


--
-- Name: ig_menu_conversations ig_menu_conversations_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_conversations
    ADD CONSTRAINT ig_menu_conversations_pkey PRIMARY KEY (workspace_id, conversation_id);


--
-- Name: ig_menu_replies ig_menu_replies_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_replies
    ADD CONSTRAINT ig_menu_replies_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: ig_menu_replies ig_menu_replies_workspace_id_source_message_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_replies
    ADD CONSTRAINT ig_menu_replies_workspace_id_source_message_id_key UNIQUE (workspace_id, source_message_id);


--
-- Name: ig_meta_audit ig_meta_audit_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_audit
    ADD CONSTRAINT ig_meta_audit_pkey PRIMARY KEY (id);


--
-- Name: ig_meta_connections ig_meta_connections_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_connections
    ADD CONSTRAINT ig_meta_connections_pkey PRIMARY KEY (id);


--
-- Name: ig_meta_connections ig_meta_connections_workspace_id_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_connections
    ADD CONSTRAINT ig_meta_connections_workspace_id_id_key UNIQUE (workspace_id, id);


--
-- Name: ig_meta_ingress_events ig_meta_ingress_events_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_ingress_events
    ADD CONSTRAINT ig_meta_ingress_events_pkey PRIMARY KEY (external_account_id, event_key);


--
-- Name: ig_meta_media ig_meta_media_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_media
    ADD CONSTRAINT ig_meta_media_pkey PRIMARY KEY (id);


--
-- Name: ig_meta_media ig_meta_media_public_key_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_media
    ADD CONSTRAINT ig_meta_media_public_key_key UNIQUE (public_key);


--
-- Name: ig_meta_media ig_meta_media_workspace_id_request_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_media
    ADD CONSTRAINT ig_meta_media_workspace_id_request_id_key UNIQUE (workspace_id, request_id);


--
-- Name: ig_meta_oauth_states ig_meta_oauth_states_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_oauth_states
    ADD CONSTRAINT ig_meta_oauth_states_pkey PRIMARY KEY (state_hash);


--
-- Name: ig_meta_publications ig_meta_publications_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_publications
    ADD CONSTRAINT ig_meta_publications_pkey PRIMARY KEY (id);


--
-- Name: ig_meta_publications ig_meta_publications_workspace_id_request_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_publications
    ADD CONSTRAINT ig_meta_publications_workspace_id_request_id_key UNIQUE (workspace_id, request_id);


--
-- Name: instagram_sim_accounts instagram_sim_accounts_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.instagram_sim_accounts
    ADD CONSTRAINT instagram_sim_accounts_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: instagram_sim_publications instagram_sim_publications_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.instagram_sim_publications
    ADD CONSTRAINT instagram_sim_publications_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: instagram_sim_publications instagram_sim_publications_workspace_id_account_id_idempote_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.instagram_sim_publications
    ADD CONSTRAINT instagram_sim_publications_workspace_id_account_id_idempote_key UNIQUE (workspace_id, account_id, idempotency_key);


--
-- Name: integration_setup integration_setup_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.integration_setup
    ADD CONSTRAINT integration_setup_pkey PRIMARY KEY (workspace_id);


--
-- Name: kb_pdf_chunks kb_pdf_chunks_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.kb_pdf_chunks
    ADD CONSTRAINT kb_pdf_chunks_pkey PRIMARY KEY (workspace_id, document_id, ordinal);


--
-- Name: kb_pdf_documents kb_pdf_documents_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.kb_pdf_documents
    ADD CONSTRAINT kb_pdf_documents_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: kb_pdf_documents kb_pdf_documents_workspace_id_sha256_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.kb_pdf_documents
    ADD CONSTRAINT kb_pdf_documents_workspace_id_sha256_key UNIQUE (workspace_id, sha256);


--
-- Name: me_citations me_citations_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_citations
    ADD CONSTRAINT me_citations_pkey PRIMARY KEY (job_id, document_id);


--
-- Name: me_conversations me_conversations_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_conversations
    ADD CONSTRAINT me_conversations_pkey PRIMARY KEY (id);


--
-- Name: me_conversations me_conversations_workspace_id_channel_account_ref_contact_r_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_conversations
    ADD CONSTRAINT me_conversations_workspace_id_channel_account_ref_contact_r_key UNIQUE (workspace_id, channel, account_ref, contact_ref);


--
-- Name: me_conversations me_conversations_workspace_id_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_conversations
    ADD CONSTRAINT me_conversations_workspace_id_id_key UNIQUE (workspace_id, id);


--
-- Name: me_documents me_documents_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_documents
    ADD CONSTRAINT me_documents_pkey PRIMARY KEY (id);


--
-- Name: me_documents me_documents_workspace_id_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_documents
    ADD CONSTRAINT me_documents_workspace_id_id_key UNIQUE (workspace_id, id);


--
-- Name: me_events me_events_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_events
    ADD CONSTRAINT me_events_pkey PRIMARY KEY (event_id);


--
-- Name: me_external_messages me_external_messages_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_external_messages
    ADD CONSTRAINT me_external_messages_pkey PRIMARY KEY (workspace_id, channel, account_ref, external_message_id);


--
-- Name: me_external_messages me_external_messages_workspace_id_message_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_external_messages
    ADD CONSTRAINT me_external_messages_workspace_id_message_id_key UNIQUE (workspace_id, message_id);


--
-- Name: me_jobs me_jobs_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_jobs
    ADD CONSTRAINT me_jobs_pkey PRIMARY KEY (id);


--
-- Name: me_jobs me_jobs_workspace_id_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_jobs
    ADD CONSTRAINT me_jobs_workspace_id_id_key UNIQUE (workspace_id, id);


--
-- Name: me_limits me_limits_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_limits
    ADD CONSTRAINT me_limits_pkey PRIMARY KEY (workspace_id);


--
-- Name: me_messages me_messages_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_messages
    ADD CONSTRAINT me_messages_pkey PRIMARY KEY (id);


--
-- Name: me_messages me_messages_workspace_id_conversation_id_external_message_i_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_messages
    ADD CONSTRAINT me_messages_workspace_id_conversation_id_external_message_i_key UNIQUE (workspace_id, conversation_id, external_message_id);


--
-- Name: me_messages me_messages_workspace_id_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_messages
    ADD CONSTRAINT me_messages_workspace_id_id_key UNIQUE (workspace_id, id);


--
-- Name: me_operations me_operations_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_operations
    ADD CONSTRAINT me_operations_pkey PRIMARY KEY (workspace_id, kind, operation_id);


--
-- Name: me_provider_sentiment_jobs me_provider_sentiment_jobs_claim_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_provider_sentiment_jobs
    ADD CONSTRAINT me_provider_sentiment_jobs_claim_id_key UNIQUE (claim_id);


--
-- Name: me_provider_sentiment_jobs me_provider_sentiment_jobs_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_provider_sentiment_jobs
    ADD CONSTRAINT me_provider_sentiment_jobs_pkey PRIMARY KEY (workspace_id, message_id);


--
-- Name: mensagens mensagens_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.mensagens
    ADD CONSTRAINT mensagens_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wa_bot_access wa_bot_access_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_access
    ADD CONSTRAINT wa_bot_access_pkey PRIMARY KEY (workspace_id, channel_id);


--
-- Name: wa_bot_access wa_bot_access_token_hash_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_access
    ADD CONSTRAINT wa_bot_access_token_hash_key UNIQUE (token_hash);


--
-- Name: wa_bot_conversations wa_bot_conversations_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_conversations
    ADD CONSTRAINT wa_bot_conversations_pkey PRIMARY KEY (workspace_id, channel_id, conversation_id);


--
-- Name: wa_bot_decisions wa_bot_decisions_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_decisions
    ADD CONSTRAINT wa_bot_decisions_pkey PRIMARY KEY (id);


--
-- Name: wa_bot_decisions wa_bot_decisions_workspace_id_channel_id_source_message_id_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_decisions
    ADD CONSTRAINT wa_bot_decisions_workspace_id_channel_id_source_message_id_key UNIQUE (workspace_id, channel_id, source_message_id);


--
-- Name: wa_catalog_access wa_catalog_access_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_catalog_access
    ADD CONSTRAINT wa_catalog_access_pkey PRIMARY KEY (workspace_id, channel_id);


--
-- Name: wa_catalog_access wa_catalog_access_token_hash_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_catalog_access
    ADD CONSTRAINT wa_catalog_access_token_hash_key UNIQUE (token_hash);


--
-- Name: wa_human_replies wa_human_replies_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_human_replies
    ADD CONSTRAINT wa_human_replies_pkey PRIMARY KEY (workspace_id, id);


--
-- Name: workspace_members workspace_members_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.workspace_members
    ADD CONSTRAINT workspace_members_pkey PRIMARY KEY (workspace_id, user_id);


--
-- Name: workspace_profiles workspace_profiles_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.workspace_profiles
    ADD CONSTRAINT workspace_profiles_pkey PRIMARY KEY (workspace_id);


--
-- Name: workspaces workspaces_pkey; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);


--
-- Name: workspaces workspaces_slug_key; Type: CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.workspaces
    ADD CONSTRAINT workspaces_slug_key UNIQUE (slug);


--
-- Name: ig_meta_media_expiry; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ig_meta_media_expiry ON socialmei.ig_meta_media USING btree (expires_at);


--
-- Name: ig_meta_publications_workspace_recent; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ig_meta_publications_workspace_recent ON socialmei.ig_meta_publications USING btree (workspace_id, created_at DESC);


--
-- Name: ix_agenda_reminders_workspace_schedule; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_agenda_reminders_workspace_schedule ON socialmei.agenda_reminders USING btree (workspace_id, scheduled_for, id);


--
-- Name: ix_appointments_resource_schedule; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_appointments_resource_schedule ON socialmei.agenda_appointments USING btree (workspace_id, resource_id, scheduled_for, ends_at) WHERE (status <> 'cancelled'::text);


--
-- Name: ix_auth_recuperacao_envios_pending; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_auth_recuperacao_envios_pending ON socialmei.auth_recuperacao_envios USING btree (queued_at, user_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: ix_auth_sessoes_expira; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_auth_sessoes_expira ON socialmei.auth_sessoes USING btree (expira_em);


--
-- Name: ix_auth_sessoes_usuario; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_auth_sessoes_usuario ON socialmei.auth_sessoes USING btree (user_id);


--
-- Name: ix_content_preparation_due; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_content_preparation_due ON socialmei.content_preparation_jobs USING btree (workspace_id, run_after, id) WHERE ((status)::text = 'scheduled'::text);


--
-- Name: ix_content_preparation_history; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_content_preparation_history ON socialmei.content_preparation_jobs USING btree (workspace_id, created_at DESC, id);


--
-- Name: ix_conversas_cliente; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_conversas_cliente ON socialmei.conversas USING btree (cliente_id);


--
-- Name: ix_conversas_ultima_mensagem; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_conversas_ultima_mensagem ON socialmei.conversas USING btree (ultima_mensagem_em DESC);


--
-- Name: ix_crm_clientes_workspace; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_clientes_workspace ON socialmei.crm_clientes USING btree (workspace_id);


--
-- Name: ix_crm_clientes_workspace_nome; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_clientes_workspace_nome ON socialmei.crm_clientes USING btree (workspace_id, lower((nome)::text));


--
-- Name: ix_crm_conversas_canal_cliente; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_conversas_canal_cliente ON socialmei.crm_conversas_canal USING btree (workspace_id, cliente_id) WHERE (cliente_id IS NOT NULL);


--
-- Name: ix_crm_conversas_canal_ultima; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_conversas_canal_ultima ON socialmei.crm_conversas_canal USING btree (workspace_id, ultima_mensagem_em DESC, id);


--
-- Name: ix_crm_eventos_canal_pendentes; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_eventos_canal_pendentes ON socialmei.crm_eventos_canal USING btree (workspace_id, canal_id, recebido_em, id) WHERE ((status)::text = ANY (ARRAY[('recebido'::character varying)::text, ('falha'::character varying)::text]));


--
-- Name: ix_crm_financeiro_workspace_vencimento; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_financeiro_workspace_vencimento ON socialmei.crm_financeiro USING btree (workspace_id, vencimento DESC, id);


--
-- Name: ix_crm_mensagens_canal_conversa; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_mensagens_canal_conversa ON socialmei.crm_mensagens_canal USING btree (workspace_id, conversa_id, ocorrida_em, id);


--
-- Name: ix_crm_mensagens_canal_pendentes; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_mensagens_canal_pendentes ON socialmei.crm_mensagens_canal USING btree (workspace_id, status, criado_em, id) WHERE (((direcao)::text = 'saida'::text) AND ((status)::text = ANY (ARRAY[('pendente'::character varying)::text, ('incerta'::character varying)::text])));


--
-- Name: ix_crm_produtos_workspace_nome; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_produtos_workspace_nome ON socialmei.crm_produtos USING btree (workspace_id, lower((nome)::text));


--
-- Name: ix_crm_vendas_workspace_data; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_crm_vendas_workspace_data ON socialmei.crm_vendas USING btree (workspace_id, data DESC, id);


--
-- Name: ix_identity_mail_pending; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_identity_mail_pending ON socialmei.auth_identity_mail USING btree (created_at, id) WHERE ((status)::text = 'pending'::text);


--
-- Name: ix_ig_direct_jobs_workspace; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_ig_direct_jobs_workspace ON socialmei.ig_direct_jobs USING btree (workspace_id, created_at DESC, id);


--
-- Name: ix_ig_menu_conversation_history; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_ig_menu_conversation_history ON socialmei.ig_menu_replies USING btree (workspace_id, conversation_id, created_at DESC);


--
-- Name: ix_ig_meta_audit_workspace; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_ig_meta_audit_workspace ON socialmei.ig_meta_audit USING btree (workspace_id, created_at DESC, id);


--
-- Name: ix_ig_meta_connections_workspace_history; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_ig_meta_connections_workspace_history ON socialmei.ig_meta_connections USING btree (workspace_id, created_at DESC, id);


--
-- Name: ix_ig_meta_ingress_workspace; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_ig_meta_ingress_workspace ON socialmei.ig_meta_ingress_events USING btree (workspace_id, received_at DESC);


--
-- Name: ix_ig_meta_states_workspace; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_ig_meta_states_workspace ON socialmei.ig_meta_oauth_states USING btree (workspace_id, status);


--
-- Name: ix_instagram_sim_workspace_recent; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_instagram_sim_workspace_recent ON socialmei.instagram_sim_publications USING btree (workspace_id, created_at DESC);


--
-- Name: ix_kb_pdf_chunks_search; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_kb_pdf_chunks_search ON socialmei.kb_pdf_chunks USING gin (search_vector);


--
-- Name: ix_kb_pdf_documents_workspace; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_kb_pdf_documents_workspace ON socialmei.kb_pdf_documents USING btree (workspace_id, uploaded_at DESC);


--
-- Name: ix_me_conversation_customer; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_me_conversation_customer ON socialmei.me_conversations USING btree (workspace_id, cliente_id) WHERE (cliente_id IS NOT NULL);


--
-- Name: ix_me_documents_scope; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_me_documents_scope ON socialmei.me_documents USING btree (workspace_id, expires_at) WHERE (deleted_at IS NULL);


--
-- Name: ix_me_jobs_message; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_me_jobs_message ON socialmei.me_jobs USING btree (workspace_id, message_id, message_revision DESC);


--
-- Name: ix_me_provider_sentiment_pending; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_me_provider_sentiment_pending ON socialmei.me_provider_sentiment_jobs USING btree (status, lease_until) WHERE (status = 'processing'::text);


--
-- Name: ix_mensagens_conversa_enviada; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_mensagens_conversa_enviada ON socialmei.mensagens USING btree (conversa_id, enviada_em);


--
-- Name: ix_opportunity_history; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_opportunity_history ON socialmei.crm_opportunity_events USING btree (workspace_id, opportunity_id, id);


--
-- Name: ix_opportunity_list; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_opportunity_list ON socialmei.crm_opportunities USING btree (workspace_id, outcome, updated_at DESC, id);


--
-- Name: ix_wa_bot_history; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_wa_bot_history ON socialmei.wa_bot_decisions USING btree (workspace_id, channel_id, conversation_id, created_at DESC);


--
-- Name: ix_wa_catalog_instance_active; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_wa_catalog_instance_active ON socialmei.wa_catalog_access USING btree (instance) WHERE enabled;


--
-- Name: ix_wa_human_reply_history; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE INDEX ix_wa_human_reply_history ON socialmei.wa_human_replies USING btree (workspace_id, conversation_id, created_at DESC, id);


--
-- Name: ux_auth_convite_email_ativo; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_auth_convite_email_ativo ON socialmei.auth_convites USING btree (email) WHERE ((usado_em IS NULL) AND (revogado_em IS NULL));


--
-- Name: ux_auth_session_tenant_user; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_auth_session_tenant_user ON socialmei.auth_sessoes USING btree (token_hash, workspace_id, user_id);


--
-- Name: ux_auth_sessoes_public_id; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_auth_sessoes_public_id ON socialmei.auth_sessoes USING btree (public_id);


--
-- Name: ux_clientes_identificador_externo; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_clientes_identificador_externo ON socialmei.clientes USING btree (identificador_externo) WHERE (identificador_externo IS NOT NULL);


--
-- Name: ux_conversas_identificador_externo; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_conversas_identificador_externo ON socialmei.conversas USING btree (canal, identificador_externo) WHERE (identificador_externo IS NOT NULL);


--
-- Name: ux_crm_clientes_workspace_id; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_crm_clientes_workspace_id ON socialmei.crm_clientes USING btree (workspace_id, id);


--
-- Name: ux_crm_clientes_workspace_legacy_local; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_crm_clientes_workspace_legacy_local ON socialmei.crm_clientes USING btree (workspace_id, legacy_local_id) WHERE (legacy_local_id IS NOT NULL);


--
-- Name: ux_crm_finance_workspace_id; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_crm_finance_workspace_id ON socialmei.crm_financeiro USING btree (workspace_id, id);


--
-- Name: ux_crm_products_workspace_id; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_crm_products_workspace_id ON socialmei.crm_produtos USING btree (workspace_id, id);


--
-- Name: ux_crm_sales_workspace_id; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_crm_sales_workspace_id ON socialmei.crm_vendas USING btree (workspace_id, id);


--
-- Name: ux_identity_invitation_active; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_identity_invitation_active ON socialmei.auth_identity_mail USING btree (workspace_id, email) WHERE (((purpose)::text = 'invitation'::text) AND ((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'sent'::character varying])::text[])));


--
-- Name: ux_identity_verification_active; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_identity_verification_active ON socialmei.auth_identity_mail USING btree (user_id) WHERE (((purpose)::text = 'verification'::text) AND ((status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'sent'::character varying])::text[])));


--
-- Name: ux_ig_menu_provider_receipt; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_ig_menu_provider_receipt ON socialmei.ig_menu_replies USING btree (workspace_id, provider_message_id) WHERE (provider_message_id IS NOT NULL);


--
-- Name: ux_ig_meta_connected_account; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_ig_meta_connected_account ON socialmei.ig_meta_connections USING btree (external_account_id) WHERE (status = 'connected'::text);


--
-- Name: ux_ig_meta_connected_workspace; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_ig_meta_connected_workspace ON socialmei.ig_meta_connections USING btree (workspace_id) WHERE (status = 'connected'::text);


--
-- Name: ux_ig_meta_connection_account; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_ig_meta_connection_account ON socialmei.ig_meta_connections USING btree (workspace_id, id, external_account_id);


--
-- Name: ux_me_conversation_origin; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_me_conversation_origin ON socialmei.me_conversations USING btree (workspace_id, id, origin);


--
-- Name: ux_me_message_origin; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_me_message_origin ON socialmei.me_messages USING btree (workspace_id, id, origin);


--
-- Name: ux_mensagens_identificador_externo; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_mensagens_identificador_externo ON socialmei.mensagens USING btree (identificador_externo) WHERE (identificador_externo IS NOT NULL);


--
-- Name: ux_opportunity_sale; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_opportunity_sale ON socialmei.crm_opportunities USING btree (workspace_id, sale_id) WHERE (sale_id IS NOT NULL);


--
-- Name: ux_users_email_normalizado; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_users_email_normalizado ON socialmei.users USING btree (lower(btrim((email)::text)));


--
-- Name: ux_wa_bot_provider_receipt; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_wa_bot_provider_receipt ON socialmei.wa_bot_decisions USING btree (workspace_id, channel_id, provider_message_id) WHERE (provider_message_id IS NOT NULL);


--
-- Name: ux_wa_human_provider_receipt; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_wa_human_provider_receipt ON socialmei.wa_human_replies USING btree (workspace_id, channel_id, provider_message_id) WHERE (provider_message_id IS NOT NULL);


--
-- Name: ux_waha_active_account; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_waha_active_account ON socialmei.crm_canais USING btree (identificador_conta) WHERE (ingress_provisioned AND ativo);


--
-- Name: ux_waha_channel_account; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_waha_channel_account ON socialmei.crm_canais USING btree (workspace_id, id, identificador_conta);


--
-- Name: ux_waha_ingress_global; Type: INDEX; Schema: socialmei; Owner: -
--

CREATE UNIQUE INDEX ux_waha_ingress_global ON socialmei.crm_eventos_canal USING btree (waha_account_snapshot, waha_event_key) WHERE (waha_event_key IS NOT NULL);


--
-- Name: me_conversations trg_me_customer_link_revision; Type: TRIGGER; Schema: socialmei; Owner: -
--

CREATE TRIGGER trg_me_customer_link_revision BEFORE UPDATE OF cliente_id ON socialmei.me_conversations FOR EACH ROW EXECUTE FUNCTION socialmei.me_customer_link_revision();


--
-- Name: agenda_appointment_history agenda_appointment_history_workspace_id_appointment_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_appointment_history
    ADD CONSTRAINT agenda_appointment_history_workspace_id_appointment_id_fkey FOREIGN KEY (workspace_id, appointment_id) REFERENCES socialmei.agenda_appointments(workspace_id, id) ON DELETE CASCADE;


--
-- Name: agenda_appointments agenda_appointments_workspace_id_cliente_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_appointments
    ADD CONSTRAINT agenda_appointments_workspace_id_cliente_id_fkey FOREIGN KEY (workspace_id, cliente_id) REFERENCES socialmei.crm_clientes(workspace_id, id) ON DELETE SET NULL (cliente_id);


--
-- Name: agenda_appointments agenda_appointments_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_appointments
    ADD CONSTRAINT agenda_appointments_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: agenda_appointments agenda_appointments_workspace_id_resource_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_appointments
    ADD CONSTRAINT agenda_appointments_workspace_id_resource_id_fkey FOREIGN KEY (workspace_id, resource_id) REFERENCES socialmei.agenda_resources(workspace_id, id);


--
-- Name: agenda_appointments agenda_appointments_workspace_id_servico_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_appointments
    ADD CONSTRAINT agenda_appointments_workspace_id_servico_id_fkey FOREIGN KEY (workspace_id, servico_id) REFERENCES socialmei.crm_produtos(workspace_id, id) ON DELETE SET NULL (servico_id);


--
-- Name: agenda_reminders agenda_reminders_workspace_id_cliente_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_reminders
    ADD CONSTRAINT agenda_reminders_workspace_id_cliente_id_fkey FOREIGN KEY (workspace_id, cliente_id) REFERENCES socialmei.crm_clientes(workspace_id, id) ON DELETE SET NULL (cliente_id);


--
-- Name: agenda_reminders agenda_reminders_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_reminders
    ADD CONSTRAINT agenda_reminders_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: agenda_resources agenda_resources_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.agenda_resources
    ADD CONSTRAINT agenda_resources_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: auth_auditoria auth_auditoria_alvo_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_auditoria
    ADD CONSTRAINT auth_auditoria_alvo_user_id_fkey FOREIGN KEY (alvo_user_id) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: auth_auditoria auth_auditoria_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_auditoria
    ADD CONSTRAINT auth_auditoria_user_id_fkey FOREIGN KEY (user_id) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: auth_convites auth_convites_criado_por_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_convites
    ADD CONSTRAINT auth_convites_criado_por_fkey FOREIGN KEY (criado_por) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: auth_convites auth_convites_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_convites
    ADD CONSTRAINT auth_convites_user_id_fkey FOREIGN KEY (user_id) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: auth_credenciais auth_credenciais_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_credenciais
    ADD CONSTRAINT auth_credenciais_user_id_fkey FOREIGN KEY (user_id) REFERENCES socialmei.users(id) ON DELETE CASCADE;


--
-- Name: auth_email_activation auth_email_activation_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_email_activation
    ADD CONSTRAINT auth_email_activation_user_id_fkey FOREIGN KEY (user_id) REFERENCES socialmei.users(id) ON DELETE CASCADE;


--
-- Name: auth_identity_mail auth_identity_mail_created_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_identity_mail
    ADD CONSTRAINT auth_identity_mail_created_by_fkey FOREIGN KEY (created_by) REFERENCES socialmei.users(id) ON DELETE CASCADE;


--
-- Name: auth_identity_mail auth_identity_mail_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_identity_mail
    ADD CONSTRAINT auth_identity_mail_user_id_fkey FOREIGN KEY (user_id) REFERENCES socialmei.users(id) ON DELETE CASCADE;


--
-- Name: auth_identity_mail auth_identity_mail_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_identity_mail
    ADD CONSTRAINT auth_identity_mail_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: auth_preferences auth_preferences_workspace_id_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_preferences
    ADD CONSTRAINT auth_preferences_workspace_id_user_id_fkey FOREIGN KEY (workspace_id, user_id) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE CASCADE;


--
-- Name: auth_recuperacao_envios auth_recuperacao_envios_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_recuperacao_envios
    ADD CONSTRAINT auth_recuperacao_envios_user_id_fkey FOREIGN KEY (user_id) REFERENCES socialmei.users(id) ON DELETE CASCADE;


--
-- Name: auth_recuperacoes auth_recuperacoes_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_recuperacoes
    ADD CONSTRAINT auth_recuperacoes_user_id_fkey FOREIGN KEY (user_id) REFERENCES socialmei.users(id) ON DELETE CASCADE;


--
-- Name: auth_sessoes auth_sessoes_workspace_id_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.auth_sessoes
    ADD CONSTRAINT auth_sessoes_workspace_id_user_id_fkey FOREIGN KEY (workspace_id, user_id) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE CASCADE;


--
-- Name: content_preparation_events content_preparation_events_workspace_id_job_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.content_preparation_events
    ADD CONSTRAINT content_preparation_events_workspace_id_job_id_fkey FOREIGN KEY (workspace_id, job_id) REFERENCES socialmei.content_preparation_jobs(workspace_id, id) ON DELETE CASCADE;


--
-- Name: content_preparation_jobs content_preparation_jobs_requested_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.content_preparation_jobs
    ADD CONSTRAINT content_preparation_jobs_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: content_preparation_jobs content_preparation_jobs_workspace_id_account_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.content_preparation_jobs
    ADD CONSTRAINT content_preparation_jobs_workspace_id_account_id_fkey FOREIGN KEY (workspace_id, account_id) REFERENCES socialmei.instagram_sim_accounts(workspace_id, id);


--
-- Name: content_preparation_jobs content_preparation_jobs_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.content_preparation_jobs
    ADD CONSTRAINT content_preparation_jobs_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: conversas conversas_cliente_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.conversas
    ADD CONSTRAINT conversas_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES socialmei.clientes(id) ON DELETE CASCADE;


--
-- Name: crm_canais crm_canais_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_canais
    ADD CONSTRAINT crm_canais_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE RESTRICT;


--
-- Name: crm_cliente_importacoes crm_cliente_importacoes_cliente_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_cliente_importacoes
    ADD CONSTRAINT crm_cliente_importacoes_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES socialmei.crm_clientes(id) ON DELETE SET NULL;


--
-- Name: crm_cliente_importacoes crm_cliente_importacoes_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_cliente_importacoes
    ADD CONSTRAINT crm_cliente_importacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_clientes crm_clientes_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_clientes
    ADD CONSTRAINT crm_clientes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_conversas_canal crm_conversas_canal_workspace_id_canal_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_conversas_canal
    ADD CONSTRAINT crm_conversas_canal_workspace_id_canal_id_fkey FOREIGN KEY (workspace_id, canal_id) REFERENCES socialmei.crm_canais(workspace_id, id) ON DELETE RESTRICT;


--
-- Name: crm_conversas_canal crm_conversas_canal_workspace_id_cliente_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_conversas_canal
    ADD CONSTRAINT crm_conversas_canal_workspace_id_cliente_id_fkey FOREIGN KEY (workspace_id, cliente_id) REFERENCES socialmei.crm_clientes(workspace_id, id) ON DELETE SET NULL (cliente_id);


--
-- Name: crm_eventos_canal crm_eventos_canal_workspace_id_canal_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_eventos_canal
    ADD CONSTRAINT crm_eventos_canal_workspace_id_canal_id_fkey FOREIGN KEY (workspace_id, canal_id) REFERENCES socialmei.crm_canais(workspace_id, id) ON DELETE RESTRICT;


--
-- Name: crm_eventos_canal crm_eventos_canal_workspace_id_canal_id_mensagem_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_eventos_canal
    ADD CONSTRAINT crm_eventos_canal_workspace_id_canal_id_mensagem_id_fkey FOREIGN KEY (workspace_id, canal_id, mensagem_id) REFERENCES socialmei.crm_mensagens_canal(workspace_id, canal_id, id) ON DELETE SET NULL (mensagem_id);


--
-- Name: crm_financeiro crm_financeiro_cliente_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro
    ADD CONSTRAINT crm_financeiro_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES socialmei.crm_clientes(id) ON DELETE SET NULL;


--
-- Name: crm_financeiro_importacoes crm_financeiro_importacoes_lancamento_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro_importacoes
    ADD CONSTRAINT crm_financeiro_importacoes_lancamento_id_fkey FOREIGN KEY (lancamento_id) REFERENCES socialmei.crm_financeiro(id);


--
-- Name: crm_financeiro_importacoes crm_financeiro_importacoes_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro_importacoes
    ADD CONSTRAINT crm_financeiro_importacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_financeiro_operacoes crm_financeiro_operacoes_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro_operacoes
    ADD CONSTRAINT crm_financeiro_operacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_financeiro crm_financeiro_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro
    ADD CONSTRAINT crm_financeiro_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_mensagens_canal crm_mensagens_canal_workspace_id_canal_id_conversa_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_mensagens_canal
    ADD CONSTRAINT crm_mensagens_canal_workspace_id_canal_id_conversa_id_fkey FOREIGN KEY (workspace_id, canal_id, conversa_id) REFERENCES socialmei.crm_conversas_canal(workspace_id, canal_id, id) ON DELETE RESTRICT;


--
-- Name: crm_opportunities crm_opportunities_created_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunities
    ADD CONSTRAINT crm_opportunities_created_by_fkey FOREIGN KEY (created_by) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: crm_opportunities crm_opportunities_workspace_id_client_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunities
    ADD CONSTRAINT crm_opportunities_workspace_id_client_id_fkey FOREIGN KEY (workspace_id, client_id) REFERENCES socialmei.crm_clientes(workspace_id, id);


--
-- Name: crm_opportunities crm_opportunities_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunities
    ADD CONSTRAINT crm_opportunities_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_opportunities crm_opportunities_workspace_id_sale_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunities
    ADD CONSTRAINT crm_opportunities_workspace_id_sale_id_fkey FOREIGN KEY (workspace_id, sale_id) REFERENCES socialmei.crm_vendas(workspace_id, id);


--
-- Name: crm_opportunity_events crm_opportunity_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunity_events
    ADD CONSTRAINT crm_opportunity_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: crm_opportunity_events crm_opportunity_events_workspace_id_opportunity_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunity_events
    ADD CONSTRAINT crm_opportunity_events_workspace_id_opportunity_id_fkey FOREIGN KEY (workspace_id, opportunity_id) REFERENCES socialmei.crm_opportunities(workspace_id, id) ON DELETE CASCADE;


--
-- Name: crm_opportunity_operations crm_opportunity_operations_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_opportunity_operations
    ADD CONSTRAINT crm_opportunity_operations_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_produto_importacoes crm_produto_importacoes_produto_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_produto_importacoes
    ADD CONSTRAINT crm_produto_importacoes_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES socialmei.crm_produtos(id) ON DELETE SET NULL;


--
-- Name: crm_produto_importacoes crm_produto_importacoes_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_produto_importacoes
    ADD CONSTRAINT crm_produto_importacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_produtos crm_produtos_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_produtos
    ADD CONSTRAINT crm_produtos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_transferencias crm_transferencias_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_transferencias
    ADD CONSTRAINT crm_transferencias_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_venda_importacoes crm_venda_importacoes_venda_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_venda_importacoes
    ADD CONSTRAINT crm_venda_importacoes_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES socialmei.crm_vendas(id);


--
-- Name: crm_venda_importacoes crm_venda_importacoes_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_venda_importacoes
    ADD CONSTRAINT crm_venda_importacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_venda_operacoes crm_venda_operacoes_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_venda_operacoes
    ADD CONSTRAINT crm_venda_operacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_vendas crm_vendas_cliente_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_vendas
    ADD CONSTRAINT crm_vendas_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES socialmei.crm_clientes(id) ON DELETE SET NULL;


--
-- Name: crm_vendas crm_vendas_produto_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_vendas
    ADD CONSTRAINT crm_vendas_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES socialmei.crm_produtos(id) ON DELETE SET NULL;


--
-- Name: crm_vendas crm_vendas_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_vendas
    ADD CONSTRAINT crm_vendas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: crm_cliente_importacoes fk_crm_customer_import_workspace; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_cliente_importacoes
    ADD CONSTRAINT fk_crm_customer_import_workspace FOREIGN KEY (workspace_id, cliente_id) REFERENCES socialmei.crm_clientes(workspace_id, id) ON DELETE SET NULL (cliente_id);


--
-- Name: crm_financeiro_importacoes fk_crm_finance_import_workspace; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro_importacoes
    ADD CONSTRAINT fk_crm_finance_import_workspace FOREIGN KEY (workspace_id, lancamento_id) REFERENCES socialmei.crm_financeiro(workspace_id, id);


--
-- Name: crm_financeiro fk_crm_finance_workspace_customer; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_financeiro
    ADD CONSTRAINT fk_crm_finance_workspace_customer FOREIGN KEY (workspace_id, cliente_id) REFERENCES socialmei.crm_clientes(workspace_id, id) ON DELETE SET NULL (cliente_id);


--
-- Name: crm_produto_importacoes fk_crm_product_import_workspace; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_produto_importacoes
    ADD CONSTRAINT fk_crm_product_import_workspace FOREIGN KEY (workspace_id, produto_id) REFERENCES socialmei.crm_produtos(workspace_id, id) ON DELETE SET NULL (produto_id);


--
-- Name: crm_venda_importacoes fk_crm_sale_import_workspace; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_venda_importacoes
    ADD CONSTRAINT fk_crm_sale_import_workspace FOREIGN KEY (workspace_id, venda_id) REFERENCES socialmei.crm_vendas(workspace_id, id);


--
-- Name: crm_vendas fk_crm_sales_workspace_customer; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_vendas
    ADD CONSTRAINT fk_crm_sales_workspace_customer FOREIGN KEY (workspace_id, cliente_id) REFERENCES socialmei.crm_clientes(workspace_id, id) ON DELETE SET NULL (cliente_id);


--
-- Name: crm_vendas fk_crm_sales_workspace_product; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_vendas
    ADD CONSTRAINT fk_crm_sales_workspace_product FOREIGN KEY (workspace_id, produto_id) REFERENCES socialmei.crm_produtos(workspace_id, id) ON DELETE SET NULL (produto_id);


--
-- Name: me_conversations fk_me_conversation_workspace_customer; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_conversations
    ADD CONSTRAINT fk_me_conversation_workspace_customer FOREIGN KEY (workspace_id, cliente_id) REFERENCES socialmei.crm_clientes(workspace_id, id) ON DELETE SET NULL (cliente_id);


--
-- Name: me_external_messages fk_me_external_origin; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_external_messages
    ADD CONSTRAINT fk_me_external_origin FOREIGN KEY (workspace_id, message_id, origin) REFERENCES socialmei.me_messages(workspace_id, id, origin) ON DELETE CASCADE;


--
-- Name: me_messages fk_me_message_origin; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_messages
    ADD CONSTRAINT fk_me_message_origin FOREIGN KEY (workspace_id, conversation_id, origin) REFERENCES socialmei.me_conversations(workspace_id, id, origin) ON DELETE CASCADE;


--
-- Name: crm_eventos_canal fk_waha_ingress_account; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_eventos_canal
    ADD CONSTRAINT fk_waha_ingress_account FOREIGN KEY (workspace_id, canal_id, waha_account_snapshot) REFERENCES socialmei.crm_canais(workspace_id, id, identificador_conta);


--
-- Name: crm_eventos_canal fk_waha_ingress_inbox; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.crm_eventos_canal
    ADD CONSTRAINT fk_waha_ingress_inbox FOREIGN KEY (workspace_id, inbox_message_id, inbox_origin) REFERENCES socialmei.me_messages(workspace_id, id, origin);


--
-- Name: ig_direct_attempts ig_direct_attempts_workspace_id_job_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_attempts
    ADD CONSTRAINT ig_direct_attempts_workspace_id_job_id_fkey FOREIGN KEY (workspace_id, job_id) REFERENCES socialmei.ig_direct_jobs(workspace_id, id) ON DELETE CASCADE;


--
-- Name: ig_direct_events ig_direct_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_events
    ADD CONSTRAINT ig_direct_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: ig_direct_events ig_direct_events_workspace_id_job_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_events
    ADD CONSTRAINT ig_direct_events_workspace_id_job_id_fkey FOREIGN KEY (workspace_id, job_id) REFERENCES socialmei.ig_direct_jobs(workspace_id, id) ON DELETE CASCADE;


--
-- Name: ig_direct_jobs ig_direct_jobs_workspace_id_approved_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_jobs
    ADD CONSTRAINT ig_direct_jobs_workspace_id_approved_by_fkey FOREIGN KEY (workspace_id, approved_by) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE SET NULL (approved_by);


--
-- Name: ig_direct_jobs ig_direct_jobs_workspace_id_connection_id_external_account_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_jobs
    ADD CONSTRAINT ig_direct_jobs_workspace_id_connection_id_external_account_fkey FOREIGN KEY (workspace_id, connection_id, external_account_id) REFERENCES socialmei.ig_meta_connections(workspace_id, id, external_account_id);


--
-- Name: ig_direct_jobs ig_direct_jobs_workspace_id_conversation_id_origin_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_jobs
    ADD CONSTRAINT ig_direct_jobs_workspace_id_conversation_id_origin_fkey FOREIGN KEY (workspace_id, conversation_id, origin) REFERENCES socialmei.me_conversations(workspace_id, id, origin);


--
-- Name: ig_direct_jobs ig_direct_jobs_workspace_id_created_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_jobs
    ADD CONSTRAINT ig_direct_jobs_workspace_id_created_by_fkey FOREIGN KEY (workspace_id, created_by) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE SET NULL (created_by);


--
-- Name: ig_direct_jobs ig_direct_jobs_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_jobs
    ADD CONSTRAINT ig_direct_jobs_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_direct_jobs ig_direct_jobs_workspace_id_source_message_id_origin_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_jobs
    ADD CONSTRAINT ig_direct_jobs_workspace_id_source_message_id_origin_fkey FOREIGN KEY (workspace_id, source_message_id, origin) REFERENCES socialmei.me_messages(workspace_id, id, origin);


--
-- Name: ig_direct_operations ig_direct_operations_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_direct_operations
    ADD CONSTRAINT ig_direct_operations_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_lab_connections ig_lab_connections_workspace_id_account_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_connections
    ADD CONSTRAINT ig_lab_connections_workspace_id_account_id_fkey FOREIGN KEY (workspace_id, account_id) REFERENCES socialmei.instagram_sim_accounts(workspace_id, id);


--
-- Name: ig_lab_connections ig_lab_connections_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_connections
    ADD CONSTRAINT ig_lab_connections_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_lab_events ig_lab_events_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_events
    ADD CONSTRAINT ig_lab_events_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_lab_publications ig_lab_publications_approved_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_publications
    ADD CONSTRAINT ig_lab_publications_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: ig_lab_publications ig_lab_publications_workspace_id_account_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_publications
    ADD CONSTRAINT ig_lab_publications_workspace_id_account_id_fkey FOREIGN KEY (workspace_id, account_id) REFERENCES socialmei.instagram_sim_accounts(workspace_id, id);


--
-- Name: ig_lab_publications ig_lab_publications_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_publications
    ADD CONSTRAINT ig_lab_publications_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_lab_states ig_lab_states_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_states
    ADD CONSTRAINT ig_lab_states_user_id_fkey FOREIGN KEY (user_id) REFERENCES socialmei.users(id) ON DELETE CASCADE;


--
-- Name: ig_lab_states ig_lab_states_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_lab_states
    ADD CONSTRAINT ig_lab_states_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_menu_conversations ig_menu_conversations_workspace_id_conversation_id_origin_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_conversations
    ADD CONSTRAINT ig_menu_conversations_workspace_id_conversation_id_origin_fkey FOREIGN KEY (workspace_id, conversation_id, origin) REFERENCES socialmei.me_conversations(workspace_id, id, origin);


--
-- Name: ig_menu_conversations ig_menu_conversations_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_conversations
    ADD CONSTRAINT ig_menu_conversations_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_menu_conversations ig_menu_conversations_workspace_id_last_message_id_origin_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_conversations
    ADD CONSTRAINT ig_menu_conversations_workspace_id_last_message_id_origin_fkey FOREIGN KEY (workspace_id, last_message_id, origin) REFERENCES socialmei.me_messages(workspace_id, id, origin);


--
-- Name: ig_menu_replies ig_menu_replies_workspace_id_connection_id_external_accoun_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_replies
    ADD CONSTRAINT ig_menu_replies_workspace_id_connection_id_external_accoun_fkey FOREIGN KEY (workspace_id, connection_id, external_account_id) REFERENCES socialmei.ig_meta_connections(workspace_id, id, external_account_id);


--
-- Name: ig_menu_replies ig_menu_replies_workspace_id_conversation_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_replies
    ADD CONSTRAINT ig_menu_replies_workspace_id_conversation_id_fkey FOREIGN KEY (workspace_id, conversation_id) REFERENCES socialmei.ig_menu_conversations(workspace_id, conversation_id) ON DELETE CASCADE;


--
-- Name: ig_menu_replies ig_menu_replies_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_replies
    ADD CONSTRAINT ig_menu_replies_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_menu_replies ig_menu_replies_workspace_id_source_message_id_origin_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_menu_replies
    ADD CONSTRAINT ig_menu_replies_workspace_id_source_message_id_origin_fkey FOREIGN KEY (workspace_id, source_message_id, origin) REFERENCES socialmei.me_messages(workspace_id, id, origin);


--
-- Name: ig_meta_audit ig_meta_audit_workspace_id_connection_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_audit
    ADD CONSTRAINT ig_meta_audit_workspace_id_connection_id_fkey FOREIGN KEY (workspace_id, connection_id) REFERENCES socialmei.ig_meta_connections(workspace_id, id);


--
-- Name: ig_meta_audit ig_meta_audit_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_audit
    ADD CONSTRAINT ig_meta_audit_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_meta_audit ig_meta_audit_workspace_id_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_audit
    ADD CONSTRAINT ig_meta_audit_workspace_id_user_id_fkey FOREIGN KEY (workspace_id, user_id) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE SET NULL (user_id);


--
-- Name: ig_meta_connections ig_meta_connections_workspace_id_created_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_connections
    ADD CONSTRAINT ig_meta_connections_workspace_id_created_by_fkey FOREIGN KEY (workspace_id, created_by) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE SET NULL (created_by);


--
-- Name: ig_meta_connections ig_meta_connections_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_connections
    ADD CONSTRAINT ig_meta_connections_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_meta_ingress_events ig_meta_ingress_events_workspace_id_connection_id_external_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_ingress_events
    ADD CONSTRAINT ig_meta_ingress_events_workspace_id_connection_id_external_fkey FOREIGN KEY (workspace_id, connection_id, external_account_id) REFERENCES socialmei.ig_meta_connections(workspace_id, id, external_account_id);


--
-- Name: ig_meta_ingress_events ig_meta_ingress_events_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_ingress_events
    ADD CONSTRAINT ig_meta_ingress_events_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_meta_ingress_events ig_meta_ingress_events_workspace_id_message_id_message_ori_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_ingress_events
    ADD CONSTRAINT ig_meta_ingress_events_workspace_id_message_id_message_ori_fkey FOREIGN KEY (workspace_id, message_id, message_origin) REFERENCES socialmei.me_messages(workspace_id, id, origin);


--
-- Name: ig_meta_media ig_meta_media_created_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_media
    ADD CONSTRAINT ig_meta_media_created_by_fkey FOREIGN KEY (created_by) REFERENCES socialmei.users(id);


--
-- Name: ig_meta_media ig_meta_media_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_media
    ADD CONSTRAINT ig_meta_media_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id);


--
-- Name: ig_meta_oauth_states ig_meta_oauth_states_session_hash_workspace_id_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_oauth_states
    ADD CONSTRAINT ig_meta_oauth_states_session_hash_workspace_id_user_id_fkey FOREIGN KEY (session_hash, workspace_id, user_id) REFERENCES socialmei.auth_sessoes(token_hash, workspace_id, user_id) ON DELETE CASCADE;


--
-- Name: ig_meta_oauth_states ig_meta_oauth_states_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_oauth_states
    ADD CONSTRAINT ig_meta_oauth_states_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: ig_meta_publications ig_meta_publications_connection_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_publications
    ADD CONSTRAINT ig_meta_publications_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES socialmei.ig_meta_connections(id);


--
-- Name: ig_meta_publications ig_meta_publications_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.ig_meta_publications
    ADD CONSTRAINT ig_meta_publications_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id);


--
-- Name: instagram_sim_accounts instagram_sim_accounts_created_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.instagram_sim_accounts
    ADD CONSTRAINT instagram_sim_accounts_created_by_fkey FOREIGN KEY (created_by) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: instagram_sim_accounts instagram_sim_accounts_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.instagram_sim_accounts
    ADD CONSTRAINT instagram_sim_accounts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: instagram_sim_publications instagram_sim_publications_requested_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.instagram_sim_publications
    ADD CONSTRAINT instagram_sim_publications_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES socialmei.users(id) ON DELETE SET NULL;


--
-- Name: instagram_sim_publications instagram_sim_publications_workspace_id_account_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.instagram_sim_publications
    ADD CONSTRAINT instagram_sim_publications_workspace_id_account_id_fkey FOREIGN KEY (workspace_id, account_id) REFERENCES socialmei.instagram_sim_accounts(workspace_id, id);


--
-- Name: instagram_sim_publications instagram_sim_publications_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.instagram_sim_publications
    ADD CONSTRAINT instagram_sim_publications_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: integration_setup integration_setup_updated_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.integration_setup
    ADD CONSTRAINT integration_setup_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES socialmei.users(id);


--
-- Name: integration_setup integration_setup_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.integration_setup
    ADD CONSTRAINT integration_setup_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: kb_pdf_chunks kb_pdf_chunks_workspace_id_document_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.kb_pdf_chunks
    ADD CONSTRAINT kb_pdf_chunks_workspace_id_document_id_fkey FOREIGN KEY (workspace_id, document_id) REFERENCES socialmei.kb_pdf_documents(workspace_id, id) ON DELETE CASCADE;


--
-- Name: kb_pdf_documents kb_pdf_documents_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.kb_pdf_documents
    ADD CONSTRAINT kb_pdf_documents_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: kb_pdf_documents kb_pdf_documents_workspace_id_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.kb_pdf_documents
    ADD CONSTRAINT kb_pdf_documents_workspace_id_uploaded_by_fkey FOREIGN KEY (workspace_id, uploaded_by) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE SET NULL (uploaded_by);


--
-- Name: me_citations me_citations_workspace_id_document_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_citations
    ADD CONSTRAINT me_citations_workspace_id_document_id_fkey FOREIGN KEY (workspace_id, document_id) REFERENCES socialmei.me_documents(workspace_id, id) ON DELETE CASCADE;


--
-- Name: me_citations me_citations_workspace_id_job_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_citations
    ADD CONSTRAINT me_citations_workspace_id_job_id_fkey FOREIGN KEY (workspace_id, job_id) REFERENCES socialmei.me_jobs(workspace_id, id) ON DELETE CASCADE;


--
-- Name: me_conversations me_conversations_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_conversations
    ADD CONSTRAINT me_conversations_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: me_documents me_documents_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_documents
    ADD CONSTRAINT me_documents_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: me_events me_events_job_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_events
    ADD CONSTRAINT me_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES socialmei.me_jobs(id) ON DELETE CASCADE;


--
-- Name: me_external_messages me_external_messages_workspace_id_message_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_external_messages
    ADD CONSTRAINT me_external_messages_workspace_id_message_id_fkey FOREIGN KEY (workspace_id, message_id) REFERENCES socialmei.me_messages(workspace_id, id) ON DELETE CASCADE;


--
-- Name: me_jobs me_jobs_workspace_id_message_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_jobs
    ADD CONSTRAINT me_jobs_workspace_id_message_id_fkey FOREIGN KEY (workspace_id, message_id) REFERENCES socialmei.me_messages(workspace_id, id) ON DELETE CASCADE;


--
-- Name: me_limits me_limits_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_limits
    ADD CONSTRAINT me_limits_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: me_messages me_messages_workspace_id_conversation_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_messages
    ADD CONSTRAINT me_messages_workspace_id_conversation_id_fkey FOREIGN KEY (workspace_id, conversation_id) REFERENCES socialmei.me_conversations(workspace_id, id) ON DELETE CASCADE;


--
-- Name: me_operations me_operations_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_operations
    ADD CONSTRAINT me_operations_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: me_provider_sentiment_jobs me_provider_sentiment_jobs_workspace_id_message_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.me_provider_sentiment_jobs
    ADD CONSTRAINT me_provider_sentiment_jobs_workspace_id_message_id_fkey FOREIGN KEY (workspace_id, message_id) REFERENCES socialmei.me_messages(workspace_id, id) ON DELETE CASCADE;


--
-- Name: mensagens mensagens_conversa_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.mensagens
    ADD CONSTRAINT mensagens_conversa_id_fkey FOREIGN KEY (conversa_id) REFERENCES socialmei.conversas(id) ON DELETE CASCADE;


--
-- Name: wa_bot_access wa_bot_access_workspace_id_channel_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_access
    ADD CONSTRAINT wa_bot_access_workspace_id_channel_id_fkey FOREIGN KEY (workspace_id, channel_id) REFERENCES socialmei.crm_canais(workspace_id, id) ON DELETE CASCADE;


--
-- Name: wa_bot_access wa_bot_access_workspace_id_issued_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_access
    ADD CONSTRAINT wa_bot_access_workspace_id_issued_by_fkey FOREIGN KEY (workspace_id, issued_by) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE SET NULL (issued_by);


--
-- Name: wa_bot_conversations wa_bot_conversations_workspace_id_channel_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_conversations
    ADD CONSTRAINT wa_bot_conversations_workspace_id_channel_id_fkey FOREIGN KEY (workspace_id, channel_id) REFERENCES socialmei.crm_canais(workspace_id, id) ON DELETE CASCADE;


--
-- Name: wa_bot_conversations wa_bot_conversations_workspace_id_conversation_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_conversations
    ADD CONSTRAINT wa_bot_conversations_workspace_id_conversation_id_fkey FOREIGN KEY (workspace_id, conversation_id) REFERENCES socialmei.me_conversations(workspace_id, id) ON DELETE CASCADE;


--
-- Name: wa_bot_conversations wa_bot_conversations_workspace_id_last_message_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_conversations
    ADD CONSTRAINT wa_bot_conversations_workspace_id_last_message_id_fkey FOREIGN KEY (workspace_id, last_message_id) REFERENCES socialmei.me_messages(workspace_id, id);


--
-- Name: wa_bot_decisions wa_bot_decisions_workspace_id_channel_id_conversation_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_decisions
    ADD CONSTRAINT wa_bot_decisions_workspace_id_channel_id_conversation_id_fkey FOREIGN KEY (workspace_id, channel_id, conversation_id) REFERENCES socialmei.wa_bot_conversations(workspace_id, channel_id, conversation_id);


--
-- Name: wa_bot_decisions wa_bot_decisions_workspace_id_source_message_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_bot_decisions
    ADD CONSTRAINT wa_bot_decisions_workspace_id_source_message_id_fkey FOREIGN KEY (workspace_id, source_message_id) REFERENCES socialmei.me_messages(workspace_id, id);


--
-- Name: wa_catalog_access wa_catalog_access_workspace_id_channel_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_catalog_access
    ADD CONSTRAINT wa_catalog_access_workspace_id_channel_id_fkey FOREIGN KEY (workspace_id, channel_id) REFERENCES socialmei.crm_canais(workspace_id, id) ON DELETE CASCADE;


--
-- Name: wa_catalog_access wa_catalog_access_workspace_id_issued_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_catalog_access
    ADD CONSTRAINT wa_catalog_access_workspace_id_issued_by_fkey FOREIGN KEY (workspace_id, issued_by) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE SET NULL (issued_by);


--
-- Name: wa_human_replies wa_human_replies_workspace_id_channel_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_human_replies
    ADD CONSTRAINT wa_human_replies_workspace_id_channel_id_fkey FOREIGN KEY (workspace_id, channel_id) REFERENCES socialmei.crm_canais(workspace_id, id) ON DELETE CASCADE;


--
-- Name: wa_human_replies wa_human_replies_workspace_id_conversation_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_human_replies
    ADD CONSTRAINT wa_human_replies_workspace_id_conversation_id_fkey FOREIGN KEY (workspace_id, conversation_id) REFERENCES socialmei.me_conversations(workspace_id, id) ON DELETE CASCADE;


--
-- Name: wa_human_replies wa_human_replies_workspace_id_created_by_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_human_replies
    ADD CONSTRAINT wa_human_replies_workspace_id_created_by_fkey FOREIGN KEY (workspace_id, created_by) REFERENCES socialmei.workspace_members(workspace_id, user_id) ON DELETE SET NULL (created_by);


--
-- Name: wa_human_replies wa_human_replies_workspace_id_source_message_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.wa_human_replies
    ADD CONSTRAINT wa_human_replies_workspace_id_source_message_id_fkey FOREIGN KEY (workspace_id, source_message_id) REFERENCES socialmei.me_messages(workspace_id, id) ON DELETE CASCADE;


--
-- Name: workspace_members workspace_members_user_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.workspace_members
    ADD CONSTRAINT workspace_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES socialmei.users(id) ON DELETE CASCADE;


--
-- Name: workspace_members workspace_members_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.workspace_members
    ADD CONSTRAINT workspace_members_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- Name: workspace_profiles workspace_profiles_workspace_id_fkey; Type: FK CONSTRAINT; Schema: socialmei; Owner: -
--

ALTER TABLE ONLY socialmei.workspace_profiles
    ADD CONSTRAINT workspace_profiles_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES socialmei.workspaces(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict WiV6jzjX076uKLhK6F0XIC4JXbx6LdOVDMDLsKUrJ1b606h1Qb0qQa90m8j7atH

