local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local TOGGLE_ACTION = "ToggleCityMapFallback"

local function onToggleMapAction(_actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
	if _G.__CityMapLoaded then
		return Enum.ContextActionResult.Pass
	end
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if not inputObject or inputObject.KeyCode ~= Enum.KeyCode.M then
		return Enum.ContextActionResult.Pass
	end

	print("[CityMapFallback] M pressed")
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local cityMapGui = playerGui and playerGui:FindFirstChild("CityMapUI")
	if cityMapGui and cityMapGui:IsA("ScreenGui") then
		cityMapGui.Enabled = not cityMapGui.Enabled
		print(("[CityMapFallback] Toggled CityMapUI -> %s"):format(tostring(cityMapGui.Enabled)))
		return Enum.ContextActionResult.Sink
	end

	warn("[CityMapFallback] CityMapUI not found under PlayerGui")
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(TOGGLE_ACTION, onToggleMapAction, false, Enum.KeyCode.M)
