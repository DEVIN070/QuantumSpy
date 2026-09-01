if getgenv().SimpleSpyExecuted and type(getgenv().SimpleSpyShutdown) == "function" then
    getgenv().SimpleSpyShutdown()
end

local realconfigs = {
    logcheckcaller = false,
    autoblock = false,
    funcEnabled = true,
    advancedinfo = false,
    --logreturnvalues = false,
    supersecretdevtoggle = false
}

local configs = newproxy(true)
local configsmetatable = getmetatable(configs)

configsmetatable.__index = function(self,index)
    return realconfigs[index]
end

local oth = syn and syn.oth
local unhook = oth and oth.unhook
local hook = oth and oth.hook

local lower = string.lower
local byte = string.byte
local round = math.round
local running = coroutine.running
local resume = coroutine.resume
local status = coroutine.status
local yield = coroutine.yield
local create = coroutine.create
local close = coroutine.close
local OldDebugId = game.GetDebugId
local info = debug.info

local IsA = game.IsA
local tostring = tostring
local tonumber = tonumber
local delay = task.delay
local spawn = task.spawn
local clear = table.clear
local clone = table.clone

local function blankfunction(...)
    return ...
end

local get_thread_identity = (syn and syn.get_thread_identity) or getidentity or getthreadidentity
local set_thread_identity = (syn and syn.set_thread_identity) or setidentity
local islclosure = islclosure or is_l_closure
local threadfuncs = (get_thread_identity and set_thread_identity and true) or false

local getinfo = getinfo or blankfunction
local getupvalues = getupvalues or debug.getupvalues or blankfunction
local getconstants = getconstants or debug.getconstants or blankfunction

local getcustomasset = getsynasset or getcustomasset
local getcallingscript = getcallingscript or blankfunction
local newcclosure = newcclosure or blankfunction
local clonefunction = clonefunction or blankfunction
local cloneref = cloneref or blankfunction
local request = request or syn and syn.request
local makewritable = makewriteable or function(tbl)
    setreadonly(tbl,false)
end
local makereadonly = makereadonly or function(tbl)
    setreadonly(tbl,true)
end
local isreadonly = isreadonly or table.isfrozen

local setclipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set) or function(...)
    return ErrorPrompt("Attempted to set clipboard: "..(...),true)
end

local hookmetamethod = hookmetamethod or (makewriteable and makereadonly and getrawmetatable) and function(obj: object, metamethod: string, func: Function)
    local old = getrawmetatable(obj)

    if hookfunction then
        return hookfunction(old[metamethod],func)
    else
        local oldmetamethod = old[metamethod]
        makewriteable(old)
        old[metamethod] = func
        makereadonly(old)
        return oldmetamethod
    end
end

local function Create(instance, properties, children)
    local obj = Instance.new(instance)

    for i, v in next, properties or {} do
        obj[i] = v
        for _, child in next, children or {} do
            child.Parent = obj;
        end
    end
    return obj;
end

local function SafeGetService(service)
    return cloneref(game:GetService(service))
end

local function Search(logtable,tbl)
    table.insert(logtable,tbl)
    
    for i,v in tbl do
        if type(v) == "table" then
            return table.find(logtable,v) ~= nil or Search(v)
        end
    end
end

local function IsCyclicTable(tbl)
	local checkedtables = {}

    local function SearchTable(tbl)
        table.insert(checkedtables,tbl)
        
        for i,v in next, tbl do -- Stupid mistake on my part thanks 59it for pointing it out
            if type(v) == "table" then
                return table.find(checkedtables,v) and true or SearchTable(v)
            end
        end
    end

	return SearchTable(tbl)
end

local function deepclone(args: table, copies: table): table
    local copy = nil
    copies = copies or {}

    if type(args) == 'table' then
        if copies[args] then
            copy = copies[args]
        else
            copy = {}
            copies[args] = copy
            for i, v in next, args do
                copy[deepclone(i, copies)] = deepclone(v, copies)
            end
        end
    elseif typeof(args) == "Instance" then
        copy = cloneref(args)
    else
        copy = args
    end
    return copy
end

local function rawtostring(userdata)
	if type(userdata) == "table" or typeof(userdata) == "userdata" then
		local rawmetatable = getrawmetatable(userdata)
		local cachedstring = rawmetatable and rawget(rawmetatable, "__tostring")

		if cachedstring then
            local wasreadonly = isreadonly(rawmetatable)
            if wasreadonly then
                makewritable(rawmetatable)
            end
			rawset(rawmetatable, "__tostring", nil)
			local safestring = tostring(userdata)
			rawset(rawmetatable, "__tostring", cachedstring)
            if wasreadonly then
                makereadonly(rawmetatable)
            end
			return safestring
		end
	end
	return tostring(userdata)
end

local CoreGui = SafeGetService("CoreGui")
local Players = SafeGetService("Players")
local RunService = SafeGetService("RunService")
local UserInputService = SafeGetService("UserInputService")
local TweenService = SafeGetService("TweenService")
local ContentProvider = SafeGetService("ContentProvider")
local TextService = SafeGetService("TextService")
local http = SafeGetService("HttpService")
local GuiInset = game:GetService("GuiService"):GetGuiInset() :: Vector2 -- pulled from rewrite

local function jsone(str) return http:JSONEncode(str) end
local function jsond(str)
    local suc,err = pcall(http.JSONDecode,http,str)
    return suc and err or suc
end

function ErrorPrompt(Message,state)
    if getrenv then
        local ErrorPrompt = getrenv().require(CoreGui:WaitForChild("RobloxGui"):WaitForChild("Modules"):WaitForChild("ErrorPrompt")) -- File can be located in your roblox folder (C:\Users\%Username%\AppData\Local\Roblox\Versions\whateverversionitis\ExtraContent\scripts\CoreScripts\Modules)
        local prompt = ErrorPrompt.new("Default",{HideErrorCode = true})
        local ErrorStoarge = Create("ScreenGui",{Parent = CoreGui,ResetOnSpawn = false})
        local thread = state and running()
        prompt:setParent(ErrorStoarge)
        prompt:setErrorTitle("Simple Spy V3 Error")
        prompt:updateButtons({{
            Text = "Proceed",
            Callback = function()
                prompt:_close()
                ErrorStoarge:Destroy()
                if thread then
                    resume(thread)
                end
            end,
            Primary = true
        }}, 'Default')
        prompt:_open(Message)
        if thread then
            yield(thread)
        end
    else
        warn(Message)
    end
end

local Highlight = (isfile and loadfile and isfile("Highlight.lua") and loadfile("Highlight.lua")()) or loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/SimpleSpy/main/Highlight.lua"))()

local Quantum = {
    Background = Color3.fromRGB(11, 13, 16),
    Panel = Color3.fromRGB(16, 18, 21),
    Surface = Color3.fromRGB(19, 22, 26),
    SurfaceRaised = Color3.fromRGB(17, 20, 25),
    InnerSurface = Color3.fromRGB(12, 15, 19),
    Hover = Color3.fromRGB(24, 28, 33),
    Selected = Color3.fromRGB(26, 33, 41),
    Editor = Color3.fromRGB(8, 10, 13),
    Border = Color3.fromRGB(96, 102, 111),
    ButtonBorder = Color3.fromRGB(81, 87, 96),
    BorderSubtle = Color3.fromRGB(66, 72, 81),
    Accent = Color3.fromRGB(82, 168, 255),
    Cyan = Color3.fromRGB(64, 207, 190),
    Violet = Color3.fromRGB(149, 119, 255),
    Text = Color3.fromRGB(215, 218, 222),
    TextSecondary = Color3.fromRGB(158, 164, 173),
    TextMuted = Color3.fromRGB(102, 109, 119),
    TextVeryMuted = Color3.fromRGB(65, 72, 82),
    Success = Color3.fromRGB(63, 185, 80),
    Warning = Color3.fromRGB(210, 153, 34),
    Error = Color3.fromRGB(248, 81, 73),
}

local HEADER_HEIGHT = 64
local STATUS_HEIGHT = 32
local SIDEBAR_WIDTH = 270
local TOOLBAR_HEIGHT = 103
local MINIMUM_WIDTH = 460
local MINIMUM_HEIGHT = 280
local MAXIMUM_WIDTH = 1200
local MAXIMUM_HEIGHT = 760

local function getMaximumWindowSize(viewportSize)
    return Vector2.new(
        math.max(MINIMUM_WIDTH, math.min(MAXIMUM_WIDTH, math.round(viewportSize.X - 40))),
        math.max(MINIMUM_HEIGHT, math.min(MAXIMUM_HEIGHT, math.round(viewportSize.Y - GuiInset.Y - 40)))
    )
end

local function quantumTween(object, properties, duration, style, direction)
    local tweenObject = TweenService:Create(object, TweenInfo.new(duration or 0.12, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), properties)
    tweenObject:Play()
    return tweenObject
end

local function addCorner(object, radius)
    return Create("UICorner", {Parent = object, CornerRadius = UDim.new(0, radius or 3)})
end

local function addStroke(object, color, transparency)
    return Create("UIStroke", {Parent = object, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = color or Quantum.Border, Transparency = transparency or 0, Thickness = 1})
end

local PixelBorder = {}

function PixelBorder.create(object, color, zIndex)
    local borderColor = color or Quantum.Border
    local layer = zIndex or 3
    local edges = {
        Create("Frame", {Name = "BorderTop", Parent = object, BackgroundColor3 = borderColor, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 1), ZIndex = layer}),
        Create("Frame", {Name = "BorderBottom", Parent = object, BackgroundColor3 = borderColor, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), ZIndex = layer}),
        Create("Frame", {Name = "BorderLeft", Parent = object, BackgroundColor3 = borderColor, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = layer}),
        Create("Frame", {Name = "BorderRight", Parent = object, BackgroundColor3 = borderColor, BorderSizePixel = 0, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = layer})
    }
    return edges
end

function PixelBorder.fieldset(object, legendX, titleWidth, color, zIndex)
    local borderColor = color or Quantum.Border
    local layer = zIndex or 3
    return {
        Create("Frame", {Name = "BorderTopLeft", Parent = object, BackgroundColor3 = borderColor, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(legendX - 4, 1), ZIndex = layer}),
        Create("Frame", {Name = "BorderTopRight", Parent = object, BackgroundColor3 = borderColor, BorderSizePixel = 0, Position = UDim2.fromOffset(legendX + titleWidth, 0), Size = UDim2.new(1, -legendX - titleWidth, 0, 1), ZIndex = layer}),
        Create("Frame", {Name = "BorderBottom", Parent = object, BackgroundColor3 = borderColor, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), ZIndex = layer}),
        Create("Frame", {Name = "BorderLeft", Parent = object, BackgroundColor3 = borderColor, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = layer}),
        Create("Frame", {Name = "BorderRight", Parent = object, BackgroundColor3 = borderColor, BorderSizePixel = 0, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = layer})
    }
end

function PixelBorder.setColor(edges, color, duration)
    for _, edge in next, edges do
        if duration then
            quantumTween(edge, {BackgroundColor3 = color}, duration)
        else
            edge.BackgroundColor3 = color
        end
    end
end

local function styleButton(button, normalColor, hoverColor, pressedColor)
    button.AutoButtonColor = false
    button.MouseEnter:Connect(function()
        quantumTween(button, {BackgroundColor3 = hoverColor or Quantum.Hover}, 0.1)
    end)
    button.MouseLeave:Connect(function()
        quantumTween(button, {BackgroundColor3 = normalColor or Quantum.SurfaceRaised}, 0.1)
    end)
    button.MouseButton1Down:Connect(function()
        quantumTween(button, {BackgroundColor3 = pressedColor or Quantum.Panel}, 0.07)
    end)
    button.MouseButton1Up:Connect(function()
        quantumTween(button, {BackgroundColor3 = hoverColor or Quantum.Hover}, 0.08)
    end)
end

local function createSection(parent, name, position, size)
    local section = Create("Frame", {Name = name .. "Section", Parent = parent, BackgroundColor3 = Quantum.Panel, BorderSizePixel = 0, Position = position, Size = size})
    local titleWidth = math.max(52, #name * 7 + 12)
    local legendX = 12
    PixelBorder.fieldset(section, legendX, titleWidth, Quantum.Border, 3)
    local sectionLabel = Create("TextLabel", {Name = "SectionLabel", Parent = section, BackgroundColor3 = section.BackgroundColor3, BorderSizePixel = 0, Position = UDim2.fromOffset(legendX, -8), Size = UDim2.fromOffset(titleWidth, 16), ZIndex = 5, Font = Enum.Font.Code, Text = lower(name), TextColor3 = Quantum.TextSecondary, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center})
    section:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
        if sectionLabel.Parent then
            sectionLabel.BackgroundColor3 = section.BackgroundColor3
        end
    end)
    return section
end

local function createInspectorRow(parent, label, valueColor, layoutOrder)
    local row = Create("Frame", {Parent = parent, BackgroundTransparency = 1, LayoutOrder = layoutOrder or 0, Size = UDim2.new(1, 0, 0, 9), ZIndex = 4})
    Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Size = UDim2.fromOffset(84, 9), Font = Enum.Font.Code, Text = label, TextColor3 = Quantum.TextMuted, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5})
    return Create("TextLabel", {Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(84, 0), Size = UDim2.new(1, -84, 0, 9), Font = Enum.Font.Code, Text = "—", TextColor3 = valueColor or Quantum.Text, TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5})
end

local function createToolbarButton(parent, name, isPrimary)
    local template = Create("Frame", {Name = "FunctionTemplate", Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28)})
    local button = Create("TextButton", {Name = "Button", Parent = template, BackgroundColor3 = Quantum.SurfaceRaised, BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), AutoButtonColor = false, Font = Enum.Font.Code, Text = lower(name), TextColor3 = Quantum.TextSecondary, TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4})
    addCorner(button, 2)
    local stroke = addStroke(button, isPrimary and Quantum.Accent or Quantum.ButtonBorder, 0)
    styleButton(button, Quantum.SurfaceRaised, Quantum.Hover, Quantum.Panel)
    return template, button, button, stroke
end

local function createQuantumUI()
local SimpleSpy3 = Create("ScreenGui",{ResetOnSpawn = false})
local Storage = Create("Folder",{})
local Background = Create("CanvasGroup",{Name = "Frame",Parent = SimpleSpy3,BackgroundColor3 = Quantum.Background,BorderSizePixel = 0,GroupTransparency = 1,Position = UDim2.new(0, 320, 0, 130),Size = UDim2.new(0, 980, 0, 620),ClipsDescendants = true,ZIndex = 2})
local WindowShadow = Create("ImageLabel",{Name = "WindowShadow",Parent = SimpleSpy3,BackgroundTransparency = 1,Image = "rbxassetid://6015897843",ImageColor3 = Color3.new(0, 0, 0),ImageTransparency = 1,ScaleType = Enum.ScaleType.Slice,SliceCenter = Rect.new(49, 49, 450, 450),ZIndex = 1})
local function syncWindowShadow()
    WindowShadow.Position = UDim2.new(Background.Position.X.Scale, Background.Position.X.Offset - 12, Background.Position.Y.Scale, Background.Position.Y.Offset - 12)
    WindowShadow.Size = UDim2.new(Background.Size.X.Scale, Background.Size.X.Offset + 24, Background.Size.Y.Scale, Background.Size.Y.Offset + 24)
end
Background:GetPropertyChangedSignal("Position"):Connect(syncWindowShadow)
Background:GetPropertyChangedSignal("Size"):Connect(syncWindowShadow)
syncWindowShadow()
local BackgroundScale = Create("UIScale",{Parent = Background,Scale = 1})
addCorner(Background, 4)
PixelBorder.create(Background, Quantum.Border, 7)
local BackgroundConstraint = Create("UISizeConstraint",{Parent = Background,MinSize = Vector2.new(MINIMUM_WIDTH, MINIMUM_HEIGHT),MaxSize = Vector2.new(MAXIMUM_WIDTH, MAXIMUM_HEIGHT)})
local AccentLine = Create("Frame",{Name = "AccentLine",Parent = Background,BackgroundColor3 = Quantum.Accent,BorderSizePixel = 0,Position = UDim2.fromOffset(1, 1),Size = UDim2.new(1, -2, 0, 1),ZIndex = 8})

local TopBar = Create("Frame",{Name = "HeaderPane",Parent = Background,BackgroundColor3 = Quantum.Panel,BorderSizePixel = 0,Position = UDim2.fromOffset(9, 9),Size = UDim2.new(1, -18, 0, HEADER_HEIGHT - 20),ZIndex = 4})
PixelBorder.create(TopBar, Quantum.Border, 5)
local HeaderDivider = Create("Frame",{Name = "HeaderDivider",Parent = Background,BackgroundColor3 = Quantum.Border,BorderSizePixel = 0,Position = UDim2.new(0, 9, 0, HEADER_HEIGHT - 1),Size = UDim2.new(1, -18, 0, 1),ZIndex = 4})
local BrandMark = Create("TextLabel",{Name = "QuantumMark",Parent = TopBar,BackgroundTransparency = 1,Position = UDim2.fromOffset(13, 5),Size = UDim2.fromOffset(20, 20),Font = Enum.Font.Code,Text = "◇",TextColor3 = Quantum.Accent,TextSize = 18,ZIndex = 6})
local Simple = Create("TextButton",{Parent = TopBar,BackgroundTransparency = 1,AutoButtonColor = false,Position = UDim2.fromOffset(39, 2),Size = UDim2.fromOffset(132, 24),Font = Enum.Font.Code,Text = "SIMPLESPY",TextColor3 = Quantum.Text,TextSize = 16,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 6})
local Subtitle = Create("TextLabel",{Name = "Subtitle",Parent = TopBar,BackgroundTransparency = 1,Position = UDim2.fromOffset(40, 27),Size = UDim2.fromOffset(250, 15),Font = Enum.Font.Code,Text = "quantum / remote inspector",TextColor3 = Quantum.TextSecondary,TextSize = 10,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 6})
local SpyStatusDot = Create("Frame",{Name = "SpyStatusDot",Parent = TopBar,BackgroundColor3 = Quantum.Cyan,BorderSizePixel = 0,Position = UDim2.new(1, -159, 0, 22),Size = UDim2.fromOffset(5, 5),ZIndex = 6})
addCorner(SpyStatusDot, 3)
local SpyStatusText = Create("TextLabel",{Name = "SpyStatusText",Parent = TopBar,BackgroundTransparency = 1,Position = UDim2.new(1, -150, 0, 16),Size = UDim2.fromOffset(48, 18),Font = Enum.Font.Code,Text = "ACTIVE",TextColor3 = Quantum.Text,TextSize = 10,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 6})
local CloseButton = Create("TextButton",{Parent = TopBar,BackgroundColor3 = Quantum.Panel,BorderSizePixel = 0,Position = UDim2.new(1, -35, 0, 11),Size = UDim2.fromOffset(25, 25),Font = Enum.Font.Code,Text = "×",TextColor3 = Quantum.Text,TextSize = 16,ZIndex = 6})
local MaximizeButton = Create("TextButton",{Parent = TopBar,BackgroundColor3 = Quantum.Panel,BorderSizePixel = 0,Position = UDim2.new(1, -65, 0, 11),Size = UDim2.fromOffset(25, 25),Font = Enum.Font.Code,Text = "□",TextColor3 = Quantum.Text,TextSize = 13,ZIndex = 6})
local MinimizeButton = Create("TextButton",{Parent = TopBar,BackgroundColor3 = Quantum.Panel,BorderSizePixel = 0,Position = UDim2.new(1, -95, 0, 11),Size = UDim2.fromOffset(25, 25),Font = Enum.Font.Code,Text = "–",TextColor3 = Quantum.Text,TextSize = 14,ZIndex = 6})
local SidebarToggle = Create("TextButton",{Name = "SidebarToggle",Parent = TopBar,BackgroundColor3 = Quantum.Panel,BorderSizePixel = 0,Position = UDim2.fromOffset(8, 5),Size = UDim2.fromOffset(24, 24),Font = Enum.Font.Code,Text = "≡",TextColor3 = Quantum.TextSecondary,TextSize = 16,ZIndex = 7,Visible = false,AutoButtonColor = false})
addCorner(SidebarToggle, 2)
styleButton(SidebarToggle, Quantum.Panel, Quantum.Hover, Quantum.Surface)
for _, button in next, {CloseButton, MaximizeButton, MinimizeButton} do
    addCorner(button, 2)
    styleButton(button, Quantum.Panel, Quantum.Hover, Quantum.Surface)
end

