-- Code developed for Elevator A.I.
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created Sept 5th, 2018
-- Updated Dec 15th, 2018

local lf_printDebug = false  -- Used to print anything designated as debug
local lf_print      = false  -- Setup debug printing in local file
                             -- Use if lf_print then print("something") end


local ModDir = CurrentModPath
local StringIdBase = 1776300000 -- Elevator AI, Next number = 37
local iconEAIButtonNA    = ModDir.."UI/Icons/buttonEAInotinstalled.png"
local iconEAIButtonOn    = ModDir.."UI/Icons/buttonEAIon.png"
local iconEAIButtonOff   = ModDir.."UI/Icons/buttonEAIoff.png"
local iconEAISection  = ModDir.."UI/Icons/sectionEAIi.png"
local iconEAINotice   = ModDir.."UI/Icons/noticeEAIIcon.png"
local iconClock       = ModDir.."UI/Icons/iconClock.png"
local imageClock      = table.concat({"<image ", iconClock, " 1500>"})
local sformat         = string.format

g_EAIloaded = true -- for section and button conditionals in case templates stuck in a savegame without mod.


local IsControlPressed = function()
  --return not terminal.IsKeyPressed(const.vkControl) and Platform.osx and terminal.IsKeyPressed(const.vkLwin)
  return terminal.IsKeyPressed(const.vkControl)
end -- IsControlPressed

local IsShiftPressed = function()
  return terminal.IsKeyPressed(const.vkShift)
end --IsShiftPressed

local IsAltPressed = function()
  return terminal.IsKeyPressed(const.vkAlt)
end --IsAltPressed


-- This function finds and sets the reference in self for the rare metals button every time
-- the infopanel opens up.  The button has no Id so cannot reference it directly, search needed.
local function EAIfindRareExportButton(self)
	local off = "UI/Icons/IPButtons/forbid_exports_off.tga"
	local on  = "UI/Icons/IPButtons/forbid_exports_on.tga"
	local idMainButtons = self.parent
	local buttonfound = false
	for idx = 1, #idMainButtons do
		if ((idMainButtons[idx].Icon == off) or (idMainButtons[idx].Icon == on)) and not buttonfound then
			buttonfound = idMainButtons[idx]
			buttonfound:SetRolloverDisabledText(T{StringIdBase + 36, "Rare Metal exports are controlled by Elevator A.I."})
			break
		end -- if button found
	end -- for each button
	self.EAI_RareMetal_ExportButton = buttonfound
end --EAIfindRareExportButton()

-- message for user about having only one AI running
local function AIalreadyInstalledPopup()
	local SpaceElevator = g_EAI.elevator

    CreateRealTimeThread(function()
        local params = {
              title = T{StringIdBase, "Elevator A.I."},
               text = T{StringIdBase + 1, "Elevator A.I is already installed. You must uninstall the Elevator A.I from the existing Space Elevator to move it. Control Click the A.I. button in the Space Elevator."},
            choice1 = T{StringIdBase + 2, "Show me where the Elevator A.I is installed"},
            choice2 = T{StringIdBase + 3, "Close Window"},
              image = "UI/Messages/artificial_intelligence_mystery_01.tga",
              start_minimized = false,
        } -- params
        local choice = WaitPopupNotification(false, params)
        if choice == 1 then
        	ViewObjectMars(SpaceElevator)
        	SelectObj(SpaceElevator)
        end -- if statement
    end ) -- CreateRealTimeThread
end -- function end

local function InitEAI(elevator)
	if lf_print then print("Setting up new elevator") end
	elevator.EAI_restock_Concrete     = 0
	elevator.EAI_restock_Metals       = 0
	elevator.EAI_restock_Food         = 0
	elevator.EAI_restock_Polymers     = 0
	elevator.EAI_restock_MachineParts = 0
	elevator.EAI_restock_Electronics  = 0
	elevator.EAI_restock_frequency    = 1
	elevator.EAI_export_threshold     = 0      -- the amount to trigger and export of rare metals
	elevator.EAI_schedule             = ""
	elevator.EAI_enabled              = false
	elevator.EAI_installed            = false
	if not elevator.description_old then elevator.description_old = elevator.description end
	if not elevator.EAI_GUID then elevator.EAI_GUID = tostring(AsyncRand()).."-"..tostring(GetPreciseTicks()) end
