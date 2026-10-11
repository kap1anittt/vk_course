# Lakehouse: практическая работа №1

Пищулина Анна Ивановна. Вариант Q18, масштаб TPC-H sf1.

Стек: MinIO, PostgreSQL, Lakekeeper (Iceberg REST Catalog), Trino.

Отчёт: [REPORT.md](REPORT.md)

## Запуск

```bash
docker compose up -d
docker compose ps -a
docker exec -it trino trino --execute "SHOW CATALOGS"
```

## Слои и тесты

```bash
docker exec -it trino trino --output-format ALIGNED --file /sql/01_bronze.sql
docker exec -it trino trino --output-format ALIGNED --file /sql/02_silver.sql
docker exec -it trino trino --output-format ALIGNED --file /sql/03_gold.sql
docker exec -it trino trino --output-format ALIGNED --file /sql/04_check_q18.sql
docker exec -it trino trino --output-format ALIGNED --file /sql/05_benchmark.sql
```

| Файл | Что делает |
|---|---|
| sql/01_bronze.sql | Bronze: customer, orders, lineitem из tpch.sf1 как есть |
| sql/02_silver.sql | Silver: очистка, нужные колонки, крупные заказы |
| sql/03_gold.sql | Gold: витрина top_large_customers (ответ на Q18) |
| sql/04_check_q18.sql | Сверка витрины с эталонным Q18 |
| sql/05_benchmark.sql | Сравнение GZIP, ZSTD и SNAPPY на Bronze |
| sql/06_bench_results.sql | Только итоговые таблицы бенчмарка |
| sql/07_schema_evolution.sql | Добавление и переименование колонки на Silver |
| sql/08_time_travel.sql | Ошибочное удаление строк и просмотр снапшотов |
| sql/09_restore.sql | Восстановление таблицы из снапшота |
| sql/99_drop_bench.sql | Удаление таблиц бенчмарка перед повторным прогоном |

Веб-интерфейсы: MinIO http://localhost:9001 (minioadmin / minioadmin123), Trino http://localhost:8080.

Остановка: `docker compose stop`. Полный сброс с удалением данных: `docker compose down -v`.
