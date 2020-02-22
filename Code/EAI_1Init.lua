-- Code developed for Elevator A.I.
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created Sept 5th, 2018
-- Updated August 22nd, 2019

local lf_debug   = false  -- used only for certain ex() instances
local lf_printcf = false  -- used to print class fires
local lf_print   = false  -- Setup debug printing in local file
local lf_printrm = false  -- Used like lf_print but only for Rare Metals related code
                          -- Use if lf_print then print("something") end

g_EAInoticeDismissTime = 10000  -- 10 seconds the dismiss time for notifications

-- The reference for where the AI currently resides.
GlobalVar("g_EAI", function() return {
	GUID = false,
	elevator = false,
} end) -- g_EAI


local ModDir = CurrentModPath
local steam_id = "1504430797"
local mod_name = "Elevator A.I."
local StringIdBase = 1776300000 -- Elevator AI, File starts at 100, Next = 109
local iconEAINotice    = ModDir.."UI/Icons/noticeEAIIcon.png"
local iconEAINoticeRed = ModDir.."UI/Icons/noticeEAIIconRed.png"
local EAIRunningTasks  = {} -- variable table to keep track of running tasks so they are not called multiple times while already running
local EAInotices       = {} -- variable table to keep track of all notices


-- create elevator ai restocking queue template
-- A table of tables indexed by resource name with the following fields
-- restock   -- the target order and threshold amount the slider is set for the particular resource; zero if blacklisted
-- instock   -- realtime instock quantity of the resource
-- order     -- the amount to order if instock is less than restock
-- processed -- amount of resources processed during the CargoManifestReq process; useful for debugging not using in processes
-- itemprice -- the price of one resource
-- unitprice -- the price of the package of that resource in the games default package
-- unitpack  -- the number of that resource in a unit package
-- weight    -- the weight of one resource
-- elevatorkey -- the elevator object variable key(index key) that the sliders use
-- blacklisted -- the allowed status of the resource based on gameplay, set at time of request; default = false
-- elevatordiscount -- the discount applied from the elevator price_mod
-- sponsordiscount  -- the discount applied from the sponsor defaults
local RestockingResources = {"Concrete", "Metals", "Food", "Polymers", "MachineParts", "Electronics", "Seeds"}
local EAI_restockQtemplate = {}
for _, resource in pairs(RestockingResources) do
	EAI_restockQtemplate[resource] = {restock = 0, instock = 0, order = 0, processed = 0, itemprice = 0, unitprice = 0, unitpack = 0, weight = 0, elevatorkey = "", blacklisted = false, elevatordiscount = 0, sponsordiscount = 0}
end -- for each resource


--[[
-- space elevator cargo order template -- not used but good for reference purposes
local EAI_cargoTemplate = {
	{amount = 0, class = "Concrete"},
	{amount = 0, class = "Metals"},
	{amount = 0, class = "Food"},
	{amount = 0, class = "Polymers"},
	{amount = 0, class = "MachineParts"},
	{amount = 0, class = "Electronics"}
	{amount = 0, class = "Seeds"}
} --EAI_cargo
--]]


