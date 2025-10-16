# Change Log

<!-- changelog -->

## [v1.82.0](https://github.com/wanderer-industries/wanderer/compare/v1.81.15...v1.82.0) (2025-10-15)




### Features:

* Core: Added an ability to copy/paste selected map area between maps

### Bug Fixes:

* Map: Add ability to copy and past systems (UI part)

## [v1.81.15](https://github.com/wanderer-industries/wanderer/compare/v1.81.14...v1.81.15) (2025-10-15)




### Bug Fixes:

* Map: Fixed problem with commit - for correct restore deprecated data - change config key

## [v1.81.14](https://github.com/wanderer-industries/wanderer/compare/v1.81.13...v1.81.14) (2025-10-15)




### Bug Fixes:

* Map: Fixed problem with commit - for correct restore deprecated data

## [v1.81.13](https://github.com/wanderer-industries/wanderer/compare/v1.81.12...v1.81.13) (2025-10-15)




### Bug Fixes:

* Core: Fixed system select after tab switch

## [v1.81.12](https://github.com/wanderer-industries/wanderer/compare/v1.81.11...v1.81.12) (2025-10-15)




### Bug Fixes:

* Core: Fixed map events buffering on tab switch

## [v1.81.11](https://github.com/wanderer-industries/wanderer/compare/v1.81.10...v1.81.11) (2025-10-15)




### Bug Fixes:

* Signatures: Fixed EOL indication for un-splashed and signatures list

## [v1.81.10](https://github.com/wanderer-industries/wanderer/compare/v1.81.9...v1.81.10) (2025-10-13)




### Bug Fixes:

* Signatures: Rework for lazy signatures deletion

## [v1.81.9](https://github.com/wanderer-industries/wanderer/compare/v1.81.8...v1.81.9) (2025-10-12)




### Bug Fixes:

* Signatures: Fixed issue with wrong linked signatures deletions

## [v1.81.8](https://github.com/wanderer-industries/wanderer/compare/v1.81.7...v1.81.8) (2025-10-11)




### Bug Fixes:

* Map: Fix problem with restoring settings on widgets

## [v1.81.7](https://github.com/wanderer-industries/wanderer/compare/v1.81.6...v1.81.7) (2025-10-10)




### Bug Fixes:

* Map: Fixed problem with rendering dropdown classes in signatures

## [v1.81.6](https://github.com/wanderer-industries/wanderer/compare/v1.81.5...v1.81.6) (2025-10-10)




### Bug Fixes:

* Map: Fixed problem with a lot unnecessary loads zkb data on resize map

* Map: Added ability to see focused element

* Map: Removed unnecessary vertical scroller in Character Tracking dialog. Main always first in list of tracking characters, following next after main, another characters sorting by name

* Map: Added Search tool for systems what on the map

* Map: Added migration mechanism

* Map: Remove settings some default values if migration from very old settings system

* Map: MIGRATION: support from old store settings import

* Map: Add common migration mechanism. ATTENTION! This is a non-reversible stored map settings commit â it means we do not guarantee that settings will work if you check out back. Weâve tried to migrate old settings, but it may not work well or may NOT work at all.

* Map: Add front-end migrations for local store settings

## [v1.81.5](https://github.com/wanderer-industries/wanderer/compare/v1.81.4...v1.81.5) (2025-10-09)




### Bug Fixes:

* Core: Update connection ship size based on linked signature type

## [v1.81.4](https://github.com/wanderer-industries/wanderer/compare/v1.81.3...v1.81.4) (2025-10-09)




### Bug Fixes:

* Core: Fixed signature to system link issues

## [v1.81.3](https://github.com/wanderer-industries/wanderer/compare/v1.81.2...v1.81.3) (2025-10-07)




### Bug Fixes:

* Core: Fixed cancel ping errors

## [v1.81.2](https://github.com/wanderer-industries/wanderer/compare/v1.81.1...v1.81.2) (2025-10-07)




### Bug Fixes:

* api dropping custom name

## [v1.81.1](https://github.com/wanderer-industries/wanderer/compare/v1.81.0...v1.81.1) (2025-10-02)




### Bug Fixes:

* Core: Fixed characters tracking updates.

## [v1.81.0](https://github.com/wanderer-industries/wanderer/compare/v1.80.0...v1.81.0) (2025-10-02)




### Features:

* core: fix pwa icons + add screen in manifest

## [v1.80.0](https://github.com/wanderer-industries/wanderer/compare/v1.79.6...v1.80.0) (2025-10-02)




### Features:

* Core: Added PWA web manifest

## [v1.79.6](https://github.com/wanderer-industries/wanderer/compare/v1.79.5...v1.79.6) (2025-10-01)




### Bug Fixes:

* Core: Fixed modals auto-save on Enter.

## [v1.79.5](https://github.com/wanderer-industries/wanderer/compare/v1.79.4...v1.79.5) (2025-10-01)




### Bug Fixes:

* Core: Fixed system details modal auto-save on Enter.

## [v1.79.4](https://github.com/wanderer-industries/wanderer/compare/v1.79.3...v1.79.4) (2025-09-30)




### Bug Fixes:

* Core: Fixed updating connection time status based on linked signature data. Fixed FR gas sites parsing.

## [v1.79.3](https://github.com/wanderer-industries/wanderer/compare/v1.79.2...v1.79.3) (2025-09-27)




### Bug Fixes:

* Core: Fixed connection passages count

## [v1.79.2](https://github.com/wanderer-industries/wanderer/compare/v1.79.1...v1.79.2) (2025-09-26)




## [v1.79.1](https://github.com/wanderer-industries/wanderer/compare/v1.79.0...v1.79.1) (2025-09-26)




## [v1.79.0](https://github.com/wanderer-industries/wanderer/compare/v1.78.1...v1.79.0) (2025-09-26)




### Features:

* Core: Updated connections EOL logic

### Bug Fixes:

* Map: Fixed eslint problems

* Map: Update lifetime design and buttons

* Map: Update wormhole lifetime UI and removed unnecessary code

## [v1.78.1](https://github.com/wanderer-industries/wanderer/compare/v1.78.0...v1.78.1) (2025-09-24)




### Bug Fixes:

* pr feedback

* removed wormhole only logic error

## [v1.78.0](https://github.com/wanderer-industries/wanderer/compare/v1.77.19...v1.78.0) (2025-09-23)




### Features:

* Core: added support for jumpgates connection type

### Bug Fixes:

* Map: Add support for Bridge. Made all tooltips left and right paddings.

## [v1.77.19](https://github.com/wanderer-industries/wanderer/compare/v1.77.18...v1.77.19) (2025-09-14)




### Bug Fixes:

* Map: Fixed for all Large wormholes jump mass from 300 to 375. Fixed jump mass and total mass for N290, K329. Fixed static for J005663 was H296 now Y790. Added J492 wormhole. Change lifetime for E587 from 16 to 48

## [v1.77.18](https://github.com/wanderer-industries/wanderer/compare/v1.77.17...v1.77.18) (2025-09-13)




## [v1.77.17](https://github.com/wanderer-industries/wanderer/compare/v1.77.16...v1.77.17) (2025-09-11)




### Bug Fixes:

* Updated ACL create/update APIs

## [v1.77.16](https://github.com/wanderer-industries/wanderer/compare/v1.77.15...v1.77.16) (2025-09-11)




### Bug Fixes:

* Fixed issue with ACL add members button for managers. Added WANDERER_RESTRICT_ACLS_CREATION env support.

## [v1.77.15](https://github.com/wanderer-industries/wanderer/compare/v1.77.14...v1.77.15) (2025-09-10)




### Bug Fixes:

* Map: Fix problem with unnecessary rerenders and loads routes if move/positioning widgets.

## [v1.77.14](https://github.com/wanderer-industries/wanderer/compare/v1.77.13...v1.77.14) (2025-09-08)




### Bug Fixes:

* Fixed issue with loading connection info

## [v1.77.13](https://github.com/wanderer-industries/wanderer/compare/v1.77.12...v1.77.13) (2025-09-07)




### Bug Fixes:

* Updated character tracking, added an extra check for offline characters to reduce errors

## [v1.77.12](https://github.com/wanderer-industries/wanderer/compare/v1.77.11...v1.77.12) (2025-09-07)




### Bug Fixes:

* Decreased character tracking grace period

## [v1.77.11](https://github.com/wanderer-industries/wanderer/compare/v1.77.10...v1.77.11) (2025-09-07)




### Bug Fixes:

* Fixed CSP errors

## [v1.77.10](https://github.com/wanderer-industries/wanderer/compare/v1.77.9...v1.77.10) (2025-09-04)




### Bug Fixes:

* Removed invalid invite options

## [v1.77.9](https://github.com/wanderer-industries/wanderer/compare/v1.77.8...v1.77.9) (2025-09-04)




