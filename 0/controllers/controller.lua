--[[
	Base Defend System.
	Server.
	
	By Mitchfizz05. Licensed under the terms of the MIT license (http://opensource.org/licenses/MIT).
]]

local api = ...

local state = api.getState()
local config = api.getConfig()

local sectors = {}

-- Tables for timers.
local purgeSectorTimers = {}
local alarmTimers = {}

local devices = {}
local detectors = {}
local teslas = {}
local doors = {}
local alarms = {}

--[[
	Work out which doors to which sectors should be closed to fullfil isolation requirements.
]]
local function calculateDoorIsolation()
	local lockDoors = {}
	
	-- Find all doors that need to be locked.
	for _,sector in ipairs(sectors) do
		if sector.isolated then
			for _,door in ipairs(sector.doors) do lockDoors[#lockDoors + 1] = door end
		end
	end
	
	-- Open all doors
	for _,door in ipairs(doors) do
		door.activate(true)
	end
	
	-- Lock all doors that should be locked down.
	for _,door in ipairs(lockDoors) do
		door.activate(false)
	end
end


--[[
	Sector class.
]]
local Sector = {}
Sector.__index = Sector
function Sector.new(id)
	local self = setmetatable({}, Sector)
	
	self.id = id
	self.isolated = false
	
	-- Get devices
	self.detectors = api.getDevices("detector", self.id)
	self.teslas = api.getDevices("tesla", self.id)
	self.alarms = api.getDevices("alarm", self.id)
	self.doors = api.getDevices("door", self.id)
	
	return self
end

-- Perform a purge after a set time delay.
function Sector:delayPurge(countdown, purgeTime)
	print("Purge in sector " .. self.id .. " in " .. countdown .. " seconds!")
	
	callback.new(function ()
		self:immediatePurge(purgeTime)
	end, countdown)
end

-- Immediately purge a sector.
function Sector:immediatePurge(purgeTime)
	for _,tesla in ipairs(self.teslas) do
		tesla.activate(true)
		
		-- Queue deactivation of tesla
		TeslaTimerID = callback.new(function ()
			tesla.activate(false)
		end, purgeTime)
	end
end

-- Set alarm
function Sector:setAlarm(alarmTime)
	for _,alarm in ipairs(self.alarms) do
		alarm.activate(true)
		
		AlarmTimerID = callback.new(function ()
			alarm.activate(false)
		end, alarmTime)
	end
end

-- Isolate sector.
function Sector:isolate(isolateTime)
	-- Isolate sector and request recalculation of doors.
	self.isolated = true
	calculateDoorIsolation()
	
	-- Queue unisolate, if requested.
	if isolateTime ~= nil then
		callback.new(function ()
			self.isolated = false
			calculateDoorIsolation()
		end, isolateTime)
	end
end

---

--[[
	Set a new base status.
]]
local lastStatus = nil
local purgeTimedOut = false
local purgeRevertCallback
function setStatus(newStatus)
	lastStatus = state.status
	state.status = newStatus
	print("Status change: " .. lastStatus .. " -> " .. newStatus)
	
	if lastStatus == api.STATUSES.purge then
		-- Revert purge.
		for _,alarm in ipairs(alarms) do alarm.activate(false) end -- disable alarms
		for _,tesla in ipairs(teslas) do tesla.activate(false) end -- disable teslas
		calculateDoorIsolation() -- revert doors
		
		-- Cancel pending callback to revert to high alert. We only do this if the callback wasn't the thing to trigger the end of the purge.
		if not purgeTimedOut then
			callback.cancel(purgeRevertCallback)
		end
	end
	
	if newStatus == api.STATUSES.purge then
		-- Purge status :O
		for _,alarm in ipairs(alarms) do alarm.activate(true) end -- enable alarms
		for _,door in ipairs(doors) do door.activate(false) end -- close doors
		for _,tesla in ipairs(teslas) do tesla.activate(true) end -- enable teslas
		
		-- Revert after purge revert time.
		purgeTimedOut = false
		purgeRevertCallback = callback.new(function ()
			purgeTimedOut = true
			setStatus(api.STATUSES.high_alert)
		end, config.purge_revert_time)
	end
end


local function getSector(id)
	if sectors[id] == nil then
		sectors[id] = Sector.new(id)
	end
	return sectors[id]
end


api.onReady(function ()

	devices = api.getDevices()
	detectors = api.getDevices("detector")
	teslas = api.getDevices("tesla")
	doors = api.getDevices("door")
	alarms = api.getDevices("alarm")
	
	-- Init sectors
	for _,device in ipairs(devices) do
		local ids = device.config.sector
		if type(ids) == "number" then ids = {ids} end
		
		for _,sectorId in ipairs(ids) do getSector(sectorId) end
	end

	-- Bind to detector events
	for _,detector in ipairs(detectors) do
		detector.events.onTriggered = function (trigger)
			-- Detector triggered!
			local sectorId = detector.config.sector
			if trigger then
				
				if (state.status == api.STATUSES.normal) and (detector.config.detectType == "mob") then
					print("Mob detected in sector " .. sectorId .. "!")
					
					local totalTime = config.normal_purge_countdown + config.normal_purge_time
				
					-- Sound alarm.
					getSector(sectorId):setAlarm(totalTime)
					
					-- Isolate sector
					getSector(sectorId):isolate(totalTime)
					
					-- Purge sector
					getSector(sectorId):delayPurge(config.normal_purge_countdown, config.normal_purge_time)
				end
				
			end
		end
	end
	
	calculateDoorIsolation()
	
end)

api.onRun(function ()
	while true do
		os.pullEvent()
	end
end)
