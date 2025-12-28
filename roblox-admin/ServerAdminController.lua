--!strict
-- ServerScript for wiring commands, AI integration, and RemoteEvents.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local AdminCommands = require(ReplicatedStorage:WaitForChild("AdminPanel"):WaitForChild("AdminCommands"))
local AIConfig = require(ReplicatedStorage:WaitForChild("AdminPanel"):WaitForChild("AIConfig"))

-- Update with your own Roblox user IDs.
local ADMIN_USER_IDS = {
    123456, -- example; replace with your account id
}

local requestEvent = ReplicatedStorage:FindFirstChild("AdminCommandRequest") or Instance.new("RemoteEvent")
requestEvent.Name = "AdminCommandRequest"
requestEvent.Parent = ReplicatedStorage

local resultEvent = ReplicatedStorage:FindFirstChild("AdminCommandResult") or Instance.new("RemoteEvent")
resultEvent.Name = "AdminCommandResult"
resultEvent.Parent = ReplicatedStorage

local aiFunction = ReplicatedStorage:FindFirstChild("AdminAISuggest") or Instance.new("RemoteFunction")
aiFunction.Name = "AdminAISuggest"
aiFunction.Parent = ReplicatedStorage

local function isAdmin(player: Player)
    for _, id in ipairs(ADMIN_USER_IDS) do
        if player.UserId == id then
            return true
        end
    end
    return false
end

local function findPlayers(selector: string?, sender: Player): { Player }
    if not selector or selector == "me" then
        return { sender }
    end

    selector = string.lower(selector)
    if selector == "all" then
        return Players:GetPlayers()
    elseif selector == "others" then
        local targets = {}
        for _, plr in Players:GetPlayers() do
            if plr ~= sender then table.insert(targets, plr) end
        end
        return targets
    elseif selector == "random" then
        local plist = Players:GetPlayers()
        if #plist == 0 then return {} end
        return { plist[math.random(1, #plist)] }
    elseif selector:match("team:") then
        local teamName = selector:split(":")[2]
        local matches = {}
        for _, plr in Players:GetPlayers() do
            if plr.Team and string.lower(plr.Team.Name) == teamName then
                table.insert(matches, plr)
            end
        end
        return matches
    else
        local matches = {}
        for _, plr in Players:GetPlayers() do
            if string.find(string.lower(plr.Name), selector, 1, true)
                or string.find(string.lower(plr.DisplayName), selector, 1, true) then
                table.insert(matches, plr)
            end
        end
        return matches
    end
end

local function broadcastResult(message: string)
    resultEvent:FireAllClients(message)
end

local function sendSystemMessage(player: Player, message: string)
    resultEvent:FireClient(player, message)
end

local function executeCommand(sender: Player, name: string, args: { string })
    if not isAdmin(sender) then
        sendSystemMessage(sender, "You are not whitelisted to run admin commands.")
        return
    end

    if AdminCommands.isBanned(sender.UserId) then
        sender:Kick("You are banned from this server.")
        return
    end

    local command = AdminCommands.get(name)
    if not command then
        sendSystemMessage(sender, "Unknown command: " .. name)
        return
    end

    local ctx = {
        sender = sender,
        findPlayers = function(selector: string?)
            return findPlayers(selector, sender)
        end,
        sendSystemMessage = function(msg: string)
            sendSystemMessage(sender, msg)
        end,
        broadcastResult = broadcastResult,
    }

    task.spawn(function()
        command.run(ctx, args)
    end)
end

requestEvent.OnServerEvent:Connect(function(player, payload)
    if type(payload) ~= "table" then return end
    local name = payload.name
    local args = payload.args or {}
    if type(name) ~= "string" or type(args) ~= "table" then return end
    executeCommand(player, name, args)
end)

local function fetchAISuggestion(prompt: string): string
    if AIConfig.ApiKey == "REPLACE_WITH_YOUR_KEY" or AIConfig.ApiKey == "" then
        return "Set your AI API key in AIConfig.lua first."
    end

    local requestBody = HttpService:JSONEncode({
        model = AIConfig.Model,
        messages = {
            { role = "system", content = "You are a Roblox admin assistant. Provide concise command suggestions." },
            { role = "user", content = prompt },
        },
        max_tokens = 60,
    })

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. AIConfig.ApiKey,
    }

    local success, response = pcall(function()
        return HttpService:PostAsync(AIConfig.Endpoint, requestBody, Enum.HttpContentType.ApplicationJson, false, headers)
    end)

    if not success then
        return "AI request failed: " .. tostring(response)
    end

    local decoded = HttpService:JSONDecode(response)
    local choice = decoded.choices and decoded.choices[1]
    local content = choice and choice.message and choice.message.content
    if AIConfig.Debug then
        print("[AI] Response", content)
    end
    return content or "No suggestion available."
end

aiFunction.OnServerInvoke = function(player, prompt)
    if not isAdmin(player) then
        return "Not authorized"
    end
    if type(prompt) ~= "string" then
        return "Invalid prompt"
    end
    return fetchAISuggestion(prompt)
end

Players.PlayerAdded:Connect(function(player)
    if AdminCommands.isBanned(player.UserId) then
        player:Kick("You are banned from this session.")
        return
    end
end)