end --InitEAI()

local function EAIupdateButtonRollover(button)
	local elevator = button.context
	if elevator.EAI_enabled then
    button:SetRolloverTitle(T{StringIdBase + 4, "Disable Elevator A.I."})
    button:SetRolloverText(T{StringIdBase + 5, "Disable the Elevator A.I."})
    elevator.description = T{StringIdBase + 6, "Space Elevator - Elevator A.I. Running"}
  end -- if enabled

  if (not elevator.EAI_enabled) and elevator.EAI_installed then
    button:SetRolloverTitle(T{StringIdBase + 10, "Enable Elevator A.I."})
    button:SetRolloverText(T{StringIdBase + 11, "Enable the Elevator A.I."})
    elevator.description = T{StringIdBase + 12, "Space Elevator - Elevator A.I. Stopped"}
  end -- disabled but installed

  if not elevator.EAI_installed then
    button:SetRolloverTitle(T{StringIdBase + 7, "Install Elevator A.I."})
    button:SetRolloverText(T{StringIdBase + 8, "Install the Elevator A.I. for this Space Elevator."})
    elevator.description = T{StringIdBase + 9, "Space Elevator - Elevator A.I. not Installed"}
  end -- if not installed

end -- EAIbuttonRollover

local function ConfigureEAI(self, option)
	-- self is the button
	local elevator = self.context
	local EAISection = self.parent.parent.parent.parent.parent.idElevatorAISection

  if option == "install" and (not g_EAI.GUID) then
    elevator.EAI_installed = true
    elevator.EAI_enabled = true
    g_EAI.GUID = elevator.EAI_GUID
    g_EAI.elevator = elevator
    EAISection:SetVisible(true)
    self:SetIcon(iconEAIButtonOn)
    EAIupdateButtonRollover(self)
  elseif option == "install" and g_EAI.GUID then
  	AIalreadyInstalledPopup()
  end -- option == "install"

  if option == "uninstall" then
    InitEAI(self.context)
    elevator:EAIRestoreExportStorage()
    g_EAI.GUID = false
    g_EAI.elevator = false
    elevator.EAI_installed = false
    elevator.EAI_enabled = false
    EAISection:SetVisible(false)
    EAIupdateButtonRollover(self)
    self:SetIcon(iconEAIButtonNA)
    self.cxDesc = false
  end -- option == "uninstall"

  if option == "disable" then
    EAISection:SetVisible(false)
    elevator.EAI_enabled = false
    self:SetIcon(iconEAIButtonOff)
    EAIupdateButtonRollover(self)
  end -- option == "disable"

  if option == "enable" then
    EAISection:SetVisible(true)
    elevator.EAI_enabled = true
    self:SetIcon(iconEAIButtonOn)
    EAIupdateButtonRollover(self)
  end -- option == "enable"
end --EnableEAI()

----------------------- OnMsg -------------------------------------------------------------------------------

