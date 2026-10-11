CREATE SCHEMA IF NOT EXISTS lakehouse.bronze;

SET SESSION lakehouse.compression_codec = 'ZSTD';

CREATE TABLE IF NOT EXISTS lakehouse.bronze.customer WITH (format = 'PARQUET')
AS SELECT * FROM tpch.sf1.customer;

CREATE TABLE IF NOT EXISTS lakehouse.bronze.orders WITH (format = 'PARQUET')
AS SELECT * FROM tpch.sf1.orders;

CREATE TABLE IF NOT EXISTS lakehouse.bronze.lineitem WITH (format = 'PARQUET')
AS SELECT * FROM tpch.sf1.lineitem;

SELECT 'customer' AS tbl, (SELECT count(*) FROM lakehouse.bronze.customer) AS rows_cnt,
       (SELECT round(sum(file_size_in_bytes) / 1048576.0, 2) FROM lakehouse.bronze."customer$files") AS size_mb
UNION ALL
SELECT 'orders', (SELECT count(*) FROM lakehouse.bronze.orders),
       (SELECT round(sum(file_size_in_bytes) / 1048576.0, 2) FROM lakehouse.bronze."orders$files")
UNION ALL
SELECT 'lineitem', (SELECT count(*) FROM lakehouse.bronze.lineitem),
       (SELECT round(sum(file_size_in_bytes) / 1048576.0, 2) FROM lakehouse.bronze."lineitem$files");
