SELECT count(*) AS rows_in_snapshot
FROM lakehouse.silver.orders FOR VERSION AS OF 8254608032447525305;

SELECT count(*) AS rows_at_time
FROM lakehouse.silver.orders FOR TIMESTAMP AS OF TIMESTAMP '2026-10-11 23:30:00 UTC';

ALTER TABLE lakehouse.silver.orders EXECUTE rollback_to_snapshot(8254608032447525305);

SELECT count(*) AS rows_after_restore FROM lakehouse.silver.orders;

SELECT snapshot_id, committed_at, operation, is_current_ancestor
FROM lakehouse.silver."orders$history"
JOIN lakehouse.silver."orders$snapshots" USING (snapshot_id)
ORDER BY committed_at;
