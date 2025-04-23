# Change to your value
storage_account_name = "nyctaxistorage2pvicw"   # Change to your account name
storage_account_key = "q7oO/C6PNLXJGDNJ3dfXx6maX9P2Osn9fBKgEuzmUxmjtefbd6xyRijOkXYNDWGtth4loXBzOEw5+AStjcYHAA=="   # Change to your account key, to be consealed
container_name = "nyc-taxi-raw"
#parquet_path = "green/2025/01/green_tripdata_2025-01.parquet"
parquet_path = "yellow/2025/01/yellow_tripdata_2025-01.parquet"

# configure Spark to visit Azure Blob
spark.conf.set(
 f"fs.azure.account.key.{storage_account_name}.blob.core.windows.net",
 storage_account_key
)

# get the complete file path
file_path = f"wasbs://{container_name}@{storage_account_name}.blob.core.windows.net/{parquet_path}"

# read parquet file
df = spark.read.parquet(file_path)

# show df data and schema
df.show(5)
df.printSchema()

# Clean the Yellow taxi dataframe
# modify the column names mapping
rename_map = {
   "VendorID": "vendor_id",
   "tpep_pickup_datetime": "pickup_datetime",
   "tpep_dropoff_datetime": "dropoff_datetime",
   "passenger_count": "passenger_count",
   "trip_distance": "trip_distance",
   "RatecodeID": "rate_code_id",
   "store_and_fwd_flag": "store_and_fwd_flag",
   "PULocationID": "pu_location_id",
   "DOLocationID": "do_location_id",
   "payment_type": "payment_type",
   "fare_amount": "fare_amount",
   "extra": "extra",
   "mta_tax": "mta_tax",
   "tip_amount": "tip_amount",
   "tolls_amount": "tolls_amount",
   "improvement_surcharge": "improvement_surcharge",
   "total_amount": "total_amount",
   "congestion_surcharge": "congestion_surcharge",
   "Airport_fee": "airport_fee"
}


from pyspark.sql.functions import col
from pyspark.sql.types import IntegerType


# rename the columns
for old_col, new_col in rename_map.items():
   df = df.withColumnRenamed(old_col, new_col)


# data type standardization（eg：convert passenger_count and vendor_id to Integer）
df = df.withColumn("vendor_id", col("vendor_id").cast(IntegerType()))
df = df.withColumn("passenger_count", col("passenger_count").cast(IntegerType()))
df = df.withColumn("rate_code_id", col("rate_code_id").cast(IntegerType()))
df = df.withColumn("pu_location_id", col("pu_location_id").cast(IntegerType()))
df = df.withColumn("do_location_id", col("do_location_id").cast(IntegerType()))
df = df.withColumn("payment_type", col("payment_type").cast(IntegerType()))


# Null value handling
df = df.na.fill({"passenger_count": 0})


# check schema again
df.printSchema()
df.show(5)

# Plan A: Synapse Dedicated SQL Pool
# connection parameter
jdbc_url = (
    "jdbc:sqlserver://synapse-nyctaxi-test.sql.azuresynapse.net:1433;"
    "database=nyctaxipool;"
    "encrypt=true;"
    "trustServerCertificate=false;"
    "hostNameInCertificate=*.sql.azuresynapse.net;"
    "loginTimeout=30;"
)

jdbc_username = "sqladminuser"
jdbc_password = "wxy12345!"  # Ensure you secure this in production
table_name = "yellow_tripdata_2025_01"

# The tempDir is the staging container of Synapse
temp_dir = "wasbs://synapse-temp@nyctaxistorage2pvicw.blob.core.windows.net/tempdir"

# write to Synapse（overwrite mode）
df.write \
  .format("com.databricks.spark.sqldw") \
  .option("url", jdbc_url) \
  .option("forwardSparkAzureStorageCredentials", "true") \
  .option("dbtable", table_name) \
  .option("user", jdbc_username) \
  .option("password", jdbc_password) \
  .option("tempDir", temp_dir) \
  .mode("overwrite") \
  .save()