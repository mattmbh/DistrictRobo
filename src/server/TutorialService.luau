local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local TutorialService = {}

local tutorialRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.TutorialAction)

local STEP_TEXT = {
	[1] = "Destroy a drone",
	[2] = "Collect scrap",
	[3] = "Upgrade a fighter",
	[4] = "Make a prediction",
}

local LAST_STEP = 4

local function applyStepState(player: Player, step: number, active: boolean, completed: boolean)
	player:SetAttribute("TutorialActive", active)
	player:SetAttribute("TutorialCompleted", completed)
	player:SetAttribute("TutorialStep", step)
	player:SetAttribute("TutorialStepCount", LAST_STEP)
	player:SetAttribute("TutorialStepText", STEP_TEXT[step] or "")
end

function TutorialService.InitializePlayer(player: Player)
	if player:GetAttribute("TutorialCompleted") == true then
		applyStepState(player, LAST_STEP, false, true)
		return
	end

	applyStepState(player, 1, true, false)
end

function TutorialService.Advance(player: Player, expectedStep: number)
	if player:GetAttribute("TutorialActive") ~= true then
		return
	end

	local currentStep = tonumber(player:GetAttribute("TutorialStep") or 1) or 1
	if currentStep ~= expectedStep then
		return
	end

	if currentStep >= LAST_STEP then
		applyStepState(player, LAST_STEP, false, true)
		return
	end

	applyStepState(player, currentStep + 1, true, false)
end

function TutorialService.MarkDroneDestroyed(player: Player)
	TutorialService.Advance(player, 1)
end

function TutorialService.MarkMaterialCollected(player: Player)
	TutorialService.Advance(player, 2)
end

function TutorialService.MarkFighterUpgrade(player: Player)
	TutorialService.Advance(player, 3)
end

function TutorialService.MarkPredictionMade(player: Player)
	TutorialService.Advance(player, 4)
end

function TutorialService.Skip(player: Player)
	applyStepState(player, LAST_STEP, false, true)
end

tutorialRemote.OnServerEvent:Connect(function(player: Player, actionName: string)
	if typeof(actionName) ~= "string" then
		return
	end

	if actionName == "Skip" then
		TutorialService.Skip(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	TutorialService.InitializePlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	TutorialService.InitializePlayer(player)
end

return TutorialService
