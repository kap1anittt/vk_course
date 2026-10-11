SELECT snapshot_id, committed_at, operation
FROM lakehouse.silver."orders$snapshots"
ORDER BY committed_at;

SELECT count(*) AS rows_before FROM lakehouse.silver.orders;

DELETE FROM lakehouse.silver.orders WHERE order_year = 1998;

SELECT count(*) AS rows_after_delete FROM lakehouse.silver.orders;

SELECT snapshot_id, committed_at, operation
FROM lakehouse.silver."orders$snapshots"
ORDER BY committed_at;
