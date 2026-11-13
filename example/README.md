# flutter_osrm_navigation example

A map you can navigate on. Long press to drop a destination (and again to
add stops on the way), then tap **Navigate** to drive it with your GPS or
**Simulate** to watch it drive itself at 50 km/h.

The language buttons switch the voice and the banner between English and
Greek, and the look buttons switch between the app theme, a dark theme, and
fully custom colors through `NavigationStyle`.

Routes come from OSRM's public demo server, which is only meant for trying
things out. Point `OsrmRouter` (or `ValhallaRouter`) at your own server for
anything real.

```bash
flutter run
```