local LeftPanel = Create("CanvasGroup",{Name = "Frame",Parent = Background,BackgroundColor3 = Quantum.Background,BorderSizePixel = 0,Position = UDim2.fromOffset(0, HEADER_HEIGHT),Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -HEADER_HEIGHT - STATUS_HEIGHT)})
local FilterSection = createSection(LeftPanel, "filter", UDim2.fromOffset(9, 12), UDim2.new(1, -19, 0, 42))
local SearchFrame = Create("Frame",{Name = "Filter",Parent = FilterSection,BackgroundColor3 = Quantum.InnerSurface,BorderSizePixel = 0,Position = UDim2.fromOffset(7, 9),Size = UDim2.new(1, -14, 1, -16),ZIndex = 6})
addCorner(SearchFrame, 2)
local SearchBorder = PixelBorder.create(SearchFrame, Quantum.Border, 7)
local SearchGlyph = Create("TextLabel",{Parent = SearchFrame,BackgroundTransparency = 1,Position = UDim2.fromOffset(7, 0),Size = UDim2.new(0, 15, 1, 0),Font = Enum.Font.Code,Text = ">",TextColor3 = Quantum.Accent,TextSize = 12,TextYAlignment = Enum.TextYAlignment.Center,ZIndex = 7})
local FilterInput = Create("TextBox",{Name = "FilterInput",Parent = SearchFrame,BackgroundTransparency = 1,ClearTextOnFocus = false,PlaceholderText = "search remotes...",PlaceholderColor3 = Quantum.TextMuted,Position = UDim2.fromOffset(22, 0),Size = UDim2.new(1, -58, 1, 0),Font = Enum.Font.Code,Text = "",TextColor3 = Quantum.Text,TextSize = 11,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 7})
local FilterShortcut = Create("TextLabel",{Parent = SearchFrame,BackgroundTransparency = 1,Position = UDim2.new(1, -36, 0, 0),Size = UDim2.new(0, 31, 1, 0),Font = Enum.Font.Code,Text = "^F",TextColor3 = Quantum.TextVeryMuted,TextSize = 9,TextYAlignment = Enum.TextYAlignment.Center,ZIndex = 7})
FilterInput.Focused:Connect(function() PixelBorder.setColor(SearchBorder, Quantum.Accent, 0.12) end)
FilterInput.FocusLost:Connect(function() PixelBorder.setColor(SearchBorder, Quantum.Border, 0.12) end)
local RemoteStreamSection = createSection(LeftPanel, "remote stream", UDim2.fromOffset(9, 65), UDim2.new(1, -19, 1, -75))
local RemoteCountLabel = Create("TextLabel",{Name = "RemoteCount",Parent = RemoteStreamSection,BackgroundColor3 = RemoteStreamSection.BackgroundColor3,BorderSizePixel = 0,Position = UDim2.new(1, -72, 0, -8),Size = UDim2.fromOffset(62, 16),ZIndex = 6,Font = Enum.Font.Code,Text = "0 calls",TextColor3 = Quantum.TextMuted,TextSize = 9,TextXAlignment = Enum.TextXAlignment.Right})
local LogSurface = Create("Frame",{Name = "RemoteListSurface",Parent = RemoteStreamSection,BackgroundColor3 = Quantum.InnerSurface,BorderSizePixel = 0,Position = UDim2.fromOffset(7, 10),Size = UDim2.new(1, -14, 1, -18),ZIndex = 2})
PixelBorder.create(LogSurface, Quantum.BorderSubtle, 3)
local LogList = Create("ScrollingFrame",{Parent = LogSurface,Active = true,BackgroundColor3 = Quantum.InnerSurface,BackgroundTransparency = 0,BorderSizePixel = 0,Position = UDim2.fromOffset(1, 1),Size = UDim2.new(1, -2, 1, -2),CanvasSize = UDim2.new(),ScrollBarThickness = 2,ScrollBarImageColor3 = Quantum.TextVeryMuted,ZIndex = 2})
local UIListLayout = Create("UIListLayout",{Parent = LogList,HorizontalAlignment = Enum.HorizontalAlignment.Center,SortOrder = Enum.SortOrder.LayoutOrder,Padding = UDim.new(0, 2)})

local RightPanel = Create("CanvasGroup",{Name = "Frame",Parent = Background,BackgroundColor3 = Quantum.Background,BorderSizePixel = 0,Position = UDim2.fromOffset(SIDEBAR_WIDTH, HEADER_HEIGHT),Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -HEADER_HEIGHT - STATUS_HEIGHT)})
local InspectorTabs = Create("Frame",{Name = "InspectorTabs",Parent = RightPanel,BackgroundColor3 = Quantum.Panel,BorderSizePixel = 0,Position = UDim2.fromOffset(9, 4),Size = UDim2.new(1, -19, 0, 26),Visible = false,ZIndex = 8})
PixelBorder.create(InspectorTabs, Quantum.BorderSubtle, 9)
local InspectorTabButtons = {}
local InspectorTabAccents = {}
for index, tabName in next, {"Remote", "Args", "Code"} do
    local tabButton = Create("TextButton",{Name = tabName,Parent = InspectorTabs,BackgroundColor3 = Quantum.Panel,BorderSizePixel = 0,Position = UDim2.fromOffset((index - 1) * 100, 1),Size = UDim2.fromOffset(100, 24),AutoButtonColor = false,Font = Enum.Font.Code,Text = string.upper(tabName),TextColor3 = Quantum.TextMuted,TextSize = 10,ZIndex = 10})
    local tabAccent = Create("Frame",{Parent = tabButton,BackgroundColor3 = Quantum.Accent,BackgroundTransparency = 1,BorderSizePixel = 0,Position = UDim2.new(0, 4, 1, -2),Size = UDim2.new(1, -8, 0, 1),ZIndex = 11})
    InspectorTabButtons[tabName] = tabButton
    InspectorTabAccents[tabName] = tabAccent
end
local InspectorHeader = createSection(RightPanel, "remote", UDim2.fromOffset(9, 8), UDim2.new(1, -19, 0, 74))
local InspectorSelection = Create("TextLabel",{Name = "Selection",Parent = InspectorHeader,BackgroundColor3 = InspectorHeader.BackgroundColor3,BorderSizePixel = 0,Position = UDim2.new(1, -147, 0, -5),Size = UDim2.fromOffset(134, 13),ZIndex = 6,Font = Enum.Font.Code,Text = "no remote selected",TextColor3 = Quantum.TextMuted,TextSize = 9,TextTruncate = Enum.TextTruncate.AtEnd,TextXAlignment = Enum.TextXAlignment.Right})
local RemoteContent = Create("Frame",{Name = "RemoteContent",Parent = InspectorHeader,BackgroundColor3 = Quantum.InnerSurface,BorderSizePixel = 0,Position = UDim2.fromOffset(8, 8),Size = UDim2.new(1, -16, 1, -16),ZIndex = 2})
PixelBorder.create(RemoteContent, Quantum.BorderSubtle, 3)
local InspectorProperties = Create("Frame",{Parent = RemoteContent,BackgroundTransparency = 1,Position = UDim2.fromOffset(8, 2),Size = UDim2.new(1, -16, 1, -4),ZIndex = 3})
Create("UIListLayout",{Parent = InspectorProperties,SortOrder = Enum.SortOrder.LayoutOrder})
local RemoteNameValue = createInspectorRow(InspectorProperties, "NAME", Quantum.TextSecondary, 1)
local RemoteTypeValue = createInspectorRow(InspectorProperties, "CLASS", Quantum.TextSecondary, 2)
local RemoteMethodValue = createInspectorRow(InspectorProperties, "METHOD", Quantum.TextSecondary, 3)
local RemoteCallsValue = createInspectorRow(InspectorProperties, "CALLS", Quantum.TextSecondary, 4)
local RemotePathValue = createInspectorRow(InspectorProperties, "PATH", Quantum.TextSecondary, 5)
local RemoteScriptValue = createInspectorRow(InspectorProperties, "SCRIPT", Quantum.TextSecondary, 6)
RemoteCallsValue.Text = "0"

local ArgumentsSection = createSection(RightPanel, "arguments", UDim2.fromOffset(9, 90), UDim2.new(1, -19, 0, 116))
local ArgumentsSurface = Create("Frame",{Name = "ArgumentsSurface",Parent = ArgumentsSection,BackgroundColor3 = Quantum.InnerSurface,BorderSizePixel = 0,Position = UDim2.fromOffset(8, 8),Size = UDim2.new(1, -16, 1, -16),ZIndex = 2})
PixelBorder.create(ArgumentsSurface, Quantum.BorderSubtle, 3)
local ArgumentsScroll = Create("ScrollingFrame",{Parent = ArgumentsSurface,Active = true,AutomaticCanvasSize = Enum.AutomaticSize.Y,BackgroundColor3 = Quantum.InnerSurface,BackgroundTransparency = 0,BorderSizePixel = 0,Position = UDim2.fromOffset(1, 1),Size = UDim2.new(1, -2, 1, -2),CanvasSize = UDim2.new(),ScrollBarThickness = 2,ScrollBarImageColor3 = Quantum.TextVeryMuted,ZIndex = 2})
local ArgumentsText = Create("TextLabel",{Name = "ArgumentsEmpty",Parent = ArgumentsScroll,BackgroundTransparency = 1,LayoutOrder = 0,Size = UDim2.new(1, -12, 0, 18),Font = Enum.Font.Code,Text = "no arguments",TextColor3 = Quantum.TextMuted,TextSize = 10,TextTruncate = Enum.TextTruncate.AtEnd,TextXAlignment = Enum.TextXAlignment.Left,TextYAlignment = Enum.TextYAlignment.Center,ZIndex = 4})
Create("UIListLayout",{Parent = ArgumentsScroll,HorizontalAlignment = Enum.HorizontalAlignment.Left,SortOrder = Enum.SortOrder.LayoutOrder,Padding = UDim.new(0, 1)})
Create("UIPadding",{Parent = ArgumentsScroll,PaddingLeft = UDim.new(0, 6),PaddingRight = UDim.new(0, 6),PaddingTop = UDim.new(0, 5),PaddingBottom = UDim.new(0, 5)})

local CodeSection = createSection(RightPanel, "generated code", UDim2.fromOffset(9, 214), UDim2.new(1, -19, 1, -214 - TOOLBAR_HEIGHT))
local CopyCodeButton = Create("TextButton",{Name = "CopyCode",Parent = CodeSection,BackgroundColor3 = Quantum.InnerSurface,BorderSizePixel = 0,Position = UDim2.new(1, -78, 0, 9),Size = UDim2.fromOffset(66, 17),ZIndex = 6,AutoButtonColor = false,Font = Enum.Font.Code,Text = "copy code",TextColor3 = Quantum.TextSecondary,TextSize = 9})
addCorner(CopyCodeButton, 2)
local CopyCodeStroke = addStroke(CopyCodeButton, Quantum.ButtonBorder)
styleButton(CopyCodeButton, Quantum.InnerSurface, Quantum.Hover, Quantum.Panel)
CopyCodeButton.MouseEnter:Connect(function() quantumTween(CopyCodeStroke, {Color = Quantum.Border}, 0.1) end)
CopyCodeButton.MouseLeave:Connect(function() quantumTween(CopyCodeStroke, {Color = Quantum.ButtonBorder}, 0.1) end)
local CodeSurface = Create("Frame",{Name = "EditorSurface",Parent = CodeSection,BackgroundColor3 = Quantum.Editor,BorderSizePixel = 0,Position = UDim2.fromOffset(8, 29),Size = UDim2.new(1, -16, 1, -37),ZIndex = 2})
PixelBorder.create(CodeSurface, Quantum.BorderSubtle, 3)
local CodeBox = Create("Frame",{Parent = CodeSurface,BackgroundColor3 = Quantum.Editor,BorderSizePixel = 0,Position = UDim2.fromOffset(1, 1),Size = UDim2.new(1, -2, 1, -2),ClipsDescendants = true,ZIndex = 4})

local ActionsSection = createSection(RightPanel, "actions", UDim2.new(0, 9, 1, -95), UDim2.new(1, -19, 0, TOOLBAR_HEIGHT - 10))
local ActionsContent = Create("Frame",{Name = "ActionsContent",Parent = ActionsSection,BackgroundColor3 = Quantum.InnerSurface,BorderSizePixel = 0,Position = UDim2.fromOffset(8, 9),Size = UDim2.new(1, -16, 1, -17)})
PixelBorder.create(ActionsContent, Quantum.BorderSubtle, 3)
local ActionsOverflowButton = Create("TextButton",{Name = "ActionsOverflow",Parent = ActionsContent,BackgroundColor3 = Quantum.SurfaceRaised,BorderSizePixel = 0,Position = UDim2.new(1, -31, 0, 1),Size = UDim2.fromOffset(30, 28),Visible = false,AutoButtonColor = false,Font = Enum.Font.Code,Text = "...",TextColor3 = Quantum.TextSecondary,TextSize = 10,ZIndex = 7})
addCorner(ActionsOverflowButton, 2)
addStroke(ActionsOverflowButton, Quantum.ButtonBorder)
styleButton(ActionsOverflowButton, Quantum.SurfaceRaised, Quantum.Hover, Quantum.Panel)
local ScrollingFrame = Create("ScrollingFrame",{Parent = ActionsContent,Active = true,BackgroundTransparency = 1,BorderSizePixel = 0,Position = UDim2.fromOffset(3, 3),Size = UDim2.new(1, -6, 1, -6),CanvasSize = UDim2.new(),ScrollingDirection = Enum.ScrollingDirection.Y,ScrollBarThickness = 2,ScrollBarImageColor3 = Quantum.TextVeryMuted})
local UIGridLayout = Create("UIGridLayout",{Parent = ScrollingFrame,FillDirection = Enum.FillDirection.Horizontal,FillDirectionMaxCells = 5,HorizontalAlignment = Enum.HorizontalAlignment.Left,VerticalAlignment = Enum.VerticalAlignment.Top,SortOrder = Enum.SortOrder.LayoutOrder,CellPadding = UDim2.fromOffset(6, 6),CellSize = UDim2.new(0.2, -6, 0, 28)})
local ActionsPadding = Create("UIPadding",{Parent = ScrollingFrame,PaddingLeft = UDim.new(0, 3),PaddingRight = UDim.new(0, 3),PaddingTop = UDim.new(0, 3),PaddingBottom = UDim.new(0, 3)})

local StatusBar = Create("CanvasGroup",{Name = "StatusBar",Parent = Background,BackgroundColor3 = Quantum.SurfaceRaised,BorderSizePixel = 0,Position = UDim2.new(0, 9, 1, -STATUS_HEIGHT + 4),Size = UDim2.new(1, -18, 0, STATUS_HEIGHT - 8),ZIndex = 4})
PixelBorder.create(StatusBar, Quantum.Border, 5)
local StatusDot = Create("Frame",{Parent = StatusBar,BackgroundColor3 = Quantum.Cyan,BorderSizePixel = 0,Position = UDim2.fromOffset(12, 9),Size = UDim2.fromOffset(6, 6),ZIndex = 6})
addCorner(StatusDot, 3)
local StatusVersionText = Create("TextLabel",{Parent = StatusBar,BackgroundTransparency = 1,Position = UDim2.fromOffset(24, 3),Size = UDim2.fromOffset(110, 18),Font = Enum.Font.Code,Text = "quantum@1.0.0",TextColor3 = Quantum.TextSecondary,TextSize = 10,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 6})
local StatusSeparatorOne = Create("TextLabel",{Parent = StatusBar,BackgroundTransparency = 1,Position = UDim2.fromOffset(136, 3),Size = UDim2.fromOffset(10, 18),Font = Enum.Font.Code,Text = "|",TextColor3 = Quantum.TextVeryMuted,TextSize = 10,ZIndex = 6})
local StatusStateText = Create("TextLabel",{Parent = StatusBar,BackgroundTransparency = 1,Position = UDim2.fromOffset(150, 3),Size = UDim2.fromOffset(86, 18),Font = Enum.Font.Code,Text = "spy:active",TextColor3 = Quantum.TextMuted,TextSize = 10,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 6})
local StatusSeparatorTwo = Create("TextLabel",{Parent = StatusBar,BackgroundTransparency = 1,Position = UDim2.fromOffset(238, 3),Size = UDim2.fromOffset(10, 18),Font = Enum.Font.Code,Text = "|",TextColor3 = Quantum.TextVeryMuted,TextSize = 10,ZIndex = 6})
local StatusCallsText = Create("TextLabel",{Parent = StatusBar,BackgroundTransparency = 1,Position = UDim2.fromOffset(252, 3),Size = UDim2.fromOffset(70, 18),Font = Enum.Font.Code,Text = "calls:0",TextColor3 = Quantum.TextMuted,TextSize = 10,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 6})
local StatusSeparatorThree = Create("TextLabel",{Parent = StatusBar,BackgroundTransparency = 1,Position = UDim2.fromOffset(324, 3),Size = UDim2.fromOffset(10, 18),Font = Enum.Font.Code,Text = "|",TextColor3 = Quantum.TextVeryMuted,TextSize = 10,ZIndex = 6})
local StatusRemotesText = Create("TextLabel",{Parent = StatusBar,BackgroundTransparency = 1,Position = UDim2.fromOffset(338, 3),Size = UDim2.fromOffset(92, 18),Font = Enum.Font.Code,Text = "remotes:0",TextColor3 = Quantum.TextMuted,TextSize = 10,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 6})
local ReadyText = Create("TextLabel",{Parent = StatusBar,BackgroundTransparency = 1,Position = UDim2.new(1, -66, 0, 3),Size = UDim2.fromOffset(54, 18),Font = Enum.Font.Code,Text = "ready",TextColor3 = Quantum.Cyan,TextSize = 10,TextXAlignment = Enum.TextXAlignment.Right,ZIndex = 6})

local Layout = {SidebarWidth = SIDEBAR_WIDTH, DividerDragging = false, Mode = "Full", UseInspectorTabs = false, InspectorTab = "Remote", SidebarCollapsed = false, SidebarUserOverride = false, WasAutoCollapseWidth = false, CompactRows = false, CompactActions = false, CompactMetadata = false, OverflowOrder = 0}
local Resize = {Active = false, Direction = nil, StartMouse = nil, StartPosition = nil, StartSize = nil}
local PaneDivider = Create("TextButton",{Name = "PaneDivider",Parent = Background,BackgroundTransparency = 1,BorderSizePixel = 0,Position = UDim2.fromOffset(SIDEBAR_WIDTH - 3, HEADER_HEIGHT),Size = UDim2.new(0, 6, 1, -HEADER_HEIGHT - STATUS_HEIGHT),ZIndex = 10,AutoButtonColor = false,Text = ""})
local PaneDividerLine = Create("Frame",{Name = "DividerLine",Parent = PaneDivider,BackgroundColor3 = Quantum.BorderSubtle,BorderSizePixel = 0,Position = UDim2.fromOffset(2, 0),Size = UDim2.new(0, 1, 1, 0),ZIndex = 11})

local ToolTip = Create("Frame",{Parent = SimpleSpy3,BackgroundColor3 = Quantum.SurfaceRaised,BackgroundTransparency = 0.04,BorderSizePixel = 0,Size = UDim2.fromOffset(200, 50),ZIndex = 20,Visible = false})
addCorner(ToolTip, 2)
PixelBorder.create(ToolTip, Quantum.Border, 21)
local TextLabel = Create("TextLabel",{Parent = ToolTip,BackgroundTransparency = 1,Position = UDim2.fromOffset(7, 5),Size = UDim2.new(1, -14, 1, -10),ZIndex = 21,Font = Enum.Font.Code,Text = "",TextColor3 = Quantum.Text,TextSize = 11,TextWrapped = true,TextXAlignment = Enum.TextXAlignment.Left,TextYAlignment = Enum.TextYAlignment.Top})

local ContextMenu = Create("Frame",{Name = "RemoteContextMenu",Parent = SimpleSpy3,BackgroundColor3 = Quantum.SurfaceRaised,BorderSizePixel = 0,Size = UDim2.fromOffset(166, 205),ZIndex = 30,Visible = false})
addCorner(ContextMenu, 2)
PixelBorder.create(ContextMenu, Quantum.Border, 31)
local ContextContent = Create("Frame",{Name = "ContextContent",Parent = ContextMenu,BackgroundTransparency = 1,BorderSizePixel = 0,Position = UDim2.fromOffset(1, 1),Size = UDim2.new(1, -2, 1, -2),ZIndex = 31})
Create("UIListLayout",{Parent = ContextContent,SortOrder = Enum.SortOrder.LayoutOrder,Padding = UDim.new(0, 1)})
Create("UIPadding",{Parent = ContextContent,PaddingLeft = UDim.new(0, 4),PaddingRight = UDim.new(0, 4),PaddingTop = UDim.new(0, 4),PaddingBottom = UDim.new(0, 4)})
local ContextButtons = {}
for order, actionName in next, {"Copy Remote", "Copy Path", "Copy Code", "Get Script", "Function Info", "Exclude", "Block", "Clear"} do
    local contextButton = Create("TextButton",{Name = actionName,Parent = ContextContent,BackgroundColor3 = Quantum.SurfaceRaised,BorderSizePixel = 0,LayoutOrder = order,Size = UDim2.new(1, 0, 0, 23),ZIndex = 32,AutoButtonColor = false,Font = Enum.Font.Code,Text = lower(actionName),TextColor3 = Quantum.TextSecondary,TextSize = 10,TextXAlignment = Enum.TextXAlignment.Left})
    Create("UIPadding",{Parent = contextButton,PaddingLeft = UDim.new(0, 8)})
    styleButton(contextButton, Quantum.SurfaceRaised, Quantum.Hover, Quantum.Panel)
    ContextButtons[actionName] = contextButton
