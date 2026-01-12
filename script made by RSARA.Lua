-- LocalScript: combined-boombox-with-notifications.lua
-- Letakkan di StarterPlayerScripts

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local lp = Players.LocalPlayer

local BLUE_NAME = "BoomboxBlue"
local RED_NAME = "BoomboxRed"

-- nilai standar modifier (Script 1)
local NEW_TOOL_TEXTURE = "rbxassetid://7014074704"
local NEW_MESH_TEXTURE = "rbxassetid://5436595547"
local NEW_TOOLTIP = "Don't play loud audios on this."

-- nilai khusus untuk clone (permintaanmu)
local CLONE_TOOL_TEXTURE = "rbxassetid://7014074448"
local CLONE_MESH_TEXTURE = "rbxassetid://281722334"

---------------------------------------------------
-- Notification UI helper
---------------------------------------------------
local notified = {
	redMissing = false,
	blueMissing = false,
	success = false,
}

local NOTIF_DISPLAY_TIME = 2.2
local NOTIF_TWEEN_TIME = 0.35

-- versi counter untuk menghindari notifikasi lama menghancurkan notifikasi baru
local notifCounter = 0

local function createNotifierGui()
	local pg = lp:FindFirstChildOfClass("PlayerGui")
	if not pg then
		warn("PlayerGui belum siap")
		return nil
	end
	local existing = pg:FindFirstChild("BoomboxNotifier")
	if existing then return existing end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BoomboxNotifier"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = pg

	-- container frame (center top)
	local frame = Instance.new("Frame")
	frame.Name = "NotifFrame"
	frame.Size = UDim2.new(0.5, 0, 0, 60)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, -0.1, 0) -- start off-screen (above)
	frame.BackgroundTransparency = 0
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	frame.ClipsDescendants = true
	frame.Visible = true
	frame.LayoutOrder = 1
	frame.Rotation = 0
	frame.ZIndex = 10

	-- round corners
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 10)
	uiCorner.Parent = frame

	-- shadow (simple)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 6, 1, 6)
	shadow.Position = UDim2.new(0, -3, 0, -3)
	shadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = frame
	local sCorner = Instance.new("UICorner", shadow)
	sCorner.CornerRadius = UDim.new(0, 12)

	-- icon label (left)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 48, 1, 0)
	icon.Position = UDim2.new(0, 6, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "✓"
	icon.Font = Enum.Font.SourceSansBold
	icon.TextSize = 30
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.TextYAlignment = Enum.TextYAlignment.Center
	icon.ZIndex = 11
	icon.Parent = frame

	-- message label
	local msg = Instance.new("TextLabel")
	msg.Name = "Message"
	msg.Size = UDim2.new(1, -70, 1, 0)
	msg.Position = UDim2.new(0, 60, 0, 0)
	msg.BackgroundTransparency = 1
	msg.Text = "Notification"
	msg.Font = Enum.Font.SourceSansSemibold
	msg.TextSize = 20
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextYAlignment = Enum.TextYAlignment.Center
	msg.TextColor3 = Color3.fromRGB(230, 230, 230)
	msg.RichText = false
	msg.ZIndex = 11
	msg.Parent = frame

	return screenGui
end

local function showNotification(text, success)
	local gui = createNotifierGui()
	if not gui then return end
	local frame = gui:FindFirstChild("NotifFrame")
	if not frame then return end
	local icon = frame:FindFirstChild("Icon")
	local msg = frame:FindFirstChild("Message")

	-- increment counter (menandai notifikasi terkini)
	notifCounter = notifCounter + 1
	local myId = notifCounter

	-- set text & colors
	msg.Text = text
	if success then
		frame.BackgroundColor3 = Color3.fromRGB(24, 124, 46) -- green
		icon.Text = "✓"
		icon.TextColor3 = Color3.fromRGB(230, 230, 230)
		msg.TextColor3 = Color3.fromRGB(240, 248, 240)
	else
		frame.BackgroundColor3 = Color3.fromRGB(160, 40, 40) -- red
		icon.Text = "✖"
		icon.TextColor3 = Color3.fromRGB(255, 255, 255)
		msg.TextColor3 = Color3.fromRGB(255, 240, 240)
	end

	-- ensure starting position off-screen (in case reusing)
	frame.Position = UDim2.new(0.5, 0, -0.1, 0)

	-- tween in (slide down)
	local tweenIn = TweenService:Create(frame, TweenInfo.new(NOTIF_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.05, 0), Rotation = 0})
	tweenIn:Play()

	-- schedule hide only if this is still the latest notification
	task.delay(NOTIF_DISPLAY_TIME, function()
		if myId ~= notifCounter then
			-- ada notifikasi baru setelah ini, skip hide untuk mencegah race
			return
		end
		-- tween out (slide up)
		local tweenOut = TweenService:Create(frame, TweenInfo.new(NOTIF_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, -0.1, 0)})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			-- pastikan masih GUI yang sama dan id masih cocok lalu destroy GUI agar benar-benar hilang
			if myId == notifCounter and gui and gui.Parent then
				gui:Destroy()
			end
		end)
	end)
