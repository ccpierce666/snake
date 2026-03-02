local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Common.Roact)
local Knit = require(ReplicatedStorage.Common.Knit)

local CoinDisplay = Roact.Component:extend("CoinDisplay")

function CoinDisplay:init()
    self:setState({
        money = 0
    })
    
    self.moneyConnection = nil
end

function CoinDisplay:didMount()
    local PlayerDataService = Knit.GetService("PlayerDataService")

    PlayerDataService:GetMoney():andThen(function(money)
        self:setState({ money = money })
    end)
    
    self.moneyConnection = PlayerDataService.MoneyChanged:Connect(function(newMoney)
        self:setState({ money = newMoney })
    end)
end

function CoinDisplay:willUnmount()
    if self.moneyConnection then
        self.moneyConnection:Disconnect()
    end
end

function CoinDisplay:render()
    return Roact.createElement("ScreenGui", {
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, {
        CoinFrame = Roact.createElement("Frame", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 10),
            Size = UDim2.new(0, 200, 0, 50),
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            BorderSizePixel = 0,
        }, {
            UICorner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 8),
            }),
            
            TextLabel = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "Coins: " .. tostring(self.state.money),
                TextColor3 = Color3.fromRGB(255, 215, 0),
                TextSize = 24,
                Font = Enum.Font.GothamBold,
            }),
        })
    })
end

return CoinDisplay