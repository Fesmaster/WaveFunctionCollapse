--[[
object to represent a rectangular area with indexing and wrapping
this is used for both the source image and the output map
--]]
local dump = require("inspect")

local rect = {}

--create a new rect
--paramaters: 
--      minx, miny, maxx, maxy define the bounds (inclusive)
--      defaultvalue can be a value or a function. if a function, it is called with the x,y of the cell. 
--          if left nil, then it is set to 0
function rect.new(minx, miny, maxx, maxy, defaultvalue)
    if not defaultvalue then defaultvalue = 0 end
    local r = {
        min = {x=minx, y=miny},
        max = {x=maxx, y=maxy},
        data = {}
    }

    for x = minx, maxx do
        r.data[x] = {}
        for y = miny, maxy do
            if type(defaultvalue) == "function" then
                r.data[x][y] = defaultvalue(x, y)
            else
                r.data[x][y] = defaultvalue
            end
        end
    end

    setmetatable(r, rect)
    return r
end

--make a copy of the rect
function rect.clone(this, clonefunc)
    local r = {
        min = {x=this.min.x, y=this.min.y},
        max = {x=this.max.x, y=this.max.y},
        data = {}
    }
    for x = this.min.x, this.max.x do
        r.data[x] = {}
        for y = this.min.y, this.max.y do
            if clonefunc then
                r.data[x][y] = clonefunc(this.data[x][y])
            else
                r.data[x][y] = this.data[x][y]
            end
        end
    end
    setmetatable(r, rect)
    return r
end
--[[
index into the rect object
three possibilities:
if indexing with a number, get the row from the data table
if indexing with a vector {x=x,y=y}, get the position from the data table
otherwise, get the value from the rect table
thus, there are two ways to get a cell from the rectangle:
    r[x][y]
    r[{x=x,y=y}]
--]]
function rect.__index(this, key)
    if type(key) == "number" then
        return this.data[key]
    elseif type(key) == "table" and key.x and key.y then
        if this.data[key.x] then
            return this.data[key.x][key.y]
        else
            return nil
        end
    else
        return rect[key]
    end
end

--[[
set a value in the table. 
If passing a vector of {x=x,y=y} as the key, set the appropreate cell. 
Otherwise, set it like normal
--]]
function rect.__newindex(this, key, value)
    if type(key) == "table" and key.x and key.y and type(key.x) == "number" and type(key.y) == "number" then
        if this.data[key.x] then
            this.data[key.x][key.y] = value
        end
    else
        rawset(this, key, value)
    end
end

function rect.__len(this)
    return {x=this.max.x, y=this.max.y}
end

--[[
tostring function, for printing
print(r) works properly.
--]]
function rect.__tostring(this)
    local str = ""
    for y = this.min.y, this.max.y do
        for x = this.min.x, this.max.x do
            str = str .. dump(this.data[x][y])
            if x < this.max.x then
                str = str .. ", "
            end
        end
        if y < this.max.y then
            str = str .. "\n"
        end
    end
    return str
end

--wrap a value between min and max
local function wrap(n, min, max)
    n = n - min
    max = max - min
    while(n < 0) do n = n + max end
    return (n % max) + min
end

--wrap coords in the rect, as individual values
function rect.wrapCoords(this, x, y)
    return wrap(x, this.min.x, this.max.x+1), wrap(y, this.min.y, this.max.y+1)
end

--wrap coords in the rect, as a vector {x=x,y=y}
function rect.wrapCoordsT(this, t)
    return {x=wrap(t.x, this.min.x, this.max.x+1), y=wrap(t.y, this.min.y, this.max.y+1)}
end



--get the nearby coords, a square around {x=x,y=y} with size n (if n is even, prefers negative)
--returns a list of positions, wrapping around the sides of the rectangle
--does not return the passed position
function rect.getNearbyCoords(this, x, y, n)
    local min = -math.floor(n/2)
    local max = math.ceil(n/2)-1 --not the same as math.floor! behaves differently when n is even.
    local near = {}
    for dx = min, max do
        for dy = min, max do
            if (dx ~= 0 or dy ~= 0) then
                near[#near+1] = this:wrapCoordsT({x=x+dx, y=y+dy})
            end
        end
    end
    return near
end

--stateless iterator. Outside the iter function so its properly counted by profiler
local function stateless(tbl, v)
    --print(dump(v))
    local x=v.x+1
    local y=v.y
    if x > #tbl.data then
        x = tbl.min.x
        y=y+1
    end
    --print(dump(v))
    if tbl.data[x] and tbl.data[x][y] then
        return {x=x, y=y}, tbl.data[x][y]
    end
end

--iterate over all the values in the rectangle.
--for use in a for loop, ie:
--for pos, val in r:iter() do ...
--where pos = {x=x,y=y} and val is the val at that cell.
function rect.iter(this)
    --print(dump(this.min))
    return stateless, this, {x=this.min.x-1, y=this.min.y}
end

return rect