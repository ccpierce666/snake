-- Roui - Custom UI component library
local Roact = require(script.Parent:WaitForChild("Roact"))

local Roui = {}

-- Theme
Roui.Theme = {
    Primary = Color3.fromRGB(100, 200, 255),
    Secondary = Color3.fromRGB(100, 220, 100),
    Accent = Color3.fromRGB(255, 150, 100),
    Dark = Color3.fromRGB(30, 30, 40),
    Light = Color3.fromRGB(200, 200, 200),
    Border = Color3.fromRGB(0, 0, 0),
    BorderThickness = 3,
}

-- Helper functions
local function merge(a, b)
    local out = {}
    for k, v in pairs(a or {}) do out[k] = v end
    for k, v in pairs(b or {}) do out[k] = v end
    return out
end

local function mergeProps(props, defaults)
    return merge(defaults, props)
end

local function isAssetId(str)
    return type(str) == "string" and (str:match("^rbxasset") or str:match("^http") or tonumber(str))
end

local function el(className, props, children)
    return Roact.createElement(className, props or {}, children or {})
end

-- Common Styles
local function Border(thickness)
    return el("UIStroke", {
        Color = Roui.Theme.Border,
        Thickness = thickness or Roui.Theme.BorderThickness,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function Corner(radius)
    return el("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

-- Text component
function Roui.Text(props)
    props = mergeProps(props, {
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextScaled = false,
        Font = Enum.Font.FredokaOne, -- Cartoon style font
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.new(0,0,0),
    })
    return el("TextLabel", props)
end

-- Button component (Standard)
function Roui.Button(props)
    local color = props.Color or Roui.Theme.Primary
    props = mergeProps(props, {
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextScaled = true,
        Font = Enum.Font.FredokaOne,
        TextStrokeTransparency = 0,
    })
    
    return el("TextButton", props, {
        UICorner = Corner(8),
        UIStroke = Border(2),
        Children = props[Roact.Children] and Roact.createFragment(props[Roact.Children])
    })
end

-- StatBar component (Top bars: Score/Money)
function Roui.StatBar(props)
    local height = 50
    props = mergeProps(props, {
        Size = UDim2.new(0, 260, 0, height),
        BackgroundColor3 = Color3.fromRGB(160, 100, 255), -- Default Purple
        BorderSizePixel = 0,
    })
    
    local iconContent
    if isAssetId(props.Icon) then
        iconContent = el("ImageLabel", {
            Position = UDim2.new(0, 5, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, 36, 0, 36),
            BackgroundTransparency = 1,
            Image = props.Icon,
        })
    else
        iconContent = Roui.Text({
            Position = UDim2.new(0, 10, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, 30, 0, 30),
            Text = props.Icon or "🐍",
            TextSize = 24,
            BackgroundTransparency = 1,
        })
    end
    
    return el("Frame", props, {
        UICorner = Corner(height/2), -- Pill shape
        UIStroke = Border(4),
        
        -- Icon Container
        Icon = iconContent,
        
        -- Value Text
        Value = Roui.Text({
            Name = props.LabelName or "ValueLabel",
            Position = UDim2.new(0, 50, 0, 0),
            Size = UDim2.new(1, -90, 1, 0),
            Text = props.Value or "0",
            TextSize = 28,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = Enum.Font.FredokaOne,
        }),
        
        -- Plus Button
        AddBtn = el("ImageButton", {
            Position = UDim2.new(1, -40, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, 32, 0, 32),
            BackgroundColor3 = Color3.fromRGB(50, 200, 50),
            BorderSizePixel = 0,
        }, {
            UICorner = Corner(16),
            UIStroke = Border(3),
            PlusIcon = Roui.Text({
                Size = UDim2.new(1, 0, 1, -2),
                Text = "+",
                TextSize = 24,
                Font = Enum.Font.GothamBlack,
            })
        })
    })
end

-- MenuButton component (Shop, Skin, etc.)
function Roui.MenuButton(props)
    local size = props.Size or UDim2.new(0, 80, 0, 80)
    props = mergeProps(props, {
        Size = size,
        BackgroundColor3 = Color3.fromRGB(255, 180, 50),
        BorderSizePixel = 0,
        Text = "",
    })
    
    local iconContent
    if isAssetId(props.Icon) then
        iconContent = el("ImageLabel", {
             Position = UDim2.new(0.5, 0, 0.4, 0),
             AnchorPoint = Vector2.new(0.5, 0.5),
             Size = UDim2.new(0.65, 0, 0.65, 0),
             BackgroundTransparency = 1,
             Image = props.Icon,
        })
    else
        iconContent = Roui.Text({
            Position = UDim2.new(0.5, 0, 0.4, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0.6, 0, 0.6, 0),
            Text = props.Icon or "🏠",
            TextSize = 36,
        })
    end
    
    return el("TextButton", props, {
        UICorner = Corner(16),
        UIStroke = Border(4),
        
        Icon = iconContent,
        
        Label = Roui.Text({
            Position = UDim2.new(0.5, 0, 0.85, 0),
            AnchorPoint = Vector2.new(0.5, 1),
            Size = UDim2.new(1, 0, 0.3, 0),
            Text = props.Label or "Menu",
            TextSize = 16,
            Font = Enum.Font.FredokaOne,
            TextStrokeTransparency = 0,
        })
    })
end

-- LevelBadge component
function Roui.LevelBadge(props)
    return el("Frame", {
        Size = UDim2.new(0, 80, 0, 90),
        BackgroundColor3 = Color3.fromRGB(150, 160, 180), -- Silver/Grey
        BorderSizePixel = 0,
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
    }, {
        UICorner = Corner(20),
        UIStroke = Border(4),
        
        LevelText = Roui.Text({
            Position = UDim2.new(0.5, 0, 0.4, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(1, 0, 0.5, 0),
            Text = "LV" .. tostring(props.Level or 1),
            TextSize = 32,
            Font = Enum.Font.FredokaOne,
        }),
        
        Label = Roui.Text({
            Position = UDim2.new(0.5, 0, 0.85, 0),
            AnchorPoint = Vector2.new(0.5, 1),
            Size = UDim2.new(1, 0, 0.3, 0),
            Text = "等级",
            TextSize = 14,
        }),
        
        Notification = props.Notification and el("Frame", {
            Position = UDim2.new(1, -10, 0, -5),
            Size = UDim2.new(0, 24, 0, 24),
            BackgroundColor3 = Color3.fromRGB(255, 50, 50),
            ZIndex = 2,
        }, {
            UICorner = Corner(12),
            UIStroke = Border(2),
            Num = Roui.Text({
                Size = UDim2.new(1, 0, 1, 0),
                Text = tostring(props.Notification),
                TextSize = 14,
            })
        })
    })
end

-- LeaderboardRow component (Updated style)
function Roui.LeaderboardRow(props)
    props = mergeProps(props, {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        LayoutOrder = props.Rank or 0,
    })
    local isTop = (props.Rank or 1) <= 3
    local bgColor = props.Highlight and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(50, 60, 80)
    if isTop and not props.Highlight then
        bgColor = Color3.fromRGB(255, 200, 50) -- Gold for top 3
    end
    
    return el("Frame", props, {
        Background = el("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = bgColor,
            BorderSizePixel = 0,
            ZIndex = 0,
        }, {
            UICorner = Corner(6),
            UIStroke = Border(2),
        }),
        Rank = Roui.Text({
            Position = UDim2.new(0, 5, 0, 0),
            Size = UDim2.new(0, 25, 1, 0),
            Text = tostring(props.Rank or 1),
            TextSize = 16,
            ZIndex = 1,
        }),
        Name = Roui.Text({
            Position = UDim2.new(0, 35, 0, 0),
            Size = UDim2.new(0.6, -35, 1, 0),
            Text = props.Name or "Player",
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 1,
        }),
        Score = Roui.Text({
            Position = UDim2.new(0.6, 0, 0, 0),
            Size = UDim2.new(0.4, -5, 1, 0),
            Text = tostring(props.Score or 0),
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 1,
        }),
    })
end

-- Leaderboard component (Updated style)
function Roui.Leaderboard(props, children)
    props = mergeProps(props, {
        Size = UDim2.new(0, 180, 0, 300),
        BackgroundColor3 = Color3.fromRGB(40, 40, 50),
        BorderSizePixel = 0,
    })
    
    return el("Frame", props, children or {})
end

-- Overlay component
function Roui.Overlay(props, children)
    local transparency = props.Transparency or 0.5
    local onClose = props.OnClose
    -- Remove custom props to avoid issues
    if props.Transparency then props.Transparency = nil end
    if props.OnClose then props.OnClose = nil end
    
    props = mergeProps(props, {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = transparency,
        BorderSizePixel = 0,
        ZIndex = 100,
        Active = true, -- Block clicks
    })
    
    local overlayChildren = children or {}
    
    -- If onClose is provided, add a button to close by clicking the overlay
    if onClose then
        overlayChildren.CloseOverlay = el("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 99, -- Below the panel
            [Roact.Event.Activated] = onClose,
        })
    end
    
    return el("Frame", props, overlayChildren)
end

return Roui
