-- =========================================================
-- MugShot - Entities  (tests/preview/Entities.lua)
-- Manages 3D world target entities, sample buff catalog,
-- and event-driven mutations via pure ESO events.
-- Zero direct calls to MugShot private controller methods!
-- =========================================================

local Entities = {}

local BUFF_CATALOG = {
    { name = "Major Vulnerability", abilityId = 106754, iconFilename = "/esoui/art/icons/ability_debuff_vulnerable.dds", duration = 8,   stackCount = 0, effectType = 2, castByPlayer = true },
    { name = "Off Balance",         abilityId = 39077,  iconFilename = "/esoui/art/icons/ability_debuff_offbalance.dds", duration = 15,  stackCount = 0, effectType = 2, castByPlayer = true },
    { name = "Stumble",             abilityId = 0,      iconFilename = "/esoui/art/icons/ability_debuff_stumble.dds",    duration = 5,   stackCount = 3, effectType = 2, castByPlayer = true },
    { name = "Major Breach",        abilityId = 61743,  iconFilename = "/esoui/art/icons/ability_debuff_minor_breach.dds", duration = 30, stackCount = 0, effectType = 2, castByPlayer = true },
    { name = "Minor Breach",        abilityId = 61742,  iconFilename = "/esoui/art/icons/ability_debuff_minor_breach.dds", duration = 20, stackCount = 0, effectType = 2, castByPlayer = true },
    { name = "Crusher",             abilityId = 17906,  iconFilename = "/esoui/art/icons/ability_debuff_crusher.dds",     duration = 10, stackCount = 0, effectType = 2, castByPlayer = true },
    { name = "Minor Maim",          abilityId = 61723,  iconFilename = "/esoui/art/icons/ability_debuff_minor_maim.dds", duration = 12,  stackCount = 0, effectType = 2, castByPlayer = true },
    { name = "Major Maim",          abilityId = 61725,  iconFilename = "/esoui/art/icons/ability_debuff_major_maim.dds", duration = 15,  stackCount = 0, effectType = 2, castByPlayer = true },
    { name = "Weakening",           abilityId = 17945,  iconFilename = "/esoui/art/icons/ability_debuff_weakening.dds",  duration = 8,   stackCount = 0, effectType = 2, castByPlayer = true },
    { name = "Berserk",             abilityId = 0,      iconFilename = "/esoui/art/icons/ability_warrior_001.dds",       duration = 10,  stackCount = 5, effectType = 1, castByPlayer = true },
    { name = "Major Sorcery",       abilityId = 0,      iconFilename = "/esoui/art/icons/ability_buff_major_sorcery.dds", duration = 24, stackCount = 0, effectType = 1, castByPlayer = true },
    { name = "Major Resolve",       abilityId = 0,      iconFilename = "/esoui/art/icons/ability_buff_major_resolve.dds", duration = 180, stackCount = 0, effectType = 1, castByPlayer = true },
    { name = "Combat Prayer",       abilityId = 0,      iconFilename = "/esoui/art/icons/ability_restorationstaff_001b.dds", duration = 10, stackCount = 0, effectType = 1, castByPlayer = true },
    { name = "Minor Force",         abilityId = 0,      iconFilename = "/esoui/art/icons/ability_mage_002.dds",          duration = 15,  stackCount = 0, effectType = 1, castByPlayer = true },
}

local nextCatalogIdx = 1

function Entities.GetCatalog()
    return BUFF_CATALOG
end

