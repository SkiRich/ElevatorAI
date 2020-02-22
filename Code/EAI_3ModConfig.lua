-- Code developed for Elevator A.I.
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Mod Created Sept 5th, 2018
-- File Created Feb 21st, 2020
-- Updated Feb 21st, 2020

local lf_print = false -- Setup debug printing in local file

local StringIdBase = 1776300000 -- Elevator AI, starts at 200 to 299, Next = 200
local mod_name = "Elevator A.I"
local ModConfig_id = "1542863522"
local ModConfigWaitThread = false
g_ModConfigLoaded = false

-- var for looking up variables
local lookup = {
	idEAIpreciousmetalsSlider = "PrecMetals",
	idEAIconcreteSlider       = "Concrete",
	idEAImetalsSlider         = "Metals",
	idEAIfoodSlider           = "Food",
	idEAIpolymersSlider       = "Polymers",
	idEAImachinepartsSlider   = "MachinePts",
	idEAIelectronicsSlider    = "Electronics",
	idEAIseedsSlider          = "Seeds",
} -- lookup

-- wait for mod config to load or fail out and use defaults
local function WaitForModConfig()
	if (not ModConfigWaitThread) or (not IsValidThread(ModConfigWaitThread)) then
		ModConfigWaitThread = CreateRealTimeThread(function()
	    if lf_print then print(string.format("%s WaitForModConfig Thread Started", mod_name)) end
      local Sleep = Sleep
      local TableFind  = table.find
      local ModsLoaded = ModsLoaded
      local threadlimit = 120  -- loops to wait before fail and exit thread loop
 		  while threadlimit > 0 do
 		  	--check to make sure another mod didn't already set g_ModConfigLoaded
 			  if not g_ModConfigLoaded then
 			  	g_ModConfigLoaded = TableFind(ModsLoaded, "steam_id", ModConfig_id) or false
 			  end -- if not g_ModConfigLoaded
 			  if g_ModConfigLoaded and ModConfig:IsReady() then
 			  	-- if ModConfig loaded and is in ready state then set as true
 			  	g_ModConfigLoaded = true
 			  	break
 			  else
 			    Sleep(500) -- Sleep 1/2 second
 			  end -- if g_ModConfigLoaded
 			  threadlimit = threadlimit - 1
 		  end -- while
      if lf_print then print(string.format("%s WaitForModConfig Thread Continuing", mod_name)) end

      -- See if ModConfig is installed and any defaults changed
      if g_ModConfigLoaded and ModConfig:IsReady() then

        -- set the modconfig option to match persitent storage
		    ModConfig:Set("EAI", "EAImaxPrecMetals", g_EAIsliderCurrent.PrecMetals / const.ResourceScale)
        ModConfig:Set("EAI", "EAImaxConcrete", g_EAIsliderCurrent.Concrete / const.ResourceScale)
        ModConfig:Set("EAI", "EAImaxMetals", g_EAIsliderCurrent.Metals / const.ResourceScale)
        ModConfig:Set("EAI", "EAImaxFood", g_EAIsliderCurrent.Food / const.ResourceScale)
        ModConfig:Set("EAI", "EAImaxPolymers", g_EAIsliderCurrent.Polymers / const.ResourceScale)
        ModConfig:Set("EAI", "EAImaxMachinePts", g_EAIsliderCurrent.MachinePts / const.ResourceScale)
        ModConfig:Set("EAI", "EAImaxElectronics", g_EAIsliderCurrent.Electronics / const.ResourceScale)
        ModConfig:Set("EAI", "EAImaxSeeds", g_EAIsliderCurrent.Seeds / const.ResourceScale)

        ModLog(string.format("%s detected ModConfig running - Setup Complete", mod_name))
      else
      	-- PUT MOD DEFAULTS HERE OR SET THEM UP BEFORE RUNNING THIS FUNCTION ---

    	  if lf_print then print(string.format("**** %s - Mod Config Never Detected On Load - Using Defaults ****", mod_name)) end
    	  ModLog(string.format("**** %s - Mod Config Never Detected On Load - Using Defaults ****", mod_name))
      end -- end if g_ModConfigLoaded
      if lf_print then print(string.format("%s WaitForModConfig Thread Ended", mod_name)) end
		end) -- thread
	else
		if lf_print then print(string.format("%s Error - WaitForModConfig Thread Never Ran", mod_name)) end
		ModLog(string.format("%s Error - WaitForModConfig Thread Never Ran", mod_name))
	end -- check to make sure thread not running
