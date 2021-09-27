# Elevator A.I Changelog
## [v3.1.0] 09/26/21 8:12:56 PM
#### Changed
- Picard version bump
- UICity.funding to UIColony.funds.funding
- changed panel control ver


#### Added
- MainMapID to all the custom notifications
- MainCity to GatherResourceOverviewData(colonystock, MainCity)
- map_id ot g_EAI global var

#### Removed

#### Fixed Issues

#### Open Issues

#### Deprecated

#### Todo

--------------------------------------------------------
## 3.0.0 02/21/2020 5:04:43 PM
#### Changed
- xtemplate version to v3.0
- xtemplate max slider references to global var

#### Added
- GlobalVar for persistent dynamic sliders - g_EAIsliderCurrent
- global var for slider references - g_EAIslider
- File EAI_3ModConfig

#### Deprecated
- original static local max slider vars

--------------------------------------------------------
## v2.4.2 08/22/2019 11:19:31 PM
#### Changed
- function EAIcheckColonyStock(debugcode)

#### Added
- added code to function EAIcheckColonyStock(debugcode) to check for a bad resource definition

#### Fixed Issues
- bad resource definitions causes errors in the restock thread failing to order anything

--------------------------------------------------------
## v2.4.1 07/06/2019 1:33:05 PM

#### Added
- check on LoadGame() for missing seeds variable in already built elevators

--------------------------------------------------------
## v2.4.0 04/25/2019 10:50:10 PM
#### Changed
- Using variables for sliders
- Increased most sliders to 300 max orders

--------------------------------------------------------
## v2.3.1 04/21/2019 2:25:02 AM
#### Changed
- Rare metals slider step to 10 and max to 1000

--------------------------------------------------------
## 2.3.0 04/17/2019 6:57:25 PM

#### Added
- Seeds for Armstrong Green Planet Release

--------------------------------------------------------
## v2.2.2 12/16/2018 1:30:32 AM
#### Changed
- xTemplate for button

#### Added
- EAIupdateButtonRollover(button) - consolidated logic for rollovertext into a function

#### Fixed Issues
- Rolover text not updating when pressed and ip left open

--------------------------------------------------------
## v2.2.1 11/02/2018 11:32:55 PM
- Gagarin Updates
#### Changed
- All references to local EAISection now need 5 parents instead of 4 to reach top level.
#### Added
- Changelog
#### Removed
- assert(table.find(self.task_requests, self.export_request))
  - from SpaceElevator:EAIAdjustExportStorage(new_max_export_storage) this was throwing unecessary errors in the logs. Was removed from Gagarin anyway. Seems un-needed.
#### Fixed Issues
- Broken XTemplate causing errors and bad IP open/close
--------------------------------------------------------
### Legacy Changelog
Changelog:
v2.2 Sept 27th, 2018
- Sagan updates

v2.1 Sept 21st, 2018
- Minor bug fix around notifications

v2.0 Sept 9th, 2018
-- Added automatic export control

v1.0 Sept 6th, 2018
Initial Upload
