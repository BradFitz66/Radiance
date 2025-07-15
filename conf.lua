function love.conf(t)
    t.window.width = 400
    t.window.height = 400
    t.window.title = "Radiance"
    t.window.resizable = true
    t.window.minwidth = 400
    t.window.minheight = 300
    t.window.vsync = false
    t.window.msaa = 32
    t.modules.joystick = false
    t.modules.physics = false
    t.console = true
end