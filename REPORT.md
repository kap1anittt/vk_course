# Отчёт по практической работе №1

## 1. Вариант и масштаб

| Поле | Значение |
|---|---|
| ФИО | Пищулина Анна Ивановна |
| Вариант (запрос) | Q18 |
| Масштаб `sfN` | sf1 |
| Почему выбрала такой масштаб | Работаю на MacBook Air M4 с 16 ГБ памяти, под Docker отдала 8 ГБ. На sf1 в lineitem около 6 млн строк. Этого достаточно, чтобы разница между кодеками сжатия была заметна и по размеру, и по времени записи. При этом все данные помещаются в память ноутбука, и запросы выполняются за секунды, а не за минуты. sf5 и выше на ноутбуке без активного охлаждения считались бы долго и упирались бы в память, а для сравнения кодеков ничего принципиально нового не дали бы. |

## 2. Поднятые сервисы и почему именно они

Что реально поднято (вывод `docker compose ps -a`):

```
NAME                   IMAGE                               STATUS
lakehouse-minio        chainguard/minio:latest             Up (healthy)
lakehouse-minio-init   chainguard/minio-client:latest      Exited (0)
lakehouse-pg           postgres:16                         Up (healthy)
lakekeeper             quay.io/lakekeeper/catalog:latest   Up
lakekeeper-init        curlimages/curl:latest              Exited (0)
lakekeeper-migrate     quay.io/lakekeeper/catalog:latest   Exited (0)
trino                  trinodb/trino:476                   Up (healthy)
```

| Сервис | Роль в стеке | Почему именно он |
|---|---|---|
| MinIO | S3-совместимое объектное хранилище, сюда физически пишутся parquet-файлы | Полностью совместим с S3 API, поэтому Trino и Lakekeeper работают с ним так же, как работали бы с облачным S3, и стек можно без переделок перенести в облако. Запускается одним контейнером, бесплатный, есть веб-консоль, в которой видно файлы таблиц. Официальный образ `minio/minio` удалён с Docker Hub, поэтому я взяла сборку того же MinIO от Chainguard. |
| PostgreSQL | База, в которой Lakekeeper хранит метаданные каталога | Lakekeeper поддерживает именно PostgreSQL. Это надёжная транзакционная СУБД: при параллельных коммитах в Iceberg-таблицу указатель на текущий снапшот меняется атомарно, и метаданные не ломаются. |
| Lakekeeper | Iceberg REST Catalog, каталог метаданных таблиц | Реализует открытый стандарт Iceberg REST Catalog, поэтому к нему может подключиться любой движок с поддержкой Iceberg: Trino, Spark, Flink, DuckDB. Написан на Rust, лёгкий, запускается одним контейнером. Hive Metastore тяжелее (Java, Hadoop-зависимости), а Nessie и Polaris для лабораторной избыточны. |
| Trino | SQL-движок: берёт метаданные у Lakekeeper, читает и пишет данные в MinIO | Есть встроенный коннектор TPC-H, поэтому данные не нужно генерировать и загружать отдельно. Хорошо поддерживает Iceberg: CTAS, выбор кодека сжатия, системные таблицы `$files` и `$snapshots`, time travel, schema evolution. Распределённый MPP-движок, который на одной машине работает быстро и без настройки. |
| minio-init, lakekeeper-migrate, lakekeeper-init | Одноразовые контейнеры: создают бакет, таблицы Lakekeeper в PostgreSQL и warehouse | Благодаря им весь стек поднимается одной командой `docker compose up -d`, без ручных действий в консолях. |

BI-инструмент не поднимала.

### Скрипты, которыми поднимала стек

Весь стек описан в [docker-compose.yml](docker-compose.yml), подключение Trino к каталогам лежит в [trino/catalog](trino/catalog).

```bash
docker compose up -d
docker compose ps -a
docker logs lakekeeper-init
docker exec -it trino trino --execute "SHOW CATALOGS"
```

- `docker compose up -d` поднимает MinIO и PostgreSQL. Затем создаётся бакет `lakehouse`, выполняются миграции Lakekeeper и стартует Lakekeeper. После этого через REST API создаётся warehouse `lakehouse` поверх бакета MinIO, и последним запускается Trino.
- `docker compose ps -a` показывает, что основные сервисы в статусе Up, а вспомогательные завершились с кодом 0.
- `docker logs lakekeeper-init` выводит JSON созданного warehouse с его `warehouse-id`.
- `SHOW CATALOGS` показывает, что в Trino видны каталоги `lakehouse` (Iceberg) и `tpch` (генератор).

