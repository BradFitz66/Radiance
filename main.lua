
local lib_path = love.filesystem.getSaveDirectory() .. "/libraries"
local extension = jit.os == "Windows" and "dll" or jit.os == "Linux" and "so" or jit.os == "OSX" and "dylib"
package.cpath = string.format("%s/?.%s", lib_path, extension)
local ffi = require("ffi")
local imgui = require "Resources.Lib.cimgui"
local imgui_io;

local render_resolution = {
    width = 800,
    height = 800
}

local jfa_shader 
local seed_shader;
local distance_field_shader;
local gi_shader;
local blur_shader;

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
local canvas_seed;
local canvas_previous;

local draw_passes = {
    "GI",
    "Distance Field",
    "Jump Flood",
    "Seed"
}

local settings = {
    showNoise = true,
    showGrain = true,
    useTemporalAccum = true,
    enableSun = true,
    maxSteps = 64.0,
    rayCount = 64.0,
    sunAngle = ffi.new("float[1]", 45.0)
}

local canvas_pos = {
    x = 0,
    y = 0
}

local drawing_color = {1, 1, 1, 1}

local cur_pass = "GI"

function love.load(args)
    --Set window size
    love.window.setMode(1280, 720, {
        resizable = true,
        minwidth = 400,
        minheight = 300,
        vsync = 0,
        msaa = 8
    })
    love.graphics.setDefaultFilter("linear", "linear", 1)
    imgui.love.Init()
    local w,h = render_resolution.width, render_resolution.height

    jfa_shader =            love.graphics.newShader("Resources/Shaders/jump_flood.glsl")
    seed_shader =           love.graphics.newShader("Resources/Shaders/seed.glsl")
    distance_field_shader = love.graphics.newShader("Resources/Shaders/distancefield.glsl")
    gi_shader =             love.graphics.newShader("Resources/Shaders/raymarch.glsl")

    passes = math.ceil(math.log(math.max(w, h)));

    canvas_a =        love.graphics.newCanvas(w, h, {msaa=0})
    canvas_b =        love.graphics.newCanvas(w, h, {msaa=0})
    drawing_canvas =  love.graphics.newCanvas(w, h, {msaa=0})
    canvas_jfa =      love.graphics.newCanvas(w, h, {msaa=0})
    canvas_distance = love.graphics.newCanvas(w, h, {msaa=0})
    canvas_gi =       love.graphics.newCanvas(w, h, {msaa=0})
    canvas_seed =     love.graphics.newCanvas(w, h, {msaa=0})
    canvas_previous = love.graphics.newCanvas(w, h, {msaa=0})

    gi_shader:send("showNoise", settings.showNoise)
    gi_shader:send("showGrain", settings.showGrain)
    gi_shader:send("useTemporalAccum", settings.useTemporalAccum)
    gi_shader:send("enableSun", settings.enableSun)
    gi_shader:send("maxSteps", settings.maxSteps)
    gi_shader:send("rayCount", settings.rayCount)
    gi_shader:send("sunAngle", settings.sunAngle[0])

    imgui_io = imgui.GetIO()
    imgui_io.ConfigWindowsMoveFromTitleBarOnly = true
    imgui_io.ConfigFlags = bit.bor(imgui_io.ConfigFlags, imgui.ImGuiConfigFlags_DockingEnable)
end