### Bug Fixes:

* Auto select following char system on start

## [v1.77.8](https://github.com/wanderer-industries/wanderer/compare/v1.77.7...v1.77.8) (2025-09-03)




### Bug Fixes:

* Updated character tracking

## [v1.77.7](https://github.com/wanderer-industries/wanderer/compare/v1.77.6...v1.77.7) (2025-09-03)




### Bug Fixes:

* Updated character tracking

## [v1.77.6](https://github.com/wanderer-industries/wanderer/compare/v1.77.5...v1.77.6) (2025-09-02)




### Bug Fixes:

* Updated character tracking, added grace period to reduce false-positive cases

## [v1.77.5](https://github.com/wanderer-industries/wanderer/compare/v1.77.4...v1.77.5) (2025-09-02)




### Bug Fixes:

* resolve tracking issues

## [v1.77.4](https://github.com/wanderer-industries/wanderer/compare/v1.77.3...v1.77.4) (2025-09-02)




### Bug Fixes:

* pr feedback

* ensure pub/sub occurs after acl api change

## [v1.77.3](https://github.com/wanderer-industries/wanderer/compare/v1.77.2...v1.77.3) (2025-08-29)




### Bug Fixes:

* Fixed character tracking settings

* Fixed character tracking settings

* Fixed character tracking settings

* Fixed character tracking settings

## [v1.77.2](https://github.com/wanderer-industries/wanderer/compare/v1.77.1...v1.77.2) (2025-08-28)




### Bug Fixes:

* update system signature api to return correct system id

## [v1.77.1](https://github.com/wanderer-industries/wanderer/compare/v1.77.0...v1.77.1) (2025-08-28)




## [v1.77.0](https://github.com/wanderer-industries/wanderer/compare/v1.76.13...v1.77.0) (2025-08-27)




### Features:

* Core: Reduced DB calls to check existing system jumps

## [v1.76.13](https://github.com/wanderer-industries/wanderer/compare/v1.76.12...v1.76.13) (2025-08-27)




### Bug Fixes:

* Core: Fixed maps start timeout

## [v1.76.12](https://github.com/wanderer-industries/wanderer/compare/v1.76.11...v1.76.12) (2025-08-20)




### Bug Fixes:

* Core: Reduced ESI api calls to update character corp/ally info

## [v1.76.11](https://github.com/wanderer-industries/wanderer/compare/v1.76.10...v1.76.11) (2025-08-20)




## [v1.76.10](https://github.com/wanderer-industries/wanderer/compare/v1.76.9...v1.76.10) (2025-08-18)




### Bug Fixes:

* Core: Added character trackers start queue

## [v1.76.9](https://github.com/wanderer-industries/wanderer/compare/v1.76.8...v1.76.9) (2025-08-18)




### Bug Fixes:

* default signature types not being shown

## [v1.76.8](https://github.com/wanderer-industries/wanderer/compare/v1.76.7...v1.76.8) (2025-08-17)




### Bug Fixes:

* Core: added DB connection default timeouts

## [v1.76.7](https://github.com/wanderer-industries/wanderer/compare/v1.76.6...v1.76.7) (2025-08-16)




### Bug Fixes:

* Core: Fixed auth redirect URL

## [v1.76.6](https://github.com/wanderer-industries/wanderer/compare/v1.76.5...v1.76.6) (2025-08-15)




### Bug Fixes:

* empty subscriptions for sse

## [v1.76.5](https://github.com/wanderer-industries/wanderer/compare/v1.76.4...v1.76.5) (2025-08-15)




### Bug Fixes:

* Core: fixed tracking paused issues, fixed user activity data

## [v1.76.4](https://github.com/wanderer-industries/wanderer/compare/v1.76.3...v1.76.4) (2025-08-14)




### Bug Fixes:

* timestamp errors for sse and tracking

## [v1.76.3](https://github.com/wanderer-industries/wanderer/compare/v1.76.2...v1.76.3) (2025-08-14)




## [v1.76.2](https://github.com/wanderer-industries/wanderer/compare/v1.76.1...v1.76.2) (2025-08-14)




## [v1.76.1](https://github.com/wanderer-industries/wanderer/compare/v1.76.0...v1.76.1) (2025-08-13)




### Bug Fixes:

* Map: Fix problem when systems was deselected after change tab

## [v1.76.0](https://github.com/wanderer-industries/wanderer/compare/v1.75.23...v1.76.0) (2025-08-12)




### Features:

* Signatures: Sync signature temporary name with system on link signature to system

* Signatures: add support for signature temp names

### Bug Fixes:

* Map: Add Temp name field

## [v1.75.20](https://github.com/wanderer-industries/wanderer/compare/v1.75.19...v1.75.20) (2025-08-11)

### Bug Fixes:

* Fixed docs

## [v1.75.4](https://github.com/wanderer-industries/wanderer/compare/v1.75.3...v1.75.4) (2025-08-11)

### Bug Fixes:

* restore security audit

## [v1.75.3](https://github.com/wanderer-industries/wanderer/compare/v1.75.2...v1.75.3) (2025-08-10)

### Bug Fixes:

* core: Fixed character tracking issues

## [v1.75.2](https://github.com/wanderer-industries/wanderer/compare/v1.75.1...v1.75.2) (2025-08-10)

### Bug Fixes:

* Map: Fix indents for ally logos in list "On the map"

* Map: Fix cancelling ping from system context menu

* Map: Hide admin settings tab

* Map: Remote map setting refactoring

## [v1.75.1](https://github.com/wanderer-industries/wanderer/compare/v1.75.0...v1.75.1) (2025-07-30)

### Bug Fixes:

* unable to cancel ping from right click context menu

## [v1.75.0](https://github.com/wanderer-industries/wanderer/compare/v1.74.13...v1.75.0) (2025-07-29)




### Features:

* autoset connection size for c4->null and c13

* apiv1 and tests

* support webhook and sse

* disable webhook/websocket by default

* add websocket and webhooks for events

* Add Jest testing for getState util

### Bug Fixes:

* remove bug with lazy delete

* update broken length and remove verbose logging

* removed old documents

* removed unneeded api, and fixed data comparision bug

* ci comments

* test updates

* properly send sse events

* add test coverage for api

* add more logging around character online and tracking

* clean up SSE warnings

* update env variable usage for sse

* sse cleanup

* remove misleading error

* update killactivity color on nodes

## [v1.74.13](https://github.com/wanderer-industries/wanderer/compare/v1.74.12...v1.74.13) (2025-07-29)




### Bug Fixes:

* Core: Fixed issue with callback url

## [v1.74.11](https://github.com/wanderer-industries/wanderer/compare/v1.74.10...v1.74.11) (2025-07-18)

### Bug Fixes:

* Map: Fixed remove pings for removed systems

## [v1.74.9](https://github.com/wanderer-industries/wanderer/compare/v1.74.8...v1.74.9) (2025-07-13)




### Bug Fixes:

* Map: Trying to fix problem with fast forwarding after page are inactive some time.

## [v1.74.8](https://github.com/wanderer-industries/wanderer/compare/v1.74.7...v1.74.8) (2025-07-11)




### Bug Fixes:

* Map: removed comments

* Map: Fixed conflict

* Map: Unified settings. Second part: Import/Export

* Map: Unified settings. First part: add one place for storing settings

## [v1.74.5](https://github.com/wanderer-industries/wanderer/compare/v1.74.4...v1.74.5) (2025-07-09)




### Bug Fixes:

* Map: Add background for Pochven's systems. Changed from Region name to constellation name for pochven systems. Changed connection style for gates (display like common connection). Changed behaviour of connections.

## [v1.74.4](https://github.com/wanderer-industries/wanderer/compare/v1.74.3...v1.74.4) (2025-07-07)




### Bug Fixes:

* Core: Fixed issue with update system positions

## [v1.74.3](https://github.com/wanderer-industries/wanderer/compare/v1.74.2...v1.74.3) (2025-07-06)




### Bug Fixes:

* Core: Fixed issues with map subscription component

## [v1.74.2](https://github.com/wanderer-industries/wanderer/compare/v1.74.1...v1.74.2) (2025-06-30)




### Bug Fixes:

* Core: Fixed map loading for not existing maps

## [v1.74.1](https://github.com/wanderer-industries/wanderer/compare/v1.74.0...v1.74.1) (2025-06-28)




### Bug Fixes:

* Core: Mark connections between Pochven systems as known.

## [v1.74.0](https://github.com/wanderer-industries/wanderer/compare/v1.73.0...v1.74.0) (2025-06-25)




### Features:

* Core: Reverted showing linked signature ID as part of temporary names

## [v1.73.0](https://github.com/wanderer-industries/wanderer/compare/v1.72.1...v1.73.0) (2025-06-25)




### Features:

