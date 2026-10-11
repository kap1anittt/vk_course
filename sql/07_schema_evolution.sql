CREATE TABLE IF NOT EXISTS lakehouse.silver.orders_evo WITH (format = 'PARQUET') AS
SELECT * FROM lakehouse.silver.orders;

DESCRIBE lakehouse.silver.orders_evo;

ALTER TABLE lakehouse.silver.orders_evo ADD COLUMN order_priority varchar;

ALTER TABLE lakehouse.silver.orders_evo RENAME COLUMN totalprice TO total_price;

SELECT orderkey, custkey, total_price, order_priority
FROM lakehouse.silver.orders_evo
ORDER BY orderkey
LIMIT 5;

UPDATE lakehouse.silver.orders_evo
SET order_priority = 'HIGH'
WHERE total_price > 500000;

SELECT order_priority, count(*) AS cnt
FROM lakehouse.silver.orders_evo
GROUP BY order_priority;

DESCRIBE lakehouse.silver.orders_evo;

SELECT snapshot_id, committed_at, operation
FROM lakehouse.silver."orders_evo$snapshots"
ORDER BY committed_at;