function Entities.CreateDefaultTargets()
    return {
        {
            id = "oaxiltso",
            name = "Oaxiltso",
            title = "Boss d'épreuve (Trial Boss)",
            reaction = 1, -- UNIT_REACTION_HOSTILE (Red)
            maxHealth = 3000000,
            currentHealth = 2100000,
            shield = 250000,
            shieldActive = true,
            isDead = false,
            raceId = 0,
            allianceId = 0,
            x = 0, y = 0, z = 12.0,
            radius = 1.6,
            height = 3.6,
            color = { 0.95, 0.25, 0.25 },
            buffs = {
                -- Multi-cast : 1 cast du joueur (8s) + 1 cast d'un allié (14s) -> en Groupe: fusionné "x2" bordure cyan !
                { name = "Major Vulnerability", abilityId = 106754, iconFilename = "/esoui/art/icons/ability_debuff_vulnerable.dds", duration = 8, stackCount = 0, effectType = 2, castByPlayer = true },
                { name = "Major Vulnerability", abilityId = 106754, iconFilename = "/esoui/art/icons/ability_debuff_vulnerable.dds", duration = 14, stackCount = 0, effectType = 2, castByPlayer = false },
                -- Débuff d'un allié (visible en groupe > 1, masqué en solo) :
                { name = "Off Balance",         abilityId = 39077,  iconFilename = "/esoui/art/icons/ability_debuff_offbalance.dds", duration = 15, stackCount = 0, effectType = 2, castByPlayer = false },
                -- Débuff joueur avec 3 stacks :
                { name = "Stumble",             abilityId = 0,      iconFilename = "/esoui/art/icons/ability_debuff_stumble.dds",    duration = 5, stackCount = 3, effectType = 2, castByPlayer = true },
            }
        },
        {
            id = "elysia",
            name = "Elysia Shadowmend",
            displayName = "@ArkayHealer",
            title = "Joueuse Alliée (Friendly Player)",
            isPlayer = true,
            reaction = 2, -- UNIT_REACTION_FRIENDLY (Green)
            classId = 2, -- Sorcerer
            raceId = 6, -- High Elf
            allianceId = 1, -- Aldmeri Dominion
            maxHealth = 24500,
            currentHealth = 24500,
            shield = 0,
            shieldActive = false,
            isDead = false,
            x = 2.4, y = 0, z = 6.2,
            radius = 0.9,
            height = 2.0,
            color = { 0.20, 0.95, 0.40 },
            buffs = {
                { name = "Combat Prayer", iconFilename = "/esoui/art/icons/ability_restorationstaff_001b.dds", duration = 10, stackCount = 0, effectType = 1, castByPlayer = true },
                { name = "Major Resolve", iconFilename = "/esoui/art/icons/ability_buff_major_resolve.dds",       duration = 180, stackCount = 0, effectType = 1, castByPlayer = true },
                { name = "Minor Berserk", iconFilename = "/esoui/art/icons/ability_buff_minor_berserk.dds",       duration = 20, stackCount = 0, effectType = 1, castByPlayer = true },
            }
        },
        {
            id = "bastian",
            name = "Bastian Hallix",
            title = "Compagnon (Companion)",
            reaction = 5, -- UNIT_REACTION_NPC_ALLY (Green)
            maxHealth = 32400,
            currentHealth = 32400,
            shield = 0,
            shieldActive = false,
            isDead = false,
            raceId = 1, -- Breton
            allianceId = 1, -- Aldmeri Dominion
            x = -6.5, y = 0, z = 8.5,
            radius = 1.0,
            height = 2.0,
            color = { 0.25, 0.90, 0.35 },
            buffs = {
                { name = "Major Sorcery", iconFilename = "/esoui/art/icons/ability_buff_major_sorcery.dds", duration = 24, stackCount = 0, effectType = 1, castByPlayer = true },
                { name = "Major Resolve", iconFilename = "/esoui/art/icons/ability_buff_major_resolve.dds", duration = 180, stackCount = 0, effectType = 1, castByPlayer = true },
            }
        },
        {
            id = "familiar",
            name = "Summon Unstable Familiar",
            title = "Familier Sorcier (Sorcerer Pet)",
            reaction = 4, -- UNIT_REACTION_PLAYER_ALLY (Cyan/Blue)
            maxHealth = 21400,
            currentHealth = 18200,
            shield = 0,
            shieldActive = false,
            isDead = false,
            raceId = 0,
            allianceId = 0,
            x = -3.2, y = 0, z = 5.2,
            radius = 0.8,
            height = 1.3,
            color = { 0.30, 0.70, 1.0 },
            buffs = {
                { name = "Unstable Familiar", iconFilename = "/esoui/art/icons/ability_sorcerer_unstable_fimiliar_summoned.dds", duration = 12, stackCount = 0, effectType = 1, castByPlayer = true },
            }
        },
        {
            id = "skeleton",
            name = "Target Skeleton, Robust",
            title = "Mannequin d'entraînement (Target Dummy)",
            reaction = 3, -- UNIT_REACTION_NEUTRAL (Yellow)
            maxHealth = 6000000,
            currentHealth = 3000000,
            shield = 0,
            shieldActive = false,
            isDead = false,
            raceId = 0,
            allianceId = 0,
            x = 5.8, y = 0, z = 8.5,
            radius = 1.0,
            height = 2.2,
            color = { 0.95, 0.85, 0.22 },
            buffs = {
                { name = "Minor Breach", iconFilename = "/esoui/art/icons/ability_debuff_minor_breach.dds", duration = 10, stackCount = 0, effectType = 2, castByPlayer = true },
            }
        },
    }
end

