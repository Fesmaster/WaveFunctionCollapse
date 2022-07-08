--[[
Wavefunction Collapse Algorithm
generating random stuff for ages.

this program is written for Love2D version 11.3
this program is not determanent. It can get stuck. It can run forever. If a particular
generation is taking too long / gets stuck, etc. just close it and run it again.

from the folder containing this file, run `lovec . <yourInputFileHere> <optionalSwatchSizeHere>
The input file (an image) is nesecary, however, the swatch size option is not. See the nodes by 
the variable below for more info on the swatch size

At any point, you can press ctrl-s to save the image in its current state. This will write it to a
sequentially named file in Love2D's default save folder, and prints the full filepath
to the console. 
--]]

--[[
Settings Variables
--]]
--the size of a pizel as drawn on the screen (not in the output file)
local drawSize = 15
--the number of pixels wide and tall the output will be
local mapSizeX = 50
local mapSizeY = 50
--the swatch size determines how large of an area must be matched. Increasing this past 3 results
--in the program becoming abysmally slow. (this is a bug to be improved later)
--decreasing this less than 2 results in incoherent output.
local swatchSize = 3
--the number of steps the update can go each frame before being killed
--if performance is an issue, decrease this. It should always be at least (swatchSize+2)^2 
local floodFillMaxDepth = (6-swatchSize)^4


--imports, setup
queue = require("queue")
--stack = require("stack")
rect = require("rect")
color = require("color")
require("util")
dump = require("inspect")
math.randomseed(os.time())

--[[
global data
--]]

--the source ImageData
local SrcImageData
--width and height of the source
local SrcWidth, SrcHeight

--the source image as a rectangle of color classes
local SrcRectangle

--map of color class numbers to the actual color
local ColorClasses = {}

--list of swatches
local SwatchList = {}

--the map, a rectangle of wave functions. A wave function is a list of possible swatch ids that can go here
local Map

--this becomes true when the generation is complete
--it stops the calling of WaveFunctionCollapseStep()
local freeze = false


--[[
PROFILING
uncomment the next section (add a dash to the next line of "--[[")
to enable profiling.
This profiling code is from: https://www.lua.org/pil/23.3.html
--]]

--[[
local Counters = {}
local Names = {}
local function hook ()
    local f = debug.getinfo(2, "f").func
    if Counters[f] == nil then    -- first time `f' is called?
        Counters[f] = 1
        Names[f] = debug.getinfo(2, "Sn")
    else  -- only increment the counter
        Counters[f] = Counters[f] + 1
    end
end

function getname (func)
    local n = Names[func]
    if n.what == "C" then
        return n.name
    end
    local loc = string.format("[%s]:%s", n.short_src, n.linedefined)
    if n.namewhat ~= "" then
        return string.format("%s (%s)", loc, n.name)
    else
        return string.format("%s", loc)
    end
end

function love.quit()
    debug.sethook()
    for func, count in pairs(Counters) do
        print(getname(func) .. "\t;" .. count)
    end
end

debug.sethook(hook, "c")  -- turn on the hook
--]]