end -- WaitForModConFig

local function EAIupdateSliders()
	local template = XTemplates.ipBuilding[1]
	local idx = table.find(template, "Id", "idElevatorAISection")
	if idx then
		if lf_print then print("idElevatorAISection found") end
		template = template[idx]
		for i = 1, #template do
			local slider = template[i][1]
			local id = lookup[slider.Id]
			if id then
				if lf_print then print("Slider - ", id, "found") end
				slider.Max = g_EAIsliderCurrent[id]
			end -- if id
		end -- for i
	end -- if idx
end -- EAIupdateSliders


--------------------------------------- OnMsgs ------------------------------------------------------------

function OnMsg.ModConfigReady()

    -- Register this mod's name and description
    ModConfig:RegisterMod("EAI", -- ID
        T{StringIdBase, "Elevator A.I."}, -- Optional display name, defaults to ID
        T{StringIdBase + 201, "Options for Elevator A.I."} -- Optional description
    )

    -- EAImaxPrecMetals
    ModConfig:RegisterOption("EAI", "EAImaxPrecMetals", {
        name = T{StringIdBase +202, "Maximum precious metals slider amount:"},
        desc = T{StringIdBase + 203, "The maximum amount of precious metals the slider goes up to."},
        type = "number",
        default = 1000,
        min = 1000,
        max = g_EAIslider.PrecMetals / const.ResourceScale,
        step = 10,
        order = 1
    })

    -- EAImaxConcrete
    ModConfig:RegisterOption("EAI", "EAImaxConcrete", {
        name = T{StringIdBase +204, "Maximum concrete slider amount:"},
        desc = T{StringIdBase + 205, "The maximum amount of concrete the slider goes up to."},
        type = "number",
        default = 80,
        min = 80,
        max = g_EAIslider.Concrete / const.ResourceScale,
        step = 10,
        order = 2
    })

    -- EAImaxMetals
    ModConfig:RegisterOption("EAI", "EAImaxMetals", {
        name = T{StringIdBase +206, "Maximum metals slider amount:"},
        desc = T{StringIdBase + 207, "The maximum amount of metals the slider goes up to."},
        type = "number",
        default = 80,
        min = 80,
        max = g_EAIslider.Metals / const.ResourceScale,
        step = 10,
        order = 3
    })

    -- EAImaxFood
    ModConfig:RegisterOption("EAI", "EAImaxFood", {
        name = T{StringIdBase +208, "Maximum food slider amount:"},
        desc = T{StringIdBase + 209, "The maximum amount of food the slider goes up to."},
        type = "number",
        default = 300,
        min = 300,
        max = g_EAIslider.Food / const.ResourceScale,
        step = 10,
        order = 4
    })

    -- EAImaxPolymers
    ModConfig:RegisterOption("EAI", "EAImaxPolymers", {
        name = T{StringIdBase +210, "Maximum polymers slider amount:"},
        desc = T{StringIdBase + 211, "The maximum amount of polymers the slider goes up to."},
        type = "number",
        default = 300,
        min = 300,
        max = g_EAIslider.Polymers / const.ResourceScale,
        step = 10,
        order = 5
    })

    -- EAImaxMachinePts
    ModConfig:RegisterOption("EAI", "EAImaxMachinePts", {
        name = T{StringIdBase +212, "Maximum machine parts slider amount:"},
        desc = T{StringIdBase + 213, "The maximum amount of machine parts the slider goes up to."},
        type = "number",
        default = 300,
        min = 300,
        max = g_EAIslider.MachinePts / const.ResourceScale,
        step = 10,
        order = 6
    })

    -- EAImaxElectronics
    ModConfig:RegisterOption("EAI", "EAImaxElectronics", {
        name = T{StringIdBase +214, "Maximum electronics slider amount:"},
        desc = T{StringIdBase + 215, "The maximum amount of electronics the slider goes up to."},
        type = "number",
        default = 300,
        min = 300,
        max = g_EAIslider.Electronics / const.ResourceScale,
        step = 10,
        order = 7
    })

    -- EAImaxSeeds
    ModConfig:RegisterOption("EAI", "EAImaxSeeds", {
        name = T{StringIdBase +216, "Maximum seeds slider amount:"},
        desc = T{StringIdBase + 217, "The maximum amount of seeds the slider goes up to."},
        type = "number",
        default = 300,
        min = 300,
        max = g_EAIslider.Seeds / const.ResourceScale,
        step = 10,
        order = 8
    })

    -- Apply
    ModConfig:RegisterOption("EAI", "Apply", {
        name = T{StringIdBase + 250, "Click to apply changes now:"},
        desc = T{StringIdBase + 251, "Changes to sliders are applied only after clicking here.  Click this button to apply all settings to all sliders now.  "},
        type = "boolean",
        default = false,
        order = 9
    })
