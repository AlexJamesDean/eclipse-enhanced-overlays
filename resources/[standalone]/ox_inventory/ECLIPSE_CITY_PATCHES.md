# Eclipse City patches to ox_inventory

Base: **official ox_inventory v2.47.9** (published 13 Jul 2026)
`sha256 C072ACD028CD8F75F3FAB1A594E85C620A4C77CFB5DB77A4EA64BCDEFD362AE1`

overextended **dropped QBCore support** — upstream ships bridges for `ox / esx / qbx / nd`
only. Eclipse City stays on QBCore, so the qb support below is ours to maintain rather
than a fork dependency.

**Every change here must be re-applied after an ox_inventory update.** Diff a fresh
release against this list before deploying it.

---

## 1. NEW: `modules/bridge/qb/server.lua` + `client.lua`

The QBCore framework bridge. Written against `modules/bridge/qbx/*` as reference, since
qbx_core is a QBCore fork. Selected with `set inventory:framework "qb"` in server.cfg.

Implements: `setPlayerData`, `UseItem`, `syncInventory`, `hasLicense`, `buyLicense`,
`isPlayerBoss`, `getOwnedVehicleId`, plus player load/unload and job/gang change handling.

Four places QBCore differs from qbx:
- **No `groups` table** — synthesised from `job` + `gang` into one map (identical logic on
  client and server so permission checks agree).
- **No group-update event** — re-derived from `QBCore:Player:SetPlayerData` /
  `OnJobUpdate` / `OnGangUpdate`.
- **No `IsGradeBoss` export** — read `isboss` from `QBCore.Shared.Jobs/Gangs`, handling
  string grade keys.
- **No `qbx_vehicles`** — direct `player_vehicles` lookup by trimmed plate.

Also keeps `PlayerData.items` populated in `syncInventory`: ox is source of truth, but many
QBCore resources read `PlayerData.items` directly and would otherwise see an empty
inventory.

**`server.UseItem` — the qbx bridge cannot be copied verbatim here.** qbx_core's
`CanUseItem` returns the callback *function*; this qb-core returns a **table**:

```lua
QBCore.UsableItems[item] = { func = rawFunc, resource = GetInvokingResource() }
```

so `cb(source, data)` attempts to call a table. ox invokes `server.UseItem` inside a
`pcall` (server.lua:495-502) precisely so a bad item callback can't break the inventory —
which means this threw and **failed completely silently**. Every usable item on the server
was dead: `ajd-phone`, `qb-weed` ×2, `qb-weapons` ×4, `qb-diving` ×2, `qb-mechanicjob` ×9,
`qb-houses`, `ajd-fishing`. Symptom was "the phone does nothing", with no error anywhere.

Fixed by unwrapping `usable.func` (tolerating both shapes) and translating ox's
`{name, count, slot, metadata}` into a qb-shaped item table, since qb's
`CreateUseableItem` handlers receive `(source, item)` and several read `item.info` /
`item.slot`. The same fix is applied in `[qb]/qb-inventory`'s `UseItem` export shim.

### 1b. PATCH: `modules/bridge/qb/server.lua` — `getOwnedVehicleId` must trim BOTH ends

```lua
-- was: local trimmed = (plate:gsub('%s+$', ''))
local trimmed = (plate:gsub('^%s*(.-)%s*$', '%1'))
```

Trailing-only was wrong. GTA pads a plate shorter than 8 characters out to 8 on the
entity and the padding can land **in front** of the text, so the lookup compared
`' ACIDOG'` against a `TRIM()`ed column and matched nothing.

This has to agree with **`server.lua:180`**, which builds the inventory id
(`'trunk' .. plate` / `'glove' .. plate`) using ox_lib's `string.strtrim` — a both-end
trim. If the two strip differently, the inventory id and the database row id describe
different cars. Any future edit to either must keep them identical.

**A nil `getOwnedVehicleId` fails completely silently**, which is why this survived so
long: `Inventory.Load` short-circuits on `result = id and ...` and returns an empty
table — the trunk opens with no error and no contents — and every save then runs
`UPDATE player_vehicles SET trunk = ? WHERE id = NULL`, affecting zero rows. The only
trace anywhere is ox's own periodic **`Saved 0/1 trunks` / `Saved 0/N gloveboxes`**
line. That count is a defect signal, not noise.

Broke every owned vehicle whose plate was under 8 characters (on this box: `ACIDOG`,
`ECL002`). 8-character plates were never affected, which is why it read as one player's
problem rather than a bridge bug.

## 2. PATCH: `modules/mysql/server.lua` — add a `qb` branch

```lua
elseif shared.framework == 'qbx' or shared.framework == 'qb' then
```

Without this, `framework = 'qb'` fell through to `else return`, so the
`{user_table}` / `{user_column}` placeholders were **never substituted** — every query ran
with literal `{user_table}` in the SQL and the `ox_inventory` table was never created.
QBCore and qbx share the schema (`players.citizenid`, `player_vehicles.id`), hence one
branch.

## 3. PATCH: `modules/items/server.lua` — exact match before the weapon_ transform

`getItem()` unconditionally uppercased any name starting with `weapon_`, so a lowercase
item named `weapon_parts` was looked up as `WEAPON_PARTS` and returned nil.

Eclipse City has two `type='item'` crafting components with that prefix —
**`weapon_parts` and `weapon_spring`** — held in 7 player stacks. Fix tries the exact
lowercase key first and only falls back to the uppercase transform:

```lua
local exact = ItemList[name]
if exact then return exact end
```

Real weapons are unaffected (they exist only as `WEAPON_*` keys, so the lowercase lookup
misses and the original path runs). Arguably an upstream bug — exact match should beat a
heuristic.

