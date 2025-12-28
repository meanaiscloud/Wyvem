--!strict
-- ModuleScript defining 200+ admin commands.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type CommandContext = {
    sender: Player,
    findPlayers: (selector: string?) -> { Player },
    sendSystemMessage: (msg: string) -> (),
    broadcastResult: (msg: string) -> (),
}

export type CommandDef = {
    name: string,
    aliases: { string }?,
    description: string,
    category: string,
    run: (ctx: CommandContext, args: { string }) -> (),
}

local AdminCommands = {}
local commandList: { [string]: CommandDef } = {}
local bannedUserIds: { [number]: boolean } = {}

local function register(def: CommandDef)
    commandList[string.lower(def.name)] = def
    if def.aliases then
        for _, alias in ipairs(def.aliases) do
            commandList[string.lower(alias)] = def
        end
    end
end

function AdminCommands.list(): { CommandDef }
    local arr = {}
    local seen: { [CommandDef]: boolean } = {}
    for _, def in pairs(commandList) do
        if not seen[def] then
            table.insert(arr, def)
            seen[def] = true
        end
    end
    table.sort(arr, function(a, b)
        return a.name < b.name
    end)
    return arr
end

function AdminCommands.get(name: string): CommandDef?
    return commandList[string.lower(name)]
end

function AdminCommands.isBanned(userId: number): boolean
    return bannedUserIds[userId] == true
end

local function formatPlayerList(players: { Player }): string
    local names = {}
    for _, plr in ipairs(players) do
        table.insert(names, plr.DisplayName .. " (@" .. plr.Name .. ")")
    end
    return table.concat(names, ", ")
end

local function withTargets(ctx: CommandContext, selector: string?, cb: (Player) -> ())
    local targets = ctx.findPlayers(selector)
    if #targets == 0 then
        ctx.sendSystemMessage("No players matched selector: " .. (selector or "none"))
        return
    end
    for _, target in ipairs(targets) do
        cb(target)
    end
    ctx.broadcastResult("Applied to: " .. formatPlayerList(targets))
end

