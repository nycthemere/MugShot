-- =========================================================
-- MugShot - PortraitsTest  (tests/PortraitsTest.lua)
-- =========================================================

local root = (arg and arg[0] and arg[0]:match("(.+)[/\\][^/\\]+$")) or "."
local addonRoot = root .. "/.."

local EsoMock = dofile(root .. "/EsoMock.lua")
EsoMock.Init()

dofile(addonRoot .. "/Constants.lua")
dofile(addonRoot .. "/Data/Portraits.lua")

local P = MugShot.Portraits
local pass, fail = 0, 0
local errors = {}

local function check(cond, msg)
    if cond then pass = pass + 1
    else fail = fail + 1; table.insert(errors, "FAIL: " .. (msg or "")) end
end
local function eq(a, b, msg) check(a == b, (msg or "") .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end

-- 1. NPC with specific portrait
GetUnitName = function(tag) return "Iron Atronach" end
IsUnitPlayer = function(tag) return false end
local npcInfo = P.GetPortraitInfo("reticleover")
eq(npcInfo.portraitTexture, "/esoui/art/icons/achievement_u29_dun2_flavorc.dds", "NPC specific portrait matched")

-- 2. Player with fallback to class gamepad icon
IsUnitPlayer = function(tag) return true end
GetUnitClassId = function(tag) return 1 end
GetClassInfo = function(id) return "normal.dds", "pressed.dds", "/esoui/art/icons/class/gamepad/gp_class_dragonknight.dds" end
GetUnitDisplayName = function(tag) return "@SomePlayer" end
LibCustomIcons = nil
HodorReflexes = nil

local playerInfo = P.GetPortraitInfo("player")
eq(playerInfo.portraitTexture, "/esoui/art/icons/class/gamepad/gp_class_dragonknight.dds", "Player falls back to class gamepad icon")
check(playerInfo.portraitCoords == nil, "Class icon has nil coords")

-- 3. Player with LibCustomIcons static icon
LibCustomIcons = {
    GetStatic = function(user)
        if user == "@SomePlayer" then
            return "/custom/avatar.dds", 0.1, 0.2, 0.3, 0.4
        end
    end,
}
local customInfo = P.GetPortraitInfo("player")
eq(customInfo.portraitTexture, "/custom/avatar.dds", "LibCustomIcons static avatar matched")
eq(customInfo.portraitCoords[1], 0.1, "Custom coords preserved")

-- 4. Player with LibCustomIcons animated icon
LibCustomIcons = {
    GetStatic = function() return nil end,
    GetAnimated = function(user)
        if user == "@SomePlayer" then
            return { "/custom/anim.dds", 4, 4, 15 }
        end
    end,
}
local animInfo = P.GetPortraitInfo("player")
eq(animInfo.portraitTexture, "/custom/anim.dds", "LibCustomIcons animated first frame matched")
eq(animInfo.portraitCoords[2], 0.25, "Animated texture coords calculated (1/4)")

-- 5. Option disabled: falls back to class icon even if custom icon exists
MugShot.settings = {
    Get = function() return { useHodorIcons = false } end
}
local disabledInfo = P.GetPortraitInfo("player")
eq(disabledInfo.portraitTexture, "/esoui/art/icons/class/gamepad/gp_class_dragonknight.dds", "useHodorIcons=false forces class icon fallback")
check(disabledInfo.portraitCoords == nil, "Forced class icon coords reset")

-- 6. Player with HodorReflexes custom icon
MugShot.settings = { Get = function() return { useHodorIcons = true } end }
LibCustomIcons = nil
HodorReflexes = {
    util = {
        GetUserIcon = function(user)
            if user == "@SomePlayer" then
                return "/hodor/icon.dds", { 0, 0.5, 0, 0.5 }
            end
        end
    }
}
local hodorInfo = P.GetPortraitInfo("player")
eq(hodorInfo.portraitTexture, "/hodor/icon.dds", "HodorReflexes custom icon resolved")

-- ── 7. Companions (English Client) - Verified against live ESO assets ──
IsUnitPlayer = function() return false end
local companions = {
    { name = "Bastian Hallix",    want = "/esoui/art/icons/comp_bastian.dds" },
    { name = "Mirri Elendis",     want = "/esoui/art/icons/comp_mirri.dds" },
    { name = "Ember",             want = "/esoui/art/icons/comp_ember.dds" },
    { name = "Isobel Veloise",    want = "/esoui/art/icons/comp_isobel.dds" },
    { name = "Azandar al-Cybiades", want = "/esoui/art/icons/companion_azander.dds" },
    { name = "Sharp-as-Night",    want = "/esoui/art/icons/companion_sharp.dds" },
    { name = "Tanlorin",          want = "/esoui/art/icons/u44_companion_tanlorin.dds" },
    { name = "Zerith-var",        want = "/esoui/art/icons/u44_companion_zerith.dds" },
}

for _, comp in ipairs(companions) do
    GetUnitName = function() return comp.name end
    local info = P.GetPortraitInfo("reticleover")
    eq(info.portraitTexture, comp.want, "Companion portrait: " .. comp.name)
end

-- ── 8. Gender Tag Stripping (ESO Markup) ──────────────────
GetUnitName = function() return "Bastian Hallix^M" end
local cleanCompM = P.GetPortraitInfo("reticleover")
eq(cleanCompM.portraitTexture, "/esoui/art/icons/comp_bastian.dds", "Gender tag ^M stripped for Bastian")

-- ── 9. Sorcerer Ability Pets (English) ────────────────────
local sorcPets = {
    { name = "Unstable Familiar",         want = "/esoui/art/icons/ability_sorcerer_unstable_fimiliar_summoned.dds" },
    { name = "Volatile Familiar",         want = "/esoui/art/icons/ability_sorcerer_speedy_familiar_summoned.dds" },
    { name = "Clannfear",                 want = "/esoui/art/icons/ability_sorcerer_unstable_clannfear_summoned.dds" },
    { name = "Winged Twilight",           want = "/esoui/art/icons/ability_sorcerer_lightning_matriarch_summoned.dds" },
    { name = "Twilight Tormentor",        want = "/esoui/art/icons/ability_sorcerer_lightning_matriarch_summoned.dds" },
    { name = "Twilight Matriarch",        want = "/esoui/art/icons/ability_sorcerer_lightning_matriarch_summoned.dds" },
    { name = "Storm Atronach",            want = "/esoui/art/icons/ability_sorcerer_storm_atronach.dds" },
    { name = "Greater Storm Atronach",    want = "/esoui/art/icons/ability_sorcerer_greater_storm_atronach.dds" },
}

for _, pet in ipairs(sorcPets) do
    GetUnitName = function() return pet.name end
    local info = P.GetPortraitInfo("reticleover")
    eq(info.portraitTexture, pet.want, "Sorcerer pet: " .. pet.name)
end

-- ── 10. Warden Ability Pets (English) ─────────────────────
local wardenPets = {
    { name = "Feral Guardian",   want = "/esoui/art/icons/ability_warden_018.dds" },
    { name = "Eternal Guardian", want = "/esoui/art/icons/ability_warden_018_a.dds" },
    { name = "Wild Guardian",    want = "/esoui/art/icons/ability_warden_018_b.dds" },
    { name = "Guardian",         want = "/esoui/art/icons/ability_warden_018.dds" },
    { name = "Betty Netch",      want = "/esoui/art/icons/ability_warden_014.dds" },
    { name = "Bull Netch",       want = "/esoui/art/icons/ability_warden_014_a.dds" },
    { name = "Blue Betty",       want = "/esoui/art/icons/ability_warden_014_b.dds" },
}

for _, pet in ipairs(wardenPets) do
    GetUnitName = function() return pet.name end
    local info = P.GetPortraitInfo("reticleover")
    eq(info.portraitTexture, pet.want, "Warden pet: " .. pet.name)
end

-- ── 11. Necromancer Summons (English) ─────────────────────
local necroPets = {
    { name = "Skeletal Mage",        want = "/esoui/art/icons/ability_necromancer_003.dds" },
    { name = "Skeletal Arcanist",    want = "/esoui/art/icons/ability_necromancer_003_a.dds" },
    { name = "Skeletal Archer",      want = "/esoui/art/icons/ability_necromancer_003_b.dds" },
    { name = "Spirit Mender",        want = "/esoui/art/icons/ability_necromancer_005.dds" },
    { name = "Spirit Guardian",      want = "/esoui/art/icons/ability_necromancer_005_a.dds" },
    { name = "Intensive Mender",     want = "/esoui/art/icons/ability_necromancer_005_b.dds" },
    { name = "Blastbones",           want = "/esoui/art/icons/ability_necromancer_002.dds" },
    { name = "Stalking Blastbones",  want = "/esoui/art/icons/ability_necromancer_002_a.dds" },
    { name = "Blighted Blastbones",  want = "/esoui/art/icons/ability_necromancer_002_b.dds" },
    { name = "Flesh Abomination",    want = "/esoui/art/icons/ability_necromancer_006.dds" },
    { name = "Frozen Colossus",      want = "/esoui/art/icons/ability_necromancer_006.dds" },
    { name = "Glacial Colossus",     want = "/esoui/art/icons/ability_necromancer_006_a.dds" },
    { name = "Pestilent Colossus",   want = "/esoui/art/icons/ability_necromancer_006_b.dds" },
}

for _, pet in ipairs(necroPets) do
    GetUnitName = function() return pet.name end
    local info = P.GetPortraitInfo("reticleover")
    eq(info.portraitTexture, pet.want, "Necromancer summon: " .. pet.name)
end

-- ── 12. Nightblade Summons (English) ──────────────────────
local nbPets = {
    { name = "Summon Shade", want = "/esoui/art/icons/ability_nightblade_006.dds" },
    { name = "Dark Shade",   want = "/esoui/art/icons/ability_nightblade_006_a.dds" },
    { name = "Shadow Image", want = "/esoui/art/icons/ability_nightblade_006_b.dds" },
}

for _, pet in ipairs(nbPets) do
    GetUnitName = function() return pet.name end
    local info = P.GetPortraitInfo("reticleover")
    eq(info.portraitTexture, pet.want, "Nightblade summon: " .. pet.name)
end

-- ── 13. Arcanist Summons (English) ────────────────────────
local arcanistPets = {
    { name = "The Unblinking Eye",   want = "/esoui/art/icons/ability_arcanist_016.dds" },
    { name = "The Languid Eye",      want = "/esoui/art/icons/ability_arcanist_016_a.dds" },
    { name = "Tide King's Gaze",     want = "/esoui/art/icons/ability_arcanist_016_b.dds" },
}

for _, pet in ipairs(arcanistPets) do
    GetUnitName = function() return pet.name end
    local info = P.GetPortraitInfo("reticleover")
    eq(info.portraitTexture, pet.want, "Arcanist pet: " .. pet.name)
end

-- ── 14. Dynamic Active Companion Resolution via API ───────
GetUnitName = function() return "Custom Companion" end
local savedActiveDef = GetActiveCompanionDefId
local savedCompCol = GetCompanionCollectibleId
local savedColInfo0 = GetCollectibleInfo

GetActiveCompanionDefId = function() return 1 end
GetCompanionCollectibleId = function(defId)
    if defId == 1 then return 9999 end
    return 0
end
GetCollectibleInfo = function(colId)
    if colId == 9999 then
        return "Custom Companion", "Desc", "/esoui/art/icons/custom_comp_portrait.dds", true, false
    end
    return "", "", "", false, true
end

-- Active companion tag
local dynamicCompTag = P.GetPortraitInfo("companion")
eq(dynamicCompTag.portraitTexture, "/esoui/art/icons/custom_comp_portrait.dds", "Dynamic active companion via companion unitTag resolved")

-- Reticleover equal to companion
DoesUnitExist = function(tag) return true end
AreUnitsEqual = function(a, b) return (a == "reticleover" and b == "companion") or (a == b) end
local dynamicCompReticle = P.GetPortraitInfo("reticleover")
eq(dynamicCompReticle.portraitTexture, "/esoui/art/icons/custom_comp_portrait.dds", "Dynamic active companion via AreUnitsEqual resolved")
AreUnitsEqual = nil

GetActiveCompanionDefId = savedActiveDef
GetCompanionCollectibleId = savedCompCol
GetCollectibleInfo = savedColInfo0

-- ── 15. Dynamic Companion Collectibles Scanner ────────────
local savedTotal = GetTotalCollectiblesByCategoryType
local savedIdFromType = GetCollectibleIdFromType
local savedColInfo = GetCollectibleInfo

GetTotalCollectiblesByCategoryType = function(cat)
    if cat == 27 then return 1 end
    return 0
end
GetCollectibleIdFromType = function(cat, idx)
    if cat == 27 and idx == 1 then return 8888 end
    return 0
end
GetCollectibleInfo = function(colId)
    if colId == 8888 then
        return "Futur Nouveau Compagnon^M", "Desc", "/esoui/art/icons/achievement_update11_dungeons_001.dds", true, false
    end
    return "", "", "", false, true
end

P.PopulateDynamicRegistry()
GetUnitName = function() return "Futur Nouveau Compagnon" end
local futureComp1 = P.GetPortraitInfo("reticleover")
eq(futureComp1.portraitTexture, "/esoui/art/icons/achievement_update11_dungeons_001.dds", "Dynamic discovery added clean name")
GetUnitName = function() return "Futur Nouveau Compagnon^M" end
local futureComp2 = P.GetPortraitInfo("reticleover")
eq(futureComp2.portraitTexture, "/esoui/art/icons/achievement_update11_dungeons_001.dds", "Dynamic discovery resolved raw name with ^M")

GetTotalCollectiblesByCategoryType = savedTotal
GetCollectibleIdFromType = savedIdFromType
GetCollectibleInfo = savedColInfo

-- ── 16. Other Players' Companions (Robust Resolution) ─────
IsUnitPlayer = function() return false end
DoesUnitExist = function() return true end

-- Other player's companion with lowercase name
GetUnitName = function() return "sharp-as-night" end
local otherComp1 = P.GetPortraitInfo("reticleover")
eq(otherComp1.portraitTexture, "/esoui/art/icons/companion_sharp.dds", "Other player's Sharp-as-Night (lowercase) resolved")

-- Other player's companion with short name
GetUnitName = function() return "Sharp" end
local otherComp3 = P.GetPortraitInfo("reticleover")
eq(otherComp3.portraitTexture, "/esoui/art/icons/companion_sharp.dds", "Other player's Sharp (short) resolved")

-- Other player's Azandar
GetUnitName = function() return "Azandar" end
local otherCompAzandar = P.GetPortraitInfo("reticleover")
eq(otherCompAzandar.portraitTexture, "/esoui/art/icons/companion_azander.dds", "Other player's Azandar resolved")

-- Other player's Tanlorin
GetUnitName = function() return "Tanlorin" end
local otherCompTanlorin = P.GetPortraitInfo("reticleover")
eq(otherCompTanlorin.portraitTexture, "/esoui/art/icons/u44_companion_tanlorin.dds", "Other player's Tanlorin resolved")

-- Other player's Zerith-var
GetUnitName = function() return "Zerith-var" end
local otherCompZerith = P.GetPortraitInfo("reticleover")
eq(otherCompZerith.portraitTexture, "/esoui/art/icons/u44_companion_zerith.dds", "Other player's Zerith-var resolved")

-- Sorcerer base Familiar (English)
GetUnitName = function() return "Familiar" end
local sorcFamiliar = P.GetPortraitInfo("reticleover")
eq(sorcFamiliar.portraitTexture, "/esoui/art/icons/ability_sorcerer_unstable_fimiliar_summoned.dds", "Sorcerer base Familiar resolved")

-- Other player's Bastian with gender tag
GetUnitName = function() return "Bastian Hallix^M" end
local otherComp4 = P.GetPortraitInfo("reticleover")
eq(otherComp4.portraitTexture, "/esoui/art/icons/comp_bastian.dds", "Other player's Bastian Hallix^M resolved")

-- Other player's companion resolved via caption
GetUnitName = function() return "Bastian" end
GetUnitCaption = function() return "Compagnon de @AnotherPlayer" end
local otherComp5 = P.GetPortraitInfo("reticleover")
eq(otherComp5.portraitTexture, "/esoui/art/icons/comp_bastian.dds", "Other player's companion with Compagnon caption resolved")
GetUnitCaption = nil

-- Dummy / missing collectible icon does NOT overwrite verified static portrait
local savedColInfo2 = GetCollectibleInfo
GetCollectibleInfo = function(colId)
    return "Bastian Hallix", "Desc", "/esoui/art/icons/icon_missing.dds", false, true
end
P.PopulateDynamicRegistry()
GetUnitName = function() return "Bastian Hallix" end
local bastianInfo = P.GetPortraitInfo("reticleover")
eq(bastianInfo.portraitTexture, "/esoui/art/icons/comp_bastian.dds", "Dummy icon from GetCollectibleInfo was rejected; verified icon preserved")
GetCollectibleInfo = savedColInfo2

-- ── 17. Assistants & Allies Resolution (Ezabi, Baron Jangleplume, etc.) ─────
-- Ezabi
GetUnitName = function() return "Ezabi" end
local asst1 = P.GetPortraitInfo("reticleover")
eq(asst1.portraitTexture, "/esoui/art/icons/assistant_ezabibanker.dds", "Ezabi assistant resolved")

-- Ezabi with title & lowercase
GetUnitName = function() return "ezabi the banker" end
local asst2 = P.GetPortraitInfo("reticleover")
eq(asst2.portraitTexture, "/esoui/art/icons/assistant_ezabibanker.dds", "Ezabi the Banker (lowercase) resolved")

-- Baron Jangleplume
GetUnitName = function() return "Baron Jangleplume" end
local asst3 = P.GetPortraitInfo("reticleover")
eq(asst3.portraitTexture, "/esoui/art/crowncrates/rewards/cc_assistant_baronjangleplumethebanker.dds", "Baron Jangleplume assistant resolved")

-- Fezez
GetUnitName = function() return "Fezez" end
local asst4 = P.GetPortraitInfo("reticleover")
eq(asst4.portraitTexture, "/esoui/art/icons/assistant_fezezmerchant.dds", "Fezez assistant resolved")

-- Giladil
GetUnitName = function() return "Giladil the Ragpicker" end
local asst5 = P.GetPortraitInfo("reticleover")
eq(asst5.portraitTexture, "/esoui/art/icons/assistant_giladiltheragpicker.dds", "Giladil assistant resolved")

-- ── 18. Multilingual Verification: French Client Environment ────────
EsoMock.SetLanguage("fr")
P.PopulateDynamicRegistry()

local frenchCompanions = {
    { name = "Braise",            want = "/esoui/art/icons/comp_ember.dds" },
    { name = "Vif-comme-la-Nuit", want = "/esoui/art/icons/companion_sharp.dds" },
    { name = "Bastian Hallix",    want = "/esoui/art/icons/comp_bastian.dds" },
    { name = "Isobel Veloise",    want = "/esoui/art/icons/comp_isobel.dds" },
    { name = "Azandar al-Cybiades", want = "/esoui/art/icons/companion_azander.dds" },
}
for _, comp in ipairs(frenchCompanions) do
    GetUnitName = function() return comp.name end
    local info = P.GetPortraitInfo("reticleover")
    eq(info.portraitTexture, comp.want, "French Companion portrait: " .. comp.name)
end

GetUnitName = function() return "Braise^F" end
local cleanCompF = P.GetPortraitInfo("reticleover")
eq(cleanCompF.portraitTexture, "/esoui/art/icons/comp_ember.dds", "Gender tag ^F stripped for Braise")

local frenchPets = {
    { name = "Familier instable",   want = "/esoui/art/icons/ability_sorcerer_unstable_fimiliar_summoned.dds" },
    { name = "Familier explosif",   want = "/esoui/art/icons/ability_sorcerer_speedy_familiar_summoned.dds" },
    { name = "Faucheclan",          want = "/esoui/art/icons/ability_sorcerer_unstable_clannfear_summoned.dds" },
    { name = "Atronach de foudre",  want = "/esoui/art/icons/ability_sorcerer_storm_atronach.dds" },
    { name = "Gardien féroce",      want = "/esoui/art/icons/ability_warden_018.dds" },
    { name = "Gardien éternel",     want = "/esoui/art/icons/ability_warden_018_a.dds" },
    { name = "Gardien sauvage",     want = "/esoui/art/icons/ability_warden_018_b.dds" },
    { name = "Netch mâle",          want = "/esoui/art/icons/ability_warden_014_a.dds" },
    { name = "Squelette explosif",  want = "/esoui/art/icons/ability_necromancer_002.dds" },
    { name = "Arcaniste squelette", want = "/esoui/art/icons/ability_necromancer_003_a.dds" },
    { name = "Gardien spirituel",   want = "/esoui/art/icons/ability_necromancer_005_a.dds" },
    { name = "Colosse de chair",    want = "/esoui/art/icons/ability_necromancer_006.dds" },
    { name = "Ombre noire",         want = "/esoui/art/icons/ability_nightblade_006_a.dds" },
    { name = "Image d'ombre",       want = "/esoui/art/icons/ability_nightblade_006_b.dds" },
    { name = "L'Œil sans paupière", want = "/esoui/art/icons/ability_arcanist_016.dds" },
}
for _, pet in ipairs(frenchPets) do
    GetUnitName = function() return pet.name end
    local info = P.GetPortraitInfo("reticleover")
    eq(info.portraitTexture, pet.want, "French pet: " .. pet.name)
end

-- French un-morphed pet: Familier
GetUnitName = function() return "Familier" end
local sorcFamilier = P.GetPortraitInfo("reticleover")
eq(sorcFamilier.portraitTexture, "/esoui/art/icons/ability_sorcerer_unstable_fimiliar_summoned.dds", "Sorcerer base Familier (FR) resolved")

-- Other player companion in French (lowercase / short)
GetUnitName = function() return "vif-comme-la-nuit" end
local otherCompFr1 = P.GetPortraitInfo("reticleover")
eq(otherCompFr1.portraitTexture, "/esoui/art/icons/companion_sharp.dds", "Other player's Vif-comme-la-nuit resolved")

GetUnitName = function() return "Vif" end
local otherCompFr2 = P.GetPortraitInfo("reticleover")
eq(otherCompFr2.portraitTexture, "/esoui/art/icons/companion_sharp.dds", "Other player's Vif (short) resolved")

-- Reset mock back to English
EsoMock.SetLanguage("en")
P.PopulateDynamicRegistry()

print(string.format("[PortraitsTest] %d passed, %d failed", pass, fail))
for _, e in ipairs(errors) do print("  " .. e) end
if fail > 0 then os.exit(1) end
