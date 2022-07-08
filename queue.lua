--[[
A unique-entry queue object.
if an object is enqueued, and equal hashed object cannot be enqueued till the original is dequeued.
ie, its a queue with a set bolted on. If an object is in the set, it cannot be enqueued. 
When an object is enqueued, it is added to the set. when dequeued, it is removed. 
Since queues and sets are pretty basic, Ill leave it at that.
--]]
local queue = {}
queue.__index = queue

queue.defaultHasher = function(k)
    return tostring(k)
end

queue.new = function(hasher, optimizeval)
    if not hasher then hasher = queue.defaultHasher end
    if not optimizeval then optimizeval = 64 end
    local q = {
        hasher = hasher,
        complete = {},
        front = 1,
        data = {},
        optimizeval = optimizeval
    }
    setmetatable(q, queue)
    return q
end

queue.enqueue = function(this, val)
    local k = this.hasher(val)
    if this.complete[k] then
        return false
    else
        this.complete[k] = true
    end
    this.data[#this.data+1] = val
    return true
end

queue.dequeue = function(this)
    if this.front > #this.data then
        return nil
    end
    --not running off the end yet!
    local r = this.data[this.front]
    this.front = this.front + 1
    
    --allow the value to be entered again
    this.complete[this.hasher(r)] = false
    
    if (this.optimizeval > 1 and this.optimizeval < this.front) then
        this:optimize()
    end
    return r
end

queue.optimize = function(this)
    local newdata = {}
    local k = 1
    for i = this.front, #this.data do
        newdata[k] = this.data[i]
        k = k + 1
    end
    this.data = newdata
    this.front = 1
end

queue.__tostring = function(this)
    local str = "QUEUE: \n\tCount: " .. #this.data .. "\n\t{"
    for k, v in ipairs(this.data) do
        if k == this.front then
            str = str .. "\n\t-->"
        end
        str = str .. "{" ..this.hasher(v) .. "}"
        if k < #this.data then
            str = str .. ", "
        end
    end
    str = str .. "}\n\tFront: " .. this.front
    return str
end

return queue