Слои и тесты я запускала так:

```bash
docker exec -it trino trino --output-format ALIGNED --file /sql/01_bronze.sql
docker exec -it trino trino --output-format ALIGNED --file /sql/02_silver.sql
docker exec -it trino trino --output-format ALIGNED --file /sql/03_gold.sql
docker exec -it trino trino --output-format ALIGNED --file /sql/04_check_q18.sql
docker exec -it trino trino --output-format ALIGNED --file /sql/05_benchmark.sql
```

Что пришлось исправить при запуске:

1. Образы `minio/minio` и `minio/mc` больше не скачиваются (`pull access denied ... repository does not exist`), поэтому я заменила их на `chainguard/minio` и `chainguard/minio-client`.
2. В новом образе MinIO нет утилит `mc` и `curl`, поэтому healthcheck сделала через `bash` и `/dev/tcp`: он отправляет запрос на `/minio/health/live` и ждёт ответ 200.
3. В бенчмарке в статистике Q18 сначала было `runs = 2` вместо 3. Первый прогон каждого кодека начинался с комментария, а фильтр `LIKE 'SELECT c.name%'` его не находил. Фильтр я исправила.

## 3. Разбор запроса: какие данные нужны

Q18 (Large Volume Customer) ищет клиентов с крупными заказами, у которых суммарное количество товара в заказе больше 300. Выводит топ-100 таких заказов по сумме.

| Таблица TPC-H | Нужные колонки | Что запрос с ними делает |
|---|---|---|
| customer | custkey, name | custkey используется для джойна с orders, name выводится в результат и участвует в группировке |
| orders | orderkey, custkey, orderdate, totalprice | orderkey для джойна с lineitem и фильтра по подзапросу, custkey для джойна с customer, orderdate и totalprice выводятся и участвуют в сортировке (`totalprice DESC, orderdate`) |
| lineitem | orderkey, quantity | В подзапросе группировка по orderkey и фильтр `HAVING sum(quantity) > 300`, во внешнем запросе джойн по orderkey и агрегат `sum(quantity)` |

Из 8 колонок customer, 9 колонок orders и 16 колонок lineitem запросу нужно всего 8.

## 4. Медальон: решения по каждому слою

Вес считала по системной таблице `"<таблица>$files"` (сумма `file_size_in_bytes`), то есть это реальный размер parquet-файлов в MinIO.

### Bronze (сырой слой)

| Таблица | Колонки | Строк | Вес, МБ | Формат | Сжатие | Партиционирование | Обоснование |
|---|---|---|---|---|---|---|---|
| customer | все 8 | 150 000 | 7.8 | PARQUET | ZSTD | нет | Bronze хранит данные как есть, чтобы при ошибке на следующих слоях их можно было пересчитать без обращения к источнику. Parquet колоночный, поэтому Q18 читает только нужные колонки, хотя в таблице лежат все. ZSTD по бенчмарку почти не уступает GZIP в степени сжатия, но заметно быстрее. Партиционировать таблицу на 8 МБ бессмысленно, получились бы мелкие файлы. |
| orders | все 9 | 1 500 000 | 35.0 | PARQUET | ZSTD | нет | Аргументы те же. Можно было бы партиционировать по году orderdate, но Q18 по дате не фильтрует, поэтому отсечения партиций не было бы, а файлов стало бы в 7 раз больше. |
| lineitem | все 16 | 6 001 215 | 147.2 | PARQUET | ZSTD | нет | Самая большая таблица, на ней выбор кодека важнее всего. Q18 читает её целиком, потому что группирует по всем заказам, так что партиционирование не помогло бы. |

### Silver (очищенный слой)