end
local ActionsOverflowMenu = Create("Frame",{Name = "ActionsOverflowMenu",Parent = SimpleSpy3,BackgroundColor3 = Quantum.SurfaceRaised,BorderSizePixel = 0,Size = UDim2.fromOffset(174, 190),ZIndex = 34,Visible = false})
addCorner(ActionsOverflowMenu, 2)
PixelBorder.create(ActionsOverflowMenu, Quantum.Border, 35)
local ActionsOverflowScroll = Create("ScrollingFrame",{Parent = ActionsOverflowMenu,Active = true,BackgroundTransparency = 1,BorderSizePixel = 0,Position = UDim2.fromOffset(5, 5),Size = UDim2.new(1, -10, 1, -10),CanvasSize = UDim2.new(),ScrollBarThickness = 2,ScrollBarImageColor3 = Quantum.TextVeryMuted,ZIndex = 35})
local ActionsOverflowLayout = Create("UIListLayout",{Parent = ActionsOverflowScroll,SortOrder = Enum.SortOrder.LayoutOrder,Padding = UDim.new(0, 2)})
local ActionTemplates = {}
local ActionButtons = {}
local ActionOverflowButtons = {}
    return {
        SimpleSpy3 = SimpleSpy3,
        Storage = Storage,
        Background = Background,
        WindowShadow = WindowShadow,
        BackgroundScale = BackgroundScale,
        BackgroundConstraint = BackgroundConstraint,
        TopBar = TopBar,
        HeaderDivider = HeaderDivider,
        BrandMark = BrandMark,
        Subtitle = Subtitle,
        ToggleButton = Simple,
        SidebarToggle = SidebarToggle,
        SpyStatusDot = SpyStatusDot,
        SpyStatusText = SpyStatusText,
        CloseButton = CloseButton,
        MaximizeButton = MaximizeButton,
        MinimizeButton = MinimizeButton,
        LeftPanel = LeftPanel,
        FilterSection = FilterSection,
        SearchFrame = SearchFrame,
        FilterInput = FilterInput,
        FilterShortcut = FilterShortcut,
        RemoteStreamSection = RemoteStreamSection,
        RemoteCountLabel = RemoteCountLabel,
        LogList = LogList,
        RemoteListLayout = UIListLayout,
        RightPanel = RightPanel,
        InspectorTabs = InspectorTabs,
        InspectorTabButtons = InspectorTabButtons,
        InspectorTabAccents = InspectorTabAccents,
        InspectorHeader = InspectorHeader,
        InspectorSelection = InspectorSelection,
        RemoteContent = RemoteContent,
        InspectorProperties = InspectorProperties,
        RemoteNameValue = RemoteNameValue,
        RemoteTypeValue = RemoteTypeValue,
        RemoteMethodValue = RemoteMethodValue,
        RemoteCallsValue = RemoteCallsValue,
        RemotePathValue = RemotePathValue,
        RemoteScriptValue = RemoteScriptValue,
        ArgumentsSection = ArgumentsSection,
        ArgumentsScroll = ArgumentsScroll,
        ArgumentsText = ArgumentsText,
        CodeSection = CodeSection,
        CodeBox = CodeBox,
        CopyCodeButton = CopyCodeButton,
        ActionsSection = ActionsSection,
        ActionsContent = ActionsContent,
        ActionsOverflowButton = ActionsOverflowButton,
        ActionsScroller = ScrollingFrame,
        ActionsGrid = UIGridLayout,
        ActionsPadding = ActionsPadding,
        ActionsOverflowMenu = ActionsOverflowMenu,
        ActionsOverflowScroll = ActionsOverflowScroll,
        ActionsOverflowLayout = ActionsOverflowLayout,
        ActionTemplates = ActionTemplates,
        ActionButtons = ActionButtons,
        ActionOverflowButtons = ActionOverflowButtons,
        PrimaryActionLabels = {['Copy Code'] = 'copy', ['Copy Remote'] = 'remote', ['Run Code'] = 'run', ['Get Script'] = 'script', ['Function Info'] = 'info'},
        StatusBar = StatusBar,
        StatusDot = StatusDot,
        StatusVersionText = StatusVersionText,
        StatusSeparatorOne = StatusSeparatorOne,
        StatusStateText = StatusStateText,
        StatusSeparatorTwo = StatusSeparatorTwo,
        StatusCallsText = StatusCallsText,
        StatusSeparatorThree = StatusSeparatorThree,
        StatusRemotesText = StatusRemotesText,
        ReadyText = ReadyText,
        ToolTip = ToolTip,
        TooltipText = TextLabel,
        ContextMenu = ContextMenu,
        ContextButtons = ContextButtons,
        PaneDivider = PaneDivider,
        PaneDividerLine = PaneDividerLine,
        Layout = Layout,
        Resize = Resize,
    }
end

local UI = createQuantumUI()

-------------------------------------------------------------------------------

--- So things are descending
local layoutOrderNum = 999999999
--- Whether or not the gui is closing
local mainClosing = false
--- Whether or not the gui is closed (defaults to false)
local closed = false
--- Whether or not the sidebar is closing
local sideClosing = false
--- Whether or not the sidebar is closed (defaults to true but opens automatically on remote selection)
local sideClosed = false
--- Whether or not the code box is maximized (defaults to false)
local maximized = false
--- The event logs to be read from
local logs = {}
--- One visible row per remote identity + method; logs still retains every captured call.
local remoteGroups = {}
--- The event currently selected.Log (defaults to nil)
local selected = nil
--- The blacklist (can be a string name or the Remote Instance)
local blacklist = {}
--- The block list (can be a string name or the Remote Instance)
local blocklist = {}
--- Whether or not to add getNil function
local getNil = false
--- Array of remotes (and original functions) connected to
local connectedRemotes = {}
--- True = hookfunction, false = namecall
local toggle = false
--- used to prevent recursives
local prevTables = {}
--- holds logs (for deletion)
local remoteLogs = {}
--- used for hookfunction
getgenv().SIMPLESPYCONFIG_MaxRemotes = 300
local indent = 4
local scheduled = {}
local schedulerconnect
local SimpleSpy = {}
local topstr = ""
local bottomstr = ""
local expandedWindowHeight = 620
local codebox
local p
local getnilrequired = false

-- autoblock variables
local history = {}
local excluding = {}

-- if mouse inside gui
local mouseInGui = false

local connections = {}
local DecompiledScripts = {}
local generation = {}
local running_threads = {}
local originalnamecall
local actionHandlers = {}

local function resetQuantumInspector()
    UI.InspectorSelection.Text = "no remote selected"
    UI.InspectorSelection.TextColor3 = Quantum.TextMuted
    UI.RemoteNameValue.Text = "—"
    UI.RemoteTypeValue.Text = "—"
    UI.RemoteMethodValue.Text = "—"
    UI.RemoteCallsValue.Text = "0"
    UI.RemotePathValue.Text = "—"
    UI.RemoteScriptValue.Text = "—"
    UI.RemoteNameValue.TextColor3 = Quantum.TextSecondary
    UI.RemoteTypeValue.TextColor3 = Quantum.TextSecondary
    UI.RemoteMethodValue.TextColor3 = Quantum.TextSecondary
    UI.RemoteCallsValue.TextColor3 = Quantum.TextSecondary
    UI.RemotePathValue.TextColor3 = Quantum.TextSecondary
    UI.RemoteScriptValue.TextColor3 = Quantum.TextSecondary
    UI.ArgumentsText.Text = "no arguments"
    UI.ArgumentsText.TextColor3 = Quantum.TextMuted
    UI.ArgumentsText.Visible = true
    for _, child in next, UI.ArgumentsScroll:GetChildren() do
        if child.Name == "ArgumentRow" then
            child:Destroy()
        end
    end
    UI.ArgumentsScroll.CanvasPosition = Vector2.zero
    if codebox then
        codebox:setRaw("-- select a remote to inspect generated code")
    end
end

local function getLiveRemoteCount()
    local count = 0
    for _, group in next, remoteGroups do
        if group.Row and group.Row.Parent then
            count += 1
        end
    end
    return count
end

local function updateQuantumStatus()
    local active = toggle
    local state = active and "active" or "paused"
    local stateColor = active and Quantum.Cyan or Quantum.Warning
    UI.StatusStateText.Text = "spy:" .. state
    UI.StatusCallsText.Text = string.format("calls:%d", #logs)
    UI.StatusRemotesText.Text = string.format("remotes:%d", getLiveRemoteCount())
    UI.StatusDot.BackgroundColor3 = stateColor
    UI.SpyStatusDot.BackgroundColor3 = stateColor
    UI.SpyStatusText.Text = active and "ACTIVE" or "PAUSED"
    UI.SpyStatusText.TextColor3 = active and Quantum.TextSecondary or Quantum.Warning
    UI.RemoteCountLabel.Text = string.format("%d calls", #logs)
end

local function applyRemoteFilter()
    local query = lower(UI.FilterInput.Text)
    for _, group in next, remoteGroups do
        if group.Row and group.Row.Parent then
            group.Row.Visible = query == ""
                or lower(group.Name or ""):find(query, 1, true) ~= nil
                or lower(group.RemotePath or ""):find(query, 1, true) ~= nil
                or lower(group.Method or ""):find(query, 1, true) ~= nil
        end
    end
    UI.LogList.CanvasSize = UDim2.fromOffset(UI.RemoteListLayout.AbsoluteContentSize.X, UI.RemoteListLayout.AbsoluteContentSize.Y + 6)
end

local function styleRemoteRow(log, isSelected)
    if not log or not log.Button or not log.Button.Parent then
        return
    end
    quantumTween(log.Button, {BackgroundColor3 = isSelected and Quantum.Selected or Quantum.Surface, BackgroundTransparency = isSelected and 0 or 1}, 0.1)
    if log.SelectionBar then
        quantumTween(log.SelectionBar, {BackgroundTransparency = isSelected and 0 or 1}, 0.12)
    end
    if log.PrimaryText then
        quantumTween(log.PrimaryText, {TextColor3 = isSelected and Quantum.Text or Quantum.TextSecondary}, 0.12)
    end
end

local function closeContextMenu()
    UI.ContextMenu.Visible = false
    UI.ActionsOverflowMenu.Visible = false
end

local function toggleActionsOverflowMenu()
    if UI.ActionsOverflowMenu.Visible then
        UI.ActionsOverflowMenu.Visible = false
        return
    end
    local menuSize = UI.ActionsOverflowMenu.AbsoluteSize
    local buttonPosition = UI.ActionsOverflowButton.AbsolutePosition
    local buttonSize = UI.ActionsOverflowButton.AbsoluteSize
    local windowPosition = UI.Background.AbsolutePosition
    local windowSize = UI.Background.AbsoluteSize
    local left = math.round(windowPosition.X + 4)
    local top = math.round(windowPosition.Y + 4)
    local right = math.round(windowPosition.X + windowSize.X - 4)
    local bottom = math.round(windowPosition.Y + windowSize.Y - 4)
    local belowY = math.round(buttonPosition.Y + buttonSize.Y + 4)
    local aboveY = math.round(buttonPosition.Y - menuSize.Y - 4)
    local x = math.clamp(math.round(buttonPosition.X + buttonSize.X - menuSize.X), left, math.max(left, right - menuSize.X))
    local y = belowY + menuSize.Y <= bottom and belowY or aboveY
    y = math.clamp(y, top, math.max(top, bottom - menuSize.Y))
    UI.ContextMenu.Visible = false
    UI.ActionsOverflowMenu.Position = UDim2.fromOffset(x, y)
    UI.ActionsOverflowMenu.Visible = true
end

local function openContextMenu()
    if not selected then
        return
    end
    local mousePosition = UserInputService:GetMouseLocation() - GuiInset
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local menuSize = UI.ContextMenu.AbsoluteSize
    UI.ContextMenu.Position = UDim2.fromOffset(
        math.clamp(mousePosition.X, 4, math.max(4, viewportSize.X - menuSize.X - 4)),
        math.clamp(mousePosition.Y, 4, math.max(4, viewportSize.Y - menuSize.Y - 4))
    )
    UI.ContextMenu.Visible = true
end

local function runContextAction(displayName)
    closeContextMenu()
    if displayName == "Copy Path" then
        if selected and selected.RemotePath then
            setclipboard(selected.RemotePath)
            UI.TooltipText.Text = "Path copied!"
        end
        return
    end
    local actionName = displayName == "Exclude" and "Exclude (i)"
        or displayName == "Block" and "Block (i)"
        or displayName == "Clear" and "Clr Logs"
        or displayName
    local handler = actionHandlers[actionName]
    if handler then
        handler()
    end
end

for actionName, button in next, UI.ContextButtons do
    table.insert(connections, button.MouseButton1Click:Connect(function()
        runContextAction(actionName)
    end))
end
table.insert(connections, UI.CopyCodeButton.MouseButton1Click:Connect(function()
    runContextAction("Copy Code")
end))
table.insert(connections, UI.ActionsOverflowButton.MouseButton1Click:Connect(toggleActionsOverflowMenu))
table.insert(connections, UI.ActionsOverflowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local contentHeight = UI.ActionsOverflowLayout.AbsoluteContentSize.Y
    UI.ActionsOverflowScroll.CanvasSize = UDim2.fromOffset(0, contentHeight + 4)
    UI.ActionsOverflowMenu.Size = UDim2.fromOffset(174, math.clamp(contentHeight + 10, 48, 190))
end))

UI.FilterInput:GetPropertyChangedSignal("Text"):Connect(applyRemoteFilter)

local remoteEvent = Instance.new("RemoteEvent",UI.Storage)
local remoteFunction = Instance.new("RemoteFunction",UI.Storage)
local NamecallHandler = Instance.new("BindableEvent",UI.Storage)
local IndexHandler = Instance.new("BindableEvent",UI.Storage)
local GetDebugIdHandler = Instance.new("BindableFunction",UI.Storage) --Thanks engo for the idea of using BindableFunctions

local originalEvent = remoteEvent.FireServer
local originalFunction = remoteFunction.InvokeServer
local GetDebugIDInvoke = GetDebugIdHandler.Invoke

function GetDebugIdHandler.OnInvoke(obj: Instance) -- To avoid having to set thread identity and ect
    return OldDebugId(obj)
end

local function ThreadGetDebugId(obj: Instance): string 
    return GetDebugIDInvoke(GetDebugIdHandler,obj) -- indexing to avoid having to setnamecall later
end

local synv3 = false

if syn and identifyexecutor then
    local _, version = identifyexecutor()
    if (version and version:sub(1, 2) == 'v3') then
        synv3 = true
    end
end

xpcall(function()
    if isfile and readfile and isfolder and makefolder then
        local cachedconfigs = isfile("SimpleSpy//Settings.json") and jsond(readfile("SimpleSpy//Settings.json"))

        if cachedconfigs then
            for i,v in next, realconfigs do
                if cachedconfigs[i] == nil then
                    cachedconfigs[i] = v
                end
            end
            realconfigs = cachedconfigs
        end

        if not isfolder("SimpleSpy") then
            makefolder("SimpleSpy")
        end
        if not isfolder("SimpleSpy//Assets") then
            makefolder("SimpleSpy//Assets")
        end
        if not isfile("SimpleSpy//Settings.json") then
            writefile("SimpleSpy//Settings.json",jsone(realconfigs))
        end

        configsmetatable.__newindex = function(self,index,newindex)
            realconfigs[index] = newindex
            writefile("SimpleSpy//Settings.json",jsone(realconfigs))
        end
    else
        configsmetatable.__newindex = function(self,index,newindex)
            realconfigs[index] = newindex
        end
    end
end,function(err)
    ErrorPrompt(("An error has occured: (%s)"):format(err))
end)

local function logthread(thread: thread)
    table.insert(running_threads,thread)
end

--- Prevents remote spam from causing lag (clears logs after `getgenv().SIMPLESPYCONFIG_MaxRemotes` or 500 remotes)
function clean()
    local max = getgenv().SIMPLESPYCONFIG_MaxRemotes
    if typeof(max) ~= "number" or math.floor(max) ~= max or max < 1 then
        max = 500
    end
    if #remoteLogs > max then
        local keepCount = math.min(100, max)
        for i = keepCount + 1, #remoteLogs do
            local v = remoteLogs[i]
            if typeof(v[1]) == "RBXScriptConnection" then
                v[1]:Disconnect()
            end
            if typeof(v[2]) == "Instance" then
                v[2]:Destroy()
            end
            if v[3] then
                remoteGroups[v[3]] = nil
            end
        end
        local newLogs = {}
        for i = 1, keepCount do
            table.insert(newLogs, remoteLogs[i])
        end
        remoteLogs = newLogs
        local removedSelection = false
        for i = #logs, 1, -1 do
            local log = logs[i]
            if not log.Log or not log.Log.Parent then
                removedSelection = removedSelection or selected == log
                table.remove(logs, i)
            end
        end
        if removedSelection then
            selected = nil
            resetQuantumInspector()
        end
    end
end

local function ThreadIsNotDead(thread: thread): boolean
    return not status(thread) == "dead"
end

--- Scales the ToolTip to fit containing text
function scaleToolTip()
    local size = TextService:GetTextSize(UI.TooltipText.Text, UI.TooltipText.TextSize, UI.TooltipText.Font, Vector2.new(196, math.huge))
    UI.TooltipText.Size = UDim2.new(0, size.X, 0, size.Y)
    UI.ToolTip.Size = UDim2.new(0, size.X + 14, 0, size.Y + 10)
end

--- Executed when the toggle button (the SimpleSpy logo) is hovered over
function onToggleButtonHover()
    quantumTween(UI.ToggleButton, {TextColor3 = toggle and Quantum.Success or Quantum.Warning}, 0.12)
end

--- Executed when the toggle button is unhovered over
function onToggleButtonUnhover()
    quantumTween(UI.ToggleButton, {TextColor3 = Quantum.Text}, 0.12)
end

--- Executed when the X button is hovered over
function onXButtonHover()
    quantumTween(UI.CloseButton, {BackgroundColor3 = Quantum.Error, TextColor3 = Quantum.Text}, 0.12)
end

--- Executed when the X button is unhovered over
function onXButtonUnhover()
    quantumTween(UI.CloseButton, {BackgroundColor3 = Quantum.Panel, TextColor3 = Quantum.TextSecondary}, 0.1)
end

--- Toggles the remote spy method (when button clicked)
function onToggleButtonClick()
    toggleSpyMethod()
    updateQuantumStatus()
    quantumTween(UI.ToggleButton, {TextColor3 = toggle and Quantum.Success or Quantum.Warning}, 0.12)
end

--- Reconnects bringBackOnResize if the current viewport changes and also connects it initially
function connectResize()
    if not workspace.CurrentCamera then
        workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
    end
    local lastCam = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(bringBackOnResize)
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        lastCam:Disconnect()
        if typeof(lastCam) == 'Connection' then
            lastCam:Disconnect()
        end
        lastCam = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(bringBackOnResize)
    end)
end

--- Brings gui back if it gets lost offscreen (connected to the camera viewport changing)
function bringBackOnResize()
    validateSize()
    if sideClosed then
        minimizeSize()
    else
        maximizeSize()
    end
    local margin = 4
    local currentX = math.round(UI.Background.AbsolutePosition.X)
    local currentY = math.round(UI.Background.AbsolutePosition.Y)
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local visibleHeight = closed and HEADER_HEIGHT or UI.Background.AbsoluteSize.Y
    local maximumX = math.max(margin, math.round(viewportSize.X - UI.Background.AbsoluteSize.X - margin))
    local maximumY = math.max(margin, math.round(viewportSize.Y - visibleHeight - GuiInset.Y - margin))
    currentX = math.clamp(currentX, margin, maximumX)
    currentY = math.clamp(currentY, margin, maximumY)
    TweenService.Create(TweenService, UI.Background, TweenInfo.new(0.1), {Position = UDim2.fromOffset(currentX, currentY)}):Play()
end

