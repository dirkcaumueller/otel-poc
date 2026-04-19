-- Always good to have
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- User for Open Telemetry collector
CREATE ROLE otel WITH LOGIN PASSWORD 'otel';
GRANT pg_monitor TO otel;

-- pgbackrest backup repository status
CREATE SCHEMA IF NOT EXISTS pgbackrest;
REVOKE ALL PRIVILEGES ON SCHEMA pgbackrest FROM PUBLIC;

CREATE TABLE IF NOT EXISTS pgbackrest.pgbackrest_info (
    data jsonb,
    update_ts timestamp with time zone DEFAULT now() NOT NULL
) WITH (
  autovacuum_vacuum_scale_factor = 0,
  autovacuum_vacuum_threshold = 2,
  autovacuum_analyze_scale_factor = 0,
  autovacuum_analyze_threshold = 2
);

CREATE OR REPLACE FUNCTION pgbackrest.pgbackrest_info()
  RETURNS jsonb AS $$
DECLARE
  v_data jsonb;
  v_last_updated timestamp with time zone;
  v_record_count int;
BEGIN

  SELECT count(*) INTO v_record_count
  FROM pgbackrest.pgbackrest_info;

  IF v_record_count > 0 THEN
  
    SELECT update_ts, data
    INTO v_last_updated, v_data
    FROM pgbackrest.pgbackrest_info
    ORDER BY update_ts DESC
    LIMIT 1;

    If pg_is_in_recovery() THEN
      RETURN v_data;
    END IF;

    IF v_last_updated >= now() - INTERVAL '5 minutes' THEN
      RETURN v_data;
    END IF;

    DELETE FROM pgbackrest.pgbackrest_info;

  END IF;

  COPY pgbackrest.pgbackrest_info (data)
  FROM PROGRAM 'pgbackrest --config=/etc/pgbackrest.conf --stanza=db --output=json info | tr ''\n'' '' ''' (format text);

  SELECT data
  INTO v_data
  FROM pgbackrest.pgbackrest_info;

  RETURN v_data;

END $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pgbackrest, pg_temp;

REVOKE ALL ON FUNCTION pgbackrest.pgbackrest_info() FROM PUBLIC;

GRANT USAGE ON SCHEMA pgbackrest TO otel;
GRANT EXECUTE ON FUNCTION pgbackrest.pgbackrest_info() TO otel;

-- Pgbouncer user and function
CREATE ROLE pgbouncer WITH LOGIN PASSWORD 'pgbouncer';

CREATE SCHEMA IF NOT EXISTS pgbouncer;
REVOKE ALL PRIVILEGES ON SCHEMA pgbouncer FROM public, pgbouncer;
GRANT USAGE ON SCHEMA pgbouncer TO pgbouncer;
ALTER ROLE pgbouncer SET search_path TO pgbouncer;

CREATE OR REPLACE FUNCTION pgbouncer.get_auth(username TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS
$$
  SELECT rolname::TEXT, rolpassword::TEXT
  FROM pg_authid
  WHERE NOT pg_authid.rolsuper
  AND NOT pg_authid.rolreplication
  AND pg_authid.rolcanlogin
  AND pg_authid.rolname <> 'pgbouncer'
  AND (   pg_authid.rolvaliduntil IS NULL
       OR pg_authid.rolvaliduntil >= current_timestamp)
  AND pg_authid.rolname = $1;
$$
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = pgbouncer,pg_catalog,pg_temp;

REVOKE ALL ON FUNCTION pgbouncer.get_auth(username TEXT) FROM public, pgbouncer;
GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(username TEXT) TO pgbouncer;

-- Activate PGAudit extension
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Testuser unprivileged
CREATE ROLE testuser WITH LOGIN PASSWORD 'testuser';

-- Testadmin
CREATE ROLE testadmin WITH LOGIN SUPERUSER PASSWORD 'testadmin'; 
ALTER ROLE testadmin SET pgaudit.log = 'ALL';
