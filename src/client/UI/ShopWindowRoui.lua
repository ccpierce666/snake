local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Common.Roact)
local Roui = require(ReplicatedStorage.Common.Roui)

local ShopWindowRoui = Roact.Component:extend("ShopWindowRoui")

function ShopWindowRoui:init()
    self:setState({
        selectedItem = "sword",
        goldAmount = 1500,
    })
    
    self.shopItems = {
        { id = "sword", name = "⚔️ Iron Sword", price = 100, rarity = "Common" },
        { id = "shield", name = "🛡️ Wooden Shield", price = 150, rarity = "Common" },
        { id = "bow", name = "🏹 Wooden Bow", price = 200, rarity = "Uncommon" },
        { id = "potion", name = "🧪 Health Potion", price = 50, rarity = "Rare" },
        { id = "armor", name = "🎽 Leather Armor", price = 300, rarity = "Epic" },
    }
end

function ShopWindowRoui:render()
    local children = {}
    
    -- Header
    children.Header = Roui.Header({
        Title = "🏪 SHOP",
        Subtitle = "Premium Items",
        Color = Color3.fromRGB(255, 140, 0),
        ZIndex = 1,
    })
    
    -- Gold display card
    children.GoldCard = Roact.createElement("Frame", {
        Position = UDim2.new(0, 20, 0, 100),
        Size = UDim2.new(1, -40, 0, 60),
        BackgroundColor3 = Color3.fromRGB(255, 215, 0),
        BorderSizePixel = 0,
        ZIndex = 1,
    }, {
        UICorner = Roact.createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
        }),
        
        Text = Roact.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(40, 40, 40),
            Text = "💰 Gold: " .. self.state.goldAmount,
            TextSize = 22,
            Font = Enum.Font.GothamBold,
        })
    })
    
    -- Items container
    local itemsContainer = {
        UIListLayout = Roact.createElement("UIListLayout", {
            Padding = UDim.new(0, 12),
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
    }
    
    -- Create item cards
    for i, item in ipairs(self.shopItems) do
        local rarityColors = {
            Common = Color3.fromRGB(169, 169, 169),
            Uncommon = Color3.fromRGB(34, 139, 34),
            Rare = Color3.fromRGB(65, 105, 225),
            Epic = Color3.fromRGB(138, 43, 226),
        }
        
        local rarityColor = rarityColors[item.rarity] or Color3.fromRGB(200, 100, 50)
        
        itemsContainer["Item" .. i] = Roact.createElement("Frame", {
            Size = UDim2.new(1, -20, 0, 60),
            BackgroundColor3 = Color3.fromRGB(50, 50, 50),
            BorderSizePixel = 1,
            BorderColor3 = Color3.fromRGB(100, 100, 100),
            LayoutOrder = i,
        }, {
            UICorner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }),
            
            Icon = Roact.createElement("TextLabel", {
                Size = UDim2.new(0, 60, 1, 0),
                BackgroundColor3 = rarityColor,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Text = item.name:sub(1, 2), -- Get emoji
                TextSize = 24,
                Font = Enum.Font.GothamBold,
                BorderSizePixel = 0,
            }, {
                UICorner = Roact.createElement("UICorner", {
                    CornerRadius = UDim.new(0, 6),
                })
            }),
            
            Content = Roact.createElement("Frame", {
                Position = UDim2.new(0, 65, 0, 0),
                Size = UDim2.new(1, -135, 1, 0),
                BackgroundTransparency = 1,
            }, {
                Name = Roact.createElement("TextLabel", {
                    Size = UDim2.new(1, 0, 0.5, 0),
                    BackgroundTransparency = 1,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Text = item.name,
                    TextSize = 14,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }),
                
                Rarity = Roact.createElement("TextLabel", {
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.new(1, 0, 0.5, 0),
                    BackgroundTransparency = 1,
                    TextColor3 = rarityColor,
                    Text = item.rarity,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
            }),
            
            PriceButton = Roact.createElement("TextButton", {
                Position = UDim2.new(1, -60, 0.5, -15),
                Size = UDim2.new(0, 50, 0, 30),
                BackgroundColor3 = self.state.selectedItem == item.id 
                    and Color3.fromRGB(76, 175, 80)
                    or Color3.fromRGB(100, 100, 100),
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Text = item.price .. "G",
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                BorderSizePixel = 0,
            }, {
                UICorner = Roact.createElement("UICorner", {
                    CornerRadius = UDim.new(0, 4),
                })
            })
        })
    end
    
    children.ItemsContainer = Roact.createElement("Frame", {
        Position = UDim2.new(0, 20, 0, 175),
        Size = UDim2.new(1, -40, 0, 330),
        BackgroundTransparency = 1,
    }, itemsContainer)
    
    -- Button bar
    children.ButtonBar = Roact.createElement("Frame", {
        Position = UDim2.new(0, 20, 1, -60),
        Size = UDim2.new(1, -40, 0, 50),
        BackgroundTransparency = 1,
    }, {
        UIListLayout = Roact.createElement("UIListLayout", {
            Padding = UDim.new(0, 10),
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        
        BuyButton = Roact.createElement("TextButton", {
            Size = UDim2.new(0.5, -5, 1, 0),
            BackgroundColor3 = Color3.fromRGB(76, 175, 80),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = "💳 BUY NOW",
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        }, {
            UICorner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 8),
            })
        }),
        
        ResetButton = Roact.createElement("TextButton", {
            Size = UDim2.new(0.5, -5, 1, 0),
            BackgroundColor3 = Color3.fromRGB(244, 67, 54),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = "🔄 RESET",
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        }, {
            UICorner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 8),
            })
        })
    })
    
    return Roact.createElement("ScreenGui", {
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Name = "ShopGuiRoui",
    }, {
        Shadow = Roact.createElement("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 520, 0, 620),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.7,
            BorderSizePixel = 0,
            ZIndex = 0,
        }, {
            UICorner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 14),
            })
        }),
        
        MainWindow = Roact.createElement("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 500, 0, 600),
            BackgroundColor3 = Color3.fromRGB(20, 25, 35),
            BorderSizePixel = 0,
            ZIndex = 1,
        }, children)
    })
end

return ShopWindowRoui
