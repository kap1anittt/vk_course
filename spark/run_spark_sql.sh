#!/usr/bin/env bash
# Запуск Spark SQL поверх того же lakehouse: каталог Lakekeeper, данные в MinIO.
# Запускать из корня репозитория, стек должен быть поднят (docker compose up -d).
# Пример: ./spark/run_spark_sql.sh /sql/10_spark_bronze.sql

docker run --rm --name spark --network lakehouse_default -v "$PWD/sql:/sql" -e HOME=/tmp apache/spark:3.5.6 \
  /opt/spark/bin/spark-sql --driver-memory 2g \
  --conf spark.jars.ivy=/tmp/ivy \
  --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.9.2,org.apache.iceberg:iceberg-aws-bundle:1.9.2 \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.lakehouse=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.lakehouse.type=rest \
  --conf spark.sql.catalog.lakehouse.uri=http://lakekeeper:8181/catalog \
  --conf spark.sql.catalog.lakehouse.warehouse=lakehouse \
  --conf spark.sql.catalog.lakehouse.io-impl=org.apache.iceberg.aws.s3.S3FileIO \
  --conf spark.sql.catalog.lakehouse.s3.endpoint=http://minio:9000 \
  --conf spark.sql.catalog.lakehouse.s3.path-style-access=true \
  --conf spark.sql.catalog.lakehouse.s3.access-key-id=minioadmin \
  --conf spark.sql.catalog.lakehouse.s3.secret-access-key=minioadmin123 \
  --conf spark.sql.catalog.lakehouse.client.region=us-east-1 \
  --conf spark.sql.defaultCatalog=lakehouse \
  -f "${1:-/sql/10_spark_bronze.sql}"
