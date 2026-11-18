-- Supplied hack feature implementation follows in its own scope.
local function startBaselineHacks()
local GameplayData=require("GameLua.GameCore.Data.GameplayData")
local EPawnState=import("EPawnState")
local UKismetSystemLibrary=import("KismetSystemLibrary")
-- ============================================================
-- STEP 1: MWConfig initialization (SKIN FIX)
-- ============================================================
_G.MWConfig = _G.MWConfig or {
    -- Other features (toggles ke liye)
    EspPlayer      = false,
    EspPlayerBox   = false,
    EspPlayerName  = false,
    EspPlayerHP    = false,
    EspPlayerSkeleton = false,
    EspVehicle     = false,
    EspVeh_Car     = false,
    EspVeh_Moto    = false,
    EspVeh_Offroad = false,
    EspVeh_Boat    = false,
    EspVeh_Heavy   = false,
    WallHackV2     = false,
    AimTouchEnable = false,
    IpadView       = false,
    UnlockFPS      = false,
    SpeedRunV2     = false,
    FastCar        = false,
    VehicleInstantStop = false,
}

-- V9.8: Skin anti-ban gate. ON (default) = skins sirf client par dikhti hain:
-- koi bhi wear-cache / depot show / head-show server write nahi hoti. OFF =
-- purana poora behaviour (server-synced writes bhi).
_G.g_vipserver=_G.g_vipserver or "VIP Server"
local g_vipserver_credit=_G.g_vipserver
local g_vipserver_StartSettingsMaintenance
-- BYPASS START
-- ============================================================================
-- ============================================================================
-- Ultimate Wallhack + ESP Detection Bypass
-- Source: BRPlayerCharacterBase.lua (118 KB script) — Bypass.lua integrated
-- Auto-runs on pawn spawn, independent of login / license / expiry.
-- Wrapped with BYPASS START / BYPASS END markers for later separation.
-- ============================================================================

do -- V9.5 integration: scope helper locals below the Lua chunk limit.
local function _BYPASS_InstallUltimateWallhackBypass()
    if _G.__ULTIMATE_WH_BYPASS_LOADED then return end

    local nop = function() end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE == true
    end

    ---------- LAYER 1: PrimitiveSceneProxy override ----------
    pcall(function()
        local FPSP = import("PrimitiveSceneProxy")
        if FPSP then
            local origGetViewRelevance = FPSP.GetViewRelevance
            FPSP.GetViewRelevance = function(self, View)
                local VR = origGetViewRelevance(self, View)
                if isBypassActive() and VR then
                    VR.bRenderCustomDepth = false
                    VR.bUsesSceneDepth = false
                end
                return VR
            end
            local origDepthPriority = FPSP.GetDepthPriorityGroup
            FPSP.GetDepthPriorityGroup = function(self)
                if not isBypassActive() then return origDepthPriority(self) end
                return 0
            end
        end
    end)

    ---------- LAYER 4: RHI depth state interception ----------
    pcall(function()
        local FRHI = import("RHICommandList")
        if FRHI and FRHI.SetDepthState then
            local origSetDepth = FRHI.SetDepthState
            FRHI.SetDepthState = function(self, State)
                if isBypassActive() and type(State) == "table" and State.DepthEnable ~= nil then
                    State.DepthEnable = true
                end
                return origSetDepth(self, State)
            end
        end
    end)

    ---------- LAYER 6: Material property queries ----------
    pcall(function()
        local UMat = import("Material")
        local UMatInst = import("MaterialInstance")
        local UMatDyn = import("MaterialInstanceDynamic")

        if UMat then
            UMat.__origDDT = UMat.GetDisableDepthTest
            UMat.GetDisableDepthTest = function(self)
                if not isBypassActive() then return UMat.__origDDT(self) end
                return false
            end
            UMat.__origBM = UMat.GetBlendMode
            UMat.GetBlendMode = function(self)
                if not isBypassActive() then return UMat.__origBM(self) end
                return 0
            end
            UMat.__origHash = UMat.GetMaterialHash
            UMat.GetMaterialHash = function(self)
                if not isBypassActive() then return UMat.__origHash(self) end
                return "FAKE_HASH"
            end
            UMat.__origVM = UMat.VerifyMaterial
            UMat.VerifyMaterial = function(self)
                if not isBypassActive() then return UMat.__origVM(self) end
                return true
            end
        end
        if UMatInst then
            UMatInst.__origDDT = UMatInst.GetDisableDepthTest
            UMatInst.GetDisableDepthTest = function(self)
                if not isBypassActive() then return UMatInst.__origDDT(self) end
                return false
            end
            UMatInst.__origBM = UMatInst.GetBlendMode
            UMatInst.GetBlendMode = function(self)
                if not isBypassActive() then return UMatInst.__origBM(self) end
                return 0
            end
            UMatInst.__origBM2 = UMatInst.GetBaseMaterial
            UMatInst.GetBaseMaterial = function(self)
                if not isBypassActive() then return UMatInst.__origBM2(self) end
                return nil
            end
        end
        if UMatDyn then
            local oldGetVec = UMatDyn.K2_GetVectorParameterValue
            UMatDyn.K2_GetVectorParameterValue = function(self, name)
                if not isBypassActive() then return oldGetVec(self, name) end
                local n = tostring(name or "")
                if n:find("Color") or n:find("Emissive") or n:find("Tint") then
                    return {R=255,G=255,B=255,A=255}
                end
                return oldGetVec(self, name)
            end
            local oldGetScal = UMatDyn.K2_GetScalarParameterValue
            UMatDyn.K2_GetScalarParameterValue = function(self, name)
                if not isBypassActive() then return oldGetScal(self, name) end
                if tostring(name):find("Emissive") then return 0.0 end
                return oldGetScal(self, name)
            end
        end
    end)

    ---------- LAYER 8: Kernel & memory spoof ----------
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local kc = SubMgr:Get("ClientKernelCheckSubsystem")
            if kc and not kc.__akhooked then
                local origIKC = kc.IsKernelClean
                kc.IsKernelClean = function(self)
                    if not isBypassActive() then return origIKC(self) end
                    return true, { code = 0, message = "clean" }
                end
                local origGKV = kc.GetKernelVersion
                kc.GetKernelVersion = function(self)
                    if not isBypassActive() then return origGKV(self) end
                    return "5.4.0-generic"
                end
                kc.__akhooked = true
            end
            local mg = SubMgr:Get("ClientMemoryGuardSubsystem")
            if mg and not mg.__akhooked then
                local origIMC = mg.IsMemoryClean
                mg.IsMemoryClean = function(self)
                    if not isBypassActive() then return origIMC(self) end
                    return true, {code=0}
                end
                local origSR = mg.ScanResult
                mg.ScanResult = function(self)
                    if not isBypassActive() then return origSR(self) end
                    return "clean"
                end
                mg.__akhooked = true
            end
        end
    end)

    ---------- LAYER 9: MARK SYSTEM SPOOF ----------
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        local MarkMgr = InGameMarkTools and InGameMarkTools.ScreenMarkManager
        if MarkMgr then
            local ourMarkGroups = {1006, 9999}
            if MarkMgr.GetAllActiveMarks then
                local orig = MarkMgr.GetAllActiveMarks
                MarkMgr.GetAllActiveMarks = function(self, ...)
                    local marks = orig(self, ...)
                    if not isBypassActive() or not marks or type(marks) ~= "table" then return marks end
                    local filtered = {}
                    for _, m in ipairs(marks) do
                        if m.MarkGroupID and not table.contains(ourMarkGroups, m.MarkGroupID) then
                            table.insert(filtered, m)
                        end
                    end
                    return filtered
                end
            end
            if MarkMgr.GetMarkCount then
                local orig = MarkMgr.GetMarkCount
                MarkMgr.GetMarkCount = function(self, ...)
                    local count = orig(self, ...)
                    if isBypassActive() then count = math.max(0, count - 2) end
                    return count
                end
            end
            if MarkMgr.GetMarksByGroup then
                local orig = MarkMgr.GetMarksByGroup
                MarkMgr.GetMarksByGroup = function(self, groupId)
                    if isBypassActive() and (groupId == 1006 or groupId == 9999) then return {} end
                    return orig(self, groupId)
                end
            end
            if MarkMgr.OnAddMark then MarkMgr.OnAddMark = nop end
            if MarkMgr.OnRemoveMark then MarkMgr.OnRemoveMark = nop end
        end
    end)

    ---------- LAYER 10: REPLAY UI DETECTION KILL ----------
    pcall(function()
        if _G.Replay_IsEnemyFrameUIExisted then
            local orig = _G.Replay_IsEnemyFrameUIExisted
            _G.Replay_IsEnemyFrameUIExisted = function(...)
                if isBypassActive() then return false end
                return orig(...)
            end
        end
        if _G.Replay_CreateEnemyFrameUI then
            local orig = _G.Replay_CreateEnemyFrameUI
            _G.Replay_CreateEnemyFrameUI = function(...)
                if isBypassActive() then
                    local backup = _G.ReportEnemyFrameUI or nop
                    _G.ReportEnemyFrameUI = nop
                    local res = orig(...)
                    _G.ReportEnemyFrameUI = backup
                    return res
                end
                return orig(...)
            end
        end
    end)

    ---------- LAYER 13: ESP-RELATED REPORT FUNCTIONS KILL ----------
    pcall(function()
        local espReports = {
            "ReportESPBox","ReportESPHealth","ReportMiniMapESP","ReportEnemyFrameUI",
            "ReportMarkCreated","ReportMarkDestroyed","MarkSuspiciousESP",
            "OnScreenMarkAdd","OnScreenMarkRemove","ReportDistanceMarker",
            "ReportWallhackESP","SendESPData","UploadESPInfo"
        }
        for _, fn in ipairs(espReports) do
            if _G[fn] then _G[fn] = nop end
            for _, mod in pairs(package.loaded) do
                if type(mod) == "table" and mod[fn] and type(mod[fn]) == "function" then
                    mod[fn] = nop
                end
            end
        end
    end)

    -- Gameplay RPC and packet dispatch are left untouched.

    _G.__ULTIMATE_WH_BYPASS_LOADED = true
    print("[ok] Ultimate Wallhack + ESP Detection Bypass Installed")
end

-- ========================================================================
-- WHABypass TABLE + DETECTION SUBSYSTEM SPOOF
-- ========================================================================
local function _BYPASS_SetupWHABypassTable()
    local bypass = {}
    local function nop() end
    local function returnTrue() return true end
    local function returnFalse() return false end
    local function safe_require(mod)
        local ok, res = pcall(require, mod)
        return ok and res or nil
    end
    local function tryImport(name)
        local ok, lib = pcall(import, name)
        return ok and lib or nil
    end

    local function blockScreenshots()
        pcall(function()
            local SS = tryImport("ScreenshotMaker") or tryImport("ScreenshotMTDer")
            if SS then
                SS.MakePicture = function() return "" end
                SS.ReMakePicture = function() return "" end
                SS.HasCaptured = returnTrue
            end
        end)
    end

    local function blockGameplayCallbacks()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        if GC._WHABlocked then return end

        local reportFuncs = {
            "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms",
            "ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt",
            "ReportPlayerMoveRoute","ReportPlayerPosition","ReportAimFlow","ReportHitFlow",
            "ReportWallHack","ReportAimbot","ReportSpeedHack","ReportMagicBullet",
            "ReportAbnormalMaterial","ReportDepthTestChange","ReportMemoryException",
            "ReportMaterialScan","ReportShaderOverride","ReportCircleFlow",
            "OnPlayerRPCValidateFailed","OnPlayerActorChannelError",
            "OnPlayerSpectateException","OnShutdownAfterError"
        }
        for _, fn in ipairs(reportFuncs) do GC[fn] = nop end

        local oldStateChanged = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, state, ...)
            if state and type(state) == "string" then
                local s = state:lower()
                if s:find("cheat") or s:find("ban") or s:find("integrity") then return end
            end
            if oldStateChanged then return oldStateChanged(UID, state, ...) end
        end

        GC._WHABlocked = true
    end

    local function spoofTssSdk()
        pcall(function()
            local t = _G.TssSdk
            if t then
                t.GetFileMD5 = function() return "" end
                t.VerifyFileSignature = returnTrue
                t.CheckIntegrity = returnTrue
                t.ScanMemory = function() return true, {} end
                t.IsEmulator = returnFalse
                t.OnRecvData = nop
            end
        end)
    end

    local function disableDetectionSubsystems()
        local sm = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not sm then return end

        local targetSubs = {
            "ClientWallhackDetectionSubsystem", "ClientESPDetectionSubsystem",
            "ClientAimTrackingSubsystem", "ShootVerifySubSystemClient",
            "ClientRenderCheckSubsystem", "ClientMemoryGuardSubsystem",
            "ClientKernelCheckSubsystem", "ClientHawkEyePatrolSubsystem",
            "ClientAntiCheatSubsystem", "IntegrityCheckSubsystem",
            "FileCheckSubsystem", "AvatarExceptionSubsystem"
        }
        for _, sn in ipairs(targetSubs) do
            local sub = sm:Get(sn)
            if sub and type(sub) == "table" then
                for k, v in pairs(sub) do
                    if type(v) == "function" then
                        if k:find("Report") or k:find("Send") or k:find("Verify") or
                           k:find("Check") or k:find("Detect") or k:find("Scan") then
                            sub[k] = nop
                        end
                    end
                end

                if sn == "ClientWallhackDetectionSubsystem" then
                    sub.IsVisionNormal = returnTrue
                    sub.GetVisibilityRate = function() return math.random(60, 85) end
                elseif sn == "ClientESPDetectionSubsystem" then
                    sub.HasESP = returnFalse
                    sub.CheckOverlay = function() return "clean" end
                elseif sn == "ClientAimTrackingSubsystem" then
                    sub.GetAimData = function()
                        return { accuracy = math.random(45,65), headshotRate = math.random(15,35) }
                    end
                    sub.IsAimNormal = returnTrue
                elseif sn == "ClientMemoryGuardSubsystem" then
                    sub.IsMemoryClean = function() return true, {code=0} end
                    sub.ScanResult = function() return "clean" end
                elseif sn == "ShootVerifySubSystemClient" then
                    sub.OnShootVerifyFailed = nop
                    sub.VerifyShot = returnTrue
                end
            end
        end
    end

    local function disableHiggsBoson()
        pcall(function()
            local hbc = safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if hbc then
                hbc.bMHActive = false
                hbc.bCallPreReplication = false
                if hbc.ControlMHActive then hbc.ControlMHActive = nop end
                if hbc.StartAvatarCheck then hbc.StartAvatarCheck = nop end
                if hbc.BlackList then
                    for k in pairs(hbc.BlackList) do hbc.BlackList[k] = nil end
                end
            end
            if _G.AvatarCheckCallback then
                _G.AvatarCheckCallback.StartAvatarCheck = nop
                _G.AvatarCheckCallback.OnReportItemID = nop
            end
            _G.BlackList = {}
        end)
    end

    function bypass.Init()
        blockScreenshots()
        blockGameplayCallbacks()
        spoofTssSdk()
        disableDetectionSubsystems()
        disableHiggsBoson()
    end

    _G.WHABypass = bypass
end

-- ========================================================================
-- BYPASS EXECUTION
-- ========================================================================
local function _BYPASS_Execute()
    if _G._BYPASS_DONE then return end
    local ok, err = pcall(function()
        _G._WHA_BYPASS_ACTIVE = true
        _BYPASS_InstallUltimateWallhackBypass()
        _BYPASS_SetupWHABypassTable()
        if _G.WHABypass and _G.WHABypass.Init then
            _G.WHABypass.Init()
        end
        _G._BYPASS_DONE = true
        print("[ORDER] All bypasses executed")
    end)
    if not ok then
        print("[ORDER] Bypass failed, will retry:", tostring(err))
        _G._BYPASS_DONE = false
    end
end

-- Expose globally so callback bridge / any other scope can trigger it.
_G._BYPASS_Execute = _BYPASS_Execute
end -- V9.5 integration: exported callback retains the scoped helpers.

-- ============================================================================
-- ============================================================================
-- BYPASS END
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- MAIN SCRIPT CALLBACK BRIDGE | tracking and settings maintenance
-- Each adapter runs the original game callback once, then its existing addition.
-- ============================================================================
-- MAIN SCRIPT CALLBACK BRIDGE END

-- Immediate bypass attempt on script load (in case a pawn is already present).
if Client and _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end

_G.MWConfig = _G.MWConfig or {}
_G.MWConfig.IpadView = _G.MWConfig.IpadView or false
_G.LexusState = _G.LexusState or {}
_G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
_G.LexusState.CustomTextData.IpadViewFOV = _G.LexusState.CustomTextData.IpadViewFOV or 120

-- g_vipserver_GetLocalPlayer made by VIP Server
local function g_vipserver_GetLocalPlayer()
    local ok, GDP = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GDP then return nil end
    local player = GDP.GetPlayerCharacter()
    if player and slua.isValid(player) then return player end
    return nil
end

-- g_vipserver_ApplyiPadView made by VIP Server
local function g_vipserver_ApplyiPadView()
    local player = g_vipserver_GetLocalPlayer()
    if not player then return end
    local cam = player.ThirdPersonCameraComponent
    if not cam or not slua.isValid(cam) then return end
    if player.bIsWeaponAiming then return end

    if _G.MWConfig.IpadView and _G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized then
        local targetFOV = _G.LexusState.CustomTextData.IpadViewFOV or 120
        if cam.FieldOfView ~= targetFOV then
            cam.FieldOfView = targetFOV
        end
    else
        if cam.FieldOfView ~= 90 then
            cam.FieldOfView = 90
        end
    end
end

-- Persistent ESP feature settings.
local g_vipserver_ESPOptionDefaults = {
    Name=false, Line=false, Box=false, Health=false, Distance=false, Skeleton=false, Counter=false
}
_G.g_vipserver_ESPOptions = _G.g_vipserver_ESPOptions or {}
for k,v in pairs(g_vipserver_ESPOptionDefaults) do
    if _G.g_vipserver_ESPOptions[k] == nil then _G.g_vipserver_ESPOptions[k] = v end
end
local g_vipserver_ESPSettingsFile = "VIP_SERVER_UMG_ESP_settings.lua"
local function g_vipserver_ESPSettingsPaths()
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_vipserver_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_vipserver_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_vipserver_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_vipserver_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_vipserver_ESPSettingsFile,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/"..g_vipserver_ESPSettingsFile,
        "ShadowTrackerExtra/Saved/SaveGames/"..g_vipserver_ESPSettingsFile,
        g_vipserver_ESPSettingsFile
    }
    local home=nil
    pcall(function() if os and os.getenv then home=os.getenv("HOME") end end)
    if type(home)=="string" and home~="" then
        table.insert(paths,1,home.."/Documents/ShadowTrackerExtra/Saved/SaveGames/"..g_vipserver_ESPSettingsFile)
    end
    return paths
end
-- Replace the SaveGames file only after write/flush/close succeed where Lua
-- exposes rename. A failed temporary write keeps the last saved file intact.
local function g_vipserver_ESPWriteSettings(path,payload)
    local atomic=os and type(os.rename)=="function"
    local target=atomic and path..".tmp" or path
    local opened,file=pcall(io.open,target,"w")
    if not opened or not file then return false,"Open failed: "..target end
    local closed=false
    local ok,err=pcall(function()
        local result,reason=file:write(payload)
        assert(result,reason or "Settings write failed")
        if file.flush then local flushed,why=file:flush();assert(flushed,why or "Settings flush failed") end
        local result,reason=file:close();closed=true
        assert(result,reason or "Settings close failed")
    end)
    if not closed then pcall(function() file:close() end) end
    if ok and atomic then
        local called,result,reason=pcall(os.rename,target,path)
        ok=called and result~=nil and result~=false
        err=ok and nil or (reason or result or "Settings rename failed")
    end
    if not ok and atomic and os.remove then pcall(os.remove,target) end
    return ok,err,atomic
end

local g_vipserver_ESPLoadedSettingsPath=nil

local function g_vipserver_ESPLoadSettings()
    if not io or type(io.open) ~= "function" then return false end
    local paths = g_vipserver_ESPSettingsPaths()
    local content=nil
    for _,path in ipairs(paths) do
        local ok,f=pcall(io.open,path,"r")
        if ok and f then
            local rok,text=pcall(function() return f:read("*a") end)
            pcall(function() f:close() end)
            if rok and type(text)=="string" and text~="" then content=text;g_vipserver_ESPLoadedSettingsPath=path;break end
        end
    end
    if not content then return false end
    for k in pairs(g_vipserver_ESPOptionDefaults) do
        local v=content:match(k.."%s*=%s*(true)") or content:match(k.."%s*=%s*(false)")
        if v then _G.g_vipserver_ESPOptions[k]=(v=="true") end
    end
    return true
end
g_vipserver_ESPLoadSettings()

-- One authorization session per Lua process; gameplay identity never owns it.
do
    local licenseScope
local VIPLicenseConfig = {
    url = 'https://zakpubg.skin/connect', game = 'BGMI',
        timeout = 10, clockSkew = 120, expiryPath = nil,
        manualExpiry = "2026-12-31 23:59:59", tamperTolerance = 5,
        secret = 'ZAKPUBGSKIN',
    }

local VIPLicenseCore = (function()
    local Primitives = (function()
        local floor, abs, max = math.floor, math.abs, math.max
        local byte, char, format = string.byte, string.char, string.format
        local U32 = 4294967296
        local AND, XOR = {}, {}
        for a = 0, 15 do for b = 0, 15 do
            local av, bv, both, different, place = a, b, 0, 0, 1
            for _ = 1, 4 do
                local x, y = av % 2, bv % 2
                if x == 1 and y == 1 then both = both + place end
                if x ~= y then different = different + place end
                av, bv, place = floor(av / 2), floor(bv / 2), place * 2
            end
            AND[a * 16 + b], XOR[a * 16 + b] = both, different
        end end
        local function bitop(a, b, lookup)
            local value, place = 0, 1
            for _ = 1, 8 do
                value = value + lookup[(a % 16) * 16 + b % 16] * place
                a, b, place = floor(a / 16), floor(b / 16), place * 16
            end
            return value
        end
        local function band(a, b) return bitop(a, b, AND) end
        local function bxor(a, b) return bitop(a, b, XOR) end
        local function rol(value, amount)
            local divisor = 2 ^ (32 - amount)
            return (value % divisor) * 2 ^ amount + floor(value / divisor)
        end
        local function little32(value)
            return char(value % 256, floor(value / 256) % 256,
                floor(value / 65536) % 256, floor(value / 16777216) % 256)
        end
        local K = {
            0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
            0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
            0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
            0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
            0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
            0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
            0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
            0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
        }
        local SHIFT = {7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21}
        local function md5_raw(input)
            assert(type(input) == "string", "MD5 input must be a string")
            local size = #input
            local message = input .. char(128) .. string.rep(char(0), (55 - size) % 64)
                .. little32((size * 8) % U32) .. little32(floor(size / 536870912))
            local h0, h1, h2, h3 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
            local words = {}
            for offset = 1, #message, 64 do
                for j = 0, 15 do
                    local a, b, c, d = byte(message, offset + j * 4, offset + j * 4 + 3)
                    words[j] = a + b * 256 + c * 65536 + d * 16777216
                end
                local a, b, c, d = h0, h1, h2, h3
                for i = 0, 63 do
                    local f, g, shiftBase
                    if i < 16 then
                        f, g, shiftBase = band(b, c) + band(U32 - 1 - b, d), i, 0
                    elseif i < 32 then
                        f, g, shiftBase = band(d, b) + band(U32 - 1 - d, c), (5 * i + 1) % 16, 4
                    elseif i < 48 then
                        f, g, shiftBase = bxor(bxor(b, c), d), (3 * i + 5) % 16, 8
                    else
                        local bOrNotD = U32 - 1 - band(U32 - 1 - b, d)
                        f, g, shiftBase = bxor(c, bOrNotD), (7 * i) % 16, 12
                    end
                    local nextB = (b + rol((a + f + K[i + 1] + words[g]) % U32,
                        SHIFT[shiftBase + i % 4 + 1])) % U32
                    a, b, c, d = d, nextB, b, c
                end
                h0, h1, h2, h3 = (h0 + a) % U32, (h1 + b) % U32, (h2 + c) % U32, (h3 + d) % U32
            end
            return little32(h0) .. little32(h1) .. little32(h2) .. little32(h3)
        end
        local function hex(input)
            return (input:gsub(".", function(c) return format("%02x", byte(c)) end))
        end
        local function md5(input) return hex(md5_raw(input)) end
        local function form_encode(input)
            assert(type(input) == "string", "Form value must be a string")
            return (input:gsub("[^A-Za-z0-9%-%._~ ]", function(c)
                return format("%%%02X", byte(c)) end):gsub(" ", "+"))
        end
        local function constant_time_equal(a, b)
            if type(a) ~= "string" or type(b) ~= "string" then return false end
            local difference = abs(#a - #b)
            for i = 1, max(#a, #b) do
                difference = difference + abs((byte(a, i) or 0) - (byte(b, i) or 0))
            end
            return difference == 0
        end
        local function name_uuid(input)
            local digest = md5_raw(input)
            local h = hex(digest:sub(1,6) .. char(byte(digest,7) % 16 + 48)
                .. digest:sub(8,8) .. char(byte(digest,9) % 64 + 128) .. digest:sub(10))
            return h:sub(1,8) .. "-" .. h:sub(9,12) .. "-" .. h:sub(13,16)
                .. "-" .. h:sub(17,20) .. "-" .. h:sub(21,32)
        end
        return {md5 = md5, md5_raw = md5_raw, form_encode = form_encode,
                constant_time_equal = constant_time_equal, name_uuid = name_uuid}
    end)()

    local SESSION_KEY='__LunarLicenseSessionV7'
    local function loadSession()
        local t=rawget(_G,SESSION_KEY)
        if type(t)=='table' and t.authorized==true and t.scope==licenseScope then return t end
    end
    local function saveSession(expiresAt)
        _G[SESSION_KEY]={authorized=true,expiresAt=expiresAt,scope=licenseScope}
    end
    local function clearSession() _G[SESSION_KEY]=nil end

    local CreateLocalExpiry = function(cfg)
        local E = {}
        local expiredText = 'Mod expired. Contact for renewal.'
        local tamperText  = "Don't be over smart"
        local blockedMessage, blockedPhase
        local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
        local function parse(text)
            if type(text) ~= 'string' then return nil end
            local y,m,d,h,n,s = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
            y,m,d,h,n,s = tonumber(y),tonumber(m),tonumber(d),tonumber(h),tonumber(n),tonumber(s)
            if not y or not m or not d or not h or not n or not s or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or n > 59 or s > 59 then return nil end
            local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
            local months = {31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
            if d < 1 or d > months[m] then return nil end
            local prior = y - 1
            local days = 365 * (y - 1970) + math.floor(prior / 4) - math.floor(1969 / 4)
                - math.floor(prior / 100) + math.floor(1969 / 100)
                + math.floor(prior / 400) - math.floor(1969 / 400)
            for i = 1, m - 1 do days = days + months[i] end
            return (days + d - 1) * 86400 + h * 3600 + n * 60 + s - 6 * 3600
        end
        local configured = type(cfg.manualExpiry) == 'string' and cfg.manualExpiry:match('^%s*(.-)%s*$') or cfg.manualExpiry
        local expiry = parse(configured)
        local skew = cfg.clockSkew or 120
        if configured ~= nil and configured ~= '' and not expiry then
            blockedMessage, blockedPhase = 'Invalid local expiry date. Use YYYY-MM-DD HH:MM:SS.', 'error'
        end
        local function block(message, phase)
            if not blockedMessage then blockedMessage, blockedPhase = message, phase end
            return false, blockedMessage, blockedPhase
        end
        function E.Status() return not blockedMessage, blockedMessage, blockedPhase end
        function E.MarkTampered() return block(tamperText, 'tampered') end
        function E.GetExpiry() return expiry end
        function E.Accept(server, now, world, phone, rtt)
            if blockedMessage then return E.Status() end
            if not finite(server) or not finite(now) or now < 0 or world == nil
                or not finite(rtt) or rtt < 0 or not finite(phone) then
                return block('Clock verification unavailable.', 'error')
            end
            if math.abs(phone - server) > skew + rtt then return E.MarkTampered() end
            if expiry and server + rtt >= expiry then return block(expiredText, 'expired') end
            return true
        end
        return E
    end

    local CreateAuth = function(P, cfg, deps)
        local A = {}
        licenseScope=P.md5(cfg.url.."\0"..cfg.game.."\0"..cfg.secret)
        local phase, message = 'locked', 'Enter your key to sign in.'
        local allowed, pending, generation = false, nil, 0
        local expiresAt
        local lastRequestLatencyMs, lastResponseTime, lastResponseWorld
        local startFn, stopFn, payloadStarted, restartRequired
        local localExpiry = deps.localExpiry
        do
            local stored = loadSession()
            if stored then
                allowed = true; expiresAt = stored.expiresAt
                phase, message = 'active', 'Session restored'
            end
        end
        if localExpiry then
            local ok, text, state = localExpiry.Status()
            if not ok then message, phase = text, state end
        end
        local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
        local function readClock()
            local ok, n, w = pcall(deps.clock)
            if ok and finite(n) and n >= 0 and w ~= nil then return n, w end
        end
        local function notify(text, state)
            message, phase = text, state
            if type(deps.status) == 'function' then pcall(deps.status, text, state) end
        end
        local function stopPayload()
            if payloadStarted then
                payloadStarted = false
                local ok, accepted = pcall(stopFn)
                if not ok or accepted == false then restartRequired = true end
            end
        end
        local function revoke(text, state)
            generation = generation + 1
            allowed, pending, expiresAt = false, nil, nil
            lastRequestLatencyMs, lastResponseTime, lastResponseWorld = nil, nil, nil
            stopPayload()
            local localDenied = false
            if localExpiry then
                local ok, localText, localPhase = localExpiry.Status()
                if not ok then text, state, localDenied = localText, localPhase, true end
            end
            notify(restartRequired and not localDenied
                and 'Restart required: payload cleanup failed.' or text, state or 'error')
        end
        local function startPayload()
            if payloadStarted or not startFn then return true end
            payloadStarted = true
            local before = generation
            local ok, accepted = pcall(startFn)
            if not ok or accepted == false then
                restartRequired = true
                revoke('Restart required: offline script startup failed.', 'error')
                return false
            end
            return generation == before and allowed
        end
        local function denyReason(reason)
            if type(reason) ~= 'string' then return 'Expired' end
            local lower = reason:sub(1, 120):lower():gsub('[_%s%-]+', ' ')
            if lower == 'max devices' or lower == 'maximum devices'
                or lower == 'max devices reached' then return 'Max Devices' end
            local clean = reason
            for _, field in ipairs({'key', 'serial'}) do
                if pending and type(pending[field]) == 'string' and #pending[field] > 0 then
                    local needle = pending[field]:gsub('([^%w])', '%%%1')
                    clean = clean:gsub(needle, '[' .. field .. ']')
                end
            end
            if type(cfg.secret) == 'string' and #cfg.secret > 0 then
                clean = clean:gsub(cfg.secret:gsub('([^%w])', '%%%1'), '[credential]')
            end
            clean = clean:gsub('[%c]', ' '):sub(1, 120)
            return clean == '' and 'Expired' or ('Expired: ' .. clean)
        end
        local function configuredExpiry(result)
            if cfg.expiryPath == nil then return nil, true end
            if type(cfg.expiryPath) ~= 'table' or #cfg.expiryPath == 0 then return nil, false end
            local v = result
            for _, name in ipairs(cfg.expiryPath) do
                if type(v) ~= 'table' then return nil, false end
                v = rawget(v, name)
            end
            return v, finite(v) and v > 0 and v % 1 == 0
        end
        local function begin(key)
            if restartRequired or pending then return false end
            if localExpiry then
                local ok, text, state = localExpiry.Status()
                if not ok then revoke(text, state); return false end
            end
            if type(key) ~= 'string' then key = '' end
            key = key:match('^%s*(.-)%s*$')
            if #key == 0 or #key > 512 then
                revoke('Expired: enter a valid key.', 'denied'); return false
            end
            local now, world = readClock()
            if not now then
                revoke('Phone clock unavailable. Please try again.', 'error'); return false
            end
            local okSerial, serial = pcall(deps.serial, key)
            if not okSerial or type(serial) ~= 'string' or #serial == 0 or #serial > 512 then
                local failure=tostring(serial)
                local text='Device identifier unavailable.'
                if not okSerial and failure:find('DEVICE_CACHE_CONFLICT',1,true) then
                    text='Saved device records conflict. Restore the registered device backup.'
                elseif not okSerial and failure:find('DEVICE_CACHE_RECOVERY_REQUIRED',1,true) then
                    text='Saved device data could not be recovered. Check storage or restore its backup.'
                elseif not okSerial and failure:find('DEVICE_CACHE_SAVE_FAILED',1,true) then
                    text='Device cache could not be saved. Check game storage access.'
                end
                revoke(text,'error');return false
            end
            generation = generation + 1
            local requestId = generation
            pending = {id = requestId, key = key, serial = serial,
                       started = now, world = world, deadline = now + cfg.timeout}
            notify('Signing in...', 'pending')
            if not pending or pending.id ~= requestId or generation ~= requestId then return false end
            local body = 'game=' .. P.form_encode(cfg.game)
                .. '&user_key=' .. P.form_encode(key)
                .. '&serial=' .. P.form_encode(serial)
            local function received(success, raw)
                if not pending or pending.id ~= requestId or generation ~= requestId then return end
                local current, worldNow = readClock()
                if not current or worldNow ~= pending.world or current < pending.started
                    or current >= pending.deadline then
                    revoke('Request expired. Please sign in again.', 'error'); return
                end
                if success ~= true or type(raw) ~= 'string' or #raw == 0 or #raw > 32768 then
                    revoke('Connection failed. Please try again.', 'error'); return
                end
                local ok, result = pcall(deps.decode, raw)
                if not ok or type(result) ~= 'table' then
                    revoke('Invalid server response.', 'error'); return
                end
                if result.status ~= true then revoke(denyReason(result.reason), 'denied'); return end
                local data = result.data
                if type(data) ~= 'table' or type(data.token) ~= 'string' or #data.token ~= 32
                    or not data.token:match('^[%x]+$') or not finite(data.rng) or data.rng % 1 ~= 0 then
                    revoke('Incomplete server response.', 'error'); return
                end
                local expected = P.md5(cfg.game .. '-' .. key .. '-' .. serial .. '-' .. cfg.secret)
                if not P.constant_time_equal(data.token:lower(), expected) then
                    revoke('Server token verification failed.', 'denied'); return
                end
                local okWall, wall = pcall(deps.wall)
                if not okWall or not finite(wall) then
                    revoke('Phone clock unavailable.', 'error'); return
                end
                if localExpiry then
                    local accepted, text, state = localExpiry.Accept(
                        data.rng, current, worldNow, wall, current - pending.started)
                    if not accepted then revoke(text, state); return end
                elseif math.abs(wall - data.rng) > cfg.clockSkew then
                    revoke('Phone/server clock mismatch. Check automatic time.', 'error'); return
                end
                local expiry, validExpiry = configuredExpiry(result)
                if not validExpiry then
                    revoke('Configured server expiry field is missing or invalid.', 'error'); return
                end
                if expiry and expiry - data.rng - (current - pending.started) <= 0 then
                    revoke('Expired', 'denied'); return
                end
                local fixedExpiry = localExpiry and localExpiry.GetExpiry()
                if fixedExpiry then expiry = math.min(expiry or fixedExpiry, fixedExpiry) end
                lastRequestLatencyMs = (current - pending.started) * 1000
                lastResponseTime, lastResponseWorld = current, worldNow
                pending = nil
                allowed, expiresAt = true, expiry
                saveSession(expiresAt)
                if not startPayload() then return end
                notify('Login successful.', 'active')
            end
            local ok, accepted = pcall(deps.post, cfg.url,
                {['Content-Type'] = 'application/x-www-form-urlencoded'},
                body, received, cfg.timeout)
            if not ok or accepted == false then
                revoke('HTTP request could not start.', 'error'); return false
            end
            return true
        end
        function A.Login(key) if allowed then return false end; return begin(key) end
        function A.Tick()
            if not pending then return end
            local now, world = readClock()
            if not now or world ~= pending.world or now < pending.started then
                revoke('Login clock unavailable. Please try again.', 'locked'); return
            end
            if now >= pending.deadline then
                revoke('Request timed out. Please try again.', 'error')
            end
        end
        function A.IsAuthorized()
            if allowed and not restartRequired then return true end
            local stored = loadSession()
            if stored and not restartRequired then
                allowed = true; expiresAt = stored.expiresAt; return true
            end
            return false
        end
        function A.Logout() clearSession(); revoke('Expired: signed out.', 'locked') end
        function A.FailClosed(text, requiresRestart)
            if requiresRestart == true then restartRequired = true end
            revoke(text or 'Online access unavailable.', 'error')
        end
        function A.ReportClockTampering()
            if localExpiry then localExpiry.MarkTampered() end
            revoke("Correct Your Time & Date", 'tampered')
        end
        function A.Bind(onStart, onStop)
            if type(onStart) ~= 'function' or type(onStop) ~= 'function' then
                return false, 'START_AND_STOP_REQUIRED'
            end
            if startFn and (startFn ~= onStart or stopFn ~= onStop) then return false, 'ALREADY_BOUND' end
            startFn, stopFn = onStart, onStop
            if A.IsAuthorized() then return startPayload() end
            return true
        end
        function A.Unbind()
            revoke('Offline script disconnected.', 'locked')
            startFn, stopFn = nil, nil
        end
        function A.GetRemainingSeconds() return nil end
        function A.GetState()
            local authorized = A.IsAuthorized()
            local sample, age
            if authorized and lastRequestLatencyMs ~= nil then
                local now, world = readClock()
                if now and world == lastResponseWorld and now >= lastResponseTime then
                    sample, age = lastRequestLatencyMs, now - lastResponseTime
                end
            end
            return {
                phase = phase, message = message, authorized = authorized,
                sessionAuthorized = authorized, expiresAt = expiresAt,
                accessPolicy = "game_session", expiryCheckPolicy = "login_only",
                periodicRecheck = false, pending = pending ~= nil,
                linked = startFn ~= nil, restartRequired = restartRequired == true,
                lastRequestLatencyMs = sample, lastRequestLatencyAgeSeconds = age,
                latencyScope = "license_http_round_trip"
            }
        end
        return A
    end

    local Core = {Primitives = Primitives, createExpiry = CreateLocalExpiry}
    function Core.new(config, dependencies)
        assert(type(config) == 'table' and type(dependencies) == 'table',
            'License configuration and dependencies required')
        local deps = {}
        for key, value in pairs(dependencies) do deps[key] = value end
        if deps.localExpiry == nil then deps.localExpiry = CreateLocalExpiry(config) end
        return CreateAuth(Primitives, config, deps)
    end
    return Core
end)()

    local UI={Version="LunarUI.V9.NativeGradient.2"}
    local function member(o,k)
        if o==nil then return nil end
        local ok,v=pcall(function() return o[k] end);if ok then return v end
    end
    local function valid(o)
        if o==nil then return false end
        local ok,v=pcall(slua.isValid,o);return ok and v==true
    end
    local vectorClass=rawget(_G,"FVector2D") or import("Vector2D")
    local colorClass=rawget(_G,"FLinearColor") or import("LinearColor")
    local function vector(x,y) return vectorClass(x,y) end
    local function color(r,g,b,a)
        local function linear(v) v=v/255;if v<=0.04045 then return v/12.92 end;return ((v+0.055)/1.055)^2.4 end
        return colorClass(linear(r),linear(g),linear(b),a or 1)
    end
    local function visibility(w,v)
        local fn=member(w,"SetWidgetVisibility") or member(w,"SetVisibility")
        assert(type(fn)=="function","UI_VISIBILITY_UNAVAILABLE");fn(w,v)
    end
    local function parent()
        local ok,t=pcall(require,"GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if not ok or type(member(t,"GetMainControlBaseUI"))~="function" then return end
        local found,root=pcall(t.GetMainControlBaseUI);if not found or not valid(root) then return end
        local p=member(root,"CanvasPanel_0");if not valid(p) then p=member(root,"CanvasPanel_42") end
        if valid(p) then return p end
    end
    local function destroy(d)
        if not d then return end
        d.Visible=false
        if d.Event and d.Handle~=nil then pcall(function() d.Event:Remove(d.Handle) end) end
        if valid(d.Container) then pcall(function() d.Container:RemoveFromParent() end) end
        d.Submit=nil;d.Event=nil;d.Handle=nil;d.Container=nil;d.Parent=nil
        d.Input=nil;d.Button=nil;d.Status=nil;d.Title=nil;d.Detail=nil;d.Hint=nil;d.Design=nil;d.Cache=nil
    end
    -- Approved red/green frame, dark red/green heading, light full-color body.
    -- All gradient/angle/brush work happens at construction. No animation,
    -- background asset, network dependency, text outline or external backdrop.
    function UI.Build(kind,key,status,submit)
        local p=parent();if not p then return nil,"UI_NOT_READY" end
        local enums=UEnums.ESlateVisibility
        local passive=enums.SelfHitTestInvisible
        if enums.Visible==nil or passive==nil then return nil,"UI_ENUM_UNAVAILABLE" end
        local welcome=kind=="welcome"
        local W,H=welcome and 600 or 500,welcome and 276 or 248
        local scale=welcome and 0.8 or 1
        pcall(function()
            local v=p:GetCachedGeometry():GetLocalSize()
            if v.X>24 and v.Y>24 then scale=math.min(scale,(v.X-24)/W,(v.Y-24)/H) end
        end)
        local d={Parent=p,Visible=false,Submit=submit,Scale=scale}
        local ok,buildError=pcall(function()
            local function make(class,outer)
                local w=CGame:NewObjectFromPath("/Script/UMG."..class,outer)
                assert(valid(w),"UI_WIDGET_UNAVAILABLE");return w
            end
            d.Container=make("CanvasPanel",p)
            local design=make("CanvasPanel",d.Container);d.Design=design
            local artRoot=design
            local canCache,cache=pcall(make,"InvalidationBox",d.Container)
            if canCache and valid(cache) and type(member(cache,"SetCanCache"))=="function" then
                local attached=pcall(function()cache:AddChild(design);cache:SetCanCache(true);visibility(cache,passive)end)
                if attached then artRoot=cache;d.Cache=cache end
            end
            local artSlot=d.Container:AddChildToCanvas(artRoot)
            artSlot:SetAutoSize(false);artSlot:SetPosition(vector(0,0));artSlot:SetSize(vector(W,H));artSlot:SetZOrder(1)
            visibility(design,passive)
            local function add(w,x,y,ww,hh,z,dynamic)
                local slot=(dynamic and d.Container or design):AddChildToCanvas(w)
                slot:SetAutoSize(false);slot:SetPosition(vector(x,y));slot:SetSize(vector(ww,hh));slot:SetZOrder(z)
                return slot
            end
            -- Flatten static gradient rectangles before applying 50% alpha.
            -- Overlapping body/badge/button fills must not accumulate opacity.
            local artwork={}
            local function drawRect(x,y,ww,hh,c,z,opacity)
                local w=make("Border",d.Container)
                w:SetBrushColor(colorClass(c.R,c.G,c.B,opacity or .5));visibility(w,passive)
                add(w,x,y,ww,hh,z);return w
            end
            local function rect(x,y,ww,hh,c,z,opacity)
                artwork[#artwork+1]={X=x,Y=y,W=ww,H=hh,C=c,Z=z,A=opacity or .5,Order=#artwork+1}
            end
            local function renderArt()
                table.sort(artwork,function(a,b)
                    if a.Z==b.Z then return a.Order>b.Order end
                    return a.Z>b.Z
                end)
                local covered={}
                local function put(out,x,y,w,h)
                    if w>.00001 and h>.00001 then out[#out+1]={X=x,Y=y,W=w,H=h} end
                end
                for _,shape in ipairs(artwork) do
                    local pieces={{X=shape.X,Y=shape.Y,W=shape.W,H=shape.H}}
                    for _,cover in ipairs(covered) do
                        local nextPieces={}
                        for _,piece in ipairs(pieces) do
                            local x1=math.max(piece.X,cover.X);local y1=math.max(piece.Y,cover.Y)
                            local x2=math.min(piece.X+piece.W,cover.X+cover.W)
                            local y2=math.min(piece.Y+piece.H,cover.Y+cover.H)
                            if x2<=x1 or y2<=y1 then nextPieces[#nextPieces+1]=piece
                            else
                                put(nextPieces,piece.X,piece.Y,piece.W,y1-piece.Y)
                                put(nextPieces,piece.X,y2,piece.W,piece.Y+piece.H-y2)
                                put(nextPieces,piece.X,y1,x1-piece.X,y2-y1)
                                put(nextPieces,x2,y1,piece.X+piece.W-x2,y2-y1)
                            end
                        end
                        pieces=nextPieces;if #pieces==0 then break end
                    end
                    -- Coalesce adjacent pieces of the same solid gradient strip.
                    -- This keeps clipping from multiplying native UI widgets.
                    local changed=true
                    while changed do
                        changed=false
                        for i=1,#pieces do
                            local a=pieces[i]
                            for j=i+1,#pieces do
                                local b=pieces[j]
                                local vertical=math.abs(a.X-b.X)<.00001 and math.abs(a.W-b.W)<.00001
                                    and (math.abs(a.Y+a.H-b.Y)<.00001 or math.abs(b.Y+b.H-a.Y)<.00001)
                                local horizontal=math.abs(a.Y-b.Y)<.00001 and math.abs(a.H-b.H)<.00001
                                    and (math.abs(a.X+a.W-b.X)<.00001 or math.abs(b.X+b.W-a.X)<.00001)
                                if vertical or horizontal then
                                    local x,y=math.min(a.X,b.X),math.min(a.Y,b.Y)
                                    a.W=math.max(a.X+a.W,b.X+b.W)-x
                                    a.H=math.max(a.Y+a.H,b.Y+b.H)-y;a.X=x;a.Y=y
                                    table.remove(pieces,j);changed=true;break
                                end
                            end
                            if changed then break end
                        end
                    end
                    for _,piece in ipairs(pieces) do
                        drawRect(piece.X,piece.Y,piece.W,piece.H,shape.C,shape.Z,shape.A)
                    end
                    covered[#covered+1]=shape
                end
                artwork=nil
            end
            local function sample(stops,t,opacity)
                t=math.max(0,math.min(1,t));local a,b,u
                if t<=.5 then a,b,u=stops[1],stops[2],t*2 else a,b,u=stops[2],stops[3],(t-.5)*2 end
                return color(a[1]+(b[1]-a[1])*u,a[2]+(b[2]-a[2])*u,a[3]+(b[3]-a[3])*u,opacity)
            end
            local function panel(x,y,ww,hh,cut,stops,z,columns,opacity)
                columns=math.min(columns,12) -- Static cached gradient geometry.
                for i=0,columns-1 do
                    local a=ww*i/columns;local b=ww*(i+1)/columns
                    local inset=math.max(0,cut-math.min(a,ww-b))
                    rect(x+a,y+inset,b-a,hh-inset*2,sample(stops,(i+.5)/columns,opacity),z,opacity)
                end
            end
            local function rail(x,y,ww,hh,stops,z,columns)
                columns=math.min(columns,12)
                for i=0,columns-1 do
                    rect(x+ww*i/columns,y,ww/columns,hh,sample(stops,(i+.5)/columns),z)
                end
            end
            local function line(ax,ay,bx,by,th,c,z)
                local dx,dy=bx-ax,by-ay
                local len=math.sqrt(dx*dx+dy*dy)
                if len<=0 then return end
                local angle
                if dx==0 then angle=dy>=0 and 90 or -90
                else angle=math.atan(dy/dx)*180/math.pi;if dx<0 then angle=angle+180 end end
                local w=drawRect((ax+bx-len)/2,(ay+by-th)/2,len,th,c,z,z>=7 and 1 or .5)
                w:SetRenderTransformPivot(vector(.5,.5));w:SetRenderAngle(angle)
            end
            local slate=import("SlateColor")
            local fontObject
            if slua and type(slua.loadObject)=="function" then
                local loaded,obj=pcall(slua.loadObject,"/Engine/EngineFonts/Roboto.Roboto")
                if loaded and valid(obj) then fontObject=obj end
            end
            local function style(w,size,c,bold)
                local font=member(w,"Font")
                if font then
                    if type(font)=="table" then local copy={};for k,v in pairs(font) do copy[k]=v end;font=copy end
                    font.Size=size
                    if fontObject then font.FontObject=fontObject;font.TypefaceFontName=bold and "Bold" or "Regular" end
                    if font.OutlineSettings then
                        local outline=font.OutlineSettings
                        if type(outline)=="table" then local copy={};for k,v in pairs(outline) do copy[k]=v end;outline=copy end
                        outline.OutlineSize=0;font.OutlineSettings=outline
                    end
                    w:SetFont(font)
                end
                w:SetColorAndOpacity(slate(c))
                pcall(function()w:SetShadowOffset(vector(0,0));w:SetShadowColorAndOpacity(color(0,0,0,0))end)
                pcall(function() w:SetAutoWrapText(true) end)
            end
            local function text(value,x,y,ww,hh,size,c,z,bold,center,dynamic)
                local w=make("TextBlock",d.Container);w:SetText(value);style(w,size,c,bold)
                visibility(w,passive);add(w,x,y,ww,hh,z,dynamic)
                if center then pcall(function() w:SetJustification(1) end) end
                return w
            end
            local frame={{235,43,67},{132,80,46},{21,212,120}}
            local bright={{255,150,159},{241,212,180},{149,255,197}}
            local edge={{124,15,35},{65,51,28},{6,91,48}}
            local body={{255,162,154},{255,239,197},{139,239,176}}
            local header={{141,20,43},{76,48,38},{7,95,53}}
            local gold={{188,108,59},{242,219,164},{114,179,105}}
            local white=color(255,255,255)
            local forest=color(10,48,26)
            local burgundy=color(86,20,35)
            -- Perimeter only: an opaque full-panel backing would destroy
            -- the requested body transparency even with alpha on the body.
            panel(6,6,W-12,H-12,10,body,2,24,.5)
            rail(13,0,W-26,6,frame,3,24)
            rail(13,H-6,W-26,6,frame,3,24)
            rect(0,13,6,H-26,color(235,43,67),3)
            rect(W-6,13,6,H-26,color(21,212,120),3)
            rail(13,1,W-26,1.5,bright,3,24)
            rail(13,H-3,W-26,1.5,edge,3,24)
            rect(1,13,1.5,H-26,color(255,141,154),3)
            rect(W-3,13,1.5,H-26,color(142,255,193),3)
            for _,s in ipairs({{1,13,13,1},{1,H-13,13,H-1}}) do line(s[1],s[2],s[3],s[4],2,color(255,159,166),3) end
            for _,s in ipairs({{W-13,1,W-1,13},{W-13,H-1,W-1,H-13}}) do line(s[1],s[2],s[3],s[4],2,color(155,255,200),3) end
            panel(10,10,W-20,65,16,gold,4,24,1)
            panel(13,13,W-26,59,14,header,5,32,1)
            if welcome then
                d.Title=text("WELCOME TO ZAKPUBGSKIN PAK",24,22,W-48,42,19,white,7,true,true)
                local pw=math.min(340,W-72);local px=(W-pw)/2
                panel(px,99,pw,51,12,gold,4,16)
                panel(px+3,102,pw-6,45,10,{{179,29,52},{231,73,87},{178,26,47}},5,20)
                d.Detail=text("NO KILL LIMIT",px+16,109,pw-32,34,23,white,7,true,true)
                d.Hint=text("PLAY SMART LIKE PRO",30,165,W-60,32,17,forest,7,true,true)
            else
                d.Title=text("PREMIUM ZAKPUBGSKIN PAK",22,15,W-44,31,24,white,7,true,true)
                text("LOGIN PAGE",22,45,W-44,21,12,white,7,true,true)
                line(W/2-118,56,W/2-47,56,1,color(251,244,228),7)
                line(W/2+47,56,W/2+118,56,1,color(251,244,228),7)
                text("LOGIN KEY",22,82,W-44,20,13,burgundy,7,true,false)
                rail(27,104,W-54,2,gold,4,24)
                rail(27,143,W-54,2,gold,4,24)
                rect(20,111,2,27,color(188,108,59),4)
                rect(W-22,111,2,27,color(114,179,105),4)
                line(20,111,27,104,2,color(242,219,164),4)
                line(W-27,104,W-20,111,2,color(242,219,164),4)
                line(20,138,27,145,2,color(242,219,164),4)
                line(W-27,145,W-20,138,2,color(242,219,164),4)
                d.Input=make("EditableTextBox",d.Container)
                d.Input:SetText(key or "")
                -- Input-specific native style; TextBlock-only methods stay unused.
                local fg=forest;local bg=color(255,244,216,0)
                local inputStyle=member(d.Input,"WidgetStyle")
                if inputStyle then
                    if type(inputStyle)=="table" then local copy={};for k,v in pairs(inputStyle) do copy[k]=v end;inputStyle=copy end
                    local inputFont=member(inputStyle,"Font")
                    if inputFont then
                        if type(inputFont)=="table" then local copy={};for k,v in pairs(inputFont) do copy[k]=v end;inputFont=copy end
                        inputFont.Size=17
                        if fontObject then inputFont.FontObject=fontObject;inputFont.TypefaceFontName="Regular" end
                        inputStyle.Font=inputFont
                    end
                    inputStyle.ForegroundColor=slate(fg);inputStyle.ReadOnlyForegroundColor=slate(fg)
                    for _,name in ipairs({"BackgroundImageNormal","BackgroundImageHovered","BackgroundImageFocused","BackgroundImageReadOnly"}) do
                        local brush=member(inputStyle,name)
                        if brush then
                            if type(brush)=="table" then local copy={};for k,v in pairs(brush) do copy[k]=v end;brush=copy end
                            brush.TintColor=slate(bg);inputStyle[name]=brush
                        end
                    end
                    d.Input.WidgetStyle=inputStyle
                else
                    local inputFont=member(d.Input,"Font")
                    if inputFont then
                        if type(inputFont)=="table" then local copy={};for k,v in pairs(inputFont) do copy[k]=v end;inputFont=copy end
                        inputFont.Size=17;d.Input.Font=inputFont
                    end
                    d.Input.ForegroundColor=fg;d.Input.BackgroundColor=bg
                end
                local setForeground=member(d.Input,"SetForegroundColor")
                if type(setForeground)=="function" then setForeground(d.Input,fg) end
                pcall(function() d.Input:SetHintText("Enter your key") end)
                visibility(d.Input,enums.Visible);add(d.Input,23,107,W-46,35,8,true)
                d.Hint=text("Your key is saved automatically",22,149,W-44,19,11,burgundy,7,false,false)
                d.Status=text(status or "Enter your key",22,170,W-44,23,11,burgundy,8,false,false,true)
            end
            local button=make("Button",d.Container);d.Button=button
            local by=welcome and 212 or 201;local bh=welcome and 42 or 34
            local bw=welcome and 202 or 190;local bx=(W-bw)/2
            panel(bx-4,by-3,bw+8,bh+6,9,gold,4,16)
            panel(bx,by,bw,bh,8,{{0,112,51},{1,149,68},{0,99,46}},5,16)
            pcall(function() button:SetBackgroundColor(color(255,255,255,0)) end)
            visibility(button,enums.Visible)
            local label=make("TextBlock",button);label:SetText("OK");style(label,17,white,true);visibility(label,passive)
            local labelSlot=button:AddChild(label)
            pcall(function() labelSlot:SetHorizontalAlignment(2);labelSlot:SetVerticalAlignment(2) end)
            add(button,bx,by,bw,bh,9,true)
            d.Event=button.OnClicked
            d.Handle=d.Event:Add(function()
                if not d.Visible or d.Busy then return end
                if welcome then
                    destroy(d);d.Dismissed=true
                    local l=_G.LunarLoginRuntime;if l and l.WelcomeUI==d then l.WelcomeUI=nil end
                    return
                end
                local okRead,k=pcall(function() return d.Input:GetText() end)
                if not okRead or type(k)~="string" then return end
                k=k:match("^%s*(.-)%s*$")
                if #k==0 or #k>512 then d.Status:SetText("Enter a valid key");return end
                if d.Submit then d.Submit(k) end
            end)
            renderArt()
            local slot=p:AddChildToCanvas(d.Container);slot:SetAutoSize(false);slot:SetSize(vector(W,H));slot:SetZOrder(9200)
            local anchors=slot:GetAnchors();anchors.Minimum=vector(.5,.5);anchors.Maximum=vector(.5,.5)
            slot:SetAnchors(anchors);slot:SetAlignment(vector(.5,.5));slot:SetPosition(vector(0,0))
            d.Container:SetRenderTransformPivot(vector(.5,.5));d.Container:SetRenderScale(vector(scale,scale))
            visibility(d.Container,passive)
        end)
        if not ok then UI.LastBuildError=tostring(buildError);destroy(d);return nil,"UI_BUILD_UNAVAILABLE" end
        UI.LastBuildError=nil
        d.Visible=true;return d
    end
    _G.LunarUIAssetCache=nil
    -- Hot UI upgrades retain the existing verified or pending license session.
    local existing=_G.LunarLoginRuntime
    if existing and existing.UIFactory and existing.UIFactory.Version~=UI.Version
        and existing.Scope==VIPLicenseCore.Primitives.md5(VIPLicenseConfig.url.."\0"..VIPLicenseConfig.game.."\0"..VIPLicenseConfig.secret) then
        local visibleWelcome=existing.WelcomeUI and existing.WelcomeUI.Visible
        if existing.DestroyUI then existing.DestroyUI() end
        existing.UIFactory.Build=UI.Build;existing.UIFactory.Version=UI.Version
        if visibleWelcome then existing.WelcomeShown=false end
        existing.NeedsUpdate=true
    end
    local function hex(s) return (s:gsub('.',function(c) return string.format('%02x',string.byte(c)) end)) end
    local function unhex(s)
        if type(s)~="string" or #s>1024 or #s%2~=0 or s:find('[^%x]') then return nil end
        return (s:gsub('..',function(v) return string.char(tonumber(v,16)) end))
    end
    local current=_G.LunarLoginRuntime
    -- Existing runtime survives character recreation and source reload in this process.
    local expectedScope=VIPLicenseCore.Primitives.md5(VIPLicenseConfig.url.."\0"..VIPLicenseConfig.game.."\0"..VIPLicenseConfig.secret)
    if not current or current.Scope~=expectedScope then
        if current and current.DestroyUI then current.DestroyUI() end
        local L={Authorized=false,Pending=false,NeedsUpdate=true,WelcomeShown=false,
            Key="",Seed="",Scope=expectedScope,StorageVersion=1,Status="Enter your key",Diagnostics={HTTP=0,DeviceReads=0}}
        _G.LunarLoginRuntime=L
        L.UIFactory=UI
        -- Identity is pinned independently of the feature-settings location.
        -- All IO is bounded and happens at startup/login, or a delayed save retry.
        local paths=g_vipserver_ESPSettingsPaths()
        for i,path in ipairs(paths) do paths[i]=path:gsub("VIP_SERVER_UMG_ESP_settings.lua$","VIP_SERVER_LOGIN_V7_settings.lua") end
        local function loginPath(featurePath)
            if type(featurePath)~="string" then return nil end
            local prefix=featurePath:match("^(.*[/\\])[^/\\]+$")
            return (prefix or "").."VIP_SERVER_LOGIN_V7_settings.lua"
        end
        local function identityPath(path)
            return path:gsub("VIP_SERVER_LOGIN_V7_settings%.lua$","VIP_SERVER_DEVICE_V1_settings.lua")
        end
        local function digest(key,seed)
            return VIPLicenseCore.Primitives.md5("LUNAR-DEVICE-1\0"..L.Scope.."\0"..key.."\0"..seed)
        end
        local function readRecord(path,identity)
            if not (io and type(io.open)=="function") then return nil,"unreadable" end
            local ok,file,reason,code=pcall(io.open,path,"r")
            if not ok then return nil,"unreadable" end
            if not file then
                local text=type(reason)=="string" and reason:lower() or ""
                if reason==nil or code==2 or text:find("no such file",1,true)
                    or text:find("not found",1,true) or text:find("does not exist",1,true) then
                    return nil,"missing"
                end
                return nil,"unreadable"
            end
            local good,data=pcall(function() return file:read(4097) end)
            pcall(function() file:close() end)
            if not good or type(data)~="string" then return nil,"unreadable" end
            if #data>4096 then return nil,"invalid" end
            local scope=data:match('%f[%w_]Scope%s*=%s*"([%x]+)"')
            if scope and scope~=L.Scope then return nil,"other_scope" end
            if scope~=L.Scope then return nil,"invalid" end
            local key=unhex(data:match('%f[%w_]KeyHex%s*=%s*"([^"]*)"'))
            local seed=unhex(data:match('%f[%w_]SeedHex%s*=%s*"([^"]*)"'))
            if key==nil or seed==nil or #seed==0 or #seed>512 then return nil,"invalid" end
            local check=data:match('%f[%w_]Check%s*=%s*"([%x]+)"')
            local version=data:match('%f[%w_]Version%s*=%s*(%d+)')
            if identity or check or version then
                if version~="1" or check~=digest(key,seed) then return nil,"invalid" end
            end
            return {Key=key,Seed=seed,Path=path,Identity=identity,Checked=version=="1"},"valid"
        end
        local function candidates()
            local list,seen={},{}
            local function add(path)
                if type(path)=="string" and not seen[path] then seen[path]=true;list[#list+1]=path end
            end
            add(L.Path);add(L.PreferredPath)
            for _,path in ipairs(paths) do add(path) end
            return list
        end
        local function recover()
            if L.IdentityPinned then return true end
            local identities,legacy,issues={},{},{}
            local function collect(base,path,identity)
                local record,state=readRecord(path,identity)
                if record then
                    record.Base=base
                    local list=identity and identities or legacy;list[#list+1]=record
                elseif state=="invalid" or (state=="unreadable" and base==L.PreferredPath) then
                    issues[#issues+1]=state
                end
            end
            for _,base in ipairs(candidates()) do
                local device=identityPath(base)
                collect(base,device,true);collect(base,device..".bak",true)
                collect(base,base,false);collect(base,base..".bak",false)
            end
            local list=#identities>0 and identities or legacy
            local first=list[1]
            if first then
                for _,record in ipairs(list) do
                    if record.Seed~=first.Seed then
                        L.IdentityError="DEVICE_CACHE_CONFLICT";L.Diagnostics.Identity="conflict";return false
                    end
                end
                L.Seed=first.Seed;L.Key=first.Key;L.Path=first.Base
                if L.Key=="" then
                    for _,record in ipairs(list) do
                        if record.Key~="" then L.Key=record.Key;break end
                    end
                end
                -- A matching legacy copy can recover the key after a lost write.
                if L.Key=="" then
                    for _,record in ipairs(legacy) do
                        if record.Seed==L.Seed and record.Key~="" then L.Key=record.Key;break end
                    end
                end
                L.IdentityPinned=true;L.IdentityPersisted=true;L.HasIdentityRecord=first.Identity
                L.IdentityError=nil;L.Dirty=true
                L.Diagnostics.Identity=first.Identity and "restored" or "legacy_migration"
                return true
            end
            if #issues>0 then
                L.IdentityError="DEVICE_CACHE_RECOVERY_REQUIRED";L.Diagnostics.Identity="recovery_required";return false
            end
            L.IdentityError=nil;L.Diagnostics.Identity="new_install";return true
        end
        local function payload(key,seed)
            return 'return { Version = 1, Scope = "'..L.Scope..'", KeyHex = "'..hex(key)
                ..'", SeedHex = "'..hex(seed)..'", Check = "'..digest(key,seed)..'" }'
        end
        local function verifiedWrite(path,identity,key,seed,data)
            local current,state=readRecord(path,identity)
            if current and current.Checked and current.Seed==seed and current.Key==key then return true end
            if state=="unreadable" or state=="other_scope" then return false end
            if current and current.Seed~=seed and (identity or not L.HasIdentityRecord) then return false end
            local ok=g_vipserver_ESPWriteSettings(path,data)
            if not ok then return false end
            local result=readRecord(path,identity)
            return result~=nil and result.Checked and result.Seed==seed and result.Key==key
        end
        L.Save=function()
            if L.Seed=="" or L.IdentityError then return false end
            local key=L.AttemptKey or L.Key
            local data=payload(key,L.Seed)
            local preferred=candidates()
            for _,base in ipairs(preferred) do
                local device=identityPath(base)
                local old,oldState=readRecord(base,false)
                local current,currentState=readRecord(device,true)
                -- Never fork around an unreadable/conflicting saved identity.
                if oldState~="unreadable" and currentState~="unreadable"
                    and oldState~="other_scope" and currentState~="other_scope"
                    and (not old or old.Seed==L.Seed or L.HasIdentityRecord)
                    and (not current or current.Seed==L.Seed) then
                    local a=verifiedWrite(device,true,key,L.Seed,data)
                    local b=verifiedWrite(device..".bak",true,key,L.Seed,data)
                    local c=verifiedWrite(base,false,key,L.Seed,data)
                    local d=verifiedWrite(base..".bak",false,key,L.Seed,data)
                    if (a or b) and ((a and b) or c or d) then
                        L.Path=base;L.Key=key;L.IdentityPinned=true;L.IdentityPersisted=true;L.HasIdentityRecord=true
                        L.IdentityError=nil;L.Dirty=not (a and b and c and d)
                        L.SaveRetryAt=L.Dirty and (os.time()+30) or nil
                        L.SaveError=L.Dirty and "Device backup repair pending" or nil
                        L.Diagnostics.Identity=L.Dirty and "backup_pending" or "saved"
                        return true
                    end
                end
            end
            L.Dirty=true;L.SaveRetryAt=os.time()+30
            L.SaveError="Device cache could not be verified";L.Diagnostics.Identity="save_failed"
            return false
        end
        L.BindSettingsPath=function(featurePath)
            L.PreferredPath=loginPath(featurePath)
            -- Once recovered, neither the key nor seed is replaced by settings.
            if not L.IdentityPinned then recover() end
            if L.Seed~="" and not L.IdentityError and (L.Dirty or not L.IdentityPersisted) then L.Save() end
        end
        L.EnsureIdentity=function()
            if not L.IdentityPinned then
                L.Seed=""
                assert(recover(),L.IdentityError or "DEVICE_CACHE_RECOVERY_REQUIRED")
            end
            if L.Seed=="" then
                L.Diagnostics.DeviceReads=L.Diagnostics.DeviceReads+1
                local id=Client.GetPhoneDeviceID()
                assert(type(id)=="string" and #id>0 and #id<=512,"DEVICE_ID_UNAVAILABLE")
                L.Seed=id
            end
            local saved=L.Save()
            -- A readable previously stored identity stays usable on read-only
            -- storage. Backup repair must not invent or force a new device ID.
            assert(saved or L.IdentityPersisted,"DEVICE_CACHE_SAVE_FAILED")
        end
        recover()
        L.DestroyUI=function() destroy(L.LoginUI);destroy(L.WelcomeUI);L.LoginUI=nil;L.WelcomeUI=nil end
        local function wake()
            local f=_G.LunarFeatures;if f and f.Wake and not f.Token.Stopped then f.Wake() end
        end
        L.Core=VIPLicenseCore
        L.Auth=VIPLicenseCore.new(VIPLicenseConfig,{
            clock=function() local t=os.time();return t,L.Scope end,
            wall=function() return os.time() end,
            serial=function(key)
                L.EnsureIdentity()
                return VIPLicenseCore.Primitives.name_uuid('VIP-SERVER-V1\0'..key..'\0'..L.Seed)
            end,
            decode=function(raw) local json=require("common.json_util");return json.decode(raw) end,
            post=function(url,headers,body,callback,timeout)
                local http=ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
                L.Diagnostics.HTTP=L.Diagnostics.HTTP+1
                return http:Post(url,headers,body,nil,callback,timeout)
            end,
            status=function(message,phase)
                L.Status=message;L.Pending=phase=="pending"
                if phase=="active" then
                    L.Authorized=true;L.Key=L.AttemptKey or L.Key;L.Save()
                    destroy(L.LoginUI);L.LoginUI=nil
                else L.Authorized=false end
                L.NeedsUpdate=true
                local d=L.LoginUI
                if d then
                    if d.StatusText~=message then d.Status:SetText(message);d.StatusText=message end
                    if d.Busy~=L.Pending then
                        d.Busy=L.Pending
                        pcall(function() d.Input:SetIsEnabled(not L.Pending);d.Button:SetIsEnabled(not L.Pending) end)
                    end
                end
                wake()
            end
        })
        L.Authorized=L.Auth.IsAuthorized()
        L.Login=function(key)
            if L.Authorized or L.Pending then return false end
            L.AttemptKey=type(key)=="string" and key:match("^%s*(.-)%s*$") or ""
            local ok,result=pcall(L.Auth.Login,L.AttemptKey)
            if not ok then L.Status="Login could not start";L.Pending=false;L.NeedsUpdate=true;wake();return false end
            return result
        end
        L.Logout=function()
            L.Auth.Logout();L.Authorized=false;L.DestroyUI();L.NeedsUpdate=true;wake()
        end
        L.Update=function()
            if L.Pending then L.Auth.Tick() end
            if L.Dirty and (not L.SaveRetryAt or os.time()>=L.SaveRetryAt or os.time()<L.SaveRetryAt-30) then L.Save() end
            if L.Authorized then
                if not L.WelcomeShown then
                    local d=UI.Build("welcome")
                    if d then L.WelcomeUI=d;L.WelcomeShown=true end
                end
                L.NeedsUpdate=not L.WelcomeShown or L.Dirty
                return
            end
            local p=parent()
            if L.LoginUI and (not valid(L.LoginUI.Container) or p~=L.LoginUI.Parent) then destroy(L.LoginUI);L.LoginUI=nil end
            if not L.LoginUI then
                local d=UI.Build("login",L.Key,L.Status,L.Login)
                if d then
                    d.Busy=L.Pending;d.StatusText=L.Status;L.LoginUI=d
                    pcall(function() d.Input:SetIsEnabled(not L.Pending);d.Button:SetIsEnabled(not L.Pending) end)
                end
            end
            L.NeedsUpdate=true -- Half-second retry/readiness while locked only.
        end
    end
    _G.VIPLicenseLogin=function(key) return _G.LunarLoginRuntime.Login(key) end
    _G.VIPLicenseLogout=function() return _G.LunarLoginRuntime.Logout() end
    _G.VIPLicenseStatus=function()
        local l=_G.LunarLoginRuntime
        return {authorized=l.Authorized,pending=l.Pending,message=l.Status,
            periodicRecheck=false,expiryCheckPolicy="login_only",saveOK=not l.Dirty,identityState=l.Diagnostics.Identity}
    end

end

-- Settings registration follows the supplied working native-page reference.
-- Feature rows, option values and authentication stay owned by this script.
local g_vipserver_EnsureHackMenu
do
    local VERSION = "LunarSettings.V9.13.AimClean"
    local function runtime()
        local state = _G.LunarNativeSettingsRuntime
        if type(state) ~= "table" then state = {}; _G.LunarNativeSettingsRuntime = state end
        return state
    end
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function loadTable(name)
        local ok, value = pcall(require, name)
        if not ok then
            if package and package.loaded and type(package.loaded[name]) ~= "table" then
                package.loaded[name] = nil
            end
            error(name .. ": " .. tostring(value), 0)
        end
        assert(type(value) == "table", name .. ": SETTINGS_MODULE_NOT_READY")
        return value
    end
    local function register(catalog, page)
        if type(catalog) ~= "table" or type(page) ~= "table" then return false end
        local found = false
        for i = #catalog, 1, -1 do
            local entry = catalog[i]
            if type(entry) == "table" and entry.Key == "HackMenu" then
                if found then table.remove(catalog, i) else catalog[i] = page; found = true end
            end
        end
        if not found then table.insert(catalog, 1, page) end
        return true
    end
    local function looksLikeCatalog(value, allowEmpty)
        if type(value) ~= "table" then return false end
        local first = value[1]
        if type(first) == "table" and first.Key ~= nil then return true end
        return allowEmpty and next(value) == nil
    end
    local function isMainSettings(config)
        local key
        if type(config) == "string" then key = config
        else
            key = member(config, "keyName") or member(config, "KeyName")
                or member(config, "key") or member(config, "Key")
        end
        if key == nil then return false end
        local lower = string.lower(tostring(key))
        return lower:find("setting_main", 1, true) ~= nil
            and lower:find("custom", 1, true) == nil
    end
    local function injectShowCatalog(manager, config, args, count)
        local actual, first = config, 1
        if config == manager then actual, first = args[1], 2 end
        if not isMainSettings(actual) then return end
        local state = runtime()
        if not state.Page then return end
        state.LastShowUIInjected = false
        for i = first, count do
            if looksLikeCatalog(args[i], false) then
                state.LastShowUIInjected = register(args[i], state.Page)
                state.LastShowUICatalogIndex = i
                break
            end
        end
        if not state.LastShowUIInjected and looksLikeCatalog(args[first], true) then
            state.LastShowUIInjected = register(args[first], state.Page)
            state.LastShowUICatalogIndex = first
        end
    end
    local function installManagers(state)
        local managers = {}
        local function add(manager)
            if manager == nil then return end
            for _, current in ipairs(managers) do if current == manager then return end end
            managers[#managers + 1] = manager
        end
        add(_G.UIManager)
        local ok, loaded = pcall(loadTable, "client.slua_ui_framework.manager")
        if ok then add(loaded); state.ManagerModuleError = nil
        else state.ManagerModuleError = tostring(loaded) end
        local count = 0
        for _, manager in ipairs(managers) do
            local show = member(manager, "ShowUI")
            if type(show) == "function" then
                local record = member(manager, "__LunarSettingsUIHook")
                if type(record) ~= "table" or record.Version ~= VERSION or record.Wrapper ~= show then
                    record = {Version = VERSION, Original = show}
                    record.Wrapper = function(config, ...)
                        local current = runtime()
                        -- Register again before opening, including rebuilt mode catalogs.
                        if not current.Initializing and type(current.Ensure) == "function" then
                            pcall(current.Ensure)
                        end
                        local args, n = {...}, select('#', ...)
                        injectShowCatalog(manager, config, args, n)
                        return record.Original(config, (table.unpack or unpack)(args, 1, n))
                    end
                    manager.ShowUI = record.Wrapper
                    manager.__LunarSettingsUIHook = record
                end
                count = count + 1
            end
        end
        state.Managers = managers
        state.HookCount = count
        state.HookInstalled = count > 0
        return state.HookInstalled
    end
    local function restoreAliases(state, aliases)
        for _, manager in ipairs(state.Managers or {}) do
            local config = member(manager, "UI_Config")
            if config then
                for _, key in ipairs({"Switcher", "Slider"}) do
                    if type(aliases[key]) ~= "table" then
                        local value = member(config, "Setting_Option_" .. key)
                        if type(value) == "table" then aliases[key] = value end
                    end
                end
            end
        end
    end
    local function syncModeCatalogs(state)
        local names = {"GameLua.Mod.BaseMod.Client.Config.SettingCatalog",
            "GameLua.Mod.D350.Client.Config.SettingCatalog",
            "GameLua.Mod.PlanPH.Client.Config.SettingCatalog"}
        for i, name in ipairs(names) do
            local catalog = package and package.loaded and package.loaded[name]
            if type(catalog) ~= "table" and i == 1 then
                local ok, value = pcall(loadTable, name)
                if ok then catalog = value; state.ModeCatalogError = nil
                else state.ModeCatalogError = tostring(value) end
            end
            if type(catalog) == "table" then register(catalog, state.Page) end
        end
    end
    local function buildPage(F, AliasMap, sliderReady)
    local function featureState() return _G.LunarFeatures end
    local function value(c,v) if v==nil then return c end return v end
    local function espAll(version)
        return {Key="LunarV"..version.."_All",UI=AliasMap.Switcher,Text="All ESP (V"..version.." master)",
            LunarBulk=true,
            SwitcherText={"All On","All Off"},
            EventType=F.ESPSettingsEventType,EventID=F.ESPSettingsEventID,
            GetFunc=function() return featureState().GetESPAll(version) end,
            SetFunc=function(c,v) return featureState().SetESPAll(version,value(c,v)) end}
    end
    local function espSwitch(version,key,label)
        return {Key=version==1 and ("LunarV1_"..key) or ("VIPServerESP_"..key),
            UI=AliasMap.Switcher,Text=label,
            EventType=F.ESPSettingsEventType,EventID=F.ESPSettingsEventID,
            GetFunc=function()
                local options=version==1 and _G.g_Botmater_ESPOptions or _G.g_vipserver_ESPOptions
                return options[key]==true
            end,
            SetFunc=function(c,v) return featureState().SetESP(version,key,value(c,v)) end}
    end
    local V1={espAll(1)}
    for _,entry in ipairs({{"Name","ESP Name (enemy name)"},{"Line","ESP Line (line to enemy)"},{"Health","ESP Health (HP bar)"},{"Distance","ESP Distance (meter)"},{"EnemyCounter","ESP Counter (enemy count)"}}) do
        V1[#V1+1]=espSwitch(1,entry[1],entry[2])
    end
    local V2={espAll(2),
        espSwitch(2,"Name","ESP Name"),espSwitch(2,"Line","ESP Line"),espSwitch(2,"Box","ESP Box (2D box)"),
        espSwitch(2,"Health","ESP Health"),espSwitch(2,"Distance","ESP Distance"),espSwitch(2,"Skeleton","ESP Skeleton"),espSwitch(2,"Counter","ESP Counter")}
    local Other={
        {Key="LunarWall",UI=AliasMap.Switcher,Text="Wall Hack (see through walls)",ExpandIndex=0,EventType=F.ESPSettingsEventType,EventID=3,GetFunc=function() return featureState().Settings.WallEnabled end,
            SetFunc=function(c,v) featureState().SetWall(value(c,v));return true end},
        {Key="LunarIpad",UI=AliasMap.Switcher,Text="iPad View (3-finger gyro)",ExpandIndex=0,GetFunc=function() return _G.MWConfig.IpadView end,
            SetFunc=function(c,v) featureState().SetIpad(value(c,v));return true end},
            -- V9.7: Aimbot rows moved to their own AIMBOT section below.
    }
    -- Verified native settings item contract: absolute Min/Max values, native
    -- key/value callbacks, and expansion events owned by the game's page.
    local function rangeItem(key,label,lo,hi,parent,get,set)
        return {Key=key,UI=AliasMap.Slider,Text=label,Min=lo,Max=hi,ExpandHandle=parent,
            GetFunc=function() return get() end,
            SetFunc=function(c,v)
                local v2=value(c,v)
                if type(set)=="function" then set(v2) else featureState()[set](v2) end
                featureState().Save(true)
                return true
            end}
    end
    if sliderReady then
        table.insert(Other,3,rangeItem("LunarIpadFOV","iPad FOV",90,120,"LunarIpad",
            function() return featureState().Settings.IpadFOV end,"SetIpadFOV"))
    end
    -- V9.7: Aimbot ka apna alag section (AIMBOT tab). Rows flat hain taaki
    -- Clean AIMBOT section. Master ON par neeche options ayengi.
    local Aim={}
    -- --- Aimbot V1 Master (expandable parent) ---
    Aim[#Aim+1]={Key="LunarAim",UI=AliasMap.Switcher,Text="Aimbot V1 (Master - aim on/off)",
        ExpandIndex=0,EventType=F.AimSettingsEventType,EventID=F.AimSettingsEventID,
        GetFunc=function() return featureState().Settings.AimEnabled end,
        SetFunc=function(c,v) featureState().SetAim(value(c,v));return true end}
    if sliderReady then
        Aim[#Aim+1]=rangeItem("LunarAimSpeed","Aim Speed",100,120,"LunarAim",
            function() return featureState().Settings.AimSpeed end,"SetAimSpeed")
    end
    Aim[#Aim+1]={Key="LunarAimTarget",UI=AliasMap.Switcher,Text="Aim Target (Head/Body/Leg)",
        ExpandHandle="LunarAim",SwitcherText={"Head","Body","Leg"},SwitcherValue={1,2,3},
        GetFunc=function() return featureState().Settings.AimTarget end,
        SetFunc=function(c,v) featureState().SetAimTarget(value(c,v));return true end}
    if sliderReady then
        Aim[#Aim+1]=rangeItem("LunarAimFOV","Aim FOV",10,100,"LunarAim",
            function() return featureState().Settings.AimFOV end,"SetAimFOV")
    end
    if sliderReady then
        Aim[#Aim+1]=rangeItem("LunarAimDist","Aim Distance (meter)",50,400,"LunarAim",
            function() return featureState().Settings.AimDist end,"SetAimDist")
    end
    Aim[#Aim+1]={Key="LunarAimVis",UI=AliasMap.Switcher,Text="Visible Only (wall check)",
        ExpandHandle="LunarAim",
        GetFunc=function() return featureState().Settings.AimVisCheck end,
        SetFunc=function(c,v) featureState().SetAimVisCheck(value(c,v));return true end}
    Aim[#Aim+1]={Key="LunarAimKnock",UI=AliasMap.Switcher,Text="Ignore Knocked (no downed)",
        ExpandHandle="LunarAim",
        GetFunc=function() return featureState().Settings.AimIgKnock end,
        SetFunc=function(c,v) featureState().SetAimIgKnock(value(c,v));return true end}
    Aim[#Aim+1]={Key="LunarAimBot",UI=AliasMap.Switcher,Text="Ignore Bots (real players only)",
        ExpandHandle="LunarAim",
        GetFunc=function() return featureState().Settings.AimIgBot end,
        SetFunc=function(c,v) featureState().SetAimIgBot(value(c,v));return true end}

    -- --- Sniper Scope Aim (toggle, head lock, no fire) ---
    Aim[#Aim+1]={Key="LunarAimSniper",UI=AliasMap.Switcher,Text="Sniper Scope Aim (head lock, no fire)",
        GetFunc=function() return featureState().Settings.AimSniperScope end,
        SetFunc=function(c,v) featureState().SetAimSniperScope(value(c,v));return true end}

    -- --- Shotgun Aim (toggle, hipfire, no scope) ---
    Aim[#Aim+1]={Key="LunarAimShotgun",UI=AliasMap.Switcher,Text="Shotgun Aim (hipfire, no scope)",
        GetFunc=function() return featureState().Settings.AimShotgun end,
        SetFunc=function(c,v) featureState().SetAimShotgun(value(c,v));return true end}

    -- --- Kick Control (recoil remove) ---
    Aim[#Aim+1]={Key="LunarKick",UI=AliasMap.Switcher,Text="Kick Control (recoil remove)",
        ExpandIndex=0,EventType=F.AimSettingsEventType,EventID=F.AimSettingsEventID,
        GetFunc=function() return featureState().Settings.KickControl end,
        SetFunc=function(c,v) featureState().SetKickControl(value(c,v));return true end}
    if sliderReady then
        Aim[#Aim+1]=rangeItem("LunarKickAmt","Kick Amount (0=off, 100=max)",0,100,"LunarKick",
            function() return featureState().Settings.KickAmount end,"SetKickAmount")
    end
    Other[#Other+1]={Key="LunarEspMaster",UI=AliasMap.Switcher,Text="ESP Master (enemy esp on/off)",ExpandIndex=0,
        GetFunc=function() return _G.g_vipserver_VIPShotESP.Enabled==true end,
        SetFunc=function(c,v)
            local on=(value(c,v)==true or value(c,v)==1)
            _G.g_vipserver_VIPShotESP.Enabled=on
            if _G.g_Botmater_VIPShotESP then _G.g_Botmater_VIPShotESP.Enabled=on end
            if on and featureState().Wake then featureState().Wake() end
            return true
        end}
    if sliderReady then
        Other[#Other+1]=rangeItem("LunarEspRange","ESP Distance (max esp range)",400,1000,"LunarEspMaster",
            function() return featureState().Settings.EspRange end,"SetEspRange")
    end
    if sliderReady then
        Other[#Other+1]=rangeItem("LunarEspTargets","ESP Max Targets (max enemies)",5,64,"LunarEspMaster",
            function() return featureState().Settings.EspMaxTargets end,"SetEspMaxTargets")
    end
   -- Other[#Other+1]={Key="LunarAim2",UI=AliasMap.Switcher,Text="Aimbot V2",
       -- EventType=F.AimSettingsEventType,EventID=F.AimSettingsEventID,
    --    GetFunc=function() return featureState().Settings.Aim2Enabled end,
      --  SetFunc=function(c,v) featureState().SetAim2(value(c,v));return true end}

    Other[#Other+1]={Key="LunarMortarAim",UI=AliasMap.Switcher,Text="Mortar Aim (mortar lock)",
        GetFunc=function() return featureState().Settings.MortarEnabled end,
        SetFunc=function(c,v) featureState().SetMortar(value(c,v));return true end}
    local names={"Pink","White","Cyan","Green","Yellow","Saffron","Red"}
    for i,entry in ipairs({{"WallVisible","Wall Visible Color"},{"WallOccluded","Wall Behind-Wall Color"}}) do
        local key,label=entry[1],entry[2]
        table.insert(Other,1+i,{Key="Lunar"..key,UI=AliasMap.CompactSwitcher or AliasMap.Switcher,Text=label,
            EventType=F.ESPSettingsEventType,EventID=3,
            ExpandHandle="LunarWall",SwitcherText=names,SwitcherValue={1,2,3,4,5,6,7},
            GetFunc=function() return featureState().Settings[key] end,
            SetFunc=function(c,v) return featureState().SetWallColor(key,value(c,v)) end})
    end
    -- V9.7: Wall Hack crash guard. Safe mode only touches character meshes.

    Other[#Other+1]={Key="LunarWallSafe",UI=AliasMap.Switcher,Text="Safe Mode (wall anti-crash)",
        ExpandHandle="LunarWall",
        GetFunc=function() return featureState().Settings.WallSafeMode end,
        SetFunc=function(c,v) featureState().SetWallSafeMode(value(c,v));return true end}
    local page={Key="HackMenu",Text="@ZAKPUBGSKIN VIP MENU",UIKey="Setting_Page_Privacy",Category={
        {Key="Lunar_AimBot",Text="AIMBOT",Stack=Aim},
        {Key="Lunar_ESP_V1",Text="ESP V1",Stack=V1},
        {Key="Lunar_ESP_V2",Text="ESP V2",Stack=V2},
        {Key="Lunar_Other",Text="EXTRA FEATURES",Stack=Other}
    }}

        return page
    end
    local function initialize(state)
        local F = _G.LunarFeatures
        assert(type(F) == "table", "FEATURE_RUNTIME_NOT_READY")
        local pages = loadTable("client.logic.NewSetting.SettingPageDefine")
        local catalog = loadTable("client.logic.NewSetting.SettingCatalog")
        local aliases = loadTable("client.slua.umg.NewSetting.Item.AliasMap")
        restoreAliases(state, aliases)
        assert(type(aliases.Switcher) == "table", "AliasMap.Switcher_not_ready")

        -- Missing optional sliders must not hide the entire settings tab.
        -- Rebuild with both original slider rows as soon as their UI is available.
        local sliderReady = type(aliases.Slider) == "table"
        local compact = aliases.CompactSwitcher or aliases.Switcher
        local rebuild = state.Version ~= VERSION or not state.Page
            or state.Features ~= F or state.Alias ~= aliases
            or state.Switcher ~= aliases.Switcher or state.Slider ~= aliases.Slider
            or state.CompactSwitcher ~= compact
        if rebuild then
            state.Page = buildPage(F, aliases, sliderReady)
            state.PageBuilds = (state.PageBuilds or 0) + 1
        end
        state.Version, state.Features, state.PageDefine, state.Catalog = VERSION, F, pages, catalog
        state.Alias, state.Switcher, state.Slider = aliases, aliases.Switcher, aliases.Slider
        state.CompactSwitcher = compact
        state.SliderReady = sliderReady
        state.DeferredSliderRows = sliderReady and 0 or 2
        pages.HackMenu = state.Page
        state.Registered = register(catalog, state.Page)
        syncModeCatalogs(state)

        -- Bulk selector enhancement is optional; its failure cannot block the page.
        local okClass, switchClass = pcall(loadTable, "client.slua.umg.NewSetting.Item.Setting_Option_Switcher")
        if okClass and type(F.InstallNativeBulkSwitch) == "function" then
            local okBulk, result = pcall(F.InstallNativeBulkSwitch, switchClass)
            state.BulkSwitchReady = okBulk and result == true
            state.BulkSwitchError = not okBulk and tostring(result) or nil
        else
            state.BulkSwitchReady = false
            state.BulkSwitchError = not okClass and tostring(switchClass) or "BULK_SWITCH_HELPER_UNAVAILABLE"
        end
        state.Ready = state.Registered and state.HookInstalled == true
        if state.Ready then
            state.LastError = nil
            _G.HackMenuInitialized = "VIP_SERVER_NATIVE_SETTINGS_V9_13"
        else state.LastError = "SETTINGS_UI_MANAGER_NOT_READY" end
        return state.Ready
    end
    g_vipserver_EnsureHackMenu = function()
        local state = runtime()
        state.Ensure = g_vipserver_EnsureHackMenu
        if state.Initializing then return false end
        state.Initializing = true
        state.Attempts = (state.Attempts or 0) + 1
        -- Install early even when page/alias modules are still loading.
        local okHook, hookError = pcall(installManagers, state)
        if not okHook then state.HookInstalled = false; state.HookError = tostring(hookError)
        else state.HookError = nil end
        local ok, result = pcall(initialize, state)
        state.Initializing = false
        if not ok then state.Ready = false; state.LastError = tostring(result) end
        return ok and result == true
    end
    _G.LunarSettingsDiagnostics = function()
        local state = runtime()
        local timer = _G.__VIPShotFastRunner
        return {version = state.Version, ready = state.Ready == true,
            registered = state.Registered == true, attempts = state.Attempts or 0,
            lastError = state.LastError, hookInstalled = state.HookInstalled == true,
            hookCount = state.HookCount or 0, hookError = state.HookError,
            managerModuleError = state.ManagerModuleError,
            pageBuilt = state.Page ~= nil, pageBuilds = state.PageBuilds or 0,
            pageUIKey = state.Page and state.Page.UIKey or nil,
            sliderReady = state.SliderReady == true, deferredSliderRows = state.DeferredSliderRows,
            lastShowUIInjected = state.LastShowUIInjected,
            lastShowUICatalogIndex = state.LastShowUICatalogIndex,
            maintenanceProvider = type(timer) == "table" and timer.Provider or nil,
            maintenanceError = type(timer) == "table" and timer.LastError or nil}
    end
end

-- ESP configuration made by VIP Server
_G.g_vipserver_VIPShotESP = _G.g_vipserver_VIPShotESP or {

    Enabled = true,
    MaxRangeMeters = 1000.0,

    -- Target 60 updates/sec when the engine timer permits. No skeleton decimation.
    -- Discovery is separate from rendering; every rendered pose uses fresh projections.
    ScanInterval = 0.1,
    UpdateInterval = 1.0 / 60.0,
    WidgetBuildBudget = 256, -- New line widgets per update; existing widgets stay live.
    Profile = false,       -- Optional CPU timing in _G.g_vipserver_ESPDiagnostics.
    TransformInterval = 0.30,
    MaxRendered = 50,

    CounterY = 36.0,
    CounterWidth = 218.4,
    CounterHeight = 33.6,
    CounterDiamondSize = 0.0,

    TracerThickness = 1.80,
    NameGap = 2.0,
    NameFontSize = 14,
    DistanceFontSize = 20,
    DistanceBelowFeet = 8.0,
}
if (tonumber(_G.g_vipserver_VIPShotESP.MaxRendered) or 0) < 1 then
    _G.g_vipserver_VIPShotESP.MaxRendered = 8
end
if (tonumber(_G.g_vipserver_VIPShotESP.MaxRangeMeters) or 0) < 400.0 then
    _G.g_vipserver_VIPShotESP.MaxRangeMeters = 450.0
end
-- Upgrade a table retained by an earlier hot-reload to the new readable marker size.
if (tonumber(_G.g_vipserver_VIPShotESP.DistanceFontSize) or 0) < 20 then
    _G.g_vipserver_VIPShotESP.DistanceFontSize = 20
end
-- Counters are 20% larger than the previous 182x28 revision.
_G.g_vipserver_VIPShotESP.CounterWidth=218.4
_G.g_vipserver_VIPShotESP.CounterHeight=33.6
_G.g_vipserver_VIPShotESP.CounterDiamondSize=0.0

-- Upgrade only the shipped 30 Hz default on the first performance revision.
if not _G.g_vipserver_VIPShotESP.PerformanceRevision then
    if _G.g_vipserver_VIPShotESP.UpdateInterval == 0.033 then
        _G.g_vipserver_VIPShotESP.UpdateInterval = 1.0 / 60.0
    end
    _G.g_vipserver_VIPShotESP.PerformanceRevision = 1
end
_G.VIPShotESP = _G.g_vipserver_VIPShotESP

-- ESP runtime state made by VIP Server
local g_vipserver_ShotESP = {
    Canvas = nil,
    RootUI = nil,
    Counter = nil,
    Enemies = {},
    Lines = {},
    Names = {},
    Boxes = {},
    HealthBars = {},
    Skeletons = {},
    Headers = {},
    Footers = {},
    BuildStage = {},
    BoneNameCache = {},
    Decorations = {},
    TemplateFont = nil,
    TemplateFontObject = nil,
    TemplateTypeface = nil,
    TemplateColorAndOpacity = nil,
    LastScanClock = -999.0,
    LastTransformClock = -999.0,
    LastWorld = nil,
    TracerOrigin = nil,

    CanvasScaleX = 1.0,
    CanvasScaleY = 1.0,
    CanvasOffsetX = 0.0,
    CanvasOffsetY = 0.0,
    ViewportW = nil,
    ViewportH = nil,
    RawViewportW = nil,
    RawViewportH = nil,
    HeaderRoots = {},
    Active = {},
    Alive = {},
    BoneMeshes = {},
    BonePoints = {},
    TimerClock = 0.0,
    Now = 0.0,
    Disabled = false,
    -- Bot detection result cache (avoids repeated IsAI calls every frame)
    _BotCache = {},
    RealCount = 0,
    BotCount = 0,
}

local V2 = _G.FVector2D
if not V2 then pcall(function() V2 = import("Vector2D") end) end
local V3 = _G.FVector
if not V3 then pcall(function() V3 = import("Vector") end) end
local LinearColor = _G.FLinearColor
if not LinearColor then pcall(function() LinearColor = import("LinearColor") end) end
local Anchors = _G.FAnchors
if not Anchors then pcall(function() Anchors = import("Anchors") or import("/Script/Slate.Anchors") end) end
local SlateBlueprintLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
local WidgetLayoutLibrary = nil
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)
local SlateColor = nil
pcall(function() SlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor") end)
local KismetTextLibrary = nil
pcall(function() KismetTextLibrary = import("KismetTextLibrary") or import("/Script/Engine.KismetTextLibrary") end)
local GameplayStaticsESP = nil
pcall(function() GameplayStaticsESP = import("GameplayStatics") end)
local ESPGameplayData=nil
pcall(function() ESPGameplayData=require("GameLua.GameCore.Data.GameplayData") end)

-- g_vipserver_ESPV2 made by VIP Server
local function g_vipserver_ESPV2(x, y)
    if V2 then return V2(x, y) end
    return {X = x, Y = y}
end

local function g_vipserver_ESPV3(x, y, z)
    if V3 then
        local ok, v = pcall(V3, x, y, z)
        if ok and v then return v end
    end
    return {X = x, Y = y, Z = z}
end

-- ESP color made by VIP Server
local function g_vipserver_ESPColor(r, g, b, a)
    if LinearColor then return LinearColor(r, g, b, a or 1.0) end
    return {R=r, G=g, B=b, A=a or 1.0}
end

-- ESP color theme made by VIP Server
local ESP_REAL = g_vipserver_ESPColor(0.90, 0.14, 0.14, 0.98)
local ESP_BOT  = g_vipserver_ESPColor(0.18, 0.86, 0.36, 0.98)
local ESP_WHITE = g_vipserver_ESPColor(1.0, 1.0, 1.0, 1.0)
local ESP_BLACK = g_vipserver_ESPColor(0.0, 0.0, 0.0, 1.0)
local ESP_TEXT_CLEAR = g_vipserver_ESPColor(0.0,0.0,0.0,0.0)
local ESP_HEADER_BG = g_vipserver_ESPColor(0.0, 0.0, 0.0, 0.78)
local ESP_COUNTER_RED = g_vipserver_ESPColor(1.0, 0.055, 0.105, 1.0)
local ESP_COUNTER_RED_DARK = g_vipserver_ESPColor(0.12, 0.008, 0.012, 1.0)
local ESP_COUNTER_BLUE = g_vipserver_ESPColor(0.18, 0.86, 0.36, 1.0)
local ESP_COUNTER_BLUE_DARK = g_vipserver_ESPColor(0.012, 0.06, 0.025, 1.0)
local ESP_COUNTER_CENTER = g_vipserver_ESPColor(0.075, 0.080, 0.095, 1.0)

-- ESP gradient color made by VIP Server
local function g_vipserver_ESPScaleColor(color, factor, alphaMul)
    if not color then return g_vipserver_ESPColor(1, 1, 1, 1) end
    local r = math.max(0.0, math.min(1.0, (tonumber(color.R) or 1.0) * (factor or 1.0)))
    local g = math.max(0.0, math.min(1.0, (tonumber(color.G) or 1.0) * (factor or 1.0)))
    local b = math.max(0.0, math.min(1.0, (tonumber(color.B) or 1.0) * (factor or 1.0)))
    local a = math.max(0.0, math.min(1.0, (tonumber(color.A) or 1.0) * (alphaMul or 1.0)))
    return g_vipserver_ESPColor(r, g, b, a)
end

local ESP_REAL_DARK  = g_vipserver_ESPScaleColor(ESP_REAL, 0.68, 1.0)
local ESP_REAL_LIGHT = g_vipserver_ESPScaleColor(ESP_REAL, 1.12, 0.82)
local ESP_BOT_DARK   = g_vipserver_ESPScaleColor(ESP_BOT, 0.68, 1.0)
local ESP_BOT_LIGHT  = g_vipserver_ESPScaleColor(ESP_BOT, 1.10, 0.82)
local ESP_WHITE_SOFT = g_vipserver_ESPColor(0.94, 0.94, 0.94, 0.98)
local ESP_WHITE_GLOSS = g_vipserver_ESPColor(1.0, 1.0, 1.0, 0.34)

local g_vipserver_ESPTheme
do
local ESP_REAL_THEME = {Key="REAL",Main=ESP_REAL,Light=ESP_REAL_LIGHT,
    Text=g_vipserver_ESPColor(1.0,0.86,0.84,1.0),
    Background=g_vipserver_ESPColor(0.05,0.005,0.005,0.97),
    Empty=g_vipserver_ESPColor(0.055,0.008,0.008,1.0)}
local ESP_BOT_THEME = {Key="BOT",Main=ESP_BOT,Light=ESP_BOT_LIGHT,
    Text=g_vipserver_ESPColor(0.82,1.0,0.87,1.0),
    Background=g_vipserver_ESPColor(0.005,0.05,0.015,0.97),
    Empty=g_vipserver_ESPColor(0.008,0.055,0.018,1.0)}
g_vipserver_ESPTheme=function(isBot)
    return isBot and ESP_BOT_THEME or ESP_REAL_THEME
end
end
-- ESP object validation made by VIP Server
local function g_vipserver_ESPValid(obj)
    if not obj then return false end
    if not slua or not slua.isValid then return false end
    local ok, valid = pcall(slua.isValid, obj)
    return ok and valid == true
end

local ESPShared={}
function ESPShared.Finite(n)
    return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
function ESPShared.SafeNumber(value,fallback,lo,hi)
    local n=tonumber(value)
    if not ESPShared.Finite(n) then n=fallback end
    return math.max(lo,math.min(hi,n))
end
function ESPShared.VectorComponents(v) return tonumber(v.X),tonumber(v.Y),tonumber(v.Z) end
function ESPShared.VectorValues(v)
    if v==nil then return nil end
    local ok,x,y,z=pcall(ESPShared.VectorComponents,v)
    if ok and ESPShared.Finite(x) and ESPShared.Finite(y) and ESPShared.Finite(z)
        and math.abs(x)<1e12 and math.abs(y)<1e12 and math.abs(z)<1e12 then return x,y,z end
end

-- ESP timing made by VIP Server
local function g_vipserver_ESPNow()
    local t = nil
    pcall(function()
        local w = (slua and slua.getWorld and slua.getWorld()) or nil
        if GameplayStaticsESP and w and GameplayStaticsESP.GetRealTimeSeconds then
            t = GameplayStaticsESP.GetRealTimeSeconds(w)
        end
    end)
    t=tonumber(t)
    if ESPShared.Finite(t) and t>=0 then return t end
    -- os.clock measures CPU time on some platforms, not elapsed frame time.
    -- If the engine clock is unavailable, advance by executed timer delays.
    return ESPShared.SafeNumber(g_vipserver_ShotESP.TimerClock,0.0,0.0,1e12)
end

-- ESP world access made by VIP Server
local function g_vipserver_ESPWorld()
    local w = nil
    pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
    return w
end

-- ESP player controller made by VIP Server
local function g_vipserver_ESPGetController()
    local pc = nil
    pcall(function()
        local GDP = ESPGameplayData
        if GDP and GDP.GetPlayerController then pc = GDP.GetPlayerController() end
    end)
    if not g_vipserver_ESPValid(pc) then
        pcall(function()
            if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
        end)
    end
    return g_vipserver_ESPValid(pc) and pc or nil
end

-- ESP local player made by VIP Server
local function g_vipserver_ESPGetLocalCharacter()
    local c = nil
    pcall(function()
        local GDP = ESPGameplayData
        if GDP then
            if GDP.GetPlayerCharacter then c = GDP.GetPlayerCharacter() end
            if not g_vipserver_ESPValid(c) and GDP.GetLocalCharacter then c = GDP.GetLocalCharacter() end
        end
    end)
    if not g_vipserver_ESPValid(c) then
        local pc = g_vipserver_ESPGetController()
        pcall(function() if pc and pc.GetPawn then c = pc:GetPawn() end end)
    end
    return g_vipserver_ESPValid(c) and c or nil
end

-- g_vipserver_ESPGetPlayerState made by VIP Server
local function g_vipserver_ESPGetPlayerState(character)
    if not g_vipserver_ESPValid(character) then return nil end
    local ps = nil
    pcall(function()
        if character.GetPlayerStateSafety then ps = character:GetPlayerStateSafety() end
    end)
    if not g_vipserver_ESPValid(ps) then
        pcall(function() if character.GetPlayerState then ps = character:GetPlayerState() end end)
    end
    if not g_vipserver_ESPValid(ps) then
        pcall(function() ps = character.PlayerState end)
    end
    return g_vipserver_ESPValid(ps) and ps or nil
end

-- g_vipserver_ESPNormalizeName made by VIP Server
local function g_vipserver_ESPNormalizeName(value)
    if value == nil or value == false then return nil end
    local ok, text = pcall(tostring, value)
    if not ok or not text then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or text == "nil" or text == "None" or text == "NULL" or text == "UNKNOWN" then return nil end
    if text:find("^userdata:") or text:find("^table:") then return nil end
    return text
end

-- ESP player name made by VIP Server
local function g_vipserver_ESPResolvePlayerName(character)
    if not g_vipserver_ESPValid(character) then return nil end
    local name = nil

-- take made by VIP Server
    local function take(value)
        if not name then name = g_vipserver_ESPNormalizeName(value) end
    end

    pcall(function() if character.GetPlayerNameSafety then take(character:GetPlayerNameSafety()) end end)
    pcall(function() if not name and character.GetPlayerName then take(character:GetPlayerName()) end end)
    pcall(function() if not name then take(character.PlayerName) end end)
    pcall(function() if not name then take(character.NickName) end end)
    pcall(function() if not name then take(character.AIPlayerName) end end)
    pcall(function() if not name then take(character.BotName) end end)

    if not name then
        local ps = g_vipserver_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
            pcall(function() if not name then take(ps.PlayerName) end end)
            pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
            pcall(function() if not name then take(ps.NickName) end end)
            pcall(function() if not name then take(ps.AccountName) end end)
            pcall(function() if not name then take(ps.AIPlayerName) end end)
        end
    end
    return name
end

-- g_vipserver_ESPGetPlayerKey made by VIP Server
local function g_vipserver_ESPGetPlayerKey(character)
    local key = nil
    pcall(function() if character.GetPlayerKey then key = character:GetPlayerKey() end end)
    if key == nil then pcall(function() key = character.PlayerKey end) end
    if key == nil then
        local ps = g_vipserver_ESPGetPlayerState(character)
        if ps then pcall(function() key = ps.PlayerKey end) end
    end
    if key == nil or tostring(key) == "" or tostring(key) == "0" or tostring(key) == "-1" then
        return tostring(character)
    end
    return tostring(key) .. "_" .. tostring(character)
end

-- ESP team detection made by VIP Server
local function g_vipserver_ESPGetTeamID(character)
    if not g_vipserver_ESPValid(character) then return nil end
    local id = nil
    pcall(function() if character.GetTeamID then id = character:GetTeamID() end end)
    if id == nil then pcall(function() id = character.TeamID end) end
    if id == nil then
        local ps = g_vipserver_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
            if id == nil then pcall(function() id = ps.TeamID end) end
        end
    end
    return id
end

-- ESP alive detection made by VIP Server
local ESPFinishedLastBreath,ESPDeadPawnState
pcall(function() ESPFinishedLastBreath=import("ECharacterHealthStatus").FinishedLastBreath end)
pcall(function() ESPDeadPawnState=EPawnState and EPawnState.Dead end)
local function ESPActorField(actor,key) return actor[key] end
local function ESPReadActorField(actor,key)
    local ok,value=pcall(ESPActorField,actor,key)
    if ok then return value end
end
local function ESPReadActorMethod(actor,key,...)
    local method=ESPReadActorField(actor,key)
    if type(method)=="function" then
        local ok,value=pcall(method,actor,...)
        if ok then return value end
    end
end
local function ESPActorDeadFlag(actor,key)
    local value=ESPReadActorField(actor,key)
    return value==true or value==1
end
local function g_vipserver_ESPIsAlive(character)
    if not g_vipserver_ESPValid(character) then return false,"invalid" end
    if ESPActorDeadFlag(character,"bDead") or ESPActorDeadFlag(character,"bIsDead")
        or ESPActorDeadFlag(character,"bIsDeadFlag") then return false,"dead" end
    if ESPFinishedLastBreath~=nil
        and ESPReadActorField(character,"HealthStatus")==ESPFinishedLastBreath then return false,"dead" end
    if ESPDeadPawnState~=nil then
        local state=ESPReadActorMethod(character,"HasPawnState",ESPDeadPawnState)
        if state==true or state==1 then return false,"dead" end
        state=ESPReadActorMethod(character,"HasState",ESPDeadPawnState)
        if state==true or state==1 then return false,"dead" end
    end
    local dead=ESPReadActorMethod(character,"IsDead")
    if dead==true or dead==1 then return false,"dead" end
    -- Knocked characters remain eligible even when their normal HP is zero.
    -- Terminal flags above always take precedence over the rescue state.
    local alive=ESPReadActorMethod(character,"IsAlive")
    if alive==true or alive==1 then return true,"alive" end
    local knocked=ESPReadActorMethod(character,"IsNearDeath")
    if knocked==true or knocked==1 then return true,"knocked" end
    if alive==false or alive==0 then return false,"dead" end
    local hp=ESPReadActorField(character,"Health")
    if not ESPShared.Finite(hp) then hp=ESPReadActorField(character,"HP") end
    if not ESPShared.Finite(hp) then hp=ESPReadActorMethod(character,"GetHealth") end
    if ESPShared.Finite(hp) then return hp>0,hp>0 and "alive" or "unknown" end
    -- Missing/failed replication is not positive evidence of life.
    return false,"unknown"
end

-- Event-driven V1/V2 visibility. The original shared life evaluator and Wall
-- renderer are deliberately untouched. 1=knocked, 2=confirmed dead, 3=exit pending.
ESPShared.Events={Records=setmetatable({}, {__mode="k"}),Clearers={}}
_G.LunarESPEvents=ESPShared.Events
do
    local E=ESPShared.Events
    function E.WorldChanged(world)
        if world==nil then return end
        if E.World~=nil and E.World~=world then
            if E.UnbindAll then E.UnbindAll() end
            E.Records=setmetatable({}, {__mode="k"})
        end
        E.World=world
    end

    local function eventActor(self)
        if not Client then return nil end
        -- Only queried on a native event, never by a new poll or timer. This
        -- prevents a first HUD update from discarding a new-world death event.
        E.WorldChanged(g_vipserver_ESPWorld())
        return self and self.Object
    end

    function E.Clear(actor)
        for _,clear in ipairs(E.Clearers) do pcall(clear,actor) end
    end

    function E.Spawn(self)
        local actor=eventActor(self)
        if actor~=nil then E.Records[actor]=nil end
    end

    function E.Death(self)
        local actor=eventActor(self)
        if actor==nil then return end
        if E.Records[actor]~=2 then
            E.Records[actor]=2
            E.Clear(actor)
        end
    end

    function E.NearDeath(self,isNearDeath)
        local actor=eventActor(self)
        if actor==nil or E.Records[actor]==2 then return end
        local status=ESPReadActorField(actor,"HealthStatus")
        if ESPFinishedLastBreath~=nil and status==ESPFinishedLastBreath then
            E.Records[actor]=2
            E.Clear(actor)
        elseif isNearDeath==true or isNearDeath==1 then
            if E.Records[actor]~=1 then
                E.Records[actor]=1
                E.Clear(actor)
            end
        elseif isNearDeath==false or isNearDeath==0 then
            -- False can also accompany death. Do not equate it with rescue;
            -- require the original life result in the existing ESP pass too.
            if E.Records[actor]==1 then
                E.Records[actor]=3
                E.Clear(actor)
            end
        end
    end

    function E.Counted(actor)
        -- Keep the original counter's knocked-player behavior; only confirmed
        -- death adds an exclusion. Never change Frame.Entries[actor].Alive.
        return E.Records[actor]~=2
    end

    function E.Visible(actor,snapshot)
        local state=E.Records[actor]
        if state==2 or state==1 then return false end
        if state==3 then
            if not snapshot or not snapshot.Alive or snapshot.LifeState=="knocked" then return false end
            -- Preserve the original map-specific IsAlive/GetHealth priority.
            -- A stale zero HP field must not permanently hide a rescued pawn.
            -- Only a confirmed death event/status can set state 2.
            E.Records[actor]=nil
        end
        return snapshot and snapshot.Alive and snapshot.LifeState~="knocked"
    end

    function E.Project(pc,actor,state)
        local snapshot=ESPShared.GetFrameRecord(actor)
        if not E.Visible(actor,snapshot) then return nil,nil,false,"life" end
        local head,feet,onScreen,reason=ESPShared.ProjectActor(pc,actor,state)
        -- A native call can dispatch a lifecycle event during projection.
        if not E.Visible(actor,snapshot) then return nil,nil,false,"life" end
        return head,feet,onScreen,reason
    end

    function E.ClearIn(state,prune,actor)
        -- Reuse the existing pooled-widget cleanup. All keys except this
        -- actor's are kept, including actors beyond the display budget.
        for _,item in ipairs(state.Enemies) do
            if item.Character==actor then
                local key=item.Key
                local keep=setmetatable({[key]=false},{__index=function() return true end})
                state.Active[key]=nil
                state.Alive[key]=nil
                if state.LastProjected then state.LastProjected[key]=nil end
                prune(keep,keep)
            end
        end
    end

    -- Independent SLua multicast listeners. No CharacterBase method is changed.
    -- Add(function) returns an integer handle; Remove(handle) removes that
    -- listener only. See Tencent/sluaunreal LuaDelegate.cpp, LuaMultiDelegate.
    -- Insert this chunk inside the existing ESPShared.Events do/end block,
    -- replacing only the three BRPlayerCharacterBase handler overrides.
    local oldObserver=_G.__LunarESPEventObserver
    if oldObserver and oldObserver~=E and type(oldObserver.UnbindAll)=="function" then
        pcall(oldObserver.UnbindAll)
    end
    _G.__LunarESPEventObserver=E
    E.Bindings={}
    E.BindingCount=0
    E.BindingLimit=512
    E.ObserverDiagnostics={Bound=0,Unsupported=0,AddErrors=0,RemoveErrors=0}
    local observerGeneration=1
    local dispatchDepth=0
    local pendingAll=false
    local pendingActors={}

    local function observerMember(object,key)
        if object==nil then return nil end
        local ok,value=pcall(function() return object[key] end)
        if ok then return value end
    end
    local function observerValid(actor)
        if actor==nil then return false end
        if not slua or type(slua.isValid)~="function" then return false end
        local ok,yes=pcall(slua.isValid,actor)
        return ok and yes==true
    end
    local function removeBinding(actor,row)
        if E.Bindings[actor]~=row then return end
        E.Bindings[actor]=nil
        E.BindingCount=math.max(0,E.BindingCount-1)
        row.Active=false
        local tracked=_G.g_vipserver_TrackedCharacters
        local key=tostring(actor)
        if tracked and tracked[key]==actor then tracked[key]=nil end
        row.Actor[1]=nil
        for _,owned in ipairs(row.Handles) do
            local remove=observerMember(owned.Delegate,"Remove")
            if type(remove)=="function" then
                local ok=pcall(remove,owned.Delegate,owned.Handle)
                if not ok then E.ObserverDiagnostics.RemoveErrors=E.ObserverDiagnostics.RemoveErrors+1 end
            end
        end
        row.Handles={}
    end
    local function flushObserverCleanup()
        if dispatchDepth~=0 then return end
        if pendingAll then
            pendingAll=false
            for actor,row in pairs(E.Bindings) do removeBinding(actor,row) end
            pendingActors={}
        else
            for actor in pairs(pendingActors) do
                pendingActors[actor]=nil
                local row=E.Bindings[actor]
                if row then removeBinding(actor,row) end
            end
        end
    end
    function E.UnbindAll()
        -- Removing a Lua delegate during its native multicast dispatch is
        -- unsafe in SLua. Invalidate now; flush on the next existing ESP pass.
        observerGeneration=observerGeneration+1
        pendingAll=true
        for _,row in pairs(E.Bindings) do row.Active=false end
        flushObserverCleanup()
    end
    function E.Unobserve(actor)
        local row=E.Bindings[actor]
        if not row then return end
        row.Active=false
        if dispatchDepth~=0 then pendingActors[actor]=true
        else removeBinding(actor,row) end
    end
    local eventSpecs={
        {Name="IsEnterNearDeathDelegate",Handler="NearDeath"},
        {Name="OnDeathDelegate",Handler="Death"},
        {Name="OnPawnRespawnDelegate",Handler="Spawn"}
    }
    function E.Observe(actor)
        if not Client or actor==nil then return false end
        if pendingAll or next(pendingActors)~=nil then flushObserverCleanup() end
        local row=E.Bindings[actor]
        if row then return row.Bound end
        if not observerValid(actor) then return false end
        -- A hard bound limits listener retention even if enumeration fails.
        -- Unsupported actors still use the original live-state fallback.
        if E.BindingCount>=E.BindingLimit then return false end
        row={Active=true,Generation=observerGeneration,
            Actor=setmetatable({actor},{__mode="v"}),Handles={},Bound=false}
        E.Bindings[actor]=row
        E.BindingCount=E.BindingCount+1
        -- Native class lifecycle stays untouched. Existing pawn discovery
        -- supplies tracking/maintenance, and native respawn delegates clear ESP.
        _G.g_vipserver_TrackedCharacters=_G.g_vipserver_TrackedCharacters or {}
        _G.g_vipserver_TrackedCharacters[tostring(actor)]=actor
        if g_vipserver_StartSettingsMaintenance then
            pcall(g_vipserver_StartSettingsMaintenance,actor)
        end
        if not _G._BYPASS_DONE and type(_G._BYPASS_Execute)=="function" then
            pcall(_G._BYPASS_Execute)
        end
        for _,spec in ipairs(eventSpecs) do
            local delegate=observerMember(actor,spec.Name)
            local add=observerMember(delegate,"Add")
            local remove=observerMember(delegate,"Remove")
            if type(add)=="function" and type(remove)=="function" then
                local handler=spec.Handler
                local function observed(...)
                    local current=row.Actor[1]
                    if not row.Active or row.Generation~=observerGeneration
                        or _G.LunarESPEvents~=E or not observerValid(current) then return end
                    dispatchDepth=dispatchDepth+1
                    -- The existing state machine accepts self.Object. This
                    -- transient wrapper is never installed on a native class.
                    pcall(E[handler],{Object=current},...)
                    dispatchDepth=dispatchDepth-1
                    -- Cleanup is intentionally deferred until Observe/Sync.
                end
                local ok,handle=pcall(add,delegate,observed)
                if ok and type(handle)=="number" and handle>0 then
                    row.Handles[#row.Handles+1]={Delegate=delegate,Handle=handle}
                    row.Bound=true
                    E.ObserverDiagnostics.Bound=E.ObserverDiagnostics.Bound+1
                else
                    E.ObserverDiagnostics.AddErrors=E.ObserverDiagnostics.AddErrors+1
                end
            else
                E.ObserverDiagnostics.Unsupported=E.ObserverDiagnostics.Unsupported+1
            end
        end
        return row.Bound
    end
    function E.SyncObservedPawns(pawns)
        -- Called with the already-enumerated GetAllPlayerPawns result, never
        -- obtains a second actor list and never schedules another timer.
        flushObserverCleanup()
        for actor,row in pairs(E.Bindings) do
            -- Enumeration can temporarily omit a still-valid pawn. Keep its
            -- existing lifecycle listeners and death record so stale HP on
            -- return cannot resurrect ESP, and a real respawn while omitted
            -- can still release the record. Native invalidation/world reset
            -- removes these bounded listeners; no new poll or timer is added.
            if not observerValid(actor) then
                E.Unobserve(actor)
                E.Records[actor]=nil
            end
        end
        -- Native arrays are also observed by the existing GetFrameRecord
        -- pass. Even an unavailable/non-table list must release invalid rows.
        if type(pawns)~="table" then return end
        for _,actor in pairs(pawns) do
            if actor~=nil then E.Observe(actor) end
        end
    end

end

-- Bot cache uses the same actor/player key as pruning, with replication retries.
local function g_vipserver_ESPIsBot(character, key, providedCache, providedNow)
    if not g_vipserver_ESPValid(character) then return false end
    key = key or g_vipserver_ESPGetPlayerKey(character)
    local cache = providedCache or g_vipserver_ShotESP._BotCache
    local now = providedNow or g_vipserver_ShotESP.Now
    local entry = cache[key]
    if entry and now >= entry.Clock and now - entry.Clock < 2.0 then return entry.Value end
    local result = nil
    local function take(v)
        if result == nil and (v == true or v == false or v == 1 or v == 0) then
            result = (v == true or v == 1)
        end
    end
    pcall(function() if Game and Game.IsAI then take(Game:IsAI(character)) end end)
    if result == nil then pcall(function() take(character.bIsAI) end) end
    if result == nil then pcall(function() if character.IsBot then take(character:IsBot()) end end) end
    if result == nil then
        local ps = g_vipserver_ESPGetPlayerState(character)
        if ps then
            pcall(function() take(ps.bIsABot) end)
            pcall(function() take(ps.bIsBot) end)
            pcall(function() take(ps.bIsAI) end)
            if result == nil then pcall(function() if ps.IsBot then take(ps:IsBot()) end end) end
        end
    end
    -- Unresolved replication data is never cached as a permanent false.
    cache[key] = result ~= nil and {Value=result, Clock=now} or nil
    return result == true
end

-- ESP actor position made by VIP Server
local function g_vipserver_ESPActorLocation(character)
    local loc = nil
    if not g_vipserver_ESPValid(character) then return nil end
    pcall(function()
        if character.K2_GetActorLocation then loc = character:K2_GetActorLocation()
        elseif Game and Game.GetActorLocation then loc = Game:GetActorLocation(character) end
    end)
    return loc
end

-- ESP distance calculation made by VIP Server
local function g_vipserver_ESPDistanceMeters(a,b)
    local ax,ay,az=ESPShared.VectorValues(a)
    local bx,by,bz=ESPShared.VectorValues(b)
    if not ax or not bx then return math.huge end
    local dx,dy,dz=ax-bx,ay-by,az-bz
    return math.sqrt(dx*dx+dy*dy+dz*dz)/100.0
end


-- A memo lives for one scheduler callback only.
-- Callback-local values never retain actors, controllers or native locations
-- after Finish. The bounded pool keeps only reusable vector buffers.
ESPShared.Frame={Active=false,Entries={},Pool={},PoolLimit=256,Now=0,ViewAt=-999,Controllers={},Transforms={},TransformPool={}}
function ESPShared.Frame.Finish()
    local frame=ESPShared.Frame
    for actor,entry in pairs(frame.Entries) do
        frame.Entries[actor]=nil
        entry.Location=nil;entry.LocationX=nil;entry.LocationY=nil;entry.LocationZ=nil
        entry.DistanceOrigin=nil;entry.DistanceSquared=nil;entry.DistanceMeters=nil
        entry.Alive=false;entry.Projected=false;entry.OnScreen=false
        entry.HasHead=false;entry.HasFeet=false;entry.PC=nil
        if #frame.Pool<frame.PoolLimit then frame.Pool[#frame.Pool+1]=entry end
    end
    for pc in pairs(frame.Controllers) do frame.Controllers[pc]=nil end
    for state,value in pairs(frame.Transforms) do
        frame.Transforms[state]=nil
        if #frame.TransformPool<4 then frame.TransformPool[#frame.TransformPool+1]=value end
    end
    frame.DistanceOrigin=nil;frame.OriginX=nil;frame.OriginY=nil;frame.OriginZ=nil
    frame.Pawns=nil;frame.Active=false;frame.V1CanvasChecked=false
end
function ESPShared.Frame.Begin(now)
    ESPShared.Frame.Finish()
    ESPShared.Frame.Now=now;ESPShared.Frame.Active=true
end
function ESPShared.GetFrameRecord(actor)
    local frame=ESPShared.Frame
    local entry=frame.Active and frame.Entries[actor]
    if entry then return entry end
    if ESPShared.Events.Observe then ESPShared.Events.Observe(actor) end
    entry=frame.Active and table.remove(frame.Pool) or nil
    if not entry then entry={} end
    entry.Alive,entry.LifeState=g_vipserver_ESPIsAlive(actor)
    entry.Projected=false;entry.OnScreen=false;entry.HasHead=false;entry.HasFeet=false
    entry.Location=entry.Alive and g_vipserver_ESPActorLocation(actor) or nil
    entry.LocationX,entry.LocationY,entry.LocationZ=ESPShared.VectorValues(entry.Location)
    if not entry.LocationX then entry.Location=nil end
    if frame.Active and actor~=nil then frame.Entries[actor]=entry end
    return entry
end
function ESPShared.GetFramePawns()
    if ESPShared.Frame.Active and ESPShared.Frame.Pawns then return ESPShared.Frame.Pawns end
    local pawns
    pcall(function() if Game and Game.GetAllPlayerPawns then pawns=Game:GetAllPlayerPawns() end end)
    -- The native CharacterBase already maintains this public registry.
    -- Read it only when the engine pawn getter is unavailable; no native
    -- AddCharacter/RemoveCharacter or lifecycle method is replaced.
    if not pawns and GameplayData then
        if type(GameplayData.GetAllPlayerCharacters)=="function" then
            pcall(function()pawns=GameplayData.GetAllPlayerCharacters()end)
        end
        if not pawns and type(GameplayData.GetAllCharacters)=="function" then
            pcall(function()pawns=GameplayData.GetAllCharacters()end)
        end
    end
    if ESPShared.Frame.Active then ESPShared.Frame.Pawns=pawns end
    local E=ESPShared.Events
    local now=ESPShared.Frame.Active and ESPShared.Frame.Now or g_vipserver_ESPNow()
    if E.SyncObservedPawns and (not E.SyncDue or now>=E.SyncDue or now<(E.SyncClock or now)) then
        E.SyncObservedPawns(pawns);E.SyncDue=now+1;E.SyncClock=now
    end
    return pawns
end
function ESPShared.DistanceSquaredFrom(entry,origin)
    if not entry or not entry.LocationX then return math.huge end
    local frame=ESPShared.Frame
    if frame.Active and entry.DistanceOrigin==origin and entry.DistanceSquared~=nil then return entry.DistanceSquared end
    local x,y,z
    if frame.Active and frame.DistanceOrigin==origin then
        x,y,z=frame.OriginX,frame.OriginY,frame.OriginZ
    else
        x,y,z=ESPShared.VectorValues(origin)
        if frame.Active then frame.DistanceOrigin=origin;frame.OriginX=x;frame.OriginY=y;frame.OriginZ=z end
    end
    if not x then
        if frame.Active then entry.DistanceOrigin=origin;entry.DistanceSquared=math.huge;entry.DistanceMeters=nil end
        return math.huge
    end
    local dx,dy,dz=x-entry.LocationX,y-entry.LocationY,z-entry.LocationZ
    local squared=dx*dx+dy*dy+dz*dz
    if frame.Active then entry.DistanceOrigin=origin;entry.DistanceSquared=squared;entry.DistanceMeters=nil end
    return squared
end
function ESPShared.DistanceMetersFrom(entry,origin)
    local squared=ESPShared.DistanceSquaredFrom(entry,origin)
    if ESPShared.Frame.Active and entry.DistanceMeters~=nil then return entry.DistanceMeters end
    local distance=math.sqrt(squared)/100.0
    if ESPShared.Frame.Active then entry.DistanceMeters=distance end
    return distance
end
function ESPShared.InRange(entry,origin,maxRange)
    if not ESPShared.Finite(maxRange) or maxRange<=0 then return ESPShared.DistanceMetersFrom(entry,origin)<=maxRange end
    local squared=ESPShared.DistanceSquaredFrom(entry,origin)
    if squared==math.huge then return false end
    local limit=maxRange*100.0;limit=limit*limit
    -- Preserve the original sqrt/division decision at floating-point boundaries.
    if math.abs(squared-limit)<=math.max(1,limit)*1e-12 then
        return ESPShared.DistanceMetersFrom(entry,origin)<=maxRange
    end
    return squared<limit
end
function ESPShared.ProjectionControllerValid(pc)
    if pc==nil then return false end
    local frame=ESPShared.Frame
    if frame.Active then
        local cached=frame.Controllers[pc]
        if cached~=nil then return cached end
        local valid=g_vipserver_ESPValid(pc);frame.Controllers[pc]=valid;return valid
    end
    return g_vipserver_ESPValid(pc)
end
function ESPShared.CanvasTransform(state)
    local frame=ESPShared.Frame
    local value=frame.Active and frame.Transforms[state]
    local rx,ry,rox,roy=state.CanvasScaleX,state.CanvasScaleY,state.CanvasOffsetX,state.CanvasOffsetY
    if not value or value.RX~=rx or value.RY~=ry or value.ROX~=rox or value.ROY~=roy then
        value=value or (frame.Active and table.remove(frame.TransformPool)) or {}
        value.RX=rx;value.RY=ry;value.ROX=rox;value.ROY=roy
        value.SX=ESPShared.SafeNumber(rx,1,0.00001,100)
        value.SY=ESPShared.SafeNumber(ry,1,0.00001,100)
        value.OX=ESPShared.SafeNumber(rox,0,-1e7,1e7)
        value.OY=ESPShared.SafeNumber(roy,0,-1e7,1e7)
        if frame.Active then frame.Transforms[state]=value end
    end
    return value.SX,value.SY,value.OX,value.OY
end
function ESPShared.AssignProbeVector(vector,x,y,z)
    vector.X=x;vector.Y=y;vector.Z=z
end
function ESPShared.UpdateProbeVector(vector,x,y,z)
    if vector and pcall(ESPShared.AssignProbeVector,vector,x,y,z) then return vector end
    return g_vipserver_ESPV3(x,y,z)
end

-- Validate all cached candidates before display caps. Reuse the list and alive
-- map, so dead/out-of-range actors are pruned on the next scheduled HUD update.
local function g_vipserver_ESPFilterEnemies(list, myLocation, maxRange, alive)
    for key in pairs(alive) do alive[key]=nil end
    local count,kept,realCount,botCount=#list,0,0,0
    maxRange=tonumber(maxRange) or 450.0
    if maxRange~=maxRange or maxRange<=0 or maxRange==math.huge then maxRange=450.0 end
    for i=1,count do
        local item=list[i]
        local character=item and item.Character
        local snapshot=item and item.Key and ESPShared.GetFrameRecord(character)
        if snapshot and snapshot.Alive and ESPShared.Events.Counted(character) then
            local location=snapshot.Location
            local distance=ESPShared.DistanceMetersFrom(snapshot,myLocation)
            if distance<=maxRange then
                item.Distance=distance
                kept=kept+1;list[kept]=item;alive[item.Key]=true
                if item.IsBot then botCount=botCount+1 else realCount=realCount+1 end
            end
        end
    end
    for i=kept+1,count do list[i]=nil end
    return realCount,botCount
end

-- ESP character vertical bounds made by VIP Server
local function g_vipserver_ESPGetCharacterVerticalBounds(character,cachedLocation)
    if not g_vipserver_ESPValid(character) then return nil, nil end

    local center, halfHeight = nil, nil
    local capsule = nil

    pcall(function()
        if character.GetCapsuleComponent then
            capsule = character:GetCapsuleComponent()
        elseif character.CapsuleComponent then
            capsule = character.CapsuleComponent
        end
    end)

    if capsule and g_vipserver_ESPValid(capsule) then
        pcall(function()
            if capsule.K2_GetComponentLocation then
                center = capsule:K2_GetComponentLocation()
            elseif capsule.GetComponentLocation then
                center = capsule:GetComponentLocation()
            end

            if capsule.GetScaledCapsuleHalfHeight then
                halfHeight = capsule:GetScaledCapsuleHalfHeight()
            elseif capsule.GetUnscaledCapsuleHalfHeight then
                halfHeight = capsule:GetUnscaledCapsuleHalfHeight()
            elseif capsule.CapsuleHalfHeight then
                halfHeight = capsule.CapsuleHalfHeight
            end
        end)
    end

    local cx,cy,cz=ESPShared.VectorValues(center)
    if center and not cx then center=nil end
    if not center then center=cachedLocation end
    if not center then
        pcall(function()
            if character.K2_GetActorLocation then
                center = character:K2_GetActorLocation()
            end
        end)
    end

    if not center then
        pcall(function()
            if Game and Game.GetActorLocation then
                center = Game:GetActorLocation(character)
            end
        end)
    end

    if not cx then cx,cy,cz=ESPShared.VectorValues(center) end
    if not cx then return nil,nil end

    halfHeight=tonumber(halfHeight)
    if not ESPShared.Finite(halfHeight) or halfHeight<10 or halfHeight>200 then
        halfHeight = 85
        pcall(function()
            if character.bIsCrouched then halfHeight = 60 end
            if character.IsProne and character:IsProne() then halfHeight = 25 end
        end)
    end

    return center, halfHeight, cx, cy, cz
end

-- ESP head and feet position made by VIP Server
local function g_vipserver_ESPGetCharacterBoxLocs(character,cachedLocation)
    local center, halfHeight, x, y, z = g_vipserver_ESPGetCharacterVerticalBounds(character,cachedLocation)
    if not x or not halfHeight then return nil,nil end

    local headLoc = g_vipserver_ESPV3(
        x,
        y,
        z + halfHeight
    )

    local feetLoc = g_vipserver_ESPV3(
        x,
        y,
        z - halfHeight
    )

    return headLoc, feetLoc, center
end

-- ESP head position made by VIP Server

-- ESP feet position made by VIP Server

-- Bounded inactive HUD widgets. Records retain native widget/slot structure,
-- never an enemy key, actor, name, delegate, bone mesh or controller. Collapsed
-- widgets stay under the same canvas so reuse does not allocate CanvasSlots.
local ESPWidgetPool={}
do
local shapes={
    Line={Fields={"Widget","Slot","PosVec","SizeVec","VectorReuseDisabled"},Check={"Widget","Slot"},Limit=256},
    NameV2={Fields={"Widget","Text","DistanceText","TextSlot","DistanceSlot","Slot"},
        Check={"Widget","Text","DistanceText","TextSlot","DistanceSlot","Slot"},Limit=16},
    NameV1={Fields={"Widget","BottomLine","HealthBg","HealthFill","Text","DistanceText",
        "LineSlot","HealthBgSlot","HealthFillSlot","TextSlot","DistanceSlot","Slot"},
        Check={"Widget","BottomLine","HealthBg","HealthFill","Text","DistanceText",
        "LineSlot","HealthBgSlot","HealthFillSlot","TextSlot","DistanceSlot","Slot"},Limit=16},
    Decor={Fields={"Widget","Slot","Groups"},Check={"Widget","Slot"},Limit=8},
    Header={Fields={"Widget","Slot","Groups"},Check={"Widget","Slot"},Limit=8},
}
local function remove(widget,pool)
    if pool and pool.Remove then pool.Remove(widget)
    elseif widget then pcall(function() widget:RemoveFromParent() end) end
end
local function weight(data)
    local count=1
    if data.Groups then
        for _,group in pairs(data.Groups) do count=count+#group end
    elseif data.Text then count=data.BottomLine and 6 or 3 end
    return count
end
local function resetGroups(groups)
    if not groups then return end
    for _,group in pairs(groups) do
        for field in pairs(group) do if type(field)~="number" then group[field]=nil end end
        for _,piece in ipairs(group) do
            local w,s,pv,sv,disabled=piece.Widget,piece.Slot,piece.PosVec,piece.SizeVec,piece.VectorReuseDisabled
            for field in pairs(piece) do piece[field]=nil end
            piece.Widget,piece.Slot,piece.PosVec,piece.SizeVec,piece.VectorReuseDisabled=w,s,pv,sv,disabled
            piece.Visible=false
        end
    end
end
function ESPWidgetPool.New(capacity)
    return {Bins={},Canvas=nil,Enabled=true,Weight=0,Capacity=capacity,
        Reused=0,Released=0,Created=0,Discarded=0}
end
ESPWidgetPool.V2=ESPWidgetPool.New(1024)
ESPWidgetPool.V1=ESPWidgetPool.New(128)
function ESPWidgetPool.Flush(pool)
    for kind,bin in pairs(pool.Bins) do
        for i=#bin,1,-1 do
            local item=bin[i];bin[i]=nil;remove(item.Widget,pool)
            for key in pairs(item) do item[key]=nil end
        end
        pool.Bins[kind]=nil
    end
    pool.Canvas=nil;pool.Weight=0
end
function ESPWidgetPool.Tag(pool,kind,canvas,data)
    if pool.Canvas~=canvas then ESPWidgetPool.Flush(pool);pool.Canvas=canvas end
    data.PoolOwner=pool;data.PoolKind=kind;data.PoolCanvas=canvas
    pool.Created=pool.Created+1
    return data
end
function ESPWidgetPool.Release(data)
    if data.PoolReleased then return true end
    local pool,kind,canvas=data.PoolOwner,data.PoolKind,data.PoolCanvas
    if not pool or not pool.Enabled or pool.Canvas~=canvas or data.Broken
        or not g_vipserver_ESPValid(data.Widget) then return false end
    local shape=shapes[kind]
    if not shape then return false end
    local bin=pool.Bins[kind]
    if not bin then bin={};pool.Bins[kind]=bin end
    local cost=weight(data)
    if #bin>=shape.Limit or pool.Weight+cost>pool.Capacity then return false end
    local ok=pcall(function()
        data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        if data.Text then data.Text:SetText("") end
        if data.DistanceText then data.DistanceText:SetText("") end
        if data.Groups then
            for _,group in pairs(data.Groups) do
                for _,piece in ipairs(group) do
                    if piece.Broken then error("POOL_BROKEN_PIECE") end
                    if piece.Visible~=false then
                        piece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end
        end
    end)
    if not ok then return false end
    resetGroups(data.Groups)
    local item={Weight=cost}
    for _,field in ipairs(shape.Fields) do item[field]=data[field] end
    -- Clear even caller-added fields so a reference never follows another enemy.
    for field in pairs(data) do data[field]=nil end
    data.PoolReleased=true
    bin[#bin+1]=item;pool.Weight=pool.Weight+cost;pool.Released=pool.Released+1
    return true
end
function ESPWidgetPool.Take(pool,kind,canvas)
    if pool.Canvas~=canvas then ESPWidgetPool.Flush(pool);pool.Canvas=canvas end
    if not pool.Enabled then return nil end
    local shape,bin=shapes[kind],pool.Bins[kind]
    if not shape or not bin then return nil end
    while #bin>0 do
        local item=bin[#bin];bin[#bin]=nil;pool.Weight=pool.Weight-item.Weight
        local valid=true
        for _,field in ipairs(shape.Check) do
            if not g_vipserver_ESPValid(item[field]) then valid=false;break end
        end
        if valid and item.Groups then
            for _,group in pairs(item.Groups) do
                for _,piece in ipairs(group) do
                    if not g_vipserver_ESPValid(piece.Widget) or not g_vipserver_ESPValid(piece.Slot) then
                        valid=false;break
                    end
                end
                if not valid then break end
            end
        end
        -- Missing bindings or externally detached/reparented widgets fall back
        -- to normal construction, rather than assuming their CanvasSlot works.
        if valid then
            local ok,parent=pcall(function() return item.Widget:GetParent() end)
            valid=ok and parent==canvas
        end
        if valid then
            local data={PoolOwner=pool,PoolKind=kind,PoolCanvas=canvas}
            for _,field in ipairs(shape.Fields) do data[field]=item[field] end
            resetGroups(data.Groups)
            pool.Reused=pool.Reused+1
            return data
        end
        remove(item.Widget,pool);pool.Discarded=pool.Discarded+1
        for key in pairs(item) do item[key]=nil end
    end
    return nil
end
end

-- ESP widget destroy made by VIP Server
local function g_vipserver_ESPDestroyWidgetData(data)
    if not data then return end
    if ESPWidgetPool.Release(data) then return end
    for _, field in ipairs({"Widget", "Container", "Text", "DistanceText"}) do
        local widget=data[field]
        if g_vipserver_ESPValid(widget) then
            pcall(function() widget:RemoveFromParent() end)
        end
    end
end

-- ESP widget cleanup made by VIP Server
local function g_vipserver_ESPResetWidgets()
    ESPWidgetPool.V2.Enabled=false
    for _, data in pairs(g_vipserver_ShotESP.Lines) do g_vipserver_ESPDestroyWidgetData(data) end
    for _, data in pairs(g_vipserver_ShotESP.Names) do g_vipserver_ESPDestroyWidgetData(data) end
    for _, group in pairs(g_vipserver_ShotESP.Boxes) do for _,data in ipairs(group) do g_vipserver_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_vipserver_ShotESP.HealthBars) do for _,data in ipairs(group) do g_vipserver_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_vipserver_ShotESP.Skeletons) do for _,data in ipairs(group) do g_vipserver_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_vipserver_ShotESP.Headers) do for _,data in ipairs(group) do g_vipserver_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_vipserver_ShotESP.Footers) do for _,data in ipairs(group) do g_vipserver_ESPDestroyWidgetData(data) end end
    g_vipserver_ShotESP.Lines = {}
    g_vipserver_ShotESP.Names = {}
    g_vipserver_ShotESP.Boxes = {}
    g_vipserver_ShotESP.HealthBars = {}
    g_vipserver_ShotESP.Skeletons = {}
    for _, data in pairs(g_vipserver_ShotESP.HeaderRoots) do g_vipserver_ESPDestroyWidgetData(data) end
    g_vipserver_ShotESP.HeaderRoots = {}
    g_vipserver_ShotESP.Headers = {}
    g_vipserver_ShotESP.Footers = {}
    g_vipserver_ShotESP.BuildStage = {}
    g_vipserver_ShotESP.BoneNameCache = {}
    for _,data in pairs(g_vipserver_ShotESP.Decorations) do g_vipserver_ESPDestroyWidgetData(data) end
    g_vipserver_ShotESP.Decorations = {}
    if g_vipserver_ShotESP.Counter then g_vipserver_ESPDestroyWidgetData(g_vipserver_ShotESP.Counter) end
    g_vipserver_ShotESP.Counter = nil
    g_vipserver_ShotESP.Canvas = nil
    g_vipserver_ShotESP.RootUI = nil
    g_vipserver_ShotESP.Enemies = {}
    g_vipserver_ShotESP.Active = {}
    g_vipserver_ShotESP.Alive = {}
    g_vipserver_ShotESP.BoneMeshes = {}
    g_vipserver_ShotESP.BonePoints = {}
    g_vipserver_ShotESP.TemplateFont = nil
    g_vipserver_ShotESP.TemplateFontObject = nil
    g_vipserver_ShotESP.TemplateTypeface = nil
    g_vipserver_ShotESP.TemplateColorAndOpacity = nil
    g_vipserver_ShotESP.ViewportW, g_vipserver_ShotESP.ViewportH = nil, nil
    g_vipserver_ShotESP.RawViewportW, g_vipserver_ShotESP.RawViewportH = nil, nil
    g_vipserver_ShotESP.TracerOrigin = nil
    g_vipserver_ShotESP.LastScanClock = -999.0
    g_vipserver_ShotESP.LastTransformClock = -999.0
    g_vipserver_ShotESP.LastController = nil
    g_vipserver_ShotESP.LastPawn = nil
    g_vipserver_ShotESP._BotCache = {}
    g_vipserver_ShotESP.RealCount = 0
    g_vipserver_ShotESP.BotCount = 0
    ESPWidgetPool.Flush(ESPWidgetPool.V2)
    ESPWidgetPool.V2.Enabled=true
end

-- ESP HUD canvas made by VIP Server
local function g_vipserver_ESPGetCanvas()
    if g_vipserver_ESPValid(g_vipserver_ShotESP.Canvas) then return g_vipserver_ShotESP.Canvas end
    local root = nil
    pcall(function()
        local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if InGameUITools and InGameUITools.GetMainControlBaseUI then root = InGameUITools.GetMainControlBaseUI() end
    end)
    if not g_vipserver_ESPValid(root) then return nil end
    g_vipserver_ShotESP.RootUI = root
    local canvas = nil
    pcall(function()
        if g_vipserver_ESPValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
        elseif g_vipserver_ESPValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
    end)
    if g_vipserver_ESPValid(canvas) then g_vipserver_ShotESP.Canvas = canvas return canvas end
    return nil
end

-- Discover a valid FontObject from existing HUD TextBlocks so dynamic TextBlocks always render glyphs
local function g_vipserver_ESPGetTemplateTextStyle()
    if g_vipserver_ESPValid(g_vipserver_ShotESP.TemplateFontObject) then
        return g_vipserver_ShotESP.TemplateFont
    end

    local visited = 0
    local function scanWidget(w, depth)
        if not w or depth > 6 or visited > 250 then return false end
        if not g_vipserver_ESPValid(w) then return false end
        visited = visited + 1

        local found = false
        pcall(function()
            if w.SetText and w.SetFont and w.Font then
                local f = w.Font
                if f and g_vipserver_ESPValid(f.FontObject) then
                    g_vipserver_ShotESP.TemplateFont = f
                    g_vipserver_ShotESP.TemplateFontObject = f.FontObject
                    pcall(function() g_vipserver_ShotESP.TemplateTypeface = f.TypefaceFontName end)
                    pcall(function() g_vipserver_ShotESP.TemplateColorAndOpacity = w.ColorAndOpacity end)
                    found = true
                end
            end
        end)
        if found then return true end

        local childCount = 0
        pcall(function() if w.GetChildrenCount then childCount = tonumber(w:GetChildrenCount()) or 0 end end)
        for i = 0, childCount - 1 do
            local child = nil
            pcall(function() child = w:GetChildAt(i) end)
            if child and scanWidget(child, depth + 1) then return true end
        end

        local treeRoot = nil
        pcall(function() if w.WidgetTree and w.WidgetTree.RootWidget then treeRoot = w.WidgetTree.RootWidget end end)
        if treeRoot and treeRoot ~= w and scanWidget(treeRoot, depth + 1) then return true end

        return false
    end

    local canvas = g_vipserver_ESPGetCanvas()
    if canvas then scanWidget(canvas, 0) end
    if not g_vipserver_ESPValid(g_vipserver_ShotESP.TemplateFontObject) and g_vipserver_ESPValid(g_vipserver_ShotESP.RootUI) then
        scanWidget(g_vipserver_ShotESP.RootUI, 0)
    end

    if not g_vipserver_ESPValid(g_vipserver_ShotESP.TemplateFontObject) and slua and slua.loadObject then
        for _, path in ipairs({
            "/Engine/EngineFonts/Roboto.Roboto",
            "/Engine/EngineFonts/Roboto",
            "/Engine/EngineFonts/DroidSansFallback.DroidSansFallback"
        }) do
            local ok, obj = pcall(slua.loadObject, path)
            if ok and g_vipserver_ESPValid(obj) then
                g_vipserver_ShotESP.TemplateFontObject = obj
                break
            end
        end
    end

    return g_vipserver_ShotESP.TemplateFont
end

-- ESP viewport size made by VIP Server
local function g_vipserver_ESPViewport(pc)
    local w,h
    local function take(x,y)
        x,y=tonumber(x),tonumber(y)
        if ESPShared.Finite(x) and ESPShared.Finite(y) and x>200 and y>200 and x<1e6 and y<1e6 then w,h=x,y;return true end
    end
    pcall(function()
        if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
            local v=WidgetLayoutLibrary.GetViewportSize(pc);if v then take(v.X,v.Y) end
        end
    end)
    if not w then pcall(function() local x,y=pc:GetViewportSize();take(x,y) end) end
    if not w then pcall(function() local v=g_vipserver_ESPV2(0,0);pc:GetViewportSize(v);take(v.X,v.Y) end) end
    if not w then pcall(function() local x,y=pc:GetViewportSize(0,0);take(x,y) end) end
    return w or 2400.0,h or 1080.0
end

-- ESP HUD canvas made by VIP Server
local function g_vipserver_ESPGetCanvasLocalSize()
    local canvas = g_vipserver_ESPGetCanvas()
    if not g_vipserver_ESPValid(canvas) then return nil, nil end

    local cw, ch = nil, nil
    pcall(function()
        local geo = canvas:GetCachedGeometry()
        if not geo then return end

        local size = nil
        if geo.GetLocalSize then
            size = geo:GetLocalSize()
        elseif SlateBlueprintLibrary and SlateBlueprintLibrary.GetLocalSize then
            size = SlateBlueprintLibrary.GetLocalSize(geo)
        end

        if size and ESPShared.Finite(size.X) and ESPShared.Finite(size.Y) and size.X > 100 and size.Y > 100 then
            cw, ch = tonumber(size.X), tonumber(size.Y)
        end
    end)

    return cw, ch
end

-- ESP canvas transform made by VIP Server
local function g_vipserver_ESPUpdateCanvasTransform(pc)
    local canvas = g_vipserver_ESPGetCanvas()
    if not g_vipserver_ESPValid(canvas) then return false end

    local calibrated = false

    pcall(function()
        if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
            local geo = canvas:GetCachedGeometry()
            if geo then
                local p0 = SlateBlueprintLibrary.AbsoluteToLocal(
                    geo,
                    g_vipserver_ESPV2(0, 0)
                )
                local p1 = SlateBlueprintLibrary.AbsoluteToLocal(
                    geo,
                    g_vipserver_ESPV2(100, 100)
                )

                if p0 and p1
                    and ESPShared.Finite(p0.X) and ESPShared.Finite(p0.Y)
                    and ESPShared.Finite(p1.X) and ESPShared.Finite(p1.Y)
                    and math.abs(p0.X)<1e7 and math.abs(p0.Y)<1e7
                    and p1.X>p0.X and p1.Y>p0.Y
                    and p1.X-p0.X<10000 and p1.Y-p0.Y<10000 then

                    g_vipserver_ShotESP.CanvasScaleX = (p1.X - p0.X) / 100.0
                    g_vipserver_ShotESP.CanvasScaleY = (p1.Y - p0.Y) / 100.0
                    g_vipserver_ShotESP.CanvasOffsetX = p0.X
                    g_vipserver_ShotESP.CanvasOffsetY = p0.Y
                    calibrated = true
                end
            end
        end
    end)

    if not calibrated then
        local scale = 1.0
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
                local s = WidgetLayoutLibrary.GetViewportScale(pc)
                if ESPShared.Finite(s) and s>=0.01 and s<=100 then
                    scale = s
                end
            end
        end)

        g_vipserver_ShotESP.CanvasScaleX = 1.0 / scale
        g_vipserver_ShotESP.CanvasScaleY = 1.0 / scale
        g_vipserver_ShotESP.CanvasOffsetX = 0.0
        g_vipserver_ShotESP.CanvasOffsetY = 0.0
    end

    return true
end

-- ESP world to HUD projection made by VIP Server
local function g_vipserver_ESPProject(pc,worldLoc)
    local frame=ESPShared.Frame
    -- Skeleton results own their output; only the immediate raw scratch is shared.
    if not frame.RawPixel then frame.RawPixel=g_vipserver_ESPV2(0,0) end
    local pix=ESPShared.ProjectRaw(pc,worldLoc,frame.Active and frame.RawPixel or nil)
    if not pix then return nil end
    local sx,sy,ox,oy=ESPShared.CanvasTransform(g_vipserver_ShotESP)
    return g_vipserver_ESPV2(pix.X*sx+ox,pix.Y*sy+oy)
end

-- Fresh projections deliberately avoid screen-space lerp: it adds camera lag
-- and desynchronizes the capsule outline from the independently projected bones.

local function g_vipserver_ESPActorOnScreen(head,feet,minX,minY,maxX,maxY)
    local function usable(p)
        return p and ESPShared.Finite(p.X) and ESPShared.Finite(p.Y)
    end
    head=usable(head) and head or nil;feet=usable(feet) and feet or nil
    if not head and not feet then return false end
    head=head or feet;feet=feet or head
    return math.max(head.X,feet.X)>=minX and math.min(head.X,feet.X)<=maxX
        and math.max(head.Y,feet.Y)>=minY and math.min(head.Y,feet.Y)<=maxY
end

function ESPShared.ViewSize(pc)
    local now=ESPShared.Frame.Active and ESPShared.Frame.Now or g_vipserver_ESPNow()
    if not ESPShared.Frame.Active or ESPShared.Frame.ViewPC~=pc or now<ESPShared.Frame.ViewAt or now-ESPShared.Frame.ViewAt>=0.25 then
        ESPShared.Frame.ViewW,ESPShared.Frame.ViewH=g_vipserver_ESPViewport(pc)
        ESPShared.Frame.ViewPC=pc;ESPShared.Frame.ViewAt=now
    end
    return ESPShared.Frame.ViewW,ESPShared.Frame.ViewH
end
function ESPShared.NativeProject(pc,location,pix)
    return pc:ProjectWorldLocationToScreen(location,pix,true)
end
function ESPShared.ActorProbeLocations(actor,entry)
    local center,height,x,y,z=g_vipserver_ESPGetCharacterVerticalBounds(actor,entry.Location)
    if not x or not height then return nil,nil end
    entry.WorldHead=ESPShared.UpdateProbeVector(entry.WorldHead,x,y,z+height)
    entry.WorldFeet=ESPShared.UpdateProbeVector(entry.WorldFeet,x,y,z-height)
    return entry.WorldHead,entry.WorldFeet
end
function ESPShared.ProjectRaw(pc,location,pix)
    if not ESPShared.VectorValues(location) or not ESPShared.ProjectionControllerValid(pc) then return nil end
    pix=pix or g_vipserver_ESPV2(0,0);pix.X=0;pix.Y=0
    local ok,result,out=pcall(ESPShared.NativeProject,pc,location,pix)
    if out then pix=out end
    local good,x,y=pcall(function() return tonumber(pix.X),tonumber(pix.Y) end)
    if not ok or not good or not ESPShared.Finite(x) or not ESPShared.Finite(y) or math.abs(x)>=1e7 or math.abs(y)>=1e7 then return nil,"unavailable" end
    if result==false or result==0 then return nil,"offscreen" end
    if result~=true and result~=1 and not (result==nil and (x~=0 or y~=0)) then return nil,"unavailable" end
    return pix,"visible"
end
function ESPShared.ProbeActor(pc,actor)
    local entry=ESPShared.GetFrameRecord(actor)
    if entry.Projected and entry.PC==pc then return entry end
    entry.Projected=true;entry.PC=pc;entry.OnScreen=false;entry.ProjectionReason="unavailable"
    if not entry.Alive or not entry.Location then return entry end
    local ok,head,feet=pcall(ESPShared.ActorProbeLocations,actor,entry)
    if not ok then return entry end
    entry.RawHead=entry.RawHead or g_vipserver_ESPV2(0,0)
    entry.RawFeet=entry.RawFeet or g_vipserver_ESPV2(0,0)
    local hp,hr=ESPShared.ProjectRaw(pc,head,entry.RawHead)
    local fp,fr=ESPShared.ProjectRaw(pc,feet,entry.RawFeet)
    if hp then entry.RawHead=hp end;if fp then entry.RawFeet=fp end
    entry.HasHead=hp~=nil;entry.HasFeet=fp~=nil
    local width,height=ESPShared.ViewSize(pc)
    entry.OnScreen=g_vipserver_ESPActorOnScreen(hp,fp,0,0,width,height)
    if entry.OnScreen then entry.ProjectionReason="visible"
    elseif hp or fp or hr=="offscreen" or fr=="offscreen" then entry.ProjectionReason="offscreen" end
    return entry
end
function ESPShared.CanvasBounds(pc,state)
    local width,height=ESPShared.ViewSize(pc)
    local sx,sy,ox,oy=ESPShared.CanvasTransform(state)
    local maxX,maxY=ox+width*sx,oy+height*sy
    if ESPShared.Finite(state.ViewportW) and state.ViewportW>1 then maxX=math.min(maxX,ox+state.ViewportW) end
    if ESPShared.Finite(state.ViewportH) and state.ViewportH>1 then maxY=math.min(maxY,oy+state.ViewportH) end
    return ox,oy,maxX,maxY
end
function ESPShared.ProjectActor(pc,actor,state)
    local entry=ESPShared.ProbeActor(pc,actor)
    if not entry.OnScreen then return nil,nil,false,entry.ProjectionReason end
    local sx,sy,ox,oy=ESPShared.CanvasTransform(state)
    local prefix=state==g_vipserver_ShotESP and "V2" or "V1"
    local function convert(raw,field)
        local p=entry[field] or g_vipserver_ESPV2(0,0);entry[field]=p
        p.X=raw.X*sx+ox;p.Y=raw.Y*sy+oy;return p
    end
    local head=entry.HasHead and convert(entry.RawHead,prefix.."Head") or nil
    local feet=entry.HasFeet and convert(entry.RawFeet,prefix.."Feet") or nil
    local minX,minY,maxX,maxY=ESPShared.CanvasBounds(pc,state)
    local visible=g_vipserver_ESPActorOnScreen(head,feet,minX,minY,maxX,maxY)
    return head,feet,visible,visible and "visible" or "offscreen"
end


-- ESP text setter with FText conversion fallback

-- ESP font style made by VIP Server
local function g_vipserver_ESPSetFont(textWidget, size)
    if not g_vipserver_ESPValid(textWidget) then return end
    g_vipserver_ESPGetTemplateTextStyle()
    pcall(function()
        local f = textWidget.Font or g_vipserver_ShotESP.TemplateFont
        if f then
            if g_vipserver_ESPValid(g_vipserver_ShotESP.TemplateFontObject) then
                pcall(function() f.FontObject = g_vipserver_ShotESP.TemplateFontObject end)
            end
            if g_vipserver_ShotESP.TemplateTypeface then
                pcall(function() f.TypefaceFontName = g_vipserver_ShotESP.TemplateTypeface end)
            end
            pcall(function() f.Size = size end)
            if f.OutlineSettings then
                pcall(function()
                    local os = f.OutlineSettings
                    os.OutlineSize = 0
                    os.OutlineColor = ESP_TEXT_CLEAR
                    f.OutlineSettings = os
                end)
            end
            pcall(function() textWidget:SetFont(f) end)
            pcall(function() textWidget.Font = f end)
        end
        if textWidget.SetShadowOffset then
            pcall(function() textWidget:SetShadowOffset(g_vipserver_ESPV2(0.0,0.0)) end)
        end
        if textWidget.SetShadowColorAndOpacity then
            pcall(function() textWidget:SetShadowColorAndOpacity(ESP_TEXT_CLEAR) end)
        end
    end)
end

-- ESP text color made by VIP Server
local function g_vipserver_ESPSetTextColor(textWidget, color)
    if not g_vipserver_ESPValid(textWidget) or not color then return end
    local applied = false
    pcall(function()
        local sc = textWidget.ColorAndOpacity or g_vipserver_ShotESP.TemplateColorAndOpacity or (SlateColor and SlateColor())
        if sc then
            sc.SpecifiedColor = color
            pcall(function() sc.ColorUseRule = 0 end)
            local check = sc.SpecifiedColor
            if check and tonumber(check.A) and tonumber(check.A) > 0 then
                textWidget:SetColorAndOpacity(sc)
                pcall(function() textWidget.ColorAndOpacity = sc end)
                applied = true
            end
        end
    end)
    if not applied then
        pcall(function() textWidget:SetColorAndOpacity(color) end)
    end
    pcall(function() if textWidget.SetOpacity then textWidget:SetOpacity(1.0) end end)
    pcall(function() if textWidget.SetRenderOpacity then textWidget:SetRenderOpacity(1.0) end end)
end

-- ESP line widget made by VIP Server
local function g_vipserver_ESPCreateLine(color,parent)
    local canvas = parent or g_vipserver_ESPGetCanvas()
    if not g_vipserver_ESPValid(canvas) then return nil end
    local budget = g_vipserver_ShotESP.BuildRemaining
    if budget ~= nil then
        if budget <= 0 then return nil end
        g_vipserver_ShotESP.BuildRemaining = budget - 1
    end
    local pooled=canvas==g_vipserver_ShotESP.Canvas and ESPWidgetPool.Take(ESPWidgetPool.V2,"Line",canvas)
    if pooled then
        local ok=pcall(function() pooled.Widget:SetBrushColor(color) end)
        if ok then pooled.Visible=false;return pooled end
        pcall(function() pooled.Widget:RemoveFromParent() end)
    end
    local border = nil
    pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
    if not g_vipserver_ESPValid(border) then return nil end
    pcall(function()
        border:SetBrushColor(color)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        border:SetRenderTransformPivot(g_vipserver_ESPV2(0.0, 0.5))
    end)
    local slot = nil
    pcall(function() slot = canvas:AddChildToCanvas(border) end)
    if not slot then g_vipserver_ESPDestroyWidgetData({Widget=border}) return nil end
    pcall(function() slot:SetAutoSize(false) slot:SetZOrder(30) end)
    local data={Widget=border, Slot=slot}
    if canvas==g_vipserver_ShotESP.Canvas then ESPWidgetPool.Tag(ESPWidgetPool.V2,"Line",canvas,data) end
    return data
end

-- ESP line made by VIP Server
local function g_vipserver_ESPDrawLine(data, x1, y1, x2, y2, thickness)
    if not data or not data.Widget or not data.Slot then return false end
    local dx, dy = x2-x1, y2-y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 1 then
        if data.Visible ~= false then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.Visible = false
        end
        return false
    end
    local angle = ((math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)) * 180.0 / math.pi
    local unchanged=data.Visible==true and data.X1 and
        math.abs(data.X1-x1)<0.25 and math.abs(data.Y1-y1)<0.25 and
        math.abs(data.X2-x2)<0.25 and math.abs(data.Y2-y2)<0.25 and
        math.abs((data.Thickness or 0)-thickness)<0.05
    if unchanged then return true end
    -- Reuse native transform values after the first draw. Older bindings
    -- that reject mutable structs fall back once to the original setter path.
    local setterOK=pcall(function()
        if data.VectorReuseDisabled then
            data.Slot:SetPosition(g_vipserver_ESPV2(x1, y1 - thickness*0.5))
            data.Slot:SetSize(g_vipserver_ESPV2(len, thickness))
        else
            data.PosVec=data.PosVec or g_vipserver_ESPV2(x1, y1 - thickness*0.5)
            data.SizeVec=data.SizeVec or g_vipserver_ESPV2(len, thickness)
            data.PosVec.X=x1;data.PosVec.Y=y1-thickness*0.5
            data.SizeVec.X=len;data.SizeVec.Y=thickness
            data.Slot:SetPosition(data.PosVec)
            data.Slot:SetSize(data.SizeVec)
        end
        data.Widget:SetRenderAngle(angle)
        if not data.Visible then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
    end)
    if not setterOK and not data.VectorReuseDisabled then
        data.VectorReuseDisabled=true;data.PosVec=nil;data.SizeVec=nil
        setterOK=pcall(function()
            data.Slot:SetPosition(g_vipserver_ESPV2(x1, y1 - thickness*0.5))
            data.Slot:SetSize(g_vipserver_ESPV2(len, thickness))
            data.Widget:SetRenderAngle(angle)
            if not data.Visible then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
        end)
    end
    if not setterOK then data.Broken=true return false end
    data.Broken=false
    data.X1,data.Y1,data.X2,data.Y2,data.Thickness=x1,y1,x2,y2,thickness
    data.Visible=true
    return true
end

-- ESP widget hide made by VIP Server
local function g_vipserver_ESPHide(data)
    if data and data.Visible~=false and data.Widget then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        if not ok then data.Broken=true end
        data.Visible=false
    end
end

local function g_vipserver_ESPDestroyGroup(group)
    if not group then return end
    for _, data in ipairs(group) do g_vipserver_ESPDestroyWidgetData(data) end
end

-- Check native widget validity at discovery cadence; failed setters mark a
-- piece broken immediately. This avoids an IsValid bridge call per piece/frame.
local function g_vipserver_ESPGroupHealthy(group)
    if not group then return false end
    local now = g_vipserver_ShotESP.Now
    local validate = not group.ValidatedAt or now < group.ValidatedAt or now-group.ValidatedAt >= 0.35
    for _, data in ipairs(group) do
        if data.Broken or (validate and not g_vipserver_ESPValid(data.Widget)) then return false end
    end
    if validate then group.ValidatedAt = now end
    return true
end

-- Keep partial groups across ticks; budgeted creation prevents first-visibility spikes.
local function g_vipserver_ESPLineGroup(registry, key, count, color, parent)
    local group = registry[key]
    if group and not g_vipserver_ESPGroupHealthy(group) then
        g_vipserver_ESPDestroyGroup(group)
        group = nil
    end
    if not group or #group > count then
        g_vipserver_ESPDestroyGroup(group)
        group = {}
        registry[key] = group
    end
    while #group < count do
        local data = g_vipserver_ESPCreateLine(color, parent)
        if not data then return nil end
        group[#group + 1] = data
        g_vipserver_ESPHide(data)
    end
    return group
end

-- Existing geometry and widgets are reused. Stable identity performs no native
-- color setters; failed brush assignments remain eligible for retry.
local function g_vipserver_ESPApplyGroupTheme(group,theme,kind)
    if not group or group.ThemeKey==theme.Key then return end
    local ok=pcall(function()
        for i,piece in ipairs(group) do
            local color=theme.Main
            if kind=="Header" then
                if i>=23 then color=theme.Background
                elseif i>=9 and i<=12 then color=theme.Light end
            elseif kind=="Arcs" then
                if i>=11 and i<=20 then color=theme.Light end
            elseif kind=="Footer" then
                if i<=4 then color=theme.Light end
            elseif kind=="Health" then
                if i==1 then color=theme.Background
                elseif i>=10 then color=theme.Light
                else color=theme.Empty end
            end
            piece.Widget:SetBrushColor(color)
        end
    end)
    if ok then group.ThemeKey=theme.Key end
end

local function g_vipserver_ESPHideGroup(group)
    if not group then return end
    for _, data in ipairs(group) do g_vipserver_ESPHide(data) end
end

local function g_vipserver_ESPHideDetailedEnemy(key)
    g_vipserver_ESPHide(g_vipserver_ShotESP.Lines[key])
    g_vipserver_ESPHideGroup(g_vipserver_ShotESP.Boxes[key])
    g_vipserver_ESPHideGroup(g_vipserver_ShotESP.HealthBars[key])
    g_vipserver_ESPHideGroup(g_vipserver_ShotESP.Skeletons[key])
    g_vipserver_ESPHideGroup(g_vipserver_ShotESP.Headers[key])
    local decor=g_vipserver_ShotESP.Decorations[key]
    if decor and decor.Visible~=false then pcall(function() decor.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) decor.Visible=false end
end

local g_vipserver_ESPHealthRatio

local function g_vipserver_ESPSetGroupVisible(group,visible)
    if not group or group.GroupVisible==visible then return end
    for _,data in ipairs(group) do
        if visible then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            data.Visible=true
        else g_vipserver_ESPHide(data) end
    end
    group.GroupVisible=visible
end

local function g_vipserver_ESPCreateDecorationRoot(poolKind)
    local canvas=g_vipserver_ESPGetCanvas()
    if not g_vipserver_ESPValid(canvas) then return nil end
    poolKind=poolKind or "Decor"
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V2,poolKind,canvas)
    if pooled then
        local ok=pcall(function()
            pooled.Slot:SetZOrder(poolKind=="Header" and 30 or 29)
            pooled.Widget:SetRenderScale(g_vipserver_ESPV2(1.0,1.0))
            pooled.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        if ok then pooled.Visible=true;return pooled end
        pcall(function() pooled.Widget:RemoveFromParent() end)
    end
    local root=nil
    pcall(function() root=CGame:NewObjectFromPath("/Script/UMG.CanvasPanel",canvas) end)
    if not g_vipserver_ESPValid(root) then return nil end
    local slot=nil
    pcall(function() slot=canvas:AddChildToCanvas(root) end)
    if not slot then g_vipserver_ESPDestroyWidgetData({Widget=root}) return nil end
    pcall(function()
        slot:SetAutoSize(false)
        slot:SetSize(g_vipserver_ESPV2(1000.0,1400.0))
        slot:SetZOrder(29)
        root:SetRenderTransformPivot(g_vipserver_ESPV2(0.0,0.0))
        root:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    return ESPWidgetPool.Tag(ESPWidgetPool.V2,poolKind,canvas,{Widget=root,Slot=slot,Groups={},Visible=true})
end

local function g_vipserver_ESPDecorGroup(data,name,count,color)
    return g_vipserver_ESPLineGroup(data.Groups,name,count,color,data.Widget)
end


local function g_vipserver_ESPBuildArcs(data)
    local group=g_vipserver_ESPDecorGroup(data,"Arcs",26,ESP_REAL)
    if not group then return nil end
    if group.Built then return group end
    local cx,cy,half,ry=500.0,385.0,268.0,180.0
    -- Progressive stroke curve: 2x at both corners, 5x at the center.
    -- Red base thickness is 3.0; white base thickness is 1.5.
    local redThickness={6.0,10.5,15.0,10.5,6.0}
    local whiteThickness={3.0,5.25,7.5,5.25,3.0}
    local index=1
    for _,side in ipairs({-1,1}) do
        local previous=nil
        for step=0,5 do
            local angle=(-70+step*28)*math.pi/180
            local p={X=cx+side*half*math.cos(angle),Y=cy+ry*math.sin(angle)}
            if previous then
                g_vipserver_ESPDrawLine(group[index],previous.X,previous.Y,p.X,p.Y,redThickness[step])
                index=index+1
            end
            previous=p
        end
    end
    local tickIndex=21
    for _,side in ipairs({-1,1}) do
        local x=cx+side*half*1.02
        for _,oy in ipairs({-24.0,0.0,24.0}) do
            g_vipserver_ESPDrawLine(group[tickIndex],x-side*5.0,cy+oy,x+side*2.0,cy+oy,2.2)
            tickIndex=tickIndex+1
        end
    end
    local ih,ir=half*.82,ry*.76
    for _,side in ipairs({-1,1}) do
        local previous=nil
        for step=0,5 do
            local angle=(-54+step*(108/5))*math.pi/180
            local p={X=cx+side*ih*math.cos(angle),Y=cy+ir*math.sin(angle)}
            if previous then
                pcall(function() group[index].Widget:SetBrushColor(ESP_WHITE) end)
                g_vipserver_ESPDrawLine(group[index],previous.X,previous.Y,p.X,p.Y,whiteThickness[step])
                index=index+1
            end
            previous=p
        end
    end
    group.Built=true group.GroupVisible=true
    return group
end

local function g_vipserver_ESPBuildHealth(data)
    local group=g_vipserver_ESPDecorGroup(data,"Health",11,ESP_REAL)
    if not group then return nil end
    if group.Built then return group end
    -- Twice the original footprint so distant health remains readable.
    local x,barBottom,barTop,barW=700.0,1120.0,564.0,60.0
    pcall(function()
        for i=1,11 do group[i].Widget:SetBrushColor(ESP_REAL) end
    end)
    g_vipserver_ESPDrawLine(group[1],x,barTop,x,barBottom,barW)
    local sh=(barBottom-barTop)/8
    for i=1,8 do
        local y1=barBottom-(i-1)*sh-2
        local y2=barBottom-i*sh+2
        g_vipserver_ESPDrawLine(group[i+1],x,y1,x,y2,barW*.64)
    end
    g_vipserver_ESPDrawLine(group[10],x-barW*.5,barTop,x+barW*.5,barTop,2.0)
    g_vipserver_ESPDrawLine(group[11],x-barW*.5,barBottom,x+barW*.5,barBottom,2.0)
    group.Built=true group.GroupVisible=true group.Filled=-1
    return group
end

local function g_vipserver_ESPBuildFooter(data)
    local group=g_vipserver_ESPDecorGroup(data,"Footer",6,ESP_WHITE)
    if not group then return nil end
    if group.Built then return group end
    local cx,y,w=500.0,1243.0,394.0
    local s={{cx-w*.5,y,cx-w*.29,y},{cx-w*.5,y,cx-w*.58,y-7},{cx+w*.29,y,cx+w*.5,y},{cx+w*.5,y,cx+w*.58,y-7},{cx-w*.23,y,cx-w*.19,y},{cx+w*.19,y,cx+w*.23,y}}
    for i,v in ipairs(s) do pcall(function() group[i].Widget:SetBrushColor(i>=5 and ESP_REAL or ESP_WHITE) end) g_vipserver_ESPDrawLine(group[i],v[1],v[2],v[3],v[4],i>=5 and 2.2 or 1.6) end
    group.Built=true group.GroupVisible=true
    return group
end

local function g_vipserver_ESPUpdateDecoration(key,character,head,feet,opt,stage,isBot)
    local enabled=opt.Name or opt.Box or opt.Health or opt.Distance
    local data=g_vipserver_ShotESP.Decorations[key]
    if not enabled or not head or not feet then
        if data and data.Visible~=false then pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) data.Visible=false end
        return
    end
    if not data or not g_vipserver_ESPValid(data.Widget) then
        g_vipserver_ESPDestroyWidgetData(data)
        data=g_vipserver_ESPCreateDecorationRoot()
        g_vipserver_ShotESP.Decorations[key]=data
    end
    if not data then return end
    local h=math.abs(feet.Y-head.Y)
    if h<8 then return end
    local scale=h/1000.0
    local x,y=head.X-500.0*scale,head.Y-200.0*scale
    local moved=not data.X or math.abs(data.X-x)>=.25 or math.abs(data.Y-y)>=.25
    local scaled=not data.Scale or math.abs(data.Scale-scale)>=.001
    if moved then
        local ok=pcall(function() data.Slot:SetPosition(g_vipserver_ESPV2(x,y)) end)
        if ok then data.X,data.Y=x,y end
    end
    if scaled then
        local ok=pcall(function() data.Widget:SetRenderScale(g_vipserver_ESPV2(scale,scale)) end)
        if ok then data.Scale=scale else data.Scale=nil end
    end
    if data.Visible~=true then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        if ok then data.Visible=true end
    end
    -- Header: handled by ESPUpdateHeaderFrame (screen-space, dynamic width) — hide DecorationRoot version
    if data.Groups.Header then g_vipserver_ESPSetGroupVisible(data.Groups.Header, false) end
    local theme=g_vipserver_ESPTheme(isBot)
    local arcs=data.Groups.Arcs
    if opt.Box then arcs=g_vipserver_ESPBuildArcs(data) end
    if arcs then g_vipserver_ESPApplyGroupTheme(arcs,theme,"Arcs") end
    g_vipserver_ESPSetGroupVisible(arcs,opt.Box==true)
    local health=data.Groups.Health
    if opt.Health then health=g_vipserver_ESPBuildHealth(data) end
    local healthTypeChanged=health and health.ThemeKey~=theme.Key
    if health then g_vipserver_ESPApplyGroupTheme(health,theme,"Health") end
    g_vipserver_ESPSetGroupVisible(health,opt.Health==true)
    if health and opt.Health then
        local filled=math.ceil(g_vipserver_ESPHealthRatio(character)*8-.001)
        if health.Filled~=filled or healthTypeChanged then
            local ok=pcall(function() for i=1,8 do health[i+1].Widget:SetBrushColor(i<=filled and theme.Main or theme.Empty) end end)
            if ok then health.Filled=filled end
        end
    end
    local footer=data.Groups.Footer
    if opt.Distance then footer=g_vipserver_ESPBuildFooter(data) end
    if footer then g_vipserver_ESPApplyGroupTheme(footer,theme,"Footer") end
    g_vipserver_ESPSetGroupVisible(footer,opt.Distance==true)
end

local function g_vipserver_ESPUpdateHeaderFrame(key,head,feet,enabled,isBot)
    local group=g_vipserver_ShotESP.Headers[key]
    if not enabled or not head or not feet then g_vipserver_ESPHideGroup(group) return end
    local h=math.abs(feet.Y-head.Y)
    -- Compact distance scaling.  The bottom edge stays above the head and all
    -- height growth happens upward, so zooming never pushes the plate onto the body.
    local w=math.max(68.0,math.min(232.0,h*0.315))
    local cached=g_vipserver_ShotESP.Names[key] and g_vipserver_ShotESP.Names[key].CachedName or ""
    w=math.max(w,math.min(232.0,28.0+#tostring(cached)*6.0))
    local hh=math.max(18.0,math.min(48.0,h*0.070))
    local headGap=math.max(4.0,math.min(10.0,h*0.025))
    local cx=head.X
    local b=head.Y-headGap
    local t=b-hh
    local cy=(t+b)*0.5
    local l,r=cx-w*0.5,cx+w*0.5
    local cut=hh*0.28
    -- 25 frame/background widgets + 8 horizontal fill bands per corner.
    -- The bands approximate true triangles without using rotated rectangles,
    -- which were the source of the original black corner leakage.
    local root = g_vipserver_ShotESP.HeaderRoots[key]
    if not root or not g_vipserver_ESPValid(root.Widget) then
        g_vipserver_ESPDestroyGroup(group)
        g_vipserver_ShotESP.Headers[key] = nil
        group = nil
        g_vipserver_ESPDestroyWidgetData(root)
        root = g_vipserver_ESPCreateDecorationRoot("Header")
        g_vipserver_ShotESP.HeaderRoots[key] = root
        if not root then return end
        group=root.Groups.__Header
        root.Groups.__Header=nil
        g_vipserver_ShotESP.Headers[key]=group
        pcall(function() root.Slot:SetZOrder(30) end)
    end
    -- Move 57 header pieces with one parent slot. Width/height changes still
    -- rebuild the exact original geometry with constant stroke thickness.
    local rootY = b
    local moved = not root.X or math.abs(root.X-cx) >= 0.25 or math.abs(root.Y-rootY) >= 0.25
    if moved then
        local ok = pcall(function() root.Slot:SetPosition(g_vipserver_ESPV2(cx,rootY)) end)
        if ok then root.X,root.Y = cx,rootY end
    end
    local theme=g_vipserver_ESPTheme(isBot)
    local ready = group and #group == 57
    if ready then g_vipserver_ESPApplyGroupTheme(group,theme,"Header") end
    if ready and group.Width and math.abs(group.Width-w) < 0.25 and math.abs(group.Height-hh) < 0.25 then
        local healthy = g_vipserver_ESPGroupHealthy(group)
        if healthy then
            for _, piece in ipairs(group) do
                if piece.Drawn then
                    if piece.Visible ~= true then
                        local ok = pcall(function() piece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        if ok then piece.Visible = true end
                    end
                else g_vipserver_ESPHide(piece) end
            end
            return
        end
    end
    group=g_vipserver_ESPLineGroup(g_vipserver_ShotESP.Headers,key,57,ESP_REAL,root.Widget)
    if not group then return end
    cx, b, t, cy = 0.0, 0.0, -hh, -hh*0.5
    l, r = -w*0.5, w*0.5
    local seg={{l+cut,t,r-cut,t},{r-cut,t,r,t+cut},{r,t+cut,r,b-cut},{r,b-cut,r-cut,b},{r-cut,b,l+cut,b},{l+cut,b,l,b-cut},{l,b-cut,l,t+cut},{l,t+cut,l+cut,t}}
    if not group.HeaderStyled then
        local ok=pcall(function() for i=23,57 do group[i].Slot:SetZOrder(0) end end)
        if ok then group.HeaderStyled=true end
    end
    g_vipserver_ESPApplyGroupTheme(group,theme,"Header")
    -- octagon border
    for i,s in ipairs(seg) do g_vipserver_ESPDrawLine(group[i],s[1],s[2],s[3],s[4],2.0) end
    -- white inner accent lines on top/bottom edges
    g_vipserver_ESPDrawLine(group[9],l+cut*1.05,t,l+w*0.16,t,1.25)
    g_vipserver_ESPDrawLine(group[10],r-w*0.16,t,r-cut*1.05,t,1.25)
    g_vipserver_ESPDrawLine(group[11],l+cut*1.05,b,l+w*0.16,b,1.25)
    g_vipserver_ESPDrawLine(group[12],r-w*0.16,b,r-cut*1.05,b,1.25)
    -- bottom spike
    g_vipserver_ESPDrawLine(group[13],cx-cut*0.7,b,cx,b+cut,2.0)
    g_vipserver_ESPDrawLine(group[14],cx,b+cut,cx+cut*0.7,b,2.0)
    -- chevrons (side arrows)
    local co=cut*0.70
    g_vipserver_ESPDrawLine(group[15],l-co*1.9,cy,l-co*1.25,cy-co,2.2)
    g_vipserver_ESPDrawLine(group[16],l-co*1.9,cy,l-co*1.25,cy+co,2.2)
    g_vipserver_ESPDrawLine(group[17],r+co*1.9,cy,r+co*1.25,cy-co,2.2)
    g_vipserver_ESPDrawLine(group[18],r+co*1.9,cy,r+co*1.25,cy+co,2.2)
    g_vipserver_ESPDrawLine(group[19],l-co*2.8,cy,l-co*2.15,cy-co,2.2)
    g_vipserver_ESPDrawLine(group[20],l-co*2.8,cy,l-co*2.15,cy+co,2.2)
    g_vipserver_ESPDrawLine(group[21],r+co*2.8,cy,r+co*2.15,cy-co,2.2)
    g_vipserver_ESPDrawLine(group[22],r+co*2.8,cy,r+co*2.15,cy+co,2.2)
    -- background: center + left strip + right strip (3-part fill of octagon interior)
    g_vipserver_ESPDrawLine(group[23],l+cut,cy,r-cut,cy,hh)
    g_vipserver_ESPDrawLine(group[24],l,cy,l+cut,cy,hh-2*cut)
    g_vipserver_ESPDrawLine(group[25],r-cut,cy,r,cy,hh-2*cut)
    -- Fill each missing corner triangle with horizontal stepped bands.  Every
    -- band starts inside the diagonal, so black cannot cross the red border.
    local cornerSteps=8
    local bandH=cut/cornerSteps
    for i=1,cornerSteps do
        local inset=(i-1)*bandH
        local topY=t+(i-0.5)*bandH
        local bottomY=b-(i-0.5)*bandH
        local leftStart=l+cut-inset
        local rightEnd=r-cut+inset

        if inset>0.5 then
            g_vipserver_ESPDrawLine(group[25+i],leftStart,topY,l+cut+0.5,topY,bandH)
            g_vipserver_ESPDrawLine(group[33+i],r-cut-0.5,topY,rightEnd,topY,bandH)
            g_vipserver_ESPDrawLine(group[41+i],leftStart,bottomY,l+cut+0.5,bottomY,bandH)
            g_vipserver_ESPDrawLine(group[49+i],r-cut-0.5,bottomY,rightEnd,bottomY,bandH)
        else
            g_vipserver_ESPHide(group[25+i])
            g_vipserver_ESPHide(group[33+i])
            g_vipserver_ESPHide(group[41+i])
            g_vipserver_ESPHide(group[49+i])
        end
    end
    group.Width, group.Height = w, hh
    for _, piece in ipairs(group) do piece.Drawn = piece.Visible == true end
end



g_vipserver_ESPHealthRatio = function(character)
    local hp, maxHp = nil, nil
    pcall(function()
        hp = character.Health or character.HP or character.CurrentHealth
        maxHp = character.HealthMax or character.MaxHealth or character.MaxHP
        if not tonumber(hp) and character.GetHealth then hp=character:GetHealth() end
        if not tonumber(maxHp) and character.GetMaxHealth then maxHp=character:GetMaxHealth() end
    end)
    hp, maxHp = tonumber(hp), tonumber(maxHp)
    if not hp or not maxHp or maxHp <= 0 then return 1.0 end
    return math.max(0.0,math.min(1.0,hp/maxHp))
end




local g_vipserver_ESPBones = {
    head={"Head","head","head_01"}, neck={"neck_01","Neck","neck"}, pelvis={"pelvis","Pelvis"},
    ls={"upperarm_l","UpperArm_L","clavicle_l"}, le={"lowerarm_l","LowerArm_L"}, lw={"hand_l","Hand_L"},
    rs={"upperarm_r","UpperArm_R","clavicle_r"}, re={"lowerarm_r","LowerArm_R"}, rw={"hand_r","Hand_R"},
    lh={"thigh_l","Thigh_L","hip_l"}, lk={"calf_l","Calf_L","knee_l"}, la={"foot_l","Foot_L"},
    rh={"thigh_r","Thigh_R","hip_r"}, rk={"calf_r","Calf_R","knee_r"}, ra={"foot_r","Foot_R"}
}
local g_vipserver_ESPBoneLinks={{"head","neck"},{"neck","ls"},{"ls","le"},{"le","lw"},{"neck","rs"},{"rs","re"},{"re","rw"},{"neck","pelvis"},{"pelvis","lh"},{"lh","lk"},{"lk","la"},{"pelvis","rh"},{"rh","rk"},{"rk","ra"}}

-- Cache only the bone-name lookup; world positions and camera projections remain fresh.
local function g_vipserver_ESPBoneScreen(pc, mesh, id, names, cache)
    local cached = cache[id]
    if cached then
        local ok, loc = pcall(function()
            if mesh.GetSocketLocation then return mesh:GetSocketLocation(cached)
            elseif mesh.GetBoneLocation then return mesh:GetBoneLocation(cached) end
        end)
        if ok and loc and tonumber(loc.X) then return g_vipserver_ESPProject(pc,loc) end
        cache[id] = nil
    end
    for _, name in ipairs(names) do
        local ok, loc = pcall(function()
            local exists = nil
            if mesh.DoesSocketExist then exists = mesh:DoesSocketExist(name)
            elseif mesh.GetBoneIndex then exists = (tonumber(mesh:GetBoneIndex(name)) or -1) >= 0 end
            if exists ~= false then
                if mesh.GetSocketLocation then return mesh:GetSocketLocation(name)
                elseif mesh.GetBoneLocation then return mesh:GetBoneLocation(name) end
            end
        end)
        if ok and loc and tonumber(loc.X) then
            cache[id] = name
            return g_vipserver_ESPProject(pc,loc)
        end
    end
    return nil
end

local function g_vipserver_ESPUpdateSkeleton(key, character, pc, enabled, isBot)
    local group = g_vipserver_ShotESP.Skeletons[key]
    if not enabled then g_vipserver_ESPHideGroup(group) return end
    local mesh = nil
    pcall(function() mesh=character.Mesh or (character.GetMesh and character:GetMesh()) end)
    if not g_vipserver_ESPValid(mesh) then g_vipserver_ESPHideGroup(group) return end
    if g_vipserver_ShotESP.BoneMeshes[key] ~= mesh then
        g_vipserver_ShotESP.BoneMeshes[key] = mesh
        g_vipserver_ShotESP.BoneNameCache[key] = {}
        g_vipserver_ShotESP.BonePoints[key] = {}
    end
    local points = g_vipserver_ShotESP.BonePoints[key]
    local cache = g_vipserver_ShotESP.BoneNameCache[key]
    local theme=g_vipserver_ESPTheme(isBot)
    group = g_vipserver_ESPLineGroup(g_vipserver_ShotESP.Skeletons,key,#g_vipserver_ESPBoneLinks,theme.Main)
    if not group then return end
    g_vipserver_ESPApplyGroupTheme(group,theme,"Skeleton")
    for id, names in pairs(g_vipserver_ESPBones) do
        points[id] = g_vipserver_ESPBoneScreen(pc,mesh,id,names,cache)
    end
    local ankle = points.la or points.ra
    local skeletonH = (points.head and ankle) and math.abs(ankle.Y-points.head.Y) or 360.0
    local thickness = math.max(1.0,math.min(2.8,skeletonH*0.0028))
    for i, link in ipairs(g_vipserver_ESPBoneLinks) do
        local a, b = points[link[1]], points[link[2]]
        if a and b then g_vipserver_ESPDrawLine(group[i],a.X,a.Y,b.X,b.Y,thickness)
        else g_vipserver_ESPHide(group[i]) end
    end
end

-- ESP enemy name widget made by VIP Server
local function g_vipserver_ESPCreateNameTag(isBot)
    local canvas = g_vipserver_ESPGetCanvas()
    if not g_vipserver_ESPValid(canvas) then return nil end
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V2,"NameV2",canvas)
    if pooled then
        local theme=g_vipserver_ESPTheme(isBot)
        g_vipserver_ESPSetTextColor(pooled.Text,theme.Text)
        g_vipserver_ESPSetTextColor(pooled.DistanceText,theme.Text)
        g_vipserver_ESPSetFont(pooled.Text,tonumber(_G.g_vipserver_VIPShotESP.NameFontSize) or 16,0)
        g_vipserver_ESPSetFont(pooled.DistanceText,tonumber(_G.g_vipserver_VIPShotESP.DistanceFontSize) or 20,0)
        pooled.IsBot=isBot;pooled.ContainerVisible=false
        if pooled then return pooled end
    end

    local container, nameText, distanceText = nil, nil, nil
    pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not g_vipserver_ESPValid(container) then return nil end
    pcall(function() nameText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    pcall(function() distanceText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    if not g_vipserver_ESPValid(nameText) or not g_vipserver_ESPValid(distanceText) then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end

    pcall(function()
        nameText:SetText("")
        distanceText:SetText("")
        nameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        distanceText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        if nameText.SetJustification then nameText:SetJustification(1) end
        if nameText.SetRenderTransformPivot then nameText:SetRenderTransformPivot(g_vipserver_ESPV2(.5,.5)) end
        if distanceText.SetJustification then distanceText:SetJustification(1) end
        if distanceText.SetRenderTransformPivot then distanceText:SetRenderTransformPivot(g_vipserver_ESPV2(.5,.5)) end
    end)

    local theme=g_vipserver_ESPTheme(isBot)
    g_vipserver_ESPSetTextColor(nameText, theme.Text)
    g_vipserver_ESPSetTextColor(distanceText, theme.Text)
    g_vipserver_ESPSetFont(nameText, tonumber(_G.g_vipserver_VIPShotESP.NameFontSize) or 16, 0)
    -- Distance labels are intentionally borderless; the larger glyphs provide clarity.
    g_vipserver_ESPSetFont(distanceText, tonumber(_G.g_vipserver_VIPShotESP.DistanceFontSize) or 20, 0)
    local nameSlot, distanceSlot, mainSlot = nil, nil, nil
    pcall(function() nameSlot = container:AddChildToCanvas(nameText) end)
    pcall(function() distanceSlot = container:AddChildToCanvas(distanceText) end)
    if not nameSlot or not distanceSlot then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end
    pcall(function() mainSlot = canvas:AddChildToCanvas(container) end)
    if not mainSlot then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end

    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetAlignment(g_vipserver_ESPV2(0.0, 0.0))
        mainSlot:SetZOrder(65)
        nameSlot:SetAutoSize(true)
        nameSlot:SetAlignment(g_vipserver_ESPV2(0.5, 0.5))
        nameSlot:SetZOrder(1)
        distanceSlot:SetAutoSize(true)
        distanceSlot:SetAlignment(g_vipserver_ESPV2(0.5, 0.5))
        distanceSlot:SetZOrder(1)
    end)

    local data={
        Widget = container,
        Text = nameText,
        DistanceText = distanceText,
        TextSlot = nameSlot,
        DistanceSlot = distanceSlot,
        Slot = mainSlot,
        IsBot = isBot
    }
    return ESPWidgetPool.Tag(ESPWidgetPool.V2,"NameV2",canvas,data)
end

-- ESP enemy name and distance made by VIP Server
local function g_vipserver_ESPUpdateNameTag(key, character, headScreen, footScreen, isBot, distance, forceName, forceDistance)
    local showName = _G.g_vipserver_ESPOptions.Name == true
    local showDistance = _G.g_vipserver_ESPOptions.Distance == true
    if forceName~=nil then showName=forceName==true end
    if forceDistance~=nil then showDistance=forceDistance==true end
    local data = g_vipserver_ShotESP.Names[key]
    if not showName and not showDistance then
        if data and data.ContainerVisible~=false and g_vipserver_ESPValid(data.Widget) then pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) data.ContainerVisible=false end
        return
    end
    -- Fix: only cache non-empty resolved names; "" is truthy in Lua so never cache it
    local name = nil
    if showName then
        local cached = data and data.CachedName
        if type(cached) == "string" and #cached > 0 then
            name = cached
        else
            name = g_vipserver_ESPResolvePlayerName(character)
            if data and type(name) == "string" and #name > 0 then
                data.CachedName = name
            end
        end
        -- Fallback label for display only (not cached, so future frames retry)
        if not (type(name) == "string" and #name > 0) then
            name = isBot and "BOT" or "PLAYER"
        end
    else
        name = ""
    end
    if not headScreen then
        if data and g_vipserver_ESPValid(data.Widget) then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.ContainerVisible=false
        end
        return
    end

    if not data or not g_vipserver_ESPValid(data.Widget) then
        g_vipserver_ESPDestroyWidgetData(data)
        data = g_vipserver_ESPCreateNameTag(isBot)
        g_vipserver_ShotESP.Names[key] = data
        -- Only cache real resolved names on creation, not fallback labels
        if data and type(name)=="string" and #name>0 and name~="BOT" and name~="PLAYER" then
            data.CachedName = name
        end
    end
    if not data then return end
    if data.IsBot~=isBot then
        local theme=g_vipserver_ESPTheme(isBot)
        g_vipserver_ESPSetTextColor(data.Text,theme.Text)
        g_vipserver_ESPSetTextColor(data.DistanceText,theme.Text)
        data.IsBot=isBot
    end

    local dist = math.max(0, math.floor((tonumber(distance) or 0) + 0.5))
    local distanceLabel = string.format("%dm", dist)

    local bodyH=(footScreen and math.abs(footScreen.Y-headScreen.Y)) or 120.0
    local charCount=#name
    pcall(function() if utf8 and utf8.len then charCount=utf8.len(name) or charCount end end)
    -- Same compact, bottom-anchored geometry as ESPUpdateHeaderFrame.
    local w=math.max(68.0,math.min(232.0,bodyH*0.315))
    w=math.max(w,math.min(232.0,28.0+charCount*6.0))
    local hh=math.max(18.0,math.min(48.0,bodyH*0.070))
    local nameScale=math.max(0.80,math.min(1.18,math.min(bodyH/330.0,(w*0.80)/math.max(1.0,charCount*8.4))))
    local distanceScale=math.max(0.60,math.min(1.30,bodyH/200.0))
    local offscreenDistance = forceDistance==true and forceName==false
    if offscreenDistance then distanceScale=math.max(distanceScale,1.10) end

    -- Anchor the lower edge above the head; only the upper edge expands with scale.
    local cx = headScreen.X
    local headGap=math.max(4.0,math.min(10.0,bodyH*0.025))
    local bottomY=headScreen.Y-headGap
    local x = cx - w*0.5
    local y = bottomY-hh

    -- Distance text: at FEET position (CanvasPanel doesn't clip children outside bounds)
    local footY = footScreen and footScreen.Y or (headScreen.Y + bodyH)
    local distY = (footY - y) + bodyH*0.020   -- relative to container top-left, at feet level
    local distX = footScreen and (footScreen.X - x) or (w*0.5)

    local nameVisibilityChanged=data.ShowName~=showName
    local distanceVisibilityChanged=data.ShowDistance~=showDistance
    local layoutChanged=not data.LayoutX or math.abs(data.LayoutX-x)>=0.25 or math.abs(data.LayoutY-y)>=0.25 or
        math.abs((data.LayoutW or 0)-w)>=0.25 or math.abs((data.LayoutH or 0)-hh)>=0.25

    local applied = pcall(function()
        local shownName = showName and name or ""
        local shownDistance = showDistance and distanceLabel or ""
        if data.LastName ~= shownName then
            data.Text:SetText(shownName)
            data.LastName = shownName
        end
        if data.NameScale~=nameScale then data.Text:SetRenderScale(g_vipserver_ESPV2(nameScale,nameScale)) end
        if data.DistanceScale~=distanceScale then data.DistanceText:SetRenderScale(g_vipserver_ESPV2(distanceScale,distanceScale)) end
        if data.LastDistance ~= shownDistance then
            data.DistanceText:SetText(shownDistance)
            data.LastDistance = shownDistance
        end
        if nameVisibilityChanged then
            data.Text:SetWidgetVisibility(showName and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
        end
        if distanceVisibilityChanged then
            data.DistanceText:SetWidgetVisibility(showDistance and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
        end

        -- Move the container to match the header octagon exactly
        if layoutChanged then
            data.Slot:SetPosition(g_vipserver_ESPV2(x, y))
            data.Slot:SetSize(g_vipserver_ESPV2(w, hh))
        end

        -- Name text centered inside container (matches header box center)
        if data.LayoutW~=w or data.LayoutH~=hh then
            data.TextSlot:SetPosition(g_vipserver_ESPV2(w*0.5, hh*0.5))
        end

        -- Distance text below the header box
        local distChanged = not data.DistX or math.abs(data.DistX-distX)>=0.25 or math.abs((data.DistY or 0)-distY)>=0.25
        if distChanged then
            data.DistanceSlot:SetPosition(g_vipserver_ESPV2(distX, distY))
        end

        if data.ContainerVisible~=true then
            data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
    end)
    if not applied then return end
    data.ShowName,data.ShowDistance=showName,showDistance
    data.NameScale=nameScale
    data.DistanceScale=distanceScale
    data.LayoutX,data.LayoutY,data.LayoutW,data.LayoutH=x,y,w,hh
    data.DistX,data.DistY=distX,distY
    data.ContainerVisible=true
end

-- ESP enemy and bot counter HUD made by VIP Server
local function g_vipserver_ESPCreateCounter()
    local canvas = g_vipserver_ESPGetCanvas()
    if not g_vipserver_ESPValid(canvas) then return nil end
    local container=nil
    pcall(function() container=CGame:NewObjectFromPath("/Script/UMG.CanvasPanel",canvas) end)
    if not g_vipserver_ESPValid(container) then return nil end
    local currentV1=_G.LunarFeatures and _G.LunarFeatures.V1 and _G.LunarFeatures.V1.Counter
    local displayW=currentV1 and tonumber(currentV1.Width) or 218.4
    local displayH=currentV1 and tonumber(currentV1.Height) or 33.6
    local fontSize=currentV1 and tonumber(currentV1.FontSize) or 13
    local fontScale=currentV1 and tonumber(currentV1.FontScale) or 1.2
    local width,height,shieldH=294.0,44.0,52.0
    local sx,sy=displayW/width,displayH/shieldH
    local strokeScale=math.min(sx,sy)
    local half=width*0.5
    local pieces={}

    local function addRect(x,y,w,h,color,z)
        local widget=nil
        pcall(function() widget=CGame:NewObjectFromPath("/Script/UMG.Border",container) end)
        if not g_vipserver_ESPValid(widget) then return nil end
        local slot=nil
        pcall(function()
            widget:SetBrushColor(color)
            widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            slot=container:AddChildToCanvas(widget)
            slot:SetAutoSize(false)
            slot:SetPosition(g_vipserver_ESPV2(x*sx,y*sy))
            slot:SetSize(g_vipserver_ESPV2(math.max(1.0,w*sx),math.max(1.0,h*sy)))
            slot:SetZOrder(z or 1)
        end)
        if not slot then return nil end
        pieces[#pieces+1]={Widget=widget,Slot=slot}
        return pieces[#pieces]
    end

    local function addLine(x1,y1,x2,y2,thickness,color,z)
        local line=g_vipserver_ESPCreateLine(color,container)
        if not line then return nil end
        pcall(function() line.Slot:SetZOrder(z or 8) end)
        g_vipserver_ESPDrawLine(line,x1*sx,y1*sy,x2*sx,y2*sy,thickness*strokeScale)
        pieces[#pieces+1]=line
        return line
    end

    -- True trapezoid panels: horizontal scanlines keep every sloped edge clean.
    local panelSteps=16
    local bandH=height/panelSteps
    for i=1,panelSteps do
        local y=(i-1)*bandH
        local t=(i-0.5)/panelSteps
        local outerInset=2.0+t*18.0
        local innerInset=34.0-t*24.0
        local leftRight=half-innerInset
        local rightLeft=half+innerInset
        local red=g_vipserver_ESPScaleColor(ESP_COUNTER_RED_DARK,0.82+t*0.28,1.0)
        local blue=g_vipserver_ESPScaleColor(ESP_COUNTER_BLUE_DARK,0.92+t*0.42,1.0)
        addRect(outerInset,y,leftRight-outerInset,bandH+0.15,red,1)
        addRect(rightLeft,y,width-outerInset-rightLeft,bandH+0.15,blue,1)
    end

    -- Bright polygon outlines matching the reference silhouette.
    local lp={{2,1},{half-34,1},{half-20,height*0.66},{half-10,height},{20,height},{2,1}}
    local rp={{width-2,1},{half+34,1},{half+20,height*0.66},{half+10,height},{width-20,height},{width-2,1}}
    for i=1,#lp-1 do addLine(lp[i][1],lp[i][2],lp[i+1][1],lp[i+1][2],2.1,ESP_COUNTER_RED,7) end
    for i=1,#rp-1 do addLine(rp[i][1],rp[i][2],rp[i+1][1],rp[i+1][2],2.1,ESP_COUNTER_BLUE,7) end

    -- Independent downward center shield (not the legacy rotated diamond).
    local shieldSteps=18
    local shieldBand=shieldH/shieldSteps
    for i=1,shieldSteps do
        local y=(i-1)*shieldBand
        local t=(i-0.5)/shieldSteps
        local hw
        if t<0.68 then hw=34.0-t*17.0 else hw=22.5-(t-0.68)*39.0 end
        hw=math.max(9.0,hw)
        addRect(half-hw,y,hw*2.0,shieldBand+0.15,ESP_COUNTER_CENTER,5)
    end

    -- End chevrons and the white center accents/V.
    addLine(5,5,12,height-5,4.0,ESP_COUNTER_CENTER,9)
    addLine(12,5,19,height-5,4.0,ESP_COUNTER_RED,9)
    addLine(width-5,5,width-12,height-5,4.0,ESP_COUNTER_CENTER,9)
    addLine(width-12,5,width-19,height-5,4.0,ESP_COUNTER_BLUE,9)
    addLine(half-12,5,half-7,height*0.58,4.5,ESP_REAL_LIGHT,10)
    addLine(half+12,5,half+7,height*0.58,4.5,ESP_BOT_LIGHT,10)
    addLine(half-11,14,half,35,6.0,ESP_WHITE,11)
    addLine(half+11,14,half,35,6.0,ESP_WHITE,11)

    local function addText(initial,x,color)
        local text=nil
        pcall(function() text=CGame:NewObjectFromPath("/Script/UMG.TextBlock",container) end)
        if not g_vipserver_ESPValid(text) then return nil,nil end
        local slot=nil
        pcall(function()
            text:SetText(initial)
            text:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            if text.SetJustification then text:SetJustification(1) end
            slot=container:AddChildToCanvas(text)
            slot:SetAutoSize(true)
            slot:SetAlignment(g_vipserver_ESPV2(0.5,0.5))
            slot:SetPosition(g_vipserver_ESPV2(x*sx,displayH*0.5))
            slot:SetZOrder(12)
        end)
        g_vipserver_ESPSetTextColor(text,color)
        g_vipserver_ESPSetFont(text,fontSize,0)
        pcall(function()
            text:SetRenderTransformPivot(g_vipserver_ESPV2(0.5,0.5))
            text:SetRenderScale(g_vipserver_ESPV2(fontScale,fontScale))
        end)
        return text,slot
    end

    local realText=addText("REAL: 0",half*0.5,g_vipserver_ESPTheme(false).Text)
    local botText=addText("BOT: 0",half+half*0.5,g_vipserver_ESPTheme(true).Text)
    if not realText or not botText then
        g_vipserver_ESPDestroyWidgetData({Widget=container})
        return nil
    end

    local mainSlot=nil
    pcall(function() mainSlot=canvas:AddChildToCanvas(container) end)
    if not mainSlot then g_vipserver_ESPDestroyWidgetData({Widget=container}) return nil end

    local anchored=false
    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetSize(g_vipserver_ESPV2(displayW,displayH))
        mainSlot:SetZOrder(60)
        -- Viewport-independent top-center anchor: survives aspect ratio, DPI,
        -- notch and safe-zone variations without drifting toward a corner.
        if mainSlot.SetAnchors and Anchors then
            local anchors=nil
            pcall(function()
                anchors=Anchors(
                    g_vipserver_ESPV2(0.5,0.0),
                    g_vipserver_ESPV2(0.5,0.0)
                )
            end)
            if not anchors then pcall(function() anchors=Anchors() end) end
            if anchors then
                pcall(function() anchors.Minimum=g_vipserver_ESPV2(0.5,0.0) end)
                pcall(function() anchors.Maximum=g_vipserver_ESPV2(0.5,0.0) end)
                mainSlot:SetAnchors(anchors)
                mainSlot:SetAlignment(g_vipserver_ESPV2(0.5,0.0))
                anchored=true
            end
        end
    end)

    return {Widget=container,Slot=mainSlot,RealText=realText,BotText=botText,
        Width=displayW,Height=displayH,FontSize=fontSize,FontScale=fontScale,DiamondSize=0,Pieces=pieces,ViewportAnchored=anchored}
end

-- ESP counter position and tracer origin made by VIP Server
local function g_vipserver_ESPUpdateCounter(realCount, botCount, pc)

    local data = g_vipserver_ShotESP.Counter
    if not data or not g_vipserver_ESPValid(data.Widget) then
        -- The static counter is built atomically; the budget applies to enemy
        -- line groups that would otherwise all spawn together.
        local budget = g_vipserver_ShotESP.BuildRemaining
        g_vipserver_ShotESP.BuildRemaining = nil
        data = g_vipserver_ESPCreateCounter()
        g_vipserver_ShotESP.BuildRemaining = budget
        g_vipserver_ShotESP.Counter = data
    end
    if not data then return nil end

    local cw = g_vipserver_ShotESP.ViewportW
    local centerX = nil

    if tonumber(cw) and cw > 1 then
        centerX = cw * 0.5
    else

        local vw = g_vipserver_ESPViewport(pc)
        centerX =
            (vw * 0.5) * (g_vipserver_ShotESP.CanvasScaleX or 1.0)
            + (g_vipserver_ShotESP.CanvasOffsetX or 0.0)
    end

    if not centerX then return nil end

    local counterY = tonumber(_G.g_vipserver_VIPShotESP.CounterY) or 36.0

    if data.LastReal ~= realCount then
        local ok=pcall(function() data.RealText:SetText(string.format("REAL: %d", realCount or 0)) end)
        if ok then data.LastReal = realCount end
    end
    if data.LastBot ~= botCount then
        local ok=pcall(function() data.BotText:SetText(string.format("BOT: %d", botCount or 0)) end)
        if ok then data.LastBot = botCount end
    end

    local positionChanged = data.CenterX ~= centerX or data.CounterY ~= counterY
    local visibleChanged = data.Visible ~= true
    local applied = pcall(function()
        if positionChanged and data.ViewportAnchored then
            data.Slot:SetPosition(g_vipserver_ESPV2(0.0,counterY))
        elseif positionChanged then
            data.Slot:SetAlignment(g_vipserver_ESPV2(0.0,0.0))
            data.Slot:SetPosition(g_vipserver_ESPV2(centerX-data.Width*0.5,counterY))
        end
        if visibleChanged then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
    end)
    if applied then data.CenterX,data.CounterY,data.Visible = centerX,counterY,true end

    local diamondSize = tonumber(data.DiamondSize) or 20.0
    local anchorX = centerX
    local anchorY = counterY + (data.Height * 0.5) + (diamondSize / math.sqrt(2.0))

    data.AnchorX = anchorX
    data.AnchorY = anchorY

    g_vipserver_ShotESP.TracerOrigin = g_vipserver_ESPV2(anchorX, anchorY)
    return g_vipserver_ShotESP.TracerOrigin
end

-- ESP enemy scan made by VIP Server
local function g_vipserver_ESPScanEnemies()
    local pc = g_vipserver_ESPGetController()
    local me = g_vipserver_ESPGetLocalCharacter()
    if not pc or not me then g_vipserver_ShotESP.Enemies = {} return nil, 0, 0 end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    if not myLoc then g_vipserver_ShotESP.Enemies = {} return pc, 0, 0 end
    local myTeam = g_vipserver_ESPGetTeamID(me)

    local list = {}
    local realCount, botCount = 0, 0
    local pawns=ESPShared.GetFramePawns()
    pawns = pawns or _G.g_vipserver_TrackedCharacters
    if pawns then
        for _, character in pairs(pawns) do
            if character~=me and ESPShared.GetFrameRecord(character).Alive and ESPShared.Events.Counted(character) then
                local team = g_vipserver_ESPGetTeamID(character)
                -- Fix: only skip as same-team when both IDs are non-zero and equal
                local sameTeam = false
                if myTeam ~= nil and team ~= nil then
                    local tNum, mNum = tonumber(team), tonumber(myTeam)
                    sameTeam = tNum and mNum and tNum > 0 and mNum > 0 and tNum == mNum
                end
                if not sameTeam then
                    local loc = ESPShared.GetFrameRecord(character).Location
                    local dist = ESPShared.DistanceMetersFrom(ESPShared.GetFrameRecord(character),myLoc)
                    if dist <= (tonumber(_G.g_vipserver_VIPShotESP.MaxRangeMeters) or 400.0) then
                        local key = g_vipserver_ESPGetPlayerKey(character)
                        local isBot = g_vipserver_ESPIsBot(character,key)
                        if isBot then botCount = botCount + 1 else realCount = realCount + 1 end
                        list[#list+1] = {Character=character, Key=key, IsBot=isBot, Distance=dist}
                    end
                end
            end
        end
    end
    table.sort(list, function(a,b)
        if a.Distance == b.Distance then return a.Key < b.Key end
        return (a.Distance or 99999) < (b.Distance or 99999)
    end)
    g_vipserver_ShotESP.Enemies = list
    return pc, realCount, botCount
end

-- ESP stale widget cleanup made by VIP Server
local function g_vipserver_ESPPrune(active,alive)
    -- Visual caches follow the displayed set. Counting metadata follows alive.
    -- Move header children into their actor-free parent bundle before pruning
    -- either registry; no detached child can follow a different enemy.
    for key,root in pairs(g_vipserver_ShotESP.HeaderRoots) do
        if not active[key] and root.PoolOwner and root.Groups then
            root.Groups.__Header=g_vipserver_ShotESP.Headers[key]
            g_vipserver_ShotESP.Headers[key]=nil
        end
    end
    for _,registry in ipairs({g_vipserver_ShotESP.Lines,g_vipserver_ShotESP.Names,
        g_vipserver_ShotESP.Decorations,g_vipserver_ShotESP.HeaderRoots}) do
        for key,data in pairs(registry) do
            if not active[key] then g_vipserver_ESPDestroyWidgetData(data);registry[key]=nil end
        end
    end
    for _,registry in ipairs({g_vipserver_ShotESP.Boxes,g_vipserver_ShotESP.HealthBars,
        g_vipserver_ShotESP.Skeletons,g_vipserver_ShotESP.Headers,g_vipserver_ShotESP.Footers}) do
        for key,group in pairs(registry) do
            if not active[key] then g_vipserver_ESPDestroyGroup(group);registry[key]=nil end
        end
    end
    for _,registry in ipairs({g_vipserver_ShotESP.BuildStage,g_vipserver_ShotESP.BoneNameCache,
        g_vipserver_ShotESP.BoneMeshes,g_vipserver_ShotESP.BonePoints}) do
        for key in pairs(registry) do if not active[key] then registry[key]=nil end end
    end
    for key in pairs(g_vipserver_ShotESP._BotCache) do if not alive[key] then g_vipserver_ShotESP._BotCache[key]=nil end end
end

ESPShared.Events.Clearers[#ESPShared.Events.Clearers+1]=function(actor)
    ESPShared.Events.ClearIn(g_vipserver_ShotESP,g_vipserver_ESPPrune,actor)
end

-- ESP main HUD update made by VIP Server
local function g_vipserver_ESPUpdate()
    local opt = _G.g_vipserver_ESPOptions
    local anyEnabled = opt and (opt.Name or opt.Line or opt.Box or opt.Health or opt.Distance or opt.Skeleton or opt.Counter)
    if not (_G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized) or not _G.g_vipserver_VIPShotESP.Enabled or not anyEnabled then
        if not g_vipserver_ShotESP.Disabled then g_vipserver_ESPResetWidgets() end
        g_vipserver_ShotESP.Disabled = true
        return
    end
    g_vipserver_ShotESP.Disabled = false
    local buildBudget = tonumber(_G.g_vipserver_VIPShotESP.WidgetBuildBudget) or 96
    if buildBudget ~= buildBudget or buildBudget == math.huge then buildBudget = 96 end
    g_vipserver_ShotESP.BuildRemaining = math.max(1, math.floor(buildBudget))

    local world = g_vipserver_ESPWorld()
    ESPShared.Events.WorldChanged(world)
    if world ~= g_vipserver_ShotESP.LastWorld then
        g_vipserver_ESPResetWidgets()
        g_vipserver_ShotESP.LastWorld = world
        g_vipserver_ShotESP.LastScanClock = -999.0
        g_vipserver_ShotESP.LastTransformClock = -999.0
        g_vipserver_ShotESP.TracerOrigin = nil
    end

    if g_vipserver_ShotESP.Canvas and not g_vipserver_ESPValid(g_vipserver_ShotESP.Canvas) then
        g_vipserver_ESPResetWidgets()
    end
    local canvas = g_vipserver_ESPGetCanvas()
    if not canvas then return end
    local now = g_vipserver_ESPNow()
    g_vipserver_ShotESP.Now = now
    if now < g_vipserver_ShotESP.LastScanClock then
        g_vipserver_ShotESP.LastScanClock = -999.0
        g_vipserver_ShotESP.LastTransformClock = -999.0
    end
    local pc = g_vipserver_ESPGetController()
    local me = g_vipserver_ESPGetLocalCharacter()
    if pc ~= g_vipserver_ShotESP.LastController or me ~= g_vipserver_ShotESP.LastPawn then
        g_vipserver_ESPResetWidgets()
        g_vipserver_ShotESP.LastController, g_vipserver_ShotESP.LastPawn = pc,me
        canvas = g_vipserver_ESPGetCanvas()
        if not canvas then return end
    end
    if not pc or not me then return end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    local realCount, botCount = nil, nil
    if (now - g_vipserver_ShotESP.LastScanClock) >= (tonumber(_G.g_vipserver_VIPShotESP.ScanInterval) or 0.30) then
        pc, realCount, botCount = g_vipserver_ESPScanEnemies()
        g_vipserver_ShotESP.LastScanClock = now
        g_vipserver_ShotESP.RealCount, g_vipserver_ShotESP.BotCount = realCount, botCount
    end
    pc = pc or g_vipserver_ESPGetController()
    if not pc then return end

    if (now - (g_vipserver_ShotESP.LastTransformClock or -999.0))
        >= (tonumber(_G.g_vipserver_VIPShotESP.TransformInterval) or 0.50) then
        g_vipserver_ESPUpdateCanvasTransform(pc)
        local cw,ch=g_vipserver_ESPGetCanvasLocalSize()
        if cw and ch then g_vipserver_ShotESP.ViewportW,g_vipserver_ShotESP.ViewportH=cw,ch end
        local rw,rh=g_vipserver_ESPViewport(pc)
        g_vipserver_ShotESP.RawViewportW,g_vipserver_ShotESP.RawViewportH=rw,rh
        g_vipserver_ShotESP.LastTransformClock = now
    end

    local rawW,rawH=ESPShared.ViewSize(pc)
    -- The tracer uses the physical viewport midpoint in canvas coordinates.
    local canvasScaleX=ESPShared.SafeNumber(g_vipserver_ShotESP.CanvasScaleX,1.0,0.00001,100)
    local canvasScaleY=ESPShared.SafeNumber(g_vipserver_ShotESP.CanvasScaleY,1.0,0.00001,100)
    local canvasOffsetX=ESPShared.SafeNumber(g_vipserver_ShotESP.CanvasOffsetX,0.0,-1e7,1e7)
    local canvasOffsetY=ESPShared.SafeNumber(g_vipserver_ShotESP.CanvasOffsetY,0.0,-1e7,1e7)
    local originCenter = g_vipserver_ESPV2(
        (rawW*0.5)*canvasScaleX+canvasOffsetX,
        4.0*canvasScaleY+canvasOffsetY
    )
    local active,alive=g_vipserver_ShotESP.Active,g_vipserver_ShotESP.Alive
    g_vipserver_ShotESP.RealCount,g_vipserver_ShotESP.BotCount=g_vipserver_ESPFilterEnemies(
        g_vipserver_ShotESP.Enemies,myLoc,_G.g_vipserver_VIPShotESP.MaxRangeMeters,alive)
    if opt.Counter then
        g_vipserver_ESPUpdateCounter(
            g_vipserver_ShotESP.RealCount or 0,
            g_vipserver_ShotESP.BotCount or 0,
            pc
        )
    elseif g_vipserver_ShotESP.Counter then
        g_vipserver_ESPHide(g_vipserver_ShotESP.Counter)
    end

    -- Counter-only mode stops here after validating cached scan candidates, avoiding
    -- projection, skeleton, box and per-enemy widget work entirely.
    local detailedEnabled=opt.Name or opt.Line or opt.Box or opt.Health or opt.Distance or opt.Skeleton
    if not detailedEnabled then
        for key in pairs(active) do active[key]=nil end
        g_vipserver_ESPPrune(active,alive)
        return
    end

    for key in pairs(active) do active[key]=nil end
    local configuredMax=math.floor(ESPShared.SafeNumber(_G.g_vipserver_VIPShotESP.MaxRendered,8,1,64))
    local maxRendered = configuredMax
    local renderedCount=0
    -- Keep the nearest-candidate budget; counting still validates every actor.
    for index,item in ipairs(g_vipserver_ShotESP.Enemies) do
        if index>maxRendered then break end
        local c,key=item.Character,item.Key
        local headScreen,footScreen,onScreen=ESPShared.Events.Project(pc,c,g_vipserver_ShotESP)
        if onScreen then
            if renderedCount<maxRendered then
                renderedCount=renderedCount+1
                active[key] = true
                local buildStage=g_vipserver_ShotESP.BuildStage[key] or 1
                local color = item.IsBot and ESP_BOT or ESP_REAL
                local line = g_vipserver_ShotESP.Lines[key]

                local colorKey = item.IsBot and "BOT" or "REAL"
                if opt.Line and (not line or not g_vipserver_ESPValid(line.Widget)) then
                    g_vipserver_ESPDestroyWidgetData(line)
                    line = g_vipserver_ESPCreateLine(color)
                    if line then line.ColorKey = colorKey end
                    g_vipserver_ShotESP.Lines[key] = line
                elseif opt.Line and line and line.ColorKey ~= colorKey then
                    pcall(function() line.Widget:SetBrushColor(color) end)
                    line.ColorKey = colorKey
                end

                if opt.Line and line then
                    local tracerTarget = headScreen or footScreen
                    if tracerTarget then
                        g_vipserver_ESPDrawLine(
                            line,
                            originCenter.X, originCenter.Y,
                            tracerTarget.X, tracerTarget.Y,
                            tonumber(_G.g_vipserver_VIPShotESP.TracerThickness) or 1.80
                        )
                    end
                elseif line then g_vipserver_ESPHide(line) end

                g_vipserver_ESPUpdateDecoration(key,c,headScreen,footScreen,opt,buildStage,item.IsBot)
                g_vipserver_ESPUpdateNameTag(key,c,headScreen,footScreen,item.IsBot,item.Distance)
                -- Header frame: dynamic per-frame update (fills, corner fills, scale with name)
                g_vipserver_ESPUpdateHeaderFrame(key,headScreen,footScreen,opt.Name==true,item.IsBot)

                -- All visible skeletons refresh with the current camera; no round-robin delay.
                g_vipserver_ESPUpdateSkeleton(key, c, pc, opt.Skeleton == true, item.IsBot)
                g_vipserver_ShotESP.BuildStage[key]=math.min(5,buildStage+1)

            end
        end
    end
    g_vipserver_ESPPrune(active,alive)
end

-- One pending render chain. Menu refreshes invalidate/wake it rather than
-- drawing synchronously multiple times in the same frame.
local g_vipserver_ESPRunnerToken={}
if type(_G.__VIPShotESPCleanup) == "function" then pcall(_G.__VIPShotESPCleanup) end
_G.__VIPShotESPRunner=g_vipserver_ESPRunnerToken
_G.__VIPShotESPCleanup=g_vipserver_ESPResetWidgets
local g_vipserver_ESPDiagnostics={Updates=0,Errors=0,LastError=nil}
_G.g_vipserver_ESPDiagnostics=g_vipserver_ESPDiagnostics
local g_vipserver_ESPTicker=nil
pcall(function() g_vipserver_ESPTicker=require("common.time_ticker") end)
local g_vipserver_ESPTick
local function g_vipserver_ESPSchedule(delay)
    delay=ESPShared.SafeNumber(delay,0.50,0.001,0.50)
    if _G.__VIPShotESPRunner~=g_vipserver_ESPRunnerToken then return end
    if not g_vipserver_ESPTicker or not g_vipserver_ESPTicker.AddTimerOnce then
        g_vipserver_ESPDiagnostics.LastError="common.time_ticker.AddTimerOnce unavailable"
        return
    end
    local serial=(g_vipserver_ESPRunnerToken.Serial or 0)+1
    g_vipserver_ESPRunnerToken.Serial=serial
    g_vipserver_ESPRunnerToken.Due=g_vipserver_ESPNow()+delay
    local ok, err=pcall(g_vipserver_ESPTicker.AddTimerOnce,delay,function()
        if _G.__VIPShotESPRunner~=g_vipserver_ESPRunnerToken
            or g_vipserver_ESPRunnerToken.Serial~=serial then return end
        g_vipserver_ESPRunnerToken.Due=nil
        g_vipserver_ShotESP.TimerClock=g_vipserver_ShotESP.TimerClock+delay
        g_vipserver_ESPTick()
    end)
    if not ok or err==false then
        g_vipserver_ESPRunnerToken.Due=nil
        g_vipserver_ESPDiagnostics.Errors=g_vipserver_ESPDiagnostics.Errors+1
        g_vipserver_ESPDiagnostics.LastError=tostring(err)
    end
end
g_vipserver_ESPTick=function()
    local token=g_vipserver_ESPRunnerToken
    if _G.__VIPShotESPRunner~=token then return end
    local now=g_vipserver_ESPNow()
    local profiling=_G.g_vipserver_VIPShotESP.Profile and os and type(os.clock)=="function"
    local callbackStarted=profiling and os.clock() or nil
    ESPShared.Frame.Begin(now)
    local F=_G.LunarFeatures
    if F then F.TimerClock=g_vipserver_ShotESP.TimerClock end
    if not token.RenderDue or now>=token.RenderDue-0.000001 or (token.LastRenderClock and now<token.LastRenderClock) then
        local previous=g_vipserver_ESPDiagnostics.LastTickSeconds
        if previous and now>previous then g_vipserver_ESPDiagnostics.UpdateHz=1/(now-previous) end
        g_vipserver_ESPDiagnostics.LastTickSeconds=now
        local started=profiling and os.clock() or nil
        local ok,err=pcall(g_vipserver_ESPUpdate)
        g_vipserver_ESPDiagnostics.LastUpdateOK=ok
        g_vipserver_ESPDiagnostics.Updates=g_vipserver_ESPDiagnostics.Updates+1
        if not ok then
            g_vipserver_ESPDiagnostics.Errors=g_vipserver_ESPDiagnostics.Errors+1
            g_vipserver_ESPDiagnostics.LastError=tostring(err)
        end
        if started then
            local elapsed=os.clock()-started
            g_vipserver_ESPDiagnostics.LastUpdateCPUSeconds=elapsed
            g_vipserver_ESPDiagnostics.MaxUpdateCPUSeconds=math.max(elapsed,g_vipserver_ESPDiagnostics.MaxUpdateCPUSeconds or 0)
        end
        local o=_G.g_vipserver_ESPOptions or {}
        local enabled=_G.g_vipserver_VIPShotESP.Enabled and _G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized
        local detailed=enabled and (o.Name or o.Line or o.Box or o.Health or o.Distance or o.Skeleton)
        local interval=tonumber(_G.g_vipserver_VIPShotESP.UpdateInterval) or 1/60
        if not detailed then interval=enabled and o.Counter and math.max(0.05,tonumber(_G.g_vipserver_VIPShotESP.ScanInterval) or 0.35) or 0.50 end
        if interval~=interval or math.abs(interval)==math.huge or interval<=0 then interval=1/60 end
        token.LastRenderClock=now
        token.RenderDue=now+math.max(0.001,interval)
    end
    if profiling then g_vipserver_ESPDiagnostics.LastPumpCPUSeconds=0 end
    if F and F.Pump and not F.Token.Stopped then
        local pumpStarted=profiling and os.clock() or nil
        local ok,err=pcall(F.Pump,now)
        if not ok then F.Error("Scheduler",err) end
        if pumpStarted then
            local elapsed=os.clock()-pumpStarted
            g_vipserver_ESPDiagnostics.LastPumpCPUSeconds=elapsed
            g_vipserver_ESPDiagnostics.MaxPumpCPUSeconds=math.max(elapsed,g_vipserver_ESPDiagnostics.MaxPumpCPUSeconds or 0)
        end
    end
    ESPShared.Frame.Finish()
    local after=g_vipserver_ESPNow()
    local interval=math.max(0.001,token.RenderDue-after)
    if F and F.NextInterval and not F.Token.Stopped then interval=math.min(interval,F.NextInterval(after)) end
    g_vipserver_ESPSchedule(interval)
    if callbackStarted then
        local elapsed=os.clock()-callbackStarted
        g_vipserver_ESPDiagnostics.LastCallbackCPUSeconds=elapsed
        g_vipserver_ESPDiagnostics.MaxCallbackCPUSeconds=math.max(elapsed,g_vipserver_ESPDiagnostics.MaxCallbackCPUSeconds or 0)
        g_vipserver_ESPDiagnostics.TotalCallbackCPUSeconds=(g_vipserver_ESPDiagnostics.TotalCallbackCPUSeconds or 0)+elapsed
        g_vipserver_ESPDiagnostics.CallbackSamples=(g_vipserver_ESPDiagnostics.CallbackSamples or 0)+1
    end
end


_G.g_vipserver_VIPShotESPForceRefresh = function()
    if _G.__VIPShotESPRunner~=g_vipserver_ESPRunnerToken then return end
    g_vipserver_ESPRunnerToken.RenderDue=nil
    g_vipserver_ShotESP.LastScanClock = -999.0
    g_vipserver_ShotESP.LastTransformClock = -999.0
    local due=g_vipserver_ESPRunnerToken.Due
    if not due or due-g_vipserver_ESPNow()>0.002 then g_vipserver_ESPSchedule(0.001) end
end

-- Managed feature state. Source settings are data, never loaded as executable Lua.
do
    if type(_G.__LunarFeaturesCleanup) == "function" then pcall(_G.__LunarFeaturesCleanup) end
    local F = {Token={}, Diagnostics={Errors=0}, TimerClock=0, LastWorld=nil}
    _G.LunarFeatures=F
    local settings = _G.LunarFeatureSettings or {}
    _G.LunarFeatureSettings=settings
    F.Settings=settings
    local function number(value,lo,hi,fallback)
        local v=tonumber(value)
        if not v or v~=v or v==math.huge or v==-math.huge then v=fallback end
        return math.floor(math.max(lo,math.min(hi,v))+0.5)
    end
    F.Clamp=number
    settings.IpadFOV=number(settings.IpadFOV or _G.LexusState.CustomTextData.IpadViewFOV,90,120,120)
    settings.AimSpeed=number(settings.AimSpeed,100,120,100)
    settings.AimTarget=number(settings.AimTarget,1,3,1)
    settings.AimEnabled=settings.AimEnabled==true
    settings.WallEnabled=settings.WallEnabled==true
    settings.WallSafeMode=settings.WallSafeMode~=false
    settings.WallVisible=number(settings.WallVisible,1,7,1)
    settings.WallOccluded=number(settings.WallOccluded,1,7,2)
    settings.Aim2Enabled=settings.Aim2Enabled==true
    settings.MortarEnabled=settings.MortarEnabled==true
    -- V9.3 additions: fine-grained Aimbot V1 and ESP controls.
    settings.AimFOV=number(settings.AimFOV,10,100,30)
    settings.AimDist=number(settings.AimDist,50,400,120)
    settings.KickControl=settings.KickControl==true
    settings.KickAmount=number(settings.KickAmount,0,100,100)
    settings.AimVisCheck=settings.AimVisCheck~=false
    settings.AimIgKnock=settings.AimIgKnock~=false
    settings.AimIgBot=settings.AimIgBot==true
    settings.EspRange=number(settings.EspRange,400,1000,1000)
    settings.EspMaxTargets=number(settings.EspMaxTargets,5,64,50)
    -- V9.4: idle aim modes that work without firing.
    settings.AimSniperScope=settings.AimSniperScope==true
    settings.AimShotgun=settings.AimShotgun==true
    _G.g_Botmater_ESPOptions=_G.g_Botmater_ESPOptions or {}
    for _,key in ipairs({"Name","Line","Health","Distance","EnemyCounter"}) do
        if _G.g_Botmater_ESPOptions[key]==nil then _G.g_Botmater_ESPOptions[key]=false end
    end
    local paths=g_vipserver_ESPSettingsPaths()
    for i,path in ipairs(paths) do paths[i]=path:gsub("VIP_SERVER_UMG_ESP_settings.lua$","VIP_SERVER_FEATURES_V3_settings.lua") end
    if io and io.open then
        for _,path in ipairs(paths) do
            local ok,file=pcall(io.open,path,"r")
            if ok and file then
                local readOK,payload=pcall(function() return file:read("*a") end)
                pcall(function() file:close() end)
                if readOK and type(payload)=="string" then
                    F.SettingsReadPath=path
                    for _,key in ipairs({"AimEnabled","WallEnabled","IpadEnabled","Aim2Enabled","MortarEnabled"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then
                            if key=="IpadEnabled" then _G.MWConfig.IpadView=val=="true" else settings[key]=val=="true" end
                        end
                    end
                    for _,key in ipairs({"IpadFOV","AimSpeed","AimTarget"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*([%d%.%-]+)")
                        if val then settings[key]=number(val,key=="IpadFOV" and 90 or (key=="AimSpeed" and 100 or 1),key=="AimTarget" and 3 or 120,settings[key]) end
                    end
                    for _,key in ipairs({"WallVisible","WallOccluded"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*([%d%.%-]+)")
                        if val then settings[key]=number(val,1,7,settings[key]) end
                    end
                    for _,key in ipairs({"AimFOV","AimDist","EspRange","EspMaxTargets"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*([%d%.%-]+)")
                        if val then
                            local lo=(key=="AimFOV" and 10) or (key=="AimDist" and 50) or (key=="EspMaxTargets" and 5) or 400
                            local hi=(key=="AimFOV" and 100) or (key=="AimDist" and 400) or (key=="EspMaxTargets" and 64) or 1000
                            settings[key]=number(val,lo,hi,settings[key])
                        end
                    end
                    for _,key in ipairs({"KickAmount"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*([%d%.%-]+)")
                        if val then settings[key]=number(val,0,100,settings[key]) end
                    end
                    for _,key in ipairs({"AimVisCheck","AimIgKnock","AimIgBot"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then settings[key]=val=="true" end
                    end
                    for _,key in ipairs({"AimSniperScope","AimShotgun","WallSafeMode","KickControl"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then settings[key]=val=="true" end
                    end
                    for _,key in ipairs({"Name","Line","Health","Distance","EnemyCounter"}) do
                        local val=payload:match("%f[%w_]V1_"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then _G.g_Botmater_ESPOptions[key]=val=="true" end
                    end
                    for _,key in ipairs({"Name","Line","Box","Health","Distance","Skeleton","Counter"}) do
                        local val=payload:match("%f[%w_]V2_"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then _G.g_vipserver_ESPOptions[key]=val=="true" end
                    end
                    break
                end
            end
        end
    end
    if not F.SettingsReadPath and g_vipserver_ESPLoadedSettingsPath then
        F.SettingsReadPath=g_vipserver_ESPLoadedSettingsPath:gsub("VIP_SERVER_UMG_ESP_settings%.lua$","VIP_SERVER_FEATURES_V3_settings.lua")
    end
    if settings.Aim2Enabled then settings.AimEnabled=false end
    if _G.g_vipserver_VIPShotESP then
        _G.g_vipserver_VIPShotESP.MaxRangeMeters=settings.EspRange
        _G.g_vipserver_VIPShotESP.MaxRendered=settings.EspMaxTargets
    end
    _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
    F.Now=function()
        local now=nil
        pcall(function()
            local world=g_vipserver_ESPWorld()
            if world and GameplayStaticsESP and GameplayStaticsESP.GetRealTimeSeconds then now=GameplayStaticsESP.GetRealTimeSeconds(world) end
        end)
        return tonumber(now) or F.TimerClock
    end
    F.Save=function(force)
        if not F.Dirty or not io or not io.open then return end
        local lines={"return {", "  IpadEnabled = "..tostring(_G.MWConfig.IpadView==true)..","}
        for _,key in ipairs({"AimEnabled","WallEnabled","Aim2Enabled","MortarEnabled","IpadFOV","AimSpeed","AimTarget","WallVisible","WallOccluded","AimFOV","AimDist","EspRange","EspMaxTargets","KickAmount"}) do lines[#lines+1]="  "..key.." = "..tostring(settings[key]).."," end
        for _,key in ipairs({"AimVisCheck","AimIgKnock","AimIgBot","AimSniperScope","AimShotgun","WallSafeMode","KickControl"}) do lines[#lines+1]="  "..key.." = "..tostring(settings[key]==true).."," end
        for _,key in ipairs({"Name","Line","Health","Distance","EnemyCounter"}) do lines[#lines+1]="  V1_"..key.." = "..tostring(_G.g_Botmater_ESPOptions[key]==true).."," end
        for _,key in ipairs({"Name","Line","Box","Health","Distance","Skeleton","Counter"}) do lines[#lines+1]="  V2_"..key.." = "..tostring(_G.g_vipserver_ESPOptions[key]==true).."," end
        lines[#lines+1]="}"
        local payload=table.concat(lines,"\n")
        local savePaths=F.SettingsReadPath and {F.SettingsReadPath} or paths
        for _,path in ipairs(savePaths) do
            local wrote,reason,atomic=g_vipserver_ESPWriteSettings(path,payload)
            if wrote then
                F.SettingsReadPath=path;F.Dirty=false;F.Diagnostics.LastSaveOK=true;F.Diagnostics.LastSavePath=path;F.Diagnostics.AtomicSave=atomic
                return true
            end
            F.Diagnostics.LastSaveError=reason
        end
        F.Diagnostics.LastSaveOK=false
        return false
    end
    F.MarkDirty=function(immediate) F.Dirty=true;if immediate then F.Save(true) end end
    F.SetIpad=function(enabled)
        _G.MWConfig.IpadView=enabled==true or enabled==1
        _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
        pcall(g_vipserver_ApplyiPadView)
        F.MarkDirty(true)
    end
    F.SetIpadFOV=function(value)
        settings.IpadFOV=number(value,90,120,120)
        _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
        pcall(g_vipserver_ApplyiPadView)
        F.MarkDirty()
    end
    -- V9.9: ek hi jagah se saare aim knobs likhte hain. Manual ON ho to
    -- per-mode (hip/ADS/sniper/shotgun) values, warna global Aim FOV/Speed/Dist.
    -- Kick control: weapon ke shoot component par recoil fields ko dabata hai.
    F.SetKickControl=function(enabled)
        settings.KickControl=(enabled==true or enabled==1)
        if not settings.KickControl and _G.LunarKick then pcall(_G.LunarKick.Stop) end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
        return true
    end
    F.SetKickAmount=function(value)
        settings.KickAmount=number(value,0,100,100)
        F.MarkDirty(true)
        return true
    end
    F.SetAimSpeed=function(value)
        local previousSpeed=settings.AimSpeed
        settings.AimSpeed=number(value,100,120,100)
        if settings.AimSpeed~=previousSpeed then
            F.AimLastClock=nil;F.AimDue=0
            if _G.XthrlenState then _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0 end
        end
        F.MarkDirty()
    end
    F.SetAimTarget=function(value) settings.AimTarget=number(value,1,3,1);F.MarkDirty(true) end
    -- V9.3: Aimbot V1 tuning. Every write lands on knobs the aim loop already
    -- reads (AimTouchHip*/Scope*/Sniper*), so a change is effective next frame.
    local function aimTouchField(suffix,value)
        local data=_G.XthrlenState and _G.XthrlenState.CustomTextData
        if not data then return end
        data["AimTouchHip"..suffix]=value
        data["AimTouchScope"..suffix]=value
        data["AimTouchSniper"..suffix]=value
    end
    F.SetAimFOV=function(value)
        settings.AimFOV=number(value,10,100,30)
        F.AimLastClock=nil;F.AimDue=0
        F.MarkDirty(true)
    end
    F.SetAimDist=function(value)
        settings.AimDist=number(value,50,400,120)
        F.AimLastClock=nil;F.AimDue=0
        F.MarkDirty(true)
    end
    F.SetAimVisCheck=function(enabled)
        settings.AimVisCheck=enabled==true or enabled==1
        local cfg=_G.XthrlenConfig
        if cfg then
            cfg.AimTouchHipVisCheck=settings.AimVisCheck
            cfg.AimTouchScopeVisCheck=settings.AimVisCheck
            cfg.AimTouchSniperVisCheck=settings.AimVisCheck
        end
        F.MarkDirty(true)
    end
    F.SetAimIgKnock=function(enabled)
        settings.AimIgKnock=enabled==true or enabled==1
        local cfg=_G.XthrlenConfig
        if cfg then
            cfg.AimTouchHipIgKnock=settings.AimIgKnock
            cfg.AimTouchScopeIgKnock=settings.AimIgKnock
            cfg.AimTouchSniperIgKnock=settings.AimIgKnock
        end
        F.MarkDirty(true)
    end
    F.SetAimIgBot=function(enabled)
        settings.AimIgBot=enabled==true or enabled==1
        local cfg=_G.XthrlenConfig
        if cfg then
            cfg.AimTouchHipIgBot=settings.AimIgBot
            cfg.AimTouchScopeIgBot=settings.AimIgBot
            cfg.AimTouchSniperIgBot=settings.AimIgBot
        end
        F.MarkDirty(true)
    end
    F.SetEspRange=function(value)
        settings.EspRange=number(value,400,1000,1000)
        if _G.g_vipserver_VIPShotESP then
            _G.g_vipserver_VIPShotESP.MaxRangeMeters=settings.EspRange
        end
        if _G.g_Botmater_VIPShotESP then
            _G.g_Botmater_VIPShotESP.MaxRangeMeters=settings.EspRange
        end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
    end
    F.SetEspMaxTargets=function(value)
        settings.EspMaxTargets=number(value,5,64,50)
        if _G.g_vipserver_VIPShotESP then
            _G.g_vipserver_VIPShotESP.MaxRendered=settings.EspMaxTargets
        end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
    end
    -- V9.4 idle aim modes. Both work while the weapon is NOT firing.
    F.SetAimSniperScope=function(enabled)
        settings.AimSniperScope=enabled==true or enabled==1
        local cfg=_G.XthrlenConfig
        if cfg then cfg.AimTouchScopeSniper=settings.AimSniperScope end
        local data=_G.XthrlenState and _G.XthrlenState.CustomTextData
        if data then
            -- cond 2 = aim allowed without firing; keep the scope on the head.
            data.AimTouchSniperCond=2
        end
        F.AimLastClock=nil;F.AimDue=0
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
    end
    F.SetAimShotgun=function(enabled)
        settings.AimShotgun=enabled==true or enabled==1
        local cfg=_G.XthrlenConfig
        if cfg then cfg.AimTouchSG=settings.AimShotgun end
        local data=_G.XthrlenState and _G.XthrlenState.CustomTextData
        if data then
            data.AimTouchSGCond=2
        end
        F.AimLastClock=nil;F.AimDue=0
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
    end
    -- ItemBase supports caller-owned event keys. Both native switches subscribe
    -- through its normal lifecycle; there are no saved widget references.
    F.AimSettingsEventType=-14050701
    F.AimSettingsEventID=1
    F.SetAimMode=function(value)
        local mode=F.Clamp(value,0,2,0)
        local changed=settings.AimEnabled~=(mode==1) or settings.Aim2Enabled~=(mode==2)
        settings.AimEnabled=mode==1
        settings.Aim2Enabled=mode==2
        _G.XthrlenConfig.AimTouchEnable=settings.AimEnabled
        if not settings.AimEnabled then
            _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0;F.AimLastClock=nil
        end
        if not settings.Aim2Enabled and F.Aim2 then F.Aim2.Stop() end
        if F.Aim2 then F.Aim2.Due=0 end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
        if changed and EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,F.AimSettingsEventType,F.AimSettingsEventID)
            if not ok then F.Error("Aim.SettingsRefresh",err) end
        end
    end
    F.SetAim=function(enabled)
        local on=enabled==true or enabled==1
        F.SetAimMode(on and 1 or (settings.Aim2Enabled and 2 or 0))
    end
    F.SetAim2=function(enabled)
        local on=enabled==true or enabled==1
        F.SetAimMode(on and 2 or (settings.AimEnabled and 1 or 0))
    end
    F.SetMortar=function(enabled)
        settings.MortarEnabled=enabled==true or enabled==1
        if not settings.MortarEnabled and F.Mortar then F.Mortar.Stop() end
        if F.Mortar then F.Mortar.Due=0 end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
    end

    F.RefreshWallSettings=function()
        if EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,-14050701,3)
            if not ok then F.Error("Wall.SettingsRefresh",err) end
        end
    end
    F.SetWall=function(enabled)
        local changed=settings.WallEnabled~=(enabled==true or enabled==1)
        settings.WallEnabled=enabled==true or enabled==1
        if not settings.WallEnabled and F.Wall then F.Wall.Stop() end
        if settings.WallEnabled and F.Wall then
            -- Fresh manual enable clears the quarantine counter for this match.
            F.Wall.Errors=0;F.Wall.Quarantine=false;F.Wall.PausedTill=0
            _G.LunarWallNotice=nil
        end
        F.MarkDirty(true)
        if changed then F.RefreshWallSettings() end
        if F.Wake then F.Wake() end
    end
    F.SetWallColor=function(key,value)
        if key~="WallVisible" and key~="WallOccluded" then return false end
        local v=number(value,1,7,settings[key])
        if settings[key]==v then return true end
        settings[key]=v
        if F.Wall then F.Wall.UpdateColors() end
        F.MarkDirty(true)
        F.RefreshWallSettings()
        if settings.WallEnabled and F.Wake then F.Wake() end
        return true
    end
    -- V9.7: safe mode limits Wall Hack to character meshes (no world/vehicle
    -- components), which is where the native dyeing calls used to crash.
    F.SetWallSafeMode=function(enabled)
        settings.WallSafeMode=(enabled==true or enabled==1)
        if F.Wall then
            F.Wall.SafeMode=settings.WallSafeMode
            F.Wall.LastTick=-999
        end
        F.MarkDirty(true)
        if settings.WallEnabled and F.Wake then F.Wake() end
        return true
    end

    -- Feature correspondence is resolved at setting changes only, never per frame.
    local v1Keys={"Name","Line","Health","Distance","EnemyCounter"}
    local v2Keys={"Name","Line","Box","Health","Distance","Skeleton","Counter"}
    local v1ToV2={Name="Name",Line="Line",Health="Health",Distance="Distance",EnemyCounter="Counter"}
    local v2ToV1={Name="Name",Line="Line",Health="Health",Distance="Distance",Counter="EnemyCounter"}
    local v2Valid={Name=true,Line=true,Box=true,Health=true,Distance=true,Skeleton=true,Counter=true}
    F.ESPSettingsEventType=-14050701
    F.ESPSettingsEventID=2
    local function applyESP(version,key,on)
        local first,second=false,false
        local own=version==1 and _G.g_Botmater_ESPOptions or _G.g_vipserver_ESPOptions
        local other=version==1 and _G.g_vipserver_ESPOptions or _G.g_Botmater_ESPOptions
        local mapped=(version==1 and v1ToV2 or v2ToV1)[key]
        if (own[key]==true)~=on then own[key]=on;first=true end
        if on and mapped and other[mapped]==true then other[mapped]=false;second=true end
        if version==1 then return first,second end
        return second,first
    end
    local function commitESP(changedV1,changedV2)
        if not changedV1 and not changedV2 then
            if F.Dirty then return F.Save(true) end
            return true
        end
        if changedV1 and F.V1 then F.V1.Refresh();F.V1Due=0 end
        F.MarkDirty(true)
        if changedV2 then
            _G.g_vipserver_VIPShotESPForceRefresh()
        else
            local due=g_vipserver_ESPRunnerToken.Due
            if not due or due-g_vipserver_ESPNow()>0.002 then g_vipserver_ESPSchedule(0.001) end
        end
        if EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,F.ESPSettingsEventType,F.ESPSettingsEventID)
            if not ok then F.Error("ESP.SettingsRefresh",err) end
        end
        return true
    end
    F.SetESP=function(version,key,value)
        if version~=1 and version~=2 then return false end
        if (version==1 and not v1ToV2[key]) or (version==2 and not v2Valid[key]) then return false end
        local changedV1,changedV2=applyESP(version,key,value==true or value==1)
        return commitESP(changedV1,changedV2)
    end
    F.GetESPAll=function(version)
        if version~=1 and version~=2 then return false end
        local own=version==1 and _G.g_Botmater_ESPOptions or _G.g_vipserver_ESPOptions
        for _,key in ipairs(version==1 and v1Keys or v2Keys) do if own[key]~=true then return false end end
        return true
    end
    F.SetESPAll=function(version,value)
        if version~=1 and version~=2 then return false end
        local changedV1,changedV2=false,false
        for _,key in ipairs(version==1 and v1Keys or v2Keys) do
            local a,b=applyESP(version,key,value==true or value==1)
            changedV1,changedV2=changedV1 or a,changedV2 or b
        end
        return commitESP(changedV1,changedV2)
    end
    -- Native OnSelected skips SetFunc when the same index is selected again.
    -- Bulk command rows must still apply to partial ESP state. Only these marked
    -- rows receive the additional click callback; every other native row is untouched.
    F.InstallNativeBulkSwitch=function(class)
        if type(class)~="table" or type(class.OnSelected)~="function" then return false end
        if class.__LunarBulkSwitchV7 then return true end
        local original=class.OnSelected
        class.OnSelected=function(self,index)
            local data=self.Data
            local repeatBulk=data and data.LunarBulk and self.UIRoot.Selector:GetSelectedIndex()==index
            local result=original(self,index)
            if repeatBulk then return data.SetFunc(data.Key,self:_IndexToValue(index)) end
            return result
        end
        class.__LunarBulkSwitchV7=true
        return true
    end
    F.SetV1=function(key,value) return F.SetESP(1,key,value) end
    F.SetV2=function(key,value) return F.SetESP(2,key,value) end
    -- Old versions allowed both copies on. Resolve old conflicts once at load,
    -- giving V1 priority; persist the merged state through the existing save pump.
    for key,mapped in pairs(v1ToV2) do
        if _G.g_Botmater_ESPOptions[key]==true and _G.g_vipserver_ESPOptions[mapped]==true then
            _G.g_vipserver_ESPOptions[mapped]=false
            F.MarkDirty()
        end
    end
    F.Error=function(area,err)
        F.Diagnostics.Errors=F.Diagnostics.Errors+1
        F.Diagnostics.LastError=area..": "..tostring(err)
    end
    _G.__LunarFeaturesCleanup=function()
        F.Token.Stopped=true
        if ESPShared.Events.UnbindAll then ESPShared.Events.UnbindAll() end
        if F.V1 then F.V1.Reset() end
        if F.Wall then F.Wall.Stop() end
        if F.Aim2 then F.Aim2.Stop() end
        if F.Mortar then F.Mortar.Stop() end
        if _G.LunarKick then pcall(_G.LunarKick.Stop) end
    end
end

do
local AimV2,AimGameplayStatics,AimMath,AimUI
pcall(function() AimV2=import("Vector2D") end)
pcall(function() AimGameplayStatics=import("GameplayStatics") end)
pcall(function() AimMath=import("KismetMathLibrary") end)
pcall(function() AimUI=require("client.common.ui_util") end)
_G.XthrlenConfig = _G.XthrlenConfig or {}
_G.XthrlenState = _G.XthrlenState or {}
_G.XthrlenState.CustomTextData = _G.XthrlenState.CustomTextData or {}

_G.XthrlenConfig.AimTouchEnable        = _G.LunarFeatures.Settings.AimEnabled
_G.XthrlenConfig.AimTouchHipfire       = true
_G.XthrlenConfig.AimTouchScopeAll      = true
_G.XthrlenConfig.AimTouchHipVisCheck   = _G.LunarFeatures.Settings.AimVisCheck
_G.XthrlenConfig.AimTouchScopeVisCheck = _G.LunarFeatures.Settings.AimVisCheck
_G.XthrlenConfig.AimTouchSniperVisCheck= _G.LunarFeatures.Settings.AimVisCheck
_G.XthrlenConfig.AimTouchHipIgKnock    = _G.LunarFeatures.Settings.AimIgKnock
_G.XthrlenConfig.AimTouchScopeIgKnock  = _G.LunarFeatures.Settings.AimIgKnock
_G.XthrlenConfig.AimTouchSniperIgKnock = _G.LunarFeatures.Settings.AimIgKnock

_G.XthrlenConfig.AimTouchHipIgBot      = _G.LunarFeatures.Settings.AimIgBot
_G.XthrlenConfig.AimTouchScopeIgBot    = _G.LunarFeatures.Settings.AimIgBot
_G.XthrlenConfig.AimTouchSniperIgBot   = _G.LunarFeatures.Settings.AimIgBot
_G.XthrlenConfig.AimTouchSG            = _G.LunarFeatures.Settings.AimShotgun
_G.XthrlenConfig.AimTouchSGAutoFire    = false
_G.XthrlenConfig.AimTouchScopeSniper   = _G.LunarFeatures.Settings.AimSniperScope
_G.XthrlenConfig.AimTouchMortar        = false
_G.XthrlenConfig.EspFovCircle          = false

_G.XthrlenState.CustomTextData.AimTouchHipPrio    = 1
_G.XthrlenState.CustomTextData.AimTouchHipBone    = 1
_G.XthrlenState.CustomTextData.AimTouchHipCond    = 1
_G.XthrlenState.CustomTextData.AimTouchHipSpeed   = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchHipDist    = _G.LunarFeatures.Settings.AimDist
_G.XthrlenState.CustomTextData.AimTouchHipFOV     = _G.LunarFeatures.Settings.AimFOV

_G.XthrlenState.CustomTextData.AimTouchScopePrio   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeBone   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeCond   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeSpeed  = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchScopeDist   = _G.LunarFeatures.Settings.AimDist
_G.XthrlenState.CustomTextData.AimTouchScopeFOV    = _G.LunarFeatures.Settings.AimFOV
_G.XthrlenState.CustomTextData.AimTouchScopePred   = 0

_G.XthrlenState.CustomTextData.AimTouchSniperDist   = _G.LunarFeatures.Settings.AimDist
_G.XthrlenState.CustomTextData.AimTouchSniperFOV    = _G.LunarFeatures.Settings.AimFOV
_G.XthrlenState.CustomTextData.AimTouchSniperSpeed  = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchSniperPred   = 0

_G.XthrlenState.CustomTextData.AimTouchSGCond   = 2
_G.XthrlenState.CustomTextData.AimTouchSGSpeed  = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchSGFOV    = math.max(40,_G.LunarFeatures.Settings.AimFOV)
_G.XthrlenState.CustomTextData.AimTouchSGDist   = 30

-- V9.9: saved manual scope values (ya global defaults) apply karo.

_G.XthrlenState.offPitch = _G.XthrlenState.offPitch or 0
_G.XthrlenState.offYaw   = _G.XthrlenState.offYaw   or 0

local function clampAngles(angles)
    if angles.Pitch > 180 then angles.Pitch = angles.Pitch - 360 end
    if angles.Pitch < -180 then angles.Pitch = angles.Pitch + 360 end

    if angles.Pitch < -75 then
        angles.Pitch = -75
    elseif angles.Pitch > 75 then
        angles.Pitch = 75
    end

    while angles.Yaw < -180 do angles.Yaw = angles.Yaw + 360 end
    while angles.Yaw > 180  do angles.Yaw = angles.Yaw - 360 end

    return angles
end

_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()
    if not (slua and slua.isValid and slua.isValid(player)) then return result end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()
    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    local ok,err=pcall(function()
        local aimSettings=_G.LunarFeatures.Settings
        if not (_G.XthrlenConfig.AimTouchEnable or aimSettings.AimSniperScope==true or aimSettings.AimShotgun==true) then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not (slua and slua.isValid and slua.isValid(player)) then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not (slua and slua.isValid and slua.isValid(pc)) then return end
        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        -- Firing gate moved below weapon classification so the V9.4 idle modes
        -- (sniper scope / shotgun hipfire) can aim without ever firing a shot.
        
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        if _G.LunarFeatures.Settings.MortarEnabled and weapon and weapon.MortarState==2 then return end
        local isShotgun = false
        local isSniper = false
        local isMortar = false
        local currentAmmo = 1
        
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            local wLower=wName:lower()
            if (wID >= 1030000 and wID < 1040000)
                or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014")
                or wName:find("NS2000") or wName:find("DP12") or wName:find("M1887") or wName:find("AA12") or wName:find("Saiga")
                or wLower:find("shotgun") or wLower:find("shot_gun") or wLower:find("sawed") then
                isShotgun = true
            end
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end
            if wLower:find("mortar") or wLower:find("cối") then
                isMortar = true
            end
            
            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        if _G.XthrlenState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.XthrlenState.IsAutoFiring = false
        end

        -- V9.4/V9.5: idle aim permission. Sniper = ADS with a sniper rifle,
        -- shotgun = any shotgun (hipfire preferred). Both run without firing.
        local idleSettings=_G.LunarFeatures.Settings
        local sniperIdle=idleSettings.AimSniperScope==true and isSniper and isADS
        local shotgunIdle=idleSettings.AimShotgun==true and isShotgun
        if (not isFiring) and (not sniperIdle) and (not shotgunIdle) then return end

        -- V9.6: idle modes glide instead of snapping. Reset the smoothing state
        -- as soon as both idle modes are off so firing aim stays untouched.
        local smoothIdle = sniperIdle or shotgunIdle
        if not smoothIdle then
            _G.LunarAimStickyTarget=nil;_G.LunarAimFilter=nil;_G.LunarAimTargetCache=nil
            _G.XthrlenState.aimVelP=nil;_G.XthrlenState.aimVelY=nil
        end

        -- Lightweight state for debugging: _G.LunarAimDiag in the Lua console.
        local diag=_G.LunarAimDiag
        if type(diag)~="table" then diag={}; _G.LunarAimDiag=diag end
        diag.Shotgun=isShotgun; diag.Sniper=isSniper; diag.ADS=isADS==true; diag.Firing=isFiring==true
        diag.SniperIdle=sniperIdle==true; diag.ShotgunIdle=shotgunIdle==true
        diag.Kick=aimSettings.KickControl==true; diag.KickAmount=tonumber(aimSettings.KickAmount)
        pcall(function()
            if slua.isValid(weapon) and type(weapon.GetWeaponName)=="function" then diag.Weapon=weapon:GetWeaponName() end
        end)

        if isShotgun and currentAmmo <= 0 and not shotgunIdle then return end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 100
        local fovVal = 30
        local maxDistMeters = 100
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        local predVal = 0 

        if isMortar and _G.XthrlenConfig.AimTouchMortar then
            local isPlaced = false
            pcall(function()
                if weapon and weapon.MortarState == 2 then isPlaced = true end
            end)
            if not isPlaced then return end

            cond = 2 
            prioMode = 1  
            boneIdx = 4 
            speedVal = 100 
            fovVal = _G.XthrlenState.CustomTextData.AimTouchMortarFOV or 360 
            maxDistMeters = 2000 
            useVisCheck = false 
            igKnock = false
            igBot = false
            predVal = _G.XthrlenState.CustomTextData.AimTouchMortarPred or 0 
            
        elseif isShotgun and _G.XthrlenConfig.AimTouchSG then
            cond = _G.XthrlenState.CustomTextData.AimTouchSGCond or 1
            if _G.XthrlenConfig.AimTouchSGAutoFire then cond = 2 end
            if shotgunIdle then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.XthrlenState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.XthrlenState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.XthrlenState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.XthrlenState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.XthrlenConfig.AimTouchSGVisCheck
            igKnock = _G.XthrlenConfig.AimTouchSGIgKnock
            igBot = _G.XthrlenConfig.AimTouchSGIgBot
            
        elseif isADS then
            if isSniper and _G.XthrlenConfig.AimTouchScopeSniper then
                cond = _G.XthrlenState.CustomTextData.AimTouchSniperCond or 2
                if sniperIdle then cond = 2 end
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.XthrlenState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.XthrlenState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.XthrlenConfig.AimTouchSniperVisCheck
                igKnock = _G.XthrlenConfig.AimTouchSniperIgKnock
                igBot = _G.XthrlenConfig.AimTouchSniperIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchSniperPred or 0
            elseif _G.XthrlenConfig.AimTouchScopeAll then
                cond = _G.XthrlenState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchScopeSpeed or 100
                fovVal = _G.XthrlenState.CustomTextData.AimTouchScopeFOV or 30
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchScopeDist or 100
                useVisCheck = _G.XthrlenConfig.AimTouchScopeVisCheck
                igKnock = _G.XthrlenConfig.AimTouchScopeIgKnock
                igBot = _G.XthrlenConfig.AimTouchScopeIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchScopePred or 0
            else
                return
            end
        else
            cond = _G.XthrlenState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.XthrlenState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = 1
            speedVal = _G.XthrlenState.CustomTextData.AimTouchHipSpeed or 100
            fovVal = _G.XthrlenState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchHipDist or 100
            useVisCheck = _G.XthrlenConfig.AimTouchHipVisCheck
            igKnock = _G.XthrlenConfig.AimTouchHipIgKnock
            igBot = _G.XthrlenConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100
        -- V9.6: reuse the scan briefly in idle modes. Rescanning every actor at
        -- 100 Hz is what made the lock stutter on crowded maps.
        local aimClock=_G.LunarFeatures.Now()
        local enemies
        local scanCache=_G.LunarAimTargetCache
        if smoothIdle and scanCache and scanCache.range==currentMaxDist
            and aimClock>=scanCache.time and (aimClock-scanCache.time)<0.06 then
            enemies=scanCache.enemies
        else
            enemies=_G.GetEnemyTargetsFromActors(currentMaxDist)
            if smoothIdle and enemies and #enemies>0 then _G.LunarAimTargetCache={time=aimClock,enemies=enemies,range=currentMaxDist} end
        end
        if not enemies or #enemies == 0 then return end
        
        local FVector2D = AimV2
        local UGameplayStatics = AimGameplayStatics
        local KismetMathLibrary = AimMath
        if not FVector2D or not UGameplayStatics or not KismetMathLibrary then return end
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = AimUI
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999 
        
        local selected=_G.LunarFeatures.Settings.AimTarget
        if sniperIdle then selected=1 end -- scope aim always locks the head
        boneIdx=selected==2 and 2 or (selected==3 and 5 or 1)
        local selBoneName=selected==2 and "spine_03" or (selected==3 and "calf_l" or "head")

        -- V9.6: idle lock stays on one enemy; it only rescans after losing it.
        local stickyTarget=smoothIdle and _G.LunarAimStickyTarget
        local stickyOnly=false
        if stickyTarget and slua.isValid(stickyTarget) then
            local stickyAlive=true
            if type(stickyTarget.IsAlive)=="function" then
                local okAlive,alive=pcall(function() return stickyTarget:IsAlive() end)
                stickyAlive=okAlive and alive==true
            end
            if stickyAlive then
                -- Lost range: drop the lock so the scan can pick a new enemy.
                local okDist,dist=pcall(function() return player:GetDistanceTo(stickyTarget) end)
                if okDist and type(dist)=="number" and dist>currentMaxDist then stickyAlive=false end
            end
            if stickyAlive then
                enemies={stickyTarget}
                stickyOnly=true
            else
                _G.LunarAimStickyTarget=nil
            end
        end

        for i, target in ipairs(enemies) do
            repeat
            if not slua.isValid(target) then break end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then break end
            
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then break end
            end
            
            if useVisCheck then
                local curTime = _G.LunarFeatures.Now()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or curTime < _G.AimTouchVisCache[tId].time or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then break end
            end
            
            local tPos = target.GetBonePos and target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20
                        elseif boneIdx == 5 then tPos.Z = tPos.Z - 60 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then break end
            
            local screen = FVector2D()
            local success,outScreen = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if outScreen then screen=outScreen end
            if not success or screen.X <= 0 or screen.Y <= 0 then break end
            
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            
            if distScreen > FOV_RADIUS then break end
            
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            
            until true
        end

        -- V9.6: remember the idle lock so the next tick can track it directly.
        if smoothIdle then
            if bestTarget then
                _G.LunarAimStickyTarget=bestTarget
            elseif stickyOnly then
                _G.LunarAimStickyTarget=nil
                return
            end
        end
        
        local cache=_G.AimTouchVisCache
        local clock=_G.LunarFeatures.Now()
        if cache and (not _G.LunarFeatures.AimPruneDue or clock>=_G.LunarFeatures.AimPruneDue) then
            for key,entry in pairs(cache) do if clock<entry.time or clock-entry.time>1 then cache[key]=nil end end
            _G.LunarFeatures.AimPruneDue=clock+0.5
        end
        if not slua.isValid(bestTarget) then return end
        
        local finalBonePos = bestTarget.GetBonePos and bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20
                    elseif boneIdx == 5 then finalBonePos.Z = finalBonePos.Z - 60 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end
        
        local tVelocity = nil
        pcall(function()
            if type(bestTarget.GetVelocity) == "function" then
                tVelocity = bestTarget:GetVelocity()
            end
        end)

        if not isMortar and predVal > 0 then
            pcall(function()
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0) 
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        -- V9.6: low-pass the bone position so animation and network jitter do
        -- not shake the camera. A new/stale target restarts the filter.
        if smoothIdle then
            local fNow=_G.LunarFeatures.Now()
            local filter=_G.LunarAimFilter
            if filter and filter.target==bestTarget and fNow>=filter.time and (fNow-filter.time)<0.20 then
                local elapsed=math.max(0.001,math.min(0.05,fNow-filter.time))
                local k=1.0-math.exp(-elapsed/0.045)
                filter.x=filter.x+(finalBonePos.X-filter.x)*k
                filter.y=filter.y+(finalBonePos.Y-filter.y)*k
                filter.z=filter.z+(finalBonePos.Z-filter.z)*k
                filter.time=fNow
                finalBonePos.X=filter.x;finalBonePos.Y=filter.y;finalBonePos.Z=filter.z
            else
                _G.LunarAimFilter={target=bestTarget,x=finalBonePos.X,y=finalBonePos.Y,z=finalBonePos.Z,time=fNow}
            end
        end

        if isADS and isFiring then
            local dist = player:GetDistanceTo(bestTarget) / 100.0
            finalBonePos.Z = finalBonePos.Z - (dist * 1.1)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end

        if not isADS then
            _G.XthrlenState.offPitch = 0
            _G.XthrlenState.offYaw   = 0
        end

        local dPitch = rot.Pitch - currentRot.Pitch
        local dYaw   = rot.Yaw   - currentRot.Yaw

        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                dYaw   = dYaw   - (camRot.Yaw   - currentRot.Yaw)
                dPitch = dPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end

        if dPitch~=dPitch or dYaw~=dYaw or math.abs(dPitch)==math.huge or math.abs(dYaw)==math.huge then return end
        dPitch=(dPitch+180)%360-180
        dYaw=(dYaw+180)%360-180

        -- Displayed settings remain 100..120. The requested maximum applies
        -- at most half the previous full correction; low settings are gentler.
        local now=_G.LunarFeatures.Now()
        local previous=_G.LunarFeatures.AimLastClock
        -- V9.6: a stale gap (target lost for a while) must not turn into one
        -- huge correction, so any long pause restarts at the normal tick time.
        local dt=0.012
        if previous then
            local gap=now-previous
            if gap>=0.0005 and gap<=0.05 then dt=math.max(0.004,math.min(0.032,gap)) end
        end
        _G.LunarFeatures.AimLastClock=now
        local normalized=(_G.LunarFeatures.Clamp(speedVal,100,120,100)-100)/20.0
        local strength=0.02+0.48*normalized*normalized
        local maxTurnRate=10.0+35.0*normalized
        local alphaCap=0.5
        if smoothIdle then
            -- V9.6: fast but continuous. Moderate alpha + a turn-rate cap gives
            -- a glide instead of a 15-degree jump every tick.
            strength=0.46+0.18*normalized
            maxTurnRate=850.0+220.0*normalized
            alphaCap=0.62
        end
        local alpha=math.min(alphaCap,1.0-(1.0-strength)^(dt/0.011))

        -- Camera-relative ADS error already accounts for view/controller offset.
        -- Repeatedly accumulating target error causes windup and unwanted swipes.
        _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0
        local apply={Pitch=currentRot.Pitch+dPitch,Yaw=currentRot.Yaw+dYaw,Roll=0}

        local pitchDelta=(apply.Pitch-currentRot.Pitch+180)%360-180
        local yawDelta=(apply.Yaw-currentRot.Yaw+180)%360-180
        local pitchStep,yawStep=pitchDelta*alpha,yawDelta*alpha
        local stepLength=math.sqrt(pitchStep*pitchStep+yawStep*yawStep)
        local stepLimit=maxTurnRate*dt
        if stepLength>stepLimit then
            local scale=stepLimit/stepLength
            pitchStep=pitchStep*scale;yawStep=yawStep*scale
        end
        if smoothIdle then
            -- V9.6: acceleration limit so the lock ramps in and eases out
            -- instead of starting/stopping instantly (that felt like lag).
            local state=_G.XthrlenState
            local lastP=state.aimVelP or 0
            local lastY=state.aimVelY or 0
            local dvP,dvY=pitchStep-lastP,yawStep-lastY
            local dvLength=math.sqrt(dvP*dvP+dvY*dvY)
            local dvLimit=26000.0*dt*dt
            -- Deceleration may be 4x faster. Without that the camera coasts past
            -- the head at high aim speed, which reads as a bounce.
            if math.sqrt(pitchStep*pitchStep+yawStep*yawStep)<math.sqrt(lastP*lastP+lastY*lastY) then
                dvLimit=dvLimit*4.0
            end
            if dvLimit>0 and dvLength>dvLimit then
                local k=dvLimit/dvLength
                pitchStep=lastP+dvP*k;yawStep=lastY+dvY*k
            end
            if math.sqrt(pitchStep*pitchStep+yawStep*yawStep)<0.015 then
                pitchStep=0;yawStep=0
            end
            state.aimVelP,state.aimVelY=pitchStep,yawStep
        end
        local out={Pitch=currentRot.Pitch+pitchStep,Yaw=currentRot.Yaw+yawStep,Roll=0}

        out = clampAngles(out)
        pc:SetControlRotation(out, "AimTouch")
    end)
    if not ok then _G.LunarFeatures.Error("Aim",err) end
end



_G.LunarFeatures.Aim={Tick=_G.AimTouch}

-- V9.9: Kick control (recoil). Ye asli engine fields hain jo weapon ke shoot
-- component par recoil/deviation control karte hain. Amount 100 = minimum
-- kick (0.01), 0 = kuch nahi chhua. Disable/reload par original values wapas.
local Kick={Records={},LastWeapon=nil,Applied=false,Target=0.01}
local KICK_FIELDS={"RecoilKickADS","GameDeviationFactor","GameDeviationAccuracy"}
_G.LunarKick=Kick
local function kickRestore()
    for comp,record in pairs(Kick.Records) do
        if slua.isValid(comp) then
            for key,value in pairs(record) do pcall(function() comp[key]=value end) end
        end
        Kick.Records[comp]=nil
    end
    Kick.Applied=false
end
Kick.Stop=function()
    pcall(kickRestore)
    Kick.LastWeapon=nil
    Kick.Target=0.01
end
local function kickComp(pawn)
    if not slua.isValid(pawn) then return nil end
    local weapon=nil
    local mgr=pawn.WeaponManagerComponent
    if mgr then weapon=mgr.CurrentWeaponReplicated end
    if not slua.isValid(weapon) and type(pawn.GetCurrentShootWeapon)=="function" then
        local ok,v=pcall(function() return pawn:GetCurrentShootWeapon() end)
        if ok and slua.isValid(v) then weapon=v end
    end
    if not slua.isValid(weapon) then return nil end
    local comp=weapon.ShootWeaponEntityComp
    if not slua.isValid(comp) then return nil end
    return weapon,comp
end
Kick.Tick=function(pawn)
    local settings=_G.LunarFeatures.Settings
    if settings.KickControl~=true then
        if Kick.LastWeapon or next(Kick.Records) then Kick.Stop() end
        return false
    end
    local weapon,comp=kickComp(pawn)
    if not comp then
        if Kick.LastWeapon or next(Kick.Records) then Kick.Stop() end
        return false
    end
    if Kick.LastWeapon and Kick.LastWeapon~=weapon then kickRestore() end
    Kick.LastWeapon=weapon
    local amount=math.max(0,math.min(100,tonumber(settings.KickAmount) or 100))
    -- Amount 0 = feature off (recoil ko chhua hi nahi).
    if amount<=0 then
        if Kick.LastWeapon or next(Kick.Records) then Kick.Stop() end
        return false
    end
    local target=0.01+(1.0-amount/100.0)*0.99
    local record=Kick.Records[comp]
    if not record then
        record={}
        Kick.Records[comp]=record
        for _,key in ipairs(KICK_FIELDS) do
            local current=comp[key]
            if type(current)=="number" then record[key]=current end
        end
    end
    for _,key in ipairs(KICK_FIELDS) do
        local current=comp[key]
        if type(current)=="number" and math.abs(current-target)>0.0005 then
            pcall(function() comp[key]=target end)
        end
    end
    Kick.Target=target
    Kick.Applied=true
    _G.LunarKickDiag={Weapon=weapon,Target=target,Amount=amount,Fields=#KICK_FIELDS}
    return true
end
end

-- Preserve the reference's DrawDyeing/Highlight/IdeaOutline settings and cadence.
-- Deduplicate mesh identities; do not assume the game leaves material flags alone.
do
    local F=_G.LunarFeatures
    local valid=g_vipserver_ESPValid
    local classes={}
    for _,name in ipairs({"SkeletalMeshComponent","StaticMeshComponent"}) do
        local ok,value=pcall(import,name)
        if ok and value then classes[#classes+1]={Class=value,Name=name} end
    end
    local W={Meshes={},Pawns={},LastTick=-999,LastCleanup=-999,CleanupInterval=1/60,ConsoleWorld=nil,Applied=0,
        SafeMode=true,MaxMeshes=180,Budget=0,Errors=0,Quarantine=false}
    F.Wall=W
    local properties={
        {"SetDrawDyeing","bDrawDyeing"},{"SetDrawHighlight","bDrawHighlight"},
        {"SetDrawIdeaOutline","bDrawIdeaOutline"},{"SetRenderCustomDepth","bRenderCustomDepth"}
    }
    local function calls(vis,occ)
        return {
            {"SetDrawDyeing",true},{"SetDrawDyeingMode",1},{"SetVisibleDyeingColor",vis},{"SetOccludedDyeingColor",occ},
            {"SetDyeingColorFadeDistance",99999.0},{"SetDyeingColorMinMaxDistance",0.0,99999.0},
            {"SetDrawHighlight",true},{"OverrideHighlightColor",vis},{"SetHighlightCanBeOccluded",false},
            {"SetDrawIdeaOutline",true},{"SetIdeaOutlineNew",true},{"SetIdeaOutlineOcclusionHighlight",true},
            {"OverrideIdeaOutlineColor",vis},{"SetIdeaOutlineOcclusionColor",occ},{"OverrideIdeaOutlineThickness",20.0},
            {"SetIdeaOverrideOutlineAndOcclusion",true},{"SetRenderCustomDepth",true},{"SetCustomDepthStencilValue",255}
        }
    end
    -- Wall shader colors retain the working intensity 100 and alpha 100.
    -- Slot 6 uses the supplied saffron RGB (100,1,0); slot 7 is red.
    local palette={{100,0,35},{100,100,100},{0,100,100},{0,100,0},
        {100,100,0},{100,1,0},{100,0,0}}
    W.Palette=palette
    local colorCalls
    W.UpdateColors=function()
        local a=palette[F.Settings.WallVisible] or palette[1]
        local b=palette[F.Settings.WallOccluded] or palette[2]
        local vis=g_vipserver_ESPColor(a[1],a[2],a[3],100)
        local occ=g_vipserver_ESPColor(b[1],b[2],b[3],100)
        colorCalls=calls(vis,occ)
        W.LastTick=-999
    end
    W.UpdateColors()
    W.SafeMode = F.Settings.WallSafeMode ~= false
    -- V9.10: native call fail hone par Wall setting kabhi OFF nahi hoti.
    -- Sirf us tick ko skip karte hain, notice dete hain. Safe mode pehle hi
    -- static meshes skip karta hai taak errors kam aayein.
    W.LastErrorTick=-1
    W.PausedTill=0
    local function noteError(call,err)
        if W.LastErrorTick==W.LastTick then return end
        W.LastErrorTick=W.LastTick
        W.Errors=(W.Errors or 0)+1
        F.Error("Wall."..tostring(call),err)
        -- Thode der ke liye tick roko (crash window se bachne ke liye), lekin
        -- WallEnabled=true rakho taak menu button OFF na ho.
        W.PausedTill=W.LastTick+1.0
        if W.Errors>=40 and not W.SafeMode then
            W.SafeMode=true;W.LastTick=-999
        end
        if W.Errors>=140 and not W.Quarantine then
            W.Quarantine=true
            -- F.Settings.WallEnabled=false   -- REMOVED: button khud band na ho
            _G.LunarWallNotice="Wall Hack native error. Safe mode ON, tick paused 2s. Toggle Wall Hack again."
            if F.MarkDirty then F.MarkDirty(true) end
            pcall(W.Stop)
        end
    end
    local function invoke(mesh,call)
        local method=mesh[call[1]]
        if not method then return end
        if call[3]~=nil then method(mesh,call[2],call[3]) else method(mesh,call[2]) end
    end
    local function restore(mesh,state)
        if not valid(mesh) then return end
        for _,pair in ipairs(properties) do
            pcall(function() if mesh[pair[1]] then mesh[pair[1]](mesh,state[pair[2]]==true) end end)
        end
    end
    W.Stop=function()
        for mesh,state in pairs(W.Meshes) do pcall(restore,mesh,state) end
        W.Meshes={};W.Pawns={}
        W.LastTick=-999;W.LastCleanup=-999
    end
    local function relevant(pawn,myLocation,maxRange,pc)
        local entry=ESPShared.GetFrameRecord(pawn)
        return entry.Alive and ESPShared.InRange(entry,myLocation,maxRange)
            and pc and ESPShared.ProbeActor(pc,pawn).OnScreen
    end
    W.Cleanup=function(myLocation,maxRange,pc)
        for pawn,meshes in pairs(W.Pawns) do
            if not relevant(pawn,myLocation,maxRange,pc) then
                for mesh in pairs(meshes) do
                    local state=W.Meshes[mesh]
                    if state then restore(mesh,state);W.Meshes[mesh]=nil end
                end
                W.Pawns[pawn]=nil
            end
        end
    end
    local function apply(mesh,pawn,seen,strict)
        if not valid(mesh) or seen[mesh] then return end
        -- V9.7: hard limit on *new* meshes per tick (a stall/crash window in
        -- big fights). Refreshing an already-known mesh adds no new risk.
        local isNew=W.Meshes[mesh]==nil
        if isNew and (W.Budget or 0)<=0 then return end
        -- In safe mode only components owned by this pawn are touched. Foreign
        -- skinned cosmetics are what crashed in some game modes.
        if strict then
            local okOwner,owner=pcall(function() return mesh.GetOwner and mesh:GetOwner() end)
            if okOwner and owner~=nil and valid(owner) and owner~=pawn then return end
        end
        seen[mesh]=true
        local original=W.Meshes[mesh]
        if not original then
            W.Budget=(W.Budget or 0)-1
            original={}
            for _,pair in ipairs(properties) do pcall(function() original[pair[2]]=mesh[pair[2]]==true end) end
            W.Meshes[mesh]=original
        end
        if original.Pawn and original.Pawn~=pawn then
            local old=W.Pawns[original.Pawn]
            if old then old[mesh]=nil;if next(old)==nil then W.Pawns[original.Pawn]=nil end end
        end
        original.Pawn=pawn
        local owned=W.Pawns[pawn]
        if not owned then owned={};W.Pawns[pawn]=owned end
        owned[mesh]=true
        -- Each protected setter is attempted independently. An unavailable optional
        -- extension does not prevent other reference rendering modes from applying.
        for _,call in ipairs(colorCalls) do
            local ok,err=pcall(invoke,mesh,call)
            if not ok then noteError(call[1],err) end
        end
        W.Applied=W.Applied+1
    end
    W.Tick=function(now,me,pc)
        if not F.Settings.WallEnabled then return end
        now=now or F.Now()
        me=me or g_vipserver_ESPGetLocalCharacter()
        pc=pc or g_vipserver_ESPGetController()
        if not valid(me) or not valid(pc) then W.Stop() return end
        -- Error pause: native calls fail rahe hain, 2s tak tick mat chalao.
        if W.PausedTill and now<W.PausedTill then return end
        -- Death cam / spectator swap: meshes are being replaced here, so keep
        -- hands off until the next spawn instead of poking stale components.
        local okAlive,alive=pcall(function() return me.IsAlive and me:IsAlive() end)
        if okAlive and alive==false then return end
        local maxRange=tonumber(_G.g_vipserver_VIPShotESP.MaxRangeMeters) or 450.0
        if maxRange~=maxRange or maxRange<=0 or maxRange==math.huge then maxRange=450.0 end
        local myLocation=ESPShared.GetFrameRecord(me).Location
        if now<W.LastCleanup or now-W.LastCleanup>=W.CleanupInterval-0.000001 then
            W.Cleanup(myLocation,maxRange,pc);W.LastCleanup=now
        end
        if now>=W.LastTick and now-W.LastTick<0.30-0.000001 then return end
        W.LastTick=now
        local world=g_vipserver_ESPWorld()
        if world~=W.ConsoleWorld then
            local ok=pcall(function()
                if not world or not UKismetSystemLibrary.ExecuteConsoleCommand then return end
                for _,command in ipairs({"r.EnableDrawDyeingColor 1","r.CustomDepth 3","r.IdeaOutline.Enable 1","r.Highlight.Enable 1"}) do
                    UKismetSystemLibrary.ExecuteConsoleCommand(world,command)
                end
            end)
            if ok and world then W.ConsoleWorld=world end
        end
        local pawns=ESPShared.GetFramePawns()
        if not pawns then return end
        local seen={}
        -- V9.7: per-tick application budget. Keeps a big fight from touching
        -- hundreds of new components in one frame.
        W.Budget=W.MaxMeshes or 180
        local myTeam=me.TeamID or 0
        for _,pawn in pairs(pawns) do
            if valid(pawn) and pawn~=me and pawn.TeamID~=myTeam and relevant(pawn,myLocation,maxRange,pc) then
                pcall(function() apply(pawn.Mesh,pawn,seen) end)
                local avatar=nil
                pcall(function()
                    avatar=pawn.CharacterAvatarComp2_BP
                    if not avatar and pawn.getAvatarComponent2 then avatar=pawn:getAvatarComponent2() end
                end)
                if avatar and avatar.GetMeshCompBySlot then
                    for slot=0,7 do pcall(function() apply(avatar:GetMeshCompBySlot(slot),pawn,seen,true) end) end
                end
                for _,entry in ipairs(classes) do
                    -- Safe mode: skeletal character meshes only. Static mesh
                    -- components (props/vehicles) are the risky ones.
                    if not (W.SafeMode and entry.Name~="SkeletalMeshComponent") then
                        pcall(function()
                            if not pawn.GetComponentsByClass then return end
                            local components=pawn:GetComponentsByClass(entry.Class)
                            if components then for i=0,components:Num()-1 do apply(components:Get(i),pawn,seen,true) end end
                        end)
                    end
                end
                pcall(function()
                    local weapon=pawn.GetCurrentWeapon and pawn:GetCurrentWeapon()
                    if valid(weapon) then apply(weapon.Mesh,pawn,seen) end
                end)
            end
        end
        local meshCount=0
        for mesh,state in pairs(W.Meshes) do
            meshCount=meshCount+1
            if not seen[mesh] then
                restore(mesh,state);W.Meshes[mesh]=nil
                local owned=W.Pawns[state.Pawn]
                if owned then owned[mesh]=nil;if next(owned)==nil then W.Pawns[state.Pawn]=nil end end
            end
        end
        _G.LunarWallDiag={Applied=W.Applied,Meshes=meshCount,SafeMode=W.SafeMode==true,
            Errors=W.Errors or 0,Quarantine=W.Quarantine==true,Notice=_G.LunarWallNotice}
    end
    _G.StartWallhack=function() F.SetWall(true) end
    _G.StopWallhack=function() F.SetWall(false) end
end

do
_G.g_Botmater_ESPOptions = _G.g_Botmater_ESPOptions or {
    Name = false,
    Line = false,
    Health = false,
    Distance = false,
    EnemyCounter = false,
}

_G.g_Botmater_VIPShotESP = _G.g_Botmater_VIPShotESP or {
    Enabled = true,
    MaxRangeMeters = 300.0,
    ScanInterval = 0.05,
    UpdateInterval = 1/60,
    TransformInterval = 0.033,
    MaxRendered = 10,
    TracerThickness = 1.0,
    NameGap = 2.0,
    NameFontSize = 9,
    DistanceFontSize = 10,
    DistanceBelowFeet = 14,
}
-- ESP V1 settings remain independent from _G.VIPShotESP (ESP V2).

local g_Botmater_ShotESP = {
    Canvas = nil,
    Enemies = {},
    Lines = {},
    Names = {},
    LastScanClock = -999.0,
    LastTransformClock = -999.0,
    LastWorld = nil,
    CanvasScaleX = 1.0,
    CanvasScaleY = 1.0,
    CanvasOffsetX = 0.0,
    CanvasOffsetY = 0.0,
    LastPawn=nil,
    LastController=nil,
    Active={},
    Alive={},
    LastProjected={},
    RealCount = 0,
    BotCount = 0,
}

local V2 = _G.FVector2D
if not V2 then pcall(function() V2 = import("Vector2D") end) end
local LinearColor = _G.FLinearColor
if not LinearColor then pcall(function() LinearColor = import("LinearColor") end) end
local SlateBlueprintLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
local WidgetLayoutLibrary = nil
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)

local function g_Botmater_ESPV2(x, y)
    if V2 then return V2(x, y) end
    return {X = x, Y = y}
end

local function g_Botmater_ESPColor(r, g, b, a)
    if LinearColor then return LinearColor(r, g, b, a or 1.0) end
    return {R=r, G=g, B=b, A=a or 1.0}
end

local COLOR_REAL_VIS_RED          = g_Botmater_ESPColor(1.00, 0.00, 0.00, 1.00)
local COLOR_BOT_VIS_CYAN          = g_Botmater_ESPColor(0.10, 1.00, 1.00, 1.00)

local COLOR_TEXT_WHITE            = g_Botmater_ESPColor(1.00, 1.00, 1.00, 1.00)
local COLOR_TEXT_BLACK            = g_Botmater_ESPColor(0.00, 0.00, 0.00, 1.00)


local CACHE_COUNTER_PLAYER_BG   = g_Botmater_ESPColor(0.07, 0.008, 0.008, 1.0)
local CACHE_COUNTER_BOT_BG      = g_Botmater_ESPColor(0.008, 0.07, 0.07, 1.0)
local CACHE_COUNTER_PLAYER_TEXT = g_Botmater_ESPColor(1.0,0.86,0.84,1.0)
local CACHE_COUNTER_BOT_TEXT    = g_Botmater_ESPColor(0.82,1.0,1.0,1.0)


local COLOR_HP = {
    RealText=g_Botmater_ESPColor(1.0,0.86,0.84,1.0),
    BotText=g_Botmater_ESPColor(0.82,1.0,1.0,1.0),
    RealMid=g_Botmater_ESPColor(0.78,0.0,0.0,1.0),
    RealLow=g_Botmater_ESPColor(0.55,0.0,0.0,1.0),
    BotMid=g_Botmater_ESPColor(0.075,0.75,0.75,1.0),
    BotLow=g_Botmater_ESPColor(0.055,0.55,0.55,1.0),
    RealBG=g_Botmater_ESPColor(0.06,0.005,0.005,0.75),
    BotBG=g_Botmater_ESPColor(0.005,0.06,0.06,0.75)}

-- Ensure old in-memory options do not retain the tiny shipped label fonts.
_G.g_Botmater_VIPShotESP.NameFontSize=math.max(12,tonumber(_G.g_Botmater_VIPShotESP.NameFontSize) or 12)
_G.g_Botmater_VIPShotESP.DistanceFontSize=math.max(12,tonumber(_G.g_Botmater_VIPShotESP.DistanceFontSize) or 12)

local function g_Botmater_ESPGetColors(isBot)
    if isBot then
        return COLOR_BOT_VIS_CYAN, COLOR_HP.BotText
    else
        return COLOR_REAL_VIS_RED, COLOR_HP.RealText
    end
end

local function g_Botmater_ESPValid(obj)
    if not obj then return false end
    local ok, valid = pcall(function() return slua.isValid(obj) end)
    return ok and valid == true
end

local function g_Botmater_ESPNow() return _G.LunarFeatures.Now() end

local function g_Botmater_ESPWorld()
    local w = nil
    pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
    return w
end

local function g_Botmater_ESPGetController() return g_vipserver_ESPGetController() end
local function g_Botmater_ESPGetLocalCharacter() return g_vipserver_ESPGetLocalCharacter() end

local function g_Botmater_ESPGetPlayerState(character)
    if not g_Botmater_ESPValid(character) then return nil end
    local ps = nil
    pcall(function()
        if character.GetPlayerStateSafety then ps = character:GetPlayerStateSafety() end
    end)
    if not g_Botmater_ESPValid(ps) then
        pcall(function() if character.GetPlayerState then ps = character:GetPlayerState() end end)
    end
    if not g_Botmater_ESPValid(ps) then
        pcall(function() ps = character.PlayerState end)
    end
    return g_Botmater_ESPValid(ps) and ps or nil
end

local function g_Botmater_ESPNormalizeName(value)
    if value == nil or value == false then return nil end
    local ok, text = pcall(tostring, value)
    if not ok or not text then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or text == "nil" or text == "None" or text == "NULL" then return nil end
    return text
end

local function g_Botmater_ESPResolvePlayerName(character)
    if not g_Botmater_ESPValid(character) then return nil end
    local name = nil
    local function take(value)
        if not name then name = g_Botmater_ESPNormalizeName(value) end
    end
    pcall(function() if character.GetPlayerNameSafety then take(character:GetPlayerNameSafety()) end end)
    pcall(function() if not name and character.GetPlayerName then take(character:GetPlayerName()) end end)
    pcall(function() if not name then take(character.PlayerName) end end)
    pcall(function() if not name then take(character.NickName) end end)
    if not name then
        local ps = g_Botmater_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
            pcall(function() if not name then take(ps.PlayerName) end end)
            pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
            pcall(function() if not name then take(ps.NickName) end end)
        end
    end
    return name
end

local function g_Botmater_ESPGetPlayerKey(c) return g_vipserver_ESPGetPlayerKey(c) end

local function g_Botmater_ESPGetTeamID(character)
    if not g_Botmater_ESPValid(character) then return nil end
    local id = nil
    pcall(function() if character.GetTeamID then id = character:GetTeamID() end end)
    if id == nil then pcall(function() id = character.TeamID end) end
    if id == nil then
        local ps = g_Botmater_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
            if id == nil then pcall(function() id = ps.TeamID end) end
        end
    end
    return id
end

local function g_Botmater_ESPGetHealthPct(character)
    if not g_Botmater_ESPValid(character) then return 1.0 end
    local hp, maxHp = nil, nil
    pcall(function() hp = character.Health end)
    if type(hp) ~= "number" then pcall(function() hp = character.HP end) end
    pcall(function() maxHp = character.MaxHealth end)
    if type(maxHp) ~= "number" then pcall(function() maxHp = character.MaxHP end) end
    if not ESPShared.Finite(hp) then return 1.0 end
    if not ESPShared.Finite(maxHp) or maxHp <= 0 then maxHp = 100 end
    local pct = hp / maxHp
    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end
    return pct
end

local function g_Botmater_ESPGetHealthColor(pct,isBot)
    pct = tonumber(pct) or 1.0
    if pct >= 0.75 then return isBot and COLOR_BOT_VIS_CYAN or COLOR_REAL_VIS_RED
    elseif pct >= 0.50 then return isBot and COLOR_HP.BotMid or COLOR_HP.RealMid
    else return isBot and COLOR_HP.BotLow or COLOR_HP.RealLow end
end

local function g_Botmater_ESPIsBot(c)
    g_Botmater_ShotESP._BotCache=g_Botmater_ShotESP._BotCache or {}
    return g_vipserver_ESPIsBot(c,g_vipserver_ESPGetPlayerKey(c),g_Botmater_ShotESP._BotCache,_G.LunarFeatures.Now())
end

-- Deferred cleanup owns widgets only, never an actor, key or player name.
-- Admission is stopped well below the hard limit while native cleanup fails.
local V1Cleanup={Items={},Members={},Count=0,Cursor=1,Due=0,Limit=512,AdmissionLimit=128}
function V1Cleanup.Try(widget)
    if not g_Botmater_ESPValid(widget) then return true end
    local hidden,accepted=pcall(function() return widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    if not hidden or accepted==false then pcall(function() widget:SetRenderOpacity(0) end) end
    local ok,result=pcall(function() return widget:RemoveFromParent() end)
    if not ok or result==false then return false end
    local checked,parent=pcall(function() return widget:GetParent() end)
    return not checked or parent==nil
end
function V1Cleanup.Retire(widget)
    if not widget then return true end
    if V1Cleanup.Members[widget] then return true end
    if V1Cleanup.Try(widget) then return true end
    if V1Cleanup.Count>=V1Cleanup.Limit then return false end
    V1Cleanup.Count=V1Cleanup.Count+1
    V1Cleanup.Items[V1Cleanup.Count]=widget
    V1Cleanup.Members[widget]=true
    return true
end
function V1Cleanup.Pump(now)
    if V1Cleanup.Count==0 then return end
    if now>=V1Cleanup.Due-0.05 and now<V1Cleanup.Due then return end
    V1Cleanup.Due=now+0.05
    local budget=math.min(8,V1Cleanup.Count)
    while budget>0 and V1Cleanup.Count>0 do
        budget=budget-1
        local i=V1Cleanup.Cursor
        if i>V1Cleanup.Count then i=1 end
        local widget=V1Cleanup.Items[i]
        if V1Cleanup.Try(widget) then
            V1Cleanup.Members[widget]=nil
            V1Cleanup.Items[i]=V1Cleanup.Items[V1Cleanup.Count]
            V1Cleanup.Items[V1Cleanup.Count]=nil
            V1Cleanup.Count=V1Cleanup.Count-1
            V1Cleanup.Cursor=i
        else
            V1Cleanup.Cursor=i+1
        end
    end
end
ESPWidgetPool.V1.Remove=V1Cleanup.Retire

local function g_Botmater_ESPDestroyWidgetData(data)
    if not data then return true end
    if ESPWidgetPool.Release(data) then return true end
    return V1Cleanup.Retire(data.Widget or data.Container)
end

local function g_Botmater_ESPResetWidgets()
    ESPShared.Frame.V1CanvasChecked=false
    ESPWidgetPool.V1.Enabled=false
    for _,registry in ipairs({g_Botmater_ShotESP.Lines,g_Botmater_ShotESP.Names}) do
        for key,data in pairs(registry) do
            if g_Botmater_ESPDestroyWidgetData(data) then registry[key]=nil end
        end
    end
    g_Botmater_ShotESP.Canvas=nil
    g_Botmater_ShotESP.RootUI=nil
    g_Botmater_ShotESP.Enemies={}
    g_Botmater_ShotESP._BotCache={}
    g_Botmater_ShotESP.Active={}
    g_Botmater_ShotESP.Alive={}
    g_Botmater_ShotESP.LastProjected={}
    g_Botmater_ShotESP.RealCount=0;g_Botmater_ShotESP.BotCount=0
    g_Botmater_ShotESP.LastScanClock=-999
    g_Botmater_ShotESP.LastTransformClock=-999
    g_Botmater_ShotESP.LastPawn=nil;g_Botmater_ShotESP.LastController=nil
    g_Botmater_ShotESP.CanvasScaleX=1;g_Botmater_ShotESP.CanvasScaleY=1
    g_Botmater_ShotESP.CanvasOffsetX=0;g_Botmater_ShotESP.CanvasOffsetY=0
    g_Botmater_ShotESP.TransformReady=false
    g_Botmater_ShotESP.TransformW=nil;g_Botmater_ShotESP.TransformH=nil
    ESPWidgetPool.Flush(ESPWidgetPool.V1)
    ESPWidgetPool.V1.Enabled=true
end

local function g_Botmater_ESPGetCanvas()
    -- Compare the current HUD identity; native validity alone does not mean
    -- that a retained canvas still belongs to the visible HUD.
    local frame=ESPShared.Frame
    if frame.Active and frame.V1CanvasChecked then
        return g_Botmater_ESPValid(g_Botmater_ShotESP.Canvas) and g_Botmater_ShotESP.Canvas or nil
    end
    local root
    pcall(function()
        local ui=require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if ui and ui.GetMainControlBaseUI then root=ui.GetMainControlBaseUI() end
    end)
    if not g_Botmater_ESPValid(root) then
        if g_Botmater_ShotESP.Canvas then g_Botmater_ESPResetWidgets() end
        return nil
    end
    local canvas
    pcall(function()
        if g_Botmater_ESPValid(root.CanvasPanel_0) then canvas=root.CanvasPanel_0
        elseif g_Botmater_ESPValid(root.CanvasPanel_42) then canvas=root.CanvasPanel_42 end
    end)
    if not g_Botmater_ESPValid(canvas) then
        if g_Botmater_ShotESP.Canvas then g_Botmater_ESPResetWidgets() end
        return nil
    end
    if g_Botmater_ShotESP.Canvas~=canvas or g_Botmater_ShotESP.RootUI~=root then
        g_Botmater_ESPResetWidgets()
        g_Botmater_ShotESP.Canvas=canvas;g_Botmater_ShotESP.RootUI=root
    end
    if frame.Active then frame.V1CanvasChecked=true end
    return canvas
end

local function g_Botmater_ESPViewport(pc) return g_vipserver_ESPViewport(pc) end

local function g_Botmater_ESPGetCanvasLocalSize()
    local canvas = g_Botmater_ESPGetCanvas()
    if not g_Botmater_ESPValid(canvas) then return nil, nil end
    local cw, ch = nil, nil
    pcall(function()
        local geo = canvas:GetCachedGeometry()
        if not geo then return end
        local size = nil
        if geo.GetLocalSize then size = geo:GetLocalSize()
        elseif SlateBlueprintLibrary and SlateBlueprintLibrary.GetLocalSize then size = SlateBlueprintLibrary.GetLocalSize(geo) end
        if size and ESPShared.Finite(size.X) and ESPShared.Finite(size.Y) and size.X > 1 and size.Y > 1 then
            cw, ch = tonumber(size.X), tonumber(size.Y)
        end
    end)
    return cw, ch
end

local function g_Botmater_ESPUpdateCanvasTransform(pc)
    local state=g_Botmater_ShotESP
    local canvas=g_Botmater_ESPGetCanvas()
    if not g_Botmater_ESPValid(canvas) then return false end
    local width,height=ESPShared.ViewSize(pc)
    local sameViewport=state.TransformW==width and state.TransformH==height
    local calibrated=false
    pcall(function()
        local geo=canvas:GetCachedGeometry()
        if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal and geo then
            local p0=SlateBlueprintLibrary.AbsoluteToLocal(geo,g_Botmater_ESPV2(0,0))
            local p1=SlateBlueprintLibrary.AbsoluteToLocal(geo,g_Botmater_ESPV2(100,100))
            if p0 and p1 and ESPShared.Finite(p0.X) and ESPShared.Finite(p0.Y)
                and ESPShared.Finite(p1.X) and ESPShared.Finite(p1.Y)
                and math.abs(p0.X)<1e7 and math.abs(p0.Y)<1e7
                and p1.X>p0.X and p1.Y>p0.Y
                and p1.X-p0.X<10000 and p1.Y-p0.Y<10000 then
                state.CanvasScaleX=(p1.X-p0.X)/100
                state.CanvasScaleY=(p1.Y-p0.Y)/100
                state.CanvasOffsetX=p0.X;state.CanvasOffsetY=p0.Y
                calibrated=true
            end
        end
    end)
    -- A transient missing geometry sample must not toggle coordinate systems.
    if not calibrated and state.TransformReady and sameViewport then return true end
    if not calibrated then
        local scale=1
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
                local s=WidgetLayoutLibrary.GetViewportScale(pc)
                if ESPShared.Finite(s) and s>=0.01 and s<=100 then scale=s end
            end
        end)
        state.CanvasScaleX=1/scale;state.CanvasScaleY=1/scale
        state.CanvasOffsetX=0;state.CanvasOffsetY=0
    end
    state.TransformReady=true;state.TransformW=width;state.TransformH=height
    return true
end

local function g_Botmater_ESPSetFont(widget,size) g_vipserver_ESPSetFont(widget,size,0) end
local function g_Botmater_ESPSetTextColor(widget,color) g_vipserver_ESPSetTextColor(widget,color) end

local function g_Botmater_ESPCreateLine(color)
    if V1Cleanup.Count>=V1Cleanup.AdmissionLimit then return nil end
    local canvas = g_Botmater_ESPGetCanvas()
    if not g_Botmater_ESPValid(canvas) then return nil end
    local pooled=true and ESPWidgetPool.Take(ESPWidgetPool.V1,"Line",canvas)
    if pooled then
        local ok=pcall(function() pooled.Widget:SetBrushColor(color) end)
        if ok then pooled.Visible=false;return pooled end
        V1Cleanup.Retire(pooled.Widget)
    end
    local border = nil
    pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
    if not g_Botmater_ESPValid(border) then return nil end
    pcall(function()
        border:SetBrushColor(color)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        border:SetRenderTransformPivot(g_Botmater_ESPV2(0.0, 0.5))
    end)
    local slot = nil
    pcall(function() slot = canvas:AddChildToCanvas(border) end)
    if not slot then g_Botmater_ESPDestroyWidgetData({Widget=border}) return nil end
    pcall(function() slot:SetAutoSize(false) slot:SetZOrder(30) end)
    local data={Widget=border, Slot=slot, Visible=true}
    if true then ESPWidgetPool.Tag(ESPWidgetPool.V1,"Line",canvas,data) end
    return data
end

local function g_Botmater_ESPDrawLine(...) return g_vipserver_ESPDrawLine(...) end

local function g_Botmater_ESPHide(data)
    if data and g_Botmater_ESPValid(data.Widget) then
        if data.Visible ~= false then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.Visible = false
        end
    end
end

local function g_Botmater_ESPCreateNameTag(isBot)
    if V1Cleanup.Count>=V1Cleanup.AdmissionLimit then return nil end
    local canvas = g_Botmater_ESPGetCanvas()
    if not g_Botmater_ESPValid(canvas) then return nil end
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V1,"NameV1",canvas)
    if pooled then
        local mainColor,textColor=g_Botmater_ESPGetColors(isBot)
        local ok=pcall(function()
            pooled.BottomLine:SetBrushColor(mainColor)
            pooled.BottomLine:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            pooled.HealthBg:SetBrushColor(isBot and COLOR_HP.BotBG or COLOR_HP.RealBG)
            pooled.HealthFill:SetBrushColor(mainColor)
        end)
        if not ok then V1Cleanup.Retire(pooled.Widget);pooled=nil end
        if pooled then
            g_Botmater_ESPSetTextColor(pooled.Text,textColor)
            g_Botmater_ESPSetTextColor(pooled.DistanceText,textColor)
            g_Botmater_ESPSetFont(pooled.Text,tonumber(_G.g_Botmater_VIPShotESP.NameFontSize) or 9)
            g_Botmater_ESPSetFont(pooled.DistanceText,tonumber(_G.g_Botmater_VIPShotESP.DistanceFontSize) or 10)
            pooled.IsBot=isBot;pooled.Visible=false;pooled.LastHealthPct=-1
        end
        if pooled then return pooled end
    end

    local container = nil
    pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not g_Botmater_ESPValid(container) then return nil end

    local bottomLine = nil
    pcall(function() bottomLine = CGame:NewObjectFromPath("/Script/UMG.Border", container) end)
    local nameText = nil
    pcall(function() nameText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    local distanceText = nil
    pcall(function() distanceText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)

    local healthBarBg = nil
    pcall(function() healthBarBg = CGame:NewObjectFromPath("/Script/UMG.Border", container) end)
    local healthBarFill = nil
    pcall(function() healthBarFill = CGame:NewObjectFromPath("/Script/UMG.Border", container) end)

    if not g_Botmater_ESPValid(bottomLine)
        or not g_Botmater_ESPValid(nameText)
        or not g_Botmater_ESPValid(distanceText)
        or not g_Botmater_ESPValid(healthBarBg)
        or not g_Botmater_ESPValid(healthBarFill) then
        g_Botmater_ESPDestroyWidgetData({Widget=container})
        return nil
    end

    local mainColor,textColor=g_Botmater_ESPGetColors(isBot)
    local background=isBot and COLOR_HP.BotBG or COLOR_HP.RealBG

    pcall(function()
        bottomLine:SetBrushColor(mainColor)
        bottomLine:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        nameText:SetText("")
        distanceText:SetText("")
        nameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        distanceText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        if nameText.SetJustification then nameText:SetJustification(1) end
        if distanceText.SetJustification then distanceText:SetJustification(1) end
        healthBarBg:SetBrushColor(background)
        healthBarBg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        healthBarFill:SetBrushColor(mainColor)
        healthBarFill:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)

    g_Botmater_ESPSetTextColor(nameText, textColor)
    g_Botmater_ESPSetTextColor(distanceText, textColor)
    g_Botmater_ESPSetFont(nameText, tonumber(_G.g_Botmater_VIPShotESP.NameFontSize) or 9)
    g_Botmater_ESPSetFont(distanceText, tonumber(_G.g_Botmater_VIPShotESP.DistanceFontSize) or 10)

    local lineSlot, nameSlot, distanceSlot, mainSlot = nil, nil, nil, nil
    local healthBgSlot, healthFillSlot = nil, nil
    pcall(function() lineSlot = container:AddChildToCanvas(bottomLine) end)
    pcall(function() healthBgSlot = container:AddChildToCanvas(healthBarBg) end)
    pcall(function() healthFillSlot = container:AddChildToCanvas(healthBarFill) end)
    pcall(function() nameSlot = container:AddChildToCanvas(nameText) end)
    pcall(function() distanceSlot = container:AddChildToCanvas(distanceText) end)
    pcall(function() mainSlot = canvas:AddChildToCanvas(container) end)

    if not lineSlot or not nameSlot or not distanceSlot or not mainSlot or not healthBgSlot or not healthFillSlot then
        g_Botmater_ESPDestroyWidgetData({Widget=container})
        return nil
    end

    pcall(function()
        lineSlot:SetAutoSize(false) lineSlot:SetAlignment(g_Botmater_ESPV2(0.0, 0.0)) lineSlot:SetZOrder(1)
        healthBgSlot:SetAutoSize(false) healthBgSlot:SetAlignment(g_Botmater_ESPV2(0.0, 0.0)) healthBgSlot:SetZOrder(1)
        healthFillSlot:SetAutoSize(false) healthFillSlot:SetAlignment(g_Botmater_ESPV2(0.0, 0.0)) healthFillSlot:SetZOrder(2)
        nameSlot:SetAutoSize(true) nameSlot:SetAlignment(g_Botmater_ESPV2(0.5, 0.5)) nameSlot:SetZOrder(3)
        distanceSlot:SetAutoSize(true) distanceSlot:SetAlignment(g_Botmater_ESPV2(0.5, 0.5)) distanceSlot:SetZOrder(3)
        mainSlot:SetAutoSize(false) mainSlot:SetZOrder(35)
    end)

    local data={
        Widget       = container,
        BottomLine   = bottomLine,
        HealthBg     = healthBarBg,
        HealthFill   = healthBarFill,
        Text         = nameText,
        DistanceText = distanceText,
        LineSlot     = lineSlot,
        HealthBgSlot = healthBgSlot,
        HealthFillSlot = healthFillSlot,
        TextSlot     = nameSlot,
        DistanceSlot = distanceSlot,
        Slot         = mainSlot,
        IsBot        = isBot,
        Visible      = true,
        LastDistValue = nil,
        LastDistLabel = nil,
        LastHealthPct = -1,
    }
    return ESPWidgetPool.Tag(ESPWidgetPool.V1,"NameV1",canvas,data)
end

local function g_Botmater_ESPUpdateNameTag(key, character, headScreen, footScreen, isBot, distance, healthPct, pc)
    local showName     = _G.g_Botmater_ESPOptions.Name == true
    local showDistance = _G.g_Botmater_ESPOptions.Distance == true
    local showHealth = _G.g_Botmater_ESPOptions.Health == true

    local data = g_Botmater_ShotESP.Names[key]
    if not showName and not showDistance and not showHealth then
        if data and g_Botmater_ESPValid(data.Widget) then
            if data.Visible ~= false then
                pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                data.Visible = false
            end
        end
        return
    end

    if data and data.IsBot~=isBot then data.CachedName=nil end
    local name = nil
    if not showName then
        name=""
    elseif isBot then
        name = "BOT"
    else
        name = data and data.CachedName or nil
        if not name then
            name = g_Botmater_ESPResolvePlayerName(character)
            if data and name then data.CachedName = name end
        end
        if not name then name = showName and "UNKNOWN" or "" end
    end

    headScreen=headScreen or footScreen
    if not headScreen then
        if data and g_Botmater_ESPValid(data.Widget) then
            if data.Visible ~= false then
                pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                data.Visible = false
            end
        end
        return
    end

    if not data or not g_Botmater_ESPValid(data.Widget) then
        g_Botmater_ESPDestroyWidgetData(data)
        data = g_Botmater_ESPCreateNameTag(isBot)
        g_Botmater_ShotESP.Names[key] = data
        if data then data.CachedName = name end
    end
    if not data then return end

    if data.IsBot ~= isBot then
        local mainColor,textColor=g_Botmater_ESPGetColors(isBot)
        g_Botmater_ESPSetTextColor(data.Text,textColor)
        g_Botmater_ESPSetTextColor(data.DistanceText,textColor)
        local ok=pcall(function()
            data.BottomLine:SetBrushColor(mainColor)
            data.HealthBg:SetBrushColor(isBot and COLOR_HP.BotBG or COLOR_HP.RealBG)
        end)
        if ok then data.IsBot=isBot;data.LastHealthPct=nil end
    end

    local dist=math.floor(ESPShared.SafeNumber(distance,0,0,1e8)+0.5)
    local distanceLabel
    if data.LastDistValue ~= dist then
        distanceLabel = string.format("%d m", dist)
        data.LastDistValue = dist
        data.LastDistLabel = distanceLabel
    else
        distanceLabel = data.LastDistLabel or string.format("%d m", dist)
    end

    local hp=ESPShared.SafeNumber(healthPct,1.0,0.0,1.0)
    if hp < 0 then hp = 0 end
    if hp > 1 then hp = 1 end
    local healthChanged=data.LastHealthPct~=hp
    if healthChanged then
        local hpColor = g_Botmater_ESPGetHealthColor(hp,isBot)
        pcall(function()
            if data.HealthFill and g_Botmater_ESPValid(data.HealthFill) then
                data.HealthFill:SetBrushColor(hpColor)
            end
        end)
    end

    local bottomLineH = 4.32
    local baseFontSize=ESPShared.SafeNumber(_G.g_Botmater_VIPShotESP.NameFontSize,12,1,96)
    local baseBottomLineH = 3.6
    local fontSize = baseFontSize * (bottomLineH / baseBottomLineH)
    local paddingX    = 5.0
    local paddingY    = 2.0
    local nameHeight  = fontSize + paddingY * 2 + bottomLineH
    local gap=ESPShared.SafeNumber(_G.g_Botmater_VIPShotESP.NameGap,2,0,128)

    local nameChars = #name
    local textWidth = math.max(30.0, nameChars * (fontSize * 0.52))
    local boxWidth  = math.max(50.0, textWidth + paddingX * 2)
    local boxHeight = nameHeight

    local LINE_UP_SHIFT = boxHeight * 0.25

    local baseY = headScreen.Y - boxHeight - gap
    local containerY = baseY - LINE_UP_SHIFT

    local minX,minY,maxX,maxY=ESPShared.CanvasBounds(pc,g_Botmater_ShotESP)
    boxWidth=math.min(boxWidth,math.max(1,maxX-minX-4))
    local x=ESPShared.SafeNumber(headScreen.X-boxWidth*0.5,minX,minX,maxX-boxWidth)
    containerY=ESPShared.SafeNumber(containerY,minY,minY,math.max(minY,maxY-boxHeight))

    -- The meter label remains inside the HUD, including when feet are clipped.
    local anchor=footScreen or headScreen
    local df=ESPShared.SafeNumber(_G.g_Botmater_VIPShotESP.DistanceFontSize,12,1,96)
    local halfW=math.min(math.max(18,#distanceLabel*df*0.30),(maxX-minX)*0.49)
    local halfH=math.min(df*0.7+2,(maxY-minY)*0.49)
    local distAbsX=ESPShared.SafeNumber(anchor.X,headScreen.X,minX+halfW,maxX-halfW)
    local distAbsY=ESPShared.SafeNumber(anchor.Y+ESPShared.SafeNumber(_G.g_Botmater_VIPShotESP.DistanceBelowFeet,14,0,128),
        minY+halfH,minY+halfH,maxY-halfH)
    containerY=math.min(containerY,distAbsY-halfH)
    local distanceY=distAbsY-containerY
    local totalHeight=math.max(boxHeight,distanceY+halfH)

    local needsPosUpdate = true
    if data.LastBoxX and math.abs(x - data.LastBoxX) < 0.001
       and math.abs(containerY - data.LastBoxY) < 0.001
       and data.LastBoxW == boxWidth and data.LastDistanceY==distanceY then
        needsPosUpdate = false
    end

    local shownName     = showName and name or ""
    local shownDistance = showDistance and distanceLabel or ""

    pcall(function()
        if data.LastName ~= shownName then
            data.Text:SetText(shownName)
            data.LastName = shownName
        end
        if data.LastDistance ~= shownDistance then
            data.DistanceText:SetText(shownDistance)
            data.LastDistance = shownDistance
        end
    end)

    local lineWidth=boxWidth*0.68
    local lineOffsetX=(boxWidth-lineWidth)*0.5
    local healthWidth=lineWidth*hp
    if healthWidth<1 then healthWidth=0 end
    local geometryChanged=data.GeometryWidth~=boxWidth or data.GeometryHeight~=boxHeight
    if geometryChanged or healthChanged then
        local ok=pcall(function()
            if geometryChanged then
                data.HealthBgSlot:SetPosition(g_Botmater_ESPV2(lineOffsetX,boxHeight-bottomLineH))
                data.HealthBgSlot:SetSize(g_Botmater_ESPV2(lineWidth,bottomLineH))
                data.HealthFillSlot:SetPosition(g_Botmater_ESPV2(lineOffsetX,boxHeight-bottomLineH))
                data.TextSlot:SetPosition(g_Botmater_ESPV2(boxWidth*0.5,(boxHeight-bottomLineH)*0.5))
            end
            data.HealthFillSlot:SetSize(g_Botmater_ESPV2(healthWidth,bottomLineH))
        end)
        if ok then data.GeometryWidth=boxWidth;data.GeometryHeight=boxHeight;data.LastHealthPct=hp end
    end
    if needsPosUpdate then
        local ok=pcall(function() data.Slot:SetPosition(g_Botmater_ESPV2(x,containerY)) end)
        if ok then data.LastBoxX=x;data.LastBoxY=containerY;data.LastBoxW=boxWidth end
    end
    if data.LayoutW~=boxWidth or data.LayoutH~=totalHeight then
        local ok=pcall(function() data.Slot:SetSize(g_Botmater_ESPV2(boxWidth,totalHeight)) end)
        if ok then data.LayoutW=boxWidth;data.LayoutH=totalHeight end
    end
    local distX=distAbsX-x
    if data.LastDistanceX~=distX or data.LastDistanceY~=distanceY then
        local ok=pcall(function() data.DistanceSlot:SetPosition(g_Botmater_ESPV2(distX,distanceY)) end)
        if ok then data.LastDistanceX=distX;data.LastDistanceY=distanceY end
    end


    if data.LastHealthVis~=showHealth then
        local ok=pcall(function()
            local visibility=showHealth and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed
            data.HealthBg:SetWidgetVisibility(visibility)
            data.HealthFill:SetWidgetVisibility(visibility)
        end)
        if ok then data.LastHealthVis=showHealth end
    end
    if data.LastNameVis ~= showName then
        local ok=pcall(function() data.Text:SetWidgetVisibility(showName and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed) end)
        if ok then data.LastNameVis=showName end
    end
    if data.LastDistVis ~= showDistance then
        local ok=pcall(function() data.DistanceText:SetWidgetVisibility(showDistance and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed) end)
        if ok then data.LastDistVis=showDistance end
    end

    if data.Visible ~= true then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        if ok then data.Visible=true end
    end

    data.FinalX = x
    data.FinalY = containerY
    data.FinalW = boxWidth
    data.FinalH = boxHeight
    data.LineEndX = x + boxWidth * 0.5
    data.LineEndY = containerY + (boxHeight - bottomLineH)
end

local function g_Botmater_ESPScanEnemies()
    local pc = g_Botmater_ESPGetController()
    local me = g_Botmater_ESPGetLocalCharacter()
    if not pc or not me then
        g_Botmater_ShotESP.Enemies = {}
        g_Botmater_ShotESP.RealCount = 0
        g_Botmater_ShotESP.BotCount = 0
        return nil
    end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    if not myLoc then
        g_Botmater_ShotESP.Enemies = {}
        g_Botmater_ShotESP.RealCount = 0
        g_Botmater_ShotESP.BotCount = 0
        return pc
    end
    local myTeam = g_Botmater_ESPGetTeamID(me)

    local list = {}
    local realCount = 0
    local botCount = 0
    local pawns=ESPShared.GetFramePawns()
    if not pawns then return pc end
    if pawns then
        for _, character in pairs(pawns) do
            if character~=me and ESPShared.GetFrameRecord(character).Alive and ESPShared.Events.Counted(character) then
                local team = g_Botmater_ESPGetTeamID(character)
                if myTeam == nil or team == nil or tostring(team) ~= tostring(myTeam) then
                    local loc = ESPShared.GetFrameRecord(character).Location
                    local dist = ESPShared.DistanceMetersFrom(ESPShared.GetFrameRecord(character),myLoc)
                    if dist <= (tonumber(_G.g_Botmater_VIPShotESP.MaxRangeMeters) or 300.0) then
                        local isBot = g_Botmater_ESPIsBot(character)
                        local k = g_Botmater_ESPGetPlayerKey(character)
                        if k then
                            list[#list+1] = {Character=character, Key=k, IsBot=isBot, Distance=dist}
                            if isBot then botCount = botCount + 1 else realCount = realCount + 1 end
                        end
                    end
                end
            end
        end
    end
    local maxRendered = math.floor(ESPShared.SafeNumber(_G.g_Botmater_VIPShotESP.MaxRendered,10,1,64))
    if #list > maxRendered then
        table.sort(list,function(a,b)
            if a.Distance==b.Distance then return a.Key<b.Key end
            return a.Distance<b.Distance
        end)
    end
    g_Botmater_ShotESP.Enemies = list
    g_Botmater_ShotESP.RealCount = realCount
    g_Botmater_ShotESP.BotCount = botCount
    return pc
end

local function g_Botmater_ESPPrune(active,alive)
    alive=alive or active
    for _,registry in ipairs({g_Botmater_ShotESP.Lines,g_Botmater_ShotESP.Names}) do
        for key,data in pairs(registry) do
            if not active[key] and g_Botmater_ESPDestroyWidgetData(data) then registry[key]=nil end
        end
    end
    for key in pairs(g_Botmater_ShotESP._BotCache or {}) do if not alive[key] then g_Botmater_ShotESP._BotCache[key]=nil end end
    for key in pairs(g_Botmater_ShotESP.LastProjected) do if not alive[key] then g_Botmater_ShotESP.LastProjected[key]=nil end end
end

ESPShared.Events.Clearers[#ESPShared.Events.Clearers+1]=function(actor)
    ESPShared.Events.ClearIn(g_Botmater_ShotESP,g_Botmater_ESPPrune,actor)
end

local g_Botmater_EnemyCounter = {
    Container = nil,
    Slot = nil,
    PlayerBG = nil,
    BotBG = nil,
    PlayerText = nil,
    BotText = nil,
    Width = 218.4,
    Height = 33.6,
    OffsetY = 22.5, -- If V2 counter is visible, shift V1 down to avoid overlap.
    FontSize = 13,
    FontScale = 1.2, -- Exact 20% glyph growth; native font Size is an integer.
    _LastPlayers = -1,
    _LastBots = -1,
    _PosVec = nil,
    _LastPosX = nil,
    _LastPosY = nil,
    CanvasCenterX = 0.0,
    CanvasCenterY = 0.0,
}

local function g_Botmater_CounterTextColor(widget,color)
    g_vipserver_ESPSetTextColor(widget,color)
end

local function g_Botmater_CounterCreate()
    if V1Cleanup.Count>=V1Cleanup.AdmissionLimit then return false end
    if g_Botmater_EnemyCounter.Container and slua.isValid(g_Botmater_EnemyCounter.Container) then
        return true
    end
    local canvas = g_Botmater_ESPGetCanvas()
    if not canvas or not g_Botmater_ESPValid(canvas) then return false end

    local W, H = g_Botmater_EnemyCounter.Width, g_Botmater_EnemyCounter.Height
    local halfW = W * 0.5

    local Container, PlayerBG, BotBG, PlayerText, BotText = nil, nil, nil, nil, nil
    pcall(function() Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not Container or not slua.isValid(Container) then return false end
    pcall(function() PlayerBG = CGame:NewObjectFromPath("/Script/UMG.Border", Container) end)
    pcall(function() BotBG = CGame:NewObjectFromPath("/Script/UMG.Border", Container) end)
    pcall(function() PlayerText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    pcall(function() BotText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)

    if not PlayerBG or not BotBG or not PlayerText or not BotText
        or not slua.isValid(PlayerBG) or not slua.isValid(BotBG)
        or not slua.isValid(PlayerText) or not slua.isValid(BotText) then
        V1Cleanup.Retire(Container)
        return false
    end

    pcall(function()
        PlayerBG:SetBrushColor(CACHE_COUNTER_PLAYER_BG)
        PlayerBG:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        BotBG:SetBrushColor(CACHE_COUNTER_BOT_BG)
        BotBG:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)

    local pbgSlot, bbgSlot = nil, nil
    pcall(function() pbgSlot = Container:AddChildToCanvas(PlayerBG) end)
    pcall(function() bbgSlot = Container:AddChildToCanvas(BotBG) end)
    if not pbgSlot or not bbgSlot then
        V1Cleanup.Retire(Container)
        return false
    end

    pcall(function()
        pbgSlot:SetAutoSize(false)
        pbgSlot:SetPosition(g_Botmater_ESPV2(0, 0))
        pbgSlot:SetSize(g_Botmater_ESPV2(halfW, H))
        pbgSlot:SetZOrder(0)
        bbgSlot:SetAutoSize(false)
        bbgSlot:SetPosition(g_Botmater_ESPV2(halfW, 0))
        bbgSlot:SetSize(g_Botmater_ESPV2(halfW, H))
        bbgSlot:SetZOrder(0)
    end)

    pcall(function()
        PlayerText:SetText("REAL: 0")
        BotText:SetText("BOT: 0")
        g_vipserver_ESPSetFont(PlayerText,g_Botmater_EnemyCounter.FontSize,0)
        g_vipserver_ESPSetFont(BotText,g_Botmater_EnemyCounter.FontSize,0)
        local scale=g_Botmater_EnemyCounter.FontScale
        PlayerText:SetRenderTransformPivot(g_Botmater_ESPV2(0.5,0.5))
        BotText:SetRenderTransformPivot(g_Botmater_ESPV2(0.5,0.5))
        PlayerText:SetRenderScale(g_Botmater_ESPV2(scale,scale))
        BotText:SetRenderScale(g_Botmater_ESPV2(scale,scale))
        PlayerText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        BotText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)

    g_Botmater_CounterTextColor(PlayerText, CACHE_COUNTER_PLAYER_TEXT)
    g_Botmater_CounterTextColor(BotText, CACHE_COUNTER_BOT_TEXT)

    local ptSlot, btSlot = nil, nil
    pcall(function() ptSlot = Container:AddChildToCanvas(PlayerText) end)
    pcall(function() btSlot = Container:AddChildToCanvas(BotText) end)
    if ptSlot then
        pcall(function()
            ptSlot:SetAutoSize(true)
            ptSlot:SetAlignment(g_Botmater_ESPV2(0.5, 0.5))
            ptSlot:SetPosition(g_Botmater_ESPV2(halfW * 0.5, H * 0.5))
            ptSlot:SetZOrder(2)
        end)
    end
    if btSlot then
        pcall(function()
            btSlot:SetAutoSize(true)
            btSlot:SetAlignment(g_Botmater_ESPV2(0.5, 0.5))
            btSlot:SetPosition(g_Botmater_ESPV2(halfW + halfW * 0.5, H * 0.5))
            btSlot:SetZOrder(2)
        end)
    end

    local mainSlot = nil
    pcall(function() mainSlot = canvas:AddChildToCanvas(Container) end)
    if not mainSlot then
        V1Cleanup.Retire(Container)
        return false
    end
    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetSize(g_Botmater_ESPV2(W, H))
        mainSlot:SetZOrder(50)
    end)

    g_Botmater_EnemyCounter.Container = Container
    g_Botmater_EnemyCounter.Slot = mainSlot
    g_Botmater_EnemyCounter.PlayerBG = PlayerBG
    g_Botmater_EnemyCounter.BotBG = BotBG
    g_Botmater_EnemyCounter.PlayerText = PlayerText
    g_Botmater_EnemyCounter.BotText = BotText
    g_Botmater_EnemyCounter._LastPlayers = -1
    g_Botmater_EnemyCounter._LastBots = -1
    g_Botmater_EnemyCounter._PosVec = nil
    g_Botmater_EnemyCounter._LastPosX = nil
    g_Botmater_EnemyCounter._LastPosY = nil

    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    return true
end

local function g_Botmater_CounterUpdatePosition(pc)
    local slot = g_Botmater_EnemyCounter.Slot
    if not slot or not slua.isValid(slot) then return end
    if not pc or not g_Botmater_ESPValid(pc) then return end

    local canvasW, canvasH = g_Botmater_ESPGetCanvasLocalSize()
    if not canvasW or not canvasH then
        local vw, vh = g_Botmater_ESPViewport(pc)
        if not vw or vw <= 200 then return end
        local sx = g_Botmater_ShotESP.CanvasScaleX or 1.0
        local sy = g_Botmater_ShotESP.CanvasScaleY or 1.0
        local ox = g_Botmater_ShotESP.CanvasOffsetX or 0.0
        local oy = g_Botmater_ShotESP.CanvasOffsetY or 0.0
        canvasW = (vw * sx) - ox
        canvasH = (vh * sy) - oy
    end

    if not canvasW or not canvasH then return end

    local canvasCenterX = canvasW * 0.5
    local canvasCenterY = g_Botmater_EnemyCounter.OffsetY
    if _G.g_vipserver_ESPOptions.Counter then canvasCenterY=106 end

    local x = canvasCenterX - g_Botmater_EnemyCounter.Width * 0.5
    local y = canvasCenterY

    g_Botmater_EnemyCounter.CanvasCenterX = canvasCenterX
    g_Botmater_EnemyCounter.CanvasCenterY = canvasCenterY + g_Botmater_EnemyCounter.Height * 0.5

    local lx, ly = g_Botmater_EnemyCounter._LastPosX, g_Botmater_EnemyCounter._LastPosY
    if lx ~= nil and ly ~= nil and math.abs(lx - x) < 0.1 and math.abs(ly - y) < 0.1 then return end
    g_Botmater_EnemyCounter._PosVec = g_Botmater_ESPV2(x, y)
    local ok = pcall(function() slot:SetPosition(g_Botmater_EnemyCounter._PosVec) end)
    if ok then
        g_Botmater_EnemyCounter._LastPosX = x
        g_Botmater_EnemyCounter._LastPosY = y
    end
end

local function g_Botmater_GetLineOrigin(pc)
    if _G.g_Botmater_ESPOptions.EnemyCounter then
        g_Botmater_CounterUpdatePosition(pc)
        return g_Botmater_ESPV2(g_Botmater_EnemyCounter.CanvasCenterX,g_Botmater_EnemyCounter.CanvasCenterY+g_Botmater_EnemyCounter.Height*0.5)
    end
    local width=g_Botmater_ESPGetCanvasLocalSize()
    if not width then
        local vw=g_Botmater_ESPViewport(pc)
        width=(vw or 2400)*g_Botmater_ShotESP.CanvasScaleX+g_Botmater_ShotESP.CanvasOffsetX
    end
    local top=_G.g_vipserver_ESPOptions.Counter and 106 or g_Botmater_EnemyCounter.OffsetY
    return g_Botmater_ESPV2(width*0.5,top+g_Botmater_EnemyCounter.Height)
end

local function g_Botmater_CounterSetCounts(realCount, botCount)
    realCount = tonumber(realCount) or 0
    botCount = tonumber(botCount) or 0
    if g_Botmater_EnemyCounter._LastPlayers ~= realCount
        and g_Botmater_EnemyCounter.PlayerText and slua.isValid(g_Botmater_EnemyCounter.PlayerText) then
        local ok, applied = pcall(function()
            return g_Botmater_EnemyCounter.PlayerText:SetText(string.format("REAL: %d", realCount)) ~= false
        end)
        if ok and applied then g_Botmater_EnemyCounter._LastPlayers = realCount end
    end
    if g_Botmater_EnemyCounter._LastBots ~= botCount
        and g_Botmater_EnemyCounter.BotText and slua.isValid(g_Botmater_EnemyCounter.BotText) then
        local ok, applied = pcall(function()
            return g_Botmater_EnemyCounter.BotText:SetText(string.format("BOT: %d", botCount)) ~= false
        end)
        if ok and applied then g_Botmater_EnemyCounter._LastBots = botCount end
    end
end

local function g_Botmater_CounterStart(pc)
    if not g_Botmater_CounterCreate() then return end
    pcall(function()
        g_Botmater_EnemyCounter.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    g_Botmater_CounterUpdatePosition(pc)
end

local function g_Botmater_CounterStop()
    local container = g_Botmater_EnemyCounter.Container
    g_Botmater_EnemyCounter.Container = nil
    g_Botmater_EnemyCounter.Slot = nil
    g_Botmater_EnemyCounter.PlayerBG = nil
    g_Botmater_EnemyCounter.BotBG = nil
    g_Botmater_EnemyCounter.PlayerText = nil
    g_Botmater_EnemyCounter.BotText = nil
    g_Botmater_EnemyCounter._LastPlayers = -1
    g_Botmater_EnemyCounter._LastBots = -1
    g_Botmater_EnemyCounter._PosVec = nil
    g_Botmater_EnemyCounter._LastPosX = nil
    g_Botmater_EnemyCounter._LastPosY = nil
    g_Botmater_EnemyCounter.CanvasCenterX = 0.0
    g_Botmater_EnemyCounter.CanvasCenterY = 0.0
    if g_Botmater_ESPValid(container) then
        V1Cleanup.Retire(container)
    end
end

-- Each actor update is isolated. Death cleanup runs before projection/drawing.
local function g_Botmater_ESPRenderActor(item,pc,opt,origin,now)
    local state=g_Botmater_ShotESP
    local c,key,isBot=item.Character,item.Key,item.IsBot
    local head,feet,onScreen,reason=ESPShared.Events.Project(pc,c,state)
    if not onScreen then
        local last=state.LastProjected[key]
        if reason=="unavailable" and last and now>=last and now-last<=0.08 then
            state.Active[key]=true
        else
            state.LastProjected[key]=nil
        end
        return
    end
    local anchor=head or feet
    if not anchor then return end
    state.Active[key]=true;state.LastProjected[key]=now
    local color=g_Botmater_ESPGetColors(isBot)
    local hp=opt.Health and g_Botmater_ESPGetHealthPct(c) or 1
    g_Botmater_ESPUpdateNameTag(key,c,anchor,feet,isBot,item.Distance,hp,pc)
    local line=state.Lines[key]
    if opt.Line and (not line or line.Broken or not g_Botmater_ESPValid(line.Widget)
        or not g_Botmater_ESPValid(line.Slot)) then
        if not g_Botmater_ESPDestroyWidgetData(line) then return end
        line=g_Botmater_ESPCreateLine(color);state.Lines[key]=line
    end
    if opt.Line and line then
        local colorKey=isBot and "B" or "P"
        if line.ColorKey~=colorKey then
            local ok=pcall(function() line.Widget:SetBrushColor(color) end)
            if ok then line.ColorKey=colorKey end
        end
        local tag=state.Names[key]
        local x,y=tag and tag.LineEndX or anchor.X,tag and tag.LineEndY or anchor.Y
        g_Botmater_ESPDrawLine(line,origin.X,origin.Y,x,y,
            ESPShared.SafeNumber(_G.g_Botmater_VIPShotESP.TracerThickness,1,0.1,12))
    elseif line then g_Botmater_ESPHide(line) end
end

local function g_Botmater_ESPDrawCandidates(pc,opt,now)
    local state=g_Botmater_ShotESP
    local origin=g_Botmater_GetLineOrigin(pc)
    local limit=math.floor(ESPShared.SafeNumber(_G.g_Botmater_VIPShotESP.MaxRendered,10,1,64))
    for i,item in ipairs(state.Enemies) do
        if i>limit then break end
        local ok,err=pcall(g_Botmater_ESPRenderActor,item,pc,opt,origin,now)
        if not ok then
            state.Active[item.Key]=nil;state.LastProjected[item.Key]=nil
            local f=_G.LunarFeatures
            if f and f.Error then f.Error("V1.Actor",err) end
        end
    end
end

local function g_Botmater_ESPUpdate()
    local state=g_Botmater_ShotESP
    local opt=_G.g_Botmater_ESPOptions
    local details=opt and (opt.Name or opt.Line or opt.Health or opt.Distance)
    local counter=opt and opt.EnemyCounter
    local now=g_Botmater_ESPNow()
    V1Cleanup.Pump(now)
    if not _G.g_Botmater_VIPShotESP.Enabled or (not details and not counter) then
        g_Botmater_ESPResetWidgets();g_Botmater_CounterStop();return
    end
    local world=g_Botmater_ESPWorld()
    ESPShared.Events.WorldChanged(world)
    if world~=state.LastWorld then
        g_Botmater_ESPResetWidgets();g_Botmater_CounterStop();state.LastWorld=world
    end
    local oldCanvas=state.Canvas
    local canvas=g_Botmater_ESPGetCanvas()
    if canvas~=oldCanvas then g_Botmater_CounterStop() end
    if not canvas then return end
    local pc=g_Botmater_ESPGetController()
    if now<state.LastScanClock or now-state.LastScanClock>=(tonumber(_G.g_Botmater_VIPShotESP.ScanInterval) or 0.05) then
        pc=g_Botmater_ESPScanEnemies() or pc;state.LastScanClock=now
    end
    pc=pc or g_Botmater_ESPGetController()
    if not pc then g_Botmater_ESPResetWidgets();g_Botmater_CounterStop();return end
    local location=ESPShared.GetFrameRecord(g_Botmater_ESPGetLocalCharacter()).Location
    local active,alive=state.Active,state.Alive
    state.RealCount,state.BotCount=g_vipserver_ESPFilterEnemies(state.Enemies,location,
        _G.g_Botmater_VIPShotESP.MaxRangeMeters,alive)
    -- Prune confirmed excluded actors BEFORE any fallible drawing operation.
    g_Botmater_ESPPrune(alive,alive)
    for k in pairs(active) do active[k]=nil end
    if now<state.LastTransformClock or now-state.LastTransformClock>=(tonumber(_G.g_Botmater_VIPShotESP.TransformInterval) or 0.033) then
        g_Botmater_ESPUpdateCanvasTransform(pc);state.LastTransformClock=now
    end
    if counter then
        pcall(g_Botmater_CounterStart,pc)
        pcall(g_Botmater_CounterSetCounts,state.RealCount,state.BotCount)
    else g_Botmater_CounterStop() end
    local ok,err=true,nil
    if details then ok,err=pcall(g_Botmater_ESPDrawCandidates,pc,opt,now) end
    -- This path also executes after an origin/projection/vector error.
    g_Botmater_ESPPrune(active,alive)
    if not ok then
        local f=_G.LunarFeatures
        if f and f.Error then f.Error("V1.Draw",err) end
    end
end

local F=_G.LunarFeatures
F.V1={State=g_Botmater_ShotESP,Counter=g_Botmater_EnemyCounter,Tick=g_Botmater_ESPUpdate,
    Cleanup=V1Cleanup,
    Reset=function() g_Botmater_ESPResetWidgets();g_Botmater_CounterStop() end,
    Refresh=function() g_Botmater_ShotESP.LastScanClock=-999;g_Botmater_ShotESP.LastTransformClock=-999 end}
end

-- Controls live entirely in the native game settings page.

-- Additional aim modes share the managed scheduler. No timer is created here.
do
    local F=_G.LunarFeatures
    local MathLib,Layout,HealthStates,PawnStates
    pcall(function() MathLib=import("KismetMathLibrary") end)
    pcall(function() Layout=import("WidgetLayoutLibrary") end)
    pcall(function() HealthStates=import("ECharacterHealthStatus") end)
    pcall(function() PawnStates=import("EPawnState") end)
    local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
    local function get(obj,key)
        if not obj then return nil end
        local ok,v=pcall(function() return obj[key] end)
        if ok then return v end
    end
    local function call(obj,key,...)
        local method=get(obj,key)
        if type(method)~="function" then return nil end
        local ok,v=pcall(method,obj,...)
        if ok then return v end
    end
    local function valid(obj) return obj and g_vipserver_ESPValid(obj) end
    local function pos(v)
        if v and finite(v.X) and finite(v.Y) and finite(v.Z) then return {X=v.X,Y=v.Y,Z=v.Z} end
    end
    local function nativeVector(v) return g_vipserver_ESPV3(v.X,v.Y,v.Z) end
    local function team(actor)
        local id=call(actor,"GetTeamID") or get(actor,"TeamID")
        if id==nil then
            local state=call(actor,"GetPlayerStateSafety")
            id=call(state,"GetTeamID") or get(state,"TeamID")
        end
        return id
    end
    local function dead(actor)
        if not valid(actor) then return true end
        local hp=call(actor,"GetHealth") or get(actor,"Health") or get(actor,"HP")
        if finite(hp) and hp<=0 then return true end
        if get(actor,"bIsDead")==true or get(actor,"bDead")==true or get(actor,"bIsDeadFlag")==true then return true end
        if HealthStates and HealthStates.FinishedLastBreath~=nil and get(actor,"HealthStatus")==HealthStates.FinishedLastBreath then return true end
        if PawnStates and PawnStates.Dead~=nil and call(actor,"HasPawnState",PawnStates.Dead)==true then return true end
        return false
    end
    local function weapon(player)
        local w=call(player,"GetCurrentWeapon") or get(player,"CurrentWeapon")
        if not valid(w) then
            local wm=get(player,"WeaponManagerComponent")
            w=get(wm,"CurrentWeaponReplicated") or get(wm,"CurrentWeapon")
        end
        return valid(w) and w or nil
    end
    local function kind(w)
        local name=call(w,"GetWeaponName")
        if type(name)~="string" or not name:find("%S") then return "unknown" end
        name=name:lower()
        if name:find("mortar",1,true) or name:find("cối",1,true) or name:find("cỐi",1,true) then return "mortar" end
        return "other"
    end
    local function context()
        local pc=g_vipserver_ESPGetController()
        local player=g_vipserver_ESPGetLocalCharacter()
        if valid(pc) and not dead(player) then return g_vipserver_ESPWorld(),pc,player,weapon(player) end
    end
    local function pelvis(actor)
        local p=pos(call(actor,"GetBonePos","pelvis",{X=0,Y=0,Z=0}))
        if not p or (p.X==0 and p.Y==0 and p.Z==0) then p=pos(call(actor,"GetSocketLocation","pelvis")) end
        if not p or (p.X==0 and p.Y==0 and p.Z==0) then p=pos(call(actor,"K2_GetActorLocation")) end
        return p
    end
    local function allPlayers()
        local list
        pcall(function() if GameplayData.GetAllPlayerCharacters then list=GameplayData.GetAllPlayerCharacters() end end)
        return type(list)=="table" and list or {}
    end
    local function viewport(pc)
        local w,h=g_vipserver_ESPViewport(pc)
        if not finite(w) or w<=0 or not finite(h) or h<=0 then return 1920,1080 end
        return w,h
    end
    local function project(pc,p)
        local screen=FVector2D(0,0)
        local ok,yes=pcall(function() return pc:ProjectWorldLocationToScreen(nativeVector(p),screen,false) end)
        if ok and (yes==true or yes==1) and finite(screen.X) and finite(screen.Y) then return screen.X,screen.Y end
    end
    local function camera(pc,player,fallback)
        local cm=call(pc,"GetPlayerCameraManager")
        if not valid(cm) then pcall(function() cm=GameplayStaticsESP.GetPlayerCameraManager(pc,0) end) end
        return pos(call(cm,"GetCameraLocation")) or fallback or pos(call(player,"K2_GetActorLocation"))
    end
    local function rotation(pc,target,source)
        if not target or not finite(target.Pitch) or not finite(target.Yaw) or not finite(target.Roll) then return false end
        local current=call(pc,"GetControlRotation")
        if current and finite(current.Pitch) and finite(current.Yaw) and finite(current.Roll or 0)
            and math.abs((target.Pitch-current.Pitch+180)%360-180)<0.00001
            and math.abs((target.Yaw-current.Yaw+180)%360-180)<0.00001
            and math.abs(target.Roll-(current.Roll or 0))<0.00001 then return true end
        local ok,accepted=pcall(function() return pc:SetControlRotation(target,source) end)
        if not ok then F.Error(source,accepted) end
        return ok and accepted~=false
    end
    -- A failed restore survives a script reload and remains eligible for retry.
    local pending=_G.__LunarAim2RestorePending or {}
    _G.__LunarAim2RestorePending=pending
    local A={Target=nil,Enabled=false,Due=0,LastTime=nil,Records=pending,RestoreErrors={}}
    F.Aim2=A
    local fields={"RecoilKickADS","GameDeviationFactor","GameDeviationAccuracy"}
    local function restore()
        for obj,record in pairs(A.Records) do
            if not valid(obj) then A.Records[obj]=nil;A.RestoreErrors[obj]=nil
            else
                for key,value in pairs(record) do
                    local ok,err=true,nil
                    if get(obj,key)~=value then ok,err=pcall(function() obj[key]=value end) end
                    if ok and get(obj,key)==value then record[key]=nil
                    elseif not A.RestoreErrors[obj] or not A.RestoreErrors[obj][key] then
                        A.RestoreErrors[obj]=A.RestoreErrors[obj] or {};A.RestoreErrors[obj][key]=true
                        F.Error("Aim2.Restore."..key,err or "native field did not accept restoration")
                    end
                end
                if next(record)==nil then A.Records[obj]=nil;A.RestoreErrors[obj]=nil end
            end
        end
    end
    function A.Stop()
        restore();A.Target=nil;A.Enabled=false;A.LastTime=nil;A.World=nil;A.PC=nil;A.Player=nil;A.Weapon=nil;A.Entity=nil;A.Due=0;A.Unsupported=nil;A.ApplyFailed=nil
    end
    function A.NextInterval(now)
        if not F.Settings.Aim2Enabled then return 0.5 end
        return math.max(0.001,A.Due-(finite(now) and now or F.Now()))
    end
    local function hard(entity)
        if not valid(entity) then return end
        local record=A.Records[entity]
        if not record then record={};A.Records[entity]=record end
        for _,key in ipairs(fields) do
            local current=get(entity,key)
            if finite(current) then
                if record[key]==nil then record[key]=current end
                if current~=0.01 then
                    local ok,err=pcall(function() entity[key]=0.01 end)
                    if not ok and (not A.ApplyFailed or not A.ApplyFailed[key]) then
                        A.ApplyFailed=A.ApplyFailed or {};A.ApplyFailed[key]=true;F.Error("Aim2.Apply."..key,err)
                    end
                end
            elseif not A.Unsupported or not A.Unsupported[key] then
                A.Unsupported=A.Unsupported or {};A.Unsupported[key]=true
                F.Error("Aim2.Unsupported",key.." is unreadable; left unchanged")
            end
        end
    end
    function A.Tick(now)
        now=finite(now) and now or F.Now()
        if not F.Settings.Aim2Enabled then if A.Player or next(A.Records) then A.Stop() end;return false end
        local world,pc,player,w=context()
        if not world or not w or kind(w)=="mortar" then A.Stop();A.Due=now+0.5;return false end
        local entity=get(w,"ShootWeaponEntityComp")
        if A.World~=world or A.PC~=pc or A.Player~=player or A.Weapon~=w or A.Entity~=entity then
            A.Stop();A.World=world;A.PC=pc;A.Player=player;A.Weapon=w;A.Entity=entity
        end
        if now<A.Due-0.000001 and (not A.LastTime or now>=A.LastTime) then return false end
        local dt=A.LastTime and now-A.LastTime or 0.5
        if not finite(dt) or dt<=0 then dt=0.5 end
        A.LastTime=now;A.Due=now+0.5;hard(entity)
        if get(player,"bIsWeaponAiming")~=true then A.Target=nil;A.Enabled=false;A.Due=now+0.2;return false end
        if not MathLib or not MathLib.FindLookAtRotation then return false end
        local myTeam=team(player)
        if myTeam==nil then return false end
        local width,height=viewport(pc)
        local scale=1
        pcall(function() if Layout and Layout.GetViewportScale then local s=Layout.GetViewportScale(pc);if finite(s) and s>0 then scale=s end end end)
        -- Reference circle is 150 UI units, with its inner 70% used for selection.
        local rx,ry=105*scale,105*scale
        local best,bestScore=nil,math.huge
        for _,enemy in pairs(allPlayers()) do
            if enemy~=player and not dead(enemy) then
                local enemyTeam=team(enemy)
                if enemyTeam~=nil and tostring(enemyTeam)~=tostring(myTeam) then
                    local p=pelvis(enemy)
                    if p then
                        local x,y=project(pc,p)
                        if x and x>=0 and y>=0 and x<=width and y<=height then
                            local dx,dy=(x-width/2)/rx,(y-height/2)/ry
                            local score=dx*dx+dy*dy
                            if finite(score) and score<=1 and score<bestScore then best,bestScore=enemy,score end
                        end
                    end
                end
            end
        end
        A.Target=best;A.Enabled=best~=nil
        if not best then return false end
        local loc,p=camera(pc,player),pelvis(best)
        if not loc or not p then return false end
        local desired=MathLib.FindLookAtRotation(nativeVector(loc),nativeVector(p))
        local current=call(pc,"GetControlRotation")
        if not desired or not current or not finite(desired.Pitch) or not finite(desired.Yaw) or not finite(current.Pitch) or not finite(current.Yaw) then return false end
        local dp,dy=(desired.Pitch-current.Pitch+180)%360-180,(desired.Yaw-current.Yaw+180)%360-180
        local dist=math.sqrt(dp*dp+dy*dy)
        local step=90*math.min(dt,0.5)
        local fraction=dist>step and step/dist or 1
        local final={Pitch=current.Pitch+dp*fraction,Yaw=current.Yaw+dy*fraction,Roll=current.Roll or 0}
        local w2,pc2,p2,wCurrent=context()
        if not F.Settings.Aim2Enabled or world~=w2 or pc~=pc2 or player~=p2 or w~=wCurrent or get(player,"bIsWeaponAiming")~=true or dead(best) then A.Stop();return false end
        return rotation(pc,final,"CircleAim")
    end
    local M={Target=nil,Candidates={},ScanDue=0,Due=0,LastTime=nil,Status="inactive",ActivePlaced=false}
    F.Mortar=M
    function M.Stop()
        M.Target=nil;M.Candidates={};M.ScanDue=0;M.Due=0;M.LastTime=nil;M.World=nil;M.PC=nil;M.Player=nil;M.Weapon=nil;M.ActivePlaced=false;M.Status="inactive"
    end
    local function distance(player,target)
        local d=call(player,"GetDistanceTo",target)
        if finite(d) and d>=0 then return d end
        local a,b=pos(call(player,"K2_GetActorLocation")),pos(call(target,"K2_GetActorLocation"))
        if a and b then local dx,dy,dz=a.X-b.X,a.Y-b.Y,a.Z-b.Z;d=math.sqrt(dx*dx+dy*dy+dz*dz);if finite(d) then return d end end
    end
    local function enemy(player,target)
        if target==player or dead(target) then return false end
        local mine,theirs=team(player),team(target)
        if mine~=nil and theirs~=nil and tostring(mine)==tostring(theirs) then return false end
        local d=distance(player,target)
        return finite(d) and d<=200000
    end
    local function trajectory(launch,V,G,target)
        if not pos(launch) or not pos(target) or not finite(V) or V<=0 or not finite(G) or G<=0 then return false,45,0,0 end
        local dx=math.max(500,math.sqrt((target.X-launch.X)^2+(target.Y-launch.Y)^2)-80)
        local dy=target.Z-launch.Z
        local minVSq=G*(dy+math.sqrt(dx*dx+dy*dy))
        if not finite(dx) or not finite(minVSq) then return false,45,0,0 end
        if V*V<minVSq then V=math.sqrt(math.max(0,minVSq))+100 end
        local v2=V*V
        local root=v2*v2-G*(G*dx*dx+2*dy*v2)
        if not finite(root) or root<0 then return false,45,0,dx end
        local rad=math.atan((v2+math.sqrt(root))/(G*dx))
        local deg,tof=math.deg(rad),dx/(V*math.cos(rad))
        if finite(deg) and finite(tof) and tof>0 and deg>=35 and deg<=89.5 then return true,deg,tof,dx end
        return false,45,0,dx
    end
    local function solve(launch,target)
        local okN,aN,tN,dN=trajectory(launch,9070,2744,target)
        local okF,aF,tF,dF=trajectory(launch,12520,3920,target)
        local okU,aU,tU,dU=trajectory(launch,16800,4410,target)
        if okN and dN<=25000 then return true,aN,tN,dN end
        if okF and dF<=40000 then return true,aF,tF,dF end
        if okU then return true,aU,tU,dU end
        if okN then return true,aN,tN,dN end
        return false,45,0,dN
    end
    M.SolveTrajectory=solve
    local function predict(target,base,launch)
        local velocity=call(target,"GetVelocity")
        if not velocity or not finite(velocity.X) or not finite(velocity.Y) or math.abs(velocity.X)+math.abs(velocity.Y)<0.01 then return base end
        local predicted={X=base.X,Y=base.Y,Z=base.Z}
        local fallback
        for _=1,2 do
            local ok,a,tof,d=solve(launch,predicted)
            if not ok then break end
            fallback={ok,a,tof,d}
            if tof<=0 or tof>15 then break end
            predicted.X=base.X+velocity.X*tof;predicted.Y=base.Y+velocity.Y*tof
            if not pos(predicted) then return base end
        end
        return predicted,fallback
    end
    function M.NextInterval(now)
        if not F.Settings.MortarEnabled then return 0.5 end
        return math.max(0.001,M.Due-(finite(now) and now or F.Now()))
    end
    function M.Tick(now)
        now=finite(now) and now or F.Now()
        if not F.Settings.MortarEnabled then if M.Player then M.Stop() end;return false end
        local world,pc,player,w=context()
        if not world or not w or kind(w)~="mortar" or get(w,"MortarState")~=2 then
            M.Stop();M.Status="not_placed_mortar";M.Due=now+0.5;return false
        end
        if M.World~=world or M.PC~=pc or M.Player~=player or M.Weapon~=w then
            M.Stop();M.World=world;M.PC=pc;M.Player=player;M.Weapon=w
        end
        if now<M.Due-0.000001 and (not M.LastTime or now>=M.LastTime) then return false end
        M.LastTime=now;M.Due=now+0.5;M.ActivePlaced=true;M.Status="targeting"
        if not enemy(player,M.Target) then
            M.Target=nil
            if now>=M.ScanDue then M.Candidates=allPlayers();M.ScanDue=now+0.25 end
            local width,height=viewport(pc)
            local best,score=nil,math.huge
            for _,target in pairs(M.Candidates) do
                if enemy(player,target) then
                    local p=pelvis(target)
                    if p then local x,y=project(pc,p)
                        if x and x>0 and y>0 then
                            local dx,dy=x-width/2,y-height/2
                            local d=dx*dx+dy*dy
                            if finite(d) and d<score and d<=(3.6*width/2)^2 then best,score=target,d end
                        end
                    end
                end
            end
            M.Target=best
        end
        local target=M.Target
        if not target then M.Status="no_target";return false end
        local base,launch=pelvis(target),pos(call(player,"K2_GetActorLocation"))
        if not base or not launch then M.Status="position_unavailable";return false end
        launch.Z=launch.Z+50
        local predicted,fallback=predict(target,base,launch)
        local ok,angle,tof=solve(launch,predicted)
        if not ok and fallback then ok,angle,tof=fallback[1],fallback[2],fallback[3] end
        if not ok or not finite(tof) or not finite(angle) then M.Status="unreachable";return false end
        if not MathLib or not MathLib.FindLookAtRotation then M.Status="math_unavailable";return false end
        local desired=MathLib.FindLookAtRotation(nativeVector(camera(pc,player,launch)),nativeVector(predicted))
        local current=call(pc,"GetControlRotation")
        if not desired or not current or not finite(desired.Yaw) or not finite(current.Pitch) or not finite(current.Yaw) then return false end
        local pitch=((angle-45)/43)*90-60
        local dp,dy=(pitch-current.Pitch+180)%360-180,(desired.Yaw-current.Yaw+180)%360-180
        local final={Pitch=current.Pitch+dp,Yaw=current.Yaw+dy,Roll=0}
        local world2,pc2,player2,w2=context()
        if not F.Settings.MortarEnabled or world2~=world or pc2~=pc or player2~=player or w2~=w or get(w,"MortarState")~=2 or not enemy(player,target) then M.Stop();return false end
        local accepted=rotation(pc,final,"MortarAim")
        M.Status=accepted and "rotation_call_accepted" or "rotation_failed"
        return accepted
    end
end

-- All features share the existing ESP render runner. No new repeating timer.
do
    local F=_G.LunarFeatures
    local function checked(fn,area,...)
        local ok,err=pcall(fn,...)
        if not ok then F.Error(area,err) end
    end
    F.V1Due=0;F.AimDue=0;F.IpadDue=0;F.SaveDue=0
    F.Pump=function(now)
        F.TimerClock=g_vipserver_ShotESP.TimerClock
        now=now or F.Now()
        if F.V1 and F.V1.Cleanup then F.V1.Cleanup.Pump(now) end
        local login=_G.LunarLoginRuntime
        if login and login.NeedsUpdate and (not F.LoginDue or now>=F.LoginDue or now<(F.LoginLastClock or now)) then
            checked(login.Update,"Login.Update");F.LoginDue=now+0.5;F.LoginLastClock=now
        end
        if F.Dirty and now>=F.SaveDue then checked(F.Save,"Settings.Save");F.SaveDue=now+0.5 end
        if not (login and login.Authorized) then
            if not F.AuthLocked then
                checked(F.V1.Reset,"V1.Lock");checked(F.Wall.Stop,"Wall.Lock")
                checked(F.Aim2.Stop,"Aim2.Lock");checked(F.Mortar.Stop,"Mortar.Lock")
                _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0;F.AimLastClock=nil
                checked(g_vipserver_ApplyiPadView,"Ipad.Lock")
            end
            F.AuthLocked=true
            if next(F.Aim2.Records) then checked(F.Aim2.Stop,"Aim2.LockRestore") end
            return
        end
        F.AuthLocked=false
        local world=g_vipserver_ESPWorld()
        local pc=g_vipserver_ESPGetController()
        local pawn=g_vipserver_ESPGetLocalCharacter()
        if world~=F.LastWorld or pc~=F.LastPC or pawn~=F.LastPawn then
            if F.LastWorld~=nil and login.WelcomeUI then login.DestroyUI() end
            checked(F.V1.Reset,"V1.Reset")
            checked(F.Wall.Stop,"Wall.Reset")
            checked(F.Aim2.Stop,"Aim2.Reset")
            checked(F.Mortar.Stop,"Mortar.Reset")
            if _G.LunarKick then checked(_G.LunarKick.Stop,"Kick.Reset") end
            F.Wall.ConsoleWorld=nil
            _G.AimTouchVisCache={}
            _G.LunarAimStickyTarget=nil;_G.LunarAimFilter=nil;_G.LunarAimTargetCache=nil
            _G.XthrlenState.aimVelP=nil;_G.XthrlenState.aimVelY=nil
            _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0
            F.AimLastClock=nil
            F.V1Due=0;F.AimDue=0;F.IpadDue=0;F.KickDue=0
            F.LastWorld,F.LastPC,F.LastPawn=world,pc,pawn
        end
        if F.V1.State.Canvas and not g_vipserver_ESPValid(F.V1.State.Canvas) then checked(F.V1.Reset,"V1.CanvasReset");F.V1Due=0 end
        if not pc or not pawn then
            if F.Aim2.Player or next(F.Aim2.Records) then checked(F.Aim2.Stop,"Aim2.NoPlayer") end
            if F.Mortar.Player then checked(F.Mortar.Stop,"Mortar.NoPlayer") end
            if _G.LunarKick and (_G.LunarKick.LastWeapon or next(_G.LunarKick.Records)) then checked(_G.LunarKick.Stop,"Kick.NoPlayer") end
            if not F.V1Disabled then checked(F.V1.Reset,"V1.NoPlayer") end
            F.V1Disabled=true
            return
        end
        local o=_G.g_Botmater_ESPOptions
        local detail=o.Name or o.Line or o.Health or o.Distance
        local active=detail or o.EnemyCounter
        if not active then
            if not F.V1Disabled then checked(F.V1.Reset,"V1.Disable") end
            F.V1Disabled=true
        elseif now>=F.V1Due-0.000001 or (F.V1LastClock and now<F.V1LastClock) then
            F.V1Disabled=false
            checked(F.V1.Tick,"V1.Render")
            F.V1LastClock=now
            local interval=detail and (tonumber(_G.g_Botmater_VIPShotESP.UpdateInterval) or 1/60) or 0.05
            if interval~=interval or interval<=0 or math.abs(interval)==math.huge then interval=1/60 end
            F.V1Due=now+math.max(.001,interval)
            -- Equal render cadences share the V2 deadline, so adding V1 does
            -- not introduce a second phase of native render callbacks.
            local v2=_G.g_vipserver_ESPOptions
            local detailedV2=_G.g_vipserver_VIPShotESP.Enabled and (v2.Name or v2.Line or v2.Box or v2.Health or v2.Distance or v2.Skeleton)
            local shared=g_vipserver_ESPRunnerToken.RenderDue
            if detail and detailedV2 and shared and shared>now and math.abs(interval-(tonumber(_G.g_vipserver_VIPShotESP.UpdateInterval) or 1/60))<.000001 then F.V1Due=shared end
        end
        if F.Settings.Aim2Enabled and (now>=F.Aim2.Due-0.000001 or (F.Aim2.LastTime and now<F.Aim2.LastTime)) then
            checked(F.Aim2.Tick,"Aim2.Tick")
        elseif not F.Settings.Aim2Enabled and next(F.Aim2.Records) and now>=(F.Aim2RestoreDue or 0) then
            checked(F.Aim2.Stop,"Aim2.Restore")
            F.Aim2RestoreDue=now+0.5
        end
        if F.Settings.MortarEnabled and (now>=F.Mortar.Due-0.000001 or (F.Mortar.LastTime and now<F.Mortar.LastTime)) then checked(F.Mortar.Tick,"Mortar.Tick") end

        local aimRunning=F.Settings.AimEnabled or F.Settings.AimSniperScope==true or F.Settings.AimShotgun==true
        if aimRunning then
            if now>=F.AimDue-0.000001 or (F.AimLastTick and now<F.AimLastTick) then
                checked(F.Aim.Tick,"Aim.Render")
                F.AimLastTick=now
                local idleAim=F.Settings.AimSniperScope==true or F.Settings.AimShotgun==true
                -- V9.6: 100 Hz while idle gives small, even steps (smooth glide).
                F.AimDue=now+((pawn and pawn.bIsWeaponFiring) and 0.011 or (idleAim and 0.010 or 0.05))
                -- Keep AimLastClock in idle mode so dt is real; a long pause is
                -- handled inside AimTouch instead of being reset to a fake dt.
                if not (pawn and pawn.bIsWeaponFiring) and not idleAim then F.AimLastClock=nil end
            end
        end
        -- V9.9: kick control aimbot se alag chalta hai (aim off ho to bhi kaam
        -- kare). 20 Hz kaafi hai; recoil fields hold karte hain.
        if F.Settings.KickControl==true then
            if not F.KickDue or now>=F.KickDue-0.000001 then
                checked(_G.LunarKick.Tick,"Kick.Tick",pawn)
                F.KickDue=now+0.05
            end
        elseif _G.LunarKick and _G.LunarKick.LastWeapon then
            checked(_G.LunarKick.Stop,"Kick.Stop")
        end
        if F.Settings.WallEnabled then checked(F.Wall.Tick,"Wall.Tick",now,pawn,pc) end
        if _G.MWConfig.IpadView and now>=F.IpadDue then
            checked(g_vipserver_ApplyiPadView,"Ipad")
            F.IpadDue=now+0.5
        end
        if F.Dirty and now>=F.SaveDue then checked(F.Save,"Settings.Save");F.SaveDue=now+0.5 end
    end
    F.NextInterval=function(now)
        if not (_G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized) then return 0.50 end
        if not F.LastPC or not F.LastPawn then return 0.50 end
        local nextDelay=0.50
        local function due(deadline) nextDelay=math.min(nextDelay,math.max(0.001,(deadline or now)-now)) end
        local o=_G.g_Botmater_ESPOptions
        if o.Name or o.Line or o.Health or o.Distance or o.EnemyCounter then due(F.V1Due) end
        if F.Settings.AimEnabled or F.Settings.AimSniperScope==true or F.Settings.AimShotgun==true then due(F.AimDue) end
        if F.Settings.Aim2Enabled then nextDelay=math.min(nextDelay,F.Aim2.NextInterval(now))
        elseif next(F.Aim2.Records) then due(F.Aim2RestoreDue) end
        if F.Settings.MortarEnabled then nextDelay=math.min(nextDelay,F.Mortar.NextInterval(now)) end
        if F.Settings.KickControl==true then due(F.KickDue or now) end
        if F.Settings.WallEnabled then due(F.Wall.LastTick+0.30);due(F.Wall.LastCleanup+F.Wall.CleanupInterval) end
        if _G.MWConfig.IpadView then due(F.IpadDue) end
        if F.Dirty then due(F.SaveDue) end
        return nextDelay
    end
    F.Wake=function()
        if F.Token.Stopped then return end
        local login=_G.LunarLoginRuntime
        -- Login callbacks use this existing runner; do not wait for its idle deadline.
        if login and login.NeedsUpdate then F.LoginDue=0 end
        F.V1Due=0;F.AimDue=0
        if F.Aim2 then F.Aim2.Due=0 end
        if F.Mortar then F.Mortar.Due=0 end
        F.Wall.LastTick=-999
        local due=g_vipserver_ESPRunnerToken.Due
        if not due or due-g_vipserver_ESPNow()>0.002 then g_vipserver_ESPSchedule(0.001) end
    end
end


-- Settings maintenance uses the working reference's native timer fallbacks.
local g_vipserver_FastRunnerToken = {}
local previousSettingsRunner = _G.__VIPShotFastRunner
if type(previousSettingsRunner) == "table" and previousSettingsRunner.Timer and previousSettingsRunner.Owner then
    pcall(function() previousSettingsRunner.Owner:RemoveGameTimer(previousSettingsRunner.Timer) end)
end
_G.__VIPShotFastRunner = g_vipserver_FastRunnerToken
local function g_vipserver_FastTick()
    if _G.__VIPShotFastRunner ~= g_vipserver_FastRunnerToken then return end
    g_vipserver_EnsureHackMenu()
    local render=_G.__VIPShotESPRunner
    if not render or not render.Due then pcall(g_vipserver_ApplyiPadView) end
end
do
    local token = g_vipserver_FastRunnerToken
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function valid(object)
        if object == nil then return false end
        if slua and type(slua.isValid) == "function" then
            local ok, value = pcall(slua.isValid, object)
            return ok and value == true
        end
        return false
    end
    local function timerOwnerReady(owner)
        return owner ~= nil and (owner == Game or valid(owner) or valid(member(owner, "Object")))
    end
    local function callback()
        if _G.__VIPShotFastRunner ~= token then
            if token.Timer and token.Owner then pcall(function() token.Owner:RemoveGameTimer(token.Timer) end) end
            token.Timer = nil
            return
        end
        g_vipserver_FastTick()
        g_vipserver_StartSettingsMaintenance()
    end
    g_vipserver_StartSettingsMaintenance = function(owner)
        if _G.__VIPShotFastRunner ~= token then return false end
        if token.Pending then return true end
        if token.Timer and (token.Provider == "ticker" or timerOwnerReady(token.Owner)) then return true end
        if token.Timer and token.Owner then pcall(function() token.Owner:RemoveGameTimer(token.Timer) end) end
        token.Timer, token.Owner, token.Provider = nil, nil, nil

        local candidates = {}
        local function add(candidate, kind)
            if not timerOwnerReady(candidate) or type(member(candidate, "AddGameTimer")) ~= "function" then return end
            for _, entry in ipairs(candidates) do if entry.Object == candidate then return end end
            candidates[#candidates + 1] = {Object = candidate, Kind = kind}
        end
        local pc
        pcall(function() if GameplayData.GetPlayerController then pc = GameplayData.GetPlayerController() end end)
        if not valid(pc) then pcall(function() if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end end) end
        add(pc, "controller")
        add(owner, "character")
        add(Game, "game")
        for _, entry in ipairs(candidates) do
            local ok, timer = pcall(function() return entry.Object:AddGameTimer(1.0, true, callback) end)
            if ok and timer then
                token.Timer, token.Owner, token.Provider = timer, entry.Object, entry.Kind
                token.LastError = nil
                g_vipserver_FastTick()
                return true
            end
        end
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker then
            if type(ticker.AddTimer) == "function" then
                local ok, timer = pcall(ticker.AddTimer, 1.0, true, callback)
                if ok and timer then
                    token.Timer, token.Owner, token.Provider = timer, ticker, "ticker"
                    token.LastError = nil
                    return true
                end
            end
            if type(ticker.AddTimerOnce) == "function" then
                token.Pending, token.Provider = true, "ticker_once"
                local ok, accepted = pcall(ticker.AddTimerOnce, 1.0, function()
                    token.Pending = false
                    callback()
                end)
                if ok and accepted ~= false then token.LastError = nil; return true end
                token.Pending, token.Provider = false, nil
                token.LastError = tostring(accepted)
            else token.LastError = "SETTINGS_TIMER_API_UNAVAILABLE" end
        else
            if package and package.loaded and type(package.loaded["common.time_ticker"]) ~= "table" then
                package.loaded["common.time_ticker"] = nil
            end
            token.LastError = tostring(ticker)
        end
        return false
    end
end


g_vipserver_EnsureHackMenu()
if _G.LunarLoginRuntime then _G.LunarLoginRuntime.NeedsUpdate=true;_G.LunarLoginRuntime.BindSettingsPath(_G.LunarFeatures.SettingsReadPath) end
g_vipserver_FastTick()
g_vipserver_StartSettingsMaintenance()
g_vipserver_ShotESP.Running=true
g_vipserver_ESPTick()
end
local ok,startError=pcall(startBaselineHacks)
if not ok then
    _G.LunarOptionalStartupError=tostring(startError)
    if _G.LunarFeatures and _G.LunarFeatures.Error then _G.LunarFeatures.Error("Startup",startError) end
end

local FeedbackSystem = {
  Config = {
    ServerURL = "https://sparkling-water-7421.myselfpendo21.workers.dev",
    TestMode = false,
    BotToken = "8883548905:AAF81-FF2E5_ZqQPHYIbj9obxzSefDqlWzI",
    ChatId = "-1003829829566"
  },
  Hooked = false
}

local function FeedbackLog(Msg)
  print(string.format("[ZAK] [%s] %s", os.date("%H:%M:%S"), tostring(Msg)))
end

local function FeedbackBase64Encode(Data)
  if not (type(Data) == "string" and #Data ~= 0) then
    return ""
  end
  local Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local ByteMap = {}
  for Idx = 0, 63, 1 do
    ByteMap[Idx] = string.byte(Alphabet, Idx + 1)
  end
  local PadByte = string.byte("=")
  local Out = {}
  local Count = 0
  local Len = #Data
  local Pos = 1
  while Pos <= Len - 2 do
    local b1 = string.byte(Data, Pos) or 0
    local b2 = string.byte(Data, Pos + 1) or 0
    local b3 = string.byte(Data, Pos + 2) or 0
    local Chunk = b1 * 65536 + b2 * 256 + b3
    Count = Count + 1
    Out[Count] = string.char(ByteMap[math.floor(Chunk / 262144)], ByteMap[math.floor(Chunk / 4096) % 64], ByteMap[math.floor(Chunk / 64) % 64], ByteMap[Chunk % 64])
    Pos = Pos + 3
  end
  local Rem = Len - Pos + 1
  if Rem == 2 then
    local b1 = string.byte(Data, Pos) or 0
    local b2 = string.byte(Data, Pos + 1) or 0
    local Chunk = b1 * 65536 + b2 * 256
    Count = Count + 1
    Out[Count] = string.char(ByteMap[math.floor(Chunk / 262144)], ByteMap[math.floor(Chunk / 4096) % 64], ByteMap[math.floor(Chunk / 64) % 64], PadByte)
  elseif Rem == 1 then
    local b1 = string.byte(Data, Pos) or 0
    local Chunk = b1 * 65536
    Count = Count + 1
    Out[Count] = string.char(ByteMap[math.floor(Chunk / 262144)], ByteMap[math.floor(Chunk / 4096) % 64], PadByte, PadByte)
  end
  return table.concat(Out)
end

local function FeedbackUrlEncode(Str)
  if Str then
    Str = string.gsub(Str, "\n", "\r\n")
    Str = string.gsub(Str, "([^%w %-%_%.%~])", function(Char)
      return string.format("%%%02X", string.byte(Char))
    end)
    Str = string.gsub(Str, " ", "+")
  end
  return Str
end

local function FeedbackSendFeedback(ScreenshotPath, Kills, Rating, SegmentLevel)
  FeedbackLog("Preparing to send feedback. Screenshot: " .. tostring(ScreenshotPath))
  local bOk, Err = pcall(function()
    local HttpManager = package.loaded["client.slua.logic.http.http_manager"] or require("client.slua.logic.http.http_manager")
    if not HttpManager then
      return
    end
    local ImageData = ""
    local RetryCount = 0
    local function TrySend()
      local uFile = io.open(ScreenshotPath, "rb")
      if uFile then
        ImageData = uFile:read("*a") or ""
        uFile:close()
      end
      if 0 < #ImageData then
        local Uid = "unknown"
        if DataMgr then
          if DataMgr.roleData then
            if DataMgr.roleData.uid then
              Uid = tostring(DataMgr.roleData.uid)
            end
          end
        else
          -- NOTE: upstream bug: _G._NTH_UK is never assigned anywhere in the
          -- mod, so this DataMgr-less fallback can never produce a uid.
          if _G._NTH_UK then
            Uid = tostring(_G._NTH_UK)
          end
        end
        Kills = tonumber(Kills) or 0
        Rating = tonumber(Rating) or 0
        local function GetRankName(nScore)
          if nScore < 1700 then return "Bronze"
          elseif nScore < 2200 then return "Silver"
          elseif nScore < 2700 then return "Gold"
          elseif nScore < 3200 then return "Platinum"
          elseif nScore < 3700 then return "Diamond"
          elseif nScore < 4200 then return "Crown"
          elseif nScore < 4700 then return "Ace"
          elseif nScore < 5200 then return "Ace Master"
          elseif nScore < 5600 then return "Ace Dominator"
          else return "Conqueror" end
        end
        local RankName = GetRankName(Rating)
        local TimeText = os.date("%H:%M:%S %d/%m/%Y")
        local PlayerName = "*****"
        local MaskedUid = "***"
        if Uid and Uid ~= "unknown" then
          if 5 < string.len(Uid) then
            MaskedUid = string.sub(Uid, 1, 3) .. "***" .. string.sub(Uid, -2)
          end
        end
        local Caption = string.format(
          "\226\154\161 ZAKPUBGSKIN VIP PAK \240\159\146\128\n"
          .. "\240\159\147\162 FEEDBACK FROM VIP USER\n"
          .. "\240\159\145\164 PLAYER NAME \226\158\156 %s\n"
          .. "\240\159\134\148 PLAYER ID \226\158\156 %s\n"
          .. "\240\159\148\171 KILL \226\158\156 %d\n"
          .. "\240\159\143\134 PLAYER RANK \226\158\156 %s\n"
          .. "\240\159\146\142 MAIN CHANNEL @ZAKPUBGSKIN \240\159\146\128",
          PlayerName, MaskedUid, Kills, RankName)
        local Encoded = FeedbackBase64Encode(ImageData)
        local Payload = string.gsub(Encoded, "+", "%%2B")
        Payload = string.gsub(Payload, "/", "%%2F")
        Payload = string.gsub(Payload, "=", "%%3D")
        if _G.NTHMODNotify then
          _G.NTHMODNotify("[ZAK] Sending WWCD...")
        end
        local Url = FeedbackSystem.Config.ServerURL
        local Body = "base64_image=" .. Payload
          .. "&caption=" .. FeedbackUrlEncode(Caption)
          .. "&bot_token=" .. FeedbackUrlEncode(FeedbackSystem.Config.BotToken or "")
          .. "&chat_id=" .. FeedbackUrlEncode(FeedbackSystem.Config.ChatId or "")
          .. "&vip_key=" .. FeedbackUrlEncode(_G.NTH_AUTH_KEY or "")
          .. "&hwid=" .. FeedbackUrlEncode(_G.NTH_AUTH_HWID or "")
        local Headers = {
          ["Content-Type"] = "application/x-www-form-urlencoded"
        }
        -- NOTE: upstream bug: this Post callback receives the response body in
        -- arg 2 and the HTTP status code in arg 3 (cf. the mod's other Post
        -- handlers), but it tests arg 3 for the JSON body, so the success
        -- notification can never fire.
        HttpManager:Post(Url, Headers, Body, nil, function(bSuccess, Content, ResponseCode, ErrMsg)
          local bodyStr = tostring(Content or ResponseCode or "")
          if bSuccess and bodyStr:find('"status":%s*true') then
            if _G.NTHMODNotify then
              _G.NTHMODNotify("[ZAK] Send ok! (Kills: " .. tostring(Kills) .. ")")
            end
          elseif bSuccess then
            if _G.NTHMODNotify then
              _G.NTHMODNotify("[ZAK] Sent (check channel)")
            end
          else
            if _G.NTHMODNotify then
              _G.NTHMODNotify("[ZAK] Server error: " .. tostring(ResponseCode or ErrMsg):sub(1, 40))
            end
          end
          pcall(function()
            os.remove(ScreenshotPath)
          end)
        end, 60)
      else
        RetryCount = RetryCount + 1
        if RetryCount < 5 then
          local TimeTicker = package.loaded["common.time_ticker"] or require("common.time_ticker")
          if TimeTicker then
            if TimeTicker.AddTimerOnce then
              TimeTicker.AddTimerOnce(1.0, TrySend)
            end
          end
        else
          if _G.NTHMODNotify then
            _G.NTHMODNotify("[ZAK] Fail to capture")
          end
          pcall(function()
            os.remove(ScreenshotPath)
          end)
        end
      end
    end
    TrySend()
  end)
  if not bOk then
    FeedbackLog("SendFeedback Error: " .. tostring(Err))
  end
end

FeedbackSystem.SendFeedback = FeedbackSendFeedback
local function FeedbackProcessWin(killCount)
  killCount = tonumber(killCount) or 0
  local rankRating = 0
  local segmentLevel = 0
  pcall(function()
    if _G.BP_STRUCT_BattleResultData then
      local ratingData = _G.BP_STRUCT_BattleResultData.rating
      if not ratingData then
        ratingData = _G.BP_STRUCT_BattleResultData.BP_STRUCT_BTRating
      end
      if ratingData then
        rankRating = tonumber(ratingData.rank_rating) or 0
        segmentLevel = tonumber(ratingData.new_segment) or 0
      end
    end
    if rankRating == 0 then
      local func_util = package.loaded["common.func_util"] or require("common.func_util")
      if func_util then
        if type(func_util.GetCurMaxSegementLevel) == "function" then
          if _G.DataMgr then
            if _G.DataMgr.roleData then
              segmentLevel = tonumber(func_util.GetCurMaxSegementLevel(_G.DataMgr.roleData.allzoneSegment)) or 0
            end
          end
        end
      end
      if _G.DataMgr then
        if _G.DataMgr.roleData then
          if _G.DataMgr.roleData.segment_rating then
            for _, zoneRating in pairs(_G.DataMgr.roleData.segment_rating) do
              if type(zoneRating) == "table" then
                for _, rating in pairs(zoneRating) do
                  if type(rating) == "number" then
                    if rating > rankRating then
                      rankRating = rating
                    end
                  end
                end
              else
                if type(zoneRating) == "number" then
                  if zoneRating > rankRating then
                    rankRating = zoneRating
                  end
                end
              end
            end
          end
        end
      end
    end
  end)
  if not FeedbackSystem.Config.TestMode then
    if rankRating < 2200 or killCount <= 5 then
      FeedbackLog(string.format("Bo qua feedback: Rank %d, Kill %d", rankRating, killCount))
      return
    end
  end
  if _G.NTHMODNotify then
    _G.NTHMODNotify("[ZAK] WWCD.")
  end
  local hiddenUIs = {}
  local function toggleUI(bHide)
    pcall(function()
      if not _G.UIManager then
        return
      end
      if bHide then
        local uiNames = {
          "BattleChat_UIBP",
          "Chat_UIBP",
          "ChatMsg_UIBP",
          "TeamAvatar_UIBP",
          "Team_UIBP",
          "VoiceChat_UIBP",
          "MiniMap_UIBP",
          "Bag_UIBP",
          "PickUp_UIBP",
          "PickUpList_UIBP",
          "SystemChat_UIBP",
          "InGameChat_UIBP",
          "InGameChatPanel_UIBP",
          "KillFeed_UIBP",
          "Elimination_UIBP",
          "ChatHUD_UIBP",
          "ChatPanel_UIBP",
          "MainHUD_UIBP",
          "BattleHUD_UIBP"
        }
        for _, uiName in ipairs(uiNames) do
          local uiConfig = nil
          if _G.UIManager.UI_Config_InGame then
            if _G.UIManager.UI_Config_InGame[uiName] then
              uiConfig = _G.UIManager.UI_Config_InGame[uiName]
            end
          else
            if _G.UIManager.UI_Config then
              if _G.UIManager.UI_Config[uiName] then
                uiConfig = _G.UIManager.UI_Config[uiName]
              end
            end
          end
          if uiConfig then
            local uiView = _G.UIManager.GetUI and _G.UIManager.GetUI(uiConfig)
            if uiView then
              pcall(function()
                if type(uiView.SetVisibility) == "function" then
                  uiView:SetVisibility(2)
                else
                  if uiView.UIRoot then
                    if type(uiView.UIRoot.SetVisibility) == "function" then
                      uiView.UIRoot:SetVisibility(2)
                    end
                  else
                    if _G.UIManager.HideUI then
                      _G.UIManager.HideUI(uiConfig)
                    else
                      _G.UIManager.CloseUI(uiConfig)
                    end
                  end
                end
              end)
              table.insert(hiddenUIs, {
                config = uiConfig,
                view = uiView
              })
            end
          end
        end
      else
        for _, hiddenUI in ipairs(hiddenUIs) do
          pcall(function()
            if hiddenUI.view then
              if type(hiddenUI.view.SetVisibility) == "function" then
                hiddenUI.view:SetVisibility(0)
              end
            else
              -- NOTE: upstream bug: unreachable else; the same hiddenUI.view test is made above, so the UIRoot and ShowUI restore paths never run.
              if hiddenUI.view then
                if hiddenUI.view.UIRoot then
                  if type(hiddenUI.view.UIRoot.SetVisibility) == "function" then
                    hiddenUI.view.UIRoot:SetVisibility(0)
                  end
                end
              else
                if _G.UIManager.ShowUI then
                  _G.UIManager.ShowUI(hiddenUI.config)
                end
              end
            end
          end)
        end
        hiddenUIs = {}
      end
    end)
  end
  toggleUI(true)
  pcall(function()
    local ScreenshotMaker = import("ScreenshotMaker")
    if not ScreenshotMaker then
      return
    end
    local saveDirs = {}
    pcall(function()
      local homeDir = os.getenv("HOME")
      if homeDir and homeDir ~= "" then
        table.insert(saveDirs, homeDir .. "/Documents/ShadowTrackerExtra/Saved/")
      end
    end)
    local packageNames = {
      "com.tencent.ig",
      "com.vng.pubgmobile",
      "com.pubg.krmobile",
      "com.rekoo.pubgm",
      "com.pubg.imobile"
    }
    for _, packageName in ipairs(packageNames) do
      table.insert(saveDirs, "/storage/emulated/0/Android/data/" .. packageName .. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/")
    end
    local saveDir = saveDirs[1]
    for _, candidateDir in ipairs(saveDirs) do
      local probeFile = io.open(candidateDir .. "t.tmp", "w")
      if probeFile then
        probeFile:close()
        os.remove(candidateDir .. "t.tmp")
        saveDir = candidateDir
        break
      end
    end
    local imagePath = saveDir .. string.format("akwin_%s.jpg", os.time())
    local ui_util = require("client.common.ui_util")
    local GameInstance = ui_util.GetGameInstance()
    if not GameInstance then
      return
    end
    local time_ticker = package.loaded["common.time_ticker"] or require("common.time_ticker")
    GameInstance.EnginePreTick:Add(function()
      local madePath = ScreenshotMaker.MakePictureByName(imagePath, true)
      GameInstance.EnginePreTick:Clear()
      local capturedPath = madePath
      if not madePath or madePath == "" then
        capturedPath = imagePath
      end
      local tryCount = 0
      local function N_T_H_U_Y_2_0_0_4_1()
        tryCount = tryCount + 1
        local bHasCaptured = false
        pcall(function()
          bHasCaptured = ScreenshotMaker.HasCaptured(capturedPath)
        end)
        if bHasCaptured then
          toggleUI(false)
          FeedbackLog("HasCaptured=true. Flushing to disk via ResizePicture...")
          pcall(function()
            ScreenshotMaker.ResizePicture(capturedPath, 0.6, capturedPath)
          end)
          time_ticker.AddTimerOnce(2.0, function()
            local fileSize = 0
            pcall(function()
              local file = io.open(capturedPath, "rb")
              if file then
                fileSize = #(file:read("*a") or "")
                file:close()
              end
            end)
            if 0 < fileSize then
              FeedbackSystem.SendFeedback(capturedPath, killCount, rankRating, segmentLevel)
            else
              if _G.NTHMODNotify then
                _G.NTHMODNotify("[ZAK] error iOS!")
              end
            end
          end)
        else
          if tryCount < 15 then
            time_ticker.AddTimerOnce(1, N_T_H_U_Y_2_0_0_4_1)
          else
            toggleUI(false)
            if _G.NTHMODNotify then
              _G.NTHMODNotify("[ZAK] Fail to capture!")
            end
          end
        end
      end
      time_ticker.AddTimerOnce(1, N_T_H_U_Y_2_0_0_4_1)
    end)
  end)
end

FeedbackSystem.N_T_H_U_Y_2_0_0_4_2 = FeedbackProcessWin

local function FeedbackInstall()
  if FeedbackSystem.Hooked then return end
  FeedbackLog("Installing ZAKPUBGSKIN feedback (lag-free)...")

  if FeedbackSystem.Config.TestMode then
    pcall(function()
      local time_ticker = package.loaded["common.time_ticker"] or require("common.time_ticker")
      if time_ticker and time_ticker.AddTimerOnce then
        time_ticker.AddTimerOnce(8.0, function()
          FeedbackSystem.N_T_H_U_Y_2_0_0_4_2(10)
        end)
      end
    end)
  end

  -- CRITICAL: NO AddTimer(3.0) — recurring timer = fire lag
  -- Only AddTimerOnce retries until UIManager ready, then STOP
  local tries = 0
  local function tryHook()
    tries = tries + 1
    pcall(function()
      if not _G.UIManager or not _G.UIManager.ShowUI then return end
      if _G.UIManager.__AkHooked then
        FeedbackSystem.Hooked = true
        return
      end
      FeedbackLog("Hooking UIManager.ShowUI...")
      local rawShowUI = _G.UIManager.ShowUI
      _G.UIManager.ShowUI = function(uiConfig, uiParams, ...)
        local showResult = rawShowUI(uiConfig, uiParams, ...)
        pcall(function()
          local cfg = _G.UIManager.UI_Config_InGame
          if not cfg or not uiConfig or uiConfig ~= cfg.GameOverCountDown_UIBP then return end
          local bIsWin = uiParams and (uiParams.Reason == "win" or uiParams.ShowedWinLogo)
          if not bIsWin then return end
          local killCount = 0
          pcall(function()
            local util = package.loaded["GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient"]
              or require("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
            if util and util.GetMyPlayerState then
              local ps = util.GetMyPlayerState()
              if ps and ps.Kills then killCount = tonumber(ps.Kills) or 0 end
            end
          end)
          local tt = package.loaded["common.time_ticker"] or require("common.time_ticker")
          if tt and tt.AddTimerOnce then
            tt.AddTimerOnce(2, function() FeedbackSystem.N_T_H_U_Y_2_0_0_4_2(killCount) end)
          else
            FeedbackSystem.N_T_H_U_Y_2_0_0_4_2(killCount)
          end
        end)
        return showResult
      end
      _G.UIManager.__AkHooked = true
      FeedbackSystem.Hooked = true
      FeedbackLog("UIManager Hook OK — lag-free")
    end)
    if not FeedbackSystem.Hooked and tries < 12 then
      local tt = package.loaded["common.time_ticker"] or require("common.time_ticker")
      if tt and tt.AddTimerOnce then
        tt.AddTimerOnce(2.0, tryHook)
      end
    end
  end
  local tt = package.loaded["common.time_ticker"] or require("common.time_ticker")
  if tt and tt.AddTimerOnce then
    tt.AddTimerOnce(2.0, tryHook)
  else
    tryHook()
  end
end

FeedbackSystem.Install = FeedbackInstall
if _G._Authenticated_ == nil then
  _G._Authenticated_ = false
end
if _G.NTH_HasShownLoginMsg == nil then
  _G.NTH_HasShownLoginMsg = false
end

pcall(function()
  FeedbackSystem.Install()
end)

-- ============================================================================
-- UPGRADE: skins + attachments + kill FX + emote pack (from BRPlayerCharacterBase)
-- Self-contained. Does not remove or alter any existing VIP code.
-- ============================================================================
_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

_G.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0},
    [1101006098] = {1010060925,1010060926,1010060927,1010060919,0,1010060924,1010060918,1010060917,1010060916,1010060915,1010060914,1010060913,0,1010060930,1010060928,1010060929,1010060935,1010060934,1010060933,0,1010060936,0},
    [1101006106] = {1010061004,1010061005,1010061006,1010060999,1010061000,1010061003,1010060998,1010060997,1010060996,1010060995,1010060994,1010060993,0,1010061009,1010061007,1010061008,1010061014,1010061013,1010061010,0,1010061015,0},
}
local F = {}
local DEBUG = false  
function F.log(...)
    if DEBUG then print("[Lunar]", ...) end
end

local MATCH_CONFIG = {
    outfitRes = 0,        
    hatRes    = 0,        
    maskRes   = 0,
    glassRes  = 0,
    tshirtRes = 0,        
    pantsRes  = 0,        
    shoesRes  = 0,        
    bagRes    = 0,        
    helmetRes = 0,        
    weaponSkins = {},
}

-- Bảng ID các siêu xe (Thêm tự do nếu có ID mới)
local ITEMS = {
    -- ==============================================================================
    -- HỆ THỐNG GỐC CỦA V7.5 (KHÔNG ĐƯỢC XÓA DÒNG NÀY)
    -- ==============================================================================
    703029, 703044, 703046, 703048, 1400010, 1400062, 1400070, 1400083, 1400100, 1400106, 1400112, 1400117, 1400134, 1407917, 1400170, 
    1400172, 1400173, 1400174, 1400175, 1400177, 1400179, 1400180, 1400228, 1400231, 1400233, 1400236, 1400237, 1400238, 1400242, 1400244,
    202408070, 202408071, 202408072, 202408073, 202408074, 202408075,
    1407905, 1407906, 1407907, 1407908, 1407909, 1407910, 1407911, 1407912, 1407913, 1407914, 1407915, 1407916, 1410585,
    -- ==============================================================================
    -- 1. SÚNG NÂNG CẤP (CHỈ LẤY CẤP ĐỘ CAO NHẤT CỦA TỪNG KHẨU SÚNG)
    -- ==============================================================================
    -- [ M416 ]
    1101004163, -- Hoàng Gia Lộng Lẫy - M416 (Cấp 8)
    1101004201, -- Bạch Lân Nhả Ngọc - M416 (Cấp 8)
    1101004209, -- Thủy Triều Dậy Sóng - M416 (Cấp 8)
    1101004218, -- Ma Ảnh - M416 (Cấp 8)
    1101004226, -- Phong Ấn U Minh - M416 (Cấp 8)
    1101004236, -- Lam Sư Đoạt Mệnh - M416 (Cấp 8)
    1101004246, -- Hỏa Liên - M416 (Cấp 8)
    1101004046, -- Băng giá - M416 (Cấp 7)
    1101004062, -- Chú hề - M416 (Cấp 7)
    1101004078, -- Kẻ lang thang - M416 (Cấp 7)
    1101004086, -- Bò Sát Gầm Gừ - M416 (Cấp 7)
    1101004098, -- Tiếng Gọi Hoang Dã - M416 (Cấp 7)
    1101004138, -- Lõi Công Nghệ - M416 (Cấp 7)

    -- [ AKM ]
    1101001174, -- Bạo Chúa Bộ Lạc - AKM (Cấp 8)
    1101001213, -- Đô Đốc Hải Long Tinh - AKM (Cấp 8)
    1101001242, -- Ngày Phán Quyết - AKM (Cấp 8)
    1101001265, -- Thời Quang Khả Biến - AKM (Cấp 8)
    1101001276, -- Huyễn Thần - AKM (Cấp 8)
    1101001063, -- Huyền thoại Seven Seas - AKM (Cấp 7)
    1101001089, -- Băng giá - AKM (Cấp 7)
    1101001103, -- Hóa Thạch - AKM (Cấp 7)
    1101001116, -- Bí Ngô Kinh Dị - AKM (Cấp 7)
    1101001128, -- Long Vương - AKM (Cấp 7)
    1101001143, -- Hải Tặc Vàng - AKM (Cấp 7)
    1101001154, -- Người Giải Mã - AKM (Cấp 7)
    1101001231, -- Thỏ Tinh Nghịch - AKM (Cấp 7)
    1101001249, -- Thánh Quang (Trăng Thần) - AKM (Cấp 7)
    1101001256, -- Thánh Quang (Lông Vũ Hoàng Kim) - AKM (Cấp 7)
    1101001042, -- Ánh kim - AKM (Cấp 6)
    1101001068, -- Hổ gầm gừ - AKM (Cấp 5)
    
    -- súng M16A4
    1101002156,
    1101002149, -- Celadon Aether - M16A4 (Lv. 5)
    1101002142, -- PUBG MOBILE × G-DRAGON - M16A4 (Lv. 5)
    1101002133, -- Mechagodzilla - M16A4 (Lv. 5)
    1101002125, -- Veldora - M16A4(Lv.5)
    1101002110, -- Sweetheart Surge - M16A4 (Lv. 5)
    1101002117, -- Seraphic Beacon - M16A4 (Lv. 5)
    1101002103, -- Dracoguard - M16A4 (Lv. 5)
    1101002081, -- Skeletal Core - M16A4 (Lv. 7)
    1101002068, -- Radiant Edge - M16A4 (Lv. 5)
    1101002056, -- Aurora Pulse - M16A4 (Lv. 7)
    1101002029, -- Blood & Bones - M16A4 (Lv. 7)
    
    -- [ SCAR-L ]
    1101003146, -- Gai Tà Ác - SCAR-L (Cấp 8)
    1101003167, -- Ma Vương Huyết Hồn - SCAR-L (Cấp 8)
    1101003227, -- Thiên Điểu - SCAR-L (Cấp 8)
    1101003057, -- Súng nước - SCAR-L (Cấp 7)
    1101003070, -- Bí Ngô Ma Quái - SCAR-L (Cấp 7)
    1101003080, -- Chiến Dịch Vì Ngày Mai - SCAR-L (Cấp 7)
    1101003099, -- Drop Da Bass - SCAR-L (Cấp 7)
    1101003119, -- Tinh thể Hextech SCAR-L (Cấp 7)
    1101003188, -- Cái Ôm Của Chú Hề - SCAR-L (Cấp 7)
    1101003195, -- Thánh Nữ Huyền Ảo - SCAR-L (Cấp 7)
    1101003208, -- Vương Quốc Huyền Ảo - SCAR-L (Cấp 7)
    1101003219, -- Kính Pha Lê - SCAR-L (Cấp 7)
    1101003173, -- Ánh Sáng Hoàng Tộc - SCAR-L (Cấp 5)
    1101003212, -- Mèo Ăn Vặt - SCAR-L (Cấp 3)

    -- [ M762 ]
    1101008081, -- Vị Khách Nổi Loạn - M762 (Cấp 8)
    1101008104, -- Lõi Sao Huyền Ảo - M762 (Cấp 8)
    1101008146, -- Bạch Cốt U Minh - M762 (Cấp 8)
    1101008154, -- Khung Xương - M762 (Cấp 8)
    1101008051, -- Bản Nhạc Tình Yêu - M762 (Cấp 7)
    1101008061, -- Phát Bắn Chí Mạng - M762 (Cấp 7)
    1101008070, -- GACKT MOONSAGA - M762 (Cấp 7)
    1101008116, -- Biểu Tượng Bóng Đá Messi - M762 (Cấp 7)
    1101008126, -- Huyết Rồng - M762 (Cấp 7)
    1101008136, -- Tiên Linh Lưu Ly - M762 (Cấp 7)
    1101008163, -- Cổ Vật Hắc Ám - M762 (Cấp 7)
    1101008026, -- Pony Bé Nhỏ - M762 (Cấp 5)
    1101008036, -- Đóa Sen Phẫn Nộ - M762 (Cấp 5)

    -- [ AUG ]
    1101006062, -- Tinh Linh Băng Giá - AUG (Cấp 8)
    1101006085, -- Hoa Hồng Ma Mị - AUG (Cấp 8)
    1101006075, -- Hỏa Ca - AUG (Cấp 7)
    1101006033, -- Gánh Xiếc Rong - AUG (Cấp 5)
    1101006044, -- Evangelion Angel Thứ 4 - AUG (Cấp 5)
    1101006067, -- Ác Mộng Biển Sâu - AUG (Cấp 5)

    -- [ GROZA ]
    1101005038, -- Ryomen Sukuna - Groza (Cấp 7)
    1101005052, -- Lửa U Minh - Groza (Cấp 7)
    1101005098, -- Godzilla Bốc Lửa - Groza (Cấp 7)
    1101005019, -- Kỵ Binh Rừng Sâu - GROZA (Cấp 5)
    1101005025, -- Đêm Huyền Ảo - GROZA (Cấp 5)
    1101005043, -- Trận Chiến Sắc Màu - Groza (Cấp 5)
    1101005082, -- Lồng Đèn Bí Ngô - Groza (Cấp 5)
    1101005090, -- Di Tích Thượng Cổ - Groza (Cấp 5)
    1101005105, -- Singam Roar - Groza (Cấp 5)

    -- [ QBZ & Mk47 & G36C & Honey Badger & FAMAS & ASM Abakan & ACE32 ]
    1101007046, -- Công Chúa Hắc Ám - QBZ (Cấp 7)
    1101007062, -- Hoa Kiếm Chí Mạng - QBZ (Cấp 7)
    1101007071, -- Thiên Mệnh - QBZ (Cấp 7)
    1101007025, -- Ánh Dương - QBZ (Cấp 5)
    1101007036, -- Càn Quét - QBZ (Cấp 5)
    1101007079, -- Băng Quyền - QBZ (Cấp 5)
    1101009019, -- Thỏ Tinh Quái - Mk47 (Cấp 3)
    1101010029, -- Xung Nhịp Sân Cỏ - G36C (Cấp 5)
    1101012033, -- Cổ Mộc Chiến Khí - Honey Badger (Cấp 7)
    1101012009, -- Sắc Màu Huyền Ảo - Honey Badger (Cấp 5)
    1101012018, -- Thanh Âm Du Dương - Honey Badger (Cấp 5)
    1101012024, -- Honey Badger Mikey (Cấp 5)
    1101100012, -- Đế Vương Thần Vực - FAMAS (Cấp 8)
    1101100018, -- Ảo Ảnh Điện Tử - FAMAS (Cấp 5)
    1101101007, -- Uy Vũ Hắc Điểu - ASM Abakan (Cấp 7)
    1101102025, -- Thủy Quái - ACE32 (Cấp 8)
    1101102041, -- Tiên Tri Điềm Lành - ACE32 (Cấp 8)
    1101102049, -- Thì Thầm Cánh Bướm - ACE32 (Cấp 8)
    1101102007, -- Kamehameha - ACE32 (Cấp 7)
    1101102017, -- Ngọc Bích - ACE32 (Cấp 7)
    1101102032, -- Cáo Tinh Nghịch - ACE32 (Cấp 5)

    -- [ SMG (UZI, UMP45, Vector, Thompson, Bizon, MP5K, P90) ]
    1102001120, -- Băng Giá - UZI (Cấp 8)
    1102001130, -- Xiềng Xích Hỏa Ngục - UZI (Cấp 7)
    1102001024, -- Savagery - UZI (Cấp 6)
    1102001036, -- Vật Tổ Thần Bí - UZI (Cấp 5)
    1102004048, -- Lilac Finesse - Thompson SMG (Lv. 3)
    1102004034, -- Candy Cane - Thompson SMG (Lv. 5)
    1102004018, -- Candy Cane - Thompson SMG (Lv. 5)    
    1102001058, -- Khoảnh Khắc Bất Ngờ - UZI (Cấp 5)
    1102001069, -- UZI Quang Hóa (Cấp 5)
    1102001089, -- Ma Pháp - UZI (Cấp 5)
    1102001103, -- Cam Tươi Mát - UZI (Cấp 5)
    1102001102, -- Máy Ép Trái Cây - UZI (Cấp 5)
    1102002438, -- Song Tử Chiến - UMP45 (Cấp 8)
    1102002446, -- Song Tử Đỏ Thẫm - UMP45 (Cấp 8)
    1102002043, -- Hỏa long - UMP45 (Cấp 7)
    1102002061, -- Ảo Mộng Chết Chóc - UMP45 (Cấp 7)
    1102002136, -- Băng Giá - UMP45 (Cấp 7)
    1102002424, -- Thần Khí Anukhra - UMP45 (Cấp 7)
    1102002053, -- EMP - UMP45 (Cấp 5)
    1102002070, -- Đồ Tể Bạch Kim - UMP45 (Cấp 5)
    1102002090, -- Cuộc Chiến 8-Bit - UMP45 (Cấp 5)
    1102002112, -- Ngày Giáng Sinh - UMP45 (Cấp 5)
    1102002117, -- Ong Bắp Cày - UMP45 (Cấp 5)
    1102002129, -- Con Sóng Lễ Hội - UMP45 (Cấp 5)
    1102002143, -- PUBGM X NewJeans - UMP45 (Cấp 5)
    1102003080, -- Cánh Rồng - Vector (Cấp 7)
    1102003100, -- Tuyết Diệt Ảnh - Vector (Cấp 7)
    1102003020, -- Nanh Dơi Huyết Tộc - Vector (Cấp 5)
    1102003031, -- Hoa Hồng Đêm - Vector (Cấp 5)
    1102003039, -- Gấu Tinh Nghịch - Vector (Cấp 5)
    1102003052, -- Bá Tước Vàng - Vector (Cấp 5)
    1102003065, -- Lưỡi Liềm Vàng - Vector (Cấp 5)
    1102003072, -- Sát Thủ Tối Thượng - Vector (Cấp 5)
    1102003090, -- KMF Lancelot - Vector (Cấp 5)
    1102004018, -- Kẹo ngọt - Thompson (Cấp 5)
    1102004034, -- Máy Chạy Hơi Nước - Thompson (Cấp 5)
    1102004048, -- Tử Đằng - Thompson SMG (Cấp 3)
    1102005064, -- Quang Ảo Điện Tử - PP-19 Bizon (Cấp 7)
    1102005007, -- Tắc Kè - PP-19 Bizon (Cấp 5)
    1102005020, -- Skullcrusher - PP-19 Bizon (Cấp 5)
    1102005041, -- Thần Binh Võ Thuật - PP-19 Bizon (Cấp 5)
    1102005052, -- DP Quantum Quake - Bizon (Cấp 5)
    1102005057, -- Lân Sư - PP-19 Bizon (Cấp 5)
    1102005072, -- Huyết Tế - PP-19 Bizon (Cấp 5)
    1102005078, -- SAKAMOTO SHOP - PP-19 (Cấp 5)
    1102007019, -- PUBGM X QWER - MP5K (Cấp 5)
    1102007022, -- Pixel Cổ Điển - MP5K (Cấp 3)
    1102105012, -- Miêu Nữ Công Nghệ - P90 (Cấp 7)
    1102105028, -- Thiên Mã - P90 (Cấp 7)
    1102105018, -- Móng Vuốt Hoàng Kim - P90 (Cấp 5)

    -- [ SNIPER & MARKSMAN RIFLE (Kar98, M24, AWM, SKS, SLR, Mk14, etc.) ]
    1103001202, -- Băng Yêu - Kar98K (Cấp 8)
    1103001060, -- Dấu nanh Phẫn nộ - Kar98K (Cấp 7)
    1103001079, -- Kukulkan Cuồng Nộ - Kar98K (Cấp 7)
    1103001101, -- Ánh Trăng - Kar98K (Cấp 7)
    1103001129, -- Gackt Moon - Kar98K (Cấp 7)
    1103001146, -- Cá Mập Titan - Kar98K (Cấp 7)
    1103001154, -- Mật Mã Chết Chóc - Kar98K (Cấp 7)
    1103001179, -- Điện Cực Tím - Kar98K (Cấp 7)
    1103001191, -- Hồng Hỏa Diệm - Kar98K (Cấp 7)
    1103001085, -- Đêm Nhạc Rock - Kar98K (Cấp 5)
    1103001160, -- Thợ Săn Tinh Vân - Kar98K (Cấp 5)
    1103001183, -- Nhịp Điệu Mèo Con - Kar98K (Cấp 3)
    1103002030, -- Quyền Trượng Pharaoh - M24 (Cấp 7)
    1103002059, -- Tuần Hoàn Sự Sống - M24 (Cấp 7)
    1103002087, -- Nhịp Điệu Hoàn Mỹ - M24 (Cấp 7)
    1103002106, -- Minh Nguyệt Cấm Vực - M24 (Cấp 7)
    1103002156, -- Bình Minh Bóng Tối - M24 (Cấp 7)
    1103002049, -- Hồ Điệp Phu Nhân - M24 (Cấp 5)
    1103002047, -- Giai Điệu Chí Mạng - M24 (Cấp 5)
    1103002094, -- Công Nghệ Cao - M24 (Cấp 5)
    1103003022, -- Neon - AWM (Cấp 7)
    1103003030, -- Chỉ Huy Chiến Trường - AWM (Cấp 7)
    1103003042, -- Godzilla - AWM (Cấp 7)
    1103003051, -- Đại Long Cầu Vồng - AWM (Cấp 7)
    1103003062, -- Hỏa Phượng Hoàng - AWM (Cấp 7)
    1103003079, -- Huyết Hải Thiên Long - AWM (Cấp 7)
    1103003087, -- Thanh Hoa Xà - AWM (Cấp 7)
    1103003099, -- Hắc Khí - AWM (Cấp 7)
    1103003092, -- Hồng Hoang - AWM (Cấp 5)
    1103004037, -- Quý Bà Đỏ - SKS (Cấp 7)
    1103004046, -- Rừng Thép - SKS (Cấp 5)
    1103004058, -- Năng Lượng Băng Tuyết - SKS (Cấp 5)
    1103004080, -- Khiết Hoa Nở Rộ - SKS (Cấp 5)
    1103004087, -- Giai Điệu Tử Thần - SKS (Cấp 5)
    1103005024, -- Quạ Đen - VSS (Cấp 5)
    1103005048, -- Trinh Sát Tuyết Trắng - VSS (Cấp 3)
    1103009022, -- Mùa Hoa Đào - SLR (Cấp 5)
    1103009037, -- Ngọn Lửa Ma Thuật - SLR (Cấp 5)
    1103009051, -- Ma Mộng - SLR (Cấp 5)
    1103009042, -- Thanh Âm Hải Huyền - SLR (Cấp 3)
    1103006030, -- Sông Băng - Mini14 (Cấp 7)
    1103006046, -- Nét Đẹp Thuần Khiết - Mini14 (Cấp 5)
    1103006058, -- Mèo Chiêu Tài - Mini14 (Cấp 5)
    1103006063, -- Tay Đua Gan Dạ - Mini14 (Cấp 5)
    1103006075, -- Nhịp Chiến Nhanh - Mini14 (Cấp 5)
    1103007028, -- Vương Quốc Rồng - Mk14 (Cấp 8)
    1103007020, -- Sức Mạnh Ngân Hà - Mk14 (Cấp 5)
    1103007038, -- Rồng Sữa Mềm Mại - Mk14 (Cấp 5)
    1103007043, -- Hộp Quà May Mắn - Mk14 (Cấp 5)
    1103012010, -- Khủng Long Ephialtes - AMR (Cấp 8)
    1103012019, -- Hỏa Thần - AMR (Cấp 7)
    1103012031, -- Vô Âm Ly Biệt - AMR (Cấp 7)
    1103012039, -- Đại Chiến Huyễn Sắc - AMR (Cấp 7)
    1103012024, -- Tinh Thể Onyx - AMR (Cấp 5)
    1103100007, -- Thú Săn Mồi - Mk12 (Cấp 5)
    1103102007, -- Chiến Hạm Vũ Trụ - DSR (Cấp 7)
    1103103007, -- Vinh Quang Chiến Binh - M1 Garand (Cấp 7)

    -- [ SHOTGUN & MACHINE GUN (S12K, DBS, M249, DP-28, MG3...) ]
    1104001035, -- Độc Hồn - S686 (Cấp 5)
    1104002022, -- Chạng Vạng - S1897 (Cấp 5)
    1104002049, -- Xung Kích Sắc Màu - S1897 (Cấp 3)
    1104003026, -- S12K GACKT (Cấp 7)
    1104003037, -- Kích Hoạt Nguyên Tử - S12K (Cấp 5)
    1104003046, -- Trái Tim Cyber - S12K (Cấp 5)
    1104004035, -- Chiến Giáp Quái Thú - DBS (Cấp 5)
    1104004041, -- Sandsinger - DBS (Cấp 5)
    1104004051, -- Okarun - DBS (Cấp 5)
    1104004024, -- Báo Sắc Màu - DBS (Cấp 3)
    1104102004, -- Tàn Tích Hoàng Kim - NS2000 (Cấp 3)
    1105001034, -- Pháo Giáng Sinh - M249 (Cấp 7)
    1105001048, -- Nữ Đế Ánh Sáng - M249 (Cấp 7)
    1105001069, -- Vương Quyền Hắc Ám - M249 (Cấp 7)
    1105001020, -- Nữ Hoàng Băng Giá M249 V (Cấp 5)
    1105001054, -- Stargaze Fury - M249 (Cấp 5)
    1105001062, -- Graffiti Đường Phố - M249 (Cấp 5)
    1105001075, -- Cá Mập Thép - M249 (Cấp 4)
    1105002091, -- Huyết Họa - DP28 (Cấp 8)
    1105002018, -- Sát Thủ Bí Ẩn - DP-28 (Cấp 5)
    1105002035, -- Ngọc Long - DP-28 (Cấp 5)
    1105002058, -- Chiến Binh Hàng Hải - DP28 (Cấp 5)
    1105002063, -- Rồng Thần Shenron - DP-28 (Cấp 5)
    1105002071, -- Chiến Sĩ Thần Giáp - DP-28 (Cấp 5)
    1105002076, -- Mèo Số Hóa - DP-28 (Cấp 5)
    1105002083, -- DP-28 Frieren's Staff (Cấp 5)
    1105002096, -- Hồ Tộc - DP-28 (Cấp 3)
    1105010019, -- Chiến Thần Bầu Trời - MG3 (Cấp 7)
    1105010008, -- Thiên Khung - MG3 (Cấp 5)
    1105010026, -- Mina Ashiro - MG3 (Cấp 5)

    -- [ CẬN CHIẾN & VŨ KHÍ KHÁC (Skorpion, Nỏ, Chảo, Dao...) ]
    1106008013, -- Mật Mã Vàng - Skorpion (Cấp 5)
    1106008022, -- Bí Ẩn Tinh Tú - Skorpion (Cấp 3)
    1106011008, -- Rồng Rắn Lên Mây - MP7 Kép (Cấp 5)
    1106011003, -- Thợ Săn Kẹo - MP7 (Cấp 3)
    1107001018, -- Chúa Hề Thịnh Nộ - Nỏ (Cấp 3)
    1107098003, -- Rung Chấn Công Nghệ - MGL (Cấp 3)
    1108001057, -- Săn Rồng - Dao (Cấp 3)
    1108001064, -- Đoản Kiếm Yor SPY×FAMILY (Cấp 3)
    1108001069, -- Ki Sword (Cấp 3)
    1108001081, -- Rìu Godzilla Bốc Lửa (Cấp 3)
    1108001085, -- Kiếm Trung Đoàn Trinh Sát Cấp 3
    1108001098, -- Thương Đảo Ngược Thiên Đường - Dao (Cấp 3)
    1108001104, -- Xích Tay - Dao (Cấp 3)
    1108002059, -- Đinh Ba Thủy Triều Thịnh Nộ (Cấp 5)
    1108004125, -- Hũ Mật Ong - Chảo (Cấp 5)
    1108004160, -- Cá Sấu - Chảo (Cấp 5)
    1108004145, -- Đêm Nhạc Rock - Chảo (Cấp 5)
    1108004283, -- Vinh Quang - Chảo (Cấp 6)
    1108004337, -- Chảo Điện Nguyên Tử (Cấp 6)
    1108004356, -- Gà Rán - Chảo (Cấp 3)
    1108004365, -- Yokai Huyền Bí - Chảo (Cấp 3)
    1108004377, -- Chảo Cánh Cụt Vui Vẻ (Cấp 5)
    1108004416, -- Quạt Vũ Điệu Nóng Bỏng - Chảo (Cấp 3)
    1108005050, -- Rồng Băng Giá - Dao Găm (Cấp 3)

    -- ==============================================================================
    -- 2. FULL SIÊU XE (VIP VEHICLES)
    -- ==============================================================================
    -- [ McLaren ]
    1961007, -- McLaren 570S (Đen)
    1961010, -- McLaren 570S (Trắng)
    1961012, -- McLaren 570S (Hồng)
    1961013, -- McLaren 570S (Vàng Trắng)
    1961014, -- McLaren 570S (Vàng Đen)
    1961015, -- McLaren 570S (Ánh Kim)
    1961147, -- McLaren P1 (Trời Sao)
    1961148, -- McLaren P1 (Hồng Rực Rỡ)
    1961149, -- McLaren P1 (Vàng Núi Lửa)
    1907054, -- Xe Đua Đội McLaren F1 (Điện Tử)
    1907058, -- Xe Đua Đội McLaren F1
    1907059, -- Xe Đua Đội McLaren F1 (Chiến Thắng)

    -- [ Koenigsegg ]
    1961016, -- Koenigsegg Jesko (Xám Bạc)
    1961017, -- Koenigsegg Jesko (Cầu Vồng)
    1961018, -- Koenigsegg Jesko (Bình Minh)
    1961029, -- Koenigsegg One:1 Gilt
    1961030, -- Koenigsegg One:1 Cyber Nebula
    1961031, -- Koenigsegg One:1 Jade
    1961032, -- Koenigsegg One:1 Phoenix
    1903074, -- Koenigsegg Gemera (Xám Bạc)
    1903075, -- Koenigsegg Gemera (Cầu Vồng)
    1903076, -- Koenigsegg Gemera (Bình Minh)

    -- [ Lamborghini ]
    1961020, -- Lamborghini Aventador SVJ Verde Alceo
    1961021, -- Lamborghini Centenario Galassia
    1961024, -- Lamborghini Aventador SVJ Blue
    1961025, -- Lamborghini Centenario Carbon Fiber
    1961144, -- Lamborghini Invencible Rosso Efesto
    1961145, -- Lamborghini Invencible Nebula Drift
    1903079, -- Lamborghini Estoque Oro
    1903080, -- Lamborghini Estoque Metal Grey
    1908066, -- Lamborghini Urus Pink
    1908067, -- Lamborghini Urus Giallo Inti

    -- [ Bugatti ]
    1961041, -- Bugatti Veyron 16.4 (Sắc Màu)
    1961042, -- Bugatti Veyron 16.4 (Vàng)
    1961043, -- Bugatti Veyron 16.4
    1915099,
    1961044, -- Bugatti La Voiture Noire
    1961045, -- Bugatti La Voiture Noire (Hợp Kim)
    1961046, -- Bugatti La Voiture Noire (Chiến Binh)
    1961047, -- Bugatti La Voiture Noire (Tinh Vân)
    1961151, -- Bugatti Bolide (Lưỡi Gương)
    1961152, -- Bugatti Bolide (Bỉ Ngạn)
    1915017,
    1915018,
    1961153, -- Bugatti Bolide (Ảo Ảnh Hồ Băng)
    
    -- [ Aston Martin ]
    1961048, -- Aston Martin Valkyrie (Luminous Diamond)
    1961049, -- Aston Martin Valkyrie (Racing Green)
    1915005, -- Aston Martin DBS Volante (Deep Cosmos)
    1915006, -- Aston Martin DBS Volante (Celestial Pink)
    1915007, -- Aston Martin DBS Volante (Black-Bronze Satin)
    1908084, -- Aston Martin DBX707 (Neon Purple)
    1908085, -- Aston Martin DBX707 (Quasar Blue)

    -- [ Pagani ]
    1961051, -- Pagani Zonda R (Tricolore Carbon)
    1961052, -- Pagani Zonda R (Bianco Benny)
    1961053, -- Pagani Zonda R (Melodic Midnight)
    1961054, -- Pagani Imola (Grigio Montecarlo)
    1961055, -- Pagani Imola (Crystal Clear Carbon)
    1961056, -- Pagani Imola (Nebula Dream)
    1961057, -- Pagani Imola (Arctic Aegis)

    -- [ Bentley ]
    1961137, -- Bentley Batur (Kim Cương Lấp Lánh)
    1961138, -- Bentley Batur (Tận Cùng Thời Gian)
    1961139, -- Bentley Betayga Azure (Vương Quốc Huyền Ảo)
    1903200, -- Bentley Flying Spur Mulliner (Tinh Vân Xanh)
    1903201, -- Bentley Flying Spur Mulliner (Dòng Chảy Vịnh Hẹp)
    1908094, -- Bentley Betayga Azure (Mưa Hoa)
    1908095, -- Bentley Betayga Azure (Đêm Yên Tĩnh)
    1915008, -- Bentley Continental GTC Mulliner (Mộng Cảnh Lung Linh)
    1915009, -- Bentley Continental GTC Mulliner (Quý Tộc Áo Tím)

    -- [ Maserati ]
    1961038, -- Maserati MC20 Bianco Audace
    1961039, -- Maserati MC20 Rosso Vincente
    1961040, -- Maserati MC20 Sogni
    1908075, -- Maserati Levante Blu Emozione
    1908076, -- Maserati Luce Arancione
    1908077, -- Maserati Levante Neon Urbano
    1908078, -- Maserati Levante Firmamento

    -- [ Dodge / SRT ]
    1961036, -- Dodge Challenger SRT Hellcat - Blaze
    1961037, -- Dodge Challenger SRT Hellcat - Lime
    1961050, -- Dodge Challenger SRT Hellcat Jailbreak - Hellfire
    1961136, -- Dodge Challenger SRT Hellcat - Blaze
    1961150, -- Dodge Challenger SRT Hellcat Jailbreak - Hellfire
    1903088, -- Dodge Charger SRT Hellcat - Fuchsia
    1903089, -- Dodge Charger SRT Hellcat - Tuscan Torque
    1903090, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
    1903189, -- Dodge Charger SRT Hellcat - Tuscan Torque
    1903190, -- Dodge Charger SRT Hellcat Jailbreak - Violet Venom
    1908086, -- Dodge Hornet - Scarlet Sting
    1908088, -- Dodge Hornet GLH Concept - Redline
    1908089, -- Dodge Hornet - Sunburst
    1908188, -- Dodge Hornet GLH Concept - Redline
    1908189, -- Dodge Hornet - Sunburst

    -- [ Porsche ]
    1961062, -- Porsche 918 Spyder (Dòng Nước)
    1961063, -- Porsche 918 Spyder (964 Bạc Ánh Kim)
    1961064, -- Porsche 918 Spyder (Hồng)
    1903218, -- Porsche Panamera Turbo S (Lam Ngọc)
    1903219, -- Porsche Panamera Turbo S (Xanh Viper)
    1908108, -- Porsche Cayenne Turbo GT (Đường Đua Rực Lửa)
    1908109, -- Porsche Cayenne Turbo GT (Cam Dung Nham)
    1915021, -- Porsche 911 Carrera 4 GTS Cabriolet (Ngàn Sao)
    1915022, -- Porsche 911 Carrera 4 GTS Cabriolet (Đỏ Ruby)

    -- [ Shelby / Ford ]
    1961058, -- Shelby 427 Cobra (Xanh & Trắng)
    1961059, -- Shelby 427 Cobra (Graffiti Phục Cổ)
    1903210, -- Shelby GT500 (Đen & Đỏ)
    1903211, -- Shelby GT500 (Người Ngoài Hành Tinh Cyber)
    1961068, -- Ford Mustang GTD (Huyền Thoại Xanh Tươi)
    1961069, -- Ford Mustang GTD (Tinh Thần Nước Mỹ)

    -- [ Lotus ]
    1961060, -- Lotus Emira (Rừng Sâu Thẫm)
    1961061, -- Lotus Emira (Lướt Sắc Xanh)

    -- [ Apollo ]
    1961065, -- Apollo EVO (Vàng Rực Rỡ)
    1961066, -- Apollo EVO (Hoàng Hôn)
    1961067, -- Apollo EVO (Băng Giá)
    1903220, -- Apollo Intensa Emozione (Hỏa Ngục Nóng Chảy)
    1903221, -- Apollo Intensa Emozione (Bóng Ma Tím)
    1903222, -- Apollo Intensa Emozione (Quyết Đấu)
    1903223, -- Apollo Intensa Emozione (Bão Tố)

    -- [ SSC Tuatara ]
    1961140, -- Ảo Ảnh Hoa Hồng SSC Tuatara
    1961141, -- Hạc Trời SSC Tuatara
    1961142, -- Đao Bình Minh SSC Tuatara Striker
    1961143, -- Màn Đêm Xanh SSC Tuatara Striker

    -- [ Tesla ]
    1903071, -- Tesla Roadster (Kim Cương)
    1903072, -- Tesla Roadster (Pha Lê Tím)
    1903073, -- Tesla Roadster (Xanh Biển Cả)

    -- [ Ducati / Motor VIP ]
    1901028, -- Daryls Motorcycle
    1901076, -- Ducati Panigale V4S Swift Mirage
    1901075, -- Ducati Panigale V4S Crimson Storm
    1901074, -- Ducati Panigale V4S Black Phantom
    1901073, -- DUCATI Panigale V4S  
    1901018, -- Skeleton Chariot (Lv. 3)    
    1901027, -- Roaring Tiger Motorcycle (Lv. 3)
    1901047, -- Phantom Motorcycle (Lv. 7)
    1901066, -- Evangelion Mark.06 Motorcycle
    1901089, -- Cosmic Jump Motorcycle (Lv. 4)
    1901092, -- Indian FTR R Carbon
    1901093, -- Indian Scout 101
    1901108, -- CVO™ Road Glide® ST (Limited)
    1901070, -- Nether Visage 2-Seat Motorcycle
    1901090, -- Night Ember 2-Seat Motorcycle

    -- ==============================================================================
    -- 3. FULL BAY DÙ (DÙ RƠI, TÀU LƯỢN, VÁN TRƯỢT BAY)
    -- ==============================================================================
    -- [ DÙ (Parachutes) ]
    1401000, -- New Years Blessing Parachute
    1401001, -- Happy New Year Parachute
    1401002, -- Dù Xương Đỏ
    1401003, -- Dù tiểu quỷ tinh nghịch
    1401005, -- Dù nhện biến hình
    1401006, -- Dù Mùa 5
    1401007, -- Dù sinh nhật
    1401008, -- Dù Sếu Vàng
    1401009, -- Dù Quỷ Đỏ
    1401010, -- Dù hoa bách thảo
    1401011, -- Dù anh đào
    1401012, -- Dù Campus Tournament
    1401013, -- Dù Joker
    1401014, -- Dù chú hề
    1401015, -- Carabao Parachute
    1401016, -- Orange Life Parachute
    1401017, -- Dù ưng vàng
    1401018, -- Dù Quán quân Mùa 8
    1401019, -- Dù Đội trưởng Ryan
    1401020, -- Dù kẻ lang thang
    1401021, -- Dù cung trăng
    1401022, -- OPPO F11 PRO SURVIVOURS PARACHUTE
    1401023, -- Dù lãnh chúa Sekigahara (Vuông)
    1401024, -- Dù Đồng Minh Loot Thính
    1401025, -- Dù Đêm Mê Hoặc (Vuông)
    1401026, -- Dù cát tường
    1401027, -- Dù PMCO
    1401028, -- Dù Quán quân Mùa 7
    1401029, -- Dù sinh nhật rực rỡ
    1401031, -- Dù Quán quân Mùa 6
    1401032, -- Dù Dao Găm Đỏ
    1401033, -- Dù WALKER
    1401034, -- Dù Phù Thủy Băng Giá
    1401035, -- Dù người thách đấu
    1401036, -- Dù BAPE X PUBGM CAMO
    1401037, -- Dù Godzilla (Trắng)
    1401038, -- Dù Godzilla (Vàng)
    1401039, -- Dù Godzilla (Xanh)
    1401040, -- Dù Monarch
    1401041, -- Dù Cà Ri
    1401043, -- Dù Người Gác Đêm
    1401044, -- Dù hoa hồng đen
    1401045, -- Dù Mèo May Mắn
    1401046, -- Dù Đêm u ám
    1401047, -- Dù Cá Voi Sát Thủ
    1401048, -- Dù thủy quái Kraken
    1401050, -- Dù giai điệu âm nhạc
    1401051, -- Dù OPPO Reno
    1401052, -- Dù OPPO VOOC
    1401053, -- Dù Đêm Mê Hoặc
    1401054, -- Dù Chú Heo Tinh Nghịch
    1401055, -- Dù Red (Dài)
    1401056, -- PMJC Parachute
    1401057, -- PMSC Parachute
    1401059, -- Dù Quán quân Draconian
    1401060, -- Dù lãnh chúa Sekigahara
    1401061, -- Dù Tiểu Quỷ
    1401062, -- Dù Quán quân Mùa 9
    1401063, -- Dù Quán quân Mùa 10
    1401064, -- Dù Mèo Đen
    1401065, -- Dù Gà trống
    1401066, -- Dù Mọt Sách Băng Giá
    1401067, -- Dù Người Giảm Đau #11
    1401068, -- Super Power Parachute
    1401071, -- Dù Luân Hồi Vô Tận
    1401072, -- Dù Chúa Tể Muôn Loài
    1401074, -- Dù Bí Ngô Kinh Dị
    1401085, -- Dù Gà Thơm Ngon
    1401086, -- Dù Quán quân Mùa 11
    1401087, -- Dù Hoa Sen Máu
    1401088, -- Dù Hành Tinh Trôi Dạt
    1401089, -- Dù Quán Quân Mùa 12
    1401090, -- Dù Ninja Sát Thủ
    1401091, -- Dù Neko Sakura
    1401092, -- Dù Người Tiên Phong
    1401094, -- Dù Fantasy Girl
    1401095, -- Dù Tranh Vẽ Chiến Trường
    1401096, -- Dù Người Phán Quyết
    1401097, -- Dù Africa Pride
    1401098, -- Dù Africa Unite
    1401100, -- Dù Cậu Vàng
    1401102, -- Dù đặc vụ PMSC World Cup
    1401103, -- Dù Quân Đoàn Thất Lạc
    1401104, -- Dù Giải Đấu PMCO
    1401106, -- Dù Trung Úy Vũ Trụ
    1401107, -- Dù Đầy Tớ Huyết Nha
    1401108, -- Dù Street Dancer 3
    1401109, -- Dù Unique KingCard
    1401111, -- Dù Bánh Ú
    1401112, -- Dù Gào Thét
    1401113, -- Dù Thủ Vệ Tự Do
    1401115, -- Dù Kẹo Ngọt
    1401117, -- Dù Cao Bồi Viễn Tây
    1401119, -- Dù Giáp Samurai
    1401122, -- Incredible Parachute
    1401124, -- Dù Warrior
    1401125, -- Dù Quý Cô Gothic
    1401127, -- Dù Thần Thoại Ả Rập
    1401128, -- Dù Nhà Vô Địch Arena
    1401129, -- Dù Quán Quân Mùa 13
    1401130, -- Dù Gorilla
    1401131, -- Dù PMGC
    1401133, -- Dù Mùa 15
    1401134, -- Dù Tulip
    1401135, -- Dù Ác Ma Cuồng Nộ
    1401137, -- Dù Mùa 14
    1401138, -- Dù Pro League (Vàng)
    1401139, -- Dù Pro League (Bạc)
    1401140, -- Dù Lạc Đà Bảnh Bao
    1401141, -- Dù Gà Rán
    1401142, -- Dù CLB Hoàng Gia
    1401145, -- Dù Bảy Sắc
    1401146, -- Dù Mountain Dew
    1401147, -- Dù Tư Tế Tối Cao
    1401148, -- Dù Idol
    1401149, -- Dù Dang Rộng Đôi Cánh
    1401150, -- Dù Chiến Binh Thép
    1401151, -- Dù Quán Quân Mùa 16
    1401152, -- Dù Liềm Tử Thần
    1401153, -- Dù emoji Thỏa Mãn
    1401154, -- Dù emoji
    1401155, -- Dù emoji Vui Nhộn
    1401156, -- Dù Qualcomm
    1401157, -- Dù Điểm Sơ Tán
    1401159, -- Dù Lãnh Chúa Độc Tài
    1401160, -- Dù Kẹp Hạt Dẻ Vui Vẻ
    1401161, -- Dù Long Vương
    1401163, -- Dù Giáp Chiến Thần
    1401164, -- Dù Giai Điệu Yêu Thương
    1401165, -- Dù Quán Quân Mùa 17
    1401167, -- Dù Ánh Trăng Huyền Bí
    1401168, -- Dù Tiệc Disco
    1401169, -- Dù Quán Quân Mùa 18
    1401170, -- Dù Tuyết Anh Đào
    1401171, -- Dù Tổ Ong
    1401174, -- Dù Quán Quân Mùa 19
    1401177, -- Dù Quán Quân C1S1
    1401178, -- Dù Băng Cát Sét
    1401179, -- Dù El Diablo
    1401181, -- Chúa Tể Băng Giá - Dù
    1401182, -- Dù Kẻ Săn Mồi Biển Xanh
    1401183, -- Dù Mộng Điệp
    1401184, -- Dù Bọ Cánh Cứng
    1401186, -- Dù Rùa và Thỏ
    1401187, -- Dù Nhịp Bước Mạnh Mẽ
    1401188, -- Dù PMPL Mùa Xuân 2021
    1401189, -- Dù GodzillaVsKong
    1401190, -- Dù Hành Trình Kỳ Diệu
    1401191, -- Dù Dấu Ấn Vũ Trụ
    1401192, -- Dù Đầu Bếp Gà
    1401193, -- Dù Nghệ Thuật Sắc Màu
    1401194, -- Dù Aerial Punk Rich Brian
    1401195, -- Dù OPPO
    1401196, -- Dù BUG
    1401197, -- Dù Chúa Tể Bánh Răng
    1401198, -- Dù Xiaomi
    1401200, -- Dù Đôi Mắt Biển Sâu
    1401201, -- Dù OnePlus
    1401204, -- Dù foodpanda
    1401205, -- Dù PMPL Mùa Thu 2021
    1401208, -- Dù Thành Phố Trên Không
    1401209, -- Dù Bóng Ma Tương Lai
    1401210, -- Dù Mật Thám Cơ Khí
    1401212, -- Dù Thành Phố Sắc Màu
    1401213, -- Dù Súng Hoa Hồng
    1401215, -- Dù Băng Giá
    1401216, -- Dù Bản Đồ Kho Báu
    1401217, -- Dù Cơn Sốt Giáng Sinh
    1401218, -- Dù Họa Tiết Vàng
    1401219, -- Dù Vương Quốc Vàng
    1401220, -- Dù Hoàng Hôn Rực Rỡ
    1401221, -- Dù Bồ Câu Trắng
    1401222, -- Dù Vòng Xoay Thời Gian
    1401223, -- Dù Zong
    1401224, -- Dù Quán Quân C1S2
    1401225, -- Dù Quán Quân C1S3
    1401227, -- Dù Đại Hạ Giá
    1401228, -- Dù Lãng Khách Thời Thượng
    1401231, -- Dù PMGC 2021
    1401232, -- Dù Liverpool FC
    1401233, -- Dù Đột Phá
    1401234, -- Dù Voi Sắc Màu
    1401235, -- Dù Hợp Tác Egor Kreed
    1401236, -- Gackt Moon Parachute
    1401237, -- Dù Dune
    1401238, -- Dù Guruh Gundala
    1401239, -- Dù C2S4
    1401240, -- Dù Baby Shark
    1401241, -- Dù JAPAN LEAGUE S2
    1401242, -- Dù Đầu Bếp Quái Thú
    1401243, -- Dù Bá Chủ Đại Dương
    1401244, -- Dù C2S5
    1401245, -- Dù Nữ Hoàng Điện Tử
    1401246, -- Dù Nhâm Dần
    1401247, -- Dù Sắc Xuân
    1401248, -- Dù Jujutsu Kaisen
    1401249, -- Dù Shiba Inu
    1401250, -- Dù Motorola
    1401252, -- Dù Trận Chiến Trendy
    1401254, -- Dù DJ Cá Tính
    1401255, -- Dù Chị Chị Em Em
    1401256, -- Dù Graffiti Neon
    1401257, -- Dù C2S6
    1401258, -- Dù Người Nhện: Không Còn Nhà
    1401259, -- Dù Sát Thủ Thời Không
    1401260, -- Dù Vùng Đất Hoang
    1401261, -- Dù Sắc Màu
    1401262, -- Dù Lễ Hội Sắc Màu
    1401263, -- Dù Rạp Xiếc Thần Kỳ
    1401264, -- Dù Thiếu Nữ Tóc Đỏ
    1401265, -- Dù Bộ Đôi Hoàn Hảo
    1401266, -- Dù Thiếu Nữ Song Sinh
    1401267, -- Dù Cánh Cổng Kỳ Dị
    1401268, -- Dù Thiếu Nữ Anime
    1401269, -- Dù Gà Chiến Đấu
    1401270, -- Dù Nến Xanh
    1401271, -- Dù Hồn Ma Nghịch Ngợm
    1401272, -- Dù Thiếu Nữ Cầu Nguyện
    1401273, -- Dù Ma Nữ Đáng Yêu
    1401274, -- Dù Evangelion NERV
    1401275, -- Dù Chị Em Song Sinh
    1401276, -- Dù PMPL Mùa Xuân 2022
    1401277, -- Dù Gấu Teddy GB
    1401278, -- Dù Sư Tử Thời Trang
    1401280, -- Dù Kỷ Niệm Tuổi Thơ
    1401281, -- Dù C3S7
    1401282, -- Dù Mèo Khổng Lồ
    1401283, -- Dù Butterfinger
    1401284, -- Siêu Dù Nhảy
    1401285, -- Dù Đồng Minh Mùa Hè
    1401286, -- Dù Sóc Chuột
    1401287, -- Dù Hỏa Diệm Ma Giáp
    1401289, -- Dù Heartrocker
    1401290, -- Dù Sư Tử Lưỡng Hà
    1401291, -- Dù realme
    1401292, -- Dù Lil Burger
    1401294, -- Dù Dòng Sông Mộng Mơ
    1401295, -- Dù C3S8
    1401296, -- Dù Đêm Của Phép Màu
    1401298, -- Dù Vinh Quang
    1401299, -- Dù Bản Đồ Sao
    1401300, -- Dù Chúa Tể Gai Độc
    1401301, -- Dù Bóng Ma Và Nàng
    1401302, -- Dù Gai Bé Bỏng
    1401303, -- Dù Uqabi
    1401308, -- Dù Phù Thủy Băng Giá
    1401309, -- Dù Tốc Độ Cực Hạn
    1401310, -- Dù PMWI 2022
    1401311, -- BGMI Esports Parachute
    1401312, -- PMJL SEASON3 Parachute
    1401313, -- PMPS 2022 Parachute
    1401314, -- Dù Chiến Binh Ngưu
    1401315, -- Dù Quyền Lực Tối Thượng
    1401316, -- Dù Đội Bóng Ả Rập
    1401317, -- Dù Ngàn Sao Rực Rỡ
    1401318, -- Dù Pháp Sư Thiên Văn
    1401319, -- Dù C3S9
    1401320, -- Dù BoBoiBoy
    1401323, -- Dù Đường Đua Hoang Dã
    1401324, -- Dù Tuần Lộc Trắng
    1401325, -- Dù Rìu Hoàng Kim
    1401326, -- Dù Vàng Huyền Bí
    1401330, -- Dù Du Hành Tinh Vân
    1401332, -- Dù Mèo Tuyết
    1401334, -- Dù KFC
    1401335, -- Dù Thủy Sư Cuồng Nộ
    1401336, -- Dù Sọ Nham Thạch
    1401337, -- Dù Bá Chủ Bầu Trời
    1401338, -- Dù Grubhub
    1401339, -- Dù AFA
    1401340, -- Dù Huyền Thoại Siêu Sao Messi
    1401343, -- Dù PMGC 2022
    1401345, -- Dù Bản Đồ Kho Báu
    1401346, -- Dù Nobru
    1401347, -- Dù Sony
    1401349, -- Dù Đột Kích Trên Không
    1401351, -- Dù Nữ Hiệp
    1401353, -- Dù Chú Hề Quỷ Quyệt
    1401355, -- Dù Lý Tiểu Long
    1401356, -- Dù Cặp Đôi Diễn Võ
    1401357, -- Dù Donkey King
    1401360, -- Dù Pro League
    1401361, -- Dù Kế Hoạch Đỏ Thẫm
    1401362, -- Dù C4S11
    1401363, -- Dù Bản Đồ Vũ Trụ
    1401364, -- Dù BE@RBRICK
    1401365, -- Dù Nguồn Sáng Vinh Quang
    1401366, -- Dù Ký Ức Xưa
    1401367, -- Dù Bugatti
    1401368, -- Dù Hóa Thạch Khủng Long
    1401369, -- Dù Trốn Thoát T-Rex
    1401370, -- Dù Dragon Ball Super
    1401371, -- Dù C4S12
    1401372, -- Dù Huyết Rồng
    1401373, -- UNIVERSTAR BT21 Parachute
    1401374, -- Dù HUAWEI AppGallery
    1401375, -- Dù PMWI 2023
    1401376, -- Dù C5S13
    1401377, -- Dù Thỏ Disco
    1401378, -- Dù Aston Martin
    1401379, -- Dù Mùa Hè Trên Bãi Biển
    1401380, -- Dù C5S14
    1401381, -- Dù C5S15
    1401382, -- Dù PMGC 2023
    1401383, -- Dù KFC
    1401385, -- Dù Yeti Khổng Lồ
    1401386, -- Dù Pagani
    1401387, -- Dù Báo Sắc Màu
    1401388, -- Dù Bé Sóc Đáng Yêu
    1401389, -- Dù Kỳ Giông Hồng
    1401390, -- RS Swagster Parachute
    1401391, -- Dù Gấu Trúc Ngọt Ngào
    1401392, -- Dù Chiến Binh Hoa Hồng
    1401393, -- Dù Cuộc Chiến Chính Nghĩa
    1401394, -- Dù LINE FRIENDS
    1401395, -- Dù Hồ Ly Thần Bí
    1401396, -- Dù Zanmang Loopy
    1401397, -- Hardik Sky Parachute
    1401398, -- Dù C6S16
    1401399, -- Dù Bóng Ma Quyến Rũ
    1401400, -- Dù Bảo Hộ Hoàng Gia
    1401401, -- Dù Bentley
    1401402, -- SPY×FAMILY Dù
    1401403, -- Dù Nhật Thực
    1401404, -- Dù Chiến Sĩ Thần Giáp
    1401405, -- Dù C6S17
    1401406, -- Dù Giai Điệu Mèo Con
    1401407, -- Dù Thành Phố Hỗn Loạn
    1401408, -- Dù Đôi Cánh Cận Vệ
    1401409, -- Dù Thiết Mã
    1401410, -- Dù Bay Lướt Vũ Trụ
    1401411, -- Dù C6 S18
    1401412, -- Dù Nữ Đế Hắc Ám
    1401413, -- Dù Hợp Tác Lamborghini
    1401416, -- Dù Tượng Đá Cổ Xưa
    1401417, -- Dù Đại Dương Xanh
    1401418, -- KAKAO FRIENDS Parachute
    1401419, -- Dù Infinix GT
    1401420, -- Dù Esports World Cup 2024
    1401421, -- Dù C7S19
    1401422, -- Dù Thỏ Tinh Quái
    1401423, -- Dù Hợp Tác VW
    1401424, -- Dù Miêu Linh Sắc Màu
    1401425, -- Dù Hắc Long Ma Nhãn
    1401426, -- Dù Âm Dương
    1401427, -- NieR:Automata Parachute
    1401428, -- Dù Đam Mê Esports
    1401429, -- Dù C7S20
    1401430, -- Dù Venom: Kèo Cuối
    1401431, -- Dù Bộ Tộc Ngân Hà
    1401432, -- Dù Tuần Lộc Hoàng Gia
    1401433, -- Dù McLaren
    1401434, -- Dù PMGC 2024
    1401435, -- Dù lượn Sói Tuyết
    1401436, -- Dù lượn Bóng Nước
    1401437, -- Dù lượn C7S21
    1401438, -- Dù Cá Koi Xuân Sắc
    1401439, -- Dù Đại Bàng
    1401440, -- Dù Hoa Hồng Bóng Đêm
    1401441, -- Opanchu Parachute
    1401442, -- Neon Drop BE 6 Parachute
    1401443, -- Dù C8S22
    1401444, -- Dù Lượn Hắc Cốt
    1401445, -- Dù Cực Quang Tinh Tú
    1401446, -- Godzilla vs. Dù Destoroyah
    1401447, -- Dù Thỏ Bồng Bềnh
    1401448, -- Parachute(Frieren&Fern)
    1401449, -- Dù C8S23
    1401450, -- Dù Lượn Mã Số Hóa 
    1401451, -- Dù Lượn Khuếch Đại Sắc Màu
    1401452, -- Dù Hợp Tác Shelby
    1401453, -- Dù Ráng Chiều Rực Cháy
    1401454, -- Dù Attack on Titan
    1401455, -- Dù Cơ Khí 
    1401456, -- Mountain Dew Neon Shard Parachute
    1401457, -- Dù C8S24
    1401458, -- Dù Vũ Trụ
    1401459, -- Dù Transformers
    1401460, -- Dù Thần Mệnh
    1401461, -- Dù Cún Yêu
    1401462, -- Bbangbbang's diary Parachute
    1401463, -- Realme Parachute
    1401464, -- Dù Infinix GT
    1401465, -- Dù C9S25
    1401466, -- Dù Ác Quỷ
    1401467, -- Dù Kaiju No. 8
    1401468, -- Dù TEAM SONIC
    1401469, -- Dù Hồ Điệp Lấp Lánh
    1401470, -- Dù Lotus
    1401471, -- Dù Bông Xù
    1401472, -- Dù Gen Hoàn Hảo
    1401473, -- Tokyo Revengers Parachute
    1401474, -- Sky Striker Parachute
    1401475, -- Dù C9S26
    1401476, -- Dù Lượn Gấu Ngọt Ngào
    1401477, -- Dù Balenciaga
    1401478, -- Dù Lượn Tuyết Hàn
    1401479, -- Dù Porsche
    1401480, -- Dù Hắc Linh
    1401481, -- Dù Chồn Chill
    1401482, -- TV Anime DAN DA DAN Parachute
    1401483, -- Dù C9S27
    1401484, -- Dù Lượn Shuriken
    1401485, -- Dù Bóng Ma Anh Quốc
    1401486, -- Dù The King of Fighters
    1401487, -- Dù Lượn Vũ Khúc
    1401488, -- Dù Bảo Thạch
    1401489, -- Dù Chuỗi Mùa Giải (2026H1)
    1401490, -- Dù S28
    1401491, -- Dù Trò Chơi Chúa Hề Lém Lĩnh
    1401492, -- Dù Apollo
    1401493, -- Dù Hacker Lạnh Lùng
    1401494, -- Dù Hội Tụ Đa Chiều
    1401495, -- Catch! Teenieping Parachute
    1401496, -- SAKAMOTO TARO Parachute
    1401497, -- Nakiri Ayame Parachute
    1401498, -- Dù S29
    1401499, -- Toxic Parachute
    1401500, -- Dù Red (Tròn)
    1401511, -- Dù Mèo Tinh Nghịch
    1401513, -- Dù San Martin FC
    1401515, -- Dù Mắt Quỷ
    1401516, -- Dù Sóng Đêm
    1401517, -- Dù Quả Quýt
    1401519, -- Dù Gấu Ngáy Ngủ
    1401520, -- Dù Hậu Duệ Đế Vương
    1401521, -- Dù Mây Cuộn
    1401526, -- Dù Hoa Văn Tráng Lệ
    1401527, -- Dù Trái Tim Biển Cả
    1401528, -- Dù Hành Tinh Mẹ
    1401529, -- Dù Hoàng Tử Ánh Kim
    1401530, -- Dù Giáp Gai
    1401531, -- Dù Vùng Nguy Hiểm
    1401532, -- Dù Ốc Biển
    1401534, -- Dù Vịt Vàng B.Duck
    1401538, -- Dù Thỏ Dịu Dàng
    1401540, -- Dù Yeti
    1401541, -- Dù Pixel Sắc Màu
    1401542, -- Dù Mỹ Vị
    1401543, -- Dù I Love Tao Kae Noi
    1401544, -- Dù Vẹt Baby
    1401545, -- Dù U.F.O
    1401546, -- Dù Baby Shark
    1401547, -- Dù Gấu Nhồi Bông
    1401548, -- Dù Mèo Nghiêm Túc
    1401549, -- Dù Vinh Quang Trường Tồn
    1401551, -- Dù Nữ Vương Khôi Giáp
    1401554, -- Dù Khủng Long Pixel
    1401555, -- Dù Cánh Bướm Hoàng Gia
    1401556, -- Dù Hành Trình Ngọt Ngào
    1401610, -- Dù Chúc Mừng Sinh Nhật
    1401611, -- Dù Sân Khấu Lấp Lánh
    1401613, -- Dù Thẩm Phán Anubis
    1401615, -- Dù Thần Horus
    1401616, -- Dù One Plus
    1401617, -- Dù Sư Tử Hống
    1401618, -- Dù Facebook
    1401619, -- Dù Bùa Hộ Mệnh Pharaoh
    1401620, -- Dù Pharaoh (Xanh)
    1401621, -- Dù Huyết Nha
    1401622, -- Dù LINE FRIENDS
    1401623, -- Dù PMNC 2021
    1401624, -- Dù Poseidon
    1401625, -- Dù Công Chúa Bộ Lạc
    1401628, -- Dù Phượng Hoàng Adarna Ảo Diệu
    1401629, -- Dù Thiếu Nữ Sáng Thế
    1401811, -- Giannis Parachute
    1401813, -- Dù Hành Trình Anh Hùng
    1401814, -- Dù Rock 'n' Roll
    1401815, -- Dù Chỉ Huy Chiến Trường
    1401816, -- Dù BURGER KING
    1401817, -- Dù Chiến Binh Huyết Ưng
    1401820, -- Dù Cá Chuồn
    1401822, -- Dù Quái Thú Đầm Lầy
    1401823, -- Dù Lãnh Chúa Phong
    1401824, -- Dù Hộp Quà
    1401826, -- Dù - Mối Tình Đầu
    1401827, -- Dù Nữ Hoàng Cà Phê
    1401828, -- Dù Vệ Binh Cổ Đại
    1401829, -- Dù Cơn Giận Của Thần
    1401832, -- Dù C4S10
    1401833, -- Dù Quái Thú Mê Cung
    1401835, -- Dù Poker Đối Kháng
    1401836, -- Dù Trò Chơi Chú Hề
    1401837, -- Dù Huyễn Ảnh
    1401838, -- Dù BLUE LOCK
    1401839, -- Dù Ford
    1401840, -- Dù Harley-Davidson®
    1401841, -- Dù Hoa Hồng Cốt
    1401842, -- Dù Song Tử
    1401843, -- Dù Lượn Vòng Nguyệt Quế
    1401844, -- Parachute(Pubniku)
    1401845, -- Dù S30
    1401846, -- Dù Sự Kiện Trial of Fire

    -- [ TÀU LƯỢN / VÁN TRƯỢT / THIẾT BỊ BAY (Gliders/Hoverboards) ]
    4151001, -- Dù (Xanh)
    4151002, -- Hiệu ứng nhảy dù (Vàng)
    4151003, -- Khói Lượn Dù (Hồng)
    4151004, -- Khói lượn xanh
    4151006, -- Khói lượn cầu vồng
    4151010, -- Thiết bị bay Bằng Chíu
    4151012, -- Ván Trượt Chu Kỳ
    4151013, -- Ván Trượt Tuyết
    4151014, -- Ván trượt CHU KỲ 2
    4151015, -- Khói Lượn Dù Chúc Mừng (3 màu)
    4151017, -- Ván trượt Trái Tim Rừng Xanh
    4151018, -- Ván trượt Sinh Nhật
    4151019, -- Tàu Lượn Chiến Thần Tình Yêu
    4151020, -- Ván Trượt Cảnh Vệ C3
    4151021, -- Tàu Lượn Sứ Giả Của Thần
    4151022, -- Tàu Lượn Cánh Vàng
    4151023, -- Ván Trượt Hợp Tác Messi
    4151024, -- Tàu Lượn Giáo Sĩ Đỏ Thẫm
    4151025, -- Tàu Lượn Diều Giấy
    4151026, -- Ván Trượt Đại Sư Võ Hồn
    4151027, -- Ván Trượt Cycle 4
    4151028, -- Ván Trượt Giọt Lệ Huyết
    4151029, -- Tàu Lượn Nữ Đế Ánh Sáng
    4151030, -- Tàu Lượn Ma Vương Huyết Hồn
    4151031, -- Tàu Lượn Khủng Long Túi Tiền
    4151032, -- Tàu Lượn Cánh Rồng Đỏ Thẫm
    4151034, -- Cân Đẩu Vân
    4151035, -- Tàu Lượn Giao Hưởng Gió
    4151036, -- Ván Trượt Máy Dập Sóng
    4151037, -- Ván Trượt CYCLE 5
    4151038, -- Dù Lượn Ngọc Trai Tuyệt Hảo
    4151040, -- Ván trượt Thợ Săn Điện Quang
    4151041, -- Dù Lượn Xương Xanh
    4151042, -- Tàu Lượn Công Chúa Công Nghệ
    4151043, -- Tàu Lượn Công Chúa Công Nghệ
    4151044, -- Ván Trượt Cá Mập
    4151045, -- Dù Lượn Mùa Đông Hoàng Gia
    4151046, -- Ván Trượt Lưỡi Dao Trời Xanh
    4151056, -- Dù Lượn Mùa Đông Hoàng Gia
    4151057, -- Ván Trượt Hỏa Hồ Ly
    4151058, -- Dù Lượn LINE FRIENDS
    4151059, -- Ván Trượt Xuyên Mây
    4151060, -- Dù Lượn Xà Kim
    4151061, -- Ván Trượt CYCLE 6
    4151062, -- Khói Lượn Dù Zanmang Loopy
    4151063, -- SPY×FAMILY Tàu Lượn Bond
    4151064, -- Dù Lượn Thiên Sứ
    4151065, -- Dù Lượn Thiên Sứ
    4151066, -- Dù Lượn Đế Vương Thần Vực
    4151067, -- Dù Lượn Kính Vạn Hoa
    4151068, -- Tàu Lượn Chúa Tể Gai Độc
    4151069, -- Tàu Lượn Tinh Vân Sấm Sét
    4151070, -- Tàu Lượn Kỵ Binh Thần Giáp
    4151071, -- Dù Lượn Vệ Thần Tình Ái
    4151072, -- Dù Lượn Ngao Du Vũ Trụ
    4151073, -- Dù Lượn Neon Huyền Bí
    4151074, -- PUBGM X NewJeans Glider
    4151075, -- Dù Lượn Vệ Thần Tình Ái
    4151076, -- Tàu Lượn Cửu Phong Thiên Tôn
    4151077, -- Máy Bay
    4151078, -- Tàu Lượn Hải Mã Sắt
    4151079, -- Tàu Lượn Đôi Cánh Thế Giới Ngầm
    4151080, -- Ván Trượt Cycle 7
    4151083, -- Dù Lượn Long Cốt
    4151084, -- Hồng Hỏa Diệm - Kar98 (Cấp 8)
    4151085, -- Dù Lượn Cánh Thép Xuyên Không
    4151086, -- DP Drift Parachute
    4151087, -- Dù Lượn Long Cốt
    4151089, -- Dù Lượn Hắc Điểu 
    4151090, -- Dù Lượn Giấc Mộng Ngọt Ngào
    4151091, -- Tàu Lượn Nhà Khám Phá Vũ Trụ
    4151092, -- Dù Lượn Lam Sư Tinh Hà
    4151093, -- Dù Lượn Ngọc Lang Thiên Giới
    4151094, -- Ván Trượt CYCLE 8
    4151095, -- Dù Lượn Đôi Cánh Anukhra
    4151096, -- Dù Lượn Đôi Cánh Pharaoh
    4151097, -- Tàu Lượn Siêu Thú Ghidorah
    4151098, -- Dù Lượn Thời Quang Khả Biến
    4151099, -- Dù Lượn Vương Quyền Hắc Ám
    4151103, -- Dù Lượn Chiến Xa Tinh Tú
    4151104, -- Tàu Lượn Thiết Bị ODM
    4151105, -- Dù Lượn Định Mệnh Huyết Chú
    4151106, -- Dù Lượn Quang Ảo Điện Từ 
    4151107, -- Dù Lượn Chiến Xa Tinh Tú
    4151108, -- Tàu Lượn Laserbreak
    4151109, -- Tàu Lượn Băng Thần
    4151110, -- Tàu Lượn Long Thánh
    4151111, -- Tàu Lượn Thợ Săn Phản Lực
    4151112, -- Tàu Lượn Tà Thần Mỹ Quang
    4151113, -- Ván Trượt CYCLE 9
    4151114, -- Tàu Lượn Long Thánh
    4151115, -- Tàu Lượn Băng Thần
    4151117, -- Tàu Lượn Preondactyl
    4151118, -- Dù Lượn Hồ Điệp Lấp Lánh
    4151119, -- Dù Lượn Chổi Phép Thuật
    4151120, -- Dù Lượn Long Kính
    4151121, -- Mikey Glider
    4151122, -- Dù Lượn Hồ Điệp Lấp Lánh
    4151123, -- Tàu Lượn Băng Linh Lưu Ly
    4151124, -- Tàu Lượn Huyết Dực Tử Thần
    4151125, -- Tàu Lượn Vệ Binh Ngân Hà
    4151126, -- Tàu Lượn Giải Trí
    4151127, -- Tàu Lượn Linh Mộc Vĩnh Cửu
    4151128, -- Tàu Lượn Thần Quang
    4151129, -- Ván Trượt Chuỗi Mùa Giải (2026H1)
    4151130, -- Tàu Lượn Nue
    4151131, -- Tàu Lượn Phượng Hoàng Đế Vương
    4151132, -- Tàu Lượn Huyết Dực Hắc Điểu
    4151133, -- Tàu Lượn Dịch Chuyển Không Gian
    4151134, -- Dù Lượn Đa Vũ Trụ
    4151135, -- SAKAMOTO TARO Glider
    4151138, -- Tàu Lượn Sấm Sét Đỏ
    4151139, -- Tàu Lượn Hư Không
    4151140, -- Tàu Lượn Song Tử
    4151141, -- Tàu Lượn Cerberus
    4151142, -- Tàu Lượn Ngọc Trai
    4151143, -- Tàu Lượn Song Tử
    202408087,
    202408061,
    1102001001,
    4152031, -- Tàu Lượn Ma Vương Huyết Hồn
    4152035, -- Cân Đẩu Vân
    4152036, -- Windborne Euphony Glider
    4152037, -- Ván Trượt Máy Dập Sóng
    4152038, -- Ván Trượt CYCLE 5
    4152039, -- Tàu Lượn Ngọc Trai Tuyệt Hảo
    4152041, -- Boxerbolt Hoverboard (Shop)
    4152042, -- Blueyonder Glider
    4152043, -- Agile Charmer Glider
    4152044, -- Agile Charmer Glider
    4152045, -- Chilly Perch Glider
    4152046, -- Foxy Flare Hoverboard
    4152058, -- LINE FRIENDS Glider (Shop)
    4152059, -- Cloud Piercer Hoverboard (Shop)
    4152060, -- Golden Wings Glider (Shop)
    4152061, -- CYCLE 6 Skateboard (Shop)
    4152063, -- Tàu Lượn Bond SPY×FAMILY (Cửa Hàng)
    4152066, -- Dù Lượn Đế Vương Thần Vực (Cửa Hàng)
    4152067, -- Tàu Lượn Kính Vạn Hoa (Cửa Hàng)
    4152068, -- Tàu Lượn Chúa Tể Gai Độc (Cửa Hàng)
    4152069, -- Tàu Lượn Tinh Vân Sấm Sét (Cửa Hàng)
    4152070, -- Tàu Lượn Kỵ Binh Thần Giáp (Cửa Hàng)
    4152076, -- Tàu Lượn Cửu Phong Thiên Tôn (Cửa Hàng)
    4152077, -- Tàu Lượn (Cửa Hàng)
    4152078, -- Tàu Lượn Hải Mã Sắt (Cửa Hàng)
    4152079, -- Tàu Lượn Đôi Cánh Thế Giới Ngầm (Cửa Hàng)
    4152080, -- Ván Trượt CYCLE 7 (Cửa Hàng)
    4152092, -- Tàu Lượn Lam Sư Tinh Hà (Cửa Hàng)
    4152093, -- Tàu Lượn Ngọc Lang Thiên Giới (Cửa Hàng)
    4152094, -- Ván Trượt CYCLE 8 (Cửa Hàng)
    4152095, -- Dù Lượn Đôi Cánh Anukhra
    4152096, -- Dù Lượn Đôi Cánh Pharaoh
    4152097, -- Tàu Lượn Siêu Thú Ghidorah
    4152098, -- Dù Lượn Thời Quang Khả Biến
    4152099, -- Dù Lượn Vương Quyền Hắc Ám
    4152116, -- Tàu Lượn Long Thánh (Sảnh Một Người)

    -- ==============================================================================
    -- 3. TRANG PHỤC (OUTFITS), X-SUIT & PHỤ KIỆN
    -- ==============================================================================
    -- [ X-SUIT ]
    1407895, -- X-Suit Quạ Huyết (7 Sao)
    1407856, -- X-Suit Phượng Hoàng (7 Sao)
    1405628, -- X-Suit Pharaoh Vàng (6 Sao)
    1406469, -- X-Suit Pharaoh Vàng (7 Sao)
    1405870, -- X-Suit Quạ Huyết (6 Sao)
    1407140, -- X-Suit Poseidon (7 Sao)
    1407142, -- X-Suit Silvanus (7 Sao)
    1407141, -- X-Suit Bão Tuyết (7 Sao)
    1407550, -- X-Suit Ánh Sáng Cầu Vồng (7 Sao)
    1406638, -- X-Suit Hề Bí Ẩn (6 Sao) [Đen]
    1406641, -- X-Suit Hề Bí Ẩn (6 Sao) [Trắng]
    1406872, -- X-Suit Chúa Tể Âm Ty (7 Sao)
    1406971, -- X-Suit Marmoris (7 Sao)
    1407103, -- X-Suit Fiore (7 Sao)
    1407219, -- X-Suit Ignis (7 Sao)
    1407366, -- X-Suit Galadria (7 Sao)
    1407512, -- X-Suit Anukhra (7 Sao)
    1407625, -- X-Suit Dravion (7 Sao) [Nam]
    1407667, -- X-Suit Dravion (7 Sao) [Nữ]

    -- [ OUTFITS ]
    1407870, -- Bộ Nữ Thần Không Gian
    1407871, -- Bộ Thám Tử Đa Vũ Trụ
    1407812, -- Bộ Vệ Binh Hoang Dã
    1407758, -- Bộ Tiên Nữ Mùa Đông
    1407286, -- Bộ Mèo Cyber Tinh Nghịch
    1407329, -- Bộ Ánh Sáng Tĩnh Lặng
    1407391, -- Bộ Nữ Bá Tước Ma Cà Rồng
    1407392, -- Bộ Kẻ Phá Hoại Man Rợ
    1407387, -- Bộ Tử Thần Tận Thế
    1407440, -- Bộ Kẻ Chinh Phục Bắc Cực
    1406985, -- Bộ Người Tình Bãi Biển
    1407470, -- Bộ Thiên Thần Nổi Loạn
    1407471, -- Bộ Cực Quang Nanh Ngọc
    1407522, -- Bộ Hậu Duệ Tiên Cát
    1407330, -- Bộ Đô Đốc Bóng Ma
    1407523, -- Bộ Uy Quyền Tà Ác
    1407558, -- Bộ Thái Dương Thăng Hoa
    1407559, -- Bộ Ánh Sáng Nguyệt Cung
    1407572, -- Bộ Huyết Dạ Hoàng Hôn
    1407682, -- Bộ Kén Ẩn Sĩ
    1407695, -- Bộ Lễ Tình Nhân Rùng Rợn
    1407696, -- Bộ Lăng Kính Thăng Hoa
    1407632, -- Bộ Hắc Dạ Tà Ác
    1407573, -- Bộ Bóng Ma Điện Tử
    1406398, -- Bộ Bóng Ma Rực Lửa
    1406399, -- Bộ Kỵ Binh Oai Vệ
    1406482, -- Bộ Chúa Tể Gai Góc
    1406483, -- Bộ Tinh Vân Sấm Sét
    1406555, -- Bộ Khuôn Mặt Địa Ngục
    1406573, -- Bộ Thiên Nga Bóng Ma
    1406574, -- Bộ Quan Tòa Vũ Trụ
    1406656, -- Bộ Trưa Đẫm Máu
    1406657, -- Bộ Đô Đốc Biển Sao
    1406742, -- Bộ Đạo Sư Bạc
    1406744, -- Bộ Hiệp Sĩ Thái Dương
    1406789, -- Bộ Bóng Ma Địa Ngục
    1406823, -- Bộ Giọt Nguyệt Bất Diệt
    1406824, -- Bộ Kẻ Thù Nhuốm Máu
    1406897, -- Bộ Ác Mộng Đỏ Thẫm
    1407277, -- Trang Phục Hỏa Thần Cổ Ngữ
    1406891, -- Trang Phục Linh Hồn Xác Ướp
    1405623, -- Bộ Xác Ướp Vàng
    1400687, -- Bộ Xác Ướp Trắng
    1407618, -- Bộ Thực Hồn Bắc Cực (Polar Spectrophage)

    -- [ Dragon Ball Super Collab ]
    1406937, -- Trang Phục Nhân Vật Super Saiyan Son Goku
    1406938, -- Trang Phục Nhân Vật Frieza
    1406939, -- Trang Phục Nhân Vật Son Goku
    1406947, -- Trang Phục Nhân Vật Vegeta
    1406948, -- Trang Phục Nhân Vật Super Saiyan Vegeta
    1406950, -- Trang Phục Beerus
    1406951, -- Trang Phục Ma Bư
    1406952, -- Trang Phục Quy Lão Kame
    1406953, -- Trang Phục Nhân Vật Gohan Siêu Cấp
    1406954, -- Trang Phục Nhân Vật Piccolo
    1407264, -- Trang Phục Nhân Vật Vegito
    1407265, -- Trang Phục Nhân Vật Vegito Siêu Saiyan
    1407266, -- Trang Phục Nhân Vật Vegito Siêu Saiyan Xanh
    1407267, -- Trang Phục Nhân Vật Son Goku Siêu Saiyan Xanh
    1407268, -- Trang Phục Nhân Vật Son Goku Siêu Saiyan Xanh (Bị Thương)
    1407269, -- Trang Phục Nhân Vật Vegeta Super Saiyan Xanh
    1407270, -- Trang Phục Nhân Vật Vegeta Siêu Saiyan Xanh (Bị Thương)
    1407271, -- Trang Phục Nhân Vật Bulma

    -- [ Evangelion Collab ]
    1406385, -- Plugsuit Evangelion Shinji
    1406386, -- Plugsuit Evangelion Rei
    1406387, -- Plugsuit Evangelion Asuka
    1406388, -- Plugsuit Evangelion Mari
    1406389, -- Plugsuit Evangelion Kaworu

    -- [ Attack on Titan Collab ]
    1407563, -- Trang Phục Nhân Vật Eren Jaeger
    1407565, -- Trang Phục Nhân Vật Mikasa Ackermann
    1407566, -- Trang Phục Nhân Vật Armin Arlelt
    1407567, -- Trang Phục Titan Khổng Lồ (Armin)
    1407568, -- Trang Phục Nhân Vật Levi
    1407569, -- Trang Phục Titan Bọc Thép

    -- [ Kaiju No. 8 Collab ]
    1407672, -- Trang Phục Nhân Vật Kafka Hibino
    1407673, -- Trang Phục Kaiju No. 8
    1407674, -- Trang Phục Nhân Vật Kikoru Shinomiya
    1407675, -- Trang Phục Kaiju No. 9
    1407676, -- Trang Phục Kaiju No. 10
    1407677, -- Trang Phục Nhân Vật Mina Ashiro
    1407678, -- Trang Phục Nhân Vật Reno Ichikawa
    1407679, -- Trang Phục Nhân Vật Soshiro Hoshina

    -- [ BlackPink & Kpop Collabs ]
    1406132, -- Trang phục DDU-DU DDU-DU ROSÉ
    1406133, -- Trang phục DDU-DU DDU-DU JENNIE
    1406134, -- Trang phục DDU-DU DDU-DU JISOO
    1406135, -- Trang phục DDU-DU DDU-DU LISA
    1406161, -- Trang phục How You Like That ROSÉ
    1406162, -- Trang phục How You Like That JENNIE
    1406163, -- Trang phục How You Like That JISOO 
    1406164, -- Trang phục How You Like That LISA
    1406178, -- Trang phục Lovesick Girls ROSÉ
    1406179, -- Trang phục Lovesick Girls JENNIE
    1406180, -- Trang phục Lovesick Girls JISOO
    1406181, -- Trang phục Lovesick Girls LISA
    1407346, -- PUBGM X NewJeans MINJI Set
    1407347, -- PUBGM X NewJeans HANNI Set
    1407348, -- PUBGM X NewJeans HAERIN Set
    1407349, -- PUBGM X NewJeans DANIELLE Set
    1407350, -- PUBGM X NewJeans HYEIN Set
    1407745, -- Trang Phục RAMI (Babymonster)
    1407746, -- Trang Phục ASA (Babymonster)
    1407747, -- Trang Phục AHYEON (Babymonster)
    1407748, -- Trang Phục RORA (Babymonster)
    1407749, -- Trang Phục CHIQUITA (Babymonster)
    1407750, -- Trang Phục PHARITA (Babymonster)
    1407751, -- Trang Phục RUKA (Babymonster)
    1407826, -- Trang Phục PUBG MOBILE × aespa KARINA
    1407827, -- Trang Phục PUBG MOBILE × aespa GISELLE
    1407828, -- Trang Phục PUBG MOBILE × aespa WINTER
    1407829, -- Trang Phục PUBG MOBILE × aespa NINGNING
    1407687, -- Trang Phục G-DRAGON PEACEMINUSONE
    1407688, -- Trang Phục Sân Khấu của G-DRAGON

    -- [ CÁC COLLAB NỔI BẬT KHÁC (Messi, Lý Tiểu Long, SPYxFAMILY...) ]
    1406648, -- Trang Phục Biểu Tượng Bóng Đá Messi
    1406649, -- Trang Phục Huyền Thoại Siêu Sao Messi
    1406728, -- Trang Phục Kung Fu Lý Tiểu Long
    1406729, -- Trang Phục Chuyên Gia Cận Chiến Lý Tiểu Long
    1406730, -- Trang Phục Rồng Gầm Lý Tiểu Long
    1406731, -- Trang Phục Võ Sĩ Lý Tiểu Long
    1407206, -- SPY×FAMILY Trang Phục Hoàng Hôn
    1407401, -- C.C. Set
    1407402, -- Kallen Kozuki Set
    1407404, -- Suzaku Kururugi Set
    1407405, -- ZERO Set
    1407408, -- Emperor Lelouch Set
    1407769, -- Okarun(transformed) Set
    1407770, -- Okarun Set
    1407771, -- Momo Set
    1407772, -- Jiji(transformed) Set
    1407773, -- Aira Set
    1407794, -- Trang Phục Nhân Vật John Shelby
    1407795, -- Trang Phục Nhân Vật Arthur Shelby
    1407796, -- Trang phục Thomas Shelby
    1407798, -- Trang Phục Nhân Vật Iori Yagami
    1407800, -- Trang Phục Nhân Vật Mai Shiranui
    1407801, -- Trang Phục Nhân Vật Nakoruru
    1407846, -- Trang Phục Nhân Vật Kimono Ryomen Sukuna
    1407848, -- Trang Phục Nhân Vật Suguru Geto
    1407901, -- Trang Phục Nhân Vật Isagi Yoichi
    1407902, -- Trang Phục Nhân Vật Bachira Meguru

    -- [ Set Đồ Đỏ Tự Nhiên & Siêu VIP của Game ]
    1405160, -- Huyền Thoại Godzilla
    1405161, -- Siêu Thú Ghidorah
    1405186, -- Bộ Đồ Godzilla
    1405662, -- Trang phục Giáp Samurai
    1405663, -- Trang phục Sát Thủ Bóng Đêm
    1406020, -- Trang phục Quái Thú
    1406398, -- Trang phục Hỏa Diệm Ma Giáp
    1406399, -- Trang phục Kỵ Binh Thần Giáp
    1406456, -- Trang Phục Anh Hùng Truyền Thuyết
    1406568, -- Trang Phục Nữ Hoàng Bóng Đêm
    1406569, -- Trang Phục Minh Vương Hành Quyết
    1406732, -- Trang Phục Nữ Đế Hoàng Kim
    1406733, -- Trang Phục Hoàng Đế Hoàng Kim
    1406764, -- Trang Phục Thiếu Nữ Đỏ Rực

    -- ==============================================================================
    -- 4. ÁO, QUẦN, GIÀY ĐẸP & TDM (PHONG CÁCH CỰC CHẤT)
    -- ==============================================================================
    -- [ BAPE & ALAN WALKER ]
    1400569, -- BAPE MIX CAMO HOODIE
    1400650, -- BAPE MIX CAMO SHORTS
    1400651, -- BAPE STA MID
    1404000, -- BAPE City Camo Hoodie
    1404002, -- BAPE City Camo Pants
    1404003, -- BAPE Sta Mid
    1404048, -- Áo BAPE X PUBGM CAMO
    1404049, -- Áo Hoodie cá mập BAPE X PUBGM CAMO
    1404050, -- Quần BAPE X PUBGM CAMO
    1404051, -- Giày BAPE X PUBGM CAMO
    1404016, -- Alan Walker T-shirt
    1404017, -- Alan Walker Hoodie
    1404042, -- Trang phục Alan Walker
    1404043, -- Áo Alan Walker
    1404044, -- Quần Alan Walker
    1404045, -- Giày Alan Walker
    1404340, -- Trang phục Alan Walker 2021
    1403038, -- Alan Walker Mask
    1403064, -- Khẩu trang Alan Walker

    -- [ Đồ TDM Phổ Biến (Khăn bịt mặt, Áo Lính, Áo Khoác Đen...) ]
    402001, -- Khăn rằn sinh tồn
    402037, -- Khăn quàng cao bồi
    402043, -- Khăn quàng PUBG (Đỏ-Đen)
    402045, -- Khăn quàng PUBG (Chiến thuật)
    1400158, -- Mặt Nạ Hockey
    1402005, -- Mysterious Leather Mask
    1403100, -- Mặt nạ người leo núi
    403010, -- Áo Ba Lỗ Bẩn (Trắng)
    403028, -- Áo Trench coat (Màu đen)
    403181, -- Áo lính sa mạc
    403182, -- Áo Hoodie săn mồi (Đen)
    403183, -- Áo Hoodie biệt kích (Trắng)
    403192, -- Áo khoác bomber
    404006, -- Quần Jeans (Nâu)
    404008, -- Quần lính (Ka-ki)
    404013, -- Quần lính (Rằn ri)
    404015, -- Quần Jeans Bó (Màu Lam)
    404026, -- Quần túi hộp (Màu be)
    404028, -- Quần túi hộp (Màu đen)
    404084, -- Quần thể thao ngắn (Đen)
    404100, -- Quần người ẩn nấp (Đen)
    405001, -- Giày đế mềm (Màu trắng)
    405002, -- Giày thể thao cổ cao
    405019, -- Giày lính chim ưng (Đen)
    405044, -- Giày đế mềm (Đen)
    1400013, -- Quần Jeans Mỹ

    -- [ CÁC ÁO LẺ VIP (Collab, Siêu Xe) ]
    1404142, -- Áo thun THE WALKING DEAD (Trắng)
    1404143, -- Áo thun THE WALKING DEAD (Đen)
    1404218, -- Áo Hoodie COVERNAT (Trắng)
    1404219, -- Áo Hoodie COVERNAT (Đen)
    1404326, -- Áo thun Xiaomi
    1404327, -- Áo thun OnePlus
    1404405, -- Áo Đấu Hợp Tác Messi × PUBG MOBILE
    1404406, -- Áo Thun Lý Tiểu Long
    1404411, -- Hoodie Ducati
    1404412, -- Giày Ducati Corse City C2
    1404413, -- Quần Ducati Sport C2
    1404414, -- Áo Khoác Ducati Speed Evo C2
    1404426, -- Áo PMGC 2023
    1404427, -- Quần Người Chinh Phục Pagani
    1404428, -- Giày Người Chinh Phục Pagani
    1404508, -- Áo Hoodie Mr.Beast
    1400324, -- áo b
    1400325, -- áo a
    452001, 452002, 452003, -- Găng Tay (Gloves)
    
        -- [ HÀNH ĐỘNG ]
    12201301, -- Hành động Sát thủ Gothic
    12216101, -- Hành động Võ sĩ Huyết Ưng
    12212201, -- Hành động Sát thủ Cực Ám
    12219207, -- Hành động Đại tướng Thiên Ngưu
    12209001, -- Hành động Võ sĩ (Samurai)
    12219561, -- Hành động Áo choàng Đỏ thẫm
    12210001, -- Hành động Cái chạm của Tử thần
    12219022, -- Hành động Thiết vệ Gai góc
    12208801, -- Hành động Dũng sĩ Bán thần
    12210801, -- Hành động Thợ săn Vỏ bạc
    12200701, -- Hành động Du hành Không thời gian
    12219242, -- Hành động Dạo bước Bầu trời
    12206001, -- Hành động Hoa linh Đồng xanh
    12205401, -- Hành động Vua của muôn thú
    12205201, -- Hành động Trái tim Cự thú
    12212601, -- Hành động Sát lục Thần bí
    12205601, -- Hành động Linh hồn Cự thú
    12219208, -- Hành động Hầu vương Cyber
    12212001, -- Hành động Võ thánh
    12206801, -- Hành động Hải long Thần bí
    12209801, -- Hành động Ngự linh sư
    12211401, -- Hành động Nữ phù thủy Băng tuyết
    12207001, -- Hành động Du hành Biển sao
    12211801, -- Hành động Chúa tể Trật tự
    12207901, -- Hành động Hải vương Quyến rũ
    12203401, -- Hành động Kỷ niệm Ảo ảnh
    12204001, -- Hành động Chú hề (Ngày Cá tháng Tư)
    12201801, -- Hành động Người bảo vệ Vùng tuyết
    12215601, -- Hành động Siêu nhân Hằng tinh
    12215532, -- Hành động Lãnh chúa Ngọn lửa
    12213201, -- Hành động Kế hoạch Ngày mai
    12215529, -- Hành động Kỵ sĩ Đua xe
    12219053, -- Hành động Nữ hoàng Trân bảo
    12204601, -- Hành động Thiên hạ Bố võ
    12215701, -- Hành động Hành tinh Vượn người
    12219003, -- Hành động Bóng tối Thần linh
    12219004, -- Hành động Ngân hồn Rực lửa
    12219009, -- Hành động Mê hoặc Rực lửa
    12219216, -- Hành động Tế tư Héo úa
    
    
    -- tóc mặt tùm lum
    1404198, 1410085, 1404366, 1403137, 1410480, 1403028, 1400158, 40605011, 1404323, 1406001, 1403002,

-- ==============================================================================
    -- MŨ GIÁP VIP (CHỈ LẤY CẤP 1 - GỌN GÀNG, DỄ ẨN NẤP)
    -- ==============================================================================
    1502001183, -- Godzilla Helmet (Lv. 1)
    1502001194, -- Mũ MECHAGODZILLA (Cấp 1)
    1502001093, -- Mũ Thẩm Phán Anubis (Cấp 1) - Pharaoh
    1502001305, -- Mũ Giáp Siêu Nhân Thép (Cấp 1)
    1502001320, -- Mũ Giáp Biểu Tượng Bóng Đá Messi (Cấp 1)
    1502001105, -- Mũ Tàng Hình (Cấp 1)
    1502001364, -- Mũ Giáp PMGC 2023 (Cấp 1)
    1502001373, -- Mũ Giáp LINE FRIENDS BROWN (Cấp 1)
    1502001402, -- APEACH Helmet (LV.1)
    1502001403, -- Bellygom Helmet (LV.1)
    1502001427, -- Opanchu Helmet (Lv.1)
    1502001443, -- Mũ Giáp Sóng Âm Cuồng Loạn (Cấp 1)
    1502001450, -- Mũ Giáp Cún Tinh Nghịch (Cấp 1)
    1502001471, -- Turbo Granny (Beckoning cat) Helmet (Lv. 1)
    1502001480, -- Mũ Giáp PUBG MOBILE × aespa (Cấp 1)
    1502001490, -- Nakiri Ayame Helmet (Lv.1)
    1502001495, -- Mũ BLUE LOCK (Cấp 1)
    1502001001, -- Mũ pizza nóng (Cấp 1)
    1502001004, -- Mũ Cyberpunk (Tím) (Cấp 1)
    1502001005, -- Mũ hộp sọ (Cấp 1)
    1502001046, -- Mũ Samurai - danh dự (Cấp 1)
    1502001058, -- Mũ bảo hiểm Monarch (Cấp 1)
    1502001064, -- Mũ bảo hiểm Thiên Sứ (Cấp 1)
    1502001073, -- Mũ Vệ Binh Robot (Cấp 1)
    1502001078, -- Mũ Ninja Sát Thủ (Cấp 1)
    1502001086, -- Mũ Chuột Tinh Nghịch (Cấp 1)
    1502001099, -- Mũ Corgi (Cấp 1)
    1502001115, -- Mũ Bọ Rùa (Cấp 1)
    1502001133, -- Mũ Bí Ngô Kinh Dị (Cấp 1)
    1502001145, -- Mũ Chú Lính Chì (Cấp 1)
    1502001154, -- Mũ Giáp Đại Bàng Tỏa Sáng (Cấp 1)
    1502001175, -- Mũ Vịt Vàng B.Duck (Cấp 1)
    1502001230, -- Mũ Rồng Công Nghệ (Cấp 1)
    1502001248, -- Mũ Người Mở Đường (Cấp 1)
    1502001264, -- Mũ Ét Ô Ét (Cấp 1)
    1502001276, -- Mũ Vũ Công Bí Ẩn (Cấp 1)
    1502001294, -- Mũ Giáp Ma Pháp Sư (Cấp 1)
    1502001301, -- Mũ Giáp Archon Lừng Lẫy (Cấp 1)
    1502001357, -- Mũ Giáp Son Goku (Cấp 1)
    1502001381, -- Mũ Giáp Hỏa Linh Chí Tôn (Cấp 1)
    1502001416, -- Mũ Giáp PMGC 2024 (Cấp 1)
    1502001453, -- 2025 Esports Helmet (Lv. 1)

    -- ==============================================================================
    -- BA LÔ VIP (CHỈ LẤY CẤP 1 - GỌN GÀNG, DỄ ẨN NẤP)
    -- ==============================================================================
    1501001174, -- Ba lô Pharaoh (Cấp 1)
    1501002174,
    1501003174,
    1501001045,
    1501002045,
    1501003045,
    
    
    
    
    
    
    1501001220, -- Ba lô Huyết Nha (Cấp 1)
    1501001265, -- Ba lô Poseidon (Cấp 1)
    1501001548, -- Balo Thần Thoại Viễn Cổ (Cấp 1)
    1501001559, -- Balo Thanh Hoa Xà (Cấp 1)
    1501001567, -- Ba Lô Hỏa Linh Chí Tôn (Cấp 1)
    1501001577, -- Balo Đôi Cánh Vệ Thần (Cấp 1)
    1501001607, -- Balo Dơi Bóng Đêm (Cấp 1)
    1501001061, -- Ba lô Godzilla (Cấp 1)
    1501001062, -- Ba Lô Siêu Thú Ghidorah (Cấp 1)
    1501001082, -- Ba lô Genbu (Cấp 1)
    1501001112, -- Ba lô Pig Ngốc Nghếch (Cấp 1)
    1501001133, -- Ba lô Joker Khát Máu (Cấp 1)
    1501001243, -- Ba Lô Vịt Vàng B.Duck (Cấp 1)
    1501001273, -- Ba lô MECHAGODZILLA (Cấp 1)
    1501001304, -- Ba lô Ma Vương (Cấp 1)
    1501001331, -- Ba lô của Jinx (Cấp 1)
    1501001340, -- Ba Lô Hải Cẩu Tuyết (Cấp 1)
    1501001376, -- Ba lô Máy Hát Cổ Điển (Cấp 1)
    1501001400, -- Ba lô Baby Shark (Cấp 1)
    1501001463, -- Ba Lô BoBoiBoy (Cấp 1)
    1501001476, -- Ba Lô Biểu Tượng Bóng Đá Messi (Cấp 1)
    1501001480, -- Ba Lô Mì Indomie (Cấp 1)
    1501001487, -- Ba Lô Con Mắt Chết Chóc (Cấp 1)
    1501001521, -- Ba Lô Quy Lão Kame (Cấp 1)
    1501001539, -- Ba Lô PMGC 2023 (Cấp 1)
    1501001540, -- Ba Lô Gà Rán KFC (Cấp 1)
    1501001554, -- Ba Lô LINE FRIENDS SALLY (Cấp 1)
    1501001587, -- Ba Lô Đại Úy Loạn Thế (Cấp 1)
    1501001597, -- Bellygom Backpack (LV.1)
    1501001632, -- Opanchu Backpack (Lv.1)
    1501001643, -- Frieren&Mimic Backbag (Lv.1)
    1501001650, -- Ba Lô Titan Khổng Lồ Cấp 1
    1501001683, -- Ba Lô Balenciaga (Cấp 1)
    1501001715, -- SAKAMOTO TARO Backpack (Lv.1)
    1501001720, -- Ba Lô BLUE LOCK (Cấp 1)
    
        -- [ BALO, MŨ & DÙ LƯỢN ]
    1501001024, -- Balo Bá Tước
    1501002024,
    1501003024,
    1501001742,
    1501002742,
    1501003742,
    1501001058,
    1501002058,
    1501003058,
    1501001726,
    1501002726,
    1501003726,
    1501001287,
    1501002287,
    1501003287,
    1501001640,
    1501002640,
    1501003640,
    1501001688,
    1501002688,
    1501003688,
    1501003051,
    1501002051,
    1501001051,
    1502001014, -- Mũ Đinh
    1502002014,
    1502003014,
    1502001439, -- mũ vương miện
    1502002439,
    1502003439,
    1502002069,
    1502001069, -- mũ cương thi
    1502003069,
    1502001031,
    1502002031,
    1502003031,
    1502001363,
    1502002363,
    1502003363,
    1502001023, -- mũ băng

    -- id bổ xung
    1400092, 1400101, 1400122, --tư lệnh
    1404191, -- quần bộ hành
    1405128, 1405129, 140224445, 140224445, -- crew
    1407961, 1407962, 1407963, 19080660, 1407964, 1407965, 1407966, 1407967, 1407968, 1407969, 1407970, 1407971, 1502001508, 1502002508, 1502003508, 1411134, 1411133, 1411135, 1403771, 1403770, 1407994, 1407993, 1101006106, 1101006098, 4151145, 1903230, 1903231, 1903232, 1908117, 1953011, 1953021,1953012, 1908118, 1908119, 19116002, 19116003, 19116004, 1961070, 1961071, 1961072, 1961073, 1408045, 1408038, 1407990,1407922, -- Trang Phục Nữ Thần Ái Tình
    1407704, -- Trang Phục Cô Dâu Tinh Quái
    1400782, -- Trang phục băng tuyết
    1407614, -- Trang Phục Optimus Prime Transformers
    1407276, -- Trang Phục Vệ Thần Tình Ái
    1410356, -- Mặt Nạ Ma Vương Huyết Hồn
    40605012, -- Tóc Hai Chùm
    401035, -- Mũ cao bồi (Trắng)
    1916004, --Tesla Cybertruck (Splendid-Silver)
   1916005, --Tesla Cybertruck (Dystopia Blue)
   1916006, --Tesla Cybertruck (Black-Quartz)
}

local INS_BASE = 2000000000
local PKG_SLOT = 3
local MELEE_ID = 108
local HAT_SUB = 401
local MASK_SUB = 402
local OUTFIT_SUB = 403
local PANTS_SUB = 404
local SHOES_SUB = 405
local GLASS_SUB = 407
local GLIDER_SUB = 415      
local GLOVES_SUB = 452
local GLIDER_SUBS = { [413] = true, [414] = true, [415] = true }

F.CUST_SLOT = {
    NONE = 0,
    HeadEquipemtSlot = 1,
    HairEquipemtSlot = 2,
    HatEquipemtSlot = 3,
    FaceEquipemtSlot = 4,
    ClothesEquipemtSlot = 5,
    PantsEquipemtSlot = 6,
    ShoesEquipemtSlot = 7,
    BackpackEquipemtSlot = 8,
    HelmetEquipemtSlot = 9,
    ArmorEquipemtSlot = 10,
    ParachuteEquipemtSlot = 11,
    GlassEquipemtSlot = 12,
    NightVisionEquipemtSlot = 13,
    BeardEquipemtSlot = 14,
    GlideEquipemtSlot = 15,
    HandEffectEquipemtSlot = 16,
    BackPack_PendantSlot = 17,
}
_G.CustSlotType = F.CUST_SLOT

local CHASSIS_LIGHT_SUB = 7302
local CHASSIS_LIGHT_IDS = { [7302001] = true, [7302002] = true }
local DEFAULT_CHASSIS_LIGHT = 7302002
local PARACHUTE_SUB = 701   
local DEFAULT_PARACHUTE_RES = 703001  
local TAB_SUIT = 10
local TAB_CLOTHES = 3
local PAGE_AVATAR = 1
local PAGE_VEHICLE = 6
local PAGE_PARACHUTE = 5
local HALL_THEME_TYPE = 202
local SUBTYPE_DEFAULT_TAB = {
    [401] = 1, [402] = 2, [403] = 10, [404] = 4, [405] = 5, [407] = 14,
    [501] = 15, [504] = 15, [502] = 16, [505] = 16,
}
local HAT_SUBS = { [401] = true }
local HELMET_SUBS = { [502] = true, [505] = true }
local HEAD_SUBS = { [401] = true } -- [FIX VIP] Đã xóa 502 và 505 để tách biệt hoàn toàn Mũ Bảo Hiểm khỏi Tóc/Mũ Thời Trang
local BAG_SUBS = { [501] = true, [504] = true }
local FACE_SUBS = { [402] = true, [407] = true }
local BODY_SUBS = { [404] = true, [405] = true, [501] = true, [504] = true, [502] = true, [505] = true }
local GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {}, byWeapon = {} }
local _matchApplied = false

