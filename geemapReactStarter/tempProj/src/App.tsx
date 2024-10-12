import { useState } from "react";
import { APIProvider, Map } from "@vis.gl/react-google-maps";

function App() {
  const startPos = { lat: 11, lng: 76.7 };
  return (
    <>
      <APIProvider apiKey="AIzaSyAtXBRRlAXSW9OWYjsCoGx0HQ4TCiBp1T0">
        <div style={{ height: "100vh" }}>
          <Map defaultZoom={9} defaultCenter={startPos}></Map>
        </div>
      </APIProvider>
    </>
  );
}

export default App;