* Core: Allowed system temp names up to 12 characters. Deprecated showing linked signature ID as part of temporary name.

## [v1.72.1](https://github.com/wanderer-industries/wanderer/compare/v1.72.0...v1.72.1) (2025-06-23)




### Bug Fixes:

* issue with tracking signature activity

## [v1.72.0](https://github.com/wanderer-industries/wanderer/compare/v1.71.3...v1.72.0) (2025-06-21)




### Features:

* Core: Added an ability to see & topup map balance and map subscription info (on public)

## [v1.71.3](https://github.com/wanderer-industries/wanderer/compare/v1.71.2...v1.71.3) (2025-06-21)




### Bug Fixes:

* Map: Fix incorrect placing of labels

## [v1.71.2](https://github.com/wanderer-industries/wanderer/compare/v1.71.1...v1.71.2) (2025-06-20)




### Bug Fixes:

* fix issue with kill service disconnect

## [v1.71.1](https://github.com/wanderer-industries/wanderer/compare/v1.71.0...v1.71.1) (2025-06-19)




### Bug Fixes:

* update system kills widget timing

## [v1.71.0](https://github.com/wanderer-industries/wanderer/compare/v1.70.7...v1.71.0) (2025-06-19)




### Features:

* use external services for kill data

### Bug Fixes:

* remove duplicate kills connections

* Fixed kills clinet init & map start/update logic

* avoid duplicate subs, and remove subs on inactive maps

## [v1.70.7](https://github.com/wanderer-industries/wanderer/compare/v1.70.6...v1.70.7) (2025-06-18)




### Bug Fixes:

* Subscriptions: Added option to topup using ALL user balance available

## [v1.70.5](https://github.com/wanderer-industries/wanderer/compare/v1.70.4...v1.70.5) (2025-06-17)




### Bug Fixes:

* Core: Fixed character caching issues

## [v1.70.4](https://github.com/wanderer-industries/wanderer/compare/v1.70.3...v1.70.4) (2025-06-16)




### Bug Fixes:

* Core: Distribute tracking to minimal pool first

## [v1.70.3](https://github.com/wanderer-industries/wanderer/compare/v1.70.2...v1.70.3) (2025-06-16)




### Bug Fixes:

* Core: Don't pause tracking for new pools

## [v1.70.2](https://github.com/wanderer-industries/wanderer/compare/v1.70.1...v1.70.2) (2025-06-15)




### Bug Fixes:

* Core: Invalidate character copr and ally data on map server start

## [v1.70.1](https://github.com/wanderer-industries/wanderer/compare/v1.70.0...v1.70.1) (2025-06-14)




### Bug Fixes:

* resolve api issue with custom name

## [v1.70.0](https://github.com/wanderer-industries/wanderer/compare/v1.69.1...v1.70.0) (2025-06-11)




### Features:

* Core: Fix admin page error

## [v1.69.0](https://github.com/wanderer-industries/wanderer/compare/v1.68.6...v1.69.0) (2025-06-11)




### Features:

* Core: Added multiple tracking pools support

## [v1.68.5](https://github.com/wanderer-industries/wanderer/compare/v1.68.4...v1.68.5) (2025-06-10)




### Bug Fixes:

* Core: Fixed updating map options

## [v1.68.2](https://github.com/wanderer-industries/wanderer/compare/v1.68.1...v1.68.2) (2025-06-09)




### Bug Fixes:

* Core: Fixed character auth with wallet (on characters page)

## [v1.68.1](https://github.com/wanderer-industries/wanderer/compare/v1.68.0...v1.68.1) (2025-06-09)




### Bug Fixes:

* Core: Fixed auth from welcome page if invites disabled

## [v1.68.0](https://github.com/wanderer-industries/wanderer/compare/v1.67.5...v1.68.0) (2025-06-09)




### Features:

* Core: Added invites store support

## [v1.67.5](https://github.com/wanderer-industries/wanderer/compare/v1.67.4...v1.67.5) (2025-06-08)




### Bug Fixes:

* Core: Added back ARM docker image build

## [v1.67.4](https://github.com/wanderer-industries/wanderer/compare/v1.67.3...v1.67.4) (2025-06-08)




### Bug Fixes:

* Core: Fixed issue with system splash updates

## [v1.67.3](https://github.com/wanderer-industries/wanderer/compare/v1.67.2...v1.67.3) (2025-06-08)




### Bug Fixes:

* Core: Fixed issue with system splash updates

## [v1.67.0](https://github.com/wanderer-industries/wanderer/compare/v1.66.25...v1.67.0) (2025-06-08)




### Features:

* Core: Added support for WANDERER_CHARACTER_TRACKING_PAUSE_DISABLED env variable to pause inactive character trackers

## [v1.66.25](https://github.com/wanderer-industries/wanderer/compare/v1.66.24...v1.66.25) (2025-06-08)




### Bug Fixes:

* Core: Disabled kills fetching based on env settings

## [v1.66.21](https://github.com/wanderer-industries/wanderer/compare/v1.66.20...v1.66.21) (2025-06-07)




### Bug Fixes:

* Core: Fixed kills fetching based on env settings

## [v1.66.19](https://github.com/wanderer-industries/wanderer/compare/v1.66.18...v1.66.19) (2025-06-07)




### Bug Fixes:

* Core: Added check for offline characters timeouts

## [v1.66.17](https://github.com/wanderer-industries/wanderer/compare/v1.66.16...v1.66.17) (2025-06-07)




### Bug Fixes:

* Core: Increased tracking pause timeout for offline characters up to 10 hours

## [v1.66.16](https://github.com/wanderer-industries/wanderer/compare/v1.66.15...v1.66.16) (2025-06-07)




### Bug Fixes:

* Core: Increased tracking pause timeout for offline characters up to 10 hours

## [v1.66.15](https://github.com/wanderer-industries/wanderer/compare/v1.66.14...v1.66.15) (2025-06-07)




### Bug Fixes:

* Core: Added back arm docker image build

## [v1.66.14](https://github.com/wanderer-industries/wanderer/compare/v1.66.13...v1.66.14) (2025-06-07)




### Bug Fixes:

* Core: fixed online updates

## [v1.66.13](https://github.com/wanderer-industries/wanderer/compare/v1.66.12...v1.66.13) (2025-06-07)




### Bug Fixes:

* Core: fixed location tracking issues

## [v1.66.11](https://github.com/wanderer-industries/wanderer/compare/v1.66.10...v1.66.11) (2025-06-06)




### Bug Fixes:

* Core: fixed refresh character tokens

## [v1.66.8](https://github.com/wanderer-industries/wanderer/compare/v1.66.7...v1.66.8) (2025-06-06)




### Bug Fixes:

* fixed disable detailed kills env check

## [v1.66.7](https://github.com/wanderer-industries/wanderer/compare/v1.66.6...v1.66.7) (2025-06-06)




### Bug Fixes:

* fixed disable detailed kills env check

## [v1.66.6](https://github.com/wanderer-industries/wanderer/compare/v1.66.5...v1.66.6) (2025-06-06)




### Bug Fixes:

* respect error limits for ESI APIs

## [v1.66.5](https://github.com/wanderer-industries/wanderer/compare/v1.66.4...v1.66.5) (2025-06-06)




### Bug Fixes:

* respect error limits for ESI APIs

## [v1.66.4](https://github.com/wanderer-industries/wanderer/compare/v1.66.3...v1.66.4) (2025-06-06)




### Bug Fixes:

* respect error limits for ESI APIs

## [v1.66.1](https://github.com/wanderer-industries/wanderer/compare/v1.66.0...v1.66.1) (2025-06-05)




### Bug Fixes:

* remove bugs with signature deletion

## [v1.66.0](https://github.com/wanderer-industries/wanderer/compare/v1.65.24...v1.66.0) (2025-06-05)




### Features:

* show deleted signatures during undo timer

### Bug Fixes:

* remove callbacks from effect dependencies

## [v1.65.24](https://github.com/wanderer-industries/wanderer/compare/v1.65.23...v1.65.24) (2025-06-04)




### Bug Fixes:

* Core: Fixed errors duration check to reduce requests amount to ESI

## [v1.65.23](https://github.com/wanderer-industries/wanderer/compare/v1.65.22...v1.65.23) (2025-06-04)




### Bug Fixes:

* Core: Added back arm docker image build

## [v1.65.22](https://github.com/wanderer-industries/wanderer/compare/v1.65.21...v1.65.22) (2025-06-04)




### Bug Fixes:

* Core: Fix character tracking issues

## [v1.65.21](https://github.com/wanderer-industries/wanderer/compare/v1.65.20...v1.65.21) (2025-06-01)




### Bug Fixes:

* Core: Fix connection pool errors

## [v1.65.20](https://github.com/wanderer-industries/wanderer/compare/v1.65.19...v1.65.20) (2025-06-01)