## 3b. PATCH: `init.lua` — framework default `esx` -> `qb`

```lua
framework = GetConvar('inventory:framework', 'qb'),
```

`init.lua` is registered as **both** a `server_script` and a `client_script`
(fxmanifest lines 28 and 31), and `modules/bridge/client.lua` also runs
`lib.load(('modules.bridge.%s.client'):format(shared.framework))` — so the **client**
reads this convar too.

Two traps stacked up:
1. A convar set with plain `set` is server-only; clients never receive it.
2. A convar first created non-replicated does **not** gain the replication flag when
   later re-issued with `setr`.

Result: the server ran the qb bridge correctly while the client silently kept the `esx`
default, loaded `modules/bridge/esx/client.lua`, and died with
`No such export getSharedObject in resource es_extended` — with nothing wrong in the
server log at all. Defaulting to `qb` makes the right bridge load with or without the
convar; the convar still overrides when properly replicated, so no flexibility is lost.

server.cfg also carries `setr inventory:framework "qb"` and `setr inventory:keys ...` —
note **setr**, not `set`, for the same reason.

## 4. REPLACED: `data/items.lua`

330 items generated from `QBCore.Shared.Items` by `[ajd]/ajd-itemconvert`.
Upstream default kept as `data/items.lua.ox-default`.

- Weapons are **not** converted — ox's own `data/weapons.lua` already defines 108, the same
  count qb had. Only 10 qb weapons are absent and most are props
  (`WEAPON_BREAD`, `WEAPON_HANDCUFFS`, `WEAPON_GARBAGEBAG`, …).
- **No item declares `degrade`** — deliberate. AJ's rule: items do not decay on a timer;
  durability changes only through scripts. Keep it that way.

## 4b. NEW: Aurora theme — `web/build/aurora.css` (+ 2 one-line hooks)

**No React build needed.** The release ships only the compiled bundle (`web/build`, no
`web/src`), but the bundler kept **semantic class names** — `.inventory-slot`,
`.tooltip-wrapper`, `.weight-bar`, `.context-menu-item` … — and `assets/index.css` is only
7.8 KB. So the theme is a pure stylesheet override. This also means **yarn/webpack are
irrelevant**: those only matter for resources that compile at server start, and ox does not.

Three files touched:
1. `web/build/aurora.css` — NEW, the whole theme. Survives updates untouched.
2. `web/build/index.html` — one `<link>` **after** `assets/index.css`, so
   equal-specificity rules win without `!important`. **An ox release overwrites this file.**
3. `fxmanifest.lua` — `'web/build/aurora.css'` added to `files{}`. Without it the client
   cannot fetch the stylesheet and the UI silently stays stock.

`!important` is used only on `.weight-bar > div` / `.durability-bar > div`, because React
writes those fills as inline styles and inline beats any stylesheet.

ox's stock palette (Mantine dark) that this replaces: `#c1c2c5` text, `#22232c` surfaces,
`#0c0c0c66` slots, `#0003` inset borders.

## 4c. PATCH: `web/build/assets/index.js` — do not request `web/build/none`

The compiled UI rendered empty inventory and hotbar slots with:

```js
backgroundImage: `url(${item?.name ? getItemImage(item) : `none`}`
```

That makes Chromium treat `none` as a relative image URL and request the nonexistent
resource file `web/build/none`. Cfx Server's 27 Jul 2026 Enhanced build reports every
such request as:

```text
Failed to open resource file web/build/none for resource ox_inventory.
```

The two empty-slot expressions now use the CSS keyword directly:

```js
backgroundImage: item?.name ? `url(${getItemImage(item)})` : `none`
```

This is a compiled-bundle patch because the release contains no `web/src`. Original
bundle backup: `web/build/assets/index.js.pre-b98-none-fix.bak` (not included by the
manifest's `*.js` wildcard).

## 5. MERGED: `web/images/`

675 images — ox's original 198 plus 477 from `qb-inventory/html/images`. Name collisions
kept ox's version. Six items still have no image
(`pill_press` never existed; `hammer`, `wood`, `sprayremover`, `emp_ammo`,
`luxuryfinish_attachment`).

---

## Companion resource: `[ajd]/ajd-inventory-compat`

Lives outside ox_inventory so ox stays updatable. Routes QBCore call sites to ox via
`QBCore.Functions.AddPlayerMethod`, injecting `AddItem`, `RemoveItem`, `GetItemByName`,
`GetItemsByName`, `GetItemBySlot`, `ClearInventory`, `CanCarryItem` per player, plus a
global `QBCore.Functions.HasItem`.

**It also fixes a pre-existing bug.** This qb-core build never defined `AddItem`,
`RemoveItem` or `GetItemByName` on the player object — qb-inventory only exposed them as
resource exports. ~53 call sites were already calling nil, including
`ajd-crafting/server.lua:460-463`, the main crafting success path. It never surfaced
because the benches were unreachable, so no craft completed.

Load order: ox_inventory must start before it. `[standalone]` is ensured before `[ajd]` in
server.cfg, so ox_inventory in `[standalone]` satisfies this.

## Still outstanding

- Player inventory format migration (`amount`→`count`, `info`→`metadata`, `[]`→nil,
  `serie`→`serial`, `quality`→`durability` forced to 100)
- `set inventory:framework "qb"` in server.cfg
- Disable qb-inventory; patch qb-core's own inventory coupling
- Check the 11 `ajd-*` resources that call inventory directly
- Aurora theme — requires a React rebuild of `web/`
- ox_lib on this server is **3.39.0**; confirm it satisfies ox_inventory 2.47.9