-- ── Sync Entity to ESO Mock ───────────────────────────────

function Entities.SyncToMock(entity, EsoMock)
    if not EsoMock then return end
    if entity then
        local now = EsoMock.currentTime or 1000.0
        local unitBuffs = {}
        for _, b in ipairs(entity.buffs or {}) do
            table.insert(unitBuffs, {
                name         = b.name,
                abilityId    = b.abilityId or 0,
                iconFilename = b.iconFilename,
                duration     = b.duration or 10,
                timeStarted  = b.timeStarted or now,
                timeEnding   = (b.duration and b.duration > 0) and (now + (b.remaining or b.duration)) or 0,
                stackCount   = b.stackCount or 0,
                effectType   = b.effectType or 2,
                castByPlayer = (b.castByPlayer ~= false),
            })
        end

        local shieldVal = (entity.shieldActive and entity.shield) or 0
        EsoMock.SetUnit("reticleover", {
            exists        = true,
            name          = entity.name,
            displayName   = entity.displayName or "",
            isPlayer      = entity.isPlayer or false,
            classId       = entity.classId,
            reaction      = entity.reaction,
            currentHealth = entity.currentHealth,
            maxHealth     = entity.maxHealth,
            shield        = shieldVal,
            raceId        = entity.raceId,
            allianceId    = entity.allianceId,
            isDead        = entity.isDead or false,
            buffs         = unitBuffs,
        })
        EsoMock.TriggerEvent(EVENT_RETICLE_TARGET_CHANGED)
    else
        EsoMock.SetUnit("reticleover", { exists = false })
        EsoMock.TriggerEvent(EVENT_RETICLE_TARGET_CHANGED)
    end
end

-- ── Event-Driven Mutations (Pure ESO events) ──────────────

function Entities.UpdateHealth(entity, delta, EsoMock)
    if not entity or not EsoMock then return end
    local cur = entity.currentHealth
    local max = entity.maxHealth
    local newHp = math.min(max, math.max(0, cur + math.floor(max * delta)))
    entity.currentHealth = newHp

    local u = EsoMock.units["reticleover"]
    if u then
        u.currentHealth = newHp
        EsoMock.TriggerEvent(EVENT_POWER_UPDATE, "reticleover", 1, COMBAT_MECHANIC_FLAGS_HEALTH, newHp, max, max)
    end
end

function Entities.HealFull(entity, EsoMock)
    if not entity or not EsoMock then return end
    entity.currentHealth = entity.maxHealth
    entity.isDead = false

    local u = EsoMock.units["reticleover"]
    if u then
        u.currentHealth = entity.maxHealth
        u.isDead = false
        EsoMock.TriggerEvent(EVENT_UNIT_DEATH_STATE_CHANGED, "reticleover", false)
        EsoMock.TriggerEvent(EVENT_POWER_UPDATE, "reticleover", 1, COMBAT_MECHANIC_FLAGS_HEALTH, entity.maxHealth, entity.maxHealth, entity.maxHealth)
    end
end

function Entities.ToggleShield(entity, EsoMock)
    if not entity or not EsoMock then return false end
    entity.shieldActive = not entity.shieldActive
    local shieldAmount = entity.shieldActive and math.floor(entity.maxHealth * 0.20) or 0
    entity.shield = shieldAmount

    local u = EsoMock.units["reticleover"]
    if u then
        u.shield = shieldAmount
        if entity.shieldActive then
            EsoMock.TriggerEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, "reticleover", ATTRIBUTE_VISUAL_POWER_SHIELDING, 1, 1, 1, shieldAmount, u.currentHealth, u.maxHealth)
        else
            EsoMock.TriggerEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, "reticleover", ATTRIBUTE_VISUAL_POWER_SHIELDING, 1, 1, 1, 0, u.currentHealth, u.maxHealth)
        end
    end
    return entity.shieldActive
end

function Entities.ToggleDeath(entity, EsoMock)
    if not entity or not EsoMock then return false end
    entity.isDead = not entity.isDead
    local u = EsoMock.units["reticleover"]
    if u then
        u.isDead = entity.isDead
        EsoMock.TriggerEvent(EVENT_UNIT_DEATH_STATE_CHANGED, "reticleover", entity.isDead)
    end
    return entity.isDead
end

