# ui/

Holds everything UI related. UI should not be entangled in game code - act as a clean layer on top. It visualizes logic defined elsewhere and provides control. Game code should provide good signals to keep the UI dynamic and updated and "endpoints" for changing things.

Current content: `map_browser/` is the minimal v1 map browser. It lists the built-in `MapDB`, shows map thumbnails, and calls the loader's public load/unload API while listening to its result signals.
