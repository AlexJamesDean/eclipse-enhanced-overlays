# Eclipse Enhanced overlays

These are the changes the Eclipse City Enhanced Server Template makes to open-source FiveM resources: QBCore, ox_inventory, ox_lib, bob74_ipl, PolyZone, ps-adminmenu and the rest. They're free.

Every folder under `resources/` holds only the files that differ from the upstream version the template's txAdmin recipe downloads. The recipe pins each upstream to an exact commit or release, then copies this repository over the top. **This repository on its own is not a server.**

## Licences

Each file keeps the licence of the resource it belongs to, most of them GPL-3.0 or LGPL-3.0. See the `LICENSE` file in that resource's upstream repository. Under those licences, the modified source is published here.

## What changed and why

- Streamed folders are renamed `stream` → `stream_enhanced` (FiveM Enhanced warns about the old name). Those moves happen in the recipe, so they aren't copied here.
- QBCore jobs, items, vehicles and gangs are reworked for a UK roleplay city on Enhanced.
- ox_inventory runs on the QBCore bridge, with the converted item list.
- The police resources carry a shim into `ajd-police`.

The paid template that uses these overlays is sold separately. It is not approved, sponsored or endorsed by Rockstar Games.
