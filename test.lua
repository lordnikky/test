print("1:", typeof(Drawing), typeof(Drawing and Drawing.new))
local ok, err = pcall(function()
    local circle = Drawing.new("Circle")
    print("2:", typeof(circle))
    circle.Visible = true
    circle.Radius = 60
    circle.Position = Vector2.new(300, 300)
    circle.Color = Color3.fromRGB(255, 0, 0)
    circle.Filled = true
    print("3: props set")
    task.wait(1)
    circle:Remove()
    print("4: removed")
end)
print("err:", err)
