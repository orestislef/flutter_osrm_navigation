## 0.1.3

* WebAssembly ready: on the web the voice now uses the browser's own speech directly, and flutter_tts is only loaded on phones and desktops. Same `TtsNavigationVoice`, nothing to change on your side
* Works with latlong2 0.10 as well as 0.9

## 0.1.2

* Arrival no longer leaves an empty strip under the banner: the footer buttons move up next to the arrival text, which also shows the destination name
* The arrival time follows the navigation language: 24 hour in Greek, the device setting in English (`NavigationStrings.clockTime`)

## 0.1.1

More events, so distance and time can be followed without listening to the controller:

* `ProgressUpdated` after every GPS fix that counted: distance and time left, distance to the next maneuver, position, speed, arrival time
* `StepChanged` when the next maneuver changes, the one before passed
* `EtaUpdated` when the router's estimate corrects the time left

Nothing to change on your side.

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