--- Drags gui (so long as mouse is held down)
--- @param input InputObject
function onBarInput(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local lastPos = UserInputService:GetMouseLocation()
        local mainPos = UI.Background.AbsolutePosition
        local offset = mainPos - lastPos
        local currentPos = offset + lastPos
        if not connections["drag"] then
            connections["drag"] = RunService.RenderStepped:Connect(function()
                local newPos = UserInputService:GetMouseLocation()
                if newPos ~= lastPos then
                    local margin = 4
                    local currentX = math.round((offset + newPos).X)
                    local currentY = math.round((offset + newPos).Y)
                    local viewportSize = workspace.CurrentCamera.ViewportSize
                    local visibleHeight = closed and HEADER_HEIGHT or UI.Background.AbsoluteSize.Y
                    local maximumX = math.max(margin, math.round(viewportSize.X - UI.Background.AbsoluteSize.X - margin))
                    local maximumY = math.max(margin, math.round(viewportSize.Y - visibleHeight - GuiInset.Y - margin))
                    currentX = math.clamp(currentX, margin, maximumX)
                    currentY = math.clamp(currentY, margin, maximumY)
                    currentPos = Vector2.new(currentX, currentY)
                    lastPos = newPos
                    TweenService.Create(TweenService, UI.Background, TweenInfo.new(0.1), {Position = UDim2.new(0, currentPos.X, 0, currentPos.Y)}):Play()
                end
                    -- if input.UserInputState ~= Enum.UserInputState.Begin then
                    --     RunService.UnbindFromRenderStep(RunService, "drag")
                    -- end
            end)
        end
        table.insert(connections, UserInputService.InputEnded:Connect(function(inputE)
            if input == inputE then
                if connections["drag"] then
                    connections["drag"]:Disconnect()
                    connections["drag"] = nil
                end
            end
        end))
    end
end

--- Expands and minimizes the gui (closed is the toggle boolean)
function toggleMinimize(override)
    if mainClosing and not override or maximized then
        return
    end
    mainClosing = true
    closed = not closed
    if closed then
        expandedWindowHeight = math.max(UI.Background.AbsoluteSize.Y, MINIMUM_HEIGHT)
        UI.BackgroundConstraint.MinSize = Vector2.new(MINIMUM_WIDTH, HEADER_HEIGHT)
        quantumTween(UI.LeftPanel, {GroupTransparency = 1}, 0.14)
        quantumTween(UI.RightPanel, {GroupTransparency = 1}, 0.14)
        quantumTween(UI.StatusBar, {GroupTransparency = 1}, 0.14)
        quantumTween(UI.Background, {Size = UDim2.fromOffset(UI.Background.AbsoluteSize.X, HEADER_HEIGHT)}, 0.18, Enum.EasingStyle.Quint)
        UI.MinimizeButton.Text = "▢"
        wait(0.18)
        UI.LeftPanel.Visible = false
        UI.RightPanel.Visible = false
        UI.StatusBar.Visible = false
    else
        UI.LeftPanel.Visible = true
        UI.RightPanel.Visible = not sideClosed
        UI.StatusBar.Visible = true
        local viewportSize = workspace.CurrentCamera.ViewportSize
        UI.BackgroundConstraint.MaxSize = getMaximumWindowSize(viewportSize)
        quantumTween(UI.Background, {Size = UDim2.fromOffset(UI.Background.AbsoluteSize.X, expandedWindowHeight)}, 0.18, Enum.EasingStyle.Quint)
        wait(0.12)
        quantumTween(UI.LeftPanel, {GroupTransparency = 0}, 0.14)
        quantumTween(UI.RightPanel, {GroupTransparency = sideClosed and 1 or 0}, 0.14)
        quantumTween(UI.StatusBar, {GroupTransparency = 0}, 0.14)
        UI.BackgroundConstraint.MinSize = Vector2.new(MINIMUM_WIDTH, MINIMUM_HEIGHT)
        UI.MinimizeButton.Text = "–"
        bringBackOnResize()
    end
    mainClosing = false
end

--- Expands and minimizes the sidebar (sideClosed is the toggle boolean)
function toggleSideTray(override)
    if sideClosing and not override or maximized then
        return
    end
    sideClosing = true
    if closed then
        toggleMinimize(true)
    end
    sideClosed = not sideClosed
    if sideClosed then
        quantumTween(UI.RightPanel, {GroupTransparency = 1}, 0.14)
        wait(0.14)
        UI.RightPanel.Visible = false
        minimizeSize(0.18)
    else
        UI.RightPanel.Visible = true
        UI.RightPanel.GroupTransparency = 1
        maximizeSize(0.18)
        quantumTween(UI.RightPanel, {GroupTransparency = 0}, 0.16)
        bringBackOnResize()
    end
    sideClosing = false
end

--- Expands code box to fit screen for more convenient viewing
function toggleMaximize()
    if not sideClosed and not maximized then
        maximized = true
        local disable = Instance.new("TextButton")
        local prevSize = UDim2.new(0, UI.CodeBox.AbsoluteSize.X, 0, UI.CodeBox.AbsoluteSize.Y)
        local prevPos = UDim2.new(0,UI.CodeBox.AbsolutePosition.X, 0, UI.CodeBox.AbsolutePosition.Y)
        disable.Size = UDim2.new(1, 0, 1, 0)
        disable.BackgroundColor3 = Color3.new()
        disable.BorderSizePixel = 0
        disable.Text = 0
        disable.ZIndex = 3
        disable.BackgroundTransparency = 1
        disable.AutoButtonColor = false
        UI.CodeBox.ZIndex = 4
        UI.CodeBox.Position = prevPos
        UI.CodeBox.Size = prevSize
        TweenService:Create(UI.CodeBox, TweenInfo.new(0.5), {Size = UDim2.new(0.5, 0, 0.5, 0), Position = UDim2.new(0.25, 0, 0.25, 0)}):Play()
        TweenService:Create(disable, TweenInfo.new(0.5), {BackgroundTransparency = 0.5}):Play()
        disable.MouseButton1Click:Connect(function()
            if UserInputService:GetMouseLocation().Y + GuiInset.Y >= UI.CodeBox.AbsolutePosition.Y and UserInputService:GetMouseLocation().Y + GuiInset.Y <= UI.CodeBox.AbsolutePosition.Y + UI.CodeBox.AbsoluteSize.Y and UserInputService:GetMouseLocation().X >= UI.CodeBox.AbsolutePosition.X and UserInputService:GetMouseLocation().X <= UI.CodeBox.AbsolutePosition.X + UI.CodeBox.AbsoluteSize.X then
                return
            end
            TweenService:Create(UI.CodeBox, TweenInfo.new(0.5), {Size = prevSize, Position = prevPos}):Play()
            TweenService:Create(disable, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
            wait(0.5)
            disable:Destroy()
            UI.CodeBox.Size = UDim2.new(1, 0, 0.5, 0)
            UI.CodeBox.Position = UDim2.new(0, 0, 0, 0)
            UI.CodeBox.ZIndex = 0
            maximized = false
        end)
    end
end

--- Checks if cursor is within resize range
--- @param p Vector2
function isInResizeRange(p)
    local relativeP = p - UI.Background.AbsolutePosition
    local backgroundSize = UI.Background.AbsoluteSize
    local range = 6
    local onLeft = relativeP.X >= 0 and relativeP.X <= range
    local onRight = relativeP.X >= backgroundSize.X - range and relativeP.X <= backgroundSize.X
    local onTop = relativeP.Y >= 0 and relativeP.Y <= range
    local onBottom = relativeP.Y >= backgroundSize.Y - range and relativeP.Y <= backgroundSize.Y

    if onTop and onLeft then
        return true, "TL"
    elseif onTop and onRight then
        return true, "TR"
    elseif onBottom and onLeft then
        return true, "BL"
    elseif onBottom and onRight then
        return true, "BR"
    elseif onLeft then
        return true, "L"
    elseif onRight then
        return true, "R"
    elseif onTop then
        return true, "T"
    elseif onBottom then
        return true, "B"
    end
    return false
end

--- Checks if cursor is within dragging range
--- @param p Vector2
function isInDragRange(p)
    local topLeft = UI.TopBar.AbsolutePosition
    local bottomRight = topLeft + UI.TopBar.AbsoluteSize
    if UI.SidebarToggle.Visible then
        local toggleTopLeft = UI.SidebarToggle.AbsolutePosition
        local toggleBottomRight = toggleTopLeft + UI.SidebarToggle.AbsoluteSize
        if p.X >= toggleTopLeft.X and p.X <= toggleBottomRight.X and p.Y >= toggleTopLeft.Y and p.Y <= toggleBottomRight.Y then
            return false
        end
    end
    return p.X >= topLeft.X and p.X <= bottomRight.X - UI.CloseButton.AbsoluteSize.X * 3 and p.Y >= topLeft.Y and p.Y <= bottomRight.Y
end

--- Called when mouse enters SimpleSpy
local customCursor = Create("ImageLabel",{Parent = UI.SimpleSpy3,Visible = false,Size = UDim2.fromOffset(200, 200),ZIndex = 1e9,BackgroundTransparency = 1,Image = "",Parent = UI.SimpleSpy3})
function mouseEntered()
    local con = connections["SIMPLESPY_CURSOR"]
    if con then
        con:Disconnect()
        connections["SIMPLESPY_CURSOR"] = nil
    end
    connections["SIMPLESPY_CURSOR"] = RunService.RenderStepped:Connect(function()
        UserInputService.MouseIconEnabled = not mouseInGui
        customCursor.Visible = mouseInGui
        if mouseInGui and getgenv().SimpleSpyExecuted then
            local mouseLocation = UserInputService:GetMouseLocation() - GuiInset
            customCursor.Position = UDim2.fromOffset(mouseLocation.X - customCursor.AbsoluteSize.X / 2, mouseLocation.Y - customCursor.AbsoluteSize.Y / 2)
            local inRange, resizeDirection = isInResizeRange(mouseLocation)
            if inRange and not closed then
                local isHorizontal = resizeDirection == "L" or resizeDirection == "R"
                local isVertical = resizeDirection == "T" or resizeDirection == "B"
                customCursor.Image = isHorizontal and "rbxassetid://6065821086" or isVertical and "rbxassetid://6065821596" or "rbxassetid://6065821980"
                customCursor.Rotation = (resizeDirection == "TR" or resizeDirection == "BL") and 90 or 0
            elseif customCursor.Image ~= "rbxassetid://6065775281" then
                customCursor.Image = "rbxassetid://6065775281"
                customCursor.Rotation = 0
            end
        else
            connections["SIMPLESPY_CURSOR"]:Disconnect()
        end
    end)
end

--- Called when mouse moves
function mouseMoved()
    local mousePos = UserInputService:GetMouseLocation() - GuiInset
    if not closed
    and mousePos.X >= UI.TopBar.AbsolutePosition.X and mousePos.X <= UI.TopBar.AbsolutePosition.X + UI.TopBar.AbsoluteSize.X
    and mousePos.Y >= UI.Background.AbsolutePosition.Y and mousePos.Y <= UI.Background.AbsolutePosition.Y + UI.Background.AbsoluteSize.Y then
        if not mouseInGui then
            mouseInGui = true
            mouseEntered()
        end
    else
        mouseInGui = false
    end
end

function applyResponsiveProperties(object, properties, speed)
    if speed and speed > 0 then
        quantumTween(object, properties, speed)
    else
        for property, value in next, properties do
            object[property] = value
        end
    end
end

function getLayoutMode(width, height)
    if height <= 340 then
        return "Thin"
    elseif width <= 600 then
        return "Narrow"
    elseif width < 800 or height < 500 then
        return "Compact"
    end
    return "Full"
end

function setInspectorTab(tabName)
    if UI.InspectorTabButtons[tabName] then
        closeContextMenu()
        UI.Layout.InspectorTab = tabName
        updateResponsiveLayout(0, true)
    end
end

--- Centrally lays out the window without rebuilding any logged or generated content.
function updateResponsiveLayout(speed, preserveSidebarWidth)
    local width = math.round(UI.Background.AbsoluteSize.X)
    local height = math.round(UI.Background.AbsoluteSize.Y)
    local mode = getLayoutMode(width, height)
    local useInspectorTabs = mode ~= "Full"
    local isNarrow = width <= 600
    local isVeryNarrow = width <= 600
    local fullHeader = mode == "Full" or closed
    local headerHeight = fullHeader and HEADER_HEIGHT or mode == "Thin" and 40 or 46
    local statusHeight = mode == "Full" and STATUS_HEIGHT or mode == "Thin" and 22 or 26
    local headerInset = fullHeader and 9 or mode == "Thin" and 4 or 5
    local topBarHeight = headerHeight - headerInset * 2 - 2
    local controlY = fullHeader and 11 or math.max(3, math.round((topBarHeight - 25) * 0.5))

    UI.Layout.Mode = mode
    if useInspectorTabs and not UI.Layout.UseInspectorTabs then
        UI.Layout.InspectorTab = selected and "Code" or "Remote"
    end
    UI.Layout.UseInspectorTabs = useInspectorTabs
    local autoCollapseWidth = width <= 480
    if autoCollapseWidth and not UI.Layout.WasAutoCollapseWidth and not UI.Layout.SidebarUserOverride then
        UI.Layout.SidebarCollapsed = true
    elseif not isVeryNarrow then
        UI.Layout.SidebarCollapsed = false
        UI.Layout.SidebarUserOverride = false
    end
    UI.Layout.WasAutoCollapseWidth = autoCollapseWidth

    applyResponsiveProperties(UI.TopBar, {Position = UDim2.fromOffset(headerInset, headerInset), Size = UDim2.fromOffset(width - headerInset * 2, topBarHeight)}, speed)
    applyResponsiveProperties(UI.HeaderDivider, {Position = UDim2.fromOffset(headerInset, headerHeight - 1), Size = UDim2.fromOffset(width - headerInset * 2, 1)}, speed)
    UI.Subtitle.Visible = fullHeader
    UI.SidebarToggle.Visible = isVeryNarrow and not closed and not sideClosed
    UI.SidebarToggle.Text = UI.Layout.SidebarCollapsed and "»" or "≡"
    applyResponsiveProperties(UI.SidebarToggle, {Position = UDim2.fromOffset(8, controlY), Size = UDim2.fromOffset(24, 25)}, speed)
    local brandX = UI.SidebarToggle.Visible and 35 or 13
    local titleX = UI.SidebarToggle.Visible and 59 or 39
    local brandY = fullHeader and 5 or math.max(3, controlY)
    local titleY = fullHeader and 2 or math.max(1, controlY - 2)
    applyResponsiveProperties(UI.BrandMark, {Position = UDim2.fromOffset(brandX, brandY), Size = UDim2.fromOffset(20, 20)}, speed)
    applyResponsiveProperties(UI.ToggleButton, {Position = UDim2.fromOffset(titleX, titleY), Size = UDim2.fromOffset(isVeryNarrow and 108 or 132, 24)}, speed)
    applyResponsiveProperties(UI.Subtitle, {Position = UDim2.fromOffset(40, 27), Size = UDim2.fromOffset(250, 15)}, speed)
    applyResponsiveProperties(UI.CloseButton, {Position = UDim2.new(1, -35, 0, controlY), Size = UDim2.fromOffset(25, 25)}, speed)
    applyResponsiveProperties(UI.MaximizeButton, {Position = UDim2.new(1, -65, 0, controlY), Size = UDim2.fromOffset(25, 25)}, speed)
    applyResponsiveProperties(UI.MinimizeButton, {Position = UDim2.new(1, -95, 0, controlY), Size = UDim2.fromOffset(25, 25)}, speed)
    applyResponsiveProperties(UI.SpyStatusDot, {Position = UDim2.new(1, -159, 0, fullHeader and 22 or math.round(topBarHeight * 0.5 - 2)), Size = UDim2.fromOffset(5, 5)}, speed)
    applyResponsiveProperties(UI.SpyStatusText, {Position = UDim2.new(1, -150, 0, fullHeader and 16 or math.round(topBarHeight * 0.5 - 9)), Size = UDim2.fromOffset(48, 18)}, speed)

    if closed or height < MINIMUM_HEIGHT then
        UI.ActionsOverflowMenu.Visible = false
        return
    end

    local contentHeight = height - headerHeight - statusHeight
    local statusInset = mode == "Full" and 9 or 5
    local statusBarHeight = mode == "Full" and statusHeight - 8 or mode == "Thin" and 18 or statusHeight - 6
    local statusTextY = math.max(0, math.round((statusBarHeight - 18) * 0.5))
    applyResponsiveProperties(UI.StatusBar, {Position = UDim2.fromOffset(statusInset, height - statusHeight + (mode == "Full" and 4 or 3)), Size = UDim2.fromOffset(width - statusInset * 2, statusBarHeight)}, speed)

    local abbreviatedStatus = width <= 600 or height <= 320
    UI.StatusStateText.Visible = not abbreviatedStatus
    UI.StatusSeparatorTwo.Visible = not abbreviatedStatus
    UI.StatusRemotesText.Visible = not abbreviatedStatus
    UI.StatusSeparatorThree.Visible = not abbreviatedStatus
    UI.StatusVersionText.Text = abbreviatedStatus and "quantum" or "quantum@1.0.0"
    applyResponsiveProperties(UI.StatusDot, {Position = UDim2.fromOffset(mode == "Full" and 12 or 10, statusTextY + 6), Size = UDim2.fromOffset(6, 6)}, speed)
    applyResponsiveProperties(UI.StatusVersionText, {Position = UDim2.fromOffset(mode == "Full" and 24 or 22, statusTextY), Size = UDim2.fromOffset(abbreviatedStatus and 98 or 110, 18)}, speed)
    applyResponsiveProperties(UI.StatusSeparatorOne, {Position = UDim2.fromOffset(abbreviatedStatus and 121 or 136, statusTextY), Size = UDim2.fromOffset(10, 18)}, speed)
    applyResponsiveProperties(UI.StatusStateText, {Position = UDim2.fromOffset(150, statusTextY), Size = UDim2.fromOffset(86, 18)}, speed)
    applyResponsiveProperties(UI.StatusSeparatorTwo, {Position = UDim2.fromOffset(238, statusTextY), Size = UDim2.fromOffset(10, 18)}, speed)
    applyResponsiveProperties(UI.StatusCallsText, {Position = UDim2.fromOffset(abbreviatedStatus and 135 or 252, statusTextY), Size = UDim2.fromOffset(70, 18)}, speed)
    applyResponsiveProperties(UI.StatusSeparatorThree, {Position = UDim2.fromOffset(324, statusTextY), Size = UDim2.fromOffset(10, 18)}, speed)
    applyResponsiveProperties(UI.StatusRemotesText, {Position = UDim2.fromOffset(338, statusTextY), Size = UDim2.fromOffset(92, 18)}, speed)
    applyResponsiveProperties(UI.ReadyText, {Position = UDim2.new(1, mode == "Full" and -66 or -62, 0, statusTextY), Size = UDim2.fromOffset(mode == "Full" and 54 or 50, 18)}, speed)

    local compactSidebar = mode ~= "Full"
    local filterTop = compactSidebar and 4 or 12
    local filterHeight = mode == "Thin" and 28 or compactSidebar and 32 or 42
    local streamTop = filterTop + filterHeight + (compactSidebar and 5 or 11)
    local streamBottomInset = compactSidebar and 4 or 10
    applyResponsiveProperties(UI.FilterSection, {Position = UDim2.fromOffset(compactSidebar and 5 or 9, filterTop), Size = UDim2.new(1, compactSidebar and -10 or -19, 0, filterHeight)}, speed)
    applyResponsiveProperties(UI.SearchFrame, {Position = UDim2.fromOffset(compactSidebar and 5 or 7, compactSidebar and 7 or 9), Size = UDim2.new(1, compactSidebar and -10 or -14, 1, compactSidebar and -11 or -16)}, speed)
    UI.FilterShortcut.Visible = mode == "Full"
    UI.FilterInput.PlaceholderText = (mode == "Thin" or mode == "Narrow") and "filter..." or mode == "Compact" and "search..." or "search remotes..."
    applyResponsiveProperties(UI.FilterInput, {Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, mode == "Full" and -58 or -27, 1, 0)}, speed)
    applyResponsiveProperties(UI.RemoteStreamSection, {Position = UDim2.fromOffset(compactSidebar and 5 or 9, streamTop), Size = UDim2.new(1, compactSidebar and -10 or -19, 0, math.max(44, contentHeight - streamTop - streamBottomInset))}, speed)
    UI.RemoteCountLabel.Visible = not isNarrow

    if sideClosed then
        UI.PaneDivider.Visible = false
        UI.ActionsOverflowMenu.Visible = false
        UI.LeftPanel.Visible = true
        UI.RightPanel.Visible = false
        UI.InspectorTabs.Visible = false
        applyResponsiveProperties(UI.LeftPanel, {Position = UDim2.fromOffset(0, headerHeight), Size = UDim2.fromOffset(width, contentHeight)}, speed)
        applyResponsiveProperties(UI.RightPanel, {Position = UDim2.fromOffset(width, headerHeight), Size = UDim2.fromOffset(0, contentHeight)}, speed)
        return
    end

    local minimumSidebarWidth = isNarrow and 130 or mode == "Thin" and 170 or mode == "Compact" and 170 or 250
    local maximumSidebarWidth = isNarrow and math.min(190, width - 220) or mode == "Thin" and math.min(210, width - 300) or mode == "Compact" and math.min(240, width - 300) or math.min(380, width - 430)
    maximumSidebarWidth = math.max(minimumSidebarWidth, maximumSidebarWidth)
    local targetSidebarWidth = math.round(width * (isNarrow and 0.28 or mode == "Thin" and 0.22 or mode == "Compact" and 0.24 or 0.27))
    local sidebarWidth = preserveSidebarWidth and UI.Layout.SidebarWidth or targetSidebarWidth
    sidebarWidth = math.clamp(math.round(sidebarWidth), minimumSidebarWidth, maximumSidebarWidth)
    UI.Layout.SidebarWidth = sidebarWidth

    local compactRows = sidebarWidth <= 190
    if UI.Layout.CompactRows ~= compactRows then
        UI.Layout.CompactRows = compactRows
        for _, group in next, remoteGroups do
            if group.Row and group.Row.Parent then
                if group.TypeIndicator then
                    group.TypeIndicator.Position = UDim2.fromOffset(compactRows and 6 or 9, 7)
                end
                group.PrimaryText.Position = UDim2.fromOffset(compactRows and 18 or 22, 1)
                group.PrimaryText.Size = UDim2.new(1, compactRows and -70 or -80, 0, 16)
                group.MetaText.Position = UDim2.fromOffset(compactRows and 18 or 22, 18)
                group.MetaText.Size = UDim2.new(1, compactRows and -28 or -34, 0, 13)
                group.CountText.Position = UDim2.new(1, compactRows and -49 or -54, 0, 1)
                group.CountText.Size = UDim2.fromOffset(compactRows and 40 or 44, 16)
            end
        end
    end

    local sidebarCollapsed = isVeryNarrow and UI.Layout.SidebarCollapsed
    local inspectorX = sidebarCollapsed and 0 or sidebarWidth
    local inspectorWidth = width - inspectorX
    UI.LeftPanel.Visible = not sidebarCollapsed
    UI.RightPanel.Visible = true
    applyResponsiveProperties(UI.LeftPanel, {Position = UDim2.fromOffset(sidebarCollapsed and -sidebarWidth or 0, headerHeight), Size = UDim2.fromOffset(sidebarWidth, contentHeight)}, speed)
    applyResponsiveProperties(UI.RightPanel, {Position = UDim2.fromOffset(inspectorX, headerHeight), Size = UDim2.fromOffset(inspectorWidth, contentHeight)}, speed)
    applyResponsiveProperties(UI.PaneDivider, {Position = UDim2.fromOffset(sidebarWidth - 3, headerHeight), Size = UDim2.fromOffset(6, contentHeight)}, speed)
    UI.PaneDivider.Visible = not sidebarCollapsed

    local rightWidth = inspectorWidth - 19
    UI.InspectorTabs.Visible = useInspectorTabs

    if useInspectorTabs then
        local tabHeight = 30
        local panelY = 38
        local actionsHeight = 44
        local actionsY = contentHeight - actionsHeight - 3
        local panelHeight = math.max(64, actionsY - panelY - 5)
        local remoteHeight = math.min(116, panelHeight)
        applyResponsiveProperties(UI.InspectorTabs, {Position = UDim2.fromOffset(9, 4), Size = UDim2.fromOffset(rightWidth, tabHeight)}, speed)

        local tabsWidth = math.max(3, rightWidth - 2)
        local baseTabWidth = math.floor(tabsWidth / 3)
        local tabX = 1
        for index, tabName in ipairs({"Remote", "Args", "Code"}) do
            local tabWidth = index == 3 and tabsWidth - baseTabWidth * 2 or baseTabWidth
            local selectedTab = UI.Layout.InspectorTab == tabName
            local tabButton = UI.InspectorTabButtons[tabName]
            tabButton.Position = UDim2.fromOffset(tabX, 1)
            tabButton.Size = UDim2.fromOffset(tabWidth, tabHeight - 2)
            tabButton.BackgroundColor3 = Quantum.Panel
            tabButton.TextColor3 = selectedTab and Quantum.Text or Quantum.TextMuted
            UI.InspectorTabAccents[tabName].BackgroundTransparency = selectedTab and 0 or 1
            tabX += tabWidth
        end

        local selectedTab = UI.Layout.InspectorTab
        UI.InspectorHeader.Visible = selectedTab == "Remote"
        UI.ArgumentsSection.Visible = selectedTab == "Args"
        UI.CodeSection.Visible = selectedTab == "Code"
        UI.ActionsSection.Visible = true
        local panelProperties = {Position = UDim2.fromOffset(9, panelY), Size = UDim2.fromOffset(rightWidth, panelHeight)}
        applyResponsiveProperties(UI.InspectorHeader, {Position = UDim2.fromOffset(9, panelY), Size = UDim2.fromOffset(rightWidth, remoteHeight)}, speed)
        applyResponsiveProperties(UI.ArgumentsSection, panelProperties, speed)
        applyResponsiveProperties(UI.CodeSection, panelProperties, speed)
        applyResponsiveProperties(UI.ActionsSection, {Position = UDim2.fromOffset(9, actionsY), Size = UDim2.fromOffset(rightWidth, actionsHeight)}, speed)
        applyResponsiveProperties(UI.RemoteContent, {Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16)}, speed)
        applyResponsiveProperties(UI.ActionsContent, {Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -8)}, speed)
        UI.ActionsOverflowButton.Visible = true
    else
        UI.InspectorHeader.Visible = true
        UI.ArgumentsSection.Visible = true
        UI.CodeSection.Visible = true
        UI.ActionsSection.Visible = true
        UI.ActionsOverflowButton.Visible = false
        UI.ActionsOverflowMenu.Visible = false
        applyResponsiveProperties(UI.RemoteContent, {Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16)}, speed)
        applyResponsiveProperties(UI.ActionsContent, {Position = UDim2.fromOffset(8, 9), Size = UDim2.new(1, -16, 1, -17)}, speed)
        applyResponsiveProperties(UI.ActionsScroller, {Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6)}, speed)

        local topInset = 8
        local bottomInset = 2
        local sectionGap = 8
        local usableHeight = contentHeight - topInset - bottomInset - sectionGap * 3
        local remoteHeight = math.clamp(math.round(usableHeight * 0.15), 74, 104)
        local argumentsHeight = math.clamp(math.round(usableHeight * 0.23), 90, 180)
        local actionsHeight = math.clamp(math.round(usableHeight * 0.20), 93, 116)
        local codeHeight = usableHeight - remoteHeight - argumentsHeight - actionsHeight
        local argumentsY = topInset + remoteHeight + sectionGap
        local codeY = argumentsY + argumentsHeight + sectionGap
        local actionsY = codeY + codeHeight + sectionGap

        applyResponsiveProperties(UI.InspectorHeader, {Position = UDim2.fromOffset(9, topInset), Size = UDim2.fromOffset(rightWidth, remoteHeight)}, speed)
        applyResponsiveProperties(UI.ArgumentsSection, {Position = UDim2.fromOffset(9, argumentsY), Size = UDim2.fromOffset(rightWidth, argumentsHeight)}, speed)
        applyResponsiveProperties(UI.CodeSection, {Position = UDim2.fromOffset(9, codeY), Size = UDim2.fromOffset(rightWidth, codeHeight)}, speed)
        applyResponsiveProperties(UI.ActionsSection, {Position = UDim2.fromOffset(9, actionsY), Size = UDim2.fromOffset(rightWidth, actionsHeight)}, speed)
    end

    if UI.Layout.CompactMetadata ~= useInspectorTabs then
        UI.Layout.CompactMetadata = useInspectorTabs
        local rowHeight = useInspectorTabs and 14 or 9
        for _, row in next, UI.InspectorProperties:GetChildren() do
            if row:IsA("Frame") then
                row.Size = UDim2.new(1, 0, 0, rowHeight)
                for _, label in next, row:GetChildren() do
                    if label:IsA("TextLabel") then
                        label.Size = UDim2.new(label.Size.X.Scale, label.Size.X.Offset, 0, rowHeight)
                    end
                end
            end
        end
    end

    if updateFunctionCanvas then
        updateFunctionCanvas()
    end
