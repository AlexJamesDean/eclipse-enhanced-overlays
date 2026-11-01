# QB-Banking

## Features
- Handles all player interaction with bank/job/gang/shared accounts
- ATM and bank card integration
- Third-eye `Use ATM` and `Rob ATM` actions on cashpoint models
- Shared accounts between players
- Auto creation of job/gang accounts on bank first open
- Boss-only access to job/gang accounts

Documentation: https://docs.qbcore.org/qbcore-documentation/qbcore-resources/qb-banking

## Eclipse City cashpoint robbery

Cashpoints use qb-target independently of the global `UseTarget` convar; bank counters retain their existing
interaction policy. `Config.atmRobbery` controls the required item, on-duty police minimum, progress duration,
per-cashpoint cooldown, interaction distance and cash reward range.

The server owns the crowbar/police checks, cashpoint reservation, immediate police alert, elapsed-time and distance
validation, cooldown and payout. Every accepted attempt removes 20 durability from the crowbar immediately;
cancelling or failing after the alarm does not avoid the wear or reset that cashpoint's cooldown.

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
