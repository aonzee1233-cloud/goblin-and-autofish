--[[
Frankenstein Ritual Helper v1 | Fisch - FischFright 3 | Delta
สคริปต์แยก ไม่ต้องรันคู่กับ goblin (รันซ้ำ = แทนอันเก่า)

เควส Frankenstein = ระบบพิธี (Ritual) ที่สุสาน Caustic Hallow
  คุย Frankenstein -> "I want to begin a ritual" (100 Treats) -> เลือกพิธี -> ใส่ของลงตะเกียงฟักทอง
  + วางของ Skeleton Hand บนแท่นกลาง ให้ทันตัวจับเวลา -> ได้รางวัล แล้วพิธีถัดไปปลดล็อก
  พิธีเรียงลำดับ 11 พิธี ข้ามไม่ได้ / พอเริ่มจับเวลาแล้วหยุดไม่ได้ -> เตรียมของให้ครบก่อนจ่าย Treats

ปุ่มในหน้าต่าง
  < > เลือกพิธี | Check = เทียบของในกระเป๋ากับสูตร (ขาดอะไรบอกทุกชิ้น)
  Go = ไปหา Frankenstein (ยังไม่โหลดก็ล่องเรือ Dutchman ไป Hallow ให้ เหมือน goblin script)
  Start = คุย -> begin a ritual -> เลือกพิธี -> ยืนยัน (ถ้าของไม่ครบจะไม่เริ่ม เว้นแต่เปิด Force)
  Dump prompts / inventory / UI / remotes = เก็บข้อมูลลง log | Copy log = ก๊อปไปส่งให้ผม

ยืนยันแล้วจาก goblin script (เอามาใช้ตรงๆ)
  remote dialog: ReplicatedStorage.events.dialogstart, packages.Net["RF/DialogInteract"]
  ล่องเรือ: world.map.Fischfright26.Green["Reaping Dutchman"]["Dutchman Captain"] + DialogInteract(1, 1)
  มี remote "RE/Rituals/Hands" อยู่จริง (เห็นตอน trick-or-treat) -> ชื่อ Rituals/* อื่นๆ ให้ดูที่บรรทัด RITUAL REMOTES

ยังไม่ยืนยัน (เลยมีตัว Recon)
  * ข้อความ dialog / ลำดับเมนูของ Frankenstein  -> ดู log "DIALOG Frankenstein {...}" ครั้งแรกที่กด Start
  * วิธีวางของลงตะเกียง/แท่น และชื่อ remote ของมัน -> Auto place ปิดไว้เป็นค่าเริ่มต้น (ทดลอง)
  * ของในกระเป๋าเป็น Tool ใน Backpack หรือเปล่า, ชื่อ mutation อยู่ที่ไหน -> ปุ่ม Dump inventory
  * สูตรด้านล่างมาจากเว็บไกด์ (ofzenandcomputing) และไกด์แต่ละเว็บไม่ตรงกันบางจุด -> แก้ตาราง R ได้เลย
    ชิ้นที่ขึ้นต้นด้วย ? = ตรวจเองไม่ได้ (เช่น Any Witch Ingredient) / "Grim|Skeleton Sturgeon" = mutation|ชื่อปลา
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local genv = (getgenv and getgenv()) or _G
if genv.FrankStop then pcall(genv.FrankStop) end

local okVim, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
if not okVim then VIM = nil end

local CFG = {
	ritual = 1,
	cemetery = Vector3.new(-15104, 146, -9621), -- Frankenstein (จากไกด์) ถ้าเพี้ยนให้กด Dump prompts แล้วแก้
	hallowDeck = Vector3.new(381, 142, 384),    -- ดาดฟ้า Reaping Dutchman ที่ Moosewood (จาก goblin script)
	dialogWait = 1.1,
	clickMode = "conn",   -- "conn" = ยิง connection ของปุ่ม | "vim" = คลิกจริง
	autoPlace = false,    -- ทดลอง: วางของเอง (เดา remote/prompt) ปิดไว้ก่อนจนกว่าจะเห็น log
	force = false,        -- true = เริ่มพิธีแม้ของไม่ครบ
	hookCalls = false,    -- log FireServer/InvokeServer (goblin script ปิดไว้ เพราะ Delta เคยมีปัญหา) เปิดเองถ้าอยากลอง
	scanRadius = 120,
}

-- lan = ของใส่ตะเกียงฟักทอง | hand = ของวางบนแท่นมือกลาง | destroy = ของที่ทำลายใส่ตะเกียง | key = คำที่ใช้หาปุ่มพิธีในเมนู
local R = {
	{ name = "Hexed", key = "hexed",
		lan = { "Candy Corn Pack", "Licorice Lamprey", "Dirty Candy Corn", "Jagged Bone", "Taffy Trout", "Crushed Bone", "Tombstone Tuna" },
		hand = {} },
	{ name = "Scary Relic", key = "scary",
		lan = { "Sour Patch Salmon", "Strange Root", "Grim|Gargoyle Grouper", "Vile|Broomstick Bass", "Doomed|Crypt Crab", "Spider Eye", "Bat Wing", "?Any 2026 FischFright Skull" },
		hand = { "?Any 2026 FischFright Skull" } },
	{ name = "Haunted", key = "haunted",
		lan = { "Licorice Lamprey", "Sour Patch Salmon", "Taffy Trout", "Jawbreaker Jellyfish", "Pop-Rock Pufferfish", "Bubblegum Blobfish", "Candy Corn Pack" },
		hand = { "Bat Wing" } },
	{ name = "Jack-o-Moon", key = "moon",
		lan = { "Headless Halibut", "Decayed Dace", "Voodoo Vendace", "?Any Grim-mutated FischFright fish", "?Any Vile-mutated FischFright fish", "?Any Doomed-mutated FischFright fish", "?Any Eldritch-mutated FischFright fish" },
		hand = { "Crushed Bone", "Strange Root" } },
	{ name = "Boglin", key = "boglin",
		lan = { "Jagged Bone", "Poltergeist Perch", "Skeleton Sturgeon", "Mummy Mackerel", "Corpse Cod", "?Any Small/Tiny FischFright fish", "?Any Small/Tiny FischFright fish" },
		hand = { "?Any Big/Giant FischFright fish", "?Any Big/Giant FischFright fish" } },
	{ name = "Dutchman's Blessing", key = "blessing",
		lan = { "Doomed|Jagged Bone", "Vile|Poltergeist Perch", "Grim|Skeleton Sturgeon", "Boglin|Mummy Mackerel", "Eldritch|Corpse Cod", "Dutchman's Grasp", "Coffin" },
		hand = { "Grim Skull", "Vile Skull", "Doomed Skull" } },
	{ name = "Enhanced Boglin", key = "enhanced",
		lan = { "?2x Shiny/Sparkling Boglin-mutated FischFright fish", "?5x Boglin-mutated FischFright fish (not Shiny/Sparkling)" },
		hand = { "?3x Any Giant FischFright fish" } },
	{ name = "Haunted Cemetery", key = "cemetery",
		lan = { "Dirty Candy Corn", "Crushed Bone", "Strange Root", "Giant Mushroom", "Spider Eye", "Bat Wing", "Raven Feather" },
		hand = { "Grim Skull", "Vile Skull", "Doomed Skull", "Dobhar" } },
	{ name = "Eldritch", key = "eldritch",
		lan = { "?7x Any Witch Ingredient" },
		hand = { "Dark Art Skull", "Dark Art Skull", "Dark Art Skull", "?Any 2026 FischFright Skull" } },
	{ name = "Omniscient", key = "omniscient",
		lan = { "Grim|Jagged Bone", "Vile|Jagged Bone", "Doomed|Jagged Bone", "Eldritch|Jagged Bone", "Zombie Nessie", "Plush Nessie", "Dark Art Skull" },
		hand = { "Boglin|Jagged Bone", "Doomsekkar|Jagged Bone", "Dutchman's Curse|Jagged Bone", "Omniscient Souls", "Omniscient Bone" } },
	{ name = "Ghoul Nessie", key = "ghoul",
		lan = { "Dirty Candy Corn", "Crushed Bone", "Strange Root", "Giant Mushroom", "Spider Eye", "Bat Wing", "Raven Feather" },
		destroy = { "Dark Art Skull", "Dark Art Skull", "Dark Art Skull" },
		hand = { "Grim Skull", "Vile Skull", "Doomed Skull", "Eldritch Skull", "Omniscient|Dobhar" } },
}

-- ของปลุก "Awakened Skeletal Hand" (พิธีตั้งแต่ Scary Relic ต้องมีมือที่ปลุกแล้ว)
local HANDS = {
	{ "Azael (Davy's Rose)", "davy" },
	{ "Xylar (Ethereal Rose)", "ethereal" },
	{ "Korvath (Fable/Fabled Rose)", "fable" },
	{ "Malakor (Gourdemort's Rose)", "gourdemort" },
	{ "Kaelith (Dark Art Skull)", "dark art" },
}

local HttpService = game:GetService("HttpService")
local SAVE_FILE = "frank_ritual.json"
local saved = { started = {} }

local function saveNow()
	if type(writefile) ~= "function" then return end
	pcall(function()
		writefile(SAVE_FILE, HttpService:JSONEncode({ ritual = CFG.ritual, started = saved.started }))
	end)
end

pcall(function()
	if type(isfile) == "function" and isfile(SAVE_FILE) then
		local d = HttpService:JSONDecode(readfile(SAVE_FILE))
		if type(d.ritual) == "number" and d.ritual >= 1 and d.ritual <= #R then CFG.ritual = d.ritual end
		if type(d.started) == "table" then saved.started = d.started end
	end
end)

local running = true
local lines, conns = {}, {}
local statusLbl
local gui = Instance.new("ScreenGui")

local function log(s)
	if #lines < 1500 then lines[#lines + 1] = s end
	print("[FR] " .. s)
end

local function setStatus(s)
	if statusLbl then statusLbl.Text = s end
end

local function fmt(a, d, maxd)
	d = d or 0
	maxd = maxd or 2
	if typeof(a) == "Instance" then return a:GetFullName() end
	if type(a) == "table" then
		if d >= maxd then return "{...}" end
		local p = {}
		for k, v in pairs(a) do p[#p + 1] = tostring(k) .. "=" .. fmt(v, d + 1, maxd) end
		return "{" .. table.concat(p, ", ") .. "}"
	end
	return tostring(a)
end

local function norm(s)
	s = tostring(s or ""):lower()
	s = s:gsub("\226\128\153", "'"):gsub("<[^>]+>", "")
	return s
end

local function clean(s)
	s = tostring(s or "")
	s = s:gsub("<[^>]+>", "")
	s = s:gsub("\226\128\156", '"'):gsub("\226\128\157", '"'):gsub("\226\128\153", "'")
	return s
end

local function hrpOf()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

---------------------------------------------------------------- remotes + recon
local ev = RS:FindFirstChild("events")
local dsEvent = ev and ev:FindFirstChild("dialogstart")
local pk = RS:FindFirstChild("packages")
local net = pk and pk:FindFirstChild("Net")
local DI = net and net:FindFirstChild("RF/DialogInteract")

local dialogAt = setmetatable({}, { __mode = "k" })
local dialogCfg = setmetatable({}, { __mode = "k" })

if dsEvent then
	conns[#conns + 1] = dsEvent.OnClientEvent:Connect(function(...)
		local t = table.pack(...)
		local d, c = t[1], t[3]
		if type(d) == "table" and typeof(d.npc) == "Instance" then
			dialogAt[d.npc] = os.clock()
			dialogCfg[d.npc] = c
			local s = "DIALOG " .. d.npc.Name .. " " .. fmt(c, 0, 5)
			if #s > 3000 then s = s:sub(1, 3000) .. "...<cut>" end
			log(s)
		end
	end)
else
	log("NOTE: events.dialogstart not found")
end

do
	local names = {}
	local words = { "ritual", "frank", "pumpkin", "lantern", "altar", "hand", "dialog" }
	if net then
		for _, r in ipairs(net:GetChildren()) do
			local n = r.Name
			local ln = n:lower()
			local hit = false
			for _, w in ipairs(words) do
				if ln:find(w, 1, true) then hit = true end
			end
			if hit then
				names[#names + 1] = n .. "(" .. r.ClassName .. ")"
				if r:IsA("BaseRemoteEvent") then
					conns[#conns + 1] = r.OnClientEvent:Connect(function(...)
						local a = table.pack(...)
						local p = {}
						for i = 1, a.n do p[i] = fmt(a[i], 0, 3) end
						local s = "EVENT " .. n .. "(" .. table.concat(p, ", ") .. ")"
						if #s > 1500 then s = s:sub(1, 1500) .. "...<cut>" end
						log(s)
					end)
				end
			end
		end
	else
		log("NOTE: packages.Net not found")
	end
	log("RITUAL REMOTES: " .. table.concat(names, ", "))
end

conns[#conns + 1] = PPS.PromptTriggered:Connect(function(p)
	log("PROMPT " .. p:GetFullName() .. " | " .. p.ActionText .. " / " .. p.ObjectText)
end)

-- ทางเลือก: log สิ่งที่ client ส่งไป server (เฉพาะ remote ที่เกี่ยวกับพิธี/dialog)
if CFG.hookCalls and hookmetamethod and getnamecallmethod and not genv.FR_HOOKED then
	genv.FR_HOOKED = true
	local nc = newcclosure or function(f) return f end
	local old
	old = hookmetamethod(game, "__namecall", nc(function(self, ...)
		local m = getnamecallmethod()
		if (m == "FireServer" or m == "InvokeServer") and running then
			local t = table.pack(...)
			local remote = self
			task.defer(function()
				local path = fmt(remote)
				local lp2 = path:lower()
				if lp2:find("ritual", 1, true) or lp2:find("dialog", 1, true) then
					local parts = {}
					for i = 1, t.n do parts[i] = fmt(t[i], 0, 3) end
					log("CALL " .. path .. ":" .. m .. "(" .. table.concat(parts, ", ") .. ")")
				end
			end)
		end
		return old(self, ...)
	end))
end

---------------------------------------------------------------- gui reading / clicking
local BADUI = { "statuses", "popupNotif", "topbar", "changelogs", "PlayerList", "backpack", "TopbarStandard" }
local function badUI(o)
	local p = o:GetFullName()
	for _, k in ipairs(BADUI) do
		if p:find(k, 1, true) then return true end
	end
	return false
end

local function visibleChain(g)
	local pg = lp.PlayerGui
	local o = g
	while o and o ~= pg do
		if o:IsA("GuiObject") and not o.Visible then return false end
		if o:IsA("ScreenGui") and not o.Enabled then return false end
		o = o.Parent
	end
	return o == pg
end

local function texts()
	local out = {}
	for _, g in ipairs(lp.PlayerGui:GetDescendants()) do
		if (g:IsA("TextButton") or g:IsA("TextLabel")) and #g.Text > 1
			and not g:IsDescendantOf(gui) and visibleChain(g) and not badUI(g) then
			out[#out + 1] = g
		end
	end
	return out
end

local function clickTarget(g)
	if g:IsA("GuiButton") then return g end
	return g:FindFirstAncestorWhichIsA("GuiButton")
end

local function fireConns(sig)
	if not getconnections then return 0 end
	local n = 0
	local ok, list = pcall(getconnections, sig)
	if ok and type(list) == "table" then
		for _, c in ipairs(list) do
			if pcall(function() c:Fire() end) then n = n + 1 end
		end
	end
	return n
end

local function realClick(g)
	if not VIM then return false end
	local p, s = g.AbsolutePosition, g.AbsoluteSize
	local sg = g:FindFirstAncestorWhichIsA("ScreenGui")
	local inset = (sg and sg.IgnoreGuiInset) and Vector2.zero or GuiService:GetGuiInset()
	local x, y = p.X + s.X / 2 + inset.X, p.Y + s.Y / 2 + inset.Y
	VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait(0.06)
	VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
	return true
end

local function press(btn)
	if CFG.clickMode == "conn" then
		if fireConns(btn.Activated) > 0 then return "Activated" end
		if fireConns(btn.MouseButton1Click) > 0 then return "MouseButton1Click" end
	end
	if realClick(btn) then return "vim" end
	return "none"
end

local function dumpUI(n)
	log("---- UI DUMP (visible text) ----")
	local c = 0
	for _, g in ipairs(texts()) do
		c = c + 1
		if c > (n or 80) then break end
		log(('UI %s | "%s" | button=%s'):format(g:GetFullName(), clean(g.Text):sub(1, 60), tostring(clickTarget(g) ~= nil)))
	end
end

-- กดปุ่มที่ข้อความมีคำใดคำหนึ่ง (เลือกข้อความสั้นสุดที่ตรง กัน "Haunted" ไปชน "Haunted Cemetery")
local function clickText(words, secs)
	local t0 = os.clock()
	repeat
		local best, bestLen
		for _, g in ipairs(texts()) do
			local b = clickTarget(g)
			if b then
				local t = norm(clean(g.Text))
				local hit = false
				for _, w in ipairs(words) do
					if t:find(w, 1, true) then hit = true end
				end
				if hit and (not bestLen or #t < bestLen) then
					best, bestLen = { b = b, t = t }, #t
				end
			end
		end
		if best then
			log(('CLICK "%s" via %s'):format(best.t:sub(1, 60), press(best.b)))
			return best.t
		end
		task.wait(0.3)
	until os.clock() - t0 >= (secs or 4) or not running
	return nil
end

local function tap(key, t)
	if not VIM then return end
	pcall(function() VIM:SendKeyEvent(true, key, false, game) end)
	task.wait(t or 0.15)
	pcall(function() VIM:SendKeyEvent(false, key, false, game) end)
end

---------------------------------------------------------------- movement + npc
local function promptPos(m)
	local pp = m:FindFirstChildWhichIsA("ProximityPrompt", true)
	local par = pp and pp.Parent
	if par and par:IsA("Attachment") then return par.WorldPosition end
	if par and par:IsA("BasePart") then return par.Position end
	return m:GetPivot().Position
end

local function ppPos(pp)
	local p = pp.Parent
	if p and p:IsA("Attachment") then return p.WorldPosition end
	if p and p:IsA("BasePart") then return p.Position end
	local ok, cf = pcall(function() return p:GetPivot() end)
	return ok and cf and cf.Position or nil
end

local function tpTo(model)
	local hrp = hrpOf()
	if not hrp or not model.Parent then return false end
	if not model:FindFirstChildWhichIsA("BasePart", true) then
		pcall(function() lp:RequestStreamAroundAsync(model:GetPivot().Position, 2) end)
		hrp.Anchored = true
		hrp.CFrame = model:GetPivot() + Vector3.new(0, 40, 0)
		hrp.AssemblyLinearVelocity = Vector3.zero
		local t0 = os.clock()
		while model.Parent and os.clock() - t0 < 8 and not model:FindFirstChildWhichIsA("BasePart", true) do
			task.wait(0.1)
		end
		hrp.Anchored = false
		if not model.Parent or not model:FindFirstChildWhichIsA("BasePart", true) then return false end
	end
	hrp.CFrame = CFrame.new(model:GetPivot().Position + Vector3.new(0, 3, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.5)
	return model.Parent ~= nil
end

-- บินไปจุดหนึ่ง: ขอ stream -> ลอยรอ -> ยิง ray หาพื้น -> ลงยืน
local function goTo(cf)
	local hrp = hrpOf()
	if not hrp then return false end
	local p = cf.Position
	pcall(function() lp:RequestStreamAroundAsync(p) end)
	hrp.Anchored = true
	hrp.CFrame = CFrame.new(p + Vector3.new(0, 30, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
	task.wait(1.2)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.IgnoreWater = true
	local spot
	for attempt = 1, 4 do
		rp.FilterDescendantsInstances = { lp.Character }
		local hit = workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), rp)
		if hit and math.abs(hit.Position.Y - p.Y) < 40 then
			spot = hit.Position
			break
		end
		task.wait(0.5)
	end
	hrp.CFrame = CFrame.new((spot or p) + Vector3.new(0, 5, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.Anchored = false
	if not spot then log("NOTE: no ground found near the target, dropped at saved height") end
	return true
end

local function findNPC(pat)
	local w = workspace:FindFirstChild("world")
	local roots = { w and w:FindFirstChild("npcs"), w and w:FindFirstChild("map") }
	for _, root in ipairs(roots) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("Model") and d.Name:lower():find(pat, 1, true) then return d end
			end
		end
	end
	return nil
end

local function loadedNPC()
	local m = findNPC("frankenstein")
	if m and m:FindFirstChildWhichIsA("BasePart", true) then return m end
	return nil
end

local function waitNPC(secs)
	local t0 = os.clock()
	while running and os.clock() - t0 < secs do
		local m = loadedNPC()
		if m then return m end
		task.wait(0.4)
	end
	return nil
end

local function firePrompt(pp, useFire)
	if fireproximityprompt and useFire then
		pcall(fireproximityprompt, pp)
	else
		pcall(function()
			pp:InputHoldBegin()
			task.wait(0.2)
			pp:InputHoldEnd()
		end)
	end
end

local function openDialog(model)
	local pp = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	local t0 = os.clock()
	while not pp and model.Parent and os.clock() - t0 < 6 do
		task.wait(0.4)
		pp = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	end
	if not pp then
		log("NOTE: no prompt on " .. model.Name)
		return false
	end
	pcall(function()
		pp.HoldDuration = 0
		pp.RequiresLineOfSight = false
		pp.MaxActivationDistance = 40
	end)
	for attempt = 1, 4 do
		if not model.Parent then return false end
		local w1 = os.clock()
		while model.Parent and not pp.Enabled and os.clock() - w1 < 6 do task.wait(0.3) end
		local hrp = hrpOf()
		if hrp and (hrp.Position - promptPos(model)).Magnitude > 10 then tpTo(model) end
		local pin = hrpOf()
		if pin then pin.Anchored = true end -- ยืนนิ่งระหว่างคุย กันฟิสิกส์ดันออก
		dialogAt[model] = nil
		task.wait(0.1)
		firePrompt(pp, attempt % 2 == 1)
		local w0 = os.clock()
		while os.clock() - w0 < 4.5 do
			if dialogAt[model] then break end
			task.wait(0.1)
		end
		if dialogAt[model] then
			log("TALK " .. model.Name)
			return true
		end
		log("NOTE: no dialog yet on " .. model.Name .. " (try " .. attempt .. ")")
		task.wait(0.6)
	end
	local pin = hrpOf()
	if pin then pin.Anchored = false end
	return false
end

-- เลือกตัวเลือกผ่าน remote (สำรอง ถ้ากดปุ่มบนจอไม่เจอ) รูปแบบเดียวกับที่ goblin script ใช้เลือก difficulty
local function pickRemote(npc, words)
	local cfg = dialogCfg[npc]
	local node = cfg and cfg.dialog and cfg.dialog[1]
	local ch = node and node.choices
	if not (DI and type(ch) == "table") then return false end
	for i, c in ipairs(ch) do
		local t = norm(clean(tostring(c.text or c.arg or "")))
		for _, w in ipairs(words) do
			if t:find(w, 1, true) then
				log(("PICK '%s' -> DialogInteract(1, %d)"):format(t:sub(1, 50), i))
				local ok, res = pcall(function() return DI:InvokeServer(1, i) end)
				log("DialogInteract returned " .. tostring(ok) .. " " .. fmt(res))
				return ok
			end
		end
	end
	return false
end

---------------------------------------------------------------- go to Frankenstein
local function dutchmanCaptain()
	local w = workspace:FindFirstChild("world")
	local m = w and w:FindFirstChild("map")
	local f = m and m:FindFirstChild("Fischfright26")
	local g = f and f:FindFirstChild("Green")
	local r = g and g:FindFirstChild("Reaping Dutchman")
	return r and r:FindFirstChild("Dutchman Captain")
end

local function sail()
	local cap = dutchmanCaptain()
	if not cap then
		log("SAIL: Dutchman not loaded - going to the deck")
		goTo(CFrame.new(CFG.hallowDeck))
		local t0 = os.clock()
		while running and not dutchmanCaptain() and os.clock() - t0 < 8 do task.wait(0.3) end
		cap = dutchmanCaptain()
		if not cap then
			log("NOTE: Dutchman Captain not found - is the ship docked at Moosewood?")
			return false
		end
	end
	if not openDialog(cap) then
		log("NOTE: could not open the Dutchman dialog")
		return false
	end
	local h = hrpOf()
	if h then h.Anchored = false end
	local ok1, res = false, nil
	if DI then
		ok1, res = pcall(function() return DI:InvokeServer(1, 1) end) -- ยืนยันแล้วใน goblin log
		log("SAIL DialogInteract(1, 1) -> " .. tostring(ok1) .. " " .. fmt(res))
	end
	if not ok1 then
		if not clickText({ "set sail" }, 3) then tap(Enum.KeyCode.One, 0.15) end
	end
	return true
end

local function ensureFrank()
	local m = loadedNPC()
	if m then return m end
	setStatus("to cemetery")
	goTo(CFrame.new(CFG.cemetery))
	m = waitNPC(8)
	if m then return m end
	setStatus("sail to Hallow")
	if sail() then
		local t0 = os.clock()
		while running and os.clock() - t0 < 25 do -- รอเรือถึง
			m = loadedNPC()
			if m then return m end
			task.wait(0.5)
		end
		goTo(CFrame.new(CFG.cemetery))
		m = waitNPC(12)
	end
	if not m then
		log("NOTE: Frankenstein not found. Stand at the cemetery by hand, press Dump prompts, send the log.")
	end
	return m
end

---------------------------------------------------------------- inventory + recipe check
local function inventory()
	local out = {}
	local function add(t)
		if t:IsA("Tool") then
			local parts = { norm(t.Name) }
			for k, v in pairs(t:GetAttributes()) do parts[#parts + 1] = norm(tostring(k) .. "=" .. tostring(v)) end
			for _, c in ipairs(t:GetChildren()) do
				if c:IsA("StringValue") then parts[#parts + 1] = norm(c.Value) end
			end
			out[#out + 1] = { tool = t, name = norm(t.Name), blob = table.concat(parts, " ") }
		end
	end
	for _, t in ipairs(lp.Backpack:GetChildren()) do add(t) end
	if lp.Character then
		for _, t in ipairs(lp.Character:GetChildren()) do add(t) end
	end
	return out
end

local function take(inv, spec, used)
	local mut, nm = spec:match("^(.-)|(.+)$")
	nm = norm(nm or spec)
	mut = mut and norm(mut)
	for _, it in ipairs(inv) do
		if not used[it] and it.name:find(nm, 1, true) and (not mut or it.blob:find(mut, 1, true)) then
			used[it] = true
			return it
		end
	end
	return nil
end

local function check(r)
	local inv = inventory()
	local used = {}
	local missing, manual = {}, {}
	local function scan(list, label)
		for _, spec in ipairs(list or {}) do
			if spec:sub(1, 1) == "?" then
				manual[#manual + 1] = label .. ": " .. spec:sub(2)
			elseif not take(inv, spec, used) then
				missing[#missing + 1] = label .. ": " .. spec
			end
		end
	end
	scan(r.lan, "lantern")
	scan(r.hand, "hand")
	scan(r.destroy, "destroy")
	return missing, manual, #inv
end

local function checkHands()
	local inv = inventory()
	local used = {}
	local p = {}
	for _, h in ipairs(HANDS) do
		p[#p + 1] = h[1] .. "=" .. (take(inv, h[2], used) and "yes" or "no")
	end
	return table.concat(p, " | ")
end

---------------------------------------------------------------- auto place (ทดลอง)
local function promptsNear(center, rad)
	local out = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			local pos = ppPos(d)
			if pos and (pos - center).Magnitude <= rad then out[#out + 1] = d end
		end
	end
	return out
end

local function place(r, npc)
	local center = npc:GetPivot().Position
	local inv = inventory()
	local used = {}
	local _, hum = hrpOf()
	local function put(spec, label)
		local it = take(inv, spec, used)
		if not it then
			log("PLACE skip (not in backpack): " .. spec)
			return false
		end
		local base = norm(spec:match("|(.+)$") or spec)
		pcall(function() hum:EquipTool(it.tool) end)
		task.wait(0.35)
		local target
		for _, pp in ipairs(promptsNear(center, 90)) do
			if pp.Enabled then
				local blob = norm(pp.ActionText .. " " .. pp.ObjectText .. " " .. pp:GetFullName())
				if blob:find(base, 1, true) then
					target = pp
					break
				end
			end
		end
		if not target then
			log(("PLACE no prompt mentions '%s' (%s) - Dump prompts at the altar and send the log"):format(base, label))
			return false
		end
		pcall(function()
			target.HoldDuration = 0
			target.RequiresLineOfSight = false
		end)
		local hh = hrpOf()
		local pos = ppPos(target)
		if hh and pos and (hh.Position - pos).Magnitude > 12 then
			hh.CFrame = CFrame.new(pos + Vector3.new(0, 3, 4))
			task.wait(0.4)
		end
		firePrompt(target, true)
		log("PLACE " .. label .. ": " .. spec .. " -> " .. target:GetFullName())
		task.wait(0.8)
		return true
	end
	for _, s in ipairs(r.lan or {}) do
		if s:sub(1, 1) ~= "?" then put(s, "lantern") end
	end
	for _, s in ipairs(r.hand or {}) do
		if s:sub(1, 1) ~= "?" then put(s, "hand") end
	end
	pcall(function() hum:UnequipTools() end)
end

---------------------------------------------------------------- start ritual
local function closeDialog()
	for _, g in ipairs(texts()) do
		if norm(clean(g.Text)):find("nevermind", 1, true) then
			local b = clickTarget(g)
			if b then
				press(b)
				return true
			end
		end
	end

	-- Fallback when this dialog has no "Nevermind" button: leave the NPC's 28-stud range.
	local hrp, hum = hrpOf()
	local npc = loadedNPC()
	if hrp and hum and npc then
		local delta = hrp.Position - npc:GetPivot().Position
		local dir = delta.Magnitude > 0.1 and delta.Unit or Vector3.new(1, 0, 0)
		local goal = hrp.Position + dir * 32
		hrp.Anchored = false
		hum:MoveTo(goal)
		local deadline = os.clock() + 3
		while running and os.clock() < deadline and (hrp.Position - npc:GetPivot().Position).Magnitude < 29 do
			task.wait(0.1)
		end
		if (hrp.Position - npc:GetPivot().Position).Magnitude < 29 then
			hrp.CFrame = CFrame.new(goal + Vector3.new(0, 2, 0))
		end
		return (hrp.Position - npc:GetPivot().Position).Magnitude >= 28
	end
	return false
end

local recUntil = 0
local function recOn(s) recUntil = os.clock() + (s or 120) end
local function recActive() return running and os.clock() < recUntil end

local function treeText(inst, maxLines)
	local out = {}
	local function walk(o, d)
		if #out >= maxLines then return end
		local x = ""
		if o:IsA("TextLabel") or o:IsA("TextButton") then x = ' "' .. clean(o.Text):sub(1, 50) .. '"' end
		out[#out + 1] = string.rep("  ", d) .. o.Name .. " [" .. o.ClassName .. "]" .. x
		for _, c in ipairs(o:GetChildren()) do walk(c, d + 1) end
	end
	walk(inst, 0)
	return table.concat(out, "\n")
end

local pgSeen = {}
for _, c in ipairs(lp.PlayerGui:GetChildren()) do pgSeen[c.Name] = true end
conns[#conns + 1] = lp.PlayerGui.ChildAdded:Connect(function(c)
	if not c:IsA("ScreenGui") or c == gui or pgSeen[c.Name] then return end
	pgSeen[c.Name] = true
	task.delay(0.5, function()
		if running and c.Parent then
			local ok, s = pcall(treeText, c, 60)
			log("NEWGUI " .. c.Name .. "\n" .. (ok and s or tostring(s)))
		end
	end)
end)

conns[#conns + 1] = lp.PlayerGui.DescendantAdded:Connect(function(d)
	if not recActive() or d:IsDescendantOf(gui) then return end
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		task.delay(0.2, function()
			if d.Parent and #d.Text > 1 then log("NEWTEXT " .. d:GetFullName() .. " | " .. clean(d.Text):sub(1, 80)) end
		end)
	end
end)

local KEYS = { "pumpkin", "lantern", "altar", "ritual", "hand", "skull" }
conns[#conns + 1] = workspace.DescendantAdded:Connect(function(d)
	if not recActive() then return end
	local isPP = d:IsA("ProximityPrompt")
	local n = d.Name:lower()
	local hit = isPP
	for _, k in ipairs(KEYS) do if n:find(k, 1, true) then hit = true end end
	if not hit then return end
	local m = d:FindFirstAncestorOfClass("Model")
	if m and m:FindFirstChildOfClass("Humanoid") then return end -- ignore player/NPC body parts
	task.delay(0.3, function()
		if not d.Parent then return end
		local npc = loadedNPC()
		local c = npc and npc:GetPivot().Position or CFG.cemetery
		local ok, pos = pcall(function()
			if isPP then return ppPos(d) end
			if d:IsA("PVInstance") then return d:GetPivot().Position end
		end)
		if ok and pos and (pos - c).Magnitude <= CFG.scanRadius * 2 then
			local x = isPP and (" | action='" .. d.ActionText .. "' object='" .. d.ObjectText .. "'") or ""
			log("NEW " .. d.ClassName .. " " .. d:GetFullName() .. x)
		end
	end)
end)

local function unpin()
	local h = hrpOf()
	if h then h.Anchored = false end
end

local function startRitual(r)
	if not CFG.force then
		local miss = check(r)
		if #miss > 0 then
			log(("START blocked: %d item(s) missing for %s. Turn Force ON to try anyway."):format(#miss, r.name))
			for _, m in ipairs(miss) do log("  MISSING " .. m) end
			setStatus(("missing %d - press Check"):format(#miss))
			return false
		end
	end
	setStatus("finding Frankenstein")
	local npc = ensureFrank()
	if not npc then
		setStatus("Frankenstein not found")
		return false
	end
	setStatus("talking")
	if not openDialog(npc) then
		setStatus("could not open dialog")
		return false
	end

	local t1 = clickText({ "begin a ritual", "begin ritual", "start a ritual" }, 5)
	if not t1 and not pickRemote(npc, { "begin a ritual", "ritual" }) then
		log("NOTE: no 'begin a ritual' option found - dumping the screen")
		dumpUI(40)
		unpin()
		setStatus("no ritual option - see log")
		return false
	end
	task.wait(CFG.dialogWait)
	dumpUI(30)

	setStatus("picking " .. r.name)
	local t2 = clickText({ r.key }, 6)
	if not t2 then
		log("NOTE: ritual '" .. r.name .. "' not in the menu (locked yet?) - dumping the screen")
		dumpUI(40)
		unpin()
		setStatus("ritual not in menu - see log")
		return false
	end
	task.wait(CFG.dialogWait)
	local t3 = clickText({ "yes", "confirm", "accept", "okay", "100" }, 3)
	if t3 then task.wait(CFG.dialogWait) end
	recOn(180)
	dumpUI(30)
	if not closeDialog() then log("NOTE: no 'nevermind' after confirm") end
	unpin()
	task.delay(4, function() if running then dumpUI(60) end end)

	log("RITUAL " .. r.name .. " picked - watch the EVENT / PROMPT lines for the timer and placement")
	if CFG.autoPlace then
		setStatus("placing items")
		place(r, npc)
	end
	setStatus("started: " .. r.name)
	saved.started[r.name] = os.time()
	saveNow()
	return true
end

---------------------------------------------------------------- dumps
local function dumpPrompts()
	local npc = loadedNPC()
	local center = npc and npc:GetPivot().Position or CFG.cemetery
	local hrp = hrpOf()
	if not npc and hrp and (hrp.Position - CFG.cemetery).Magnitude < 400 then center = hrp.Position end
	local list = promptsNear(center, CFG.scanRadius)
	log(("---- PROMPTS within %d of (%.0f, %.0f, %.0f): %d ----"):format(CFG.scanRadius, center.X, center.Y, center.Z, #list))
	for i, pp in ipairs(list) do
		if i > 80 then break end
		local pos = ppPos(pp)
		log(("PP %s | action='%s' object='%s' | enabled=%s | d=%.0f"):format(
			pp:GetFullName(), pp.ActionText, pp.ObjectText, tostring(pp.Enabled), pos and (pos - center).Magnitude or -1))
	end
end

local function dumpInventory()
	log("---- INVENTORY (Backpack tools) ----")
	local n = 0
	for _, it in ipairs(inventory()) do
		n = n + 1
		if n > 120 then break end
		log("ITEM " .. it.tool.Name .. " | " .. it.blob:sub(1, 160))
	end
	log("HANDS: " .. checkHands())
end

local function dumpRemotes()
	if not net then
		log("NOTE: packages.Net not found")
		return
	end
	local p = {}
	for _, r in ipairs(net:GetChildren()) do p[#p + 1] = r.Name end
	table.sort(p)
	local s = table.concat(p, ", ")
	log(("---- NET REMOTES (%d) ----"):format(#p))
	for i = 1, #s, 1500 do log("REMOTES " .. s:sub(i, i + 1499)) end
end

---------------------------------------------------------------- UI
gui.Name = "FrankRitual"
gui.ResetOnSpawn = false
local okP = pcall(function()
	gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not okP or not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end
gui.DisplayOrder = 999

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 292)
frame.Position = UDim2.fromOffset(10, 80)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
frame.BorderSizePixel = 0
frame.Parent = gui

local header = Instance.new("TextLabel")
header.Size = UDim2.fromOffset(260, 26)
header.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
header.BorderSizePixel = 0
header.TextColor3 = Color3.new(1, 1, 1)
header.Font = Enum.Font.GothamBold
header.TextSize = 14
header.Text = "Frankenstein Ritual v1  (drag)"
header.Parent = frame

local drag, dStart, fStart = false, nil, nil
conns[#conns + 1] = header.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		drag, dStart, fStart = true, i.Position, frame.Position
	end
end)
conns[#conns + 1] = UIS.InputChanged:Connect(function(i)
	if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dStart
		frame.Position = UDim2.new(fStart.X.Scale, fStart.X.Offset + d.X, fStart.Y.Scale, fStart.Y.Offset + d.Y)
	end
end)
conns[#conns + 1] = UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		drag = false
	end
end)

local busy = false
local function run(fn)
	if busy then
		setStatus("busy... wait")
		return
	end
	task.spawn(function()
		busy = true
		local ok, err = pcall(fn)
		busy = false
		if not ok then
			unpin()
			log("ERR " .. tostring(err))
			setStatus("error - see log")
		end
	end)
end

local function mkBtn(txt, x, y, w, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, 28)
	b.Position = UDim2.fromOffset(x, y)
	b.BackgroundColor3 = Color3.fromRGB(48, 48, 66)
	b.BorderSizePixel = 0
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.Text = txt
	b.Parent = frame
	b.MouseButton1Click:Connect(cb)
	return b
end

local ritualLbl = Instance.new("TextLabel")
ritualLbl.Size = UDim2.fromOffset(168, 28)
ritualLbl.Position = UDim2.fromOffset(46, 34)
ritualLbl.BackgroundTransparency = 1
ritualLbl.TextColor3 = Color3.fromRGB(255, 200, 120)
ritualLbl.Font = Enum.Font.GothamBold
ritualLbl.TextSize = 14
ritualLbl.Parent = frame

local function refreshRitual()
	local r = R[CFG.ritual]
	ritualLbl.Text = ("%d/%d  %s%s"):format(CFG.ritual, #R, r.name, saved.started[r.name] and " *" or "")
	saveNow()
end
refreshRitual()

mkBtn("<", 8, 34, 34, function()
	CFG.ritual = CFG.ritual - 1
	if CFG.ritual < 1 then CFG.ritual = #R end
	refreshRitual()
end)
mkBtn(">", 218, 34, 34, function()
	CFG.ritual = CFG.ritual + 1
	if CFG.ritual > #R then CFG.ritual = 1 end
	refreshRitual()
end)

mkBtn("Check", 8, 68, 78, function()
	run(function()
		local r = R[CFG.ritual]
		local miss, man, n = check(r)
		log(("CHECK %s | backpack tools %d | missing %d | check by hand %d"):format(r.name, n, #miss, #man))
		for _, m in ipairs(miss) do log("  MISSING " .. m) end
		for _, m in ipairs(man) do log("  BY HAND " .. m) end
		log("HANDS: " .. checkHands())
		setStatus(("%s: missing %d, by hand %d"):format(r.name, #miss, #man))
	end)
end)
mkBtn("Go", 92, 68, 78, function()
	run(function()
		local m = ensureFrank()
		if m then
			tpTo(m)
			setStatus("at Frankenstein")
		else
			setStatus("not found - see log")
		end
	end)
end)
mkBtn("Start", 176, 68, 76, function()
	run(function() if startRitual(R[CFG.ritual]) then refreshRitual() end end)
end)

mkBtn("Dump prompts", 8, 102, 118, function() run(dumpPrompts) setStatus("prompts dumped") end)
mkBtn("Dump inventory", 130, 102, 122, function() run(dumpInventory) setStatus("inventory dumped") end)
mkBtn("Dump UI", 8, 136, 118, function() run(function() dumpUI(80) end) setStatus("UI dumped") end)
mkBtn("Dump remotes", 130, 136, 122, function() run(dumpRemotes) setStatus("remotes dumped") end)

local placeBtn, forceBtn
placeBtn = mkBtn("Auto place: OFF", 8, 170, 118, function()
	CFG.autoPlace = not CFG.autoPlace
	placeBtn.Text = "Auto place: " .. (CFG.autoPlace and "ON" or "OFF")
end)
forceBtn = mkBtn("Force: OFF", 130, 170, 122, function()
	CFG.force = not CFG.force
	forceBtn.Text = "Force: " .. (CFG.force and "ON" or "OFF")
end)

mkBtn("Copy log", 8, 204, 118, function()
	local s = table.concat(lines, "\n")
	if setclipboard then
		pcall(setclipboard, s)
		setStatus(("copied %d lines"):format(#lines))
	else
		setStatus("no setclipboard - read the console")
	end
end)

local function stop()
	running = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
	unpin()
end
genv.FrankStop = stop
mkBtn("Close", 130, 204, 122, stop)

statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.fromOffset(244, 44)
statusLbl.Position = UDim2.fromOffset(8, 240)
statusLbl.BackgroundTransparency = 1
statusLbl.TextColor3 = Color3.fromRGB(190, 190, 205)
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 12
statusLbl.TextWrapped = true
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextYAlignment = Enum.TextYAlignment.Top
statusLbl.Text = "ready - Check first, then Start"
statusLbl.Parent = frame

log("READY v1 | ritual=" .. R[CFG.ritual].name)
