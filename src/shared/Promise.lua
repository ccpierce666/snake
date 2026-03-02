-- Promise - Minimal stub
local Promise = {}

function Promise.new(executor)
    local promise = {}
    promise.resolved = false
    promise.value = nil
    
    function promise:andThen(callback)
        if self.resolved then
            callback(self.value)
        end
        return self
    end
    
    function promise:catch(callback)
        return self
    end
    
    executor(function(value)
        promise.resolved = true
        promise.value = value
    end)
    
    return promise
end

return Promise
