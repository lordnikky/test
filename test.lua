local drawing = Drawing or (getgenv and getgenv().Drawing)
if not drawing then
    print("No drawing library found")
else
    local circle = drawing.new("Circle")
    circle.Visible = true
    circle.Radius = 60
    circle.Position = Vector2.new(300, 300)
    circle.Color = Color3.fromRGB(255, 0, 0)
    circle.Filled = true
    task.wait(5)
    circle:Remove()
end