function Entities.AddBuff(entity, EsoMock)
    if not entity or not EsoMock then return nil, 0 end
    entity.buffs = entity.buffs or {}
    local sample = BUFF_CATALOG[nextCatalogIdx]
    nextCatalogIdx = (nextCatalogIdx % #BUFF_CATALOG) + 1

    local now = EsoMock.currentTime or 1000.0
    table.insert(entity.buffs, {
        name         = sample.name,
        abilityId    = sample.abilityId or 0,
        iconFilename = sample.iconFilename,
        duration     = sample.duration,
        timeStarted  = now,
        timeEnding   = (sample.duration > 0) and (now + sample.duration) or 0,
        stackCount   = sample.stackCount or 0,
        effectType   = sample.effectType or 2,
        castByPlayer = true,
    })

    Entities.SyncToMock(entity, EsoMock)
    EsoMock.TriggerEvent(EVENT_EFFECT_CHANGED, 1, 1, sample.name, "reticleover")
    return sample.name, #entity.buffs
end

function Entities.RemoveBuff(entity, EsoMock)
    if not entity or not entity.buffs or #entity.buffs == 0 or not EsoMock then return nil, 0 end
    local removed = table.remove(entity.buffs)
    Entities.SyncToMock(entity, EsoMock)
    EsoMock.TriggerEvent(EVENT_EFFECT_CHANGED, 3, 1, removed.name, "reticleover")
    return removed.name, #entity.buffs
end

function Entities.AddBuffToPlayer(EsoMock)
    if not EsoMock or not EsoMock.units["player"] then return nil, 0 end
    local p = EsoMock.units["player"]
    p.buffs = p.buffs or {}
    local sample = BUFF_CATALOG[nextCatalogIdx]
    nextCatalogIdx = (nextCatalogIdx % #BUFF_CATALOG) + 1

    local now = EsoMock.currentTime or 1000.0
    table.insert(p.buffs, {
        name         = sample.name,
        abilityId    = sample.abilityId or 0,
        iconFilename = sample.iconFilename,
        duration     = sample.duration,
        timeStarted  = now,
        timeEnding   = (sample.duration > 0) and (now + sample.duration) or 0,
        stackCount   = sample.stackCount or 0,
        effectType   = sample.effectType or 1,
        castByPlayer = true,
    })

    EsoMock.TriggerEvent(EVENT_EFFECT_CHANGED, 1, 1, sample.name, "player")
    if MugShot._controller then
        MugShot._controller:RefreshEffects(nil, "player")
    end
    return sample.name, #p.buffs
end

function Entities.RemoveBuffFromPlayer(EsoMock)
    if not EsoMock or not EsoMock.units["player"] then return nil, 0 end
    local p = EsoMock.units["player"]
    if not p.buffs or #p.buffs == 0 then return nil, 0 end
    local removed = table.remove(p.buffs)

    EsoMock.TriggerEvent(EVENT_EFFECT_CHANGED, 3, 1, removed.name, "player")
    if MugShot._controller then
        MugShot._controller:RefreshEffects(nil, "player")
    end
    return removed.name, #p.buffs
end

function Entities.ToggleStressTest(entity, EsoMock)
    if not entity or not EsoMock then return 0 end
    entity.buffs = entity.buffs or {}
    local count = 0
    if #entity.buffs >= 14 then
        entity.buffs = {}
    else
        local now = EsoMock.currentTime or 1000.0
        entity.buffs = {}
        for i = 1, 14 do
            local sample = BUFF_CATALOG[((i - 1) % #BUFF_CATALOG) + 1]
            table.insert(entity.buffs, {
                name         = sample.name,
                abilityId    = sample.abilityId or 0,
                iconFilename = sample.iconFilename,
                duration     = sample.duration,
                timeStarted  = now,
                timeEnding   = (sample.duration > 0) and (now + sample.duration) or 0,
                stackCount   = (i % 3 == 0) and (i % 5 + 1) or 0,
                effectType   = sample.effectType or 2,
                castByPlayer = true,
            })
        end
        count = 14
    end

    Entities.SyncToMock(entity, EsoMock)
    EsoMock.TriggerEvent(EVENT_EFFECT_CHANGED, 1, 1, "StressTest", "reticleover")
    return count
end

function Entities.ToggleGroup(isInGroup, EsoMock)
    if not EsoMock then return end
    EsoMock.isUnitGrouped = isInGroup
    EsoMock.groupSize = isInGroup and 4 or 1
    EsoMock.hasActiveCompanion = false

    -- Native ESO Event triggering for group change
    if isInGroup then
        EsoMock.TriggerEvent(EVENT_GROUP_MEMBER_JOINED, "Allié", "Allié")
    else
        EsoMock.TriggerEvent(EVENT_GROUP_MEMBER_LEFT, "Allié", "Allié")
    end
end

return Entities
