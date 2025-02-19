LinkLuaModifier("modifier_boss_carapace_crystals_passive", "abilities/boss/carapace/boss_carapace_crystals.lua", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------

boss_carapace_crystals = class(AbilityBaseClass)

function boss_carapace_crystals:Precache(context)
  PrecacheResource("particle", "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_sphere.vpcf", context)
  PrecacheResource("particle", "particles/units/heroes/hero_pugna/pugna_ward_sphereinner.vpcf", context)
  PrecacheResource("particle", "particles/econ/items/crystal_maiden/crystal_maiden_cowl_of_ice/maiden_crystal_nova_cowlofice.vpcf", context)
  PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_crystalmaiden.vsndevts", context)
end

function boss_carapace_crystals:GetIntrinsicModifierName()
  if self:GetLevel() > 0 then
    return "modifier_boss_carapace_crystals_passive"
  end
end

--------------------------------------------------------------------------------

modifier_boss_carapace_crystals_passive = class(ModifierBaseClass)

------------------------------------------------------------------------------------

function modifier_boss_carapace_crystals_passive:IsHidden()
	return true
end

------------------------------------------------------------------------------------

function modifier_boss_carapace_crystals_passive:IsPurgable()
	return false
end

------------------------------------------------------------------------------------

function modifier_boss_carapace_crystals_passive:RemoveOnDeath()
	return true
end

function modifier_boss_carapace_crystals_passive:DeclareFunctions()
  return {
    MODIFIER_EVENT_ON_TAKEDAMAGE,
    MODIFIER_EVENT_ON_DEATH,
    MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
    MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS
  }
end

if IsServer() then
  function modifier_boss_carapace_crystals_passive:OnDeath(event)
    if event.unit == self:GetParent() then
      if self.crystals then
        for _, crystal in pairs(self.crystals) do
          if crystal then
            if crystal.particle then
              ParticleManager:DestroyParticle(crystal.particle, true)
              ParticleManager:ReleaseParticleIndex(crystal.particle)
            end
          end
        end
      end
    end
  end

	function modifier_boss_carapace_crystals_passive:OnCreated()
		local ability = self:GetAbility()

		local additional = ability:GetSpecialValueFor("additional")
		local initial = ability:GetSpecialValueFor("initial")
		local total = additional + initial
		self.angle =  math.ceil(360 / total)
		self.count = 0

		self.crystals = {}
		for i = 1, total do
			self.crystals[i] = {}
		end

		local initialKeys = self:GetRandomElements(self.crystals, initial, nil, true)
		for _, id in pairs(initialKeys) do
			self:CreateCrystal(id)
		end

		self:StartIntervalThink(0.03)
	end

	function modifier_boss_carapace_crystals_passive:CreateCrystal(key)
		local caster = self:GetCaster()

		local thresholdMin = self:GetAbility():GetSpecialValueFor("threshold_min")
		local thresholdMax = self:GetAbility():GetSpecialValueFor("threshold_max")

		local angle = self.angle * key

		self.crystals[key].threshold = RandomInt(thresholdMin, thresholdMax)
		self.crystals[key].taken = 0
		self.crystals[key].particle = ParticleManager:CreateParticle("particles/units/heroes/hero_pugna/pugna_ward_sphereinner.vpcf", PATTACH_CUSTOMORIGIN, caster)
		ParticleManager:SetParticleControl(self.crystals[key].particle, 4, self:GetCrystalPosition(angle))

		self.count = self.count + 1

		-- print(key, position, caster:GetAbsOrigin())
	end

	function modifier_boss_carapace_crystals_passive:OnIntervalThink()
		for id, crystal in pairs(self.crystals) do
			if crystal.particle then
				local angle = self.angle * id
				ParticleManager:SetParticleControl(crystal.particle, 0, self:GetCrystalPosition(angle))
				ParticleManager:SetParticleControl(crystal.particle, 4, self:GetCrystalPosition(angle))
			end
		end
	end

	function modifier_boss_carapace_crystals_passive:GetCrystalPosition(angle)
		local caster = self:GetCaster()
		local ability = self:GetAbility()

		local position = RotatePosition(caster:GetAbsOrigin(), QAngle(0,angle + caster:GetAngles().y,0), caster:GetAbsOrigin() + Vector(ability:GetSpecialValueFor("crystal_distance"),0,0))

		return position + Vector(0,0,64)
	end
end

function modifier_boss_carapace_crystals_passive:GetModifierPhysicalArmorBonus()
  return self:GetAbility():GetSpecialValueFor("bonus_armor")
end

function modifier_boss_carapace_crystals_passive:GetModifierMagicalResistanceBonus()
  return self:GetAbility():GetSpecialValueFor("bonus_magic_resistance")
end

------------------------------------------------------------------------------------

if IsServer() then
	local function AngleOfPoint( pt )
		local x, y = pt.x, pt.y
		local radian = math.atan2(y,x)
		local angle = radian*180/math.pi
		if angle < 0 then angle = 360 + angle end
		return angle
	end

	local function AngleBetweenPoints( a, b )
		local x, y = b.x - a.x, b.y - a.y
		return AngleOfPoint( { x=x, y=y } )
	end

	local function IsAngleBetween(target, angle1, angle2)
		local rAngle = ((angle2 - angle1) % 360 + 360) % 360
		if rAngle >= 180 then
			local temp = angle1
			angle1 = angle2
			angle2 = temp
		end

		if angle1 <= angle2 then
			return target >= angle1 and target <= angle2
		else
			return target >= angle1 or target <= angle2
		end
	end

	local function Repeat(t, length)
		return t - math.floor(t / length) * length
	end

	--[[
  local function FindUnitsInCone(position, coneDirection, coneLength, coneWidth, teamNumber, teamFilter, typeFilter, flagFilter, order)
		local units = FindUnitsInRadius(teamNumber, position, nil, coneLength, teamFilter, typeFilter, flagFilter, order, false)

		coneDirection = coneDirection:Normalized()

		local output = {}
		local cone = math.cos(coneWidth/2)

		for _, unit in pairs(units) do
			local direction = (unit:GetAbsOrigin() - position):Normalized()
			if direction:Dot(coneDirection) >= cone then
				table.insert(output, unit)
			end
		end

		return output
	end
  ]]

  function modifier_boss_carapace_crystals_passive:OnTakeDamage(event)
    local caster = self:GetParent()
    local ability = self:GetAbility()
    local attacker = event.attacker
    local damage_taken = event.damage
    local damaged_unit = event.unit
    local inflictor = event.inflictor

    -- Check if attacker exists
    if not attacker or attacker:IsNull() then
      return
    end

    -- Check if damaged entity exists
    if not damaged_unit or damaged_unit:IsNull() then
      return
    end

    -- Check if damaged unit is the parent
    if damaged_unit ~= caster then
      return
    end

    -- Do nothing on self damage (ignore bleeding damage (degen) for example)
    if attacker == caster then
      return
    end

    -- Don't continue if damaged unit (caster) or attacker is dead
    if not attacker:IsAlive() or not caster:IsAlive() then
      return
    end

    -- Don't continue if damage has HP removal flag
    if bit.band(event.damage_flags, DOTA_DAMAGE_FLAG_HPLOSS) == DOTA_DAMAGE_FLAG_HPLOSS then
      return
    end

    -- Don't continue if damage has Reflection flag
    if bit.band(event.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) == DOTA_DAMAGE_FLAG_REFLECTION then
      return
    end

    -- Don't continue If ability doesn't exist
    if not ability or ability:IsNull() then
      return
    end

    -- If inflictor is this ability don't continue (prevents looping)
    if inflictor then
      if inflictor == ability or inflictor:GetAbilityName() == ability:GetAbilityName() then
        return
      end
    end

    local initial = ability:GetSpecialValueFor("initial")
    local additional = ability:GetSpecialValueFor("additional")

    if self.count - initial < additional - math.ceil((caster:GetHealth() / caster:GetMaxHealth()) * additional) then
      local function CheckCrystal(k)
        return self.crystals[k] and not self.crystals[k].full and self.crystals[k].particle == nil
      end

      local newCrystals = self:GetRandomElements(self.crystals, 1, CheckCrystal, true)
      for _, id in pairs(newCrystals) do
        self:CreateCrystal(id)
      end
    end

    -- Don't let multiple crystals explode at the same time in the same frame
    if self.skip then
      self.skip = false
      return
    end

    local caster_loc = caster:GetAbsOrigin()
    local result_angle = AngleBetweenPoints(caster_loc, attacker:GetAbsOrigin())

    for id, crystal in pairs(self.crystals) do
      local angle = Repeat((id * self.angle) + caster:GetAngles().y, 360)
      local min = angle - (self.angle / 2)
      local max = angle + (self.angle / 2)

      local crystalPosition = self:GetCrystalPosition(self.angle * id)

      if not crystal.full and crystal.particle and IsAngleBetween(result_angle, min, max) then
        self.crystals[id].taken = self.crystals[id].taken + damage_taken

        self.skip = true

        -- Bonus damage to the carapace boss
        local damageTable = {
          victim = caster,
          attacker = attacker,
          damage = damage_taken * ability:GetSpecialValueFor("damage_amplification") / 100,
          damage_type = DAMAGE_TYPE_PURE,
          damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
          ability = ability
        }
        ApplyDamage(damageTable)

        local impact = ParticleManager:CreateParticle("particles/units/heroes/hero_rattletrap/rattletrap_rocket_flare_explosion_flash_c.vpcf", PATTACH_CUSTOMORIGIN, caster)
        ParticleManager:SetParticleControl(impact, 3, crystalPosition)
        ParticleManager:ReleaseParticleIndex(impact)

        caster:EmitSound("Hero_Crystal.CrystalNova.Yulsaria")

        if self.crystals[id].taken >= self.crystals[id].threshold then
          self.crystals[id].full = true
          ParticleManager:DestroyParticle(self.crystals[id].particle, true)
          ParticleManager:ReleaseParticleIndex(self.crystals[id].particle)

          self.crystals[id].particle = ParticleManager:CreateParticle("particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_sphere.vpcf", PATTACH_CUSTOMORIGIN, caster)

          local distance = ability:GetSpecialValueFor("crystal_distance")
          local range = ability:GetSpecialValueFor("range")
          local width = range * (self.angle / distance)
          local direction = ((crystalPosition - caster_loc) * Vector(1, 1, 0)):Normalized()
          --DebugDrawLine(caster_loc, caster_loc + (direction * range), 255, 0, 0, false, 0.03)

          -- Warning particle
          local indicator = ParticleManager:CreateParticle("particles/warning/warning_particle_cone.vpcf", PATTACH_WORLDORIGIN, caster)
          ParticleManager:SetParticleControl(indicator, 1, caster_loc)
          ParticleManager:SetParticleControl(indicator, 2, caster_loc + direction * range)
          ParticleManager:SetParticleControl(indicator, 3, Vector(width, width, width))
          ParticleManager:SetParticleControl(indicator, 4, Vector(255, 0, 0))
          ParticleManager:ReleaseParticleIndex(indicator)

          local mod = self
          Timers:CreateTimer(1.0, function ()
            if not mod or caster:IsNull() or not caster:IsAlive() then return nil end

            ParticleManager:DestroyParticle(mod.crystals[id].particle, true)
            ParticleManager:ReleaseParticleIndex(mod.crystals[id].particle)
            mod.crystals[id].particle = nil

            local explosion = ParticleManager:CreateParticle("particles/econ/items/crystal_maiden/crystal_maiden_cowl_of_ice/maiden_crystal_nova_cowlofice.vpcf", PATTACH_CUSTOMORIGIN, caster)
            ParticleManager:SetParticleControl(explosion, 0, crystalPosition)
            ParticleManager:ReleaseParticleIndex(explosion)

            caster:EmitSound("Hero_Crystal.CrystalNova")

            local units = FindUnitsInLine(
              caster:GetTeamNumber(),
              caster_loc,
              caster_loc + direction * range,
              nil,
              width,
              DOTA_UNIT_TARGET_TEAM_ENEMY,
              bit.bor(DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_HERO),
              DOTA_UNIT_TARGET_FLAG_NONE
            )

            -- Damage of the crystal when it explodes
            damageTable = {
              attacker = caster,
              damage = ability:GetSpecialValueFor("damage"),
              damage_type = ability:GetAbilityDamageType(),
              ability = ability
            }

            for _, unit in pairs(units) do
              if unit and not unit:IsNull() and not unit:IsMagicImmune() and not unit:IsDebuffImmune() then
                local particle = ParticleManager:CreateParticle("particles/econ/items/crystal_maiden/crystal_maiden_cowl_of_ice/maiden_crystal_nova_cowlofice.vpcf", PATTACH_CUSTOMORIGIN, unit)
                ParticleManager:SetParticleControl(particle, 0, unit:GetAbsOrigin())
                ParticleManager:ReleaseParticleIndex(particle)

                damageTable.victim = unit
                ApplyDamage(damageTable)
              end
            end
          end)
        end

        break
      end
    end
	end
end

------------------------------------------------------------------------------------

function modifier_boss_carapace_crystals_passive:GetRandomElements(list, count, checker, return_key)
	local newTable = {}

	for k, v in pairs(list) do
		local skip = false
		if checker then
			if return_key then
				skip = not checker(k)
			else
				skip = not checker(v)
			end
		end
		if not skip then
			newTable[k] = v
		end
	end

	local function TableCount( t )
		local n = 0
		for _ in pairs( t ) do
			n = n + 1
		end
		return n
	end

	local tableLength = TableCount(newTable)
	local seeds = {}

	local function Check(number)
		for k, v in pairs(seeds) do
			if v == number then
				return false
			end
		end
		return true
	end

	for i = 1, count do
		local newSeed
		repeat
			newSeed = math.random(1, tableLength)
		until
			Check(newSeed)
		table.insert(seeds, newSeed)
	end

	local i = 1
	local returnTable = {}
	local counter = 0

	for k, v in pairs(newTable) do
		if not Check(i) then
			if return_key then
				table.insert(returnTable, k)
			else
				table.insert(returnTable, v)
			end
			counter = counter + 1
			if counter == count then
				break
			end
		end
		i = i + 1
	end

	return returnTable
end
