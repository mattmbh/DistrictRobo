local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Net.GetRemotesFolder(): Folder
	return ensureFolder(ReplicatedStorage, "Remotes")
end

function Net.GetOrCreateRemoteEvent(remoteName: string): RemoteEvent
	local remotesFolder = Net.GetRemotesFolder()
	local existing = remotesFolder:FindFirstChild(remoteName)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = remoteName
	remote.Parent = remotesFolder
	return remote
end

function Net.GetRemoteEvent(remoteName: string): RemoteEvent
	local remotesFolder = Net.GetRemotesFolder()
	return remotesFolder:WaitForChild(remoteName) :: RemoteEvent
end

return Net