| Таблица | Колонки | Строк | Вес, МБ | Формат | Сжатие | Партиционирование | Обоснование |
|---|---|---|---|---|---|---|---|
| customer | custkey, name (с trim) | 150 000 | 0.3 | PARQUET | ZSTD | нет | Оставила только те колонки, которые нужны Q18. Строки с пустым ключом отсеиваю, в name убираю лишние пробелы. Таблица уменьшилась с 7.8 до 0.3 МБ. |
| orders | orderkey, custkey, orderdate, totalprice, order_year | 1 500 000 | 13.5 | PARQUET | ZSTD | нет | Только нужные колонки плюс обогащение годом заказа для будущих разрезов в отчётах. Отсеиваю строки с пустыми ключами. Вес уменьшился с 35 до 13.5 МБ. |
| large_orders | orderkey, total_quantity | 57 | меньше 0.1 | PARQUET | ZSTD | нет | Подзапрос Q18 (заказы с суммой quantity больше 300) посчитан один раз и сохранён. Это самая тяжёлая часть запроса: группировка 6 млн строк lineitem. Дальше с ней работать уже не нужно. |
| large_order_details | custkey, name, orderkey, orderdate, order_year, totalprice, total_quantity | 57 | меньше 0.1 | PARQUET | ZSTD | нет | Джойн клиент, заказ и крупный заказ. Это уже готовые очищенные данные, из которых собирается витрина. |

### Gold (витрина)

| Таблица | Колонки | Строк | Вес, МБ | Формат | Сжатие | Партиционирование | Обоснование |
|---|---|---|---|---|---|---|---|
| top_large_customers | name, custkey, orderkey, orderdate, totalprice, total_quantity | 57 | меньше 0.1 | PARQUET | ZSTD | нет | Готовый ответ на Q18: колонки и сортировка такие же, как в эталонном запросе, лимит 100. На sf1 под условие подходит только 57 заказов, поэтому строк 57. Таблица маленькая, BI или аналитик читает её мгновенно. Партиционирование и выбор кодека здесь на скорость не влияют, ZSTD оставила для единообразия. |

Проверка корректности ([sql/04_check_q18.sql](sql/04_check_q18.sql)) сравнивает витрину с оригинальным Q18 на эталонных данных `tpch.sf1` через `EXCEPT` в обе стороны:

```
 reference_rows | gold_rows | missing_in_gold | extra_in_gold
----------------+-----------+-----------------+---------------
             57 |        57 |               0 |             0
```

Расхождений нет, витрина совпадает с эталоном.

Время выполнения самого Q18: на эталонных данных из генератора `tpch` запрос с проверкой шёл около 12.9 с. На Bronze в Iceberg он выполняется примерно за 2 с, а чтение готовой витрины Gold занимает доли секунды.

## 5. Тесты производительности

Bronze (customer, orders, lineitem) я пересоздала три раза с разными кодеками ([sql/05_benchmark.sql](sql/05_benchmark.sql)). Для каждого варианта Q18 запускался 3 раза, время бралось из `system.runtime.queries` ([sql/06_bench_results.sql](sql/06_bench_results.sql)).

| Сжатие на Bronze | Время Q18, медиана (мин – макс), с | Размер Bronze, МБ | из них lineitem, МБ | Время записи lineitem, с | Вывод |
|---|---|---|---|---|---|
| GZIP | 2.0 (1.2 – 2.4) | 184.8 | 143.7 | 28.3 | Самые компактные файлы, но запись самая медленная, на треть дольше ZSTD. Подходит для холодных архивных данных, которые пишутся один раз и читаются редко. |
| ZSTD | 2.0 (2.0 – 2.1) | 190.0 | 147.2 | 21.4 | Файлы всего на 3% больше, чем у GZIP, а запись заметно быстрее. Время запроса такое же, разброс самый маленький. Лучший баланс, поэтому его я и выбрала для всех слоёв. |
| SNAPPY | 2.3 (2.1 – 2.5) | 261.3 | 198.4 | 18.9 | Запись самая быстрая, но данные занимают на 40% больше места, а запрос даже немного медленнее, потому что из MinIO приходится читать больше байт. |

Время записи остальных таблиц, с:

| Кодек | customer | orders | lineitem |
|---|---|---|---|
| GZIP | 2.9 | 9.2 | 28.3 |
| ZSTD | 1.1 | 7.1 | 21.4 |
| SNAPPY | 1.3 | 6.2 | 18.9 |

На sf1 время запроса почти не зависит от кодека: данные маленькие, распаковка занимает доли секунды, и всё упирается в саму обработку джойнов и группировок. Разница по размеру хранения при этом заметная: SNAPPY на 40% больше ZSTD. На больших объёмах это напрямую означает деньги за хранилище и время чтения по сети.

