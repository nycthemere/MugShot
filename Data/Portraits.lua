-- =========================================================
-- MugShot - Portraits  (Data/Portraits.lua)
-- Portrait mapping and metadata for target frame portraits.
-- Inspired by TargetFrame, adapted for MugShot.
-- =========================================================

MugShot.Portraits = {}

MugShot.Portraits.SpecificPortraits = {
    --- UNIVERSAL & SUMMONS ---
    ['Iron Atronach']                    = '/esoui/art/icons/achievement_u29_dun2_flavorc.dds',
    ['Frost Atronach']                   = '/esoui/art/icons/achievement_u25_dun1_flavor_boss_1a.dds',
    ['Storm Atronach']                   = '/esoui/art/icons/ability_sorcerer_storm_atronach.dds',
    ['Haj Mota']                         = '/esoui/art/icons/achievement_murkmire_loyalty.dds',
    ['Volatile Familiar']                = '/esoui/art/icons/ability_sorcerer_speedy_familiar_summoned.dds',
    ['Twilight Tormentor']               = '/esoui/art/icons/ability_sorcerer_lightning_matriarch_summoned.dds',

    --- DUMMIES & TARGETS ---
    ['Soul-Sworn Thrall']                = '/esoui/art/icons/item_soulswornthrall.dds',
    ['Target Iron Atronach, Trial']      = '/esoui/art/icons/achievement_u29_dun2_flavorc.dds',
    ['Target Skeleton, Robust Humanoid'] = '/esoui/art/icons/event_witchfest_sacking_skelet.dds',
    ['Target Skeleton, Humanoid']        = '/esoui/art/icons/event_witchfest_sacking_skelet.dds',
    ['Target Ogrim']                     = '/esoui/art/icons/target_greenarmoredogrim.dds',

    --- WORLD BOSSES ---
    ['The Precursor']                    = '/esoui/art/icons/targetdummy_theprecursor.dds',

    --- ROCKGROVE ---
    ['Havocrel Annihilator']             = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Havocrel Butcher']                 = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Havocrel Barbarian']               = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Havocrel Torchcaster']             = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Sul-xan Bloodseeker']              = '/esoui/art/icons/achievement_u30_vtrialkillmonstersa.dds',
    ['Sul-xan Reaver']                   = '/esoui/art/icons/achievement_u30_vtrialkillmonstersa.dds',
    ['Sul-xan Soulweaver']               = '/esoui/art/icons/achievement_u30_vtrialkillmonstersa.dds',
    ['Oaxiltso']                         = '/esoui/art/icons/achievement_u30_vtrial_b1_hardmode.dds',
    ['Death Hopper']                     = '/esoui/art/icons/achievement_u30_groupboss4.dds',
    ['Flesh Abomination']                = '/esoui/art/icons/ability_necromancer_006.dds',
    ['Fire Behemoth']                    = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',
    ['Flame-Herald Bahsei']              = '/esoui/art/icons/achievement_u30_vtrial_b2_hardmode.dds',
    ['Daedroth']                         = '/esoui/art/icons/achievement_092.dds',
    ['Flame Watcher']                    = '/esoui/art/icons/achievement_u29_dun2_killmonstersb.dds',
    ['Xalvakka']                         = '/esoui/art/icons/achievement_u30_vtrial_all_hardmode.dds',
    ['Havocrel Goliath']                 = '/esoui/art/icons/achievement_u32_havocrel_uniques.dds',

    --- SANCTUM OPHIDIA ---
    ['Possessed Mantikora']              = '/esoui/art/icons/achievement_u32_dl_groupboss2.dds',
    ['Stonebreaker']                     = '/esoui/art/icons/gear_undauntedtroll_head_a.dds',
    ['Ozara']                            = '/esoui/art/icons/housing_uni_inc_mountedtrophylamia001.dds',
    ['The Serpent']                      = '/esoui/art/icons/ability_mundusstones_004.dds',

    --- HEL RA CITADEL ---
    ['Ra Kotu']                          = '/esoui/art/icons/u34_vtrial_all_hardmode.dds',
    ['Yokeda Kai']                       = '/esoui/art/icons/gear_yokudan_heavy_head_a.dds',
    ["Yokeda Rok'dun"]                   = '/esoui/art/icons/gear_yokudan_heavy_head_a.dds',
    ['The Warrior']                      = '/esoui/art/icons/achievement_update11_dungeons_001.dds',

    --- SUNSPIRE ---
    ['Lokkestiiz']                       = '/esoui/art/icons/achievement_els_sunspire_flavor_2.dds',
    ['Yolnahkriin']                      = '/esoui/art/icons/achievement_els_sunspire_flavor_1.dds',
    ['Nahviintaas']                      = '/esoui/art/icons/achievement_els_sunspire_flavor_3.dds',
    ["Alkosh's Roar"]                    = '/esoui/art/icons/mounticon_monstroussenche_raht.dds',
    ["Jone's Gale-Claw"]                 = '/esoui/art/icons/mount_queenclawsencheraht.dds',
    ["Jode's Fire-Fang"]                 = '/esoui/art/icons/mount_sencherahtc.dds',
    ['Fury of Alkosh']                   = '/esoui/art/icons/ability_werewolf_002_b.dds',
    ['Ruin of Alkosh']                   = '/esoui/art/icons/ability_1handed_003.dds',
    ["Alkosh's Fate"]                    = '/esoui/art/icons/death_recap_cold_aoe.dds',
    ["Alkosh's Will"]                    = '/esoui/art/icons/ability_2handed_004_b.dds',

    --- DREADSAIL REEF ---
    ['Lylanar']                          = '/esoui/art/icons/death_recap_fire_aoe.dds',
    ['Turlassil']                        = '/esoui/art/icons/death_recap_cold_aoe.dds',
    ['Reef Guardian']                    = '/esoui/art/icons/u34_vtrial_b2_hardmode.dds',
    ['Tideborn Taleria']                 = '/esoui/art/icons/u34_vtrial_all_hardmode.dds',
    ['Bow Breaker']                      = '/esoui/art/icons/achievement_update11_dungeons_014.dds',
    ['Sail Ripper']                      = '/esoui/art/icons/u34_vtrial_flavor_4.dds',

    --- CLOUDREST ---
    ["Z'Maja"]                           = '/esoui/art/icons/achievement_su_karnwasten_groupevent.dds',
    ['Shade of Siroria']                 = '/esoui/art/icons/ability_dragonknight_010.dds',
    ['Shade of Relequen']                = '/esoui/art/icons/ability_sorcerer_thundering_presence.dds',
    ['Shade of Galenwe']                 = '/esoui/art/icons/death_recap_cold_aoe.dds',
    ['Yaghra Monstrosity']               = '/esoui/art/icons/pet_191_yaghradarkblue-yellow.dds',
    ['Yaghra Strider']                   = '/esoui/art/icons/achievement_summerset_boss_002.dds',
    ['Yaghra Spewer']                    = '/esoui/art/icons/achievement_summerset_boss_002.dds',
    ['Nocturnal Creeper']                = '/esoui/art/icons/death_recap_magic_ranged.dds',

    --- SANITY'S EDGE ---
    ['Exarchanic Yaseyla']               = '/esoui/art/icons/ability_debuff_disorient.dds',
    ['Contramagis Wamasu']               = '/esoui/art/icons/achievement_update12_dungeons_002.dds',
    ['Chimera']                          = '/esoui/art/icons/achievement_u36_zone_groupboss1.dds',
    ['Ansuul the Tormentor']             = '/esoui/art/icons/achievement_u38_vtrial_meta.dds',
}

