from flask import Flask, render_template
import geemap
import folium
import os
from folium.plugins import BeautifyIcon

import influxdb_client
from influxdb_client import InfluxDBClient

# InfluxDB connection details
token = "0P2EZ-Bcaciqj0i3EZsODrH8CIB4rnbZZtnGHWtfTQUQ4f5mPCIr9KrB7z3Q3EA_eNbB6pq_4ErI9S2EEvU1CQ=="
org = "MINTS"
url = "http://localhost:8086"
bucket = "mints-bucket"

app = Flask(__name__)

@app.route('/')
def index():
    # Set up the initial map view
    map_center = [37.0902, -95.7129]  # Center of the map, you can modify to a specific latitude and longitude
    initial_zoom = 4
    # Create a folium map instance
    m = folium.Map(location=map_center, zoom_start=initial_zoom, tiles='OpenStreetMap')

    # Connect to InfluxDB
    client = InfluxDBClient(url=url, token=token, org=org)
    query_api = client.query_api()

    # Query temperatures for specific locations
    flux_query = f'''
    from(bucket: "{bucket}")
        |> range(start: -1h)
        |> filter(fn: (r) => r._measurement == "temperature")
        |> filter(fn: (r) => r["location"] == "New York" or r["location"] == "San Francisco" or r["location"] == "Los Angeles")
    '''
    tables = query_api.query(flux_query, org=org)

    # Extract temperature data from query results
    temperature_data = []
    for table in tables:
        for record in table.records:
            location = record.values.get("location")
            temperature = record.get_value()
            lat, lon = 0, 0
            if location == "New York":
                lat, lon = 40.7128, -74.0060
            elif location == "San Francisco":
                lat, lon = 37.7749, -122.4194
            elif location == "Los Angeles":
                lat, lon = 34.0522, -118.2437
            temperature_data.append([lat, lon, temperature, location])

    # Add markers to the map
    for data in temperature_data:
        lat, lon, temperature, location = data
        icon = BeautifyIcon(
            border_color="#00ABDC",
            text_color="#00ABDC",
            icon_size=[30, 30],
            number=temperature,
            inner_icon_style='text-align: center; line-height: 1.5;'
        )
        folium.Marker(
            location=[lat, lon],
            popup=f"{location}: {temperature}°C",
            icon=icon
        ).add_to(m)

    # Add layer control
    folium.TileLayer('CartoDB positron', name='CartoDB positron', attr='Map tiles by Carto, under CC BY 3.0. Data by OpenStreetMap, under ODbL').add_to(m)
    folium.LayerControl(position='topright').add_to(m)

    # Save the map to an HTML file to display it
    map_file = 'templates/map.html'
    m.save(map_file)

    return render_template('map.html')

if __name__ == '__main__':
    if not os.path.exists('templates'):
        os.makedirs('templates')

    app.run(debug=True, port=5001)
