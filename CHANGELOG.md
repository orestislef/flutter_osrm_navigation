## 0.2.3

* README: the next turn outside the app. Which events to listen to, an ongoing notification on Android, and on iOS (which has no such notification while locating in the background) a quiet notification or a Live Activity, with SF Symbols for the maneuvers

No code changes.

## 0.2.2

* Stop and destination markers stay upright when the map turns with the road, `stopBuilder` and `destinationBuilder` widgets included. **If your builders turned themselves back against the map rotation, remove that after updating, or they turn twice**
* `crs` and `cameraConstraint` on `NavigationMap`, passed to flutter_map as they are. Defaults unchanged
* `controller.say(text, interrupt: false)` for alerts of your own through the navigation voice: it follows the mute, the language and `speakGapMs`, does not cut a prompt off unless `interrupt` is true, and comes through `events` as `InstructionSpoken`
* `controller.addWaypoint(point, index: ...)` and `removeWaypoint(index)` change the stops while navigating: a new route from where the car is through the stops not reached yet to the same destination, with `Rerouted` and no "Navigating to" said again
* Fix: a simulation that started a block away from the last real fix had its first fixes taken for GPS jumps and stood still. `RouteSimulator.start` now forgets the recent fixes, and `controller.resetFixHistory()` does it for fixes of your own
* `positionAt` and `overlayInsets` that change while following (a panel being dragged) move the camera at once, not at the next fix
* README: the next turn in a notification of your own, and the speed badge with no route

## 0.2.1

**The map without a route now follows like it does while navigating.** Until now `NavigationMap` with no navigation going kept north up, kept the zoom, stayed where the user left it after a pan, and hid the speed. Now, by default, it turns with the direction of travel (above `settings.headingKmh`, holding its rotation when slower), zooms with the speed, keeps the car low on the screen, follows again after `recenterAfter`, and shows the speed. Each of these is a switch, set them to false for the old map:

* `idleHeadingUp`
* `idleFollowLikeNavigation`
* `recenterWhenIdle`
* `speedOnlyWhileNavigating` (true hides the speed when not navigating)

Also:

* `NavigationMapState.showPoint(point, zoom: ...)` moves the camera to a place, stops following and lets `recenterAfter` or the button bring it back
* Fix: inside loose constraints, with an overlay that takes no room, the map shrank to nothing. It now always takes the size it is given
* The camera eases over from where it is when following starts, instead of jumping
* Bulgarian, German, French, Spanish and Italian built in, `NavigationStrings.forLocale` and `NavigationStrings.register` for a language of your own

## 0.2.0

What can go wrong on a real phone, said out loud so the app can help the user:

* `controller.voiceProblem`: `noEngine`, `languageMissing`, `notDownloaded` (Android, the voice speaks only online) or `unsupportedPlatform`, and `recheckVoice()` for when the user comes back from installing one. The README shows how to open the install screens on Android
* `LocationAccess.approximate` when the user turned "Precise" off: those fixes are kilometres off and navigation cannot use them. `NavigationLocation.isPrecise()`, and on iOS `ensurePermission(iosPrecisePurposeKey: ...)` asks for precise location for the session
* `controller.gpsSignal` (`good`, `weak`, `lost`), `GpsSignalChanged`, and a "Searching for GPS…" or "Weak GPS signal" line in the banner, after `settings.gpsLostSeconds` (10) without a usable fix
* README: what the package does in each of these cases

If you `switch` over `LocationAccess`, add a case for `approximate`.

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
