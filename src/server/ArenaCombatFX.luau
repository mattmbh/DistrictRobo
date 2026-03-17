local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local ArenaCombatFX = {}

local function tweenAndCleanup(instance: Instance, tweenInfo: TweenInfo, goal: {[string]: any}, lifetime: number)
	local tween = TweenService:Create(instance, tweenInfo, goal)
	tween:Play()
	Debris:AddItem(instance, lifetime)
	return tween
end

function ArenaCombatFX.EmitHit(targetRoot: BasePart, damage: number)
	local flash = Instance.new("Part")
	flash.Name = "ArenaHitFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 220, 130)
	flash.Transparency = 0.08
	flash.Size = Vector3.new(1.2, 1.2, 1.2)
	flash.CFrame = targetRoot.CFrame + Vector3.new(0, 2.6, 0)
	flash.Parent = workspace
	tweenAndCleanup(flash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(3.8, 3.8, 3.8),
	}, 0.25)

	local spark = Instance.new("Part")
	spark.Name = "ArenaHitSpark"
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanTouch = false
	spark.CanQuery = false
	spark.Material = Enum.Material.Neon
	spark.Color = Color3.fromRGB(255, 170, 90)
	spark.Transparency = 0.05
	spark.Size = Vector3.new(0.5, 0.5, 2.5)
	spark.CFrame = targetRoot.CFrame * CFrame.new(0, 2.5, 0)
	spark.Parent = workspace
	tweenAndCleanup(spark, TweenInfo.new(0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 4.8),
	}, 0.18)

	local damageBillboard = Instance.new("BillboardGui")
	damageBillboard.Name = "ArenaDamageBillboard"
	damageBillboard.Size = UDim2.fromOffset(96, 40)
	damageBillboard.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	damageBillboard.AlwaysOnTop = true
	damageBillboard.Parent = targetRoot

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.TextColor3 = Color3.fromRGB(255, 228, 138)
	label.Text = ("-%d"):format(damage)
	label.Parent = damageBillboard

	local rise = TweenService:Create(damageBillboard, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 7.6, 0),
	})
	local fade = TweenService:Create(label, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	rise:Play()
	fade:Play()
	Debris:AddItem(damageBillboard, 0.5)

	local hitSound = Instance.new("Sound")
	hitSound.Name = "ArenaHitSound"
	hitSound.SoundId = "rbxasset://sounds/impact_water.mp3"
	hitSound.Volume = 0.18
	hitSound.PlaybackSpeed = 1.3
	hitSound.RollOffMaxDistance = 80
	hitSound.Parent = targetRoot
	hitSound:Play()
	Debris:AddItem(hitSound, 2)
end

return ArenaCombatFX
