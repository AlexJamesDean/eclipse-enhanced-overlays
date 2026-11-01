# qb-ambulancejob
EMS Job and Death/Wound Logic for QB-Core Framework :ambulance:

## Dependencies
- [qb-core](https://github.com/qbcore-framework/qb-core) (Required)
- [qb-phone](https://github.com/qbcore-framework/qb-phone) (Required)
- [qb-target](https://github.com/BerkieBb/qb-target) (Optional)
- [PolyZone](https://github.com/mkafrin/PolyZone) (Required)

# Server.cfg Convar Update
- Global DrawTextUi Option
```
setr UseTarget false
``` 

- Global Target Option
```
setr UseTarget true
```


# Eclipse City notes

## Down-state metadata is client-authored

`isdead` and `inlaststand` are server metadata, but every write originates on the client
(`client/dead.lua:23`, `client/laststand.lua:124`, `client/main.lua:575-576`, `client/job.lua:146-147`).
Nothing on the server reconciles them, so a client that loses its death state between the
"died" and "revived" events — resource restart, crash, or a login whose resync did not run —
leaves `isdead` true forever on a player who is walking around. That state makes
`ajd-aidoc` refuse a call-out ("the emergency intervention window has closed"), and is also
read as "downed" by `ajd-carry`, `ajd-doorlock`, `ajd-garage` and `ajd-gangzones`.

Two guards:

- `server/main.lua:310` — `hospital:server:SetLaststandStatus(true)` clears `isdead` and the
  defib window. Last stand and full death are mutually exclusive, and the client only enters
  last stand from an alive→downed transition, so this is the self-healing point: a stuck flag
  clears the next time the player goes down. The bleed-out and second-hit paths both send
  `false` before `OnDeath()` sets `isdead`, so a real death is not affected.
- `client/job.lua:132` — the login resync waits for `PlayerData.job` and `PlayerData.metadata`
  (bounded, 20s) instead of assuming a fixed 1s delay is enough. Previously a nil `metadata`
  threw on the armour line and skipped the whole resync, including the branch that clears
  both flags.

## Restart discipline

Restarting this resource on a live server resets `isDead`/`InLaststand` on every connected
client while the server-side metadata persists — the exact desync described above. Apply
changes at a scheduled restart, not with `restart qb-ambulancejob`.

# License

    QBCore Framework
    Copyright (C) 2021 Joshua Eger

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>