-- used to copy template tables instead of using table memory references
local function TableCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[TableCopy(orig_key)] = TableCopy(orig_value)
        end
        setmetatable(copy, TableCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end -- TableCopy(orig)


-- function to add commas to numbers
-- used for display purposes onlyto add comma separators to long numbers
local function comma_value(amount)
  local formatted = amount
  local k
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end -- comma_value(amount)


-- checks to make sure building is working and AI installed and enabled
local function EAIisWorking(elevator)
	if not elevator then return false end
	return elevator.working and elevator.EAI_enabled
end --IsWorking(building)


-- checks to see if the resource is on the blacklist
function EAIisResourceBlacklisted(resource)
  -- taken from XPGMission.lua
	if resource == "Food" and IsGameRuleActive("Hunger") then
		return true
	end -- if resource
	if g_ImportLocks[resource] and next(g_ImportLocks[resource]) ~= nil then
		return true
	end -- g_ImportLocks
	return false
end --IsResourceBlacklisted()


-- this checks the colony realtime stock and creates and returns the restockQ request. returns false if nothing needed.
-- debugcode is optional and boolean.  if true it will order restock amounts of each resource set by the sliders -- for testing only.
local function EAIcheckColonyStock(debugcode)
	if lf_print then print("---- Running EAIcheckColonyStock ---- debugcode: ", tostring(debugcode)) end
	local elevator = g_EAI.elevator
	if not EAIisWorking(elevator) then return false end  -- quick check to make sure all is valid.

  local restockQ = TableCopy(EAI_restockQtemplate)
  local ResDef   = ResupplyItemDefinitions -- ResupplyItemDefinitions defined in PreGameMission.lua RocketPayload_Init
  local sponsor     = GetMissionSponsor()
  local hasOrders   = false -- mark restockQ if has any orders or not.
  local EAIisResourceBlacklisted = EAIisResourceBlacklisted
  -- get realtime colony resource data
  local colonystock = {}
  GatherResourceOverviewData(colonystock) -- use this instead of ResourceOverviewObj since ResourceOverviewObj thread does not update fast enough

  -- load up restockQ
  for resource, item in pairs(restockQ) do
  	local itemError = false
  	local itemdef = table.find_value(ResDef, "id", resource)  -- load up the resources games defaults and properties
  	-- check for bad resource def
  	if type(itemdef) == "nil" then
  		ModLog(string.format("NOTICE - EAI found a missing resource definition - %s - This item will not be ordered.", resource))
  		item.error = 0
  	end -- if type

  	item.elevatorkey = string.format("EAI_restock_%s", resource) -- duplicate the slider key
  	item.blacklisted = EAIisResourceBlacklisted(resource)
  	item.elevatordiscount = elevator.price_mod
  	item.sponsordiscount  = sponsor.CostModifierPercent
  	item.restock  = item.error or (not item.blacklisted and MulDivRound(1, elevator[item.elevatorkey], 1000)) or 0 -- make restock = 0 if blacklisted
  	item.instock  = MulDivRound(1, colonystock[resource], 1000) -- calc the resources on hand in the colony
    if (item.instock < item.restock) or debugcode then
    	-- if colony stock is lower than threshold or debugging, order the threshold amount
    	item.order = item.restock
    	hasOrders = true  -- indicate this restockQ has at least one order
    end -- if ordering
  	item.unitprice = item.error or itemdef.price
  	item.unitpack = item.error or itemdef.pack
  	-- calc price per item with elevator and sponsor discounts
  	-- discounts are not % off but modifier labels for % of original price to charge
  	local peritemprice = item.error or MulDivRound(1, itemdef.price, itemdef.pack) -- per item list price
  	peritemprice = MulDivRound(peritemprice, item.elevatordiscount, 100)  -- discount price using elevator discount see XPGMission.lua
  	peritemprice = MulDivRound(peritemprice, item.sponsordiscount, 100) -- discount price using sponsor discount see XPGMission.lua
  	item.itemprice = peritemprice
  	item.weight    = item.error or MulDivRound(1, itemdef.kg, itemdef.pack) -- item weight per item
  end -- for resource, item -- end load up restockQ

  if not hasOrders then restockQ = false end -- return false for no orders
  if lf_debug and hasOrders then ex(restockQ) end
  if lf_print then print("EAIcheckColonyStock finished") end

  return restockQ
end -- EAIcheckColonyStock()


-- create a cargo manifest request of cargo needed.
local function EAIcreateCargoManifestReq(restockQ)
	if lf_print then print(" ---- Running EAIcreateCargoManifestReq ----") end
	local elevator = g_EAI.elevator
	if not EAIisWorking(elevator) then return false end  -- quick check to make sure all is valid.

	local weightcapacity = elevator.cargo_capacity
	local batchidx = 1 -- current cargomanifest batch index (pages of manifest)
	local cargoidx = 0 -- current cargo type index
	-- each cargomanifest[batchidx] is like a page with a 2x5 table on it (amount and class) which mimics the
	-- space elevator cargomanifest plus adds some summary info.
	-- the cargomanifest page has a weight limit which is the same as one load on the space elevator.
	-- when the weight is maxed, then a new page (batchidx) is created
	-- make the first batch right away, like a blank piece of paper with some summary info on it.
	local cargomanifestTemplate = {maxweightcapacity = weightcapacity, weight = 0, cost = 0, ordered = false}
	local cargomanifest  = {}
	cargomanifest[1] = TableCopy(cargomanifestTemplate)
	cargomanifest[1].cargo = {}

  -- fill cargomanifest batch pages with cargo, start a new page if needed due to weight capacity per batch
  for resource, item in pairs(restockQ) do
  	if lf_print then print("Checking for :", resource) end
  	if item.order > 0 then
  		if lf_print then print("Processing :", resource) end
  		local resourceOrderTotal = item.order
  		cargoidx = cargoidx + 1 -- assign new cargo index to new resource
  		while item.order > 0 do
  			if (cargomanifest[batchidx].maxweightcapacity - cargomanifest[batchidx].weight) >= item.weight then
  				-- if the item fits into this batch
  				if not cargomanifest[batchidx].cargo[cargoidx] then
  					if lf_print then print("New Cargo batch cargo manifest item created") end
  					cargomanifest[batchidx].cargo[cargoidx] = {amount = 0, class = resource}  -- Duplicate elevator cargo manifest format
  				end -- if no cargo manifest in batch
  				cargomanifest[batchidx].cargo[cargoidx].amount = cargomanifest[batchidx].cargo[cargoidx].amount + 1  -- add the item to cargo manifest
  				cargomanifest[batchidx].weight = cargomanifest[batchidx].weight + item.weight -- add the item weight to batch
  				cargomanifest[batchidx].cost = cargomanifest[batchidx].cost + item.itemprice -- add the per item price to the batch
  				item.order = item.order - 1 -- subtract the item from the order
  				item.processed = item.processed + 1
  			else
  				-- batch full, create a new cargo batch
  				if lf_print then print("New Manifest batch created") end
  				batchidx = batchidx + 1 -- make a new/next batch index
  				cargoidx = 1 -- reset cargo index for new batch
  				cargomanifest[batchidx] = TableCopy(cargomanifestTemplate) -- make a new batch
  				cargomanifest[batchidx].cargo = {}
  			end -- if cargo fits into this batch
  		end -- while loop until all items are batched
  		if lf_print then print("Finished processing: ", resource, " Total order: ", resourceOrderTotal) end
  	end -- if item.order > 0
  end -- for resource
  if lf_print then print("Cargo Manifest Processing Complete") end

  if lf_debug then ex(cargomanifest) end
  if lf_print then print("EAIcreateCargoManifestReq finished") end

  return cargomanifest
end -- EAIcreateCargoManifestReq(restockQ)


-- main restock function called in OnMsg.Newhour on set frequency schedule
-- debugcode is optional and boolean.  if true it will simulate an order for restock amounts of each resource -- for testing only
-- debugfunds is optional and integer.  if set it will replace true colony funds with this amount -- for testing only
-- this function is global to be able to call from console line for testing
function EAIRestock(debugcode, debugfunds)
	if lf_print then print("---- Running EAIRestock ---- debugcode: ", tostring(debugcode), "   debugfunds: ", tostring(debugfunds)) end
	local elevator = g_EAI.elevator
	local ordersuccess       = false
	local ordersRemaining    = 0
	local totalmanifestcost  = 0
	local reasoncode  = "No restock needed"
	local UICity      = UICity
	local colonyfunds = debugfunds or (UICity.funding or 0) -- debugfunds is used for testing only UICity.funding is cash on hand.
	local notifyOnOrderStart = true -- check to see if we already sent a notification on order processing start

  -- Check if elevator is working and AI installed and enabled
  if not EAIisWorking(elevator) then return ordersuccess, ordersRemaining, totalmanifestcost, "Elevator A.I. not installed or not operating." end  -- quick check to make sure all is valid.
  if lf_print then print("Elevator valid, working and AI Installed") end

	-- Check if game mission resupply is enabled
	if g_Consts.SupplyMissionsEnabled ~= 1 then
		if not EAInotices.prohibited then
			EAInotices.prohibited = true
	  	AddCustomOnScreenNotification("EAI_Notice", T{StringIdBase + 100, "Elevator A.I Paused"}, T{StringIdBase + 101, "Elevator A.I. is prohibited from operating. Resupply is disabled."}, iconEAINoticeRed, nil, {priority = "Important", cycle_objs = {elevator}, expiration = g_EAInoticeDismissTime})
		  PlayFX("UINotificationResearchComplete", g_EAI.elevator)
		end -- if not EAInotice.prohibited
		return ordersuccess, ordersRemaining, totalmanifestcost, "Mission resupply is disabled."
	elseif g_Consts.SupplyMissionsEnabled == 1 and EAInotices.prohibited then
		EAInotices.prohibited = nil
	  AddCustomOnScreenNotification("EAI_Notice", T{StringIdBase + 102, "Elevator A.I Running"}, T{StringIdBase + 103, "Elevator A.I. is running."}, iconEAINotice, nil, {cycle_objs = {elevator}, expiration = g_EAInoticeDismissTime})
	  PlayFX("UINotificationResearchComplete", g_EAI.elevator)
	end -- if g_Consts.SupplyMissionsEnabled ~= 1

	-- Check if space elevator is already busy with tasks
	if elevator:IsBusy() then return ordersuccess, ordersRemaining, totalmanifestcost, "#### Elevator is busy with tasks ####" end

  local restockQ = EAIcheckColonyStock(debugcode)
  if not restockQ then
  	if lf_print then print("EAIRestock Exiting - Nothing to order in restockQ") end
  	return ordersuccess, ordersRemaining, totalmanifestcost, reasoncode  -- send back ordersuccess, ordersRemaining, totalmanifestcost, reasoncode
  end -- if not restockQ

  local CargoOrderManifest = EAIcreateCargoManifestReq(restockQ)
  if not CargoOrderManifest then
  	if lf_print then print("EAIRestock Exiting - Nothing to order in CargoOrderManifest") end
  	return ordersuccess, ordersRemaining, totalmanifestcost, reasoncode  -- send back ordersuccess, ordersRemaining, totalmanifestcost, reasoncode
  end -- if not CargoOrderManifest

  -- local function to calc all the unprocessed orders and costs
  local function UnprocessedOrders()
  	local amount = 0
  	local cost = 0
  	for idx = 1, #CargoOrderManifest do
  		if not CargoOrderManifest[idx].ordered then
  	    for _, item in pairs(CargoOrderManifest[idx].cargo) do
  	  	  amount = amount + item.amount
  	    end -- for each item
  	    cost = cost + CargoOrderManifest[idx].cost
  		end -- if not ordered
  	end -- for each CargoOrderManifest
  	return amount, cost
  end --  UnprocessedOrders()

  -- calc opening orders
  ordersRemaining, totalmanifestcost = UnprocessedOrders()

  if lf_print then print("Placing Orders: Manifest batches: ", #CargoOrderManifest, "  Total items in order: ", ordersRemaining, "  Total manifest cost: ", comma_value(totalmanifestcost), "  Colony funds: ", comma_value(colonyfunds)) end

  -- run through CargoOrderManifest and place all the orders with the space elevator
  -- there is at least one cargo manifest batch so if nothing is needed then all items show zero.
  -- this will go through the motions but not send the elevator and set the ordersuccess to true
  for idx, CargoOrder in pairs(CargoOrderManifest) do
  	colonyfunds = debugfunds or (UICity.funding or 0) -- if testing funds then use debugfunds
  	if CargoOrder.cost <= colonyfunds then
  		-- if enough funds to reorder cargo
  		if notifyOnOrderStart and ordersRemaining > 0 then
  			notifyOnOrderStart = false
  			-- send notification on order start and if there are items to order -- just once per CargoOrderManifest
  			AddCustomOnScreenNotification("EAI_Notice_Order", T{StringIdBase + 104, "Elevator A.I Order"}, T{StringIdBase + 105, "Elevator A.I is restocking the colony."}, iconEAINotice, nil, {cycle_objs = {elevator}, expiration = g_EAInoticeDismissTime})
  		  PlayFX("UINotificationResearchComplete", g_EAI.elevator)
  		end -- if notifyOnOrderStart
  		if not debugcode then elevator:OrderResupply(CargoOrder.cargo, CargoOrder.cost) end -- if testing do not actually order anything
  		if debugfunds then debugfunds = debugfunds - CargoOrder.cost end -- if testing funds then use debugfunds
  		if lf_print then print("Ordering manifest batch: ", idx) end
  		CargoOrder.ordered = true  -- Set the manifest batch as ordered so its not counted in UnprocessedOrder()
  		ordersuccess = true -- set once to indicate at least one order was successfull
  	end -- if CargoOrder.cost <= colonyfunds
  end -- for each CargoOrder

  -- calc orders remaining
  ordersRemaining, totalmanifestcost = UnprocessedOrders()

  -- change ordersuccess reasoncode and notify
  if ordersuccess and ordersRemaining > 0 then
  	reasoncode = "Not enough funds for entire order but partial orders filled."
  	AddCustomOnScreenNotification("EAI_Notice_Order", T{StringIdBase + 106, "Elevator A.I Order Status"}, T{StringIdBase + 107, "Elevator A.I ran out of funds during reorder.  Some orders have been filled."}, iconEAINotice, nil, {priority = "Important", cycle_objs = {elevator}, expiration = g_EAInoticeDismissTime})
    PlayFX("UINotificationResearchComplete", g_EAI.elevator)
  elseif not ordersuccess and ordersRemaining > 0 then
  	reasoncode = "No orders filled.  Not enough funds."
  	AddCustomOnScreenNotification("EAI_Notice_Order", T{StringIdBase + 106, "Elevator A.I Order Status"}, T{StringIdBase + 108, "No orders processed. Not enough funds."}, iconEAINoticeRed, nil, {priority = "Important", cycle_objs = {elevator}, expiration = g_EAInoticeDismissTime})
    PlayFX("UINotificationResearchComplete", g_EAI.elevator)
  elseif ordersuccess and ordersRemaining == 0 then
  	reasoncode = "All orders filled."
  	-- no notifications
  end -- if ordersuccess and partialsuccess

  -- send back success, leftover items, leftoveritems cost, reason
  return ordersuccess, ordersRemaining, totalmanifestcost, reasoncode
end --EAIRestock()


-- main rare metals checking function called in OnMsg.Newhour every hour to prevent or allow exports
-- this function is global to be able to call from console line for testing
-- callfrom     -- the source of the call -- for debug purposes
-- debugcode    -- is optional -- show ex()
-- debugmetals  -- is optional -- override raremetals in stock -- used for testing the function
-- debugslider  -- is optional -- override the slider settings
function EAIautoExport(callfrom, debugcode, debugmetals, debugslider)
	if lf_printrm then print("++++ Running EAIautoExport ---- callfrom: ", tostring(callfrom), "   debugcode: ", tostring(debugcode), "   debugmetals: ", tostring(debugmetals), "   debugslider: ", tostring(debugslider)) end

	local elevator = g_EAI.elevator
	if not EAIisWorking(elevator) then return false, "Elevator Not Working" end

  -- check if EAI is in control of exports, if not, exit.
	local export_threshold = debugslider or elevator.EAI_export_threshold or 0
	local EAIincontrol = export_threshold > 0
	if not EAIincontrol then
		elevator:EAIRestoreExportStorage() -- do this again just in case the fire was missed, it only executes once anyway
		return false, "EAI not in control of exports"
	end -- if not EAIincontrol

  -- check if EAIautoExport is already running in case its called from another process
  if EAIRunningTasks.EAIautoExport then return false, string.format(" !!!!!! EAIautoExport already running: %s !!!!!", EAIRunningTasks.EAIautoExport)
                                   else EAIRunningTasks.EAIautoExport = GameTime() end
   if lf_printrm then print("---- EAIautoExport start time: ", EAIRunningTasks.EAIautoExport) end

	  -- gather raremetalsInStock
	local colonystock = {}
  GatherResourceOverviewData(colonystock) -- use realtime data instead of ResourceOverviewObj since ResourceOverviewObj thread does not update fast enough
  local raremetalsInStock = debugmetals or colonystock.PreciousMetals or 0  -- use debugmetals when debugging
  raremetalsInStock = raremetalsInStock + elevator:GetStoredExportResourceAmount() -- count the inventory in the elevator so we dont cycle the elevator when loading the last bit of excess

  -- calc maximum amount of export allowed
  local excess_export_amount = 0
  if (raremetalsInStock > export_threshold) then excess_export_amount = raremetalsInStock - export_threshold end

  --## The following is code to alter elevator storage when excess exports is less than storage
  -- if export excess is less than elevator storage then shrink the storage
  local exportbufferpct = 5  -- percent of the export_threshold to use as the buffer
  local exportbuffer = MulDivRound(export_threshold, exportbufferpct, 100) -- the buffer number used to calculate when to raise the max_export_storage to prevent flapping
  if lf_printrm then print("export buffer set: ", exportbuffer) end
  -- this keeps getting lower if stock gets depleated until max_export_storage is zero
  if excess_export_amount < elevator.max_export_storage then
    -- save the original maximum storage amount the first time for the restore functions later
    if not elevator.EAI_original_max_export_storage then elevator.EAI_original_max_export_storage = elevator.max_export_storage end
  	-- set elevator max_export_storage to no more than the excess rare metals if excess less than max_export_storage
  	if lf_printrm then print("Exports are less than elevator storage - resetting max_export_storage to: ", excess_export_amount) end
  	elevator:EAIAdjustExportStorage(excess_export_amount)  -- reset to new max_export_storage
  elseif elevator.EAI_original_max_export_storage and ((excess_export_amount - exportbuffer) >= elevator.max_export_storage) and (excess_export_amount <=  elevator.EAI_original_max_export_storage) then
  	-- if EAI_original_max_export_storage is set then max_export_storage is still not equal.
  	-- the following only happens if excess exports minus exportbuffer > max_export_storage but less than original amount, so we dont flap the exports during mining and consumption
  	-- reset the elevator max_export_storage since we have more excess now
  	if lf_printrm then print("Exports increased more than elevator storage but still less than original - resetting max_export_storage to: ", excess_export_amount) end
  	elevator:EAIAdjustExportStorage(excess_export_amount) -- reset to new max_export_storage
  elseif elevator.EAI_original_max_export_storage and excess_export_amount >= elevator.EAI_original_max_export_storage then
    -- excess exports are now higher than original storage amount.  reset storage and continue.
  	elevator:EAIRestoreExportStorage() -- reset task demand and storage
  end --if excess_export_amount < elevator.max_export_storage
  --## end of elevator storage alerting code

  if debugcode then ex(colonystock, nil, "EAIautoExport - "..callfrom) end
	if lf_printrm then print("EAIincontrol: ", tostring(EAIincontrol), "   Elevator Export Status: ", elevator.allow_export, "   PreciousMetals Export Threshold: ", export_threshold, "   PreciousMetals in stock: ", raremetalsInStock) end

  -- check if allow_export threshold reached and toggle exports if EAI is in control
  local allow_export = (not (export_threshold == 0)) and (raremetalsInStock > export_threshold)
  if allow_export and (not elevator.allow_export) then
  	if not debugcode then elevator:ToggleAllowExport() end  -- if not enabled export then enable, if debug do nothing
  elseif (not allow_export) and elevator.allow_export then
  	if not debugcode then elevator:ToggleAllowExport() end  -- if enabled export then disable, if debug do nothing
  end -- if allow_export

  -- send notification once that EAI is controlling the export process
  if not EAInotices.controlling_exports then
  	EAInotices.controlling_exports = true
  	AddCustomOnScreenNotification("EAI_Notice_Exports", T{StringIdBase + 109, "Elevator A.I Auto Export"}, T{StringIdBase + 110, "Elevator A.I is controlling exports."}, iconEAINotice, nil, {cycle_objs = {elevator}, expiration = g_EAInoticeDismissTime})
    PlayFX("UINotificationResearchComplete", g_EAI.elevator)
  end -- if not EAInotices.controlling_exports

  if lf_printrm then print(string.format("==== EAIautoExport End Time: %s    allow_export: %s    EAIincontrol: %s", EAIRunningTasks.EAIautoExport, allow_export, EAIincontrol)) end
  EAIRunningTasks.EAIautoExport = nil
end --EAIautoExport()


-- calculates next frequency fire, and schedule
-- function global since used in IP's
function EAIcalcNextFrequencyTime()
	local elevator = g_EAI.elevator
  if not EAIisWorking(elevator) then return -1, {"-1"} end  -- return table with entry 1 = -1 to show disabled since Elevator AI or Elevator not working.

  local timeslots = {}
  local frequency = elevator.EAI_restock_frequency
  local interval = MulDivRound(1, 24, frequency)
  if interval > 4 and frequency > 4 then interval = 4 end -- Make sure to stay within 24 hour periods due to rounding issues with MulDivRound

  timeslots[1] = interval
  if timeslots[1] == 24 then timeslots[1] = 0 end

  for i = 2, frequency do
    timeslots[i] = timeslots[i-1] + interval
    if timeslots[i] == 24 then timeslots[i] = 0 end
  end -- for i

  table.sort(timeslots)

  local currenthour = UICity.hour
  local returnhour  = false
  -- check to see if the current hour is later than last hour in timeslots.
  -- If true set to under 0 to compare to timeslots and start from beginning of clock
  if currenthour > timeslots[#timeslots] then currenthour = -1 end

  for i = 1, #timeslots do
    if timeslots[i] >= currenthour then
    	returnhour = timeslots[i]
      break
    end -- if timeslots
  end -- for i
  return returnhour, timeslots
end -- EAIcalcNextFrequencyTime()


-------- OnMsgs ---------------------------------------------------------------------------

function OnMsg.ClassesBuilt()


  -- this function does not exist in SpaceElevator it is an ancestor
  -- make a new function and hook into OnDemolish to remove the A.I first.
  local Old_SpaceElevator_OnDemolish = SpaceElevator.OnDemolish -- Hooks into the ancestor
  function SpaceElevator:OnDemolish()
  	if lf_printcf then print("---- SpaceElevator OnDemolish fired ----") end
	  if g_EAI.elevator and self == g_EAI.elevator then
	  	if (lf_printcf) then print("Elevator A.I. destroyed") end
	  	g_EAI.GUID = false
	  	g_EAI.elevator = false
	  	self.EAI_enabled = false
	  	self.EAI_installed = nil
	  	self.description = self.description_old
	  end -- if self contains the A.I.
    Old_SpaceElevator_OnDemolish(self)
  end -- SpaceElevator:OnDemolish()

  local Old_SpaceElevator_OnDestroyed = SpaceElevator.OnDestroyed
  function SpaceElevator:OnDestroyed()
  	if lf_printcf then print("---- SpaceElevator OnDestroyed fired ----") end
  	Old_SpaceElevator_OnDestroyed(self)
  end --SpaceElevator:OnDestroyed()

	local Old_SpaceElevator_InitResourceSpots = SpaceElevator.InitResourceSpots
	function SpaceElevator:InitResourceSpots()
		if lf_printcf then print("---- SpaceElevator InitResourceSpots fired ----") end
		Old_SpaceElevator_InitResourceSpots(self)
	end

	local Old_SpaceElevator_ReturnStockpiledResources = SpaceElevator.ReturnStockpiledResources
	function SpaceElevator:ReturnStockpiledResources()
		if lf_printcf then print("---- SpaceElevator ReturnStockpiledResources fired ----") end
		Old_SpaceElevator_ReturnStockpiledResources(self)
	end

	local Old_SpaceElevator_ReturnResources = SpaceElevator.ReturnResources
	function SpaceElevator:ReturnResources()
		if lf_printcf then print("---- SpaceElevator ReturnResources fired ----") end
		Old_SpaceElevator_ReturnResources(self)
	end

	local Old_SpaceElevator_OrderResupply = SpaceElevator.OrderResupply
	function SpaceElevator:OrderResupply(cargo, cost)
		if lf_printcf then
			print("---- SpaceElevator OrderResupply fired ----")
			--ex(cargo)
			--ex(self)
			print("Total cargo import cost: ", cost)
		end -- if print
		Old_SpaceElevator_OrderResupply(self, cargo, cost)
	end --SpaceElevator:OrderResupply

  local Old_SpaceElevator_BuildingUpdate = SpaceElevator.BuildingUpdate
	function SpaceElevator:BuildingUpdate()
		if lf_printcf then print("---- SpaceElevator BuildingUpdate fired ----") end
		Old_SpaceElevator_BuildingUpdate(self)
	end

  local Old_SpaceElevator_ExportGoods = SpaceElevator.ExportGoods
	function SpaceElevator:ExportGoods()
		if lf_printcf then
			print("---- SpaceElevator ExportGoods fired ----")
			--ex(self)
		end -- if print
		Old_SpaceElevator_ExportGoods(self)
	end

  local Old_SpaceElevator_CreateResourceRequests = SpaceElevator.CreateResourceRequests
	function SpaceElevator:CreateResourceRequests()
		if lf_printcf or lf_printrm then print("-+# SpaceElevator CreateResourceRequests fired #+-") end
		Old_SpaceElevator_CreateResourceRequests(self)
	end

  local Old_SpaceElevator_OnModifiableValueChanged = SpaceElevator.OnModifiableValueChanged
	function SpaceElevator:OnModifiableValueChanged(prop, old_val, new_val)
		if lf_printcf then print("---- SpaceElevator OnModifiableValueChanged fired ----") end
		Old_SpaceElevator_OnModifiableValueChanged(self, prop, old_val, new_val)
	end

  local Old_SpaceElevator_ResetDemandRequests = SpaceElevator.ResetDemandRequests
	function SpaceElevator:ResetDemandRequests()
		if lf_printcf or lf_printrm then print("-+# SpaceElevator ResetDemandRequests fired #+-") end
		Old_SpaceElevator_ResetDemandRequests(self)
	end

  --## My new functions in SpaceElevator ##--
  -------------------------------------------

	-- check is elevator has any unprocessed imports and pod is idle
  function SpaceElevator:IsBusy(noprint)
	  if (lf_print) and not noprint then print("Pod Busy: ", IsValidThread(self.pod_thread), "Import Q: ", tostring(#self.import_queue), "  Current Q: ", tostring(self.current_imports and #self.current_imports)) end
	  -- returns false if import q's are empty and pod is idle
	  local busy = IsValidThread(self.pod_thread) or (#self.import_queue > 0) or (self.current_imports and (#self.current_imports > 0))
	  if type(busy) == "nil" then busy = false end
	  if (lf_print) and not noprint then print("*** Busy: ", busy) end
	  return busy
  end --SpaceElevator:IsBusy(noprint)

  -- check for exports on deck and adjust max_export_storage
  -- return any excess to the colony on a pallet outside the elevator
  function SpaceElevator:EAIAdjustExportStorage(new_max_export_storage)
  	if lf_printcf then print("---- EAIAdjustExportStorage called ---- ") end

  	-- check to make sure new variable passed and also not equal otherwise just exit
  	if (not new_max_export_storage) or new_max_export_storage == self.max_export_storage then return end

  	local rareMetalsOnDeck = 0
  	local old_max_export_storage = self.max_export_storage

		-- cancel demand request, interrupt drones, remove PreciousMetals from demand request
		-- note: this is a slight difference from ToggleAllowExport, since we do not disconnect
		-- supply requests, just demand requests.
		if self.export_request then
			self:InterruptDrones(nil, function(drone)
												if (drone.target == self) or
													(drone.d_request and drone.d_request:GetBuilding() == self) or
													(drone.d_request and drone.d_request == self.export_request) then
													return drone
												end
			end) -- function
			self:DisconnectFromCommandCenters()

			rareMetalsOnDeck = self.max_export_storage - self.export_request:GetActualAmount() or 0
			self.max_export_storage = new_max_export_storage
			if lf_printcf then
				print("Rare metals on deck: ", rareMetalsOnDeck)
				print("New Max Storage: ", new_max_export_storage, "   Old Max Storage: ", old_max_export_storage)
			end -- if print

      local excess = 0
      if rareMetalsOnDeck > self.max_export_storage then excess = rareMetalsOnDeck - self.max_export_storage end
      self.export_request:SetAmount(self.max_export_storage - (rareMetalsOnDeck - excess))

      -- dump excess raremetals on palllet outside building
      if excess > 0 then self:PlaceReturnStockpile("PreciousMetals", excess) end

			self:ConnectToCommandCenters()
			ObjModified(self)
		end --if self.export_request
  end --SpaceElevator:EAIAdjustExportStorage()

  -- simple function combining two functions for code brevity.
  --function SpaceElevator:EAIResetExportStorage()
  --	if lf_printcf then print("---- SpaceElevator EAIResetExportStorage called ----") end
  	--self:EAIReturnExportResources() -- return the on deck export amounts since reset deletes them
    --self:ResetDemandRequests()      -- tell the task demand system the max changed
  --end --SpaceElevator:EAIResetExportStorage()

  -- resets the elevator max_export_storage to original amount
  function SpaceElevator:EAIRestoreExportStorage()
  	if self.EAI_original_max_export_storage and (self.max_export_storage < self.EAI_original_max_export_storage) then
  		if lf_printrm then print("Resetting max_export_storage to: ", self.EAI_original_max_export_storage) end
  		local new_max_export_storage = self.EAI_original_max_export_storage or (100 * const.ResourceScale)
      self:EAIAdjustExportStorage(new_max_export_storage)  -- reset to original max_export_storage
   	  self.EAI_original_max_export_storage = nil -- do this only once
   	end -- if elevator.EAI_original_max_export_storage
  end -- EAIRestoreExportStorage()

  -- restores previous export allowed status if different then current
  function SpaceElevator:EAIRestoreExportStatus()
		-- send a notice that EAI is no longer controlling exports if it was before
    if EAInotices.controlling_exports then
  	  EAInotices.controlling_exports = nil
  	  AddCustomOnScreenNotification("EAI_Notice_Exports", T{StringIdBase + 109, "Elevator A.I Auto Export"}, T{StringIdBase + 111, "Exports are now manually controlled."}, iconEAINotice, nil, {cycle_objs = {self}, expiration = g_EAInoticeDismissTime})
      PlayFX("UINotificationResearchComplete", g_EAI.elevator)
    end -- if EAInotices.controlling_exports
		-- flip toggle if needed
  	if self.EAI_export_prevsetting ~= self.allow_export then self:ToggleAllowExport() end
  end --SpaceElevator:EAIRestoreExportStatus()

  --------------------------------------------------
  --## End of my new functions in SpaceElevator ##--

end -- OnMsg.ClassesBuilt()

local function SRDailyPopup()
    CreateRealTimeThread(function()
        local params = {
              title = "Non-Author Mod Copy",
               text = "We have detected an illegal copy version of : ".. mod_name .. ". Please uninstall the existing version.",
            choice1 = "Download the Original [Opens in new window]",
            choice2 = "Damn you copycats!",
            choice3 = "I don't care...",
              image = "UI/Messages/death.tga",
              start_minimized = false,
        } -- params
        local choice = WaitPopupNotification(false, params)
        if choice == 1 then
        	OpenUrl("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. steam_id, true)
        end -- if statement
    end ) -- CreateRealTimeThread
end -- function end

function OnMsg.NewDay(day)
    if table.find_value(ModsLoaded, "steam_id", steam_id)~= nil then
    --nothing
    else
      SRDailyPopup()
    end
end -- NewDay


function OnMsg.NewHour(hour)
	-- perform Elevator A.I. restock
	local executeEAIRestock = EAIcalcNextFrequencyTime()
	if lf_print then
		print("**** New Hour fired ****")
		print("Next EAIRestock check: ", string.format("%02d:00", executeEAIRestock))
	end
	if hour == executeEAIRestock then EAIRestock() end

	-- perform Elevator A.I autoexport
	EAIautoExport(string.format("OnMsg.NewHour - %s", hour))
end -- OnMsg.NewHour(hour)