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
local anim8 = require 'lib/anim8'
local boundingbox = require "lib/boundingbox"

-- Define game states
local menu = {}
local level1 = {}
local gameover = {}

local function Proxy(f) -- Proxy function for sprites and audio
    return setmetatable({}, {__index = function(self, k)
        local v = f(k)
        rawset(self, k, v)
        return v
    end})
end

Tile = Proxy( function(k) return love.graphics.newImage("img/tile/"..k..".png") end)
Anim = Proxy( function(k) return love.graphics.newImage("img/anim/"..k..".png") end)
Bagr = Proxy( function(k) return love.graphics.newImage("img/bg/"..k..".png") end)

dungeon = {}
sorts = {"wall", "space"}
seed = os.time()

local function init()
    local tiles = {Tile.wall1, Tile.wall2, Tile.wall3}
    for i = 1, (600 / tilesize) do
        local newrow = {}

        for n = 1, (912 / tilesize) do
            seed = seed + 11
            math.randomseed(seed)
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

local function cellulate(times) -- the cellulate function running multiple times gives smoother maps
    for i = 1, times do
        for k1,v1 in pairs(dungeon) do
            for k2,v2 in pairs(v1) do
                count = 0

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
end

local function drawcave()
    for k1,v1 in pairs(dungeon) do
        for k2,v2 in pairs(v1) do
            if v2.sort == "wall" then
                love.graphics.draw(v2.tile, v2.x, v2.y)
            end
        end
    end
end

local function moveplayer(dt)
    if love.keyboard.isDown("left") and player.xspeed > mmaxspeed then
        player.xspeed = player.xspeed - (speedmod * dt)
    elseif love.keyboard.isDown("right") and player.xspeed < maxspeed then
        player.xspeed = player.xspeed + (speedmod * dt)
    else
        if player.xspeed > 0 then
            player.xspeed = player.xspeed - (speedmod * 2 * dt)
        elseif player.xspeed < 0 then
            player.xspeed = player.xspeed + (speedmod * 2 * dt)
        end
    end

    if love.keyboard.isDown("up") and player.yspeed > mmaxspeed then
        player.yspeed = player.yspeed - (speedmod * dt)
    elseif love.keyboard.isDown("down") and player.yspeed < maxspeed then
        player.yspeed = player.yspeed + (speedmod * dt)
    else
        if player.yspeed > 0 then
            player.yspeed = player.yspeed - (speedmod * 2 * dt)
        elseif player.yspeed < 0 then
            player.yspeed = player.yspeed + (speedmod * 2 * dt)
        end
    end
end

function love.load()
    tilesize = 24

    local g = anim8.newGrid(tilesize, tilesize, Anim.char:getWidth(), Anim.char:getHeight())
    walkanim = anim8.newAnimation(g('1-4',1), 0.1)
    local g = anim8.newGrid(tilesize, tilesize, Anim.happya:getWidth(), Anim.happya:getHeight())
    happyanim = anim8.newAnimation(g('1-6',1), {0.5, 0.1, 0.1, 0.2, 0.1, 0.1})


    Gamestate.registerEvents()
    Gamestate.switch(menu)
end

function menu:enter(previous, ...)
    Gamestate.switch(level1)
end

function level1:init()
    init()
    cellulate(10)

    speedmod = 20
    maxspeed = 10
    mmaxspeed = -1 * maxspeed

    player = {x = 0, y = 0, xspeed = 0, yspeed = 0} -- TODO: Fix spawn point
end

function level1:update(dt)
    love.window.setTitle("LD33 (FPS:" .. love.timer.getFPS() .. ")") 

    moveplayer(dt)
    player.x = player.x + player.xspeed
    player.y = player.y + player.yspeed

    walkanim:update(dt)
end

function level1:draw()
    love.graphics.draw(Bagr.stone, 0, 0)

    drawcave()

    walkanim:draw(Anim.char, player.x, player.y)
end