function OnMsg.ClassesBuilt()
	local XTemplates = XTemplates
  local ObjModified = ObjModified
  local PlaceObj = PlaceObj
  local EAIButtonID1 = "ElevatorAIButton-01"
  local EAISectionID1 = "ElevatorAISection-01"
  local EAIControlVer = "v1.3"
  local XT = XTemplates.ipBuilding[1]

  if lf_print then print("Loading Classes in EAI_2Panels.lua") end

  --retro fix versioning
  if XT.EAI then
  	if lf_print then print("Retro Fit Check EAI Panels in ipBuilding") end
  	for i, obj in pairs(XT or empty_table) do
  		if type(obj) == "table" and obj.__context_of_kind == "SpaceElevator" and (
  		 obj.UniqueID == EAIButtonID1 or obj.UniqueID == EAISectionID1 ) and
  		 obj.Version ~= EAIControlVer then
  			table.remove(XT, i)
  			if lf_print then print("Removed old EAI Panels Class Obj") end
  			XT.EAI = nil
  		end -- if obj
  	end -- for each obj
  end -- retro fix versioning

  -- build the classes just once per game
  if not XT.EAI then
    XT.EAI = true
    local foundsection, idx

    --alter the ipBuilding template for EAI
    -- alter the EAI button panel
    XT[#XT + 1] = PlaceObj("XTemplateTemplate", {
    	"Version", EAIControlVer,
    	"UniqueID", EAIButtonID1,
    	"Id", "idEAIbutton",
      "__context_of_kind", "SpaceElevator",
      "__condition", function (parent, context) return g_EAIloaded and (not context.demolishing) and (not context.destroyed) and (not context.bulldozed) end,
      "__template", "InfopanelButton",
      "Icon", iconEAIButtonNA,
      --"RolloverTitle", T{StringIdBase + 7, "Install Elevator A.I."}, -- Title Used for sections only
      --"RolloverText", T{StringIdBase + 8, "Install the Elevator A.I. for this Space Elevator."},
      "RolloverHint", T{StringIdBase + 13, "<left_click> Activate<newline>Ctrl+<left_click> Uninstall A.I. from this Elevator"},
      "OnContextUpdate", function(self, context)
      	local elevator = context
      	local selfId   = sformat("ip%s", self.Id)

      	--set the buton rollover text
      	if not self.cxRolloverText then
      		EAIupdateButtonRollover(self)
      		self.cxRolloverText = true
      	end -- if not self.cxRolloverText

      	-- install reference to context
      	if not self[selfId] then
      		self[selfId] = true
      		elevator[selfId] = self
      	end --install reference

        -- Check for EAI setup and intialize
        if elevator.EAI_installed == nil then InitEAI(elevator) end
        local export_threshold = elevator.EAI_export_threshold or 0

        -- find and setup the rare metals export button status
        -- keep track of previous export status
        -- return to original setting when turned to zero or ai disabled.
        if not self.EAI_RareMetal_ExportButton then EAIfindRareExportButton(self) end
        if export_threshold > 0 and elevator.EAI_enabled and self.EAI_RareMetal_ExportButton then
          self.EAI_RareMetal_ExportButton:SetEnabled(false)  -- disable button and take control
          if not elevator.EAI_export_prevstatus then
          	elevator.EAI_export_prevstatus = true
          	elevator.EAI_export_prevsetting = elevator.allow_export  -- record previous setting
          end -- if not elevator.EAI_export_prevstatus
          if self.cxEAI_export_threshold ~= export_threshold then
          	-- run this only once per slider setting
          	self.cxEAI_export_threshold = export_threshold
            EAIautoExport(sformat("IP elevator: %s", elevator.EAI_GUID)) -- check stock and enable exports
          end --export_threshold
        elseif export_threshold == 0 and elevator.EAI_enabled and self.EAI_RareMetal_ExportButton then
          if elevator.EAI_export_prevstatus then
          	elevator.EAI_export_prevstatus = false
          	elevator:EAIRestoreExportStorage()
          	elevator:EAIRestoreExportStatus()
          end -- if elevator.EAI_export_prevstatus
          self.EAI_RareMetal_ExportButton:SetEnabled(true)   -- enable button and return manual control
        elseif (not elevator.EAI_enabled) and self.EAI_RareMetal_ExportButton then
          if elevator.EAI_export_prevstatus then
          	elevator.EAI_export_prevstatus = false
          	-- stuck this here since EAI_export_prevstatus is only called once when uninstalling
          	self.cxEAI_export_threshold = nil
          	elevator:EAIRestoreExportStorage()
          	elevator:EAIRestoreExportStatus()
          end -- if elevator.EAI_export_prevstatus
          self.EAI_RareMetal_ExportButton:SetEnabled(true)   -- enable button and return manual control
        end  -- export_threshold > 0

       	-- Set the install condition
       	if not elevator.EAI_installed and not self.cxDesc then
       		-- only execute this once- the first time on oncontextupdate
       		self.cxDesc = true
       		elevator.description = T{StringIdBase + 9, "Space Elevator - Elevator A.I. not Installed"}
       		self:SetIcon(iconEAIButtonNA)
       	end -- not context.EAI_installed

        -- Set the enabled condition
       	if elevator.EAI_enabled then
       		self:SetIcon(iconEAIButtonOn)
       	elseif (not elevator.EAI_enabled) and elevator.EAI_installed then
       		self:SetIcon(iconEAIButtonOff)
       	end --context.EAI_enabled

       	-- Set the idElevatorAISection visibile or not depending on status
        local EAISection = self.parent.parent.parent.parent.parent.idElevatorAISection
       	EAISection:SetVisible(context.EAI_installed and context.EAI_enabled)
      end, -- OnContextUpdate

      "OnPress", function(self, gamepad)
      	PlayFX("DomeAcceptColonistsChanged", "start", self.context)
      	local EAISection = self.parent.parent.parent.parent.parent.idElevatorAISection
      	local elevator = self.context
      	if not elevator.EAI_installed and not IsControlPressed() then
      		-- Install the Elevator A.I in this elevator
      		ConfigureEAI(self, "install")
      	elseif elevator.EAI_installed and IsControlPressed() then
      		-- Unistall the Elevator A.I from this elevator
      		ConfigureEAI(self, "uninstall")
      	elseif elevator.EAI_enabled then
      		-- disable Elevator A.I.
      		ConfigureEAI(self, "disable")
     	  elseif not elevator.EAI_enabled and elevator.EAI_installed then
     	  	-- enable Elevator A.I.
     	  	ConfigureEAI(self, "enable")
      	end -- if not Elevator.EAI_installed
     	  ObjModified(self)
      end -- OnPress
    }) -- End PlaceObject

    --Check for Cheats Menu and insert before Cheats menu
    foundsection, idx = table.find_value(XT, "__template", "sectionCheats")
    if not idx then idx = #XT + 1 end
    if lf_print then print("Inserting A.I. Section Template into idx: ", tostring(idx)) end

    -- Elevator A.I. Sliders Section
    table.insert(XT, idx,
      PlaceObj("XTemplateTemplate", {
      	"UniqueID", EAISectionID1,
      	"Version", EAIControlVer,
      	"Id", "idElevatorAISection",
        "__context_of_kind", "SpaceElevator",
        "__condition", function (parent, context) return g_EAIloaded and (not context.demolishing) and (not context.destroyed) and (not context.bulldozed)end,
        "__template", "InfopanelSection",
        "Icon", iconEAISection,
        "Title", "Elevator A.I.",
        "RolloverTitle", T{StringIdBase, "Elevator A.I."},
        "RolloverText", T{StringIdBase + 14, "Select the threshold to trigger a resupply for each resource."},
        "OnContextUpdate", function(self, context)
        	local elevator = context
          local selfId   = sformat("ip%s", self.Id)
      	  -- install reference to context
      	  if not self[selfId] then
      		  self[selfId] = true
      		  elevator[selfId] = self
      	  end --install reference

        	-- Setup variables to display status and schedule
        	local NextFrequencyTime, timeslots = EAIcalcNextFrequencyTime()
          if (lf_printDebug) and not self.exDebug then
          	self.exDebug = true
        		ex(self)
        		ex(timeslots)
        	end -- debug
        	local restocktime = self.idEAIstatusSection.idEAInextUpdateHourText
          if g_Consts.SupplyMissionsEnabled ~= 1 then
          	-- Mission resupply is prohibited
          	restocktime:SetText(T{StringIdBase + 15, "Prohibited"})
          	elevator.EAI_schedule = " "
          elseif context:IsBusy(true) then
          	restocktime:SetText(T{StringIdBase + 16, "Busy"})
          else
          	-- display next frequency time or ##:## if elevator not working.
          	if NextFrequencyTime < 0 then restocktime:SetText("##:##")
          	                         else restocktime:SetText(sformat("%02d:00", NextFrequencyTime)) end
          	for i = 1, #timeslots do
          		if timeslots[i] == "-1" then
          			timeslots[i] = "##:##"
          			break
          		end -- if
          		timeslots[i] = sformat("  %02d:00", timeslots[i])
          	end -- for i
          	elevator.EAI_schedule = table.concat(timeslots, "<newline>")
          end -- if g_Consts.SupplyMissionsEnabled ~= 1
        end, -- OnContextUpdate
      },{

      	 -- Status Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Status Section",
          "Id", "idEAIstatusSection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, 0),
    		 	"RolloverTemplate", "Rollover",
    	  	"RolloverTitle", T{StringIdBase + 17, "Elevator A.I. Restock Schedule"},
          "RolloverText", T{StringIdBase + 18, "The schedule is set by the frequency.  24 hours are divided by the frequency number and the A.I schedule is evenly distributed throughout the day.<newline><newline><em>Schedule</em><newline><EAI_schedule>"},
	   		 },{
          	-- Next restock Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idEAInextUpdateText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 19, "Next A.I. reorder check:"},
            }),
            -- Update hour Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idEAInextUpdateHourText",
              "Margins", box(0, 0, 20, 0),
              "TextHAlign", "right",
            }),
	   	  }), -- end of idEAIstatusSection

      	 -- Frequency Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Frequency Section",
          "Id", "idEAIfrequencySection",
	   			"IdNode", true,
	   			"Margins", box(0, 0, 0, -5),
    		 	"RolloverTemplate", "Rollover",
    	  	"RolloverTitle", T{StringIdBase + 20, "Elevator A.I. Frequency"},
          "RolloverText", T{StringIdBase + 21, "Select the frequency the A.I will check and restock the colony stock each sol."},
	   		 },{
          	-- Frequency Slider Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelSlider",
              "Id", "idEAIfrequencySlider",
              "Margins", box(0, 15, 0, 15),
              "BindTo", "EAI_restock_frequency",
              "Min", 1,
              "Max", 5,
    			  	"StepSize", 1, --change per movement
    			  	"SnapToItems", true,
            }),
    				PlaceObj('XTemplateTemplate', {
    					"__template", "InfopanelText",
    					"Id", "idEAIfrequencySliderText",
    					"Dock", "right",
    					"Margins", box(0, 0, 0, 0),
    					"Padding", box(0, 0, 0, 0),
    					"MinWidth", "45",
    					"TextHAlign", "right",
    				  "Text", T{StringIdBase + 900, "<EAI_restock_frequency><timageClock>", timageClock = imageClock},
            }),
	   	  }), -- end of idEAIfrequencySection

      	 -- Precious Metals Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Precious Metals Section",
          "Id", "idEAIpreciousmetalsSection",
	   			"IdNode", true,
	   			"__condition", function (parent, context)
	   				               if not context.EAI_export_threshold then context.EAI_export_threshold = 0 end -- retro fits variable into elevator
	   				               return not EAIisResourceBlacklisted("PreciousMetals") end,
	   			"Margins", box(0, 0, 0, -5),
    		 	"RolloverTemplate", "Rollover",
    		 	--~ modify the StringIDBase and get translations
    	  	"RolloverTitle", T{StringIdBase + 22, "Precious Metals"},
          "RolloverText", T{StringIdBase + 23, "Select the minimum amount of Precious Metals to keep in stock before allowing exports.<newline>Settings greater than zero cause Elevator A.I. to take over exporting."},
	   		 },{
          	-- Precious Metals Slider Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelSlider",
              "Id", "idEAIpreciousmetalsSlider",
              "Margins", box(0, 15, 0, 15),
              "BindTo", "EAI_export_threshold",
              "Min", 0,
              "Max", 500000,
    			  	"StepSize", 5000, --change per movement
            }),
    				PlaceObj('XTemplateTemplate', {
    					"__template", "InfopanelText",
    					"Id", "idEAIpreciousmetalsSliderText",
    					"Dock", "right",
    					"Margins", box(0, 0, 0, 0),
    					"Padding", box(0, 0, 0, 0),
    					"MinWidth", "45",
    					"TextHAlign", "right",
    				  "Text", T{StringIdBase + 901, "<preciousmetals(EAI_export_threshold)>"},
            }),
	   	  }), -- end of idEAIpreciousmetalsSection

      	 -- Concrete Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Concrete Section",
          "Id", "idEAIconcreteSection",
	   			"IdNode", true,
	   			"__condition", function (parent, context) return not EAIisResourceBlacklisted("Concrete") end,
	   			"Margins", box(0, 0, 0, -5),
    		 	"RolloverTemplate", "Rollover",
    	  	"RolloverTitle", T{StringIdBase + 24, "Concrete"},
          "RolloverText", T{StringIdBase + 25, "Select the threshold of concrete in the colony Elevator A.I. will check before ordering more concrete.  The threshold is also the reorder amount."},
	   		 },{
          	-- Concrete Slider Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelSlider",
              "Id", "idEAIconcreteSlider",
              "Margins", box(0, 15, 0, 15),
              "BindTo", "EAI_restock_Concrete",
              "Min", 0,
              "Max", 80000,
    			  	"StepSize", 1000, --change per movement
            }),
    				PlaceObj('XTemplateTemplate', {
    					"__template", "InfopanelText",
    					"Id", "idEAIconcreteSliderText",
    					"Dock", "right",
    					"Margins", box(0, 0, 0, 0),
    					"Padding", box(0, 0, 0, 0),
    					"MinWidth", "45",
    					"TextHAlign", "right",
    				  "Text", T{StringIdBase + 902, "<concrete(EAI_restock_Concrete)>"},
            }),
	   	  }), -- end of idEAIconcreteSection

      	 -- Metals Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Metals Section",
          "Id", "idEAImetalsSection",
	   			"IdNode", true,
	   			"__condition", function (parent, context) return not EAIisResourceBlacklisted("Metals") end,
	   			"Margins", box(0, 0, 0, -5),
    	  	"RolloverTemplate", "Rollover",
   		  	"RolloverTitle", T{StringIdBase + 26, "Metals"},
          "RolloverText", T{StringIdBase + 27, "Select the threshold of metals in the colony Elevator A.I. will check before ordering more metals.  The threshold is also the reorder amount."},
	   		 },{
          	-- Metals Slider Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelSlider",
              "Id", "idEAImetalsSlider",
              "Margins", box(0, 15, 0, 15),
              "BindTo", "EAI_restock_Metals",
              "Min", 0,
              "Max", 80000,
    			  	"StepSize", 1000, --change per movement
            }),
    				PlaceObj('XTemplateTemplate', {
    					"__template", "InfopanelText",
    					"Id", "idEAImetalsSliderText",
    					"Dock", "right",
    					"Margins", box(0, 0, 0, 0),
    					"Padding", box(0, 0, 0, 0),
    					"MinWidth", "45",
    					"TextHAlign", "right",
    				  "Text", T{StringIdBase + 903, "<metals(EAI_restock_Metals)>"},
            }),
	   	  }), -- end of idmEAImetalsSection

      	 -- Food Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Food Section",
          "Id", "idEAIfoodSection",
	   			"IdNode", true,
	   			"__condition", function (parent, context) return not EAIisResourceBlacklisted("Food") end,
	   			"Margins", box(0, 0, 0, -5),
    			"RolloverTemplate", "Rollover",
    			"RolloverTitle", T{StringIdBase + 28, "Food"},
          "RolloverText", T{StringIdBase + 29, "Select the threshold of food in the colony Elevator A.I. will check before ordering more food.  The threshold is also the reorder amount."},
	   		 },{
          	-- Food Slider Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelSlider",
              "Id", "idEAIfoodSlider",
              "Margins", box(0, 15, 0, 15),
              "BindTo", "EAI_restock_Food",
              "Min", 0,
              "Max", 200000,
    			  	"StepSize", 1000, --change per movement
            }),
    				PlaceObj('XTemplateTemplate', {
    					"__template", "InfopanelText",
    					"Id", "idEAIfoodSliderText",
    					"Dock", "right",
    					"Margins", box(0, 0, 0, 0),
    					"Padding", box(0, 0, 0, 0),
    					"MinWidth", "45",
    					"TextHAlign", "right",
    				  "Text", T{StringIdBase + 904, "<food(EAI_restock_Food)>"},
            }),
	   	  }), -- end of idEAIfoodSection

      	 -- Polymers Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Polymers Section",
          "Id", "idEAIpolymersSection",
	   			"IdNode", true,
	   			"__condition", function (parent, context) return not EAIisResourceBlacklisted("Polymers") end,
	   			"Margins", box(0, 0, 0, -5),
    			"RolloverTemplate", "Rollover",
    			"RolloverTitle", T{StringIdBase + 30, "Polymers"},
          "RolloverText", T{StringIdBase + 31, "Select the threshold of polymers in the colony Elevator A.I. will check before ordering more polymers.  The threshold is also the reorder amount."},
	   		 },{
          	-- Polymers Slider Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelSlider",
              "Id", "idEAIpolymersSlider",
              "Margins", box(0, 15, 0, 15),
              "BindTo", "EAI_restock_Polymers",
              "Min", 0,
              "Max", 200000,
    			  	"StepSize", 1000, --change per movement
            }),
    				PlaceObj('XTemplateTemplate', {
    					"__template", "InfopanelText",
    					"Id", "idEAIpolymersSliderText",
    					"Dock", "right",
    					"Margins", box(0, 0, 0, 0),
    					"Padding", box(0, 0, 0, 0),
    					"MinWidth", "45",
    					"TextHAlign", "right",
    				  "Text", T{StringIdBase + 905, "<polymers(EAI_restock_Polymers)>"},
            }),
	   	  }), -- end of idEAIpolymersSection

      	 -- Machine Parts Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Machine Parts Section",
          "Id", "idEAImachinepartsSection",
	   			"IdNode", true,
	   			"__condition", function (parent, context) return not EAIisResourceBlacklisted("MachineParts") end,
	   			"Margins", box(0, 0, 0, -5),
    			"RolloverTemplate", "Rollover",
    			"RolloverTitle", T{StringIdBase + 32, "Machine Parts"},
          "RolloverText", T{StringIdBase + 33, "Select the threshold of machine parts in the colony Elevator A.I. will check before ordering more machine parts.  The threshold is also the reorder amount."},
	   		 },{
          	-- Machine Parts Slider Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelSlider",
              "Id", "idEAImachinepartsSlider",
              "Margins", box(0, 15, 0, 15),
              "BindTo", "EAI_restock_MachineParts",
              "Min", 0,
              "Max", 200000,
    			  	"StepSize", 1000, --change per movement
            }),
    				PlaceObj('XTemplateTemplate', {
    					"__template", "InfopanelText",
    					"Id", "idEAImachinepartsSliderText",
    					"Dock", "right",
    					"Margins", box(0, 0, 0, 0),
    					"Padding", box(0, 0, 0, 0),
    					"MinWidth", "45",
    					"TextHAlign", "right",
    				  "Text", T{StringIdBase + 906, "<machineparts(EAI_restock_MachineParts)>"},
            }),
	   	  }), -- end of idEAImachinepartsSection

      	 -- Electronics Parts Section
			   PlaceObj('XTemplateWindow', {
	   			'comment', "Electronics Section",
          "Id", "idEAIelectronicsSection",
	   			"IdNode", true,
	   			"__condition", function (parent, context) return not EAIisResourceBlacklisted("Electronics") end,
	   			"Margins", box(0, 0, 0, -5),
    			"RolloverTemplate", "Rollover",
    			"RolloverTitle", T{StringIdBase + 34, "Electronics"},
          "RolloverText", T{StringIdBase + 35, "Select the threshold of electronics in the colony Elevator A.I. will check before ordering more electronics.  The threshold is also the reorder amount."},
	   		 },{
          	-- Electronics Slider Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelSlider",
              "Id", "idEAIelectronicsSlider",
              "Margins", box(0, 15, 0, 15),
              "BindTo", "EAI_restock_Electronics",
              "Min", 0,
              "Max", 200000,
    			  	"StepSize", 1000, --change per movement
            }),
    				PlaceObj('XTemplateTemplate', {
    					"__template", "InfopanelText",
    					"Id", "idEAIelectronicsSliderText",
    					"Dock", "right",
    					"Margins", box(0, 0, 0, 0),
    					"Padding", box(0, 0, 0, 0),
    					"MinWidth", "45",
    					"TextHAlign", "right",
    				  "Text", T{StringIdBase + 907, "<electronics(EAI_restock_Electronics)>"},
            }),
	   	  }), -- end of idEAIelectronicsSection
      }) -- End PlaceObject XTemplate
    ) --table.insert

  end --if not XT.EAI template check

end --OnMsg.ClassesBuilt()