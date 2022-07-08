--[[
Color object
this is used to represent a color! It knows how to be added, subtracted from other colors, compared to another color, and multiplied and divided by a number
this is all done with metatables
--]]

local color = {}
color.__index = color

function color.new(r, g, b, a)
    local t = {r=r,g=g,b=b,a=a}
    setmetatable(t, color)
    return t
end

function color.getHex(this)
    return  (math.floor(this.r*255) * 2^24) + 
            (math.floor(this.g*255) * 2^16) + 
            (math.floor(this.b*255) * 2^8) +
            (math.floor(this.a*255))
end

function color.__tostring(this)
    return "{r="..this.r..", g="..this.g .. ", b="..this.b..", a="..this.a.."}=>0x"..string.format("%08x", this:getHex())
end

function color.__eq(this, other)
    return this.r == other.r and
            this.g == other.g and
            this.b == other.b and
            this.a == other.a
end

function color.__add(this, other)
    return color.new(this.r+other.r, this.g+other.g, this.b+other.b, this.a+other.a)
end

function color.__sub(this, other)
    return color.new(this.r-other.r, this.g-other.g, this.b-other.b, this.a-other.a)
end

function color.__mul(this, num)
    return color.new(this.r*num, this.g*num, this.b*num, this.a*num)
end

function color.__div(this, num)
    return color.new(this.r/num, this.g/num, this.b/num, this.a/num)
end

return color