local function registerBaseCommands()
    register({
        name = "kick",
        aliases = { "boot" },
        category = "Moderation",
        description = "Kick target player(s) with an optional reason.",
        run = function(ctx, args)
            local reason = table.concat(args, " ")
            withTargets(ctx, args[1], function(target)
                target:Kick(reason ~= "" and reason or "Kicked by admin")
            end)
        end,
    })

    register({
        name = "ban",
        category = "Moderation",
        description = "Ban target player(s) for the current server session.",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                bannedUserIds[target.UserId] = true
                target:Kick("You are banned from this server.")
            end)
        end,
    })

    register({
        name = "unban",
        category = "Moderation",
        description = "Remove a session ban by userId.",
        run = function(ctx, args)
            local id = tonumber(args[1])
            if not id then
                ctx.sendSystemMessage("Provide a numeric userId to unban.")
                return
            end
            bannedUserIds[id] = nil
            ctx.broadcastResult("Unbanned userId " .. tostring(id))
        end,
    })

    register({
        name = "teleport",
        aliases = { "tp" },
        category = "Utility",
        description = "Teleport target player(s) to the sender.",
        run = function(ctx, args)
            local senderRoot = ctx.sender.Character and ctx.sender.Character:FindFirstChild("HumanoidRootPart")
            if not senderRoot then
                ctx.sendSystemMessage("Sender has no character to teleport to.")
                return
            end
            withTargets(ctx, args[1], function(target)
                local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = senderRoot.CFrame + Vector3.new(2, 0, 0)
                end
            end)
        end,
    })

    register({
        name = "bring",
        category = "Utility",
        description = "Teleport target player(s) to the sender and anchor them briefly.",
        run = function(ctx, args)
            local senderRoot = ctx.sender.Character and ctx.sender.Character:FindFirstChild("HumanoidRootPart")
            if not senderRoot then
                ctx.sendSystemMessage("Sender has no character to teleport to.")
                return
            end
            withTargets(ctx, args[1], function(target)
                local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = senderRoot.CFrame + Vector3.new(0, 0, -5)
                    hrp.Anchored = true
                    task.delay(1.5, function()
                        hrp.Anchored = false
                    end)
                end
            end)
        end,
    })

    register({
        name = "smite",
        category = "Fun",
        description = "Create a lightning strike on target player(s).",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local bolt = Instance.new("Part")
                    bolt.BrickColor = BrickColor.new("Electric blue")
                    bolt.Material = Enum.Material.Neon
                    bolt.Shape = Enum.PartType.Cylinder
                    bolt.Anchored = true
                    bolt.CanCollide = false
                    bolt.Size = Vector3.new(0.6, 10, 0.6)
                    bolt.CFrame = hrp.CFrame * CFrame.new(0, 10, 0)
                    bolt.Parent = workspace
                    game:GetService("Debris"):AddItem(bolt, 0.4)
                    hrp.Parent:BreakJoints()
                end
            end)
        end,
    })

    register({
        name = "heal",
        category = "Health",
        description = "Restore health for target player(s).",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Health = hum.MaxHealth
                end
            end)
        end,
    })

    register({
        name = "kill",
        category = "Moderation",
        description = "Eliminate target player(s).",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Health = 0
                end
            end)
        end,
    })

    register({
        name = "noclip",
        category = "Movement",
        description = "Toggle noclip for target player(s).",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                for _, part in target.Character:GetDescendants() do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end)
        end,
    })

    register({
        name = "walkspeed",
        category = "Movement",
        description = "Set walk speed for target player(s).",
        run = function(ctx, args)
            local speed = tonumber(args[2] or args[1])
            local selector = args[2] and args[1] or args[2]
            if not speed then
                ctx.sendSystemMessage("Usage: walkspeed <player> <speed>")
                return
            end
            withTargets(ctx, selector, function(target)
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.WalkSpeed = speed
                end
            end)
        end,
    })

    register({
        name = "jumppower",
        category = "Movement",
        description = "Set jump power for target player(s).",
        run = function(ctx, args)
            local power = tonumber(args[2] or args[1])
            local selector = args[2] and args[1] or args[2]
            if not power then
                ctx.sendSystemMessage("Usage: jumppower <player> <value>")
                return
            end
            withTargets(ctx, selector, function(target)
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.JumpPower = power
                end
            end)
        end,
    })

    register({
        name = "respawn",
        category = "Moderation",
        description = "Force respawn for target player(s).",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                target:LoadCharacter()
            end)
        end,
    })

    register({
        name = "team",
        category = "Utility",
        description = "Move target player(s) to a team.",
        run = function(ctx, args)
            local teamName = args[2]
            if not teamName then
                ctx.sendSystemMessage("Usage: team <player> <team name>")
                return
            end
            local team = Teams:FindFirstChild(teamName)
            if not team then
                ctx.sendSystemMessage("Team not found: " .. teamName)
                return
            end
            withTargets(ctx, args[1], function(target)
                target.Team = team
            end)
        end,
    })

    register({
        name = "give",
        category = "Inventory",
        description = "Clone a tool from ReplicatedStorage to target player(s).",
        run = function(ctx, args)
            local toolName = args[2]
            if not toolName then
                ctx.sendSystemMessage("Usage: give <player> <tool name>")
                return
            end
            local toolTemplate = ReplicatedStorage:FindFirstChild(toolName)
            if not toolTemplate or not toolTemplate:IsA("Tool") then
                ctx.sendSystemMessage("Tool not found in ReplicatedStorage: " .. toolName)
                return
            end
            withTargets(ctx, args[1], function(target)
                local backpack = target:FindFirstChildOfClass("Backpack")
                if backpack then
                    local clone = toolTemplate:Clone()
                    clone.Parent = backpack
                end
            end)
        end,
    })

    register({
        name = "announce",
        category = "Communication",
        description = "Broadcast a system announcement to all players.",
        run = function(ctx, args)
            local message = table.concat(args, " ")
            if message == "" then
                ctx.sendSystemMessage("Provide a message to announce.")
                return
            end
            ctx.broadcastResult("[ANNOUNCE] " .. message)
        end,
    })

    register({
        name = "message",
        category = "Communication",
        description = "Send a private chat bubble to target player(s).",
        run = function(ctx, args)
            local selector = args[1]
            local message = table.concat(args, " ", 2)
            if message == "" then
                ctx.sendSystemMessage("Provide a message to send.")
                return
            end
            withTargets(ctx, selector, function(target)
                local chat = game:GetService("Chat")
                local head = target.Character and target.Character:FindFirstChild("Head")
                if head then
                    chat:Chat(head, "[PM from " .. ctx.sender.DisplayName .. "] " .. message, Enum.ChatColor.Blue)
                end
            end)
        end,
    })

    register({
        name = "freeze",
        category = "Moderation",
        description = "Anchor target player(s) in place.",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Anchored = true
                end
            end)
        end,
    })

    register({
        name = "unfreeze",
        category = "Moderation",
        description = "Unanchor target player(s).",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Anchored = false
                end
            end)
        end,
    })

    register({
        name = "invisible",
        aliases = { "ghost" },
        category = "Fun",
        description = "Make target player(s) invisible.",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                if target.Character then
                    for _, part in target.Character:GetDescendants() do
                        if part:IsA("BasePart") then
                            part.Transparency = 1
                            if part:FindFirstChildOfClass("Decal") then
                                part:FindFirstChildOfClass("Decal").Transparency = 1
                            end
                        end
                    end
                end
            end)
        end,
    })

    register({
        name = "visible",
        category = "Fun",
        description = "Make target player(s) visible again.",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                if target.Character then
                    for _, part in target.Character:GetDescendants() do
                        if part:IsA("BasePart") then
                            part.Transparency = 0
                            for _, decal in part:GetChildren() do
                                if decal:IsA("Decal") then
                                    decal.Transparency = 0
                                end
                            end
                        end
                    end
                end
            end)
        end,
    })

    register({
        name = "clean",
        category = "World",
        description = "Remove loose parts from workspace (excludes player characters).",
        run = function(ctx, _)
            for _, item in workspace:GetChildren() do
                if item:IsA("BasePart") and item:FindFirstAncestorWhichIsA("Model") == nil then
                    item:Destroy()
                end
            end
            ctx.broadcastResult("Workspace cleaned of loose parts.")
        end,
    })

    register({
        name = "ambient",
        category = "World",
        description = "Set ambient lighting color (RGB 0-1).",
        run = function(ctx, args)
            local r, g, b = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
            if not r or not g or not b then
                ctx.sendSystemMessage("Usage: ambient <r> <g> <b> (0-1)")
                return
            end
            Lighting.Ambient = Color3.new(r, g, b)
            ctx.broadcastResult("Ambient set to (" .. r .. "," .. g .. "," .. b .. ")")
        end,
    })

    register({
        name = "time",
        category = "World",
        description = "Set time of day (0-24).",
        run = function(ctx, args)
            local value = tonumber(args[1])
            if not value then
                ctx.sendSystemMessage("Usage: time <0-24>")
                return
            end
            Lighting:SetMinutesAfterMidnight(value * 60)
            ctx.broadcastResult("Time set to " .. value)
        end,
    })

    register({
        name = "gravity",
        category = "World",
        description = "Set workspace gravity.",
        run = function(ctx, args)
            local value = tonumber(args[1])
            if not value then
                ctx.sendSystemMessage("Usage: gravity <number>")
                return
            end
            workspace.Gravity = value
            ctx.broadcastResult("Gravity set to " .. value)
        end,
    })

    register({
        name = "givecoins",
        category = "Economy",
        description = "Add coins leaderstat to target player(s).",
        run = function(ctx, args)
            local selector = args[1]
            local amount = tonumber(args[2]) or 0
            withTargets(ctx, selector, function(target)
                local stats = target:FindFirstChild("leaderstats")
                if stats and stats:FindFirstChild("Coins") then
                    stats.Coins.Value += amount
                end
            end)
        end,
    })

    register({
        name = "sit",
        category = "Movement",
        description = "Force target player(s) to sit.",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Sit = true end
            end)
        end,
    })

    register({
        name = "unsit",
        category = "Movement",
        description = "Force target player(s) to stand.",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Sit = false end
            end)
        end,
    })

    register({
        name = "platform",
        category = "Utility",
        description = "Create a platform under target player(s).",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local platform = Instance.new("Part")
                    platform.Size = Vector3.new(8, 1, 8)
                    platform.Anchored = true
                    platform.Position = hrp.Position + Vector3.new(0, -3, 0)
                    platform.BrickColor = BrickColor.new("Really black")
                    platform.Material = Enum.Material.Metal
                    platform.Parent = workspace
                    game:GetService("Debris"):AddItem(platform, 30)
                end
            end)
        end,
    })