end

for tabName, tabButton in next, UI.InspectorTabButtons do
    table.insert(connections, tabButton.MouseButton1Click:Connect(function()
        setInspectorTab(tabName)
    end))
end
table.insert(connections, UI.SidebarToggle.MouseButton1Click:Connect(function()
    closeContextMenu()
    UI.Layout.SidebarUserOverride = true
    UI.Layout.SidebarCollapsed = not UI.Layout.SidebarCollapsed
    updateResponsiveLayout(0, true)
end))

--- Adjusts the ui elements to the expanded layout.
function maximizeSize(speed)
    updateResponsiveLayout(speed or 0.08, false)
end

--- Adjusts the ui elements while the inspector tray is closed.
function minimizeSize(speed)
    updateResponsiveLayout(speed or 0.08, true)
end

function updateWindowResize(mousePosition)
    local resize = UI.Resize
    if not resize.Active or not resize.Direction then
        return
    end

    local margin = 4
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local maximumSize = getMaximumWindowSize(viewportSize)
    local maximumRight = math.round(viewportSize.X - margin)
    local maximumBottom = math.round(viewportSize.Y - GuiInset.Y - margin)
    local delta = mousePosition - resize.StartMouse
    local direction = resize.Direction
    local startRight = resize.StartPosition.X + resize.StartSize.X
    local startBottom = resize.StartPosition.Y + resize.StartSize.Y
    local x = resize.StartPosition.X
    local y = resize.StartPosition.Y
    local width = resize.StartSize.X
    local height = resize.StartSize.Y

    if direction:find("L", 1, true) then
        local minimumLeft = math.max(margin, startRight - maximumSize.X)
        x = math.clamp(math.round(resize.StartPosition.X + delta.X), minimumLeft, startRight - MINIMUM_WIDTH)
        width = startRight - x
    elseif direction:find("R", 1, true) then
        local allowedRight = math.min(maximumRight, resize.StartPosition.X + maximumSize.X)
        local right = math.clamp(math.round(startRight + delta.X), resize.StartPosition.X + MINIMUM_WIDTH, allowedRight)
        width = right - resize.StartPosition.X
    end

    if direction:find("T", 1, true) then
        local minimumTop = math.max(margin, startBottom - maximumSize.Y)
        y = math.clamp(math.round(resize.StartPosition.Y + delta.Y), minimumTop, startBottom - MINIMUM_HEIGHT)
        height = startBottom - y
    elseif direction:find("B", 1, true) then
        local allowedBottom = math.min(maximumBottom, resize.StartPosition.Y + maximumSize.Y)
        local bottom = math.clamp(math.round(startBottom + delta.Y), resize.StartPosition.Y + MINIMUM_HEIGHT, allowedBottom)
        height = bottom - resize.StartPosition.Y
    end

    UI.Background.Position = UDim2.fromOffset(math.round(x), math.round(y))
    UI.Background.Size = UDim2.fromOffset(math.round(width), math.round(height))
end

table.insert(connections, UI.PaneDivider.MouseEnter:Connect(function()
    quantumTween(UI.PaneDividerLine, {BackgroundColor3 = Quantum.Accent}, 0.1)
end))
table.insert(connections, UI.PaneDivider.MouseLeave:Connect(function()
    if not UI.Layout.DividerDragging then
        quantumTween(UI.PaneDividerLine, {BackgroundColor3 = Quantum.BorderSubtle}, 0.1)
    end
end))
table.insert(connections, UI.PaneDivider.MouseButton1Down:Connect(function()
    if not closed and not sideClosed then
        UI.Layout.DividerDragging = true
        UI.PaneDividerLine.BackgroundColor3 = Quantum.Accent
    end
end))
table.insert(connections, UserInputService.InputChanged:Connect(function(input)
    if UI.Resize.Active and input.UserInputType == Enum.UserInputType.MouseMovement then
        updateWindowResize(UserInputService:GetMouseLocation() - GuiInset)
    elseif UI.Layout.DividerDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        UI.Layout.SidebarWidth = math.round(UserInputService:GetMouseLocation().X - GuiInset.X - UI.Background.AbsolutePosition.X)
        updateResponsiveLayout(0, true)
    end
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UI.Resize.Active then
            UI.Resize.Active = false
            UI.Resize.Direction = nil
            UI.Resize.StartMouse = nil
            UI.Resize.StartPosition = nil
            UI.Resize.StartSize = nil
        end
        if UI.Layout.DividerDragging then
            UI.Layout.DividerDragging = false
            quantumTween(UI.PaneDividerLine, {BackgroundColor3 = Quantum.BorderSubtle}, 0.12)
        end
    end
end))

--- Ensures size is within screensize limitations
function validateSize()
    local margin = 4
    local screenSize = workspace.CurrentCamera.ViewportSize
    local maximumSize = getMaximumWindowSize(screenSize)
    UI.BackgroundConstraint.MaxSize = Vector2.new(maximumSize.X, closed and HEADER_HEIGHT or maximumSize.Y)
    local position = UI.Background.AbsolutePosition
    local availableWidth = math.max(MINIMUM_WIDTH, math.min(maximumSize.X, screenSize.X - margin - position.X))
    local width = math.clamp(math.round(UI.Background.AbsoluteSize.X), MINIMUM_WIDTH, availableWidth)
    local minimumHeight = closed and HEADER_HEIGHT or MINIMUM_HEIGHT
    local availableHeight = math.max(minimumHeight, math.min(maximumSize.Y, screenSize.Y - GuiInset.Y - margin - position.Y))
    local height = math.clamp(math.round(UI.Background.AbsoluteSize.Y), minimumHeight, availableHeight)
    UI.Background.Size = UDim2.fromOffset(width, height)
end

--- Called on user input while mouse in 'Background' frame
--- @param input InputObject
function backgroundUserInput(input)
    local controlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
    local focusedTextBox = UserInputService:GetFocusedTextBox()
    if input.UserInputType == Enum.UserInputType.MouseButton1 and UI.ActionsOverflowMenu.Visible then
        local pointer = UserInputService:GetMouseLocation() - GuiInset
        local menuPosition = UI.ActionsOverflowMenu.AbsolutePosition
        local menuSize = UI.ActionsOverflowMenu.AbsoluteSize
        local buttonPosition = UI.ActionsOverflowButton.AbsolutePosition
        local buttonSize = UI.ActionsOverflowButton.AbsoluteSize
        local insideMenu = pointer.X >= menuPosition.X and pointer.X <= menuPosition.X + menuSize.X and pointer.Y >= menuPosition.Y and pointer.Y <= menuPosition.Y + menuSize.Y
        local insideButton = pointer.X >= buttonPosition.X and pointer.X <= buttonPosition.X + buttonSize.X and pointer.Y >= buttonPosition.Y and pointer.Y <= buttonPosition.Y + buttonSize.Y
        if not insideMenu and not insideButton then
            UI.ActionsOverflowMenu.Visible = false
        end
    end
    if input.KeyCode == Enum.KeyCode.Escape then
        closeContextMenu()
        if focusedTextBox then
            focusedTextBox:ReleaseFocus()
        end
        return
    end
    if input.KeyCode == Enum.KeyCode.F and controlDown then
        UI.FilterInput:CaptureFocus()
        return
    end
    if input.KeyCode == Enum.KeyCode.C and controlDown and selected and not focusedTextBox then
        runContextAction("Copy Code")
        return
    end
    if input.KeyCode == Enum.KeyCode.L and controlDown and not focusedTextBox then
        runContextAction("Clear")
        return
    end
    local mousePos = UserInputService:GetMouseLocation() - GuiInset
    local inResizeRange, resizeDirection = isInResizeRange(mousePos)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and inResizeRange and not closed then
        UI.Resize.Active = true
        UI.Resize.Direction = resizeDirection
        UI.Resize.StartMouse = mousePos
        UI.Resize.StartPosition = Vector2.new(math.round(UI.Background.AbsolutePosition.X), math.round(UI.Background.AbsolutePosition.Y))
        UI.Resize.StartSize = Vector2.new(math.round(UI.Background.AbsoluteSize.X), math.round(UI.Background.AbsoluteSize.Y))
    elseif isInDragRange(mousePos) then
        onBarInput(input)
    end
end

--- Gets the player an instance is descended from
function getPlayerFromInstance(instance)
    for _, v in next, Players:GetPlayers() do
        if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then
            return v
        end
    end
end

local function formatArgumentValue(value)
    local valueType = typeof(value)
    local preview
    if valueType == "string" then
        preview = string.format("%q", value)
    elseif valueType == "table" then
        preview = "{ ... }"
    elseif valueType == "Instance" then
        preview = value:GetFullName()
    else
        preview = rawtostring(value)
    end
    if #preview > 58 then
        preview = preview:sub(1, 55) .. "..."
    end
    return lower(valueType), preview
end

local argumentTypeColors = {
    string = Quantum.Success,
    number = Quantum.Cyan,
    boolean = Quantum.Warning,
    table = Quantum.Violet,
    instance = Quantum.Accent,
}

local function renderArgumentTree(args, owner)
    for _, child in next, UI.ArgumentsScroll:GetChildren() do
        if child.Name == "ArgumentRow" then
            child:Destroy()
        end
    end
    local count = args and (args.n or #args) or 0
    if count == 0 then
        UI.ArgumentsText.Text = owner and "0 arguments" or "no arguments"
        UI.ArgumentsText.Visible = true
        return
    end

    UI.ArgumentsText.Visible = false
    owner.ArgumentExpansion = owner.ArgumentExpansion or {}
    local expansion = owner.ArgumentExpansion
    local rowOrder = 0

    local function addRow(key, value, depth, path, ancestors)
        if rowOrder >= 80 then
            return
        end
        rowOrder += 1
        local valueType, preview = formatArgumentValue(value)
        local isTable = valueType == "table"
        local isExpanded = isTable and expansion[path] == true
        local row = Create("Frame",{Name = "ArgumentRow",Parent = UI.ArgumentsScroll,BackgroundColor3 = Quantum.Hover,BackgroundTransparency = 1,BorderSizePixel = 0,LayoutOrder = rowOrder,Size = UDim2.new(1, -12, 0, 18),ZIndex = 3})
        local indentOffset = 6 + depth * 14
        local keyButton = Create("TextButton",{Parent = row,Active = isTable,AutoButtonColor = false,BackgroundTransparency = 1,Position = UDim2.fromOffset(indentOffset, 0),Size = UDim2.new(0.42, -indentOffset, 1, 0),Font = Enum.Font.Code,Text = (isTable and (isExpanded and "▼ " or "▶ ") or "  ") .. key,TextColor3 = Quantum.TextSecondary,TextSize = 10,TextTruncate = Enum.TextTruncate.AtEnd,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 4})
        Create("TextLabel",{Parent = row,BackgroundTransparency = 1,Position = UDim2.new(0.42, 4, 0, 0),Size = UDim2.fromOffset(62, 18),Font = Enum.Font.Code,Text = valueType,TextColor3 = argumentTypeColors[valueType] or Quantum.TextMuted,TextSize = 9,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 4})
        local valueText = Create("TextLabel",{Parent = row,BackgroundTransparency = 1,Position = UDim2.new(0.42, 68, 0, 0),Size = UDim2.new(0.58, -74, 0, 18),Font = Enum.Font.Code,Text = preview,TextColor3 = Quantum.TextMuted,TextSize = 9,TextTruncate = Enum.TextTruncate.AtEnd,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 4})

        keyButton.MouseEnter:Connect(function()
            quantumTween(row, {BackgroundTransparency = 0.35}, 0.1)
        end)
        keyButton.MouseLeave:Connect(function()
            quantumTween(row, {BackgroundTransparency = 1}, 0.1)
        end)

        if not isTable then
            return
        end

        local keys = {}
        for childKey in next, value do
            keys[#keys + 1] = childKey
        end
        table.sort(keys, function(a, b)
            return rawtostring(a) < rawtostring(b)
        end)
        valueText.Text = string.format("{%d}", #keys)
        keyButton.MouseButton1Click:Connect(function()
            expansion[path] = not isExpanded
            if selected == owner then
                renderArgumentTree(args, owner)
            end
        end)

        if not isExpanded then
            return
        end
        if ancestors[value] then
            valueText.Text = "<cycle>"
            return
        end
        if depth >= 4 then
            valueText.Text = "{…}"
            return
        end

        ancestors[value] = true
        for _, childKey in next, keys do
            if rowOrder >= 80 then
                break
            end
            local childLabel = typeof(childKey) == "string" and childKey or "[" .. rawtostring(childKey) .. "]"
            addRow(childLabel, value[childKey], depth + 1, path .. "/" .. rawtostring(childKey), ancestors)
        end
        ancestors[value] = nil
    end

    for index = 1, math.min(count, 24) do
        addRow("[" .. index .. "]", args[index], 0, rawtostring(index), {})
    end
end

local function getRemoteCallCount(log)
    local group = log and remoteGroups[log.GroupKey]
    if group and group.Row and group.Row.Parent then
        return group.count
    end
    local count = 0
    for _, existing in next, logs do
        if existing.GroupKey == log.GroupKey and existing.Log and existing.Log.Parent then
            count += 1
        end
    end
    return count
end

--- Selects a captured remote log and populates the inspector.
--- Accepts the captured log directly; frame lookup remains as a compatibility fallback.
function eventSelect(selection)
    local nextSelected = typeof(selection) == "table" and selection.Log and selection or nil
    if not nextSelected then
        for _, log in next, logs do
            if selection == log.Log then
                nextSelected = log
                break
            end
        end
    end
    if selected and selected.Log and (not nextSelected or selected.Log ~= nextSelected.Log) then
        styleRemoteRow(selected, false)
    end
    selected = nextSelected
    if selected and selected.Log then
        styleRemoteRow(selected, true)
        UI.InspectorSelection.Text = string.format("%s / %s", selected.Name, selected.Method or "remote")
        UI.InspectorSelection.TextColor3 = Quantum.TextSecondary
        UI.RemoteNameValue.Text = selected.Name
        UI.RemoteTypeValue.Text = selected.Remote.ClassName
        UI.RemoteMethodValue.Text = selected.Method or "—"
        UI.RemoteCallsValue.Text = tostring(getRemoteCallCount(selected))
        UI.RemotePathValue.Text = selected.RemotePath or "—"
        local source = selected.Source
        UI.RemoteScriptValue.Text = typeof(source) == "Instance" and source.Name or typeof(source) == "string" and source or "—"
        UI.RemoteNameValue.TextColor3 = Quantum.Text
        UI.RemoteTypeValue.TextColor3 = Quantum.TextSecondary
        UI.RemoteMethodValue.TextColor3 = Quantum.Cyan
        UI.RemoteCallsValue.TextColor3 = Quantum.Text
        UI.RemotePathValue.TextColor3 = Quantum.TextSecondary
        UI.RemoteScriptValue.TextColor3 = Quantum.TextSecondary
        UI.ArgumentsScroll.CanvasPosition = Vector2.zero
        renderArgumentTree(selected.args, selected)
        quantumTween(UI.CodeBox, {BackgroundColor3 = Quantum.Surface}, 0.07)
        codebox:setRaw(selected.GenScript)
        quantumTween(UI.CodeBox, {BackgroundColor3 = Quantum.Editor}, 0.12)
    else
        resetQuantumInspector()
    end
    if UI.Layout.UseInspectorTabs then
        UI.Layout.InspectorTab = selected and "Code" or "Remote"
        updateResponsiveLayout(0, true)
    end
    updateQuantumStatus()
    if sideClosed then
        toggleSideTray()
    end
end

--- Updates the canvas size to fit the current amount of function buttons
function updateFunctionCanvas()
    local compactActions = UI.Layout.UseInspectorTabs
    if UI.Layout.CompactActions ~= compactActions then
        UI.Layout.CompactActions = compactActions
        for actionName, template in next, UI.ActionTemplates do
            local compactLabel = UI.PrimaryActionLabels[actionName]
            template.Visible = not compactActions or compactLabel ~= nil
            UI.ActionButtons[actionName].Text = compactActions and compactLabel or lower(actionName)
        end
    end

    local gap = compactActions and 4 or 6
    if compactActions then
        local availableWidth = math.max(6, math.round(UI.ActionsContent.AbsoluteSize.X) - 2)
        local buttonWidth = math.max(1, math.floor((availableWidth - gap * 5) / 6))
        local primaryWidth = buttonWidth * 5 + gap * 4
        UI.ActionsScroller.Position = UDim2.fromOffset(1, 4)
        UI.ActionsScroller.Size = UDim2.fromOffset(primaryWidth, 28)
        UI.ActionsOverflowButton.Position = UDim2.fromOffset(1 + primaryWidth + gap, 4)
        UI.ActionsOverflowButton.Size = UDim2.fromOffset(buttonWidth, 28)
        UI.ActionsScroller.ScrollingDirection = Enum.ScrollingDirection.Y
        UI.ActionsScroller.ScrollBarThickness = 0
        UI.ActionsPadding.PaddingLeft = UDim.new(0, 0)
        UI.ActionsPadding.PaddingRight = UDim.new(0, 0)
        UI.ActionsPadding.PaddingTop = UDim.new(0, 0)
        UI.ActionsPadding.PaddingBottom = UDim.new(0, 0)
        UI.ActionsGrid.CellPadding = UDim2.fromOffset(gap, 0)
        UI.ActionsGrid.FillDirectionMaxCells = 5
        UI.ActionsGrid.CellSize = UDim2.fromOffset(buttonWidth, 28)
        UI.ActionsScroller.CanvasSize = UDim2.fromOffset(0, 0)
        return
    end

    local usableWidth = UI.ActionsScroller.AbsoluteSize.X - 6
    if usableWidth <= 0 then
        return
    end
    UI.ActionsScroller.ScrollingDirection = Enum.ScrollingDirection.Y
    UI.ActionsScroller.ScrollBarThickness = 2
    UI.ActionsPadding.PaddingLeft = UDim.new(0, 3)
    UI.ActionsPadding.PaddingRight = UDim.new(0, 3)
    UI.ActionsPadding.PaddingTop = UDim.new(0, 3)
    UI.ActionsPadding.PaddingBottom = UDim.new(0, 3)
    UI.ActionsGrid.CellPadding = UDim2.fromOffset(gap, gap)
    local columns = math.clamp(math.floor((usableWidth + gap) / 86), 1, 5)
    local buttonWidth = math.max(64, math.floor((usableWidth - gap * (columns - 1)) / columns))
    local targetSize = UDim2.fromOffset(buttonWidth, 28)
    if UI.ActionsGrid.FillDirectionMaxCells ~= columns then
        UI.ActionsGrid.FillDirectionMaxCells = columns
    end
    if UI.ActionsGrid.CellSize ~= targetSize then
        UI.ActionsGrid.CellSize = targetSize
    end
    UI.ActionsScroller.CanvasSize = UDim2.fromOffset(0, UI.ActionsGrid.AbsoluteContentSize.Y + 6)
end

--- Updates the canvas size to fit the amount of current remotes
function updateRemoteCanvas()
    UI.LogList.CanvasSize = UDim2.fromOffset(UI.RemoteListLayout.AbsoluteContentSize.X, UI.RemoteListLayout.AbsoluteContentSize.Y + 6)
end

table.insert(connections, UI.ActionsGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateFunctionCanvas))
table.insert(connections, UI.ActionsScroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateFunctionCanvas))
table.insert(connections, UI.ActionsContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateFunctionCanvas))
table.insert(connections, UI.RemoteListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateRemoteCanvas))
table.insert(connections, UI.Background:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    UI.ActionsOverflowMenu.Visible = false
    updateResponsiveLayout(0, false)
end))