### Bug Fixes:

* Core: fix waypoint set timeout errors

## [v1.65.19](https://github.com/wanderer-industries/wanderer/compare/v1.65.18...v1.65.19) (2025-06-01)




### Bug Fixes:

* Core: fix updating character online

## [v1.65.18](https://github.com/wanderer-industries/wanderer/compare/v1.65.17...v1.65.18) (2025-05-30)




### Bug Fixes:

* Core: fix updating systems and connections

## [v1.65.17](https://github.com/wanderer-industries/wanderer/compare/v1.65.16...v1.65.17) (2025-05-29)




### Bug Fixes:

* Core: fix updating systems and connections

* Comments: fix error loading comments

## [v1.65.16](https://github.com/wanderer-industries/wanderer/compare/v1.65.15...v1.65.16) (2025-05-29)




### Bug Fixes:

* Map: Allow lock systems for members

## [v1.65.13](https://github.com/wanderer-industries/wanderer/compare/v1.65.12...v1.65.13) (2025-05-28)




### Bug Fixes:

* Signatures: small wh size is now passed from signature to connection

## [v1.65.12](https://github.com/wanderer-industries/wanderer/compare/v1.65.11...v1.65.12) (2025-05-27)




### Bug Fixes:

* Map: Fixed showing character ship

## [v1.65.11](https://github.com/wanderer-industries/wanderer/compare/v1.65.10...v1.65.11) (2025-05-27)




### Bug Fixes:

* Map: Fixed showing character ship

## [v1.65.10](https://github.com/wanderer-industries/wanderer/compare/v1.65.9...v1.65.10) (2025-05-27)




### Bug Fixes:

* Map: Fixed sorting for characters in Local

* Map: Rally: fixed conflict style of status and rally

* Core: Fixed character token refresh

* Map: Add Rally point. Change placement of settings in Map User Settings. Add ability to placement minimap.

