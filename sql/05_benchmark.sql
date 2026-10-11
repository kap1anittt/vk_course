CREATE SCHEMA IF NOT EXISTS lakehouse.bench_gzip;
SET SESSION lakehouse.compression_codec = 'GZIP';
CREATE TABLE lakehouse.bench_gzip.customer WITH (format = 'PARQUET') AS SELECT * FROM tpch.sf1.customer;
CREATE TABLE lakehouse.bench_gzip.orders WITH (format = 'PARQUET') AS SELECT * FROM tpch.sf1.orders;
CREATE TABLE lakehouse.bench_gzip.lineitem WITH (format = 'PARQUET') AS SELECT * FROM tpch.sf1.lineitem;

CREATE SCHEMA IF NOT EXISTS lakehouse.bench_zstd;
SET SESSION lakehouse.compression_codec = 'ZSTD';
CREATE TABLE lakehouse.bench_zstd.customer WITH (format = 'PARQUET') AS SELECT * FROM tpch.sf1.customer;
CREATE TABLE lakehouse.bench_zstd.orders WITH (format = 'PARQUET') AS SELECT * FROM tpch.sf1.orders;
CREATE TABLE lakehouse.bench_zstd.lineitem WITH (format = 'PARQUET') AS SELECT * FROM tpch.sf1.lineitem;

CREATE SCHEMA IF NOT EXISTS lakehouse.bench_snappy;
SET SESSION lakehouse.compression_codec = 'SNAPPY';
CREATE TABLE lakehouse.bench_snappy.customer WITH (format = 'PARQUET') AS SELECT * FROM tpch.sf1.customer;
CREATE TABLE lakehouse.bench_snappy.orders WITH (format = 'PARQUET') AS SELECT * FROM tpch.sf1.orders;
CREATE TABLE lakehouse.bench_snappy.lineitem WITH (format = 'PARQUET') AS SELECT * FROM tpch.sf1.lineitem;

SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bench_gzip.customer c JOIN lakehouse.bench_gzip.orders o ON c.custkey = o.custkey JOIN lakehouse.bench_gzip.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bench_gzip.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice ORDER BY o.totalprice DESC, o.orderdate LIMIT 100;
SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bench_gzip.customer c JOIN lakehouse.bench_gzip.orders o ON c.custkey = o.custkey JOIN lakehouse.bench_gzip.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bench_gzip.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice ORDER BY o.totalprice DESC, o.orderdate LIMIT 100;
SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bench_gzip.customer c JOIN lakehouse.bench_gzip.orders o ON c.custkey = o.custkey JOIN lakehouse.bench_gzip.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bench_gzip.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice ORDER BY o.totalprice DESC, o.orderdate LIMIT 100;

SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bench_zstd.customer c JOIN lakehouse.bench_zstd.orders o ON c.custkey = o.custkey JOIN lakehouse.bench_zstd.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bench_zstd.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice ORDER BY o.totalprice DESC, o.orderdate LIMIT 100;
SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bench_zstd.customer c JOIN lakehouse.bench_zstd.orders o ON c.custkey = o.custkey JOIN lakehouse.bench_zstd.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bench_zstd.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice ORDER BY o.totalprice DESC, o.orderdate LIMIT 100;
SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bench_zstd.customer c JOIN lakehouse.bench_zstd.orders o ON c.custkey = o.custkey JOIN lakehouse.bench_zstd.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bench_zstd.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice ORDER BY o.totalprice DESC, o.orderdate LIMIT 100;

SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bench_snappy.customer c JOIN lakehouse.bench_snappy.orders o ON c.custkey = o.custkey JOIN lakehouse.bench_snappy.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bench_snappy.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice ORDER BY o.totalprice DESC, o.orderdate LIMIT 100;
SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bench_snappy.customer c JOIN lakehouse.bench_snappy.orders o ON c.custkey = o.custkey JOIN lakehouse.bench_snappy.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bench_snappy.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice ORDER BY o.totalprice DESC, o.orderdate LIMIT 100;
SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bench_snappy.customer c JOIN lakehouse.bench_snappy.orders o ON c.custkey = o.custkey JOIN lakehouse.bench_snappy.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bench_snappy.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice ORDER BY o.totalprice DESC, o.orderdate LIMIT 100;

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