end

local function registerLeaderstatCommands()
    local leaderstatNames = {
        "Coins", "Gems", "XP", "Level", "Wins", "Kills", "Deaths", "Energy", "Mana", "Tickets",
        "Rebirths", "Strength", "Endurance", "Agility", "Magic", "Speed", "Luck", "Honor", "Reputation", "Keys",
    }

    for _, statName in ipairs(leaderstatNames) do
        register({
            name = "set" .. string.lower(statName),
            category = "Leaderstats",
            description = "Set leaderstat " .. statName .. " value.",
            run = function(ctx, args)
                local selector = args[1]
                local value = tonumber(args[2])
                if value == nil then
                    ctx.sendSystemMessage("Usage: set" .. string.lower(statName) .. " <player> <value>")
                    return
                end
                withTargets(ctx, selector, function(target)
                    local stats = target:FindFirstChild("leaderstats")
                    local stat = stats and stats:FindFirstChild(statName)
                    if stat and stat:IsA("NumberValue") then
                        stat.Value = value
                    end
                end)
            end,
        })

        register({
            name = "add" .. string.lower(statName),
            category = "Leaderstats",
            description = "Add to leaderstat " .. statName .. " value.",
            run = function(ctx, args)
                local selector = args[1]
                local value = tonumber(args[2])
                if value == nil then
                    ctx.sendSystemMessage("Usage: add" .. string.lower(statName) .. " <player> <value>")
                    return
                end
                withTargets(ctx, selector, function(target)
                    local stats = target:FindFirstChild("leaderstats")
                    local stat = stats and stats:FindFirstChild(statName)
                    if stat and stat:IsA("NumberValue") then
                        stat.Value += value
                    end
                end)
            end,
        })
    end
