# Elevator A.I Changelog
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
