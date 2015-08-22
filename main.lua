-- Ludum Dare 33 entry
-- Copyright (C) 2015 Marnix Massar <marnix@vivesce.re>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "lib/lovedebug" -- For live debugging
local Gamestate = require "lib/HUMP/gamestate" -- For game states
local anim8 = require 'lib/anim8' -- For animations

-- Define game states
local menu = {}
local level1 = {}
local inter = {}
local gameover = {}

local function Proxy(f) -- Proxy function for sprites and audio
    return setmetatable({}, {__index = function(self, k)
        local v = f(k)
        rawset(self, k, v)
        return v
    end})
end

function round(num, idp)
    return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

function checkcollision(x1,y1,w1,h1, x2,y2,w2,h2)
    return x1 < x2+w2 and
            x2 < x1+w1 and
            y1 < y2+h2 and
            y2 < y1+h1
end

Tile = Proxy( function(k) return love.graphics.newImage("img/tile/"..k..".png") end)
Anim = Proxy( function(k) return love.graphics.newImage("img/anim/"..k..".png") end)
Bagr = Proxy( function(k) return love.graphics.newImage("img/bg/"..k..".png") end)
Snd = Proxy(function(k) return love.audio.newSource(love.sound.newSoundData("snd/"..k..".wav")) end)

sorts = {"wall", "space"}
seed = os.time()

function q() -- For debug mode
    love.event.quit()
end