end

---------------------------------------------------
-- UTIL for tools & processing flag
---------------------------------------------------
local function findToolOnPlayer(player, toolName)
	local bp = player:FindFirstChild("Backpack")
	if bp and bp:FindFirstChild(toolName) then
		return bp:FindFirstChild(toolName)
	end
	if player.Character and player.Character:FindFirstChild(toolName) then
		return player.Character:FindFirstChild(toolName)
	end
	return nil
end

local function isProcessed(tool)
	return tool and tool:FindFirstChild("__BoomboxModified") ~= nil
end

local function markProcessed(tool)
	if not tool then return end
	if isProcessed(tool) then return end
	local tag = Instance.new("BoolValue")
	tag.Name = "__BoomboxModified"
	tag.Value = true
	tag.Parent = tool
end

---------------------------------------------------
-- SCRIPT 1 : MODIFY BOOMBOX (LANGSUNG JALAN)
---------------------------------------------------
local function modifyBoombox(tool)
	if not tool or isProcessed(tool) then return end

	-- Tool texture
	pcall(function()
		if tool.TextureId ~= nil then
			tool.TextureId = NEW_TOOL_TEXTURE
		end
	end)
	for _, c in ipairs(tool:GetChildren()) do
		if c:IsA("Decal") or c:IsA("Texture") then
			pcall(function() c.Texture = NEW_TOOL_TEXTURE end)
			pcall(function() c.TextureId = NEW_TOOL_TEXTURE end)
		end
	end

	-- Tooltip
	pcall(function()
		if tool.ToolTip ~= nil then
			tool.ToolTip = NEW_TOOLTIP
		end
	end)

	-- Handle texture
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
	if handle then
		pcall(function()
			if handle.TextureID ~= nil then
				handle.TextureID = NEW_MESH_TEXTURE
			end
		end)

		local mesh = handle:FindFirstChildWhichIsA("SpecialMesh") or handle:FindFirstChildWhichIsA("Mesh")
		if mesh then
			pcall(function()
				if mesh.TextureId ~= nil then
					mesh.TextureId = NEW_MESH_TEXTURE
				elseif mesh.Texture ~= nil then
					mesh.Texture = NEW_MESH_TEXTURE
				end
			end)
		end

		for _, c in ipairs(handle:GetChildren()) do
			if c:IsA("Decal") or c:IsA("Texture") then
				pcall(function() c.Texture = NEW_MESH_TEXTURE end)
				pcall(function() c.TextureId = NEW_MESH_TEXTURE end)
			end
		end
	end

	-- Hapus Client lama
	local oldClient = tool:FindFirstChild("Client")
	if oldClient then
		oldClient:Destroy()
	end

	-- Clone Client dari BoomboxRed player lain (jika tersedia)
	local foundRedClient = false
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= lp then
			local red = findToolOnPlayer(pl, RED_NAME)
			if red and red:FindFirstChild("Client") then
				local ok, cloned = pcall(function() return red.Client:Clone() end)
				if ok and cloned then
					cloned.Parent = tool
					foundRedClient = true
				end
				break
			end
		end
	end

	if not foundRedClient and not notified.redMissing then
		notified.redMissing = true
		showNotification("Failed! The player who has the red boombox is not there.", false)
	end

	markProcessed(tool)
end

-- Monitor Backpack & Character untuk tool baru
local function watchContainer(container)
	if not container then return end
	container.ChildAdded:Connect(function(child)
		if child and child:IsA("Tool") and child.Name == BLUE_NAME and not isProcessed(child) then
			task.defer(function()
				pcall(function() modifyBoombox(child) end)
			end)
		end
	end)
end

watchContainer(lp:WaitForChild("Backpack"))
if lp.Character then watchContainer(lp.Character) end
lp.CharacterAdded:Connect(function(c) watchContainer(c) end)

-- lakukan pengecekan awal: modifikasi tool yang sudah ada sekarang
do
	local bp = lp:FindFirstChild("Backpack")
	if bp then
		local t = bp:FindFirstChild(BLUE_NAME)
		if t and t:IsA("Tool") and not isProcessed(t) then
			pcall(function() modifyBoombox(t) end)
		end
	end
	if lp.Character then
		local t2 = lp.Character:FindFirstChild(BLUE_NAME)
		if t2 and t2:IsA("Tool") and not isProcessed(t2) then
			pcall(function() modifyBoombox(t2) end)
		end
	end
