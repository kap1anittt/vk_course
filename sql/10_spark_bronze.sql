SHOW NAMESPACES IN lakehouse;

SHOW TABLES IN lakehouse.bronze;

SELECT 'customer' AS tbl, count(*) AS rows_cnt FROM lakehouse.bronze.customer
UNION ALL
SELECT 'orders', count(*) FROM lakehouse.bronze.orders
UNION ALL
SELECT 'lineitem', count(*) FROM lakehouse.bronze.lineitem;

SELECT snapshot_id, committed_at, operation
FROM lakehouse.bronze.lineitem.snapshots;

SELECT c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice, sum(l.quantity) AS total_quantity
FROM lakehouse.bronze.customer c
JOIN lakehouse.bronze.orders   o ON c.custkey = o.custkey
JOIN lakehouse.bronze.lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (SELECT orderkey FROM lakehouse.bronze.lineitem GROUP BY orderkey HAVING sum(quantity) > 300)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice
ORDER BY o.totalprice DESC, o.orderdate
LIMIT 10;