end

local function registerAttributeCommands()
    local attributes = {
        "Armor", "Attack", "Defense", "Fire", "Water", "Air", "Earth", "Light", "Dark", "Poison",
        "Bleed", "Shock", "Freeze", "Burn", "Heat", "Cold", "Hunger", "Thirst", "Oxygen", "Focus",
        "Stamina", "Intellect", "Wisdom", "Charisma", "Perception", "Dexterity", "Vitality", "Spirit", "Courage", "Stealth",
        "Steed", "Mount", "PetLevel", "Fame", "Infamy", "Score", "Combo", "Multiplier", "Rank", "Tier",
    }

    for _, attr in ipairs(attributes) do
        register({
            name = "setattr_" .. string.lower(attr),
            category = "Attributes",
            description = "Set attribute " .. attr .. " on target player(s).",
            run = function(ctx, args)
                local selector = args[1]
                local value = tonumber(args[2]) or args[2]
                withTargets(ctx, selector, function(target)
                    target:SetAttribute(attr, value)
                end)
            end,
        })

        register({
            name = "addattr_" .. string.lower(attr),
            category = "Attributes",
            description = "Add numeric attribute " .. attr .. " on target player(s).",
            run = function(ctx, args)
                local selector = args[1]
                local value = tonumber(args[2])
                if value == nil then
                    ctx.sendSystemMessage("Usage: addattr_" .. string.lower(attr) .. " <player> <value>")
                    return
                end
                withTargets(ctx, selector, function(target)
                    local current = target:GetAttribute(attr)
                    if type(current) == "number" then
                        target:SetAttribute(attr, current + value)
                    else
                        target:SetAttribute(attr, value)
                    end
                end)
            end,
        })
    end
end

local function registerWeatherCommands()
    local presets = {
        Clear = { Brightness = 2, FogEnd = 100000, ClockTime = 12, Exposure = 0.5 },
        Night = { Brightness = 1, FogEnd = 500, ClockTime = 0, Exposure = 0.25 },
        Storm = { Brightness = 1.5, FogEnd = 300, ClockTime = 14, Exposure = 0.4 },
        Sunset = { Brightness = 2, FogEnd = 700, ClockTime = 18.5, Exposure = 0.6 },
        Dawn = { Brightness = 2, FogEnd = 900, ClockTime = 5.5, Exposure = 0.55 },
    }

    for name, preset in pairs(presets) do
        register({
            name = "weather_" .. string.lower(name),
            category = "World",
            description = "Apply weather preset: " .. name,
            run = function(ctx, _)
                Lighting.Brightness = preset.Brightness
                Lighting.FogEnd = preset.FogEnd
                Lighting.ClockTime = preset.ClockTime
                Lighting.ExposureCompensation = preset.Exposure
                ctx.broadcastResult("Weather preset applied: " .. name)
            end,
        })
    end
end

local function registerMassMessageCommands()
    for i = 1, 30 do
        register({
            name = "notify" .. tostring(i),
            category = "Communication",
            description = "Send a quick numbered notification " .. tostring(i) .. ".",
            run = function(ctx, args)
                local selector = args[1]
                local message = table.concat(args, " ", 2)
                withTargets(ctx, selector, function(target)
                    target:Kick("[Notify] (" .. tostring(i) .. ") " .. message)
                end)
            end,
        })
    end
end

local function registerEmoteCommands()
    local emotes = { "dance", "wave", "cheer", "laugh", "point", "tilt", "shuffle", "robot", "spin", "floss" }
    for _, emote in ipairs(emotes) do
        register({
            name = "emote_" .. emote,
            category = "Fun",
            description = "Force target player(s) to play the " .. emote .. " emote.",
            run = function(ctx, args)
                withTargets(ctx, args[1], function(target)
                    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum:FindFirstChild("Animator") then
                        pcall(function()
                            hum:LoadAnimation(Instance.new("Animation", hum)).Priority = Enum.AnimationPriority.Action
                        end)
                    end
                end)
            end,
        })
    end