MugShot.Portraits.RaceIdToName = {
    [1]  = 'breton',
    [2]  = 'redguard',
    [3]  = 'orc',
    [4]  = 'dunmer',
    [5]  = 'nord',
    [6]  = 'argonian',
    [7]  = 'altmer',
    [8]  = 'bosmer',
    [9]  = 'khajiit',
    [10] = 'imperial',
}

MugShot.Portraits.AllianceNames = {
    [1] = 'aldmeri',
    [2] = 'ebonheart',
    [3] = 'daggerfall',
}

MugShot.Portraits.AllianceColors = {
    [1] = { 1.0, 1.0, 0.5 },
    [2] = { 1.0, 0.5, 0.5 },
    [3] = { 0.5, 0.5, 1.0 },
}

--- Resolves portrait, race badge, and alliance badge textures for a unit
function MugShot.Portraits.GetPortraitInfo(unitTag)
    local isPlayer = IsUnitPlayer and IsUnitPlayer(unitTag)
    local portraitTexture = nil
    local raceIcon = nil
    local allianceIcon = nil
    local allianceColor = nil

    if isPlayer then
        -- 1. Check HodorReflexes custom avatar if available
        local displayName = GetUnitDisplayName and GetUnitDisplayName(unitTag)
        if displayName and HodorReflexes and HodorReflexes.users and HodorReflexes.users[displayName] and HodorReflexes.users[displayName][3] then
            portraitTexture = HodorReflexes.users[displayName][3]
        end

        -- 2. Fall back to class icon
        if not portraitTexture and GetUnitClassId then
            local classId = GetUnitClassId(unitTag)
            if classId and GetClassInfo then
                local _, _, gamepadIcon = GetClassInfo(classId)
                portraitTexture = gamepadIcon
            end
            if not portraitTexture and GetUnitClass then
                local className = string.lower(GetUnitClass(unitTag) or "")
                if className ~= "" then
                    portraitTexture = '/esoui/art/icons/class/gamepad/gp_class_' .. className .. '.dds'
                end
            end
        end

        -- 3. Race badge (top-right corner)
        if GetUnitRaceId then
            local raceId = GetUnitRaceId(unitTag)
            local raceName = MugShot.Portraits.RaceIdToName[raceId]
            if raceName then
                raceIcon = '/esoui/art/charactercreate/gamepad/charactercreate_' .. raceName .. 'icon_down.dds'
            end
        end

        -- 4. Alliance badge (bottom-right corner)
        if GetUnitAlliance then
            local allianceId = GetUnitAlliance(unitTag)
            local allianceName = MugShot.Portraits.AllianceNames[allianceId]
            if allianceName then
                allianceIcon = '/esoui/art/stats/alliancebadge_' .. allianceName .. '.dds'
                allianceColor = MugShot.Portraits.AllianceColors[allianceId]
            end
        end
    else
        -- NPC / Boss / Monster portrait
        local unitName = GetUnitName and GetUnitName(unitTag)
        if unitName and MugShot.Portraits.SpecificPortraits[unitName] then
            portraitTexture = MugShot.Portraits.SpecificPortraits[unitName]
        end
    end

    return {
        portraitTexture = portraitTexture,
        raceIcon        = raceIcon,
        allianceIcon    = allianceIcon,
        allianceColor   = allianceColor,
    }
end

MugShot.logger:Info("=== Portraits loaded ===")
