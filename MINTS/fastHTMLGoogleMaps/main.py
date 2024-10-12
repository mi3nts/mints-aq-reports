from fasthtml.common import *
import json

app, rt = fast_app(
    hdrs=(
        Script(src="https://cdn.plot.ly/plotly-2.32.0.min.js"),
        Script(src="https://maps.googleapis.com/maps/api/js?key=AIzaSyAtXBRRlAXSW9OWYjsCoGx0HQ4TCiBp1T0&callback=initMap", async_=True, defer=True),
        Script("""
            function initMap() {
                const map = new google.maps.Map(document.getElementById("map"), {
                    center: { lat: -34.397, lng: 150.644 },
                    zoom: 8,
                });
            }
        """),
        Style("""
            html, body {
                height: 100%;
                margin: 0;
                padding: 0;
            }
            #map {
                height: 100%;
                width: 100%;
                position: absolute;
                top: 0;
                left: 0;
            }
            .overlay {
                position: absolute;
                top: 10px;
                left: 10px;
                z-index: 1000;
                background-color: rgba(255, 255, 255, 0.7);
                padding: 10px;
                border-radius: 5px;
            }
        """)

    )
    
)
# Sample weather data for three locations in Texas
weather_data = {
    "Houston": {"lat": 29.7604, "lng": -95.3698, "temperatures": [72, 75, 80, 85, 78, 70]},
    "Austin": {"lat": 30.2672, "lng": -97.7431, "temperatures": [70, 73, 78, 82, 76, 68]},
    "Dallas": {"lat": 32.7767, "lng": -96.7970, "temperatures": [68, 72, 77, 83, 74, 69]}
}

# Function to convert weather data to JavaScript format
weather_data_js = json.dumps(weather_data)

@rt("/")
def get():
    return Titled("Google Maps Example",
        Div(
            Div(
                H1("Welcome to our Map", style="color: black !important;"),
                P("This is a simple example of integrating Google Maps with FastHTML.", style="color: black !important;"),
                cls="overlay"
            ),
            Div(id="map")
        )
    )

serve()