--[[
swatch object. 
This is a set of nxn color classes (with the middle stored seperately)
the middle color class is used for determining the color of an output pixel (based 
on which swatches it matches)
The adjacency list (the rest of the nxn area) is used to determine if a swatch can match an area.
that function is later appended to the swatch table. (it depends of a different function defined later)
--]]
local swatch = {
    --check if a swatch is equal to another (allowing the == operator to be used between swatch instances)
    __eq = function(this, other)
        if this.ColorClass ~= other.ColorClass then return false end
        if #this.AdjcencyList ~= #other.AdjcencyList then return false end
        for k, v in ipairs(this.AdjcencyList) do
            if v ~= other.AdjcencyList[k] then return false end
        end
        return true
    end,
    --turn a swatch into a string, for debugging
    --ie, now print(swatchobject) works correctly
    __tostring = function(this)
        return "Swatch:\n\tColorClass = " .. this.ColorClass .. "\n\tAdjacencyList = " .. dump(this.AdjcencyList)
    end,
    
}
--set up the swatch table to be used as a metatable
swatch.__index = swatch
--create a new swatch from the source at x,y
function swatch.new(x, y)
    local s = {
        ColorClass = SrcRectangle[x][y],
        AdjcencyList = {},
    }
    --for all the nearby coordinates to x,y (within the swatchSize), add their color class to the adjacency list
    --this must be a list, as there is a mapping from coord to index (as enforced by rect.getNearbyCoords)
    for k, v in ipairs(SrcRectangle:getNearbyCoords(x, y, swatchSize)) do
        s.AdjcencyList[#s.AdjcencyList+1] = SrcRectangle[v]
    end
    --set swatch as the metatable so the above metamethods work
    setmetatable(s, swatch)
    return s
end

--[[
setup functions
--]]

--construct the color classes from source image
--also builds the source rectangle at the same time. less work than doing it later
--if you were converting this to tilemaps, this is one of the functions you would need to change
local function BuildColorClasses()
    --make the source rectangle
    SrcRectangle = rect.new(0,0,SrcWidth-1, SrcHeight-1, 0)
    for x = 0, SrcWidth-1 do
        for y = 0, SrcHeight-1 do
            --ok, this is a crazy line
            --create a new color, based off of the pixels from the source image at x,y
            --then add that (uniquely!) to ColorClasses. This returns its index
            --THEN, set that index as the value of the SrcRectangle at x,y
            SrcRectangle[x][y] = addUnique(ColorClasses, color.new(SrcImageData:getPixel(x, y)))
        end
    end
end

--builds the swatch list
--must be run after BuildColorClasses()
local function BuildSwatches()
    --for every pos in the Src rectangle, make a swatch from it, 
    --and add uniquely to the swatch list
    for pos, v in SrcRectangle:iter() do
        addUnique(SwatchList, swatch.new(pos.x, pos.y))
    end
end

--build the map
--must be done after swatches are built
local function BuildMap()
    --just make a new rectangle, with a lambda function returning a new list
    Map = rect.new(0,0,mapSizeX-1, mapSizeY-1, function()
        --iota works like std::iota from c++, taking the input list, 
        --and filling it with the numbers from start to stop
        return iota({},1,#SwatchList)
    end)
end

--this is used in debugging messages and queueing positions
--it just turns a vector into a string
local function posHasher(v)
    return ""..v.x..","..v.y
end

--[[
wave funtion collapse algorithm
This is where all the jucy stuff lives
due to the nature of lua, you will find the individual parts
first, and teh full algorithm after.
--]]


--find the cell in the map with the least complex wave function that is not collapsed (its list is not len 1.)
local function FindLeastCell()
    local lowest_val = #SwatchList+1 --can never have this many
    local lowest_list = {}
    for pos, list in Map:iter() do
        if #list < lowest_val and #list > 1 then
            --if a new lowest that isn't 1 is found, set it as lowest
            lowest_val = #list
            lowest_list= {pos}
        elseif #list == lowest_val then
            --if one equal to lowest is found, add to list
            lowest_list[#lowest_list + 1] = pos
        end
    end
    if #lowest_list > 0 then
        --pick a random position from the lowest list
        return lowest_list[math.random(#lowest_list)] 
    else
        return nil --nothing else to do. It will exit, as the algorithm has finished
    end
end

--get a set of all possible color classes for a cell.
--used in Swatch:MatchAgainstWorldCell
--the return value is a set as things will be searching it for specific values
--and puting the values in the key (as they are integers) makes it amortized O(1) search time
--yes, there is probability involved in that, as its a hash table, but
--it doesn't matter that much
local function GetColorClassesOfCell(pos)
    local wave = Map[pos]
    if not wave then return {} end
    local cc = {}
    for k, i in ipairs(wave) do
        cc[SwatchList[i].ColorClass] = true
    end
    return cc
end

--match a swatch against a position in the world. Returns true if the swatch can be there, false otherwise
--this function is part of the swatch class. As it depends on GetColorClassesOfCell, its defined here.
function swatch.MatchAgainstWorldCell(this, pos)
    --for each pos in the map nearby the given pos, get its nearby color classes
    --and add them to the list
    --this list is the same order as the adjacency list in the swatch.
    local NearbyColorClasses = {}
    for k, p2 in ipairs(Map:getNearbyCoords(pos.x, pos.y, swatchSize)) do
        NearbyColorClasses[#NearbyColorClasses+1] = GetColorClassesOfCell(p2)
    end
    --as long as each of the nearby color class sets contains the matching adjacency color, then the swatch can fit
    for k, cc in ipairs(this.AdjcencyList) do
        if not NearbyColorClasses[k][cc] then
            return false --could not find one of that color class.
        end
    end
    return true
end

--compare two waves (list of swatch ids.)
--the lists will always be in ascending order.
function CompareWaves(w1, w2)
    if #w1 ~= #w2 then return false end
    for i, k in ipairs(w1) do
        if k ~= w2[i] then return false end
    end
    return true
end

--Update the wave function of a cell in the world
--returns true if the cell was actually changed, false otherwise.
local function UpdateWorldCellWave(pos)
    local wave = Map[pos]
    if not wave then return false end --early out if wave is not present (pos outside of map)
    if #wave == 1 then return false end --early out if already collapsed
    --for each possible swatch, check if it can fit here
    --yes, this allows the number of possibilities to grow.
    --see the next two functions for why this is important
    --this never allows collapsed cells to grow (as they exit the function earlier)
    local newWave = {}
    for i = 1, #SwatchList do
        if SwatchList[i] and SwatchList[i]:MatchAgainstWorldCell(pos) then
            newWave[#newWave + 1] = i
        end
    end
    --set the new wave to the world
    Map[pos] = newWave
    return not CompareWaves(wave, newWave) 
end

--whenever an impossible situation is encountered
--the area around it is erased. This function does that erasure.
--because cells can be erased, it must be possible for other cells nearby to have their waves increased
local function EraseAndFix(pos)
    --for every cell in the swatch size, erase it
    for i, p in ipairs(Map:getNearbyCoords(pos.x, pos.y, swatchSize)) do
        Map[p] = iota({},1,#SwatchList)
    end
    --nearby does not have the passed position as one of its returns, so do that one manually
    Map[pos] = iota({},1,#SwatchList)
end

--perform updates on cells, starting from a specific position
--if not constrained (by floodFillMaxDepth) it would likely run for infinity
local function FloodFillCellUpdate(pos)
    local q = queue.new(posHasher) --a queue
    --enqueue all cells in the size of a swatch around the start pos
    for k, p2 in ipairs(Map:getNearbyCoords(pos.x, pos.y, swatchSize)) do
        q:enqueue(p2)
    end
    --contunuously dequeue a cell, update it, and, if changed, enqueue its neighbors
    --however, only do this floodFillMaxDepth times.
    local counter = 0
    local p = q:dequeue()
    while p and counter < floodFillMaxDepth do
        counter = counter + 1
        if UpdateWorldCellWave(p) then
            if #(Map[p]) == 0 then
                --the update showed that it cannot have any tiles placed there
                --so, erase it, erase the starting position, and continue updating with this new info
                EraseAndFix(p)
                EraseAndFix(pos)
                --enqueue the area around start too
                for k, p2 in ipairs(Map:getNearbyCoords(pos.x, pos.y, swatchSize)) do
                    if #(Map[p2]) > 1 then
                        q:enqueue(p2)
                    end
                end    
            end
            --enqueue neighbors
            for k, p2 in ipairs(Map:getNearbyCoords(p.x, p.y, swatchSize)) do
                if #(Map[p2]) > 1 then
                    q:enqueue(p2)
                end
            end     
        end
        p = q:dequeue()
    end
end

--perform a single step of the wave function collapse
--This is the jucy function
--it actually performs the wave function collapse algorithm
local function WaveFunctionCollapseStep()
    --find a cell to collapse
    local pos = FindLeastCell()
    if not pos then 
        --there are no cells to collapse, so, we are done.
        freeze = true
        print("COMPLETE!")
        return 
    end 
    
    --collapse the selected cell
    local wave = Map[pos]
    if not wave then 
        print("INVALID POSITION")
        return  --we picked a position outside the map. huh.
    end
    if #wave <= 1 then 
        print("COMPLETE POSITION")
        return --we picked a position that was already collapsed
    end
    --the actual collapse. Pick a random swatchID from the current wave, and make a new wave containing Only that id.
    local newWave = {wave[math.random(#wave)]}
    Map[pos] = newWave

    --update nearby cells (and possibly collapse them)
    FloodFillCellUpdate(pos)
end


--function run when love loads
function love.load(arg)
    --get the image from the args
    if not  arg[1] then
        print("No image passed")
        love.event.quit(1)
    end
    --get the swatch size from the args
    if arg[2] then
        local n = tonumber(arg[2])
        if n then
            swatchSize = n
        end
    end
    --set the window size to match the view of the output
    love.window.setMode(drawSize*mapSizeX, drawSize*mapSizeY)

    --import the image
    SrcImageData = love.image.newImageData(arg[1])
    SrcWidth, SrcHeight = SrcImageData:getDimensions()
    
    --run the setup functions in proper order
    BuildColorClasses()
    BuildSwatches()
    BuildMap()
end


--the update function
local frameCount = 0;
local  timeCount = 0;
function love.update(dt)
    if not freeze then
        --FPS measureing
        frameCount = frameCount + 1
        timeCount = timeCount + dt
        if timeCount > 1 then
            print("FPS: " .. (frameCount / timeCount))
            frameCount = 0
            timeCount = 0
        end
        
        --run a single step of the algorithm
        WaveFunctionCollapseStep()
    end
    
end




--[[
DRAWING STUFF
this is no longer related to the algorithm, and is for putting stuff on screen
the two functions (DrawRectangle and DrawSwatch) are left there so you can fiddle aroudn with what is drawn and 
gain a better understnding of the algorithm

These are fairly straightforward, and I am not going to explain them in detail.
--]]

local function DrawRectangle(x, y, r)
    for pos, class in r:iter() do
        local color = ColorClasses[class]
        love.graphics.setColor(color.r, color.g, color.b, color.a)
        love.graphics.rectangle("fill", x+(pos.x)*drawSize, y+(pos.y)*drawSize, drawSize, drawSize)
    end
end

local function DrawSwatch(x, y, s)
    local min = -math.floor(swatchSize/2)
    local max = math.ceil(swatchSize/2)-1 --not the same as math.floor! behaves differently when n is even.
    local index = 1
    for dx = min, max do
        for dy = min, max do
            local class = 0
            if (dx ~= 0 or dy ~= 0) then
                class = s.AdjcencyList[index]
                index = index + 1
            else
                class = s.ColorClass
            end
            local color = ColorClasses[class]
            if color then
                love.graphics.setColor(color.r, color.g, color.b, color.a)
            else
                love.graphics.setColor(1, 0, 1, 1)
            end
            love.graphics.rectangle("fill", x+(dx-min)*drawSize, y+(dy-min)*drawSize, drawSize, drawSize)
        end
    end
end

local function DrawMap(x, y)
    for pos, swatchIDs in Map:iter() do
        local c = nil
        for k, id in ipairs(swatchIDs) do
            if c then
                c = c + ColorClasses[SwatchList[id].ColorClass]
            else
                c = ColorClasses[SwatchList[id].ColorClass]
            end
        end
        if c then
            c = c / #swatchIDs
        else
            c = color.new(1,0,1,1)
        end
        love.graphics.setColor(c.r, c.g, c.b, c.a)
        love.graphics.rectangle("fill", x+(pos.x)*drawSize, y+(pos.y)*drawSize, drawSize, drawSize)
    end
end

function love.draw()
    love.graphics.clear(1, 0, 1, 1)

    --comment this if drawing any of the below
    --only one of the three drawables should be uncommented (so its clear what is being drawn)
    DrawMap(0,0)

    --uncomment this to draw all the swatches
    --[[
    for i, s in ipairs(SwatchList) do
        DrawSwatch(i*(swatchSize+1)*drawSize, 0, s)
    end
    --]]
    
    --uncomment this to draw the source rectangle
    --DrawRectangle(0,0,SrcRectangle)
end



--[[
Saving ability
--]]

local function DrawMapToImageData(id)
    for pos, swatchIDs in Map:iter() do
        local c = nil
        for k, id in ipairs(swatchIDs) do
            if c then
                c = c + ColorClasses[SwatchList[id].ColorClass]
            else
                c = ColorClasses[SwatchList[id].ColorClass]
            end
        end
        if c then
            c = c / #swatchIDs
        else
            c = color.new(1,0,1,1)
        end
        id:setPixel(pos.x, pos.y, c.r, c.g, c.b, c.a)
    end
end

function love.keypressed( key, scancode, isrepeat )
    if key == "s" then
        if love.keyboard.isDown( "lctrl", "rctrl" ) then
            print("saving...")
            --create an imageData and fill it with the map's pixels
            local id = love.image.newImageData(mapSizeX, mapSizeY, "rgba8")
            DrawMapToImageData(id)
            --now find an output file to dump into
            local index = -1
            local exists = true
            local filename = ""
            while exists do
                index = index + 1
                filename = string.format("outfile%04d.png", index)
                exists = (love.filesystem.getInfo(filename) ~= nil)
            end
            --with the nonexistant file found, write to it
            local cwd = love.filesystem.getAppdataDirectory()
            id:encode("png", filename)
            print("saved to: " .. cwd .. "/" .. filename)
        end 
    end
end