--- Allows for toggling of the tooltip and easy setting of le description
--- @param enable boolean
--- @param text string
function makeToolTip(enable, text)
    if enable and text then
        if UI.ToolTip.Visible then
            UI.ToolTip.Visible = false
            local tooltip = connections["ToolTip"]
            if tooltip then
                tooltip:Disconnect()
            end
        end
        local first = true
        connections["ToolTip"] = RunService.RenderStepped:Connect(function()
            local MousePos = UserInputService:GetMouseLocation()
            local topLeft = MousePos + Vector2.new(20, -15)
            local bottomRight = topLeft + UI.ToolTip.AbsoluteSize
            local ViewportSize = workspace.CurrentCamera.ViewportSize
            local ViewportSizeX = ViewportSize.X
            local ViewportSizeY = ViewportSize.Y

            if topLeft.X < 0 then
                topLeft = Vector2.new(0, topLeft.Y)
            elseif bottomRight.X > ViewportSizeX then
                topLeft = Vector2.new(ViewportSizeX - UI.ToolTip.AbsoluteSize.X, topLeft.Y)
            end
            if topLeft.Y < 0 then
                topLeft = Vector2.new(topLeft.X, 0)
            elseif bottomRight.Y > ViewportSizeY - 35 then
                topLeft = Vector2.new(topLeft.X, ViewportSizeY - UI.ToolTip.AbsoluteSize.Y - 35)
            end
            if topLeft.X <= MousePos.X and topLeft.Y <= MousePos.Y then
                topLeft = Vector2.new(MousePos.X - UI.ToolTip.AbsoluteSize.X - 2, MousePos.Y - UI.ToolTip.AbsoluteSize.Y - 2)
            end
            if first then
                UI.ToolTip.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
                first = false
            else
                UI.ToolTip:TweenPosition(UDim2.fromOffset(topLeft.X, topLeft.Y), "Out", "Linear", 0.1)
            end
        end)
        UI.TooltipText.Text = text
        UI.TooltipText.TextScaled = true
        UI.ToolTip.Visible = true
        return
    else
        if UI.ToolTip.Visible then
            UI.ToolTip.Visible = false
            local tooltip = connections["ToolTip"]
            if tooltip then
                tooltip:Disconnect()
            end
        end
    end
end

--- Creates new function button (below codebox)
--- @param name string
---@param description function
---@param onClick function
function newButton(name, description, onClick)
    actionHandlers[name] = function(...)
        logthread(running())
        return onClick(...)
    end
    local isPrimary = name == "Run Code"
    local FunctionTemplate, Button, Text, ButtonStroke = createToolbarButton(UI.ActionsScroller, name, isPrimary)
    local compactLabel = UI.PrimaryActionLabels[name]
    UI.ActionTemplates[name] = FunctionTemplate
    UI.ActionButtons[name] = Button
    FunctionTemplate.Visible = not UI.Layout.UseInspectorTabs or compactLabel ~= nil
    Button.Text = UI.Layout.UseInspectorTabs and compactLabel or lower(name)

    if not compactLabel then
        UI.Layout.OverflowOrder += 1
        local overflowLabel = name == "Clr Logs" and "clear logs" or name == "Clr Blacklist" and "clear blacklist" or lower(name)
        local overflowButton = Create("TextButton",{Name = name,Parent = UI.ActionsOverflowScroll,BackgroundColor3 = Quantum.SurfaceRaised,BorderSizePixel = 0,LayoutOrder = UI.Layout.OverflowOrder,Size = UDim2.new(1, -4, 0, 23),AutoButtonColor = false,Font = Enum.Font.Code,Text = overflowLabel,TextColor3 = Quantum.TextSecondary,TextSize = 9,TextTruncate = Enum.TextTruncate.AtEnd,TextXAlignment = Enum.TextXAlignment.Left,ZIndex = 36})
        Create("UIPadding",{Parent = overflowButton,PaddingLeft = UDim.new(0, 7),PaddingRight = UDim.new(0, 7)})
        styleButton(overflowButton, Quantum.SurfaceRaised, Quantum.Hover, Quantum.Panel)
        overflowButton.MouseButton1Click:Connect(function(...)
            UI.ActionsOverflowMenu.Visible = false
            actionHandlers[name](FunctionTemplate, ...)
        end)
        UI.ActionOverflowButtons[name] = overflowButton
    end

    Button.MouseEnter:Connect(function()
        quantumTween(ButtonStroke, {Color = isPrimary and Quantum.Accent or Quantum.Border}, 0.1)
        makeToolTip(true, description())
    end)
    Button.MouseLeave:Connect(function()
        quantumTween(ButtonStroke, {Color = isPrimary and Quantum.Accent or Quantum.ButtonBorder}, 0.1)
        makeToolTip(false)
    end)
    FunctionTemplate.AncestryChanged:Connect(function()
        makeToolTip(false)
    end)
    Button.MouseButton1Click:Connect(function(...)
        actionHandlers[name](FunctionTemplate, ...)
        if name:sub(1, 4) == "Copy" then
            Text.Text = "copied"
            Text.TextColor3 = Quantum.Success
            delay(1, function()
                if Text.Parent then
                    Text.Text = UI.Layout.UseInspectorTabs and (UI.PrimaryActionLabels[name] or lower(name)) or lower(name)
                    Text.TextColor3 = Quantum.TextSecondary
                end
            end)
        end
    end)
    updateFunctionCanvas()
end