function love.draw()
    love.graphics.setBackgroundColor(1, 0, 0, 1)
    love.graphics.setBlendMode("alpha")
    local mx, my = love.mouse.getPosition()
    
    
    imgui.DockSpaceOverViewport(0, imgui.GetMainViewport(),imgui.ImGuiDockNodeFlags_PassthruCentralNode);
    imgui.SetNextWindowSizeConstraints(
        imgui.ImVec2_Float(render_resolution.width, render_resolution.height+20),
        imgui.ImVec2_Float(render_resolution.width, render_resolution.height+20)
    )
    imgui.Begin("Radiance")
        local window_region_min = imgui.GetContentRegionAvail()
        local window_pos = imgui.GetWindowPos()

        canvas_pos.x = window_pos.x 
        canvas_pos.y = window_pos.y+20
    imgui.End()
    imgui.Begin("Info")
        imgui.Text("Controls")
        imgui.Text("Left Click: Draw")
        imgui.Text("Right Click: Random Color")
        imgui.Text("Middle Click: Toggle Color (Black/White)")
        imgui.Text("Scroll Wheel: Change Brush Size")
        imgui.Text("Space: Next Pass")
        imgui.Text("Up Arrow: Increase Passes")
        imgui.Text("Down Arrow: Decrease Passes")
        imgui.Text("R: Reset")
        imgui.Separator()
        imgui.Text("Current Brush Size: " .. brushSize)
        imgui.Text("Current Pass: " .. draw_passes[drawing_pass+1])
        imgui.Text("Current Passes: " .. passes)
        imgui.Text("Current Drawing Color: ")
        imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Button, drawing_color)
        imgui.SameLine()
        imgui.Button("  ")
        imgui.PopStyleColor()
        imgui.Text("Current Resolution: " .. render_resolution.width .. "x" .. render_resolution.height)
    imgui.End()

    imgui.Begin("Settings")
        
        if imgui.Button("Toggle Noise") then
            settings.showNoise = not settings.showNoise
            gi_shader:send("showNoise", settings.showNoise)
            reset()
        end
        if imgui.Button("Toggle Grain") then
            settings.showGrain = not settings.showGrain
            gi_shader:send("showGrain", settings.showGrain)
            reset()
        end
        if imgui.Button("Toggle Temporal Accumulation") then
            settings.useTemporalAccum = not settings.useTemporalAccum
            gi_shader:send("useTemporalAccum", settings.useTemporalAccum)
            reset()
        end
        if imgui.Button("Toggle Sun") then
            settings.enableSun = not settings.enableSun
            gi_shader:send("enableSun", settings.enableSun)
            reset()
        end
        imgui.SliderFloat("Sun Angle", settings.sunAngle, 0.0, 360.0, "%.0f", imgui.ImGuiSliderFlags_AlwaysClamp)
        gi_shader:send("sunAngle", math.rad(settings.sunAngle[0]))
        gi_shader:send("maxSteps", settings.maxSteps)

         
    imgui.End()
    
    imgui.Render()
    imgui.love.RenderDrawLists()
    if drawing_pass == 0 then
        love.graphics.draw(canvas_gi,canvas_pos.x,canvas_pos.y)
    elseif drawing_pass == 1 then
        love.graphics.draw(canvas_distance, canvas_pos.x, canvas_pos.y)
    elseif drawing_pass == 2 then
        love.graphics.draw(canvas_jfa, canvas_pos.x, canvas_pos.y)
    elseif drawing_pass == 3 then
        love.graphics.draw(canvas_seed, canvas_pos.x, canvas_pos.y, 0, 1)
    end

    love.graphics.circle("line", mx, my, brushSize)

    redraw()
end

function love.update(dt)
    --Set title to show FPS
    love.window.setTitle("FPS: " .. love.timer.getFPS())
    local mouseX, mouseY = love.mouse.getPosition()
    --Account for canvas position
    mouseX = mouseX - canvas_pos.x
    mouseY = mouseY - canvas_pos.y

    gi_shader:send("time", love.timer.getTime())

    if love.mouse.isDown(1) then
        drawing = true
        if startX == 0 and startY == 0 then
            startX, startY = mouseX, mouseY
            toX, toY = mouseX, mouseY
        end
    elseif not love.mouse.isDown(1) then
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
            if(toX == startX and toY == startY) then
                love.graphics.circle('fill', toX, toY, brushSize)
            end
            love.graphics.setColor(1, 1, 1, 1)
        end)
        startX, startY = toX, toY
    else
        toX, toY = 0,0
    end
    imgui.love.Update(dt)
    imgui.NewFrame()
end