local function caveinit()
    local tiles = {Tile.wall1, Tile.wall2, Tile.wall3, Tile.wall4}
    dungeon = {}
    for i = 1, (600 / tilesize) do
        local newrow = {}

        for n = 1, (912 / tilesize) do
            randomise()
            local newtile = {sort = sorts[math.random(#sorts)], tile = tiles[math.random(#tiles)]}
            table.insert(newrow, newtile)
        end

        table.insert(dungeon, newrow)
    end
end

function check(pos)
    if pos ~= nil and pos.sort == "wall" then -- If this tile is a wall then add one to count
        return 1
    elseif pos == nil then -- If this tile doesn't exist (and thus counts as a wall) then add one to count
        return 1
    else -- If this tile is open, add zero
        return 0
    end
end

function randomise()
    seed = seed + 11
    math.randomseed(seed)
end

local function cellulate(times) -- the cellulate function running multiple times gives smoother maps
    for i = 1, times do
        for k1,v1 in pairs(dungeon) do
            for k2,v2 in pairs(v1) do
                count = 0
                hatched = false

                count = count + check(v1[k2 - 1]) -- left
                count = count + check(v1[k2 + 1]) -- right
    
                if k1 == 1 then -- top row
                    count = count + 3
                else
                    count = count + check(dungeon[k1 - 1][k2 - 1]) -- top and left
                    count = count + check(dungeon[k1 - 1][k2]) -- directly above
                    count = count + check(dungeon[k1 - 1][k2 + 1]) -- top and right
                end

                if k1 == #dungeon then -- bottom row
                    count = count + 3
                else
                    count = count + check(dungeon[k1 + 1][k2 - 1])
                    count = count + check(dungeon[k1 + 1][k2])
                    count = count + check(dungeon[k1 + 1][k2 + 1])
                end

                if count > 5 then -- apply rules to count - toy around with these for different results
                    v2.sort = "wall"
                elseif count < 3 then
                    v2.sort = "space"
                end

                if k1 == 1 or k1 == #dungeon or k2 == 1 or k2 == (912 / tilesize) then
                    v2.sort = "wall"
                end

                v2.x = (k2 - 1) * tilesize
                v2.y = (k1 - 1) * tilesize
            end
        end
    end
--    dungeon[math.random(#dungeon)][math.random(912/tilesize)].item = "hatch"
    
    local cont = true
    while cont == true do
        randomise()
        hatchloc = dungeon[math.random(#dungeon)][math.random(888/tilesize)]
        if hatchloc.sort == "space" then
            hatchloc.item = "hatch"
            cont = false
        end
    end
end

local function drawcave() -- Draw caves from the grid
    for k1,v1 in pairs(dungeon) do
        for k2,v2 in pairs(v1) do
            if v2.sort == "wall" then
                love.graphics.draw(v2.tile, v2.x, v2.y)
            elseif v2.item == "hatch" then
                love.graphics.draw(Tile.hatch, v2.x, v2.y)
            end
        end
    end
end

function spawn(sort, x, y)
    if sort == "happya" then
        newmonster = {sort = "happya", x = x, y = y}
        table.insert(happyas, newmonster)
        debugvar2 = true
    end
    debugvar1 = true
end

function checkwallcollision()
    gridloc = {x = round((player.x + (tilesize / 2)) / tilesize, 0), y = round((player.y + (tilesize / 2)) / tilesize, 0)} -- Magic!

    if (checkcollision(dungeon[gridloc.y][gridloc.x].x, dungeon[gridloc.y][gridloc.x].y, tilesize, tilesize, player.x, player.y, 21, 6) and dungeon[gridloc.y][gridloc.x].sort == "wall") or
        (checkcollision(dungeon[gridloc.y + 1][gridloc.x].x, dungeon[gridloc.y + 1][gridloc.x].y, tilesize, tilesize, player.x, player.y, 21, 6) and dungeon[gridloc.y + 1][gridloc.x].sort == "wall") or
        (checkcollision(dungeon[gridloc.y][gridloc.x + 1].x, dungeon[gridloc.y][gridloc.x + 1].y, tilesize, tilesize, player.x, player.y, 21, 6) and dungeon[gridloc.y][gridloc.x + 1].sort == "wall") or
        (checkcollision(dungeon[gridloc.y + 1][gridloc.x + 1].x, dungeon[gridloc.y + 1][gridloc.x + 1].y, tilesize, tilesize, player.x, player.y, 21, 6) and dungeon[gridloc.y + 1][gridloc.x + 1].sort == "wall") then
        return true
    else
        return false
    end

--    if (dungeon[gridloc.y][gridloc.x].sort == "wall" and player.x % tilesize ~= 0) or 
--        (dungeon[gridloc.y + 1][gridloc.x + 1].sort == "wall" and player.y % tilesize ~= 0) or
--        (dungeon[gridloc.y][gridloc.x + 1].sort == "wall" and player.y % tilesize ~= 0) or
--        (dungeon[gridloc.y + 1][gridloc.x].sort == "wall" and player.x % tilesize ~= 0) then
--        return true
--    else
--        return false
--    end
end

local function moveplayer(dt)
    local lastloc = {x = player.x, y = player.y}

    -- Check if the player wants to go left or right, and if yes, give them the velocity to do so
    if love.keyboard.isDown("left") and player.xspeed > mmaxspeed then
        player.xspeed = player.xspeed - (speedmod)
    elseif love.keyboard.isDown("right") and player.xspeed < maxspeed then
        player.xspeed = player.xspeed + (speedmod)
    else
        player.xspeed = 0
    end

    -- Check up and down
    if love.keyboard.isDown("up") and player.yspeed > mmaxspeed then
        player.yspeed = player.yspeed - (speedmod)
    elseif love.keyboard.isDown("down") and player.yspeed < maxspeed then
        player.yspeed = player.yspeed + (speedmod)
    else
        player.yspeed = 0
    end

    -- Do the actual moving
    player.x = player.x + player.xspeed
    player.y = player.y + player.yspeed

    -- Move back in case of collision
    if checkwallcollision() then
        player.x = lastloc.x
        player.y = lastloc.y
    end
end

function love.load()
    -- Constants
    tilesize = 24
    speedmod = 1
    maxspeed = 4
    mmaxspeed = -1 * maxspeed

    -- Fonts
    justice = love.graphics.newFont("font/justice.ttf", 30)
    love.graphics.setFont(justice)

    -- Globals
    depth = 1

    -- Animations
    local g = anim8.newGrid(21, 6, Anim.newchar:getWidth(), Anim.newchar:getHeight())
    walkanim = anim8.newAnimation(g('1-3',1), 0.2)
    local g = anim8.newGrid(tilesize, tilesize, Anim.happya:getWidth(), Anim.happya:getHeight())
    happyanim = anim8.newAnimation(g('1-6',1), {0.5, 0.1, 0.1, 0.1, 0.1, 0.1})

    -- Switch to menu gamestate
    Gamestate.registerEvents()
    Gamestate.switch(menu)
end


function menu:enter(previous, ...)
    flashtimer = 0.4
    flashon = true
end

function menu:update(dt)
    flashtimer = flashtimer -dt

    if flashtimer <= 0 then
        if flashon == true then flashon = false else flashon = true end
        flashtimer = 0.4
    end

    if love.keyboard.isDown(" ") then
        love.audio.play(Snd.Select)
        Gamestate.switch(level1)
    end
end

function menu:draw()
    love.graphics.draw(Bagr.menu, 0, 0) -- Background
    if flashon == true then
        love.graphics.draw(Bagr.begin, 0, 0) -- "Press start" text
    end
end

function level1:enter()
    -- Prepare a map
    caveinit()
    cellulate(10)

    -- Decide background based on depth
    if depth == 1 then
        bg = Bagr.stone
    elseif depth < 4 then
        bg = Bagr.stone
    else
        bg = Bagr.darkstone
    end

    -- Decide player spawn location
    local cont = true
    while cont == true do
        randomise()
        a = dungeon[math.random(#dungeon)][math.random(888/tilesize)]
        if a.sort == "space" then
            spawnpoint = {x = a.x, y = a.y}
            cont = false
        end
    end

    -- Prepare spawn timers
    t_happya = 0

    -- Entities
    happyas = {} -- Format: {sort = str, x = int, y = int}
    player = {xspeed = 0, yspeed = 0, x = spawnpoint.x, y = spawnpoint.y}
end

function level1:update(dt)
    love.window.setTitle("Caffiend dev build (FPS:" .. love.timer.getFPS() .. ")") 

    -- Check if we reached the hatch
    if checkcollision(player.x, player.y, 21, 6, hatchloc.x, hatchloc.y + 3, 24, 21) then -- Magic: hatch misses one row of pixels, or three real pixels, at the top
        hatchreached = true
        depth = depth + 1
        Gamestate.switch(inter)
    end

    -- Player movement
    moveplayer(dt)

    -- Manually spawn happyas (debug)
    if love.keyboard.isDown("q") then
        spawn("happya", 0, 0)
    end

    -- Update the animations
--    walkanim:update(dt)
    happyanim:update(dt)

    --Check for ready timers
    if t_happya <= 0 then
        spawn("happya", hatchloc.x, hatchloc.y)
        t_happya = 20
    end

    -- Adjust timers
    t_happya = t_happya - dt
end

function level1:draw()
    -- Draw the current background
    love.graphics.draw(bg, 0, 0)

    -- Draw the cave
    drawcave()

    -- Run the walk animation for the player
    walkanim:draw(Anim.newchar, player.x, player.y)

    -- Draw Happyas
    for k,v in pairs(happyas) do 
        happyanim:draw(Anim.happya, v.x, v.y)
    end
end

function inter:enter()
    hatchreached = false
    remaining = 3 -- Make sure we wait a bit before going to the next level
end

function inter:update(dt)
    remaining = remaining - dt -- Count down....

    if remaining <= 0 then -- And next level
        Gamestate.switch(level1)
    end
end

function inter:draw()
    love.graphics.draw(bg, 0, 0)
    love.graphics.printf("Cleared floor " .. tostring(depth - 1) .. "!", 0, 10, 900, "center") 
end
