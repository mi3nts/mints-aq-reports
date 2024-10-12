from fasthtml.common import *
import json

# Initialize FastHTML app
app, rt = fast_app()

# Google Maps API integration (replace 'YOUR_API_KEY' with your Google Maps API key)
MAPS_API_KEY = "AIzaSyAtXBRRlAXSW9OWYjsCoGx0HQ4TCiBp1T0"

google_maps_script = Script(src=f"https://maps.googleapis.com/maps/api/js?key={MAPS_API_KEY}&callback=initMap", async_=True, defer=True)

@rt('/')
def index():
    return Titled("Google Maps Integration", 
        Div(id="map", style="height: 100vh; width: 100vw;"),
        google_maps_script,
        Script(init_map_js()),
    )

def init_map_js():
    return NotStr("""
        function initMap() {
            const map = new google.maps.Map(document.getElementById('map'), {
                center: { lat: 32.7767, lng: -96.7970 }, // Centered in Dallas
                zoom: 7,
                gestureHandling: 'greedy',
            });

            // Dummy temperature data for markers
            const locations = [
                { 
                    name: 'Dallas', 
                    lat: 32.7767, 
                    lng: -96.7970, 
                    temperature: '85°F', 
                    hourlyTemperatures: [
                        '8 AM: 75°F', '9 AM: 77°F', '10 AM: 80°F', '11 AM: 82°F', '12 PM: 85°F',
                        '1 PM: 86°F', '2 PM: 87°F', '3 PM: 88°F', '4 PM: 85°F', '5 PM: 84°F'
                    ]
                },
                { 
                    name: 'Houston', 
                    lat: 29.7604, 
                    lng: -95.3698, 
                    temperature: '90°F', 
                    hourlyTemperatures: [
                        '8 AM: 80°F', '9 AM: 82°F', '10 AM: 85°F', '11 AM: 87°F', '12 PM: 90°F',
                        '1 PM: 92°F', '2 PM: 93°F', '3 PM: 94°F', '4 PM: 92°F', '5 PM: 91°F'
                    ]
                },
                { 
                    name: 'Fort Worth', 
                    lat: 32.7555, 
                    lng: -97.3308, 
                    temperature: '88°F', 
                    hourlyTemperatures: [
                        '8 AM: 78°F', '9 AM: 80°F', '10 AM: 82°F', '11 AM: 85°F', '12 PM: 88°F',
                        '1 PM: 89°F', '2 PM: 90°F', '3 PM: 91°F', '4 PM: 89°F', '5 PM: 87°F'
                    ]
                },
            ];

            // Store all info windows to manage them
            const infoWindows = [];

            // Create markers and info windows
            locations.forEach(function(location) {
                const marker = new google.maps.Marker({
                    position: { lat: location.lat, lng: location.lng },
                    map: map,
                    title: location.name,
                    icon: {
                        url: "http://maps.google.com/mapfiles/kml/paddle/blu-circle.png",
                        scaledSize: new google.maps.Size(50, 50),
                        labelOrigin: new google.maps.Point(25, -10)
                    },
                    label: {
                        text: location.temperature,
                        color: 'black',
                        fontWeight: 'bold',
                        fontSize: '18px'
                    }
                });

                const infoWindow = new google.maps.InfoWindow({
                    content: `<div><h3>${location.name}</h3><p>Temperature: ${location.temperature}</p><p>Hourly Temperatures:</p><ul>${location.hourlyTemperatures.map(temp => `<li>${temp}</li>`).join('')}</ul></div>`
                });

                infoWindows.push(infoWindow);

                marker.addListener('click', function() {
                    // Close all other info windows
                    infoWindows.forEach(function(iw) {
                        iw.close();
                    });
                    // Toggle the clicked info window
                    if (infoWindow.getMap()) {
                        infoWindow.close();
                    } else {
                        infoWindow.open(map, marker);
                    }
                });
            });
        }
    """)

# Run the server
serve()