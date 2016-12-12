--[[
	Base Defend System.
	Server.
	
	By Mitchfizz05. Licensed under the terms of the MIT license (http://opensource.org/licenses/MIT).
]]

local api = ...

local state = api.getState()

local sectors = {}

-- Tables for timers.
local purgeSectorTimers = {}
local alarmTimers = {}

local detectors = {}


--[[
	Sector class.
]]
local Sector = {}
Sector.__index = Sector
function Sector.new(id)
	local self = setmetatable({}, Sector)
	
	self.id = id
	
	-- Get devices
	self.detectors = api.getDevices("detector", self.id)
	self.teslas = api.getDevices("tesla", self.id)
	self.alarms = api.getDevices("alarm", self.id)
	
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

---


local function getSector(id)
	if sectors[id] == nil then
		sectors[id] = Sector.new(id)
	end
	return sectors[id]
end


api.onReady(function ()

	detectors = api.getDevices("detector")

	-- Bind to detector events
	for _,detector in ipairs(detectors) do
		detector.events.onTriggered = function (trigger)
			-- Detector triggered!
			local sectorId = detector.config.sector
			if trigger then
				
				if (state.status == api.STATUSES.normal) and (detector.config.detectType == "mob") then
					print("Mob detected in sector " .. sectorId .. "!")
				
					getSector(sectorId):setAlarm(4)
					-- TODO: isolate sector
					
					-- Purge sector after 10 seconds.
					getSector(sectorId):delayPurge(2, 2) -- TODO: change this back to 10 seconds
				end
				
			end
		end
	end
	
end)

api.onRun(function ()
	while true do
		local e = {os.pullEvent()}
	end
end)
