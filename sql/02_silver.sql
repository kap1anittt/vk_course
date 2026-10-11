CREATE SCHEMA IF NOT EXISTS lakehouse.silver;

SET SESSION lakehouse.compression_codec = 'ZSTD';

CREATE TABLE IF NOT EXISTS lakehouse.silver.customer WITH (format = 'PARQUET') AS
SELECT custkey, trim(name) AS name
FROM lakehouse.bronze.customer
WHERE custkey IS NOT NULL;

CREATE TABLE IF NOT EXISTS lakehouse.silver.orders WITH (format = 'PARQUET') AS
SELECT orderkey, custkey, orderdate, totalprice, year(orderdate) AS order_year
FROM lakehouse.bronze.orders
WHERE orderkey IS NOT NULL AND custkey IS NOT NULL;

CREATE TABLE IF NOT EXISTS lakehouse.silver.large_orders WITH (format = 'PARQUET') AS
SELECT orderkey, sum(quantity) AS total_quantity
FROM lakehouse.bronze.lineitem
GROUP BY orderkey
HAVING sum(quantity) > 300;

CREATE TABLE IF NOT EXISTS lakehouse.silver.large_order_details WITH (format = 'PARQUET') AS
SELECT c.custkey, c.name, o.orderkey, o.orderdate, o.order_year, o.totalprice, lo.total_quantity
FROM lakehouse.silver.large_orders lo
JOIN lakehouse.silver.orders   o ON o.orderkey = lo.orderkey
JOIN lakehouse.silver.customer c ON c.custkey  = o.custkey;

SELECT 'customer' AS tbl, (SELECT count(*) FROM lakehouse.silver.customer) AS rows_cnt,
       (SELECT round(sum(file_size_in_bytes) / 1048576.0, 2) FROM lakehouse.silver."customer$files") AS size_mb
UNION ALL
SELECT 'orders', (SELECT count(*) FROM lakehouse.silver.orders),
       (SELECT round(sum(file_size_in_bytes) / 1048576.0, 2) FROM lakehouse.silver."orders$files")
UNION ALL
SELECT 'large_orders', (SELECT count(*) FROM lakehouse.silver.large_orders),
       (SELECT round(sum(file_size_in_bytes) / 1048576.0, 2) FROM lakehouse.silver."large_orders$files")
UNION ALL
SELECT 'large_order_details', (SELECT count(*) FROM lakehouse.silver.large_order_details),
       (SELECT round(sum(file_size_in_bytes) / 1048576.0, 2) FROM lakehouse.silver."large_order_details$files");
