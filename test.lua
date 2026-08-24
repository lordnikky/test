loadstring([[
    print("outer start")
    local inner = loadstring("print('inner hello')")
    inner()
    print("outer end")
]])()
