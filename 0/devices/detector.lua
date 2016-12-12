local api, device = ...

api.onReady(function ()
	device.events.onTriggered = function (trigger)
		--print("trigger: " .. tostring(trigger))
	end
end)

api.onRun(function ()
	while true do
		-- Get pressure plate status.
		local success, triggered = device:remoteExecute(function ()
			os.pullEvent("redstone")
			return rs.getInput("top")
		end)
		
		-- Raise event
		device:raise("onTriggered", triggered)
	end
end)


-- Device successfully initialised.
return true
