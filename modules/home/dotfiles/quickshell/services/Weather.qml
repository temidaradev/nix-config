pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Open-Meteo: current conditions + 5-day forecast for a city name stored in
// ~/.local/state/quickshell/weather-city (defaults to the timezone's city).
Singleton {
    id: root
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    property string city: ""
    property string place: ""
    property real lat: 0
    property real lon: 0
    property var current: null      // {temp, code, wind, humidity, feels}
    property var daily: []          // [{date, code, min, max}]
    property string error: ""
    readonly property bool ready: current !== null

    function glyph(code, night) {
        if (code === 0) return night ? "󰖔" : "󰖙"
        if (code <= 2) return night ? "󰼱" : "󰖕"
        if (code === 3) return "󰖐"
        if (code <= 48) return "󰖑"
        if (code <= 57) return "󰖗"
        if (code <= 67) return "󰖖"
        if (code <= 77) return "󰖘"
        if (code <= 82) return "󰖖"
        if (code <= 86) return "󰖘"
        return "󰖓"
    }
    function describe(code) {
        const m = { 0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast", 45: "Fog", 48: "Rime fog", 51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
                    61: "Light rain", 63: "Rain", 65: "Heavy rain", 66: "Freezing rain", 67: "Freezing rain", 71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
                    80: "Showers", 81: "Showers", 82: "Heavy showers", 85: "Snow showers", 86: "Snow showers", 95: "Thunderstorm", 96: "Thunderstorm, hail", 99: "Thunderstorm, hail" }
        return m[code] || "—"
    }

    Component.onCompleted: city = Settings.s.weather.city
    onCityChanged: if (city !== "") geocode.running = true

    Process {
        id: geocode
        command: ["curl", "-sf", "--max-time", "10", "https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&name=" + encodeURIComponent(root.city)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text).results[0]
                    root.lat = r.latitude; root.lon = r.longitude
                    root.place = r.name + (r.country_code ? ", " + r.country_code : "")
                    root.error = ""
                    forecast.running = true
                } catch (e) { root.error = "Unknown place: " + root.city }
            }
        }
    }
    Process {
        id: forecast
        command: ["curl", "-sf", "--max-time", "10", "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat + "&longitude=" + root.lon
                  + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=5"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    root.current = { temp: Math.round(j.current.temperature_2m), feels: Math.round(j.current.apparent_temperature), humidity: j.current.relative_humidity_2m,
                                     code: j.current.weather_code, wind: Math.round(j.current.wind_speed_10m), night: j.current.is_day === 0 }
                    root.daily = j.daily.time.map((d, i) => ({ date: d, code: j.daily.weather_code[i], max: Math.round(j.daily.temperature_2m_max[i]), min: Math.round(j.daily.temperature_2m_min[i]) }))
                    root.error = ""
                } catch (e) { root.error = "Weather unavailable" }
            }
        }
    }
    Timer { interval: 15 * 60000; running: root.lat !== 0; repeat: true; onTriggered: forecast.running = true }
}
