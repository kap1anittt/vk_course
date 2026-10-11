SELECT 'GZIP' AS codec,
  round(((SELECT sum(file_size_in_bytes) FROM lakehouse.bench_gzip."customer$files")
       + (SELECT sum(file_size_in_bytes) FROM lakehouse.bench_gzip."orders$files")
       + (SELECT sum(file_size_in_bytes) FROM lakehouse.bench_gzip."lineitem$files")) / 1048576.0, 2) AS bronze_size_mb,
  round((SELECT sum(file_size_in_bytes) FROM lakehouse.bench_gzip."lineitem$files") / 1048576.0, 2) AS lineitem_mb
UNION ALL
SELECT 'ZSTD' AS codec,
  round(((SELECT sum(file_size_in_bytes) FROM lakehouse.bench_zstd."customer$files")
       + (SELECT sum(file_size_in_bytes) FROM lakehouse.bench_zstd."orders$files")
       + (SELECT sum(file_size_in_bytes) FROM lakehouse.bench_zstd."lineitem$files")) / 1048576.0, 2) AS bronze_size_mb,
  round((SELECT sum(file_size_in_bytes) FROM lakehouse.bench_zstd."lineitem$files") / 1048576.0, 2) AS lineitem_mb
UNION ALL
SELECT 'SNAPPY' AS codec,
  round(((SELECT sum(file_size_in_bytes) FROM lakehouse.bench_snappy."customer$files")
       + (SELECT sum(file_size_in_bytes) FROM lakehouse.bench_snappy."orders$files")
       + (SELECT sum(file_size_in_bytes) FROM lakehouse.bench_snappy."lineitem$files")) / 1048576.0, 2) AS bronze_size_mb,
  round((SELECT sum(file_size_in_bytes) FROM lakehouse.bench_snappy."lineitem$files") / 1048576.0, 2) AS lineitem_mb;

SELECT upper(regexp_extract(query, 'bench_([a-z]+)\.', 1)) AS codec,
       regexp_extract(query, 'bench_[a-z]+\.([a-z]+)', 1) AS tbl,
       round(date_diff('millisecond', created, "end") / 1000.0, 2) AS write_sec
FROM system.runtime.queries
WHERE state = 'FINISHED' AND query LIKE 'CREATE TABLE lakehouse.bench_%'
ORDER BY codec, tbl;

SELECT upper(regexp_extract(query, 'bench_([a-z]+)\.', 1)) AS codec,
       count(*) AS runs,
       round(min(date_diff('millisecond', created, "end")) / 1000.0, 2) AS min_sec,
       round(approx_percentile(date_diff('millisecond', created, "end"), 0.5) / 1000.0, 2) AS median_sec,
       round(max(date_diff('millisecond', created, "end")) / 1000.0, 2) AS max_sec
FROM system.runtime.queries
WHERE state = 'FINISHED'
  AND query LIKE '%SELECT c.name%'
  AND query LIKE '%FROM lakehouse.bench_%'
  AND query NOT LIKE '%system.runtime.queries%'
GROUP BY 1
ORDER BY 1;
