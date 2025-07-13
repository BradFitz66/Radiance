local vector = require("Resources.Lib.brinevector")
local render_resolution = {
    width = 1280/2,
    height = 700/2
}

local jfa_shader 
local seed_shader;
local distance_field_shader;
local gi_shader;
local drawing = false;
local startX, startY = 0, 0;
local toX, toY = 0, 0;

local drawing_pass = 0;
local brushSize = 8;
local passes = 0;

local drawing_canvas
local canvas_a 
local canvas_b 
local canvas_jfa
local canvas_distance
local canvas_gi
local canvas_gi_prev
local drawing_color = {1, 1, 1, 1}

function love.load()
    local w,h = render_resolution.width, render_resolution.height
    jfa_shader = love.graphics.newShader("Resources/Shaders/jump_flood.glsl")
    seed_shader = love.graphics.newShader("Resources/Shaders/seed.glsl")
    distance_field_shader = love.graphics.newShader("Resources/Shaders/distancefield.glsl")
    gi_shader = love.graphics.newShader("Resources/Shaders/raymarch.glsl")
    passes = 1


    
    canvas_a = love.graphics.newCanvas(w, h)
    canvas_b = love.graphics.newCanvas(w, h)
    drawing_canvas = love.graphics.newCanvas(w, h)
    canvas_jfa = love.graphics.newCanvas(w, h)
    canvas_distance = love.graphics.newCanvas(w, h)
    canvas_gi = love.graphics.newCanvas(w, h)
    canvas_gi_prev = love.graphics.newCanvas(w, h)

    local screen = vector(w, h)
    local aspect = screen / math.max(screen.x, screen.y)
    print("Aspect Ratio: " .. aspect.x .. ", " .. aspect.y)
    --jfa_shader:send("aspect", {aspect.x, aspect.y})
    jfa_shader:send("oneOverSize", {1.0 / w, 1.0 / h})
    gi_shader:send("showNoise", true)
    gi_shader:send("showGrain", false)
    gi_shader:send("useTemporalAccum", false)
    gi_shader:send("enableSun", false)
    gi_shader:send("maxSteps", 64)
    gi_shader:send("rayCount", 32)
    gi_shader:send("sunAngle", 1.0)


end



function love.draw()
    local mx, my = love.mouse.getPosition()

    if drawing_pass == 0 then
        love.graphics.draw(canvas_gi,0,0)
    elseif drawing_pass == 1 then
        love.graphics.draw(canvas_distance, 0, 0)
    elseif drawing_pass == 2 then
        love.graphics.draw(canvas_jfa, 0, 0)
    end

--Draw UI
    love.graphics.circle("line", mx, my, brushSize)
    love.graphics.print("Passes: " .. passes, 10, 10)

    
end


function redraw()
    local w,h = render_resolution.width, render_resolution.height
    local a_or_b = true

    canvas_b:renderTo(function()
        love.graphics.setShader(seed_shader)
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.draw(drawing_canvas)
        love.graphics.setShader()
    end)
    
    local max = math.max(w, h)
    local steps = math.ceil(math.log(max))
    local stepSize = 1;

    local a, b
    for i = 1, passes do
        if a_or_b then 
            a = canvas_a
            b = canvas_b
        else
            a = canvas_b
            b = canvas_a
        end
        jfa_shader:send("stepsize", math.pow(2, passes- i))
        love.graphics.setCanvas(a)
            love.graphics.setShader(jfa_shader)
                love.graphics.clear(0, 0, 0, 1)
                love.graphics.draw(b)
            love.graphics.setShader()
        love.graphics.setCanvas()
        a_or_b = not a_or_b
        if a_or_b then canvas_jfa = a else canvas_jfa = b end
    end


    love.graphics.setCanvas(canvas_distance)
        love.graphics.setShader(distance_field_shader)
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.draw(canvas_jfa)
        love.graphics.setShader()
    love.graphics.setCanvas()

    gi_shader:send("distanceTexture", canvas_distance)
    gi_shader:send("lastFrameTexture", canvas_gi_prev)

    love.graphics.setCanvas(canvas_gi)
        love.graphics.setShader(gi_shader)
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.draw(drawing_canvas)
        love.graphics.setShader()
    love.graphics.setCanvas()
end

function drawLine(fromX, fromY, toX, toY)
    local left  = 0;
    local top = 0;
    local right = render_resolution.width - 1;
    local bottom = render_resolution.height - 1;

    local width = right - left + 1;
    local height = bottom - top + 1;

    local dx = toX - fromX;
    local dy = toY - fromY;
    local length = math.sqrt(dx * dx + dy * dy);
    if length == 0 then return end
    dx = dx / length;
    dy = dy / length;
    local x0 = math.floor(fromX - left);
    local y0 = math.floor(fromY - top);
    local x1 = math.floor(toX - left);
    local y1 = math.floor(toY - top);
    local dx = math.abs(x1 - x0);
    local dy = math.abs(y1 - y0);
    local sx = (x0 < x1) and 1 or -1;
    local sy = (y0 < y1) and 1 or -1;
    local err = dx - dy;

    while true do
        -- Draw the pixel and its surrounding pixels
        love.graphics.circle('fill', x0 + left, y0 + top, brushSize)

        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x0 = x0 + sx
        end
        if e2 < dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
end

function love.update(dt)
    --Set title to show FPS
    love.window.setTitle("FPS: " .. love.timer.getFPS())
    local mouseX, mouseY = love.mouse.getPosition()

    gi_shader:send("time", love.timer.getTime())


    if love.mouse.isDown(1) then
        drawing = true
        if startX == 0 and startY == 0 then
            startX, startY = mouseX, mouseY
            toX, toY = mouseX, mouseY
        end
    else
        drawing = false
        startX, startY = 0, 0
        toX, toY = 0, 0
    end

    if drawing then 
        toX, toY = mouseX, mouseY
        if drawing_canvas == nil then
            return;
        end
        drawing_canvas:renderTo(function()
            love.graphics.setColor(drawing_color)
            drawLine(startX, startY, toX, toY)
            if (startX == toX and startY == toY) then
                love.graphics.circle('fill', toX, toY, brushSize)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end)
        redraw()
        startX, startY = toX, toY
    else
        toX, toY = 0,0
    end

end



function love.wheelmoved(x, y)
    if y > 0 then
        brushSize = brushSize + 4
    elseif y < 0 then
        brushSize = math.max(1, brushSize - 4)
    end
end

function love.mousepressed(x, y, button)
    if button == 2 then
        if drawing_color[1] == 1 then
            drawing_color = {0, 0, 0, 1} -- Change to black
        else
            drawing_color = {1, 1, 1, 1} -- Change to white
        end
    elseif button == 3 then
        --Set color to random
        drawing_color = {love.math.random(), love.math.random(), love.math.random(), 1}
    end

end

function love.keypressed(key)
    --Redraw when space is pressed
    if key == "space" then
        drawing_pass = (drawing_pass + 1) % 3
    end
    --Increase passes when up arrow is pressed
    if key == "up" then
        passes = passes + 1
        redraw()
    end
    --Decrease passes when down arrow is pressed
    if key == "down" then
        passes = math.max(1, passes - 1)
        redraw(true)
    end
end