* Map: Routes - hide user routes btn from context if subscriptions is not active or widget is closed. Also now hidden widget will show again in place where it was on moment of hide (except cases when screen size has changed.

* Map: PINGS - Rally point first prototype

## [v1.65.7](https://github.com/wanderer-industries/wanderer/compare/v1.65.6...v1.65.7) (2025-05-26)




### Bug Fixes:

* Core: Fixed map character tracking issues

## [v1.65.6](https://github.com/wanderer-industries/wanderer/compare/v1.65.5...v1.65.6) (2025-05-26)




### Bug Fixes:

* Core: Fixed map character tracking issues

## [v1.65.5](https://github.com/wanderer-industries/wanderer/compare/v1.65.4...v1.65.5) (2025-05-26)




### Bug Fixes:

* Core: Fixed map character tracking issues

* Signature: Update restored signature character

## [v1.65.4](https://github.com/wanderer-industries/wanderer/compare/v1.65.3...v1.65.4) (2025-05-24)




### Bug Fixes:

* Signature: Force signature update even if there are no any changes

## [v1.65.3](https://github.com/wanderer-industries/wanderer/compare/v1.65.2...v1.65.3) (2025-05-23)




### Bug Fixes:

* Signature: Fixed signature clenup

## [v1.65.2](https://github.com/wanderer-industries/wanderer/compare/v1.65.1...v1.65.2) (2025-05-23)




### Bug Fixes:

* Signature: Fixed signature updates

## [v1.65.1](https://github.com/wanderer-industries/wanderer/compare/v1.65.0...v1.65.1) (2025-05-22)




### Bug Fixes:

* Core: Added unsync map events timeout handling (force page refresh if outdated map events found)

## [v1.65.0](https://github.com/wanderer-industries/wanderer/compare/v1.64.8...v1.65.0) (2025-05-22)




### Features:

* default connections from c1 holes to medium size

* support german and french signatures

* improve signature undo process

### Bug Fixes:

* remove required id field from character schema

* update openapi spec response types

* fix issue with connection generation between k-space

* Signature: Fixed signatures updates

* update openapi spec for other apis

## [v1.64.8](https://github.com/wanderer-industries/wanderer/compare/v1.64.7...v1.64.8) (2025-05-20)




### Bug Fixes:

* Core: Added unsync map events timeout handling (force page refresh if outdated map events found)

## [v1.64.7](https://github.com/wanderer-industries/wanderer/compare/v1.64.6...v1.64.7) (2025-05-15)




### Bug Fixes:

* Core: Fixed connection EOL time refreshed every 2 minutes

## [v1.64.6](https://github.com/wanderer-industries/wanderer/compare/v1.64.5...v1.64.6) (2025-05-15)




### Bug Fixes:

* Core: Added map hubs limits checking & a proper warning message shown

## [v1.64.5](https://github.com/wanderer-industries/wanderer/compare/v1.64.4...v1.64.5) (2025-05-14)




### Bug Fixes:

* Core: Added character name update on re-auth

## [v1.64.4](https://github.com/wanderer-industries/wanderer/compare/v1.64.3...v1.64.4) (2025-05-14)




### Bug Fixes:

* Core: Added 1 min timeout for ship and location updates on ESI API errors

## [v1.64.3](https://github.com/wanderer-industries/wanderer/compare/v1.64.2...v1.64.3) (2025-05-14)




### Bug Fixes:

* Core: Fixed character tracking initialization logic & removed search caching

## [v1.64.2](https://github.com/wanderer-industries/wanderer/compare/v1.64.1...v1.64.2) (2025-05-13)




### Bug Fixes:

* Core: Fixed tracking of ship & location for offline characters

## [v1.64.1](https://github.com/wanderer-industries/wanderer/compare/v1.64.0...v1.64.1) (2025-05-13)




### Bug Fixes:

* Core: Fixed tracking stopped due to server errors

## [v1.64.0](https://github.com/wanderer-industries/wanderer/compare/v1.63.0...v1.64.0) (2025-05-13)




### Features:

* api: add additional structure/signature methods (#365)

* api: add additional system/connections methods (#351)

### Bug Fixes:

* Core: Fixed EOL connections cleanup

* Core: Avoid Zarzakh system in routes widget

* remove repeat errors for token refresh (#375)

* updated openapi spec for character activity (#374)

* removed error from characters endpoint, and updated routes (#372)

* cleanup examples for system and connections (#370)

* remove error on websocket reconnect (#367)

## [v1.63.0](https://github.com/wanderer-industries/wanderer/compare/v1.62.4...v1.63.0) (2025-05-11)




### Features:

* Core: Updated map active characters page

## [v1.62.4](https://github.com/wanderer-industries/wanderer/compare/v1.62.3...v1.62.4) (2025-05-10)




### Bug Fixes:

* Core: Fixed map characters got untracked

## [v1.62.3](https://github.com/wanderer-industries/wanderer/compare/v1.62.2...v1.62.3) (2025-05-08)




### Bug Fixes:

* Core: Fixed map characters got untracked

## [v1.62.2](https://github.com/wanderer-industries/wanderer/compare/v1.62.1...v1.62.2) (2025-05-05)




### Bug Fixes:

* Core: Fixed audit export API

## [v1.62.0](https://github.com/wanderer-industries/wanderer/compare/v1.61.2...v1.62.0) (2025-05-05)




### Features:

* Core: added user routes support

### Bug Fixes:

* Map: Fixed link signature modal crash afrer destination system removed

* Map: Change design for tags (#358)

* Map: Removed paywall restriction from public routes

* Core: Fixed issues with structures loading

* Map: Removed unnecessary logs

* Map: Add support user routes

* Map: Add support for User Routes on FE side.

* Map: Refactor Local - show ship name, change placement of ship name. Refactor On the Map - show corp and ally logo. Fixed problem with ellipsis at long character and ship names.

* Map: Refactored routes widget. Add loader for routes. Prepared for custom hubs

* Map: Refactor init and update of mapper

## [v1.61.2](https://github.com/wanderer-industries/wanderer/compare/v1.61.1...v1.61.2) (2025-04-29)




### Bug Fixes:

* Core: Fixed main character checking & manual systems delete logic

## [v1.61.1](https://github.com/wanderer-industries/wanderer/compare/v1.61.0...v1.61.1) (2025-04-26)




### Bug Fixes:

* Core: Fixed additional price calc for map sub updates

## [v1.61.0](https://github.com/wanderer-industries/wanderer/compare/v1.60.1...v1.61.0) (2025-04-24)




### Features:

* Core: force checking main character set for all map activity

## [v1.60.1](https://github.com/wanderer-industries/wanderer/compare/v1.60.0...v1.60.1) (2025-04-22)




### Bug Fixes:

* Map: Removed unnecessary code onFE part

* Map: Removed unnecessary debugger

* Map: Changed name for drifters systems. Fixed static info for Barbican.

## [v1.60.0](https://github.com/wanderer-industries/wanderer/compare/v1.59.11...v1.60.0) (2025-04-17)




### Features:

* api: api showing character by user and main character (#334)

* Core: force map page reload after 30 mins of user inactivity (switched browser/tab)

* update character activity to use main character (#333)

## [v1.59.11](https://github.com/wanderer-industries/wanderer/compare/v1.59.10...v1.59.11) (2025-04-16)




### Bug Fixes:

* Map: Fixed lifetime for A009 from 16h to 4.5h. Fixed problem with no appearing icon of shattered for Drifter wormholes. Fixed wanderings for Drifter wormholes. For system J011355 added static K346. For system J011824 added static K346. (#329)

## [v1.59.9](https://github.com/wanderer-industries/wanderer/compare/v1.59.8...v1.59.9) (2025-04-15)




### Bug Fixes:

* Core: Fixed issues with map server manager

## [v1.59.8](https://github.com/wanderer-industries/wanderer/compare/v1.59.7...v1.59.8) (2025-04-15)




### Bug Fixes:

* Core: Fixed issues with main character & tracking

## [v1.59.7](https://github.com/wanderer-industries/wanderer/compare/v1.59.6...v1.59.7) (2025-04-14)




### Bug Fixes:

* Core: Fixed auto-select splashed systems

## [v1.59.6](https://github.com/wanderer-industries/wanderer/compare/v1.59.5...v1.59.6) (2025-04-13)




### Bug Fixes:

* Map: Fix icons of main, follow and shattered (#321)

## [v1.59.5](https://github.com/wanderer-industries/wanderer/compare/v1.59.4...v1.59.5) (2025-04-12)




### Bug Fixes:

* Signatures: avoid signatures delete on wrong buffer

## [v1.59.2](https://github.com/wanderer-industries/wanderer/compare/v1.59.1...v1.59.2) (2025-04-10)




### Bug Fixes:

* Core: fixed connection validation

## [v1.59.1](https://github.com/wanderer-industries/wanderer/compare/v1.59.0...v1.59.1) (2025-03-26)




### Bug Fixes:

* doc: improve bot setup instructions (#309)

## [v1.59.0](https://github.com/wanderer-industries/wanderer/compare/v1.58.0...v1.59.0) (2025-03-23)




### Features:

* Core: added handling cases when wrong connections created

## [v1.58.0](https://github.com/wanderer-industries/wanderer/compare/v1.57.1...v1.58.0) (2025-03-22)




### Features:

* Core: Show online state on map characters page

* api: update character activity and api to allow date range (#299)

* api: update character activity and api to allow date range

## [v1.57.0](https://github.com/wanderer-industries/wanderer/compare/v1.56.6...v1.57.0) (2025-03-19)




### Features:

* doc: update bot news (#294)

## [v1.56.3](https://github.com/wanderer-industries/wanderer/compare/v1.56.2...v1.56.3) (2025-03-19)




### Bug Fixes:

* cloak key error behavior (#288)

## [v1.56.2](https://github.com/wanderer-industries/wanderer/compare/v1.56.1...v1.56.2) (2025-03-18)




### Bug Fixes:

* show signature tooltip on top

## [v1.56.1](https://github.com/wanderer-industries/wanderer/compare/v1.56.0...v1.56.1) (2025-03-18)




### Bug Fixes:

* update activity api (#284)

* qol updates for dev (#283)

## [v1.56.0](https://github.com/wanderer-industries/wanderer/compare/v1.55.2...v1.56.0) (2025-03-17)




### Features:

* add static wh info (#262)

* add static wh info

* api: add character activity api (#263)

* api: add character activity api

### Bug Fixes:

* character activity hide error

* character added to map on follow (#272)

## [v1.55.2](https://github.com/wanderer-industries/wanderer/compare/v1.55.1...v1.55.2) (2025-03-16)




### Bug Fixes:

* Core: fixed lazy delete reset state

## [v1.55.1](https://github.com/wanderer-industries/wanderer/compare/v1.55.0...v1.55.1) (2025-03-16)




### Bug Fixes:

* Core: fixed lazy delete timeouts

* Core: fixed lazy delete settings

* keep character api off by default (#258)

## [v1.55.0](https://github.com/wanderer-industries/wanderer/compare/v1.54.1...v1.55.0) (2025-03-15)




### Features:

* News: added map subscription news

* Api: added map audit base API. Added comments server validations.

* enhance character activty and summmarize by user (#206)

* enhance character activty and summmarize by user (#206)

### Bug Fixes:

* Core: updated balance top up instructions

* updated connections cleanup logic

* removed placeholder favicon (#240)

* fixed activity aggregation and new user tracking (#230)

* fixed activity aggregation and new user tracking (#230)

* fixed activity aggregation and new user tracking (#230)

* fixed activity aggregation and new user tracking (#230)

## [v1.54.1](https://github.com/wanderer-industries/wanderer/compare/v1.54.0...v1.54.1) (2025-03-06)




### Bug Fixes:

* fix scroll and size issues with kills widget (#219)

* fix scroll and size issues with kills widget

## [v1.54.0](https://github.com/wanderer-industries/wanderer/compare/v1.53.4...v1.54.0) (2025-03-05)




### Features:

* added auto-refresh timeout for cloud new version updates

* add selectable sig deletion timing, and color options (#208)

## [v1.53.4](https://github.com/wanderer-industries/wanderer/compare/v1.53.3...v1.53.4) (2025-03-04)




### Bug Fixes:

* add retry on kills retrieval (#207)

* add missing masses to wh sizes const (#215)

## [v1.53.3](https://github.com/wanderer-industries/wanderer/compare/v1.53.2...v1.53.3) (2025-02-27)




### Bug Fixes:

* Map: little bit up performance for windows manager

## [v1.53.1](https://github.com/wanderer-industries/wanderer/compare/v1.53.0...v1.53.1) (2025-02-26)




### Bug Fixes:

* Core: Fixed map ACLs add/remove behaviour

## [v1.53.0](https://github.com/wanderer-industries/wanderer/compare/v1.52.8...v1.53.0) (2025-02-26)




### Features:

* Auto-set connection EOL status and ship size when linking/editing signatures (#194)

* Automatically set connection EOL status and ship size type when linking/updating signatures

## [v1.52.8](https://github.com/wanderer-industries/wanderer/compare/v1.52.7...v1.52.8) (2025-02-26)




### Bug Fixes:

* Map: Added delete systems hotkey

## [v1.52.7](https://github.com/wanderer-industries/wanderer/compare/v1.52.6...v1.52.7) (2025-02-24)




### Bug Fixes:

* update news image link (#204)

* Map: Block map events for old client versions

## [v1.52.6](https://github.com/wanderer-industries/wanderer/compare/v1.52.5...v1.52.6) (2025-02-23)




### Bug Fixes:

* Map: Fixed delete systems on map changes

## [v1.52.5](https://github.com/wanderer-industries/wanderer/compare/v1.52.4...v1.52.5) (2025-02-22)




### Bug Fixes:

* Map: Fixed delete system on signature deletion

* Map: Fixed delete system on signature deletion

## [v1.52.4](https://github.com/wanderer-industries/wanderer/compare/v1.52.3...v1.52.4) (2025-02-21)




### Bug Fixes:

* signature paste for russian lang

## [v1.52.3](https://github.com/wanderer-industries/wanderer/compare/v1.52.2...v1.52.3) (2025-02-21)




### Bug Fixes:

* remove signature expiration (#196)

## [v1.52.2](https://github.com/wanderer-industries/wanderer/compare/v1.52.1...v1.52.2) (2025-02-21)




### Bug Fixes:

* prevent constant full signature widget rerender (#195)

## [v1.52.1](https://github.com/wanderer-industries/wanderer/compare/v1.52.0...v1.52.1) (2025-02-20)




### Bug Fixes:

* proper virtual scroller usage (#192)

* restore delete key functionality for nodes (#191)

## [v1.52.0](https://github.com/wanderer-industries/wanderer/compare/v1.51.3...v1.52.0) (2025-02-19)




### Features:

* Map: Added map characters view

## [v1.51.3](https://github.com/wanderer-industries/wanderer/compare/v1.51.2...v1.51.3) (2025-02-19)




### Bug Fixes:

* pending deletion working again (#185)

## [v1.51.0](https://github.com/wanderer-industries/wanderer/compare/v1.50.0...v1.51.0) (2025-02-17)




### Features:

* add undo deletion for signatures (#155)

* add undo for signature deletion and addition

## [v1.50.0](https://github.com/wanderer-industries/wanderer/compare/v1.49.0...v1.50.0) (2025-02-17)




### Features:

* allow addition of characters to acl without preregistration (#176)

## [v1.49.0](https://github.com/wanderer-industries/wanderer/compare/v1.48.1...v1.49.0) (2025-02-15)




### Features:

* add api for acl management (#171)

## [v1.48.0](https://github.com/wanderer-industries/wanderer/compare/v1.47.6...v1.48.0) (2025-02-12)




### Features:

* autosize local character tooltip and increase hover target (#165)

## [v1.47.5](https://github.com/wanderer-industries/wanderer/compare/v1.47.4...v1.47.5) (2025-02-12)




### Bug Fixes:

* sync kills count bookmark and the kills widget (#160)

* lazy load kills widget

## [v1.47.2](https://github.com/wanderer-industries/wanderer/compare/v1.47.1...v1.47.2) (2025-02-11)




### Bug Fixes:

* lazy load kills widget (#157)

* lazy load kills widget

* updates for eslint and pr feedback

## [v1.47.1](https://github.com/wanderer-industries/wanderer/compare/v1.47.0...v1.47.1) (2025-02-09)




### Bug Fixes:

* Connections: Fixed connections auto-refresh after update

## [v1.47.0](https://github.com/wanderer-industries/wanderer/compare/v1.46.1...v1.47.0) (2025-02-09)




### Features:

* Map: Added check for active map subscription to using Map APIs

## [v1.46.1](https://github.com/wanderer-industries/wanderer/compare/v1.46.0...v1.46.1) (2025-02-09)




### Bug Fixes:

* Map: Fixed a lot of design and architect issues after last milliâ¦ (#154)

* Map: Fixed a lot of design and architect issues after last million PRs

* Map: removed unnecessary hooks styles

## [v1.46.0](https://github.com/wanderer-industries/wanderer/compare/v1.45.5...v1.46.0) (2025-02-08)




### Features:

* Added WANDERER_RESTRICT_MAPS_CREATION env support

## [v1.45.5](https://github.com/wanderer-industries/wanderer/compare/v1.45.4...v1.45.5) (2025-02-07)




### Bug Fixes:

* restore styling for local characters list (#152)

## [v1.45.4](https://github.com/wanderer-industries/wanderer/compare/v1.45.3...v1.45.4) (2025-02-07)




### Bug Fixes:

* remove snap to grid customization (#153)

## [v1.45.3](https://github.com/wanderer-industries/wanderer/compare/v1.45.2...v1.45.3) (2025-02-05)




### Bug Fixes:

* color and formatting fixes for local character (#150)

## [v1.45.2](https://github.com/wanderer-industries/wanderer/compare/v1.45.1...v1.45.2) (2025-02-05)




### Bug Fixes:

* fix route list hover and on the map character list (#149)

* correct formatting for on the map character list

* fix hover for route list

## [v1.45.1](https://github.com/wanderer-industries/wanderer/compare/v1.45.0...v1.45.1) (2025-02-05)




### Bug Fixes:

* kill count subscript position on firefox, and remove kill filter for single system (#148)

## [v1.45.0](https://github.com/wanderer-industries/wanderer/compare/v1.44.9...v1.45.0) (2025-02-05)




### Features:

* allow filtering of k-space kills (#147)

## [v1.44.9](https://github.com/wanderer-industries/wanderer/compare/v1.44.8...v1.44.9) (2025-02-04)




### Bug Fixes:

* improve local character header shrink behavior (#146)

## [v1.44.8](https://github.com/wanderer-industries/wanderer/compare/v1.44.7...v1.44.8) (2025-02-04)




### Bug Fixes:

* Core: include external libraries in build

## [v1.44.7](https://github.com/wanderer-industries/wanderer/compare/v1.44.6...v1.44.7) (2025-02-04)




### Bug Fixes:

* Core: include external libraries in build

## [v1.44.5](https://github.com/wanderer-industries/wanderer/compare/v1.44.4...v1.44.5) (2025-02-04)




### Bug Fixes:

* include category param in search cache key (#144)

## [v1.44.3](https://github.com/wanderer-industries/wanderer/compare/v1.44.2...v1.44.3) (2025-02-02)




### Bug Fixes:

* restored kills lightning bolt functionality (#143)

## [v1.44.1](https://github.com/wanderer-industries/wanderer/compare/v1.44.0...v1.44.1) (2025-02-01)




### Bug Fixes:

* Map: Fixed problem with windows. (#140)

* Map: Fixed problem with windows.

* Core: Added min heigth for body

## [v1.44.0](https://github.com/wanderer-industries/wanderer/compare/v1.43.9...v1.44.0) (2025-02-01)




### Features:

* add news post for zkill widget

* add zkill widget

### Bug Fixes:

* design feedback patch

* removed unneeded event handler

## [v1.43.9](https://github.com/wanderer-industries/wanderer/compare/v1.43.8...v1.43.9) (2025-01-30)




### Bug Fixes:

* Core: Add discord link to 'Like' icon on main interface

## [v1.43.8](https://github.com/wanderer-industries/wanderer/compare/v1.43.7...v1.43.8) (2025-01-26)




### Bug Fixes:

* Core: Update shuttered constellations (required EVE DB data update on server).

## [v1.43.6](https://github.com/wanderer-industries/wanderer/compare/v1.43.5...v1.43.6) (2025-01-22)




### Bug Fixes:

* Widgets: Fix widgets not visible on map

## [v1.43.5](https://github.com/wanderer-industries/wanderer/compare/v1.43.4...v1.43.5) (2025-01-22)




### Bug Fixes:

* Audit: Fix signature added/removed system name

## [v1.43.4](https://github.com/wanderer-industries/wanderer/compare/v1.43.3...v1.43.4) (2025-01-21)




### Bug Fixes:

* improve structure widget styling (#127)

## [v1.43.2](https://github.com/wanderer-industries/wanderer/compare/v1.43.1...v1.43.2) (2025-01-21)




### Bug Fixes:

* prevent constraint error for follow/toggle (#132)

## [v1.43.0](https://github.com/wanderer-industries/wanderer/compare/v1.42.5...v1.43.0) (2025-01-20)




### Features:

* add news post for structures widget (#131)

## [v1.42.5](https://github.com/wanderer-industries/wanderer/compare/v1.42.4...v1.42.5) (2025-01-20)




### Bug Fixes:

* Map: Fix link signatures on splash. Fix deleting connection on locked system remove.

## [v1.42.4](https://github.com/wanderer-industries/wanderer/compare/v1.42.3...v1.42.4) (2025-01-20)




### Bug Fixes:

* Fix system statics list (required EVE DB data update). Add system name to signature added/removed audit log

## [v1.42.3](https://github.com/wanderer-industries/wanderer/compare/v1.42.2...v1.42.3) (2025-01-17)




### Bug Fixes:

* change structure tooltip to avoid paste confusion (#125)

* change structure tooltip to avoid paste confusion

* clarify use of evetime and use primereact calendar

## [v1.42.1](https://github.com/wanderer-industries/wanderer/compare/v1.42.0...v1.42.1) (2025-01-16)




### Bug Fixes:

* Map: Remove linked sig ID if system containing signature removed from map

## [v1.42.0](https://github.com/wanderer-industries/wanderer/compare/v1.41.0...v1.42.0) (2025-01-16)




### Features:

* Audit: Add 'Signatures added/removed' map audit events

## [v1.41.0](https://github.com/wanderer-industries/wanderer/compare/v1.40.7...v1.41.0) (2025-01-16)




### Features:

* Audit: Add 'ACL added/removed' map audit events

## [v1.40.6](https://github.com/wanderer-industries/wanderer/compare/v1.40.5...v1.40.6) (2025-01-15)




### Bug Fixes:

* Map: Fix follow mode

* center system is not selected text for structures (#122)

* Map: Fix system revert issues

* Map: Fix issues with splashing signatures select & sig ID in temp names

## [v1.40.5](https://github.com/wanderer-industries/wanderer/compare/v1.40.4...v1.40.5) (2025-01-14)




### Bug Fixes:

* Map: Fix follow mode

## [v1.40.4](https://github.com/wanderer-industries/wanderer/compare/v1.40.3...v1.40.4) (2025-01-14)




### Bug Fixes:

* center system is not selected text for structures (#122)

## [v1.40.3](https://github.com/wanderer-industries/wanderer/compare/v1.40.2...v1.40.3) (2025-01-14)




### Bug Fixes:

* Map: Fix system revert issues

## [v1.40.2](https://github.com/wanderer-industries/wanderer/compare/v1.40.1...v1.40.2) (2025-01-14)




### Bug Fixes:

* Map: Fix issues with splashing signatures select & sig ID in temp names

## [v1.40.0](https://github.com/wanderer-industries/wanderer/compare/v1.39.3...v1.40.0) (2025-01-14)




### Features:

* add structure widget with timer and associated api

## [v1.39.3](https://github.com/wanderer-industries/wanderer/compare/v1.39.2...v1.39.3) (2025-01-14)




### Bug Fixes:

* Map: Add style of corners for windows. Add ability to reset widgets. A lot of refactoring

## [v1.39.1](https://github.com/wanderer-industries/wanderer/compare/v1.39.0...v1.39.1) (2025-01-13)




### Bug Fixes:

* Map: New windows systems

* Map: Add new windows system and removed old

* Map: First prototype of windows

## [v1.39.0](https://github.com/wanderer-industries/wanderer/compare/v1.38.7...v1.39.0) (2025-01-13)




### Features:

* Map: Added option to show signature ID as system temporary name part

## [v1.38.2](https://github.com/wanderer-industries/wanderer/compare/v1.38.1...v1.38.2) (2025-01-11)




### Bug Fixes:

* Fix connections remove timeouts

## [v1.38.1](https://github.com/wanderer-industries/wanderer/compare/v1.38.0...v1.38.1) (2025-01-10)




### Bug Fixes:

* restored default theme colors (#115)

## [v1.38.0](https://github.com/wanderer-industries/wanderer/compare/v1.37.9...v1.38.0) (2025-01-10)




### Features:

* Map: Ability to store/view audit logs up to 3 months

* Map: Inroduced Env settings for connection auto EOL/remove timeouts

## [v1.37.9](https://github.com/wanderer-industries/wanderer/compare/v1.37.8...v1.37.9) (2025-01-10)




### Bug Fixes:

* restore system status colors (#112)

* restore system status colors

## [v1.37.8](https://github.com/wanderer-industries/wanderer/compare/v1.37.7...v1.37.8) (2025-01-10)




### Bug Fixes:

* fix issue with newly added systems not adding a connection (#114)

* resolve issue with newly added systems not connecting

## [v1.37.7](https://github.com/wanderer-industries/wanderer/compare/v1.37.6...v1.37.7) (2025-01-10)




### Bug Fixes:

* support additional theme names

## [v1.37.6](https://github.com/wanderer-industries/wanderer/compare/v1.37.5...v1.37.6) (2025-01-09)




### Bug Fixes:

* support additional theme names

## [v1.37.5](https://github.com/wanderer-industries/wanderer/compare/v1.37.4...v1.37.5) (2025-01-09)




### Bug Fixes:

* restore node styling, simplify framework for new themes

## [v1.37.4](https://github.com/wanderer-industries/wanderer/compare/v1.37.3...v1.37.4) (2025-01-09)




### Bug Fixes:

* Map: Fixed dbclick behaviour

## [v1.37.3](https://github.com/wanderer-industries/wanderer/compare/v1.37.2...v1.37.3) (2025-01-09)




### Bug Fixes:

* Map: Fixed dbclick behaviour

## [v1.37.1](https://github.com/wanderer-industries/wanderer/compare/v1.37.0...v1.37.1) (2025-01-08)




### Bug Fixes:

* add back pathfinder theme font

## [v1.37.0](https://github.com/wanderer-industries/wanderer/compare/v1.36.2...v1.37.0) (2025-01-08)




### Features:

* add theme selection and pathfinder theme

## [v1.36.2](https://github.com/wanderer-industries/wanderer/compare/v1.36.1...v1.36.2) (2025-01-08)




### Bug Fixes:

* Map: Fixed pasting into Name, Custom Label and Description

## [v1.36.1](https://github.com/wanderer-industries/wanderer/compare/v1.36.0...v1.36.1) (2025-01-08)




### Bug Fixes:

* Map: Removed unnecessary comment

* Map: Add support RU signatures and fix filtering

## [v1.36.0](https://github.com/wanderer-industries/wanderer/compare/v1.35.0...v1.36.0) (2025-01-07)




### Features:

* added static system info to api (#101)

* added static system info to api


## [v1.35.0](https://github.com/wanderer-industries/wanderer/compare/v1.34.0...v1.35.0) (2025-01-07)


### Features:

* Map: add "temporary system names" toggle  (#86)

## [v1.34.0](https://github.com/wanderer-industries/wanderer/compare/v1.33.1...v1.34.0) (2025-01-07)




### Features:

* Map: api to allow systematic access to visible systems and tracked characters (#89)

* add limited api for system and tracked characters

## [v1.33.0](https://github.com/wanderer-industries/wanderer/compare/v1.32.7...v1.33.0) (2025-01-07)




### Features:

* Map: api to allow systematic access to visible systems and tracked characters (#89)

* add limited api for system and tracked characters

## [v1.32.5](https://github.com/wanderer-industries/wanderer/compare/v1.32.4...v1.32.5) (2025-01-04)




### Bug Fixes:

* map: prevent deselect on click to map (#96)

## [v1.32.4](https://github.com/wanderer-industries/wanderer/compare/v1.32.3...v1.32.4) (2025-01-02)




### Bug Fixes:

* Map: Fix 'Character Activity' modal

## [v1.32.3](https://github.com/wanderer-industries/wanderer/compare/v1.32.2...v1.32.3) (2025-01-02)




### Bug Fixes:

* Map: Fix 'Allow only tracked characters' saving

## [v1.32.0](https://github.com/wanderer-industries/wanderer/compare/v1.31.0...v1.32.0) (2024-12-24)




### Features:

* Map: Add search & update manual adding systems API

* Map: Add search & update manual adding systems API

### Bug Fixes:

* Map: Added ability to add new system to routes via routes widget

* Map: Reworked add system to map

## [v1.31.0](https://github.com/wanderer-industries/wanderer/compare/v1.30.2...v1.31.0) (2024-12-20)




### Features:

* Core: Show tracking for new users by default. Auto link characters to account fix. Add character loading indicators.

## [v1.30.2](https://github.com/wanderer-industries/wanderer/compare/v1.30.1...v1.30.2) (2024-12-17)




### Bug Fixes:

* Map: Fixed problem with ship size change.

## [v1.30.1](https://github.com/wanderer-industries/wanderer/compare/v1.30.0...v1.30.1) (2024-12-17)




### Bug Fixes:

* Map: Little rework Signatures header: change System Signatures to Signatures, and show selected system name instead.

* Map: update default size of connections

* Map: add ability set the size of wormhole and mark connection with label

## [v1.30.0](https://github.com/wanderer-industries/wanderer/compare/v1.29.5...v1.30.0) (2024-12-16)




### Features:

* Map: Fixed incorrect wrapping labels of checkboxes in System Signatures, Local and Routes. Also changed dotlan links for k-spacem now it leads to region map before, for wh all stay as it was. Added ability to chane to softer background and remove dots on background of map. Also some small design issues. #2

* Map: Fixed incorrect wrapping labels of checkboxes in System Signatures, Local and Routes. Also changed dotlan links for k-spacem now it leads to region map before, for wh all stay as it was. Added ability to chane to softer background and remove dots on background of map. Also some small design issues.

### Bug Fixes:

* Map: fixed U210, K346 for C4 shattered systems

* Map: fixed U210, K346 for shattered systems. Fixed mass of mediums chains. Fixed size of some capital chains from 3M to 3.3M. Based on https://whtype.info/ data.

* Map: removed unnecessary log

* Map: Uncomment what should not be commented

## [v1.29.5](https://github.com/wanderer-industries/wanderer/compare/v1.29.4...v1.29.5) (2024-12-14)




### Bug Fixes:

* Core: Fix character trackers cleanup

## [v1.29.4](https://github.com/wanderer-industries/wanderer/compare/v1.29.3...v1.29.4) (2024-12-10)




### Bug Fixes:

* Core: Small fixes

## [v1.29.3](https://github.com/wanderer-industries/wanderer/compare/v1.29.2...v1.29.3) (2024-12-07)




### Bug Fixes:

* Core: Increased eve DB data download timeout

## [v1.29.2](https://github.com/wanderer-industries/wanderer/compare/v1.29.1...v1.29.2) (2024-12-07)




### Bug Fixes:

* Core: Fix unpkg CDN issues, fix Abyssals sites adding as systems on map

## [v1.29.0](https://github.com/wanderer-industries/wanderer/compare/v1.28.1...v1.29.0) (2024-12-05)




### Features:

* Signatures: Show 'Unsplashed' signatures on the map (optionally)

## [v1.28.0](https://github.com/wanderer-industries/wanderer/compare/v1.27.1...v1.28.0) (2024-12-04)




### Features:

* Map: Added an option to show 'Offline characters' to map admins & managers only

## [v1.27.1](https://github.com/wanderer-industries/wanderer/compare/v1.27.0...v1.27.1) (2024-12-04)




### Bug Fixes:

* Map: Fix 'On the map' visibility

## [v1.27.0](https://github.com/wanderer-industries/wanderer/compare/v1.26.1...v1.27.0) (2024-12-03)




### Features:

* Map: Hide 'On the map' list for 'Viewer' role

## [v1.26.1](https://github.com/wanderer-industries/wanderer/compare/v1.26.0...v1.26.1) (2024-12-03)




### Bug Fixes:

* Signatures: Fix error on splash wh

## [v1.26.0](https://github.com/wanderer-industries/wanderer/compare/v1.25.2...v1.26.0) (2024-12-03)




### Features:

* Signatures: Keep 'Lazy delete' enabled setting

## [v1.25.2](https://github.com/wanderer-industries/wanderer/compare/v1.25.1...v1.25.2) (2024-12-01)




### Bug Fixes:

* Signatures: Fix lazy delete on system switch

## [v1.25.1](https://github.com/wanderer-industries/wanderer/compare/v1.25.0...v1.25.1) (2024-11-28)




### Bug Fixes:

* Signatures: Fix colors & add 'Backspace' hotkey to delete signatures

## [v1.25.0](https://github.com/wanderer-industries/wanderer/compare/v1.24.2...v1.25.0) (2024-11-28)




### Features:

* Signatures: Automatically remove signature if linked system removed

## [v1.24.2](https://github.com/wanderer-industries/wanderer/compare/v1.24.1...v1.24.2) (2024-11-27)




### Bug Fixes:

* Signatures: Fix paste signatures

## [v1.24.0](https://github.com/wanderer-industries/wanderer/compare/v1.23.0...v1.24.0) (2024-11-27)




### Features:

* Signatures: Added "Lazy delete" option & got rid of update popup

## [v1.23.0](https://github.com/wanderer-industries/wanderer/compare/v1.22.0...v1.23.0) (2024-11-26)




### Features:

* Map: Lock systems available to manager/admin roles only (#75)

* Map: Lock systems available to manager/admin roles only

* Map: Fix add system & add acl member select behaviour

## [v1.22.0](https://github.com/wanderer-industries/wanderer/compare/v1.21.0...v1.22.0) (2024-11-26)




### Features:

* Map: Rework design of checkboxes in Signatures settings dialog. Rework design of checkboxes in Routes settings dialog. Now signature will deleteing by Delete hotkey was Backspace. Fixed size of group column in signatures list. Instead Updated column will be Added, updated may be turn on in settings. (#76)

## [v1.21.0](https://github.com/wanderer-industries/wanderer/compare/v1.20.1...v1.21.0) (2024-11-24)




### Features:

* Map: add new gate design, change EOL placement

## [v1.20.0](https://github.com/wanderer-industries/wanderer/compare/v1.19.3...v1.20.0) (2024-11-22)




### Features:

* Core: Add connection type for Gates, add new Update logic

## [v1.19.3](https://github.com/wanderer-industries/wanderer/compare/v1.19.2...v1.19.3) (2024-11-20)




### Bug Fixes:

* Core: Fix adding systems on splash (#71)

* Core: Fix adding systems on splash

## [v1.19.0](https://github.com/wanderer-industries/wanderer/compare/v1.18.1...v1.19.0) (2024-11-19)




### Features:

* Signatures: Add user setting to show Inserted time in a separate column

## [v1.18.0](https://github.com/wanderer-industries/wanderer/compare/v1.17.0...v1.18.0) (2024-11-16)




### Features:

* Map: a lot of design issues

## [v1.17.0](https://github.com/wanderer-industries/wanderer/compare/v1.16.1...v1.17.0) (2024-11-15)




### Features:

* Signatures: Add user setting to show Description in a separate column

## [v1.16.1](https://github.com/wanderer-industries/wanderer/compare/v1.16.0...v1.16.1) (2024-11-15)




### Bug Fixes:

* Signatures: Fix signature stored filters

## [v1.16.0](https://github.com/wanderer-industries/wanderer/compare/v1.15.5...v1.16.0) (2024-11-15)




### Features:

* Signatures: Add additional filters support to signature list, show description icon

## [v1.15.4](https://github.com/wanderer-industries/wanderer/compare/v1.15.3...v1.15.4) (2024-11-14)




### Bug Fixes:

* Core: Untracked characters still tracked on map (#63)

## [v1.15.1](https://github.com/wanderer-industries/wanderer/compare/v1.15.0...v1.15.1) (2024-11-07)




### Bug Fixes:

* Dev: Update .devcontainer instructions

## [v1.15.0](https://github.com/wanderer-industries/wanderer/compare/v1.14.1...v1.15.0) (2024-11-07)




### Features:

* Connections: Add connection mark EOL time (#56)

## [v1.14.1](https://github.com/wanderer-industries/wanderer/compare/v1.14.0...v1.14.1) (2024-11-06)




### Bug Fixes:

* Core: Fix character tracking permissions

## [v1.14.0](https://github.com/wanderer-industries/wanderer/compare/v1.13.12...v1.14.0) (2024-11-05)




### Features:

* ACL: Add an ability to assign member role without DnD

## [v1.13.12](https://github.com/wanderer-industries/wanderer/compare/v1.13.11...v1.13.12) (2024-11-04)




### Bug Fixes:

* Map: Fix system revert issues

## [v1.13.11](https://github.com/wanderer-industries/wanderer/compare/v1.13.10...v1.13.11) (2024-11-02)




### Bug Fixes:

* Map: Fix system revert issues

## [v1.13.10](https://github.com/wanderer-industries/wanderer/compare/v1.13.9...v1.13.10) (2024-11-01)




### Bug Fixes:

* Map: Fix system revert issues

## [v1.13.0](https://github.com/wanderer-industries/wanderer/compare/v1.12.11...v1.13.0) (2024-10-28)




### Features:

* Core: Use ESI /characters/affiliation API

## [v1.12.4](https://github.com/wanderer-industries/wanderer/compare/v1.12.3...v1.12.4) (2024-10-21)




### Bug Fixes:

* Map: Fix systems cleanup

## [v1.12.3](https://github.com/wanderer-industries/wanderer/compare/v1.12.2...v1.12.3) (2024-10-18)




### Bug Fixes:

* Map: Fix regression issues

## [v1.12.1](https://github.com/wanderer-industries/wanderer/compare/v1.12.0...v1.12.1) (2024-10-16)




### Bug Fixes:

* Map: Fix system add error after map page refresh

## [v1.12.0](https://github.com/wanderer-industries/wanderer/compare/v1.11.5...v1.12.0) (2024-10-16)




### Features:

* Map: Prettify user settings

## [v1.11.0](https://github.com/wanderer-industries/wanderer/compare/v1.10.0...v1.11.0) (2024-10-14)




### Features:

* Map: Add map level option to store custom labels

## [v1.10.0](https://github.com/wanderer-industries/wanderer/compare/v1.9.0...v1.10.0) (2024-10-13)




### Features:

* Map: Link signature on splash

## [v1.5.0](https://github.com/wanderer-industries/wanderer/compare/v1.4.0...v1.5.0) (2024-10-11)




### Features:

* Map: Follow Character on Map and auto select their current system

## [v1.3.6](https://github.com/wanderer-industries/wanderer/compare/v1.3.5...v1.3.6) (2024-10-09)




### Bug Fixes:

* Signatures: Signatures update fixes

## [v1.3.0](https://github.com/wanderer-industries/wanderer/compare/v1.2.10...v1.3.0) (2024-10-07)




### Features:

* Map: Fix default sort

* Map: Remove resizible and fix styles of column sorting

* Map: Revision of sorting from also adding ability to sort all columns

## [v1.2.6](https://github.com/wanderer-industries/wanderer/compare/v1.2.5...v1.2.6) (2024-10-05)




### Bug Fixes:

* Core: Stability & performance improvements

## [v1.2.5](https://github.com/wanderer-industries/wanderer/compare/v1.2.4...v1.2.5) (2024-10-04)




### Bug Fixes:

* Core: Add system "true security" correction

## [v1.2.4](https://github.com/wanderer-industries/wanderer/compare/v1.2.3...v1.2.4) (2024-10-03)




### Bug Fixes:

* Map: Remove duplicate connections

## [v1.2.3](https://github.com/wanderer-industries/wanderer/compare/v1.2.2...v1.2.3) (2024-10-02)




### Bug Fixes:

* Map: Fix map loading after select a different map.

## [v1.2.1](https://github.com/wanderer-industries/wanderer/compare/v1.2.0...v1.2.1) (2024-10-02)




### Bug Fixes:

* ACL: Fix allowing to save map/access list with empty owner set

## [v1.2.0](https://github.com/wanderer-industries/wanderer/compare/v1.1.0...v1.2.0) (2024-09-29)




### Features:

* Map: Add ability to open jump planner from routes

## [v1.1.0](https://github.com/wanderer-industries/wanderer/compare/v1.0.23...v1.1.0) (2024-09-29)




### Features:

* Map: Add highlighting for imperial space systems depends on faction

## [v1.0.23](https://github.com/wanderer-industries/wanderer/compare/v1.0.22...v1.0.23) (2024-09-25)




### Bug Fixes:

* Map: Main map doesn't load back after refreshing/switching pages

