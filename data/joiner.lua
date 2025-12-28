(function()
    repeat task.wait() until game:IsLoaded()

    local WebSocketURL = "ws://127.0.0.1:51948"

    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local UIS = game:GetService("UserInputService")

    local running = false
    local wsConnection = nil

    -- =========================
    -- BYPASSES (UNCHANGED)
    -- =========================

    hookfunction(isfunctionhooked, function(func)
        if func == tick then return false end
    end)

    local origTick = getfenv()["tick"]
    getfenv()["tick"] = function() return math.huge end
    hookfunction(tick, function() return math.huge end)

    for _, player in pairs(Players:GetPlayers()) do
        player.CharacterAdded:Connect(function()
            player:ClearCharacterAppearance()
        end)
        if player.Character then
            player:ClearCharacterAppearance()
        end
    end

    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            player:ClearCharacterAppearance()
        end)
    end)

    local function prints(str)
        print("[AutoJoiner]: " .. str)
    end

    -- =========================
    -- CORE LOGIC (UNCHANGED)
    -- =========================

    local function findTargetGui()
        for _, v in ipairs(CoreGui:GetDescendants()) do
            if v:IsA("ScreenGui") and v.Name == "ChilliLibUI" then
                return v.MainBase.Frame:GetChildren()[3]
                    :GetChildren()[6]
                    .Frame.ContentHolder
            end
        end
    end

    local function setJobIDText(targetGui, text)
        if not targetGui then return end
        local textBox = targetGui:GetChildren()[5].Frame.TextBox
        textBox.Text = text
        firesignal(textBox.FocusLost)
        prints("Textbox updated: " .. text)
        return origTick()
    end

    local function clickJoinButton(targetGui)
        return targetGui:GetChildren()[6].TextButton
    end

    local function bypass10M(jobId)
        task.defer(function()
            local targetGui = findTargetGui()
            local start = setJobIDText(targetGui, jobId)
            local button = clickJoinButton(targetGui)

            if button then
                getconnections(button.MouseButton1Click)[1]:Fire()
                prints(("Join clicked | delay: %.5fs"):format(origTick() - start))
            end
        end)
    end

    local function justJoin(script)
        local func, err = loadstring(script)
        if not func then
            return prints("Loadstring error: " .. err)
        end

        local ok, res = pcall(func)
        if not ok then
            prints("Runtime error: " .. res)
        end
    end

    -- =========================
    -- WEBSOCKET CONTROL
    -- =========================

    local function connect()
        if running then return end
        running = true

        task.spawn(function()
            while running do
                prints("Connecting to " .. WebSocketURL)
                local success, socket = pcall(WebSocket.connect, WebSocketURL)

                if success and socket then
                    prints("WebSocket connected")
                    wsConnection = socket

                    socket.OnMessage:Connect(function(msg)
                        if not running then return end

                        if not string.find(msg, "TeleportService") then
                            bypass10M(msg)
                        else
                            justJoin(msg)
                        end
                    end)

                    socket.OnClose:Connect(function()
                        if running then
                            prints("WebSocket closed, retrying...")
                            task.wait(1)
                        end
                    end)

                    break
                else
                    prints("Connection failed, retrying...")
                    task.wait(1)
                end
            end
        end)
    end

    local function stop()
        running = false
        if wsConnection then
            pcall(function()
                wsConnection:Close()
            end)
            wsConnection = nil
        end
        prints("AutoJoiner stopped")
    end

    -- =========================
    -- UI
    -- =========================

    local gui = Instance.new("ScreenGui", CoreGui)
    gui.Name = "AutoJoinerUI"
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromOffset(200, 110)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local startBtn = Instance.new("TextButton", frame)
    startBtn.Size = UDim2.fromOffset(160, 35)
    startBtn.Position = UDim2.fromOffset(20, 15)
    startBtn.Text = "START AUTOJOIN"
    startBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
    startBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", startBtn)

    local stopBtn = Instance.new("TextButton", frame)
    stopBtn.Size = UDim2.fromOffset(160, 35)
    stopBtn.Position = UDim2.fromOffset(20, 60)
    stopBtn.Text = "STOP"
    stopBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    stopBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", stopBtn)

    startBtn.MouseButton1Click:Connect(connect)
    stopBtn.MouseButton1Click:Connect(stop)

end)()
