local api, device = ...

local state = api.getState()

local lastStatus = nil

function device:run()
	local success, action = device:remoteExecute(function (buttons, rednetInfo)
		while true do
			if #buttons > 2 then error("Max of 2 buttons per button panel.") end
			
			local buttonNames = {
				purge = "Purge",
				emergency = "Emergency"
			}
			
			local clickedButton = nil
			
			local buttonColours = {
				purge = colours.red,
				emergency = colours.orange
			}
			
			local function getButtonColour(buttonId)
				if clickedButton == buttonId then return colours.green end
				return buttonColours[buttons[buttonId]]
			end
			
			
			local buttonRegions = {}
		
			local mon = peripheral.wrap("top")
			mon.setTextScale(1)
			local width, height = mon.getSize()
			if width <= 7 then
				mon.setTextScale(0.5)
				width, height = mon.getSize()
			end
			
			--[[
				Render buttons.
			]]
			local function render()
				local oldTerm = term.redirect(mon)
				term.setBackgroundColour(colours.black)
				term.clear()
				term.setCursorPos(1,1)
				
				buttonRegions[1] = {
					x1 = 1, y1 = 1,
					x2 = width,
					y2 = math.floor(height / 2)
				}
				buttonRegions[2] = {
					x1 = 1,
					y1 = math.floor(height / 2) + 2,
					x2 = width, y2 = height
				}
				
				paintutils.drawFilledBox(buttonRegions[1].x1, buttonRegions[1].y1, buttonRegions[1].x2, buttonRegions[1].y2, getButtonColour(1))
				paintutils.drawFilledBox(buttonRegions[2].x1, buttonRegions[2].y1, buttonRegions[2].x2, buttonRegions[2].y2, getButtonColour(2))
				
				term.setTextColour(colours.white)
				
				local x, y, btnText
				
				-- Draw text for button 1
				btnText = buttonNames[buttons[1]]
				x = math.floor(width / 2) - math.floor(#btnText / 2)
				y = math.floor( math.floor(height / 2) / 2 )
				term.setCursorPos(x, y)
				term.setBackgroundColour(getButtonColour(1))
				term.write(btnText)
				
				-- Draw text for button 2
				btnText = buttonNames[buttons[2]]
				x = math.floor(width / 2) - math.floor(#btnText / 2)
				y = math.floor(height / 2) + 1 + math.floor( math.floor(height / 2) / 2 )
				term.setCursorPos(x, y)
				term.setBackgroundColour(getButtonColour(2))
				term.write(btnText)
				
				term.redirect(oldTerm)
			end
			
			render()
			
			local e = {os.pullEvent()}
			
			if e[1] == "monitor_touch" then
				local x,y = e[3], e[4]
				
				for buttonId,region in ipairs(buttonRegions) do
					if x >= region.x1 and x <= region.x2 and y >= region.y1 and y <= region.y2 then
						-- Button clicked!
						clickedButton = buttonId
						render()
						sleep(0.3)
						clickedButton = nil
						render()
						
						
						return buttons[buttonId]
					end
				end
			end
		end
	end, device.config.buttons, {
		host = os.getComputerID(),
		channel = api.CHANNEL
	})
	
	return action
end

api.onReady(function ()
	
end)

api.onRun(function ()
	while true do
		local action = device:run()
		
		if action == "purge" then
			lastStatus = state.status
			api.getController().setStatus(4)
		elseif action == "emergency" then
			lastStatus = state.status
			api.getController().setStatus(3)
		end
	end
end)

return true
