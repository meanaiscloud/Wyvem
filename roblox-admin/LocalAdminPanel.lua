--!strict
-- LocalScript for client-side UI and networking.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local AdminCommands = require(ReplicatedStorage:WaitForChild("AdminPanel"):WaitForChild("AdminCommands"))
local requestEvent = ReplicatedStorage:WaitForChild("AdminCommandRequest")
local resultEvent = ReplicatedStorage:WaitForChild("AdminCommandResult")
local aiFunction = ReplicatedStorage:WaitForChild("AdminAISuggest")

local theme = {
    primary = Color3.fromRGB(10, 20, 40),
    accent = Color3.fromRGB(0, 132, 255),
    surface = Color3.fromRGB(15, 25, 55),
    text = Color3.fromRGB(220, 235, 255),
}

local gui = Instance.new("ScreenGui")
if syn and syn.protect_gui then
    syn.protect_gui(gui)
end
gui.Name = "AdminPanel"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Size = UDim2.fromScale(0.4, 0.6)
container.Position = UDim2.fromScale(0.3, 0.2)
container.BackgroundColor3 = theme.primary
container.BorderSizePixel = 0
container.Visible = false
container.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 50)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Admin Panel"
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = theme.text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = container

local toggleHint = Instance.new("TextLabel")
toggleHint.Size = UDim2.new(1, -20, 0, 20)
toggleHint.Position = UDim2.new(0, 10, 0, 30)
toggleHint.BackgroundTransparency = 1
toggleHint.Text = "RightCtrl to toggle"
toggleHint.Font = Enum.Font.GothamSemibold
toggleHint.TextSize = 12
toggleHint.TextColor3 = Color3.fromRGB(160, 190, 230)
toggleHint.TextXAlignment = Enum.TextXAlignment.Left
toggleHint.Parent = container

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -20, 0, 32)
searchBox.Position = UDim2.new(0, 10, 0, 60)
searchBox.PlaceholderText = "Search commands..."
searchBox.Text = ""
searchBox.TextColor3 = theme.text
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 16
searchBox.BackgroundColor3 = theme.surface
searchBox.BorderSizePixel = 0
searchBox.Parent = container

local commandListFrame = Instance.new("ScrollingFrame")
commandListFrame.Size = UDim2.new(1, -20, 0.55, -20)
commandListFrame.Position = UDim2.new(0, 10, 0, 100)
commandListFrame.BackgroundColor3 = theme.surface
commandListFrame.BorderSizePixel = 0
commandListFrame.ScrollBarThickness = 6
commandListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
commandListFrame.CanvasSize = UDim2.new()
commandListFrame.Parent = container

local uiList = Instance.new("UIListLayout")
uiList.Padding = UDim.new(0, 4)
uiList.FillDirection = Enum.FillDirection.Vertical
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Parent = commandListFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 24)
infoLabel.Position = UDim2.new(0, 10, 1, -80)
infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.GothamSemibold
infoLabel.TextSize = 14
infoLabel.TextColor3 = theme.text
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Text = "Select a command"
infoLabel.Parent = container

local argsBox = Instance.new("TextBox")
argsBox.Size = UDim2.new(1, -20, 0, 32)
argsBox.Position = UDim2.new(0, 10, 1, -50)
argsBox.PlaceholderText = "Args (space separated). First arg is target selector"
argsBox.Text = ""
argsBox.TextColor3 = theme.text
argsBox.Font = Enum.Font.Gotham
argsBox.TextSize = 15
argsBox.BackgroundColor3 = theme.surface
argsBox.BorderSizePixel = 0
argsBox.Parent = container

local sendButton = Instance.new("TextButton")
sendButton.Size = UDim2.new(0.4, -15, 0, 32)
sendButton.Position = UDim2.new(0, 10, 1, -12)
sendButton.Text = "Run"
sendButton.Font = Enum.Font.GothamBold
sendButton.TextSize = 16
sendButton.TextColor3 = theme.text
sendButton.BackgroundColor3 = theme.accent
sendButton.BorderSizePixel = 0
sendButton.Parent = container

local aiButton = Instance.new("TextButton")
aiButton.Size = UDim2.new(0.6, -15, 0, 32)
aiButton.Position = UDim2.new(0.4, 15, 1, -12)
aiButton.Text = "Ask AI for suggestion"
aiButton.Font = Enum.Font.GothamBold
aiButton.TextSize = 16
aiButton.TextColor3 = theme.text
aiButton.BackgroundColor3 = Color3.fromRGB(0, 85, 170)
aiButton.BorderSizePixel = 0
aiButton.Parent = container

local selectedCommand: string? = nil

local function animateVisible(show: boolean)
    if show then container.Visible = true end
    local goal = { BackgroundTransparency = show and 0 or 1 }
    TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
    if not show then task.delay(0.2, function() container.Visible = false end) end
end

local function renderCommands()
    for _, child in ipairs(commandListFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local query = string.lower(searchBox.Text)
    for _, def in ipairs(AdminCommands.list()) do
        if query == "" or string.find(string.lower(def.name), query, 1, true) or string.find(string.lower(def.description), query, 1, true) then
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, -6, 0, 32)
            button.BackgroundColor3 = theme.primary
            button.TextColor3 = theme.text
            button.Font = Enum.Font.Gotham
            button.TextSize = 14
            button.TextXAlignment = Enum.TextXAlignment.Left
            button.AutoButtonColor = false
            button.Text = def.name .. " • " .. def.category
            button.Parent = commandListFrame

            button.MouseButton1Click:Connect(function()
                selectedCommand = def.name
                infoLabel.Text = def.description
            end)
        end
    end
end

renderCommands()

searchBox:GetPropertyChangedSignal("Text"):Connect(renderCommands)

sendButton.MouseButton1Click:Connect(function()
    if not selectedCommand then
        infoLabel.Text = "Select a command first."
        return
    end
    local args = {}
    for word in string.gmatch(argsBox.Text, "[^%s]+") do
        table.insert(args, word)
    end
    requestEvent:FireServer({ name = selectedCommand, args = args })
end)

aiButton.MouseButton1Click:Connect(function()
    aiButton.Text = "Thinking..."
    local ok, suggestion = pcall(function()
        return aiFunction:InvokeServer(argsBox.Text ~= "" and argsBox.Text or "Suggest a command for moderation")
    end)
    aiButton.Text = "Ask AI for suggestion"
    if ok and type(suggestion) == "string" then
        infoLabel.Text = suggestion
    else
        infoLabel.Text = "AI error: " .. tostring(suggestion)
    end
end)

resultEvent.OnClientEvent:Connect(function(message)
    infoLabel.Text = message
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        animateVisible(not container.Visible)
    end
end)
