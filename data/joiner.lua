(function()
    repeat task.wait() until game:IsLoaded()

    local WebSocketURL = "ws://127.0.0.1:51948"

    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")

    local SAVE_FILE = "autojoiner_ui_pos.json"

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
    -- UI POSITION SAVE / LOAD
    -- =========================

    local function savePosition(pos)
        writefile(SAVE_FILE, HttpService:JSONEncode({
            x = pos.X.Scale,
            xo = pos.X.Offset,
            y = pos.Y.Scale,
            yo = pos.Y.Offset
        }))
    end

    local function loadPosition()
        if isfile(SAVE_FILE) then
            local d = HttpService:JSONDecode(readfile(SAVE_FILE))
            return UDim2.new(d.x, d.xo, d.y, d.yo)
        end
        return UDim2.fromScale(0.5, 0.5)
    end

    -- =========================
    -- SIMPLE UI
    -- =========================

    local gui = Instance.new("ScreenGui", CoreGui)
    gui.Name = "AutoJoinerUI"
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.fromOffset(220, 120)
    frame.Position = loadPosition()
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Active = true

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BackgroundTransparency = 1
    title.Text = "AutoJoiner"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.new(1, 1, 1)

    local startBtn = Instance.new("TextButton", frame)
    startBtn.Size = UDim2.fromOffset(180, 34)
    startBtn.Position = UDim2.fromOffset(20, 40)
    startBtn.Text = "START"
    startBtn.BackgroundColor3 = Color3.fromRGB(70, 180, 110)
    startBtn.TextColor3 = Color3.new(1,1,1)
    startBtn.BorderSizePixel = 0
    Instance.new("UICorner", startBtn)

    local stopBtn = Instance.new("TextButton", frame)
    stopBtn.Size = UDim2.fromOffset(180, 30)
    stopBtn.Position = UDim2.fromOffset(20, 78)
    stopBtn.Text = "STOP"
    stopBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
    stopBtn.TextColor3 = Color3.new(1,1,1)
    stopBtn.BorderSizePixel = 0
    Instance.new("UICorner", stopBtn)

    startBtn.MouseButton1Click:Connect(connect)
    stopBtn.MouseButton1Click:Connect(stop)

    -- =========================
    -- DRAG + SAVE POSITION
    -- =========================

    do
        local dragging = false
        local dragStart
        local startPos

        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
            end
        end)

        frame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
                savePosition(frame.Position)
            end
        end)

        RunService.RenderStepped:Connect(function()
            if dragging then
                local delta = UIS:GetMouseLocation() - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

end)()
