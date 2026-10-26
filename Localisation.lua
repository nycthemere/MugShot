-- =========================================================
-- MugShot - Localisation  (Localisation.lua)
-- Multi-language dictionary for French (fr) and English (en).
-- Automatically selects language via GetCVar("language.2").
-- =========================================================

MugShot = MugShot or {}

local strings = {
    en = {
        ENABLED                 = "|c9b00afMugShot|r enabled.",
        DISABLED                = "|c9b00afMugShot|r disabled.",
        DISABLED_HELP           = "MugShot is disabled in settings; use /mugshot to enable",
        FRAME_LOCKED            = "|c9b00afMugShot|r: frame locked. Position saved.",
        FRAME_UNLOCKED          = "|c9b00afMugShot|r: frame unlocked (repositioning mode). Mouse cursor active. Drag the frame, then retype |c00ffcc/mugshotmove|r to lock.",
        DEBUG_SHOWN             = "|c9b00afMugShot|r DEBUG: frame shown — position offsetX=%s offsetY=%s",
        DEBUG_HIDDEN            = "|c9b00afMugShot|r DEBUG: debug mode disabled.",
        POSITION_RESET          = "|c9b00afMugShot|r: position reset to TOPLEFT (100, 200) and frame unlocked.",
        STATUS_HEADER           = "|c9b00af[MugShot Status]|r",
        STATUS_ENABLED_LOCKED   = "  Enabled: %s | Locked: %s",
        STATUS_FRAME_POS        = "  Frame: IsHidden=%s | Pos: (offX=%s, offY=%s)",
        STATUS_TARGET           = "  Target 'reticleover': %s (name: %s)",
        STATUS_TARGET_NONE      = "none",
        STATUS_NATIVE_HOOKED    = "  Native frame hooked: %s",
        DRAG_ME_TITLE           = "[MugShot] Drag me!",
        UNKNOWN                 = "Unknown",
        HODOR_ICONS_ENABLED     = "|c9b00afMugShot|r: HodorReflexes / LibCustomIcons custom portraits enabled.",
        HODOR_ICONS_DISABLED    = "|c9b00afMugShot|r: Custom portraits disabled (showing class icon).",
    },
    fr = {
        ENABLED                 = "|c9b00afMugShot|r activé.",
        DISABLED                = "|c9b00afMugShot|r désactivé.",
        DISABLED_HELP           = "MugShot est désactivé dans les paramètres ; tapez /mugshot pour l'activer",
        FRAME_LOCKED            = "|c9b00afMugShot|r : cadre verrouillé. Position enregistrée.",
        FRAME_UNLOCKED          = "|c9b00afMugShot|r : cadre déverrouillé (mode déplacement). Curseur de souris activé. Déplacez le cadre puis retapez |c00ffcc/mugshotmove|r pour verrouiller.",
        DEBUG_SHOWN             = "|c9b00afMugShot|r DEBUG: cadre affiché — position offsetX=%s offsetY=%s",
        DEBUG_HIDDEN            = "|c9b00afMugShot|r DEBUG: mode debug désactivé.",
        POSITION_RESET          = "|c9b00afMugShot|r : position réinitialisée à TOPLEFT (100, 200) et cadre déverrouillé.",
        STATUS_HEADER           = "|c9b00af[Statut MugShot]|r",
        STATUS_ENABLED_LOCKED   = "  Actif : %s | Verrouillé : %s",
        STATUS_FRAME_POS        = "  Cadre : IsHidden=%s | Pos : (offX=%s, offY=%s)",
        STATUS_TARGET           = "  Cible 'reticleover' : %s (nom : %s)",
        STATUS_TARGET_NONE      = "aucun",
        STATUS_NATIVE_HOOKED    = "  Cadre natif lié : %s",
        DRAG_ME_TITLE           = "[MugShot] Déplacez-moi !",
        UNKNOWN                 = "Inconnu",
        HODOR_ICONS_ENABLED     = "|c9b00afMugShot|r : Icônes personnalisées HodorReflexes / LibCustomIcons activées.",
        HODOR_ICONS_DISABLED    = "|c9b00afMugShot|r : Icônes personnalisées désactivées (affichage de la classe).",
    },
}

-- Detect client language
local lang = "en"
if GetCVar then
    local cvarLang = GetCVar("language.2")
    if cvarLang and strings[cvarLang] then
        lang = cvarLang
    end
end

MugShot.currentLang = lang
MugShot.strings = strings
MugShot.L = strings[lang] or strings.en

-- Helper to retrieve text, format with args, and fall back to en / key
function MugShot.GetText(key, ...)
    local dict = MugShot.L
    local str = dict and dict[key]
    if not str then
        str = strings.en and strings.en[key]
    end
    if not str then
        return key or ""
    end
    if select("#", ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

if MugShot.logger then
    MugShot.logger:Info("=== Localisation loaded (language: %s) ===", lang)
end