--- Adds new Remote to logs
--- @param name string The name of the remote being logged
--- @param type string The type of the remote being logged (either 'function' or 'event')
--- @param args any
--- @param remote any
--- @param function_info string
--- @param blocked any
function newRemote(type, data)
    if layoutOrderNum < 1 then layoutOrderNum = 999999999 end
    local remote = data.remote
    local callingscript = data.callingscript
    local remotePath = remote:GetFullName()
    local typeColor = type == "event" and Quantum.Accent or Quantum.Violet
    local methodLabel = type == "event" and "FireServer" or "InvokeServer"
    local groupMethod = data.method or methodLabel
    local groupKey = rawtostring(data.id or remotePath) .. "\0" .. lower(groupMethod)

    local log = {
        Name = remote.name,
        Function = data.infofunc or "--Function Info is disabled",
        Remote = remote,
        DebugId = data.id,
        metamethod = data.metamethod,
        args = data.args,
        RemotePath = remotePath,
        Method = groupMethod,
        Blocked = data.blocked,
        Source = callingscript,
        returnvalue = data.returnvalue,
        GenScript = "-- Generating, please wait...\n-- (If this message persists, the remote args are likely extremely long)",
        GroupKey = groupKey
    }
    logs[#logs + 1] = log

    local group = remoteGroups[groupKey]
    if group and group.Row and group.Row.Parent then
        group.latestCall = log
        group.count += 1
        log.Log = group.Row
        log.Button = group.Button
        log.SelectionBar = group.SelectionBar
        log.PrimaryText = group.PrimaryText
        log.MetaText = group.MetaText
        log.CountText = group.CountText
        group.CountText.Text = string.format("×%d", group.count)
        if selected and selected.GroupKey == groupKey then
            UI.RemoteCallsValue.Text = tostring(group.count)
        end
        updateQuantumStatus()
        return
    elseif group then
        remoteGroups[groupKey] = nil
    end

    local RemoteTemplate = Create("Frame",{LayoutOrder = layoutOrderNum,Name = "RemoteTemplate",Parent = UI.LogList,Active = false,BackgroundTransparency = 1,Size = UDim2.new(1, -2, 0, 36)})
    local Button = Create("TextButton",{Name = "Button",Parent = RemoteTemplate,Active = true,BackgroundColor3 = Quantum.InnerSurface,BackgroundTransparency = 1,BorderSizePixel = 0,Size = UDim2.fromScale(1, 1),AutoButtonColor = false,ClipsDescendants = true,Text = "",ZIndex = 2})
    addCorner(Button, 2)
    local ButtonScale = Create("UIScale",{Parent = Button,Scale = 1})
    local SelectionBar = Create("Frame",{Name = "SelectionBar",Parent = Button,Active = false,BackgroundColor3 = Quantum.Accent,BackgroundTransparency = 1,BorderSizePixel = 0,Position = UDim2.fromOffset(0, 2),Size = UDim2.fromOffset(2, 32),ZIndex = 4})
    addCorner(SelectionBar, 1)
    local compactRow = UI.Layout.CompactRows
    local ColorBar = Create("Frame",{Name = "ColorBar",Parent = Button,Active = false,BackgroundColor3 = typeColor,BorderSizePixel = 0,Position = UDim2.fromOffset(compactRow and 6 or 9, 7),Size = UDim2.fromOffset(6, 6),ZIndex = 3})
    addCorner(ColorBar, 1)
    local Text = Create("TextLabel",{TextTruncate = Enum.TextTruncate.AtEnd,Name = "Text",Parent = Button,Active = false,BackgroundTransparency = 1,Position = UDim2.fromOffset(compactRow and 18 or 22, 1),Size = UDim2.new(1, compactRow and -70 or -80, 0, 16),ZIndex = 3,Font = Enum.Font.Code,Text = remote.Name,TextColor3 = Quantum.Text,TextSize = 11,TextXAlignment = Enum.TextXAlignment.Left})
    local PathText = Create("TextLabel",{TextTruncate = Enum.TextTruncate.AtEnd,Name = "Method",Parent = Button,Active = false,BackgroundTransparency = 1,Position = UDim2.fromOffset(compactRow and 18 or 22, 18),Size = UDim2.new(1, compactRow and -28 or -34, 0, 13),ZIndex = 3,Font = Enum.Font.Code,Text = methodLabel,TextColor3 = Quantum.TextMuted,TextSize = 9,TextXAlignment = Enum.TextXAlignment.Left})
    local CountText = Create("TextLabel",{Name = "Count",Parent = Button,Active = false,BackgroundTransparency = 1,Position = UDim2.new(1, compactRow and -49 or -54, 0, 1),Size = UDim2.fromOffset(compactRow and 40 or 44, 16),ZIndex = 3,Font = Enum.Font.Code,Text = "×1",TextColor3 = Quantum.TextMuted,TextSize = 9,TextTruncate = Enum.TextTruncate.AtEnd,TextXAlignment = Enum.TextXAlignment.Right})

    log.Log = RemoteTemplate
    log.Button = Button
    log.SelectionBar = SelectionBar
    log.PrimaryText = Text
    log.MetaText = PathText
    log.CountText = CountText
    group = {
        Row = RemoteTemplate,
        Button = Button,
        SelectionBar = SelectionBar,
        TypeIndicator = ColorBar,
        PrimaryText = Text,
        MetaText = PathText,
        CountText = CountText,
        Name = log.Name,
        RemotePath = remotePath,
        Method = groupMethod,
        latestCall = log,
        count = 1
    }
    remoteGroups[groupKey] = group
    Button.MouseEnter:Connect(function()
        if not selected or selected.GroupKey ~= groupKey then
            quantumTween(Button, {BackgroundColor3 = Quantum.Hover, BackgroundTransparency = 0}, 0.1)
        end
    end)
    Button.MouseLeave:Connect(function()
        styleRemoteRow(group.latestCall, selected and selected.GroupKey == groupKey)
        quantumTween(ButtonScale, {Scale = 1}, 0.08)
    end)
    Button.MouseButton1Down:Connect(function() quantumTween(ButtonScale, {Scale = 0.99}, 0.07) end)
    Button.MouseButton1Up:Connect(function() quantumTween(ButtonScale, {Scale = 1}, 0.08) end)
    local function selectRemote()
        local latestCall = group.latestCall
        if not latestCall then
            return
        end
        logthread(running())
        eventSelect(latestCall)
        latestCall.GenScript = genScript(latestCall.Remote, latestCall.args)
        if latestCall.Blocked then
            latestCall.GenScript = "-- THIS REMOTE WAS PREVENTED FROM FIRING TO THE SERVER BY SIMPLESPY\n\n" .. latestCall.GenScript
        end
        if selected == latestCall and RemoteTemplate.Parent then
            eventSelect(latestCall)
        end
    end
    local connect = Button.MouseButton1Click:Connect(selectRemote)
    Button.MouseButton2Click:Connect(function()
        selectRemote()
        openContextMenu()
    end)
    layoutOrderNum -= 1
    table.insert(remoteLogs, 1, {connect, RemoteTemplate, groupKey})
    clean()
    updateRemoteCanvas()
    applyRemoteFilter()
    updateQuantumStatus()
end

--- Generates a script from the provided arguments (first has to be remote path)
function genScript(remote, args)
    prevTables = {}
    local gen = ""
    if #args > 0 then
        xpcall(function()
            gen = v2v({args = args}) .. "\n"
        end,function(err)
            gen ..= "-- An error has occured:\n--"..err.."\n-- TableToString failure! Reverting to legacy functionality (results may vary)\nlocal args = {"
            xpcall(function()
                for i, v in next, args do
                    if type(i) ~= "Instance" and type(i) ~= "userdata" then
                        gen = gen .. "\n    [object] = "
                    elseif type(i) == "string" then
                        gen = gen .. '\n    ["' .. i .. '"] = '
                    elseif type(i) == "userdata" and typeof(i) ~= "Instance" then
                        gen = gen .. "\n    [" .. string.format("nil --[[%s]]", typeof(v)) .. ")] = "
                    elseif type(i) == "userdata" then
                         gen = gen .. "\n    [game." .. i:GetFullName() .. ")] = "
                    end
                    if type(v) ~= "Instance" and type(v) ~= "userdata" then
                        gen = gen .. "object"
                    elseif type(v) == "string" then
                        gen = gen .. '"' .. v .. '"'
                    elseif type(v) == "userdata" and typeof(v) ~= "Instance" then
                        gen = gen .. string.format("nil --[[%s]]", typeof(v))
                    elseif type(v) == "userdata" then
                        gen = gen .. "game." .. v:GetFullName()
                    end
                end
                gen ..= "\n}\n\n"
            end,function()
                gen ..= "}\n-- Legacy tableToString failure! Unable to decompile."
            end)
        end)
        if not remote:IsDescendantOf(game) and not getnilrequired then
            gen = "function getNil(name,class) for _,v in next, getnilinstances()do if v.ClassName==class and v.Name==name then return v;end end end\n\n" .. gen
        end
        if remote:IsA("RemoteEvent") then
            gen ..= v2s(remote) .. ":FireServer(unpack(args))"
        elseif remote:IsA("RemoteFunction") then
            gen = gen .. v2s(remote) .. ":InvokeServer(unpack(args))"
        end
    else
        if remote:IsA("RemoteEvent") then
            gen ..= v2s(remote) .. ":FireServer()"
        elseif remote:IsA("RemoteFunction") then
            gen ..= v2s(remote) .. ":InvokeServer()"
        end
    end
    prevTables = {}
    return gen
end

--- value-to-string: value, string (out), level (indentation), parent table, var name, is from tovar
local CustomGeneration = {
    Vector3 = (function()
        local temp = {}
        for i,v in Vector3 do
            if type(v) == "vector" then
                temp[v] = `Vector3.{i}`
            end
        end
        return temp
    end)(),
    Vector2 = (function()
        local temp = {}
        for i,v in Vector2 do
            if type(v) == "userdata" then
                temp[v] = `Vector2.{i}`
            end
        end
        return temp
    end)(),
    CFrame = {
        [CFrame.identity] = "CFrame.identity"
    }
}

local number_table = {
    ["inf"] = "math.huge",
    ["-inf"] = "-math.huge",
    ["nan"] = "0/0"
}

local ufunctions
ufunctions = {
    TweenInfo = function(u)
        return `TweenInfo.new({u.Time}, {u.EasingStyle}, {u.EasingDirection}, {u.RepeatCount}, {u.Reverses}, {u.DelayTime})`
    end,
    Ray = function(u)
        local Vector3tostring = ufunctions["Vector3"]

        return `Ray.new({Vector3tostring(u.Origin)}, {Vector3tostring(u.Direction)})`
    end,
    BrickColor = function(u)
        return `BrickColor.new({u.Number})`
    end,
    NumberRange = function(u)
        return `NumberRange.new({u.Min}, {u.Max})`
    end,
    Region3 = function(u)
        local center = u.CFrame.Position
        local centersize = u.Size/2
        local Vector3tostring = ufunctions["Vector3"]

        return `Region3.new({Vector3tostring(center-centersize)}, {Vector3tostring(center+centersize)})`
    end,
    Faces = function(u)
        local faces = {}
        if u.Top then
            table.insert(faces, "Top")
        end
        if u.Bottom then
            table.insert(faces, "Enum.NormalId.Bottom")
        end
        if u.Left then
            table.insert(faces, "Enum.NormalId.Left")
        end
        if u.Right then
            table.insert(faces, "Enum.NormalId.Right")
        end
        if u.Back then
            table.insert(faces, "Enum.NormalId.Back")
        end
        if u.Front then
            table.insert(faces, "Enum.NormalId.Front")
        end
        return `Faces.new({table.concat(faces, ", ")})`
    end,
    EnumItem = function(u)
        return tostring(u)
    end,
    Enums = function(u)
        return "Enum"
    end,
    Enum = function(u)
        return `Enum.{u}`
    end,
    Vector3 = function(u)
        return CustomGeneration.Vector3[u] or `Vector3.new({u})`
    end,
    Vector2 = function(u)
        return CustomGeneration.Vector2[u] or `Vector2.new({u})`
    end,
    CFrame = function(u)
        return CustomGeneration.CFrame[u] or `CFrame.new({table.concat({u:GetComponents()},", ")})`
    end,
    PathWaypoint = function(u)
        return `PathWaypoint.new({ufunctions["Vector3"](u.Position)}, {u.Action}, "{u.Label}")`
    end,
    UDim = function(u)
        return `UDim.new({u})`
    end,
    UDim2 = function(u)
        return `UDim2.new({u})`
    end,
    Rect = function(u)
        local Vector2tostring = ufunctions["Vector2"]
        return `Rect.new({Vector2tostring(u.Min)}, {Vector2tostring(u.Max)})`
    end,
    Color3 = function(u)
        return `Color3.new({u.R}, {u.G}, {u.B})`
    end,
    RBXScriptSignal = function(u) -- The server doesnt recive this
        return "RBXScriptSignal --[[RBXScriptSignal's are not supported]]"
    end,
    RBXScriptConnection = function(u) -- The server doesnt recive this
        return "RBXScriptConnection --[[RBXScriptConnection's are not supported]]"
    end,
}

local typeofv2sfunctions = {
    number = function(v)
        local number = tostring(v)
        return number_table[number] or number
    end,
    boolean = function(v)
        return tostring(v)
    end,
    string = function(v,l)
        return formatstr(v, l)
    end,
    ["function"] = function(v) -- The server doesnt recive this
        return f2s(v)
    end,
    table = function(v, l, p, n, vtv, i, pt, path, tables, tI)
        return t2s(v, l, p, n, vtv, i, pt, path, tables, tI)
    end,
    Instance = function(v)
        local DebugId = OldDebugId(v)
        return i2p(v,generation[DebugId])
    end,
    userdata = function(v) -- The server doesnt recive this
        if configs.advancedinfo then
            if getrawmetatable(v) then
                return "newproxy(true)"
            end
            return "newproxy(false)"
        end
        return "newproxy(true)"
    end
}

local typev2sfunctions = {
    userdata = function(v,vtypeof)
        if ufunctions[vtypeof] then
            return ufunctions[vtypeof](v)
        end
        return `{vtypeof}({rawtostring(v)}) --[[Generation Failure]]`
    end,
    vector = ufunctions["Vector3"]
}


function v2s(v, l, p, n, vtv, i, pt, path, tables, tI)
    local vtypeof = typeof(v)
    local vtypeoffunc = typeofv2sfunctions[vtypeof]
    local vtypefunc = typev2sfunctions[type(v)]
    local vtype = type(v)
    if not tI then
        tI = {0}
    else
        tI[1] += 1
    end

    if vtypeoffunc then
        return vtypeoffunc(v, l, p, n, vtv, i, pt, path, tables, tI)
    elseif vtypefunc then
        return vtypefunc(v,vtypeof)
    end
    return `{vtypeof}({rawtostring(v)}) --[[Generation Failure]]`
end

--- value-to-variable
--- @param t any
function v2v(t)
    topstr = ""
    bottomstr = ""
    getnilrequired = false
    local ret = ""
    local count = 1
    for i, v in next, t do
        if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
            ret = ret .. "local " .. i .. " = " .. v2s(v, nil, nil, i, true) .. "\n"
        elseif rawtostring(i):match("^[%a_]+[%w_]*$") then
            ret = ret .. "local " .. lower(rawtostring(i)) .. "_" .. rawtostring(count) .. " = " .. v2s(v, nil, nil, lower(rawtostring(i)) .. "_" .. rawtostring(count), true) .. "\n"
        else
            ret = ret .. "local " .. type(v) .. "_" .. rawtostring(count) .. " = " .. v2s(v, nil, nil, type(v) .. "_" .. rawtostring(count), true) .. "\n"
        end
        count = count + 1
    end
    if getnilrequired then
        topstr = "function getNil(name,class) for _,v in next, getnilinstances() do if v.ClassName==class and v.Name==name then return v;end end end\n" .. topstr
    end
    if #topstr > 0 then
        ret = topstr .. "\n" .. ret
    end
    if #bottomstr > 0 then
        ret = ret .. bottomstr
    end
    return ret
end

function tabletostring(tbl: table,format: boolean)
    
end

--- table-to-string
--- @param t table
--- @param l number
--- @param p table
--- @param n string
--- @param vtv boolean
--- @param i any
--- @param pt table
--- @param path string
--- @param tables table
--- @param tI table
function t2s(t, l, p, n, vtv, i, pt, path, tables, tI)
    local globalIndex = table.find(getgenv(), t) -- checks if table is a global
    if type(globalIndex) == "string" then
        return globalIndex
    end
    if not tI then
        tI = {0}
    end
    if not path then -- sets path to empty string (so it doesn't have to manually provided every time)
        path = ""
    end
    if not l then -- sets the level to 0 (for indentation) and tables for logging tables it already serialized
        l = 0
        tables = {}
    end
    if not p then -- p is the previous table but doesn't really matter if it's the first
        p = t
    end
    for _, v in next, tables do -- checks if the current table has been serialized before
        if n and rawequal(v, t) then
            bottomstr = bottomstr .. "\n" .. rawtostring(n) .. rawtostring(path) .. " = " .. rawtostring(n) .. rawtostring(({v2p(v, p)})[2])
            return "{} --[[DUPLICATE]]"
        end
    end
    table.insert(tables, t) -- logs table to past tables
    local s =  "{" -- start of serialization
    local size = 0
    l += indent -- set indentation level
    for k, v in next, t do -- iterates over table
        size = size + 1 -- changes size for max limit
        if size > (getgenv().SimpleSpyMaxTableSize or 1000) then
            s = s .. "\n" .. string.rep(" ", l) .. "-- MAXIMUM TABLE SIZE REACHED, CHANGE 'getgenv().SimpleSpyMaxTableSize' TO ADJUST MAXIMUM SIZE "
            break
        end
        if rawequal(k, t) then -- checks if the table being iterated over is being used as an index within itself (yay, lua)
            bottomstr ..= `\n{n}{path}[{n}{path}] = {(rawequal(v,k) and `{n}{path}` or v2s(v, l, p, n, vtv, k, t, `{path}[{n}{path}]`, tables))}`
            --bottomstr = bottomstr .. "\n" .. rawtostring(n) .. rawtostring(path) .. "[" .. rawtostring(n) .. rawtostring(path) .. "]" .. " = " .. (rawequal(v, k) and rawtostring(n) .. rawtostring(path) or v2s(v, l, p, n, vtv, k, t, path .. "[" .. rawtostring(n) .. rawtostring(path) .. "]", tables))
            size -= 1
            continue
        end
        local currentPath = "" -- initializes the path of 'v' within 't'
        if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then -- cleanly handles table path generation (for the first half)
            currentPath = "." .. k
        else
            currentPath = "[" .. v2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "]"
        end
        if size % 100 == 0 then
            scheduleWait()
        end
        -- actually serializes the member of the table
        s = s .. "\n" .. string.rep(" ", l) .. "[" .. v2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "] = " .. v2s(v, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. ","
    end
    if #s > 1 then -- removes the last comma because it looks nicer (no way to tell if it's done 'till it's done so...)
        s = s:sub(1, #s - 1)
    end
    if size > 0 then -- cleanly indents the last curly bracket
        s = s .. "\n" .. string.rep(" ", l - indent)
    end
    return s .. "}"
end

--- function-to-string
function f2s(f)
    for k, x in next, getgenv() do
        local isgucci, gpath
        if rawequal(x, f) then
            isgucci, gpath = true, ""
        elseif type(x) == "table" then
            isgucci, gpath = v2p(f, x)
        end
        if isgucci and type(k) ~= "function" then
            if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then
                return k .. gpath
            else
                return "getgenv()[" .. v2s(k) .. "]" .. gpath
            end
        end
    end
    
    if configs.funcEnabled then
        local funcname = info(f,"n")
        
        if funcname and funcname:match("^[%a_]+[%w_]*$") then
            return `function {funcname}() end -- Function Called: {funcname}`
        end
    end
    return tostring(f)
end

--- instance-to-path
--- @param i userdata
function i2p(i,customgen)
    if customgen then
        return customgen
    end
    local player = getplayer(i)
    local parent = i
    local out = ""
    if parent == nil then
        return "nil"
    elseif player then
        while true do
            if parent and parent == player.Character then
                if player == Players.LocalPlayer then
                    return 'game:GetService("Players").LocalPlayer.Character' .. out
                else
                    return i2p(player) .. ".Character" .. out
                end
            else
                if parent.Name:match("[%a_]+[%w+]*") ~= parent.Name then
                    out = ':FindFirstChild(' .. formatstr(parent.Name) .. ')' .. out
                else
                    out = "." .. parent.Name .. out
                end
            end
            task.wait()
            parent = parent.Parent
        end
    elseif parent ~= game then
        while true do
            if parent and parent.Parent == game then
                if game:FindService(parent.ClassName) then  -- You arent getting clout off of this
                    if lower(parent.ClassName) == "workspace" then
                        return `workspace{out}`
                    else
                        return 'game:GetService("' .. parent.ClassName .. '")' .. out
                    end
                else
                    if parent.Name:match("[%a_]+[%w_]*") then
                        return "game." .. parent.Name .. out
                    else
                        return 'game:FindFirstChild(' .. formatstr(parent.Name) .. ')' .. out
                    end
                end
            elseif not parent.Parent then
                getnilrequired = true
                return 'getNil(' .. formatstr(parent.Name) .. ', "' .. parent.ClassName .. '")' .. out
            else
                if parent.Name:match("[%a_]+[%w_]*") ~= parent.Name then
                    out = ':WaitForChild(' .. formatstr(parent.Name) .. ')' .. out
                else
                    out = ':WaitForChild("' .. parent.Name .. '")'..out
                end
            end
            if i:IsDescendantOf(Players.LocalPlayer) then
                return 'game:GetService("Players").LocalPlayer'..out
            end
            parent = parent.Parent
            task.wait()
        end
    else
        return "game"
    end
end

--- Gets the player an instance is descended from
function getplayer(instance)
    for _, v in next, Players:GetPlayers() do
        if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then
            return v
        end
    end
end

--- value-to-path (in table)
function v2p(x, t, path, prev)
    if not path then
        path = ""
    end
    if not prev then
        prev = {}
    end
    if rawequal(x, t) then
        return true, ""
    end
    for i, v in next, t do
        if rawequal(v, x) then
            if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
                return true, (path .. "." .. i)
            else
                return true, (path .. "[" .. v2s(i) .. "]")
            end
        end
        if type(v) == "table" then
            local duplicate = false
            for _, y in next, prev do
                if rawequal(y, v) then
                    duplicate = true
                end
            end
            if not duplicate then
                table.insert(prev, t)
                local found
                found, p = v2p(x, v, path, prev)
                if found then
                    if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
                        return true, "." .. i .. p
                    else
                        return true, "[" .. v2s(i) .. "]" .. p
                    end
                end
            end
        end
    end
    return false, ""
end

--- format s: string, byte encrypt (for weird symbols)
function formatstr(s, indentation)
    if not indentation then
        indentation = 0
    end
    local handled, reachedMax = handlespecials(s, indentation)
    return '"' .. handled .. '"' .. (reachedMax and " --[[ MAXIMUM STRING SIZE REACHED, CHANGE 'getgenv().SimpleSpyMaxStringSize' TO ADJUST MAXIMUM SIZE ]]" or "")
end

--- Adds \'s to the text as a replacement to whitespace chars and other things because string.format can't yayeet

local function isFinished(coroutines: table)
    for _, v in next, coroutines do
        if status(v) == "running" then
            return false
        end
    end
    return true
end

local specialstrings = {
    ["\n"] = function(thread,index)
        resume(thread,index,"\\n")
    end,
    ["\t"] = function(thread,index)
        resume(thread,index,"\\t")
    end,
    ["\\"] = function(thread,index)
        resume(thread,index,"\\\\")
    end,
    ['"'] = function(thread,index)
        resume(thread,index,"\\\"")
    end
}

function handlespecials(s, indentation)
    local i = 0
    local n = 1
    local coroutines = {}
    local coroutineFunc = function(i, r)
        s = s:sub(0, i - 1) .. r .. s:sub(i + 1, -1)
    end
    local timeout = 0
    repeat
        i += 1
        if timeout >= 10 then
            task.wait()
            timeout = 0
        end
        local char = s:sub(i, i)

        if byte(char) then
            timeout += 1
            local c = create(coroutineFunc)
            table.insert(coroutines, c)
            local specialfunc = specialstrings[char]

            if specialfunc then
                specialfunc(c,i)
                i += 1
            elseif byte(char) > 126 or byte(char) < 32 then
                resume(c, i, "\\" .. byte(char))
                -- s = s:sub(0, i - 1) .. "\\" .. byte(char) .. s:sub(i + 1, -1)
                i += #rawtostring(byte(char))
            end
            if i >= n * 100 then
                local extra = string.format('" ..\n%s"', string.rep(" ", indentation + indent))
                s = s:sub(0, i) .. extra .. s:sub(i + 1, -1)
                i += #extra
                n += 1
            end
        end
    until char == "" or i > (getgenv().SimpleSpyMaxStringSize or 10000)
    while not isFinished(coroutines) do
        RunService.Heartbeat:Wait()
    end
    clear(coroutines)
    if i > (getgenv().SimpleSpyMaxStringSize or 10000) then
        s = string.sub(s, 0, getgenv().SimpleSpyMaxStringSize or 10000)
        return s, true
    end
    return s, false
end

--- finds script from 'src' from getinfo, returns nil if not found
--- @param src string
function getScriptFromSrc(src)
    local realPath
    local runningTest
    --- @type number
    local s, e
    local match = false
    if src:sub(1, 1) == "=" then
        realPath = game
        s = 2
    else
        runningTest = src:sub(2, e and e - 1 or -1)
        for _, v in next, getnilinstances() do
            if v.Name == runningTest then
                realPath = v
                break
            end
        end
        s = #runningTest + 1
    end
    if realPath then
        e = src:sub(s, -1):find("%.")
        local i = 0
        repeat
            i += 1
            if not e then
                runningTest = src:sub(s, -1)
                local test = realPath.FindFirstChild(realPath, runningTest)
                if test then
                    realPath = test
                end
                match = true
            else
                runningTest = src:sub(s, e)
                local test = realPath.FindFirstChild(realPath, runningTest)
                local yeOld = e
                if test then
                    realPath = test
                    s = e + 2
                    e = src:sub(e + 2, -1):find("%.")
                    e = e and e + yeOld or e
                else
                    e = src:sub(e + 2, -1):find("%.")
                    e = e and e + yeOld or e
                end
            end
        until match or i >= 50
    end
    return realPath
end

--- schedules the provided function (and calls it with any args after)

function schedule(f, ...)
    table.insert(scheduled, {f, ...})
end

--- yields the current thread until the scheduler gives the ok
function scheduleWait()
    local thread = running()
    schedule(function()
        resume(thread)
    end)
    yield()
end

--- the big (well tbh small now) boi task scheduler himself, handles p much anything as quicc as possible
local function taskscheduler()
    if not toggle then
        scheduled = {}
        return
    end
    if #scheduled > SIMPLESPYCONFIG_MaxRemotes + 100 then
        table.remove(scheduled, #scheduled)
    end
    if #scheduled > 0 then
        local currentf = scheduled[1]
        table.remove(scheduled, 1)
        if type(currentf) == "table" and type(currentf[1]) == "function" then
            pcall(unpack(currentf))
        end
    end
end

local function tablecheck(tabletocheck,instance,id)
    return tabletocheck[id] or tabletocheck[instance.Name]
end

function remoteHandler(data)
    if configs.autoblock then
        local id = data.id

        if excluding[id] then
            return
        end
        if not history[id] then
            history[id] = {badOccurances = 0, lastCall = tick()}
        end
        if tick() - history[id].lastCall < 1 then
            history[id].badOccurances += 1
            return
        else
            history[id].badOccurances = 0
        end
        if history[id].badOccurances > 3 then
            excluding[id] = true
            return
        end
        history[id].lastCall = tick()
    end

    if data.remote:IsA("RemoteEvent") and lower(data.method) == "fireserver" then
        newRemote("event", data)
    elseif data.remote:IsA("RemoteFunction") and lower(data.method) == "invokeserver" then
        newRemote("function", data)
    end
end

local newindex = function(method,originalfunction,...)
    if typeof(...) == 'Instance' then
        local remote = cloneref(...)

        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            if not configs.logcheckcaller and checkcaller() then return originalfunction(...) end
            local id = ThreadGetDebugId(remote)
            local blockcheck = tablecheck(blocklist,remote,id)
            local args = {select(2,...)}

            if not tablecheck(blacklist,remote,id) and not IsCyclicTable(args) then
                local data = {
                    method = method,
                    remote = remote,
                    args = deepclone(args),
                    infofunc = infofunc,
                    callingscript = callingscript,
                    metamethod = "__index",
                    blockcheck = blockcheck,
                    id = id,
                    returnvalue = {}
                }
                args = nil

                if configs.funcEnabled then
                    data.infofunc = info(2,"f")
                    local calling = getcallingscript()
                    data.callingscript = calling and cloneref(calling) or nil
                end

                schedule(remoteHandler,data)

                --[[if configs.logreturnvalues and remote:IsA("RemoteFunction") then
                    local thread = running()
                    local returnargs = {...}
                    local returndata

                    spawn(function()
                        setnamecallmethod(method)
                        returndata = originalnamecall(unpack(returnargs))
                        data.returnvalue.data = returndata
                        if ThreadIsNotDead(thread) then
                            resume(thread)
                        end
                     end)
                    yield()
                    if not blockcheck then
                        return returndata
                    end
                end]]
                end
            if blockcheck then return end
        end
    end
    return originalfunction(...)
end

local newnamecall = newcclosure(function(...)
    local method = getnamecallmethod()

    if method and (method == "FireServer" or method == "fireServer" or method == "InvokeServer" or method == "invokeServer") then
        if typeof(...) == 'Instance' then
            local remote = cloneref(...)

            if IsA(remote,"RemoteEvent") or IsA(remote,"RemoteFunction") then    
                if not configs.logcheckcaller and checkcaller() then return originalnamecall(...) end
                local id = ThreadGetDebugId(remote)
                local blockcheck = tablecheck(blocklist,remote,id)
                local args = {select(2,...)}

                if not tablecheck(blacklist,remote,id) and not IsCyclicTable(args) then
                    local data = {
                        method = method,
                        remote = remote,
                        args = deepclone(args),
                        infofunc = infofunc,
                        callingscript = callingscript,
                        metamethod = "__namecall",
                        blockcheck = blockcheck,
                        id = id,
                        returnvalue = {}
                    }
                    args = nil

                    if configs.funcEnabled then
                        data.infofunc = info(2,"f")
                        local calling = getcallingscript()
                        data.callingscript = calling and cloneref(calling) or nil
                    end

                    schedule(remoteHandler,data)
                    
                    --[[if configs.logreturnvalues and remote.IsA(remote,"RemoteFunction") then
                        local thread = running()
                        local returnargs = {...}
                        local returndata

                        spawn(function()
                            setnamecallmethod(method)
                            returndata = originalnamecall(unpack(returnargs))
                            data.returnvalue.data = returndata
                            if ThreadIsNotDead(thread) then
                                resume(thread)
                            end
                        end)
                        yield()
                        if not blockcheck then
                            return returndata
                        end
                    end]]
                end
                if blockcheck then return end
            end
        end
    end
    return originalnamecall(...)
end)

local newFireServer = newcclosure(function(...)
    return newindex("FireServer",originalEvent,...)
end)

local newInvokeServer = newcclosure(function(...)
    return newindex("InvokeServer",originalFunction,...)
end)

local function disablehooks()
    if synv3 then
        unhook(getrawmetatable(game).__namecall,originalnamecall)
        unhook(Instance.new("RemoteEvent").FireServer, originalEvent)
        unhook(Instance.new("RemoteFunction").InvokeServer, originalFunction)
        restorefunction(originalnamecall)
        restorefunction(originalEvent)
        restorefunction(originalFunction)
    else
        if hookmetamethod then
            hookmetamethod(game,"__namecall",originalnamecall)
        else
            hookfunction(getrawmetatable(game).__namecall,originalnamecall)
        end
        hookfunction(Instance.new("RemoteEvent").FireServer, originalEvent)
        hookfunction(Instance.new("RemoteFunction").InvokeServer, originalFunction)
    end
end

--- Toggles on and off the remote spy
function toggleSpy()
    if not toggle then
        local oldnamecall
        if synv3 then
            oldnamecall = hook(getrawmetatable(game).__namecall,clonefunction(newnamecall))
            originalEvent = hook(Instance.new("RemoteEvent").FireServer, clonefunction(newFireServer))
            originalFunction = hook(Instance.new("RemoteFunction").InvokeServer, clonefunction(newInvokeServer))
        else
            if hookmetamethod then
                oldnamecall = hookmetamethod(game, "__namecall", clonefunction(newnamecall))
            else
                oldnamecall = hookfunction(getrawmetatable(game).__namecall,clonefunction(newnamecall))
            end
            originalEvent = hookfunction(Instance.new("RemoteEvent").FireServer, clonefunction(newFireServer))
            originalFunction = hookfunction(Instance.new("RemoteFunction").InvokeServer, clonefunction(newInvokeServer))
        end
        originalnamecall = originalnamecall or function(...)
            return oldnamecall(...)
        end
    else
        disablehooks()
    end
end

--- Toggles between the two remotespy methods (hookfunction currently = disabled)
function toggleSpyMethod()
    toggleSpy()
    toggle = not toggle
end

--- Shuts down the remote spy
local function shutdown()
    if UI.SimpleSpy3.Parent then
        quantumTween(UI.Background, {GroupTransparency = 1}, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        quantumTween(UI.WindowShadow, {ImageTransparency = 1}, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        wait(0.14)
    end
    if schedulerconnect then
        schedulerconnect:Disconnect()
    end
    for _, connection in next, connections do
        connection:Disconnect()
    end
    for i,v in next, running_threads do
        if ThreadIsNotDead(v) then
            close(v)
        end
    end
    clear(running_threads)
    clear(connections)
    clear(logs)
    clear(remoteLogs)
    clear(remoteGroups)
    disablehooks()
    UI.SimpleSpy3:Destroy()
    UI.Storage:Destroy()
    UserInputService.MouseIconEnabled = true
    getgenv().SimpleSpyExecuted = false
end

-- main
if not getgenv().SimpleSpyExecuted then
    local succeeded,err = pcall(function()
        if not RunService:IsClient() then
            error("SimpleSpy cannot run on the server!")
        end
        getgenv().SimpleSpyShutdown = shutdown
        onToggleButtonClick()
        if not hookmetamethod then
            ErrorPrompt("Simple Spy V3 will not function to it's fullest capablity due to your executor not supporting hookmetamethod.",true)
        end
        codebox = Highlight.new(UI.CodeBox)
        do
            local editorScroller = UI.CodeBox:FindFirstChildOfClass("ScrollingFrame")
            if editorScroller then
                local editorTextFrame
                local gutterFrame
                for _, child in next, editorScroller:GetChildren() do
                    if child:IsA("Frame") then
                        if child.BackgroundTransparency == 1 then
                            editorTextFrame = child
                        else
                            gutterFrame = child
                        end
                    end
                end

                local function alignEditorSpacing()
                    if editorTextFrame and editorTextFrame.Parent then
                        editorTextFrame.Position = UDim2.fromOffset(44, 0)
                        editorTextFrame.Size = UDim2.new(1, -44, 1, 0)
                    end
                    if gutterFrame and gutterFrame.Parent then
                        gutterFrame.Size = UDim2.new(0, 36, gutterFrame.Size.Y.Scale, gutterFrame.Size.Y.Offset)
                        for _, child in next, gutterFrame:GetChildren() do
                            if child:IsA("Frame") and child.BackgroundTransparency == 1 then
                                child.Position = UDim2.fromOffset(4, 0)
                                child.Size = UDim2.new(0, 27, 1, 0)
                            end
                        end
                    end
                end

                alignEditorSpacing()
                UI.CodeBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(alignEditorSpacing)
                Create("Frame",{Name = "EditorRightPadding",Parent = UI.CodeBox,Active = false,BackgroundColor3 = Quantum.Editor,BorderSizePixel = 0,Position = UDim2.new(1, -6, 0, 0),Size = UDim2.new(0, 4, 1, -6),ZIndex = UI.CodeBox.ZIndex})
                Create("Frame",{Name = "EditorBottomPadding",Parent = UI.CodeBox,Active = false,BackgroundColor3 = Quantum.Editor,BorderSizePixel = 0,Position = UDim2.new(0, 36, 1, -6),Size = UDim2.new(1, -42, 0, 4),ZIndex = UI.CodeBox.ZIndex})
            end
        end
        codebox:setRaw("-- select a remote to inspect generated code")
        getgenv().SimpleSpy = SimpleSpy
        getgenv().getNil = function(name,class)
			for _,v in next, getnilinstances() do
				if v.ClassName == class and v.Name == name then
					return v;
				end
			end
		end
        UI.Background.MouseEnter:Connect(function(...)
            mouseInGui = true
            mouseEntered()
        end)
        UI.Background.MouseLeave:Connect(function(...)
            mouseInGui = false
            mouseEntered()
        end)
        UI.TooltipText:GetPropertyChangedSignal("Text"):Connect(scaleToolTip)
        -- UI.TopBar.InputBegan:Connect(onBarInput)
        UI.MinimizeButton.MouseButton1Click:Connect(toggleMinimize)
        UI.MaximizeButton.MouseButton1Click:Connect(toggleSideTray)
        UI.ToggleButton.MouseButton1Click:Connect(onToggleButtonClick)
        UI.CloseButton.MouseEnter:Connect(onXButtonHover)
        UI.CloseButton.MouseLeave:Connect(onXButtonUnhover)
        UI.ToggleButton.MouseEnter:Connect(onToggleButtonHover)
        UI.ToggleButton.MouseLeave:Connect(onToggleButtonUnhover)
        UI.CloseButton.MouseButton1Click:Connect(shutdown)
        table.insert(connections, UserInputService.InputBegan:Connect(backgroundUserInput))
        connectResize()
        UI.SimpleSpy3.Enabled = true
        logthread(spawn(function()
            delay(1,onToggleButtonUnhover)
        end))
        schedulerconnect = RunService.Heartbeat:Connect(taskscheduler)
        bringBackOnResize()
        local settledPosition = UI.Background.Position
        UI.Background.Position = UDim2.new(settledPosition.X.Scale, settledPosition.X.Offset, settledPosition.Y.Scale, settledPosition.Y.Offset + 4)
        UI.SimpleSpy3.Parent = (gethui and gethui()) or (syn and syn.protect_gui and syn.protect_gui(UI.SimpleSpy3)) or CoreGui
        quantumTween(UI.Background, {GroupTransparency = 0, Position = settledPosition}, 0.2, Enum.EasingStyle.Quint)
        quantumTween(UI.WindowShadow, {ImageTransparency = 0.72}, 0.2, Enum.EasingStyle.Quint)
        updateQuantumStatus()
        logthread(spawn(function()
            local lp = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
            generation = {
                [OldDebugId(lp)] = 'game:GetService("Players").LocalPlayer',
                [OldDebugId(lp:GetMouse())] = 'game:GetService("Players").LocalPlayer:GetMouse',
                [OldDebugId(game)] = "game",
                [OldDebugId(workspace)] = "workspace"
            }
        end))
    end)
    if succeeded then
        getgenv().SimpleSpyExecuted = true
    else
        shutdown()
        ErrorPrompt("An error has occured:\n"..rawtostring(err))
        return
    end
else
    UI.SimpleSpy3:Destroy()
    return
end

function SimpleSpy:newButton(name, description, onClick)
    return newButton(name, description, onClick)
end

----- ADD ONS ----- (easily add or remove additonal functionality to the RemoteSpy!)
--[[
    Some helpful things:
        - add your function in here, and create buttons for them through the 'newButton' function
        - the first argument provided is the TextButton the player clicks to run the function
        - generated scripts are generated when the namecall is initially fired and saved in remoteFrame objects
        - blacklisted remotes will be ignored directly in namecall (less lag)
        - the properties of a 'remoteFrame' object:
            {
                Name: (string) The name of the Remote
                GenScript: (string) The generated script that appears in the codebox (generated when namecall fired)
                Source: (Instance (LocalScript)) The script that fired/invoked the remote
                Remote: (Instance (RemoteEvent) | Instance (RemoteFunction)) The remote that was fired/invoked
                Log: (Instance (TextButton)) The button being used for the remote (same as 'selected.Log')
            }
        - globals list: (contact @exx#9394 for more information or if you have suggestions for more to be added)
            - closed: (boolean) whether or not the GUI is currently minimized
            - logs: (table[remoteFrame]) full of remoteFrame objects (properties listed above)
            - selected: (remoteFrame) the currently selected remoteFrame (properties listed above)
            - blacklist: (string[] | Instance[] (RemoteEvent) | Instance[] (RemoteFunction)) an array of blacklisted names and remotes
            - codebox: (Instance (TextBox)) the textbox that holds all the code- cleared often
]]
-- Copies the contents of the codebox
newButton(
    "Copy Code",
    function() return "Click to copy code" end,
    function()
        setclipboard(codebox:getString())
        UI.TooltipText.Text = "Copied successfully!"
    end
)

--- Copies the source script (that fired the remote)
newButton(
    "Copy Remote",
    function() return "Click to copy the path of the remote" end,
    function()
        if selected and selected.Remote then
            setclipboard(v2s(selected.Remote))
            UI.TooltipText.Text = "Copied!"
        end
    end
)

-- Executes the contents of the codebox through loadstring
newButton("Run Code",
    function() return "Click to execute code" end,
    function()
        local Remote = selected and selected.Remote
        if Remote then
            UI.TooltipText.Text = "Executing..."
            xpcall(function()
                local returnvalue
                if Remote:IsA("RemoteEvent") then
                    returnvalue = Remote:FireServer(unpack(selected.args))
                else
                    returnvalue = Remote:InvokeServer(unpack(selected.args))
                end

                UI.TooltipText.Text = ("Executed successfully!\n%s"):format(v2s(returnvalue))
            end,function(err)
                UI.TooltipText.Text = ("Execution error!\n%s"):format(err)
            end)
            return
        end
        UI.TooltipText.Text = "Source not found"
    end
)

--- Gets the calling script (not super reliable but w/e)
newButton(
    "Get Script",
    function() return "Click to copy calling script to clipboard\nWARNING: Not super reliable, nil == could not find" end,
    function()
        if selected then
            if not selected.Source then
                selected.Source = rawget(getfenv(selected.Function),"script")
            end
            setclipboard(v2s(selected.Source))
            UI.TooltipText.Text = "Done!"
        end
    end
)

--- Decompiles the script that fired the remote and puts it in the code box
newButton("Function Info",function() return "Click to view calling function information" end,
function()
    local func = selected and selected.Function
    if func then
        local typeoffunc = typeof(func)

        if typeoffunc ~= 'string' then
            codebox:setRaw("--[[Generating Function Info please wait]]")
            RunService.Heartbeat:Wait()
            local lclosure = islclosure(func)
            local SourceScript = rawget(getfenv(func),"script")
            local CallingScript = selected.Source or nil
            local info = {}
            
            info = {
                info = getinfo(func),
                constants = lclosure and deepclone(getconstants(func)) or "N/A --Lua Closure expected got C Closure",
                upvalues = deepclone(getupvalues(func)),
                script = {
                    SourceScript = SourceScript or 'nil',
                    CallingScript = CallingScript or 'nil'
                }
            }
                    
            if configs.advancedinfo then
                local Remote = selected.Remote

                info["advancedinfo"] = {
                    Metamethod = selected.metamethod,
                    DebugId = {
                        SourceScriptDebugId = SourceScript and typeof(SourceScript) == "Instance" and OldDebugId(SourceScript) or "N/A",
                        CallingScriptDebugId = CallingScript and typeof(SourceScript) == "Instance" and OldDebugId(CallingScript) or "N/A",
                        RemoteDebugId = OldDebugId(Remote)
                    },
                    Protos = lclosure and getprotos(func) or "N/A --Lua Closure expected got C Closure"
                }

                if Remote:IsA("RemoteFunction") then
                    info["advancedinfo"]["OnClientInvoke"] = getcallbackmember and (getcallbackmember(Remote,"OnClientInvoke") or "N/A") or "N/A --Missing function getcallbackmember"
                elseif getconnections then
                    info["advancedinfo"]["OnClientEvents"] = {}

                    for i,v in next, getconnections(Remote.OnClientEvent) do
                        info["advancedinfo"]["OnClientEvents"][i] = {
                            Function = v.Function or "N/A",
                            State = v.State or "N/A"
                        }
                    end
                end
            end
            codebox:setRaw("--[[Converting table to string please wait]]")
            selected.Function = v2v({functionInfo = info})
        end
        codebox:setRaw("-- Calling function info\n-- Generated by the SimpleSpy V3 serializer\n\n"..selected.Function)
        UI.TooltipText.Text = "Done! Function info generated by the SimpleSpy V3 Serializer."
    else
        UI.TooltipText.Text = "Error! Selected function was not found."
    end
end)

--- Clears the Remote logs
newButton(
    "Clr Logs",
    function() return "Click to clear logs" end,
    function()
        UI.TooltipText.Text = "Clearing..."
        clear(logs)
        for i,v in next, UI.LogList:GetChildren() do
            if not v:IsA("UIListLayout") and not v:IsA("UIStroke") then
                v:Destroy()
            end
        end
        clear(remoteLogs)
        clear(remoteGroups)
        selected = nil
        resetQuantumInspector()
        updateRemoteCanvas()
        updateQuantumStatus()
        UI.TooltipText.Text = "Logs cleared!"
    end
)

--- Excludes the selected.Log Remote from the RemoteSpy
newButton(
    "Exclude (i)",
    function() return "Click to exclude this Remote.\nExcluding a remote makes SimpleSpy ignore it, but it will continue to be usable." end,
    function()
        if selected then
            blacklist[OldDebugId(selected.Remote)] = true
            UI.TooltipText.Text = "Excluded!"
        end
    end
)

--- Excludes all Remotes that share the same name as the selected.Log remote from the RemoteSpy
newButton(
    "Exclude (n)",
    function() return "Click to exclude all remotes with this name.\nExcluding a remote makes SimpleSpy ignore it, but it will continue to be usable." end,
    function()
        if selected then
            blacklist[selected.Name] = true
            UI.TooltipText.Text = "Excluded!"
        end
    end
)

--- clears blacklist
newButton("Clr Blacklist",
function() return "Click to clear the blacklist.\nExcluding a remote makes SimpleSpy ignore it, but it will continue to be usable." end,
function()
    blacklist = {}
    UI.TooltipText.Text = "Blacklist cleared!"
end)

--- Prevents the selected.Log Remote from firing the server (still logged)
newButton(
    "Block (i)",
    function() return "Click to stop this remote from firing.\nBlocking a remote won't remove it from SimpleSpy logs, but it will not continue to fire the server." end,
    function()
        if selected then
            blocklist[OldDebugId(selected.Remote)] = true
            UI.TooltipText.Text = "Excluded!"
        end
    end
)

--- Prevents all remotes from firing that share the same name as the selected.Log remote from the RemoteSpy (still logged)
newButton("Block (n)",function()
    return "Click to stop remotes with this name from firing.\nBlocking a remote won't remove it from SimpleSpy logs, but it will not continue to fire the server." end,
    function()
        if selected then
            blocklist[selected.Name] = true
            UI.TooltipText.Text = "Excluded!"
        end
    end
)

--- clears blacklist
newButton(
    "Clr Blocklist",
    function() return "Click to stop blocking remotes.\nBlocking a remote won't remove it from SimpleSpy logs, but it will not continue to fire the server." end,
    function()
        blocklist = {}
        UI.TooltipText.Text = "Blocklist cleared!"
    end
)

--- Attempts to decompile the source script
newButton("Decompile",
    function()
        return "Decompile source script"
    end,function()
        if decompile then
            if selected and selected.Source then
                local Source = selected.Source
                if not DecompiledScripts[Source] then
                    codebox:setRaw("--[[Decompiling]]")

                    xpcall(function()
                        local decompiledsource = decompile(Source):gsub("-- Decompiled with the Synapse X Luau decompiler.","")
                        local Sourcev2s = v2s(Source)
                        if (decompiledsource):find("script") and Sourcev2s then
                            DecompiledScripts[Source] = ("local script = %s\n%s"):format(Sourcev2s,decompiledsource)
                        end
                    end,function(err)
                        return codebox:setRaw(("--[[\nAn error has occured\n%s\n]]"):format(err))
                    end)
                end
                codebox:setRaw(DecompiledScripts[Source] or "--No Source Found")
                UI.TooltipText.Text = "Done!"
            else
                UI.TooltipText.Text = "Source not found!"
            end
        else
            UI.TooltipText.Text = "Missing function (decompile)"
        end
    end
)

    --[[newButton(
        "returnvalue",
        function() return "Get a Remote's return data" end,
        function()
            if selected then
                local Remote = selected.Remote
                if Remote and Remote:IsA("RemoteFunction") then
                    if selected.returnvalue and selected.returnvalue.data then
                        return codebox:setRaw(v2s(selected.returnvalue.data))
                    end
                    return codebox:setRaw("No data was returned")
                else
                    codebox:setRaw("RemoteFunction expected got "..(Remote and Remote.ClassName))
                end
            end
        end
    )]]

newButton(
    "Disable Info",
    function() return string.format("[%s] Toggle function info (because it can cause lag in some games)", configs.funcEnabled and "ENABLED" or "DISABLED") end,
    function()
        configs.funcEnabled = not configs.funcEnabled
        UI.TooltipText.Text = string.format("[%s] Toggle function info (because it can cause lag in some games)", configs.funcEnabled and "ENABLED" or "DISABLED")
    end
)

newButton(
    "Autoblock",
    function() return string.format("[%s] [BETA] Intelligently detects and excludes spammy remote calls from logs", configs.autoblock and "ENABLED" or "DISABLED") end,
    function()
        configs.autoblock = not configs.autoblock
        UI.TooltipText.Text = string.format("[%s] [BETA] Intelligently detects and excludes spammy remote calls from logs", configs.autoblock and "ENABLED" or "DISABLED")
        history = {}
        excluding = {}
    end
)

newButton("Logcheckcaller",function()
    return ("[%s] Log remotes fired by the client"):format(configs.logcheckcaller and "ENABLED" or "DISABLED")
end,
function()
    configs.logcheckcaller = not configs.logcheckcaller
    UI.TooltipText.Text = ("[%s] Log remotes fired by the client"):format(configs.logcheckcaller and "ENABLED" or "DISABLED")
end)

--[[newButton("Log returnvalues",function()
    return ("[BETA] [%s] Log RemoteFunction's return values"):format(configs.logcheckcaller and "ENABLED" or "DISABLED")
end,
function()
    configs.logreturnvalues = not configs.logreturnvalues
    UI.TooltipText.Text = ("[BETA] [%s] Log RemoteFunction's return values"):format(configs.logreturnvalues and "ENABLED" or "DISABLED")
end)]]

newButton("Advanced Info",function()
    return ("[%s] Display more remoteinfo"):format(configs.advancedinfo and "ENABLED" or "DISABLED")
end,
function()
    configs.advancedinfo = not configs.advancedinfo
    UI.TooltipText.Text = ("[%s] Display more remoteinfo"):format(configs.advancedinfo and "ENABLED" or "DISABLED")
end)

newButton("Join Discord",function()
    return "Joins The Simple Spy Discord"
end,
function()
    setclipboard("https://discord.com/invite/AWS6ez9")
    UI.TooltipText.Text = "Copied invite to your clipboard"
    if request then
        request({Url = 'http://127.0.0.1:6463/rpc?v=1',Method = 'POST',Headers = {['Content-Type'] = 'application/json', Origin = 'https://discord.com'},Body = http:JSONEncode({cmd = 'INVITE_BROWSER',nonce = http:GenerateGUID(false),args = {code = 'AWS6ez9'}})})
    end
end)

if configs.supersecretdevtoggle then
    newButton("Load SSV2.2",function()
        return "Load's Simple Spy V2.2"
    end,
    function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/exxtremestuffs/SimpleSpySource/master/SimpleSpy.lua"))()
    end)
    newButton("Load SSV3",function()
        return "Load's Simple Spy V3"
    end,
    function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/SimpleSpy/main/SimpleSpySource.lua"))()
    end)
    local SuperSecretFolder = Create("Folder",{Parent = UI.SimpleSpy3})
    newButton("SUPER SECRET BUTTON",function()
        return "You dont need a discription you already know what it does"
    end,
    function()
        SuperSecretFolder:ClearAllChildren()
        local random = listfiles("Music")
        local NotSound = Create("Sound",{Parent = SuperSecretFolder,Looped = false,Volume = math.random(1,5),SoundId = getsynasset(random[math.random(1,#random)])})
        NotSound:Play()
    end)
end