function redraw()
    love.graphics.setColor(1, 1, 1, 1)

    canvas_seed:renderTo(function()
        love.graphics.setShader(seed_shader)
            love.graphics.draw(drawing_canvas)
        love.graphics.setShader()
    end)
    love.graphics.setBlendMode("alpha", "premultiplied")
    canvas_b:renderTo(function()
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.draw(canvas_seed)
    end)


    local stepsize = 1
    for i = 1, passes do
        stepsize = stepsize / 2
    end

    --love.graphics.setBlendMode("alpha", "premultiplied")
    local a_or_b = true
    while stepsize <= 1 do
        local a, b
        if a_or_b then
            a = canvas_a 
            b = canvas_b
        else
            a = canvas_b
            b = canvas_a
        end
        stepsize = stepsize * 2
        jfa_shader:send("stepsize", stepsize)
        love.graphics.setCanvas(a)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setShader(jfa_shader)
                love.graphics.draw(b)
            love.graphics.setShader()
        love.graphics.setCanvas()
        if a_or_b then canvas_jfa = a else canvas_jfa = b end
        a_or_b = not a_or_b
    end


    love.graphics.setCanvas(canvas_distance)
        love.graphics.setShader(distance_field_shader)
            love.graphics.draw(canvas_jfa)
        love.graphics.setShader()
    love.graphics.setCanvas()

    gi_shader:send("distanceTexture", canvas_distance)
    --gi_shader:send("drawingTexture", drawing_canvas)
    gi_shader:send("lastFrameTexture", canvas_previous)

    love.graphics.setCanvas(canvas_gi)
        love.graphics.setShader(gi_shader)
            love.graphics.draw(drawing_canvas)
        love.graphics.setShader()
    love.graphics.setCanvas()
    --Set previous
    love.graphics.setCanvas(canvas_previous)
        love.graphics.draw(canvas_gi)
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
    love.graphics.setBlendMode("alpha")
end


function love.wheelmoved(x, y)
    imgui.love.WheelMoved(x, y)
    if y > 0 then
        brushSize = brushSize + 4
    elseif y < 0 then
        brushSize = math.max(1, brushSize - 4)
    end
end

function love.mousereleased(x, y, button)
    imgui.love.MouseReleased(button)    
end

function love.mousemoved(x, y, dx, dy, istouch)
    imgui.love.MouseMoved(x, y, dx, dy, istouch)
end

function love.mousepressed(x, y, button)
    imgui.love.MousePressed(button)    
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

function reset(all)
    --Clear all canvases
    love.graphics.setCanvas(canvas_a)
        love.graphics.clear(0, 0, 0, 1)
    love.graphics.setCanvas()

    love.graphics.setCanvas(canvas_b)
        love.graphics.clear(0, 0, 0, 1)
    love.graphics.setCanvas()        

    love.graphics.setCanvas(canvas_jfa)
        love.graphics.clear(0, 0, 0, 1)
    love.graphics.setCanvas()        

    love.graphics.setCanvas(canvas_distance)
        love.graphics.clear(0, 0, 0, 1)
    love.graphics.setCanvas()        

    love.graphics.setCanvas(canvas_gi)
        love.graphics.clear(0, 0, 0, 1)
    love.graphics.setCanvas()      
    
    love.graphics.setCanvas(canvas_seed)
        love.graphics.clear(0, 0, 0, 1)
    love.graphics.setCanvas()
    if all then
        love.graphics.setCanvas(drawing_canvas)
            love.graphics.clear(0, 0, 0, 0)
        love.graphics.setCanvas()
    end
end

function love.keyreleased(key)
    imgui.love.KeyReleased(key)
end

function love.keypressed(key)
    imgui.love.KeyPressed(key)
    --Redraw when space is pressed
    if key == "space" then
        drawing_pass = (drawing_pass + 1) % 4
    end
    --Reset when R is pressed
    if key == "r" then
        reset(true)
    end
    --Increase passes when up arrow is pressed
    if key == "up" then
        passes = passes + 1
        reset()
    end
    --Decrease passes when down arrow is pressed
    if key == "down" then
        passes = math.max(1, passes - 1)
        reset()
    end
end