end

---------------------------------------------------
-- SCRIPT 2 : CLONE BOOMBOX (JALAN LANGSUNG) + ubah texture clone
---------------------------------------------------
task.spawn(function()
	-- kumpulkan pemain lain
	local otherPlayers = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= lp then
			table.insert(otherPlayers, pl)
		end
	end
	if #otherPlayers == 0 then
		-- Tidak ada pemain lain => anggap blue tidak ada
		if not notified.blueMissing then
			notified.blueMissing = true
			showNotification("Failed! The player who has the blue boombox is not there.", false)
		end
		return
	end

	-- pilih target acak (jika target tidak punya tool, coba pemain lain)
	local target = otherPlayers[math.random(#otherPlayers)]
	local function findBlueForPlayer(pl)
		return (pl:FindFirstChild("Backpack") and pl.Backpack:FindFirstChild(BLUE_NAME))
			or (pl.Character and pl.Character:FindFirstChild(BLUE_NAME))
	end

	local tool = findBlueForPlayer(target)
	if not tool then
		for _, pl in ipairs(otherPlayers) do
			if pl ~= target then
				local t = findBlueForPlayer(pl)
				if t then
					tool = t
					break
				end
			end
		end
	end

	if not tool or not tool:IsA("Tool") then
		-- tidak ditemukan BoomboxBlue pada pemain lain
		if not notified.blueMissing then
			notified.blueMissing = true
			showNotification("Failed! The player who has the blue boombox is not there.", false)
		end
		return
	end

	-- Clone
	tool.Archivable = true
	local ok, clone = pcall(function() return tool:Clone() end)
	if not ok or not clone then
		if not notified.blueMissing then
			notified.blueMissing = true
			showNotification("Failed! The player who has the blue boombox is not there.", false)
		end
		return
	end

	-- == Ubah texture pada clone sesuai permintaan sebelum preload/parent ==
	pcall(function()
		if clone.TextureId ~= nil then
			clone.TextureId = CLONE_TOOL_TEXTURE
		end
	end)
	for _, c in ipairs(clone:GetChildren()) do
		if c:IsA("Decal") or c:IsA("Texture") then
			pcall(function() c.Texture = CLONE_TOOL_TEXTURE end)
			pcall(function() c.TextureId = CLONE_TOOL_TEXTURE end)
		end
	end

	-- ubah Handle / mesh pada clone
	local handle = clone:FindFirstChild("Handle") or clone:FindFirstChildWhichIsA("BasePart")
	if handle then
		pcall(function()
			if handle.TextureID ~= nil then
				handle.TextureID = CLONE_MESH_TEXTURE
			end
		end)

		local mesh = handle:FindFirstChildWhichIsA("SpecialMesh") or handle:FindFirstChildWhichIsA("Mesh")
		if mesh then
			pcall(function()
				if mesh.TextureId ~= nil then
					mesh.TextureId = CLONE_MESH_TEXTURE
				elseif mesh.Texture ~= nil then
					mesh.Texture = CLONE_MESH_TEXTURE
				end
			end)
		end

		for _, c in ipairs(handle:GetChildren()) do
			if c:IsA("Decal") or c:IsA("Texture") then
				pcall(function() c.Texture = CLONE_MESH_TEXTURE end)
				pcall(function() c.TextureId = CLONE_MESH_TEXTURE end)
			end
		end
	end

	-- Tandai clone sebagai sudah diproses agar modifier tidak menimpanya
	markProcessed(clone)

	-- Preload visuals (untuk memastikan tampilan)
	if handle then
		pcall(function()
			ContentProvider:PreloadAsync(handle:GetDescendants())
		end)
	end

	-- Parent ke Backpack local player
	local bp = lp:WaitForChild("Backpack")
	clone.Parent = bp

	-- Sukses => notifikasi sekali
	if not notified.success then
		notified.success = true
		showNotification("Successfully executed", true)
	end
end)

---------------------------------------------------
-- AUTO-REJOIN ON DEATH (when character reset)
---------------------------------------------------
local function setupRejoinOnDeath(character)
	-- cari Humanoid (atau tunggu sebentar)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			-- teleport kembali ke place (rejoin)
			pcall(function()
				TeleportService:Teleport(game.PlaceId)
			end)
		end)
	end
end

if lp.Character then
	setupRejoinOnDeath(lp.Character)
end
lp.CharacterAdded:Connect(setupRejoinOnDeath)

-- end of script