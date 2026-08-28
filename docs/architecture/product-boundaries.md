# Product boundaries

Omagen has two packaged plugin products:

| Product | Manifest | Entry point | Ownership |
| --- | --- | --- | --- |
| Overlay + launcher/status widget | `manifest.json` (`pretty.omagen`) | `Omagen.qml`, `OmagenBarWidget.qml` | Opens the Studio overlay and exposes a small bar integration. |
| Full Bar plugin | `bar-manifest.json` (`pretty.omagen.bar`) | `OmagenBar.qml` | Renders the replacement/full bar and its presets. |

The launcher widget may summon the overlay through the running Omarchy shell;
it does not own session, generation, Apply, or recovery logic. The full Bar
plugin consumes BarSpec/profile data and native shell integrations but does not
become a second theme engine.

The backend remains the shared durable authority. QML views, Bar QML, native
Omarchy, and the runtime adapters meet through explicit data/protocol seams.
