-- Shared set-up for the MDH-003 constraint tests. Included by every test file with \ir.
-- Everything here lives in the test's transaction and is rolled back at the end.
--
--   pg_temp.ok(n, description, statement [, run_as])         statement must succeed
--   pg_temp.fails(n, description, statement, expected [, run_as])
--       statement must fail; expected = the constraint name, or text found in the error
--   pg_temp.check(n, description, boolean_query [, run_as])  query must return true
--
-- run_as runs the statement as another database role (used for the access tests).
-- Results go to a temporary table; _report.sql prints them and fails the file if any failed.

DO $$
BEGIN
    IF current_database() <> 'mop_mdh' THEN
        RAISE EXCEPTION 'Connect to mop_mdh before running tests (now: %).', current_database();
    END IF;
END
$$;

CREATE TEMP TABLE test_results (
    n INTEGER PRIMARY KEY,
    description TEXT NOT NULL,
    result TEXT NOT NULL,
    detail TEXT
) ON COMMIT DROP;

CREATE FUNCTION pg_temp.ok(n INTEGER, description TEXT, stmt TEXT, run_as TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    m TEXT;
BEGIN
    BEGIN
        IF run_as IS NOT NULL THEN
            EXECUTE format('SET LOCAL ROLE %I', run_as);
        END IF;
        EXECUTE stmt;
        IF run_as IS NOT NULL THEN
            RESET ROLE;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS m = MESSAGE_TEXT;
        INSERT INTO test_results VALUES (n, description, 'FAIL', 'unexpected error: ' || m);
        RETURN;
    END;
    INSERT INTO test_results VALUES (n, description, 'PASS', 'accepted');
END
$$;

CREATE FUNCTION pg_temp.fails(n INTEGER, description TEXT, stmt TEXT, expected TEXT,
                              run_as TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    c TEXT;
    m TEXT;
    s TEXT;
BEGIN
    BEGIN
        IF run_as IS NOT NULL THEN
            EXECUTE format('SET LOCAL ROLE %I', run_as);
        END IF;
        EXECUTE stmt;
        -- No error: undo whatever the statement did, then report the failure.
        RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'statement was accepted';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS c = CONSTRAINT_NAME, m = MESSAGE_TEXT, s = RETURNED_SQLSTATE;
    END;
    IF s = 'P0099' THEN
        INSERT INTO test_results VALUES (n, description, 'FAIL', 'expected an error, but ' || m);
    ELSIF coalesce(c, '') = expected OR m ILIKE '%' || expected || '%' THEN
        INSERT INTO test_results VALUES (n, description, 'PASS', 'refused: ' || coalesce(nullif(c, ''), m));
    ELSE
        INSERT INTO test_results VALUES (n, description, 'FAIL',
            format('wrong error (expected %s): %s %s', expected, coalesce(c, ''), m));
    END IF;
END
$$;

CREATE FUNCTION pg_temp.check(n INTEGER, description TEXT, query TEXT, run_as TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    b BOOLEAN;
    m TEXT;
BEGIN
    BEGIN
        IF run_as IS NOT NULL THEN
            EXECUTE format('SET LOCAL ROLE %I', run_as);
        END IF;
        EXECUTE query INTO b;
        IF run_as IS NOT NULL THEN
            RESET ROLE;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS m = MESSAGE_TEXT;
        INSERT INTO test_results VALUES (n, description, 'FAIL', 'error: ' || m);
        RETURN;
    END;
    INSERT INTO test_results VALUES (n, description,
        CASE WHEN b THEN 'PASS' ELSE 'FAIL' END, CASE WHEN b THEN 'true' ELSE 'returned ' || coalesce(b::TEXT, 'null') END);
END
$$;

-- A stored source record with its own load batch. Returns the record ID.
CREATE FUNCTION pg_temp.make_record(p_system TEXT, p_key TEXT, p_payload JSONB)
RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE
    v_batch UUID;
    v_record UUID;
BEGIN
    INSERT INTO source.load_batches (system_code, file_name, file_sha256, extracted_at,
                                     rows_received, rows_stored, rows_unchanged, rows_rejected)
    VALUES (p_system, 'test_' || p_key || '.json',
            encode(sha256(convert_to(gen_random_uuid()::TEXT, 'UTF8')), 'hex'),
            '2026-11-02 08:00+01', 1, 1, 0, 0)
    RETURNING batch_id INTO v_batch;

    INSERT INTO source.source_records (system_code, source_key, record_version, content_sha256,
                                       payload, batch_id)
    VALUES (p_system, p_key,
            1 + coalesce((SELECT max(record_version) FROM source.source_records
                          WHERE system_code = p_system AND source_key = p_key), 0),
            encode(sha256(convert_to(p_payload::TEXT, 'UTF8')), 'hex'),
            p_payload, v_batch)
    RETURNING source_record_id INTO v_record;
    RETURN v_record;
END
$$;

-- Synthetic fixtures shared by the tests.
INSERT INTO config.rule_versions (rules_version, file_sha256, notes)
VALUES ('TEST-RULES', repeat('a', 64), 'Test fixture');

INSERT INTO config.staff (staff_id, full_name, email, department, sales_owner_id) VALUES
    ('ST-901', 'Test Steward', 'steward.test@mop-cloud.example', 'operations', NULL),
    ('ST-902', 'Test Finance Controller', 'finance.test@mop-cloud.example', 'finance', NULL),
    ('ST-903', 'Test Sales Director', 'sales.director.test@mop-cloud.example', 'sales', 'SM-09'),
    ('ST-904', 'Test SDR', 'sdr.test@mop-cloud.example', 'sales', 'ES-09'),
    ('ST-905', 'Test Account Executive', 'ae.test@mop-cloud.example', 'sales', 'AE-ES-09'),
    ('ST-906', 'Test DPO', 'dpo.test@mop-cloud.example', 'legal', NULL);
