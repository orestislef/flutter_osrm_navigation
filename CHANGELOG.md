## 0.1.9

* `fallbackUrls` on `OsrmRouter` and `ValhallaRouter`: other servers to ask when one is down, too slow, rate limited or failing. Requests stay on the one that answered and go back to the first after `retryMainAfter` (5 minutes), `currentUrl` says which is in use
* `FallbackRouter` chains routers of any kind, your own Valhalla first and OSRM behind it say. `onNoRoute` also falls over on "no route"

Nothing to change on your side.

## 0.1.8

* `RouteSimulator` parks at the end: its last fix says speed 0, so the speed badge no longer stays at the simulated speed after the drive. A real GPS already reports 0 when the car stops

## 0.1.7

* Speed limit sign next to the speed, from the route's `maxspeed` annotation, and the speed in `speedingColor` while over it. Without limits only the speed shows. `OsrmRouter(speedLimits: true)` asks for them on servers that support it, `speedLimitKmh`, `speeding` and `SpeedLimitChanged` on the controller
* `stopBuilder` and `destinationBuilder` for your own stop and destination widgets
* `onFollowingChanged` on `NavigationMap`, and `NavigationMapState.recenter()` through a `GlobalKey`
* README: an animation of a drive, and a screenshot with the speed

Nothing to change on your side.

## 0.1.6

* Spacing for everything over the map: `bannerPadding`, `bannerMaxWidth`, `recenterPadding`, `recenterAlignment` (next to `speedPadding` and `speedAlignment`), and `overlayInsets` that pushes the banner, the speed and the re-center button in together, for buttons or a panel of your own

Nothing to change on your side, the defaults are the old spacing.

## 0.1.5

* The current speed on the map: `NavigationMap(showSpeed: true)` by default, in km/h or mph by `settings.units` and in the navigation language. `NavigationSpeedometer` for your own layout, `speedColor` and `onSpeedColor` in `NavigationStyle`
* README: every switch on `NavigationMap` in one place, the accuracy circle (`showAccuracy`, on by default) among them

Nothing to change on your side. To keep the map as before pass `showSpeed: false`.

## 0.1.4

* Rate limits are handled: a 429 or a server error is not retried on the spot, `RoutingException` has `isRateLimited`, `isServerError` and the server's `retryAfter`, and reroutes and ETA refreshes wait at least as long as `Retry-After` asks
* Every routing error keeps its HTTP status
* `headersBuilder` on both routers, asked before every request, for tokens that expire
* `ValhallaRouter` takes `queryParameters`, for hosted servers that want the key in the URL
* README: keys, tokens and rate limits, and fresh screenshots of the arrival and of the Greek banner

Nothing to change on your side.

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
