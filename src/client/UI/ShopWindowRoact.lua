local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Common.Roact)

local ShopWindowRoact = Roact.Component:extend("ShopWindowRoact")

function ShopWindowRoact:init()
    self:setState({
        selectedItem = "sword",
        goldAmount = 1000,
    })
    
    self.shopItems = {
        { id = "sword", name = "Iron Sword", price = 100, icon = "⚔️" },
        { id = "shield", name = "Wooden Shield", price = 150, icon = "🛡️" },
        { id = "bow", name = "Wooden Bow", price = 200, icon = "🏹" },
        { id = "potion", name = "Health Potion", price = 50, icon = "🧪" },
        { id = "armor", name = "Leather Armor", price = 300, icon = "🎽" },
    }
end

function ShopWindowRoact:render()
    local children = {
        UIListLayout = Roact.createElement("UIListLayout", {
            Padding = UDim.new(0, 5),
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        Title = Roact.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = "SHOP",
            TextSize = 24,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        }),
        
        GoldLabel = Roact.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Color3.fromRGB(50, 50, 50),
            TextColor3 = Color3.fromRGB(255, 215, 0),
            Text = "💰 Gold: " .. self.state.goldAmount,
            TextSize = 16,
            Font = Enum.Font.Gotham,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        }),
    }
    
    -- Create item buttons dynamically
    for index, item in ipairs(self.shopItems) do
        children["Item_" .. item.id] = Roact.createElement("Frame", {
            Size = UDim2.new(1, -10, 0, 40),
            BackgroundColor3 = Color3.fromRGB(60, 60, 60),
            BorderSizePixel = 1,
            BorderColor3 = Color3.fromRGB(100, 100, 100),
            LayoutOrder = 2 + index,
        }, {
            ItemText = Roact.createElement("TextLabel", {
                Size = UDim2.new(0.7, 0, 1, 0),
                BackgroundTransparency = 1,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Text = item.icon .. " " .. item.name .. " (" .. item.price .. "G)",
                TextSize = 14,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextScaled = true,
            }),
            
            SelectButton = Roact.createElement("TextButton", {
                Position = UDim2.new(0.7, 0, 0, 0),
                Size = UDim2.new(0.3, -5, 1, 0),
                BackgroundColor3 = self.state.selectedItem == item.id 
                    and Color3.fromRGB(0, 150, 0) 
                    or Color3.fromRGB(100, 100, 100),
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Text = self.state.selectedItem == item.id and "✓ SEL" or "SELECT",
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                BorderSizePixel = 0,
            })
        })
    end
    
    -- Buy button
    children["BuyButton"] = Roact.createElement("TextButton", {
        Size = UDim2.new(0.5, -5, 0, 40),
        BackgroundColor3 = Color3.fromRGB(0, 120, 200),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "BUY",
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        LayoutOrder = 100,
    })
    
    -- Reset button
    children["ResetButton"] = Roact.createElement("TextButton", {
        Size = UDim2.new(0.5, -5, 0, 40),
        BackgroundColor3 = Color3.fromRGB(200, 100, 0),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "RESET",
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        LayoutOrder = 101,
    })
    
    return Roact.createElement("ScreenGui", {
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Name = "ShopGui",
    }, {
        ShopWindow = Roact.createElement("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 450, 0, 450),
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            BorderColor3 = Color3.fromRGB(200, 150, 0),
            BorderSizePixel = 2,
            Name = "ShopWindow",
        }, children)
    })
end

return ShopWindowRoact