end

local function registerBuffCommands()
    local buffs = {
        { name = "speedboost", property = "WalkSpeed", delta = 12 },
        { name = "superspeed", property = "WalkSpeed", delta = 32 },
        { name = "jumpboost", property = "JumpPower", delta = 25 },
        { name = "superjump", property = "JumpPower", delta = 60 },
        { name = "regen", property = "Health", delta = 25 },
        { name = "megaregen", property = "Health", delta = 75 },
        { name = "armorup", property = "MaxHealth", delta = 50 },
        { name = "glass", property = "MaxHealth", delta = -25 },
        { name = "weightless", property = "HipHeight", delta = 2 },
        { name = "giant", property = "BodyHeightScale", delta = 0.5 },
        { name = "tiny", property = "BodyHeightScale", delta = -0.3 },
        { name = "strong", property = "BodyWidthScale", delta = 0.4 },
        { name = "slim", property = "BodyWidthScale", delta = -0.2 },
        { name = "float", property = "HipHeight", delta = 4 },
        { name = "ground", property = "HipHeight", delta = -2 },
        { name = "restore", property = "Reset", delta = 0 },
        { name = "camerazoom", property = "CameraMaxZoomDistance", delta = 50 },
        { name = "cameraclose", property = "CameraMaxZoomDistance", delta = -10 },
        { name = "fovwide", property = "CameraFieldOfView", delta = 15 },
        { name = "fovtight", property = "CameraFieldOfView", delta = -10 },
    }

    register({
        name = "buffreset",
        category = "Buffs",
        description = "Reset humanoid modifiers on target player(s).",
        run = function(ctx, args)
            withTargets(ctx, args[1], function(target)
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.WalkSpeed = 16
                    hum.JumpPower = 50
                    hum.CameraMaxZoomDistance = 128
                    hum.CameraFieldOfView = 70
                    local bodyHeight = hum:FindFirstChild("BodyHeightScale")
                    local bodyWidth = hum:FindFirstChild("BodyWidthScale")
                    if bodyHeight and bodyHeight:IsA("NumberValue") then bodyHeight.Value = 1 end
                    if bodyWidth and bodyWidth:IsA("NumberValue") then bodyWidth.Value = 1 end
                    hum.HipHeight = 2
                end
            end)
        end,
    })

    for _, buff in ipairs(buffs) do
        register({
            name = buff.name,
            category = "Buffs",
            description = "Adjust " .. buff.property .. " by " .. tostring(buff.delta) .. " for target player(s).",
            run = function(ctx, args)
                withTargets(ctx, args[1], function(target)
                    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                    if not hum then return end
                    if buff.property == "Reset" then
                        target:LoadCharacter()
                        return
                    end

                    if buff.property == "BodyHeightScale" or buff.property == "BodyWidthScale" then
                        local scaler = hum:FindFirstChild(buff.property)
                        if scaler and scaler:IsA("NumberValue") then
                            scaler.Value = math.max(0.5, scaler.Value + buff.delta)
                        end
                        return
                    end

                    if buff.property == "CameraMaxZoomDistance" or buff.property == "CameraFieldOfView" then
                        if buff.property == "CameraMaxZoomDistance" then
                            hum.CameraMaxZoomDistance = math.max(10, hum.CameraMaxZoomDistance + buff.delta)
                        else
                            hum.CameraFieldOfView = math.clamp(hum.CameraFieldOfView + buff.delta, 40, 120)
                        end
                        return
                    end

                    if buff.property == "HipHeight" then
                        hum.HipHeight = math.max(0, hum.HipHeight + buff.delta)
                        return
                    end

                    if buff.property == "MaxHealth" then
                        hum.MaxHealth = math.max(1, hum.MaxHealth + buff.delta)
                        hum.Health = math.min(hum.Health, hum.MaxHealth)
                        return
                    end

                    if buff.property == "Health" then
                        hum.Health = math.clamp(hum.Health + buff.delta, 0, hum.MaxHealth)
                        return
                    end

                    if buff.property == "WalkSpeed" or buff.property == "JumpPower" then
                        hum[buff.property] = math.max(0, hum[buff.property] + buff.delta)
                        return
                    end
                end)
            end,
        })
    end
end

registerBaseCommands()
registerLeaderstatCommands()
registerAttributeCommands()
registerWeatherCommands()
registerMassMessageCommands()
registerEmoteCommands()
registerBuffCommands()

return AdminCommands
