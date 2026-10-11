CREATE SCHEMA IF NOT EXISTS lakehouse.gold;

SET SESSION lakehouse.compression_codec = 'ZSTD';

CREATE TABLE IF NOT EXISTS lakehouse.gold.top_large_customers WITH (format = 'PARQUET') AS
SELECT name, custkey, orderkey, orderdate, totalprice, total_quantity
FROM lakehouse.silver.large_order_details
ORDER BY totalprice DESC, orderdate
LIMIT 100;

SELECT count(*) AS rows_cnt,
       (SELECT round(sum(file_size_in_bytes) / 1048576.0, 4) FROM lakehouse.gold."top_large_customers$files") AS size_mb
FROM lakehouse.gold.top_large_customers;

SELECT * FROM lakehouse.gold.top_large_customers ORDER BY totalprice DESC, orderdate LIMIT 10;