## 6. Часть 2: осмысление и работа с инструментами

### 6.1. Понять и объяснить

| Вопрос | Мой ответ |
|---|---|
| Зачем нужны большие данные и lakehouse (а не обычная БД или хранилище)? | Обычная БД хранит данные на своих дисках в своём формате, и масштабировать её дорого: хранение и вычисления растут вместе. В lakehouse данные лежат в дешёвом объектном хранилище в открытом формате (Parquet + Iceberg), а движок подключается отдельно и масштабируется независимо. Одни и те же таблицы может читать Trino, Spark или BI, и данные никуда копировать не нужно. В отличие от простого data lake из файлов, Iceberg даёт то, что раньше было только в БД: транзакции, схему и её изменение, снапшоты и откат к прошлым версиям. В итоге получается дешёвое хранение озера и надёжность хранилища. |
| Пример schema evolution на Silver: добавила или переименовала колонку, что произошло? | Скрипт [sql/07_schema_evolution.sql](sql/07_schema_evolution.sql). Сделала копию `silver.orders_evo` (1 500 000 строк), добавила колонку `order_priority varchar` и переименовала `totalprice` в `total_price`. Обе операции выполнились мгновенно: Iceberg меняет только метаданные, parquet-файлы не переписываются. В старых строках новая колонка читается как NULL. Переименованная колонка читается со старыми значениями, потому что Iceberg связывает колонки по внутреннему id, а не по имени. Потом я заполнила новую колонку через `UPDATE ... SET order_priority = 'HIGH' WHERE total_price > 500000` (16 строк). В `$snapshots` появилось два снапшота, `append` (создание) и `overwrite` (UPDATE). Изменения схемы снапшотов не создают. |
| Пример скрипта восстановления данных из снапшота (time travel) | Скрипты [sql/08_time_travel.sql](sql/08_time_travel.sql) и [sql/09_restore.sql](sql/09_restore.sql). Сымитировала ошибку: удалила из `silver.orders` все заказы 1998 года (`DELETE`, 133 623 строки), осталось 1 366 377. В `$snapshots` появился снапшот `delete`. Затем через `FOR VERSION AS OF <snapshot_id>` и `FOR TIMESTAMP AS OF` убедилась, что старая версия на месте (1 500 000 строк), и откатила таблицу командой `ALTER TABLE lakehouse.silver.orders EXECUTE rollback_to_snapshot(<snapshot_id>)`. После отката снова 1 500 000 строк, а в `$history` снапшот с удалением помечен как `is_current_ancestor = false`. Важный нюанс: в `FOR VERSION AS OF` нельзя написать подзапрос, id снапшота нужно сначала посмотреть в `$snapshots` и подставить числом. |

Восстановление выглядит так:

```sql
SELECT snapshot_id, committed_at, operation
FROM lakehouse.silver."orders$snapshots"
ORDER BY committed_at;

SELECT count(*) FROM lakehouse.silver.orders FOR VERSION AS OF 8254608032447525305;

ALTER TABLE lakehouse.silver.orders EXECUTE rollback_to_snapshot(8254608032447525305);

SELECT count(*) FROM lakehouse.silver.orders;
```

### 6.2. Подключить инструмент к lakehouse

| Инструмент | Почему выбрала именно его |
|---|---|
| Spark 3.5.6 | Spark читает Iceberg напрямую через REST-каталог Lakekeeper, Trino ему для этого не нужен. На этом хорошо видно главное преимущество lakehouse: два разных движка работают с одними и теми же таблицами Bronze, а данные никуда не копируются. Metabase или Superset тоже подключились бы, но только через мой же Trino, то есть движок остался бы тот же. Кроме того, Spark хорошо подходит для тяжёлых пакетных ETL, и именно он обычно пересчитывает Bronze в Silver на больших объёмах. Doris и StarRocks тоже умеют читать Iceberg, но на sf1 их отдельный кластер избыточен. |

С первого раза образ `apache/spark:3.5.6` не скачался, Docker Hub несколько раз отвечал `TLS handshake timeout`. Со второй попытки всё прошло. Отдельный контейнер со Spark постоянно не держу: запускаю его разово в той же docker-сети `lakehouse_default`, в которой работает стек.

