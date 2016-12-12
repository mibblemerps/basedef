--[[
	Base Defend System.
	Device - Detector.
	
	By Mitchfizz05. Licensed under the terms of the MIT license (http://opensource.org/licenses/MIT).
]]

-- Load API
os.unloadAPI("basedef")
os.loadAPI("basedef")

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


-- Init
if not openRednet() then
	print("Warning! No RedNet modems attached! Communication unavailable.")
end

local device = basedef.Device.new("basedefend", "thelab")

-- Print display
term.clear()
term.setCursorPos(1,1)
print("Base Defence Device.\n")
print("  Device ID: " .. os.getComputerID())
print("  Channel: " .. device.channel)
print("  Network Name: " .. device.networkName)


-- Remote execute callback
local remoteExecuteCallbackFunc = nil
local remoteExecuteCallbackArgs = nil
local remoteExecuteFinishedCallback = nil
device.remoteExecuteCallback = function (func, args, callback)
	remoteExecuteCallbackFunc = func
	remoteExecuteCallbackArgs = args
	remoteExecuteFinishedCallback = callback
	os.queueEvent("remote_execute")
end


-- Run coroutines.
local e = {}
while true do
	parallel.waitForAny(function ()
		while true do device:runRednet() end
	end,
	function ()
		while true do
			os.pullEvent("remote_execute")
			
			-- Execute remote execute code
			local success, result = pcall(function ()
				return remoteExecuteCallbackFunc(unpack(remoteExecuteCallbackArgs))
			end)
			remoteExecuteFinishedCallback(success, result)
		end
	end)
end

