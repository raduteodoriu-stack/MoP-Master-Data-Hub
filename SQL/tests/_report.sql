-- Prints the results of one test file and fails it if any check failed.
-- Included at the end of every test file with \ir, before ROLLBACK.

\o
SELECT n AS "#", description, result, detail
FROM test_results
ORDER BY n;

DO $$
DECLARE
    total INTEGER;
    failed INTEGER;
BEGIN
    SELECT count(*), count(*) FILTER (WHERE result <> 'PASS') INTO total, failed FROM test_results;
    IF total = 0 THEN
        RAISE EXCEPTION 'No checks ran.';
    END IF;
    IF failed > 0 THEN
        RAISE EXCEPTION '% of % checks failed.', failed, total;
    END IF;
    RAISE NOTICE 'All % checks passed.', total;
END
$$;