end -- ModConfigReady

function OnMsg.ModConfigChanged(mod_id, option_id, value, old_value, token)
    if g_ModConfigLoaded and mod_id == "EAI" then

        -- Change option for EAImaxPrecMetals
    	  if option_id == "EAImaxPrecMetals" then
        	g_EAIsliderCurrent.PrecMetals = value * const.ResourceScale
        end -- if option_id

        -- Change option for EAImaxConcrete
    	  if option_id == "EAImaxConcrete" then
        	g_EAIsliderCurrent.Concrete = value * const.ResourceScale
        end -- if option_id

        -- Change option for EAImaxMetals
    	  if option_id == "EAImaxMetals" then
        	g_EAIsliderCurrent.Metals = value * const.ResourceScale
        end -- if option_id

        -- Change option for EAImaxFood
    	  if option_id == "EAImaxFood" then
        	g_EAIsliderCurrent.Food = value * const.ResourceScale
        end -- if option_id

        -- Change option for EAImaxPolymers
    	  if option_id == "EAImaxPolymers" then
        	g_EAIsliderCurrent.Polymers = value * const.ResourceScale
        end -- if option_id

        -- Change option for EAImaxMachinePts
    	  if option_id == "EAImaxMachinePts" then
        	g_EAIsliderCurrent.MachinePts = value * const.ResourceScale
        end -- if option_id

        -- Change option for EAImaxElectronics
    	  if option_id == "EAImaxElectronics" then
        	g_EAIsliderCurrent.Electronics = value * const.ResourceScale
        end -- if option_id

        -- Change option for EAImaxSeeds
    	  if option_id == "EAImaxSeeds" then
        	g_EAIsliderCurrent.Seeds = value * const.ResourceScale
        end -- if option_id

        -- apply changes now
        if option_id == "Apply" and token ~= "Reset" then
        	if lf_print then print("Toggled Apply") end
        	if value == true then -- Apply and retoggle button
        		EAIupdateSliders()
        		CreateRealTimeThread(function()
        			Sleep(2000) -- Short delay to show the toggle
        			if lf_print then print("Reset Apply") end
        			ModConfig:Toggle("EAI", "Apply", "Reset")
        		end) -- end RealTimeThread
        	end
        end

    end -- end if g_ModConfigLoaded
end -- end OnMsg.ModConfigChanged


function OnMsg.CityStart()

	EAIupdateSliders()
	WaitForModConfig()

end -- OnMsg.CityStart()

function OnMsg.LoadGame()

  EAIupdateSliders()
  WaitForModConfig()

end -- OnMsg.LoadGame()