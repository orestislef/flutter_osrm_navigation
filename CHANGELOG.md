## 0.1.0

First release.

* Turn-by-turn navigation along the route line: distance to the next maneuver, time and distance left, arrival time
* Voice prompts far, near and at each maneuver, earlier at speed, with the next one when it comes right after
* Rerouting when off the route, driving the wrong way, or past a missed U-turn. One request at a time with a backoff, the old route stays until a new one arrives
* Stops on the way, announced and reported, and kept in reroutes
* Routers for OSRM and Valhalla, plus `CallbackRouter` for routes that come through your own backend
* Live ETA from the router now and then
* `NavigationMap` with a camera that turns with the road, zooms with speed and comes back after you pan
* `NavigationBanner`, `NavigationRouteLayer`, `NavigationStopsLayer` and `NavigationPositionLayer` for your own layouts
* `NavigationStyle` theme extension for every color
* `NavigationLocation` for GPS fixes that keep coming in the background (Android foreground service, iOS background location)
* English and Greek, metric and imperial
* `RouteSimulator` to drive a route at a desk, with `missTurn` and `turnAround` to watch rerouting
* Tested on Android 15 in the foreground and with the screen off
