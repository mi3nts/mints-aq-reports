import influxdb_client, os, time
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

token = "0P2EZ-Bcaciqj0i3EZsODrH8CIB4rnbZZtnGHWtfTQUQ4f5mPCIr9KrB7z3Q3EA_eNbB6pq_4ErI9S2EEvU1CQ=="
org = "MINTS"
url = "http://localhost:8086"
bucket="mints-bucket"


write_client = influxdb_client.InfluxDBClient(url=url, token=token, org=org)


write_api = write_client.write_api(write_options=SYNCHRONOUS)

point = (
  Point("temperature")
  .tag("location", "New York")
  .field("temp", 28)
)
write_api.write(bucket=bucket, org="MINTS", record=point)
point = (
  Point("temperature")
  .tag("location", "San Francisco")
  .field("temp", 15)
)
write_api.write(bucket=bucket, org="MINTS", record=point)
point = (
  Point("temperature")
  .tag("location", "Los Angeles")
  .field("temp ", 25)
)
write_api.write(bucket=bucket, org="MINTS", record=point)
# point = (
#   Point("measurement1")
#   .tag("tagname1", "tagvalue1")
#   .field("field1", value)
# )
# write_api.write(bucket=bucket, org="MINTS", record=point)
time.sleep(1) # separate points by 1 second


# query_api = write_client.query_api()

# query = """from(bucket: "test-bucket")
#  |> range(start: -10m)
#  |> filter(fn: (r) => r._measurement == "measurement1")"""
# tables = query_api.query(query, org="MINTS")

# for table in tables:
#   for record in table.records:
#     print(record)
