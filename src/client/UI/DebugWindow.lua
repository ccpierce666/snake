local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Iris = require(ReplicatedStorage.Common.Iris)
local Knit = require(ReplicatedStorage.Common.Knit)

local DebugWindow = {}

function DebugWindow.Start()
    local PlayerDataService = Knit.GetService("PlayerDataService")
    
    local moneyState = Iris.State(0)
    
    PlayerDataService.MoneyChanged:Connect(function(newMoney)
        moneyState:set(newMoney)
    end)
    
    PlayerDataService:GetMoney():andThen(function(money)
        moneyState:set(money)
    end)

    Iris:Connect(function()
        Iris.Window({"Debug Window"})
            Iris.Text({"Current Money: " .. moneyState:get()})
            
            if Iris.Button({"Add 10 Money (Mock)"}).clicked() then
                 print("Button clicked!")
            end
        Iris.End()
    end)
end

return DebugWindow