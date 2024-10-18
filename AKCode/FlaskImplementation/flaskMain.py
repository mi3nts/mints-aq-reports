from flask import Flask, render_template
import geemap
import folium
import os
from folium.plugins import BeautifyIcon

app = Flask(__name__)

@app.route('/')
def index():
    # Set up the initial map view
    map_center = [37.0902, -95.7129]  # Center of the map, you can modify to a specific latitude and longitude
    initial_zoom = 4

    # Create a folium map instance
    m = folium.Map(location=map_center, zoom_start=initial_zoom, tiles='OpenStreetMap')

    temperature_data = [
        [37.7749, -122.4194, 15],
        [40.7128, -74.0060, 22],
        [34.0522, -118.2437, 18]
    ]

    for data in temperature_data:
        lat, lon, temperature = data
        icon = BeautifyIcon(
            border_color="#00ABDC",
            text_color="#00ABDC",
            icon_size=[30, 30],
            number = temperature,
            inner_icon_style='text-align: center; line-height: 1.5;',
        )
        folium.Marker(
            location=[lat, lon],
            icon=icon
        ).add_to(m)

    # Add layer control to toggle between different layers
    folium.TileLayer('CartoDB positron', name='CartoDB positron', attr='Map tiles by Carto, under CC BY 3.0. Data by OpenStreetMap, under ODbL').add_to(m)
    folium.LayerControl(position='topright').add_to(m)

    # Save the map to an HTML file to display it
    map_file = 'templates/map.html'
    m.save(map_file)

    return render_template('map.html')

if __name__ == '__main__':
    # Make sure templates directory exists
    if not os.path.exists('templates'):
        os.makedirs('templates')

    app.run(debug=True, port=5000)
