local screen = Instance.new("ScreenGui")
screen.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 150)
frame.Position = UDim2.new(0.5, -150, 0.5, -75)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.Parent = screen

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0.5, 0)
label.Position = UDim2.new(0, 0, 0, 0)
label.Text = "Yes or No?"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.Parent = frame

local yesBtn = Instance.new("TextButton")
yesBtn.Size = UDim2.new(0.4, 0, 0.3, 0)
yesBtn.Position = UDim2.new(0.1, 0, 0.6, 0)
yesBtn.Text = "Yes"
yesBtn.Parent = frame

local noBtn = Instance.new("TextButton")
noBtn.Size = UDim2.new(0.4, 0, 0.3, 0)
noBtn.Position = UDim2.new(0.5, 0, 0.6, 0)
noBtn.Text = "No"
noBtn.Parent = frame

yesBtn.MouseButton1Click:Connect(function()
    print("Yes clicked")
    screen:Destroy()
end)

noBtn.MouseButton1Click:Connect(function()
    print("No clicked")
    screen:Destroy()
end)