Скрипт запуска лежит в [spark/run_spark_sql.sh](spark/run_spark_sql.sh). Главное в нём:

```bash
docker run --rm --name spark --network lakehouse_default -v "$PWD/sql:/sql" -e HOME=/tmp apache/spark:3.5.6 \
  /opt/spark/bin/spark-sql --driver-memory 2g \
  --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.9.2,org.apache.iceberg:iceberg-aws-bundle:1.9.2 \
  --conf spark.sql.catalog.lakehouse=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.lakehouse.type=rest \
  --conf spark.sql.catalog.lakehouse.uri=http://lakekeeper:8181/catalog \
  --conf spark.sql.catalog.lakehouse.warehouse=lakehouse \
  --conf spark.sql.catalog.lakehouse.io-impl=org.apache.iceberg.aws.s3.S3FileIO \
  --conf spark.sql.catalog.lakehouse.s3.endpoint=http://minio:9000 \
  --conf spark.sql.catalog.lakehouse.s3.path-style-access=true \
  ...   # ключи MinIO и регион, полностью в скрипте
  -f /sql/10_spark_bronze.sql
```

- `--packages` скачивает из Maven Iceberg для Spark и AWS-бандл для работы с S3. Это около 100 МБ, и качаются они один раз за запуск.
- `catalog.lakehouse.type=rest` и `uri` направляют Spark в тот же Lakekeeper, что и Trino, а `warehouse=lakehouse` выбирает тот же warehouse.
- `S3FileIO` и `s3.*` нужны, чтобы Spark читал parquet-файлы напрямую из MinIO.

Что делала: запустила `./spark/run_spark_sql.sh`, он выполнил [sql/10_spark_bronze.sql](sql/10_spark_bronze.sql). Вывод Spark:

```
-- SHOW NAMESPACES IN lakehouse
bronze
silver
gold
bench_gzip
bench_zstd
bench_snappy

-- SHOW TABLES IN lakehouse.bronze
customer
orders
lineitem

-- count(*) по таблицам Bronze
customer   150000
orders     1500000
lineitem   6001215

-- снапшоты lineitem (метаданные Iceberg)
1435780585209411755   2026-10-11 23:21:08.172   append

-- Q18 по Bronze, первые 10 строк (14.3 с)
Customer#000128120  128120  4722021  1994-04-07  544089.09  323.0
Customer#000144617  144617  3043270  1997-02-12  530604.44  317.0
Customer#000013940  13940   2232932  1997-04-13  522720.61  304.0
Customer#000066790  66790   2199712  1996-09-30  515531.82  327.0
Customer#000046435  46435   4745607  1997-07-03  508047.99  309.0
...
```

Spark увидел все схемы, которые я создала через Trino. Количество строк в Bronze совпало с тем, что показывал Trino, а снапшот у lineitem ровно тот, который появился при CTAS из Trino. Q18, посчитанный Spark по Bronze, дал те же первые строки, что лежат в моей витрине Gold. Значит, оба движка видят одни и те же данные через один каталог. По времени Spark медленнее Trino: 14.3 с против примерно 2 с. Сюда входит прогрев JVM в одноразовом запуске, к тому же Spark рассчитан на долгие пакетные задачи, а не на быстрые интерактивные запросы. Поэтому для аналитики я оставила бы Trino, а Spark взяла бы для тяжёлых пересчётов слоёв.

## 7. Выводы

Медальонная архитектура разделяет хранение сырых данных и подготовку ответа. В Bronze лежит всё как есть, и это страховка. Silver уменьшает данные в разы: из 16 колонок lineitem остаётся только нужное, а тяжёлый подзапрос Q18 считается один раз. Gold содержит маленький готовый ответ, который совпал с эталонным Q18 строка в строку. Сравнение кодеков показало, что ZSTD почти так же компактен, как GZIP, но записывает быстрее, а SNAPPY быстрее пишет, но занимает на 40% больше места. Поэтому для всех слоёв я выбрала Parquet с ZSTD без партиционирования: на sf1 партиции дали бы только лишние мелкие файлы. Iceberg поверх MinIO дал возможности, которых нет у простого озера из файлов: изменение схемы без перезаписи данных и восстановление таблицы после ошибочного удаления за одну команду.
