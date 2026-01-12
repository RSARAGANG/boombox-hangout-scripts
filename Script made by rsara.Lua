--[[
HOW TO USE THIS SCRIPT:

1. Join the **Boombox Hangout** game
2. Make sure there is AT LEAST ONE player with a **Red Boombox**
3. The player with the Red Boombox MUST NOT be using or holding it
4. If they are still holding it:
   - Throw the boombox at them
   - Or wait until they stop using it
5. After all requirements are met, execute this script
6. The script will run automatically (no extra settings needed)

NOTES:
- This script will not work if no Red Boombox exists in the server
- The script may fail if the Red Boombox is currently being used
- Rejoin the server and try again if it does not work
]]

task.spawn(function()
    loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/RSARAGANG/boombox-hangout-scripts/refs/heads/main/script%20made%20by%20rsara.Lua",
        true
    ))()
end)

task.wait(2)

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function setBoomboxUndroppable()
    local backpack = player:WaitForChild("Backpack")
    local boombox = backpack:FindFirstChild("BoomboxBlue")

    if boombox and boombox:IsA("Tool") then
        boombox.CanBeDropped = false
    end
end

setBoomboxUndroppable()

player.Backpack.ChildAdded:Connect(function(child)
    if child.Name == "BoomboxBlue" and child:IsA("Tool") then
        child.CanBeDropped = false
    end
end)