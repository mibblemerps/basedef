--[[
	Base Defend System.
	Server.
	
	By Mitchfizz05. Licensed under the terms of the MIT license (http://opensource.org/licenses/MIT).
]]

-- Constants
local CHANNEL = "basedefend"
local NETWORK_NAME = "thelab"

-- Types of devices that can be on the network.
local DEVICE_TYPES = {
	"tesla_coil",
	"detector",
	"display",
	"alarm"
}

-- Names of lua scripts for devices.
local DEVICE_SCRIPTS = {
	detector = "detector.lua"
}

-- List of valid statuses the base can be in. See `statuses.md` for informaton on what these mean.
local STATUSES = {
	safe = 0,
	normal = 1,
	high_alert = 2,
	emergency = 3,
	purge = 4
}

-- Variables
local state = {
	status = STATUSES.normal
}
local devices = {} -- Devices connected to server

-- Maps RedNet IDs to device types. Required if device doesn't send out it's device type.
local deviceTypeMappings = {
	[1] = "detector",
	[2] = "tesla",
	[4] = "alarm",
	[5] = "door",
}

-- Maps RedNet IDs to device configs.
local deviceConfigMappings = {
	[1] = { -- Detector
		sector = 1,
		detectType = "mob"
	},
	[2] = { -- Tesla
		sector = 1
	},
	[4] = { -- Alarm
		sector = 1
	},
	[5] = { -- Door
		sector = {1, 2}
	},
}

local loadedDeviceScripts = {}

-- The controller object
local controller = nil

-- Load APIs
os.unloadAPI("lib/base64")
os.loadAPI("lib/base64")

os.unloadAPI("lib/callback")
os.loadAPI("lib/callback")


--[[
	Used for devices to interface with the base.
]]
local onReadyCallbacks = {}
local onRunCallbacks = {}
local DeviceApi = {
	CHANNEL = CHANNEL,
	NETWORK_NAME = NETWORK_NAME,
	STATUSES = STATUSES,
	DEVICE_TYPES = DEVICE_TYPES,

	-- Called once devices have been connected and the system is ready to go.
	onReady = function (callback)
		onReadyCallbacks[#onReadyCallbacks + 1] = callback
	end,
	
	-- Called when devices should run. Called once, each device on their own coroutine.
	onRun = function (callback)
		onRunCallbacks[#onRunCallbacks + 1] = callback
	end,

	-- Get current base state
	getState = function ()
		return state
	end,
	
	-- Get the table of devices.
	getDevices = function ()
		return devices
	end
}

--[[
	Used for the controller to interface with the system.
]]
local onControllerReadyCallbacks = {}
local onControllerRunCallbacks = {}
local ControllerApi = {
	CHANNEL = CHANNEL,
	NETWORK_NAME = NETWORK_NAME,
	STATUSES = STATUSES,
	DEVICE_TYPES = DEVICE_TYPES,
	
	-- Called once devices have been connected and the system is ready to go.
	onReady = function (callback)
		onControllerReadyCallbacks[#onControllerReadyCallbacks + 1] = callback
	end,
	
	-- Called when the controller should run. Called once, so make sure it doesn't terminate.
	onRun = function (callback)
		onControllerRunCallbacks[#onControllerRunCallbacks + 1] = callback
	end,

	-- Get current base state
	getState = function ()
		return state
	end,
	
	-- Get the table of devices. Optionally can provide type and sector filters.
	getDevices = function (name, sector)
		if name == nil then return devices end
		
		local found = {}
		for _,device in ipairs(devices) do
			if device.deviceType == name then
				local validSectors = {}
				if type(device.config.sector) == "table" then
					validSectors = device.config.sector
				else
					validSectors = {device.config.sector}
				end
				if (sector == nil) or table.contains(validSectors, sector) then
					found[#found + 1] = device
				end
			end
		end
		return found
	end
}

--[[
	Device class.
	A device is a computer connected via RedNet providing functionailty such as a tesla coils or mob detection.
]]
local Device = {}
Device.__index = Device

function Device.new(id, deviceType, deviceConfig)
	local self = setmetatable({}, Device)
	self.id = id
	self.deviceType = deviceType
	self.config = deviceConfig
	self.remoteExecuteSupported = false
	self.events = {}
	
	-- Create device script.
	self.deviceScript = assert(loadfile("devices/" .. self.deviceType .. ".lua"))(DeviceApi, self)
	
	return self
end

--[[
	Raise an event.
	
	name: Event name
	...: Event args
]]
function Device:raise(name, ...)
	if self.events[name] then
		self.events[name](unpack(arg))
	end
end

--[[
	Remotely execute code directly on device.
	
	codeBlock: Function to execute remotely.
	...: Args to be passed
	
	Returns success, result. (Result being return value from code block)
]]
function Device:remoteExecute(codeBlock, ...)
	local args = {...}

	local codeChunk = string.dump(codeBlock)
	
	-- Send code to be executed.
	rednet.send(self.id, {
		intent = "remote_execute",
		code = base64.encodeStr(codeChunk),
		args = args
	}, CHANNEL)
	
	-- Wait for response
	while true do
		local e,id,data,channel = os.pullEvent()
		
		if e == "rednet_message" and channel == CHANNEL and id == self.id then
		
			-- Response
			local success, result = pcall(function ()
				if data.intent == "remote_execute_response" then
					if data.success then
						return data.result
					else
						error(tostring(data.result) .. " (@" .. tostring(self.id) .. ")")
					end
				end
			end)
			if not success then
				print("Failed to process remote execute response!")
				print(result)
				break
			end
			
			-- Successful response
			return true, result
			
		end
	end
	
	-- Something went wrong if the code reached this far.
	return false
end



-- Check if table contains an element.
function table.contains(tbl, elm)
	for _,v in pairs(tbl) do
		if v == elm then
			return true
		end
	end
	return false
end

-- Open all RedNet modems.
local function openRednet()
	local opened = false
	for _,side in ipairs(rs.getSides()) do
		if peripheral.getType(side) == "modem" then
			rednet.open(side)
			opened = true
		end
	end
	return opened
end

local coroutineFilters = {}
local function runCoroutine(co, e)
	if (coroutineFilters[co] == nil) or (coroutineFilters[co] == e[1]) then
		local ok,param = coroutine.resume(co, unpack(e))
		
		if ok then
			coroutineFilters[co] = param
		else
			error(param) -- coroutine error!
		end
	end
end

local function cleanCoroutineFilters()
	for co,_ in pairs(coroutineFilters) do
		if coroutine.status(co) == "dead" then coroutineFilters[co] = nil end
	end
end

-- Scan RedNet for available devices.
local function scanDevices()
	-- Broadcast discover message.
	rednet.broadcast({
		intent = "discover",
		network_name = NETWORK_NAME
	}, CHANNEL)
	
	local timeoutTimer = os.startTimer(0.25)
	while true do
		local e, id, msg = os.pullEvent()
		
		if e == "timer" and id == timeoutTimer then
			-- Timeout
			break
		elseif e == "rednet_message" then
			-- New recruit.
			local meta = textutils.unserialise(msg)
			if type(meta) == "table" then
				-- Valid response
				if meta.intent == "connect" then
					-- New recruit!
					
					-- Work out device type
					local deviceType = meta.type
					if deviceType == nil then
						deviceType = deviceTypeMappings[id] -- get device type from mapping
					end
					if deviceType == nil then
						-- Still no device type. We have a problem.
						print("Cannot determine device type for " .. id .. ".")
					else
						if not fs.exists("devices/" .. deviceType .. ".lua") then
							error("Device type \"" .. deviceType .. "\" (for " .. id .. ") has no device script!")
						end
						
						local newDevice = Device.new(
							id,
							deviceType,
							deviceConfigMappings[id]
						)
						
						if meta.remoteExecute then
							-- Remote execute available.
							newDevice.remoteExecuteSupported = true
						end
						
						devices[#devices + 1] = newDevice
						
						print("New device connected (" .. id .. ") of type " .. deviceType .. "!")
					end
				end
			end
		end
	end
	
	print("Total of " .. #devices .. " device connected.")
end


-- Clear terminal
term.clear()
term.setCursorPos(1,1)

-- Init
if not openRednet() then
	print("Warning! No RedNet modems attached! Communication unavailable.")
end

-- Scan for devices
print("Waiting for devices to start...")
sleep(0.1) -- wait for devices to come online
scanDevices()


-- Ready - let devices perform initialisation.
print("Devices initialising...")
for _,callback in ipairs(onReadyCallbacks) do callback() end
print("Devices initalised.")


-- Initialise controller
print("Initialising controller...")
controller = assert(loadfile("controllers/controller.lua"))(ControllerApi)
for _,callback in ipairs(onControllerReadyCallbacks) do callback() end


-- Create run coroutines for controller
local controllerCoroutines = {}
for _,callback in ipairs(onControllerRunCallbacks) do
	local newCoroutine = coroutine.create(callback)
	
	controllerCoroutines[newCoroutine] = callback
end


-- Create run coroutines for each device.
local deviceCoroutines = {}
for _,callback in ipairs(onRunCallbacks) do
	local newCoroutine = coroutine.create(callback)
	
	deviceCoroutines[newCoroutine] = callback
end


-- Main execution loop.
print("System running.")
local e = {}
while true do
	-- Controller coroutines...
	for co,callback in pairs(controllerCoroutines) do
		if coroutine.status(co) == "suspended" then
			runCoroutine(co, e)
		else
			print("Coroutine dead.")
		end
	end

	-- Device coroutines...
	for co,callback in pairs(deviceCoroutines) do
		if coroutine.status(co) == "suspended" then
			runCoroutine(co, e)
		else
			print("Coroutine dead.")
		end
	end
	
	-- Pull event
	e = {os.pullEvent()}
	
	-- Run any callbacks
	callback.pullEvent(e)
end

