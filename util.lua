--[[
some of utility functions I did not feel like having in the main file.
--]]

function iota(table, start, stop, val)
    if not val then val = start end
    for i = start, stop do
        table[i] = val
        val = val + 1
    end
    return table
end

function addUnique(table, value)
    for k, v in ipairs(table) do
        if v == value then
            return k
        end
    end
    table[#table+1] = value
    return #table
end

function indexOf(table, value)
    for k, v in ipairs(table) do
        if v == value then
            return k
        end
    end
    return -1
end

function removeValuePure(table, value)
    local t = {}
    for k, v in ipairs(table) do
        if v ~= value then
            t[#t+1] = v
        end
    end
    return t
end