local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Simple text-based debug info display
local DebugUIPanel = {}

function DebugUIPanel.Start()
    print("[DebugUIPanel] Starting Debug Panel...")
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Create debug window
    local debugGui = Instance.new("ScreenGui")
    debugGui.Name = "DebugGui"
    debugGui.ResetOnSpawn = false
    debugGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    debugGui.Parent = playerGui
    
    -- Debug panel frame
    local panel = Instance.new("Frame")
    panel.Name = "DebugPanel"
    panel.Position = UDim2.new(0, 10, 0, 10)
    panel.Size = UDim2.new(0, 280, 0, 250)
    panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    panel.BorderColor3 = Color3.fromRGB(0, 255, 100)
    panel.BorderSizePixel = 2
    panel.Parent = debugGui
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 35)
    title.BackgroundColor3 = Color3.fromRGB(0, 150, 75)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "🛠️ DEBUG PANEL (Iris Style)"
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.BorderSizePixel = 0
    title.Parent = panel
    
    -- Info text - Section 1
    local section1 = Instance.new("TextLabel")
    section1.Name = "Section1"
    section1.Position = UDim2.new(0, 10, 0, 45)
    section1.Size = UDim2.new(1, -20, 0, 50)
    section1.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    section1.TextColor3 = Color3.fromRGB(0, 255, 150)
    section1.Text = "📊 STATS\n💰 Gold: 1500\n⭐ Level: 25"
    section1.TextSize = 12
    section1.Font = Enum.Font.Courier
    section1.TextXAlignment = Enum.TextXAlignment.Left
    section1.TextYAlignment = Enum.TextYAlignment.Top
    section1.BorderSizePixel = 1
    section1.BorderColor3 = Color3.fromRGB(0, 150, 75)
    section1.Parent = panel
    
    local padding1 = Instance.new("UIPadding")
    padding1.PaddingLeft = UDim.new(0, 8)
    padding1.PaddingTop = UDim.new(0, 5)
    padding1.Parent = section1
    
    -- Info text - Section 2
    local section2 = Instance.new("TextLabel")
    section2.Name = "Section2"
    section2.Position = UDim2.new(0, 10, 0, 105)
    section2.Size = UDim2.new(1, -20, 0, 50)
    section2.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    section2.TextColor3 = Color3.fromRGB(100, 200, 255)
    section2.Text = "🎮 CONTROLS\n↑ Move Up\n← Move Left"
    section2.TextSize = 12
    section2.Font = Enum.Font.Courier
    section2.TextXAlignment = Enum.TextXAlignment.Left
    section2.TextYAlignment = Enum.TextYAlignment.Top
    section2.BorderSizePixel = 1
    section2.BorderColor3 = Color3.fromRGB(0, 150, 75)
    section2.Parent = panel
    
    local padding2 = Instance.new("UIPadding")
    padding2.PaddingLeft = UDim.new(0, 8)
    padding2.PaddingTop = UDim.new(0, 5)
    padding2.Parent = section2
    
    -- Button
    local button = Instance.new("TextButton")
    button.Name = "TestButton"
    button.Position = UDim2.new(0, 10, 0, 165)
    button.Size = UDim2.new(1, -20, 0, 30)
    button.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = "🔵 Test Button"
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = panel
    
    button.MouseButton1Click:Connect(function()
        print("[DebugUIPanel] Button clicked!")
    end)
    
    -- Status line
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Position = UDim2.new(0, 10, 0, 205)
    status.Size = UDim2.new(1, -20, 0, 30)
    status.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    status.TextColor3 = Color3.fromRGB(0, 255, 100)
    status.Text = "✓ ALL SYSTEMS OPERATIONAL"
    status.TextSize = 11
    status.Font = Enum.Font.Courier
    status.BorderSizePixel = 1
    status.BorderColor3 = Color3.fromRGB(0, 255, 100)
    status.Parent = panel
    
    print("[DebugUIPanel] Debug Panel created successfully!")
end

return DebugUIPanel

