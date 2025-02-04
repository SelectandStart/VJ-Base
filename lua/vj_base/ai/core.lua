/*--------------------------------------------------
	*** Copyright (c) 2012-2025 by DrVrej, All rights reserved. ***
	No parts of this code or any of its contents may be reproduced, copied, modified or adapted,
	without the prior written consent of the author, unless otherwise indicated for stand-alone materials.
--------------------------------------------------*/
---------------------------------------------------------------------------------------------------------------------------------------------
/*
	This file contains functions and variables shared between all the NPC bases.
	
	-- Change movement speed:
	self:SetLocalVelocity(self:GetMoveVelocity() * 1.5)
*/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Localized static values
local defPos = Vector(0, 0, 0)
local defAng = Angle(0, 0, 0)
local CurTime = CurTime
local IsValid = IsValid
local GetConVar = GetConVar
local isnumber = isnumber
local isvector = isvector
local isstring = isstring
local tonumber = tonumber
local string_sub = string.sub
local string_find = string.find
local table_concat = table.concat
local table_remove = table.remove
local bAND = bit.band
local math_rad = math.rad
local math_deg = math.deg
local math_cos = math.cos
local math_sin = math.sin
local math_atan2 = math.atan2
local math_clamp = math.Clamp
local math_angDif = math.AngleDifference
local varCPly = "CLASS_PLAYER_ALLY"
local StopSound = VJ.STOPSOUND
local PICK = VJ.PICK
local VJ_STATE_NONE = VJ_STATE_NONE
local VJ_STATE_FREEZE = VJ_STATE_FREEZE
local VJ_STATE_ONLY_ANIMATION_CONSTANT = VJ_STATE_ONLY_ANIMATION_CONSTANT
local VJ_BEHAVIOR_PASSIVE = VJ_BEHAVIOR_PASSIVE
local VJ_BEHAVIOR_PASSIVE_NATURE = VJ_BEHAVIOR_PASSIVE_NATURE
local VJ_MOVETYPE_GROUND = VJ_MOVETYPE_GROUND
local VJ_MOVETYPE_AERIAL = VJ_MOVETYPE_AERIAL
local VJ_MOVETYPE_AQUATIC = VJ_MOVETYPE_AQUATIC
local VJ_MOVETYPE_STATIONARY = VJ_MOVETYPE_STATIONARY
local VJ_MOVETYPE_PHYSICS = VJ_MOVETYPE_PHYSICS
local NPC_ALERT_STATE_READY = VJ.NPC_ALERT_STATE_READY
local NPC_ALERT_STATE_ENEMY = VJ.NPC_ALERT_STATE_ENEMY
local ANIM_TYPE_NONE = VJ.ANIM_TYPE_NONE
local ANIM_TYPE_ACTIVITY = VJ.ANIM_TYPE_ACTIVITY
local ANIM_TYPE_SEQUENCE = VJ.ANIM_TYPE_SEQUENCE
local ANIM_TYPE_GESTURE = VJ.ANIM_TYPE_GESTURE

local vj_npc_gib_collision = GetConVar("vj_npc_gib_collision")
local vj_npc_gib_fade = GetConVar("vj_npc_gib_fade")
local vj_npc_gib_fadetime = GetConVar("vj_npc_gib_fadetime")

---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Creates a extra corpse entity, use this function to create extra corpse entities when the NPC is killed
		- class = The object class to use, common types: "prop_ragdoll", "prop_physics"
		- models = Model(s) to use, can be a table which it will pick randomly from it OR a string | "None" = Doesn't set a model
		- extraOptions = Table that holds extra options to modify parts of the code
			- Pos = Sets the spawn position
			- Ang = Sets the spawn angle
			- Vel = Sets the velocity | "UseDamageForce" = To use the damage's force only | DEFAULT = Uses damage force
			- HasVel = If set to false, it won't set any velocity, allowing you to code your own in customFunc | DEFAULT = true
			- ShouldFade = Should it fade away after certain time | DEFAULT = false
			- ShouldFadeTime = How much time until the entity fades away | DEFAULT = 0
			- RemoveOnCorpseDelete = Should the entity get removed if the corpse is removed? | DEFAULT = true
		- customFunc(ent) = Use this to edit the entity which is given as parameter "ent"
-----------------------------------------------------------]]
local colorGrey = Color(90, 90, 90)
--
function ENT:CreateExtraDeathCorpse(class, models, extraOptions, customFunc)
	-- Should only be ran after self.Corpse has been created!
	if !IsValid(self.Corpse) then return end
	local dmginfo = self.Corpse.DamageInfo
	if dmginfo == nil then return end
	extraOptions = extraOptions or {}
	local ent = ents.Create(class or "prop_ragdoll")
	if models != "None" then ent:SetModel(PICK(models)) end
	ent:SetPos(extraOptions.Pos or self:GetPos())
	ent:SetAngles(extraOptions.Ang or self:GetAngles())
	ent:Spawn()
	ent:Activate()
	ent:SetColor(self.Corpse:GetColor())
	ent:SetMaterial(self.Corpse:GetMaterial())
	ent:SetCollisionGroup(self.DeathCorpseCollisionType)
	if self.Corpse:IsOnFire() then
		ent:Ignite(math.Rand(8, 10), 0)
		ent:SetColor(colorGrey)
	end
	if extraOptions.HasVel != false then
		local dmgForce = (self.SavedDmgInfo.force / 40) + self:GetMoveVelocity() + self:GetVelocity()
		if self.DeathAnimationCodeRan then
			dmgForce = self:GetMoveVelocity() == defPos and self:GetGroundSpeedVelocity() or self:GetMoveVelocity()
		end
		ent:GetPhysicsObject():AddVelocity(extraOptions.Vel or dmgForce)
	end
	if extraOptions.ShouldFade == true then
		local fadeTime = extraOptions.ShouldFadeTime or 0
		if ent:GetClass() == "prop_ragdoll" then
			ent:Fire("FadeAndRemove", "", fadeTime)
		else
			ent:Fire("kill", "", fadeTime)
		end
	end
	if extraOptions.RemoveOnCorpseDelete != false then //self.Corpse:DeleteOnRemove(ent)
		self.Corpse.ChildEnts[#self.Corpse.ChildEnts + 1] = ent
	end
	if (customFunc) then customFunc(ent) end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Creates a gib entity, use this function to create gib!
		- class = The object class to use, recommended to use "obj_vj_gib", and for ragdoll type of gib use "prop_ragdoll"
		- models = Model(s) to use, can be a table which it will pick randomly from it OR a string
			- Defined strings: "UseAlien_Small", "UseAlien_Big", "UseHuman_Small", "UseHuman_Big"
		- extraOptions = Table that holds extra options to modify parts of the code
			- Pos = Sets the spawn position
			- Ang = Sets the spawn angle | DEFAULT = Random angle
			- Vel = Sets the velocity | "UseDamageForce" = To use the damage's force only | DEFAULT = Random velocity
			- Vel_ApplyDmgForce = If set to false, it won't add the damage force to the given velocity | DEFAULT = true
			- AngVel = Angle velocity, basically the speed it rotates as it's flying | DEFAULT = Random velocity
			- BloodType = Sets the blood type of the gib | Overrides "CollisionDecal" option | Works only with "obj_vj_gib"
			- CollisionDecal = Decal it spawns when it collides with something | false = Disable decals | DEFAULT = Base decides
			- CollisionSound = Sound(s) it plays when it collides with something | false = Disable collision sounds | DEFAULT = Base decides
			- NoFade = Should it let the base make it fade & remove (Adjusted in the NPC settings menu) | DEFAULT = false
			- RemoveOnCorpseDelete = Should the entity get removed if the corpse is removed? | DEFAULT = false
		- customFunc(gib) = Use this to edit the entity which is given as parameter "gib"
-----------------------------------------------------------]]
local gib_mdlAAll = {"models/vj_base/gibs/alien/gib_small1.mdl", "models/vj_base/gibs/alien/gib_small2.mdl", "models/vj_base/gibs/alien/gib_small3.mdl", "models/vj_base/gibs/alien/gib1.mdl", "models/vj_base/gibs/alien/gib2.mdl", "models/vj_base/gibs/alien/gib3.mdl", "models/vj_base/gibs/alien/gib4.mdl", "models/vj_base/gibs/alien/gib5.mdl", "models/vj_base/gibs/alien/gib6.mdl", "models/vj_base/gibs/alien/gib7.mdl"}
local gib_mdlASmall = {"models/vj_base/gibs/alien/gib_small1.mdl", "models/vj_base/gibs/alien/gib_small2.mdl", "models/vj_base/gibs/alien/gib_small3.mdl"}
local gib_mdlABig = {"models/vj_base/gibs/alien/gib1.mdl", "models/vj_base/gibs/alien/gib2.mdl", "models/vj_base/gibs/alien/gib3.mdl", "models/vj_base/gibs/alien/gib4.mdl", "models/vj_base/gibs/alien/gib5.mdl", "models/vj_base/gibs/alien/gib6.mdl", "models/vj_base/gibs/alien/gib7.mdl"}
local gib_mdlHSmall = {"models/vj_base/gibs/human/gib_small1.mdl", "models/vj_base/gibs/human/gib_small2.mdl", "models/vj_base/gibs/human/gib_small3.mdl"}
local gib_mdlHBig = {"models/vj_base/gibs/human/gib1.mdl", "models/vj_base/gibs/human/gib2.mdl", "models/vj_base/gibs/human/gib3.mdl", "models/vj_base/gibs/human/gib4.mdl", "models/vj_base/gibs/human/gib5.mdl", "models/vj_base/gibs/human/gib6.mdl", "models/vj_base/gibs/human/gib7.mdl"}
--
function ENT:CreateGibEntity(class, models, extraOptions, customFunc)
	if self.CanGib == false then return end
	local bloodType = false
	if models == "UseAlien_Small" then
		models =  PICK(gib_mdlASmall)
		bloodType = VJ.BLOOD_COLOR_YELLOW
	elseif models == "UseAlien_Big" then
		models =  PICK(gib_mdlABig)
		bloodType = VJ.BLOOD_COLOR_YELLOW
	elseif models == "UseHuman_Small" then
		models =  PICK(gib_mdlHSmall)
		bloodType = VJ.BLOOD_COLOR_RED
	elseif models == "UseHuman_Big" then
		models =  PICK(gib_mdlHBig)
		bloodType = VJ.BLOOD_COLOR_RED
	else -- Custom models
		models = PICK(models)
		if VJ.HasValue(gib_mdlAAll, models) then
			bloodType = VJ.BLOOD_COLOR_YELLOW
		end
	end
	extraOptions = extraOptions or {}
		local vel = extraOptions.Vel or Vector(math.Rand(-100, 100), math.Rand(-100, 100), math.Rand(150, 250))
		if self.SavedDmgInfo then
			local dmgForce = self.SavedDmgInfo.force / 70
			if extraOptions.Vel_ApplyDmgForce != false && extraOptions.Vel != "UseDamageForce" then -- Use both damage force AND given velocity
				vel = vel + dmgForce
			elseif extraOptions.Vel == "UseDamageForce" then -- Use damage force
				vel = dmgForce
			end
		end
		bloodType = (extraOptions.BloodType or bloodType or self.BloodColor) -- Certain entities such as the VJ Gib entity, you can use this to set its gib type
	
	local gib = ents.Create(class or "obj_vj_gib")
	gib:SetModel(models)
	gib:SetPos(extraOptions.Pos or (self:GetPos() + self:OBBCenter()))
	gib:SetAngles(extraOptions.Ang or Angle(math.Rand(-180, 180), math.Rand(-180, 180), math.Rand(-180, 180)))
	if gib:GetClass() == "obj_vj_gib" then
		gib.BloodType = bloodType
		if extraOptions.CollisionDecal != nil then
			gib.CollisionDecal = extraOptions.CollisionDecal
		elseif extraOptions.BloodDecal then -- Backwards compatibility
			gib.CollisionDecal = extraOptions.BloodDecal
		end
		if extraOptions.CollisionSound != nil then
			gib.CollisionSound = extraOptions.CollisionSound
		elseif extraOptions.CollideSound then -- Backwards compatibility
			gib.CollisionSound = extraOptions.CollideSound
		end
		//gib.BloodData = {Color = bloodType, Particle = self.BloodParticle, Decal = self.CollisionDecal} -- For eating system
	end
	gib:Spawn()
	gib:Activate()
	gib.IsVJBaseCorpse_Gib = true
	if vj_npc_gib_collision:GetInt() == 0 then gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS) end
	local phys = gib:GetPhysicsObject()
	if IsValid(phys) then
		phys:AddVelocity(vel)
		phys:AddAngleVelocity(extraOptions.AngVel or Vector(math.Rand(-200, 200), math.Rand(-200, 200), math.Rand(-200, 200)))
	end
	if extraOptions.NoFade != true && vj_npc_gib_fade:GetInt() == 1 then
		if gib:GetClass() == "obj_vj_gib" then timer.Simple(vj_npc_gib_fadetime:GetInt(), function() SafeRemoveEntity(gib) end)
		elseif gib:GetClass() == "prop_ragdoll" then gib:Fire("FadeAndRemove", "", vj_npc_gib_fadetime:GetInt())
		elseif gib:GetClass() == "prop_physics" then gib:Fire("kill", "", vj_npc_gib_fadetime:GetInt()) end
	end
	if removeOnCorpseDelete then //self.Corpse:DeleteOnRemove(extraent)
		if !self.DeathCorpse_ChildEnts then self.DeathCorpse_ChildEnts = {} end -- If it doesn't exist, then create it!
		self.DeathCorpse_ChildEnts[#self.DeathCorpse_ChildEnts + 1] = gib
	end
	if (customFunc) then customFunc(gib) end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[
More info about sound hints: https://github.com/DrVrej/VJ-Base/wiki/Developer-Notes#sound-hints
-- Condition --					-- Sound bit --								-- Suggested Use --
COND_HEAR_DANGER				SOUND_DANGER								Danger
COND_HEAR_PHYSICS_DANGER		SOUND_PHYSICS_DANGER						Danger
COND_HEAR_MOVE_AWAY				SOUND_MOVE_AWAY								Danger
COND_HEAR_COMBAT				SOUND_COMBAT								Interest
COND_HEAR_WORLD					SOUND_WORLD									Interest
COND_HEAR_BULLET_IMPACT			SOUND_BULLET_IMPACT							Interest
COND_HEAR_PLAYER				SOUND_PLAYER								Interest
COND_SMELL						SOUND_CARCASS/SOUND_MEAT/SOUND_GARBAGE		Smell
COND_HEAR_THUMPER				SOUND_THUMPER								Special case
COND_HEAR_BUGBAIT				SOUND_BUGBAIT								Special case
COND_NO_HEAR_DANGER				none										No danger detected
COND_HEAR_SPOOKY 				none										Not possible in GMod due to the missing SOUNDENT_CHANNEL_SPOOKY_NOISE
--]]
local sdInterests = bit.bor(SOUND_COMBAT, SOUND_DANGER, SOUND_BULLET_IMPACT, SOUND_PHYSICS_DANGER, SOUND_MOVE_AWAY, SOUND_PLAYER_VEHICLE, SOUND_PLAYER, SOUND_WORLD, SOUND_CARCASS, SOUND_MEAT, SOUND_GARBAGE)
--
function ENT:GetSoundInterests()
	return sdInterests
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Reset and stop the eating behavior
		- statusData = Status info to pass to "OnEat" (info types defined in that function)
-----------------------------------------------------------]]
function ENT:ResetEatingBehavior(statusData)
	local eatingData = self.EatingData
	self:SetState(VJ_STATE_NONE)
	self:OnEat("StopEating", statusData)
	self.VJ_ST_Eating = false
	self.AnimationTranslations[ACT_IDLE] = eatingData.OrgIdle -- Reset the idle animation table in case it changed!
	local food = eatingData.Ent
	if IsValid(food) then
		local foodData = food.FoodData
		-- if we are the last person eating, then reset the food data!
		if foodData.NumConsumers <= 1 then
			food.VJ_ST_BeingEaten = false
			foodData.NumConsumers = 0
			foodData.SizeRemaining = foodData.Size
		else
			foodData.NumConsumers = foodData.NumConsumers - 1
			foodData.SizeRemaining = foodData.SizeRemaining + self:OBBMaxs():Distance(self:OBBMins())
		end
	end
	self.EatingData = {Ent = NULL, NextCheck = eatingData.NextCheck, AnimStatus = "None", OrgIdle = nil}
	-- AnimStatus: "None" = Not prepared (Probably moving to food location) | "Prepared" = Prepared (Ex: Played crouch down anim) | "Eating" = Prepared and is actively eating
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Called every time a change occurs in the eating system
		- status = The change that occurred, possible changes:
			- "CheckFood"		= Possible food found, check if it's good
			- "StartBehavior"	= Food found, start the eating behavior
			- "BeginEating"		= Food location reached
			- "Eat"				= Actively eating food
			- "StopEating"		= Food may have moved, removed, or finished
		- statusData = Some status may have extra data:
			- "CheckFood": SoundHintData table, more info: https://wiki.facepunch.com/gmod/Structures/SoundHintData
			- "StopEating": String, holding one of the following states:
				- "HaltOnly"	= This is ONLY a halt, not complete reset!		| Recommendation: Play normal get up anim
				- "Unspecified"	= Ex: Food suddenly removed or moved far away	| Recommendation: Play normal get up anim
				- "Devoured"	= Has completely devoured the food!				| Recommendation: Play normal get up anim and play a sound
				- "Enemy"		= Has been alerted or detected an enemy			| Recommendation: Play scared get up anim
				- "Injured"		= Has been injured by something					| Recommendation: Play scared get up anim
				- "Dead"		= Has died, usually called in "OnRemove"		| Recommendation: Do NOT play any animation!
	Returns
		- Boolean, ONLY used for "CheckFood", returning true will tell the base the possible food is valid
		- Number, Delay to add before moving to another status, useful to make sure animations aren't cut off!
-----------------------------------------------------------]]
local vecZ50 = Vector(0, 0, -50)
--
function ENT:OnEat(status, statusData)
	-- The following code is a ideal example based on Half-Life 1 Zombie
	//VJ.DEBUG_Print(self, "OnEat", status, statusData)
	if status == "CheckFood" then
		return true //statusData.owner.BloodData && statusData.owner.BloodData.Color == VJ.BLOOD_COLOR_RED
	elseif status == "BeginEating" then
		self.AnimationTranslations[ACT_IDLE] = ACT_GESTURE_RANGE_ATTACK1 -- Eating animation
		return select(2, self:PlayAnim(ACT_ARM, true, false))
	elseif status == "Eat" then
		VJ.EmitSound(self, "barnacle/bcl_chew" .. math.random(1, 3) .. ".wav", 55)
		-- Health changes
		local food = self.EatingData.Ent
		local damage = 15 -- How much damage food will receive
		local foodHP = food:Health() -- Food's health
		local myHP = self:Health() -- NPC's current health
		self:SetHealth(math.Clamp(myHP + ((damage > foodHP and foodHP) or damage), myHP, self:GetMaxHealth() < myHP and myHP or self:GetMaxHealth())) -- Give health to the NPC
		food:SetHealth(foodHP - damage) -- Decrease corpse health
		-- Blood effects
		local bloodData = food.BloodData
		if bloodData then
			local bloodPos = food:GetPos() + food:OBBCenter()
			local bloodParticle = PICK(bloodData.Particle)
			if bloodParticle then
				ParticleEffect(bloodParticle, bloodPos, self:GetAngles())
			end
			local bloodDecal = PICK(bloodData.Decal)
			if bloodDecal then
				local tr = util.TraceLine({start = bloodPos, endpos = bloodPos + vecZ50, filter = {food, self}})
				util.Decal(bloodDecal, tr.HitPos + tr.HitNormal + Vector(math.random(-45, 45), math.random(-45, 45), 0), tr.HitPos - tr.HitNormal, food)
			end
		end
		return 2 -- Eat every this seconds
	elseif status == "StopEating" then
		if statusData != "Dead" && self.EatingData.AnimStatus != "None" then -- Do NOT play anim while dead or has NOT prepared to eat
			return select(2, self:PlayAnim(ACT_DISARM, true, false))
		end
	end
	return 0
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:UpdateAnimationTranslations(wepHoldType)
	-- Decide what type of animation set to use
	if !self.ModelAnimationSet then
		if VJ.AnimExists(self, "signal_takecover") && VJ.AnimExists(self, "grenthrow") && VJ.AnimExists(self, "bugbait_hit") then
			self.ModelAnimationSet = VJ.ANIM_SET_COMBINE -- Combine
		elseif VJ.AnimExists(self, ACT_WALK_AIM_PISTOL) && VJ.AnimExists(self, ACT_RUN_AIM_PISTOL) && VJ.AnimExists(self, ACT_POLICE_HARASS1) then
			self.ModelAnimationSet = VJ.ANIM_SET_METROCOP -- Metrocop
		elseif VJ.AnimExists(self, "coverlow_r") && VJ.AnimExists(self, "wave_smg1") && VJ.AnimExists(self, ACT_BUSY_SIT_GROUND) then
			self.ModelAnimationSet = VJ.ANIM_SET_REBEL -- Rebel
		elseif VJ.AnimExists(self, "gmod_breath_layer") then
			self.ModelAnimationSet = VJ.ANIM_SET_PLAYER -- Player
		end
	end
	self.AnimationTranslations = {} -- Reset all translated animations
	self:SetAnimationTranslations(wepHoldType)
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Helper function used in `TranslateActivity` when randomly picking from a table
	NOTE: ALWAYS use this when overriding ACT_IDLE from a table!
		- tbl = Table to retrieve an animation from
	Returns
		- Activity it picked
-----------------------------------------------------------]]
function ENT:ResolveAnimation(tbl)
	-- Returns the current animation if it's found in the table and is not done playing it
	if self:GetCycle() < 0.99 then
		local curAnim = self:GetSequenceActivity(self:GetIdealSequence())
		for _, v in ipairs(tbl) do
			if curAnim == v then
				return v
			end
		end
	end
	return tbl[math.random(1, #tbl)]
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Maintains and applies the idle animation
		- force = Forcibly apply the idle animation without checking if it's already playing ACT_IDLE
-----------------------------------------------------------]]
function ENT:MaintainIdleAnimation(force)
	-- Animation cycle needs to be set to 0 to make sure engine does NOT attempt to switch sequence multiple times in this code: https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/ai_basenpc.cpp#L2987
	-- "self:IsSequenceFinished()" should NOT be used as it's broken, it returns "true" even though the animation hasn't finished, especially for non-looped animations
	//bit.band(self:GetSequenceInfo(self:GetSequence()).flags, 1) == 0 -- Checks if animation is none-looping
	//print(self:GetIdealActivity(), self:GetActivity(), self:GetSequenceName(self:GetIdealSequence()), self:GetSequenceName(self:GetSequence()), self:IsSequenceFinished(), self:GetInternalVariable("m_bSequenceLoops"), self:GetCycle())
	if force then
		//VJ.DEBUG_Print(self, "MaintainIdleAnimation", "force")
		self.LastAnimationSeed = 0
		self:ResetIdealActivity(ACT_IDLE)
		self:SetCycle(0) -- This is to make sure this destructive code doesn't override it: https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/ai_basenpc.cpp#L2987
		self:SetSaveValue("m_bSequenceLoops", false) -- Otherwise it will stutter and play an idle sequence at 999x playback speed for 0.001 second when changing from one idle to another!
	elseif self:GetIdealActivity() == ACT_IDLE && self:GetActivity() == ACT_IDLE then -- Check both ideal and current to make sure we are 100% playing an idle, otherwise transitions, certain movements, and animations will break!
		-- If animation has finished OR idle animation has changed then play a new idle!
		if (self:GetCycle() >= 0.98) or (self:TranslateActivity(ACT_IDLE) != self:GetSequenceActivity(self:GetIdealSequence())) then
			//VJ.DEBUG_Print(self, "MaintainIdleAnimation", "auto")
			self.LastAnimationSeed = 0
			self:ResetIdealActivity(ACT_IDLE)
			self:SetCycle(0) -- This is to make sure this destructive code doesn't override it: https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/ai_basenpc.cpp#L2987
			self:SetSaveValue("m_bSequenceLoops", false) -- Otherwise it will stutter and play an idle sequence at 999x playback speed for 0.001 second when changing from one idle to another!
		else
			self:SetSaveValue("m_bSequenceLoops", true) -- "m_bSequenceLoops" has to be true because non-looped animations tend to cut off near the end, usually after the cycle passes 0.8
		end
	end
	
	-- Alternative system: Directly sets the translated activity, but has other downsides
	//if self.CurrentIdleAnimation != self:GetIdealSequence() or CurTime() > self.NextIdleStandTime then
		//self.CurrentIdleAnimation = self:GetIdealSequence()
		//self.NextIdleStandTime = CurTime() + (self:SequenceDuration(self:GetIdealSequence()) / self:GetPlaybackRate())
		//self:ResetIdealActivity(self:TranslateActivity(ACT_IDLE))
	//end
	
	/* -- Old idle system
	local idleAnimTbl = self.Weapon_UnarmedBehavior_Active and self.AnimTbl_ScaredBehaviorStand or ((self.Alerted && self:GetWeaponState() != VJ.NPC_WEP_STATE_HOLSTERED && IsValid(self:GetActiveWeapon())) and self.AnimTbl_WeaponAim or self.AnimTbl_IdleStand)
	local posIdlesTbl = {}
	local posIdlesTblIndex = 1
	local sameAnimFound = false -- If true then it one of the animations in the table is the same as the current!
	local curAnim = self.CurrentIdleAnimation
	for k, v in ipairs(idleAnimTbl) do
		v = VJ.SequenceToActivity(self, v) -- Translate any sequence to activity
		if v != false then -- Its a valid activity
			-- Human base ONLY
			local wepAnim = self.WeaponAnimTranslations[v] -- Translate to weapon act in case it needs to!
			if wepAnim then -- Translation found
				v = PICK(wepAnim)
				-- VERY UGLY: If it's a table, then check inside it to see if current idle anim is one of them
				if curAnim != v && istable(wepAnim) then
					for _, v2 in ipairs(wepAnim) do
						if curAnim == v2 then
							sameAnimFound = true
							break
						end
					end
				end
			end-- End of human base only
			//idleAnimTbl[k] = v -- In case it was a sequence, override it with the translated activity number
			posIdlesTbl[posIdlesTblIndex] = v
			posIdlesTblIndex = posIdlesTblIndex + 1
			-- Check if its the current idle animation...
			if sameAnimFound == false && curAnim == v then
				sameAnimFound = true
				//break
			end
		else -- Get rid of any animations that aren't valid!
			table_remove(idleAnimTbl, k)
		end
	end
	//PrintTable(idleAnimTbl)
	-- If there is more than 1 animation in the table AND one of the animations is the current animation AND time hasn't expired, then return!
	//if #idleAnimTbl > 1 && sameAnimFound == true && self.NextIdleStandTime > CurTime() then
		//return
	//end
	
	local pickedAnim = PICK(posIdlesTbl) or ACT_IDLE -- If no animation was found, then use ACT_IDLE
	
	-- If sequence and it has no activity, then don't continue!
	//pickedAnim = VJ.SequenceToActivity(self,pickedAnim)
	//if pickedAnim == false then return false end
	
	if (!sameAnimFound) or (CurTime() > self.NextIdleStandTime) then // or (sameAnimFound && numOfAnims == 1 && CurTime() > self.NextIdleStandTime)
		self.CurrentIdleAnimation = pickedAnim
		//self.CurIdleStandMove = false
		-- VERY old system
		//if (self.MovementType == VJ_MOVETYPE_AERIAL or self.MovementType == VJ_MOVETYPE_AQUATIC) then
			//if self:BusyWithActivity() == true then return end
			//self:AA_StopMoving()
			//self:PlayAnim(pickedAnim, false, 0, false, 0, {SequenceDuration=false, SequenceInterruptible=true}) // AlwaysUseSequence=true
		//end
		//if self.CurrentSchedule == nil then -- If it's not doing a schedule then reset the activity to make sure it's not already playing the same idle activity!
			//self:StartEngineTask(ai.GetTaskID("TASK_RESET_ACTIVITY"), 0)
		//end -- End of VERY old system
		//self:StartEngineTask(ai.GetTaskID("TASK_PLAY_SEQUENCE"), pickedAnim)
		if (self.MovementType == VJ_MOVETYPE_AERIAL or self.MovementType == VJ_MOVETYPE_AQUATIC) then self:AA_StopMoving() end
		self.LastAnimationSeed = 0
		self:ResetIdealActivity(pickedAnim)
		self.NextIdleStandTime = CurTime() + (self:SequenceDuration(self:GetIdealSequence()) / self:GetPlaybackRate())
	//elseif self.CurIdleStandMove && !self:IsSequenceFinished() then
		//self:AutoMovement(self:GetAnimTimeInterval())
	end*/
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:MaintainIdleBehavior(idleType) -- idleType: nil = Random | 1 = Wander | 2 = Idle Stand
	local curTime = CurTime()
	if self.Dead or self.VJ_IsBeingControlled or (self.CurrentAttackAnimationTime > curTime) or (self.NextIdleTime > curTime) or (self.AA_CurrentMoveTime > curTime) or self:GetState() == VJ_STATE_ONLY_ANIMATION_CONSTANT then return end
	
	-- Things that override can't bypass, Forces the NPC to ONLY idle stand!
	if self:IsGoalActive() or self.DisableWandering or self.IsGuard or self.MovementType == VJ_MOVETYPE_STATIONARY or !self.LastHiddenZone_CanWander or self.NextWanderTime > curTime or self.IsFollowing or self.Medic_Status then
		self:SCHEDULE_IDLE_STAND()
		return -- Don't set self.NextWanderTime below
	elseif !idleType && self.IdleAlwaysWander then
		idleType = 1
	end
	
	-- Random (Wander & Idle Stand)
	if !idleType then
		if math.random(1, 3) == 1 then
			self:SCHEDULE_IDLE_WANDER()
		else
			self:SCHEDULE_IDLE_STAND()
		end
	-- Wander
	elseif idleType == 1 then
		self:SCHEDULE_IDLE_WANDER()
	-- Idle Stand
	elseif idleType == 2 then
		self:SCHEDULE_IDLE_STAND()
		return -- Don't set self.NextWanderTime below
	end
	
	self.NextWanderTime = curTime + math.Rand(3, 6) // self.NextIdleTime
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	The main animation function, it can play activities, sequences and gestures
		- animation = The animation to play, it can be a table OR string OR ACT_*
			- Adding "vjseq_" to a string will make it play as a sequence
			- Adding "vjges_" to a string will make it play as a gesture
			- If it's a string AND "vjseq_" or "vjges_" is NOT added:
				- The base will attempt to convert it activity, if it fails, it will play it as a sequence
				- This behavior can be overridden by AlwaysUseSequence & AlwaysUseGesture options
		- lockAnim = Should the animation be locked and not interrupted? | Includes activities, behaviors, idle, chasing, attacking, etc. | DEFAULT: false
			- NOTE: This automatically turns off if it's a gesture, only works for activities and sequences!
			- false = Interruptible by everything!
			- true = Interruptible by nothing, completely locked!
			- "LetAttacks" = Interruptible ONLY by attacks!
		- lockAnimTime = How long should it lock the animation? | DEFAULT: 0
			- false = Base calculates the time (recommended)
		- faceEnemy = Should it constantly face the enemy while playing this animation? | DEFAULT: false
			- false = Don't face the enemy
			- true = Constantly face the enemy even behind walls, objects, etc.
			- "Visible" = Only face the enemy while it's visible
		- animDelay = Delays the animation by the given number | DEFAULT: 0
		- extraOptions = Table that holds extra options to modify parts of the code
			- OnFinish(interrupted, anim) = A function that runs when the animation finishes | DEFAULT: nil
				- interrupted = Was the animation cut off? Basically something else stopped it before the animation fully completed
				- anim = The animation it played, it can be a string or an activity enumeration
			- AlwaysUseSequence = The base will force attempt to play this animation as a sequence regardless of the other options | DEFAULT: false
			- AlwaysUseGesture = The base will force attempt to play this animation as a gesture regardless of the other options | DEFAULT: false
				- NOTE: Combining "AlwaysUseSequence" and "AlwaysUseGesture" will force it to play a gesture-sequence
			- PlayBackRate = How fast should the animation play? | DEFAULT: Whatever the current playback rate is
			- PlayBackRateCalculated = If the playback rate is already calculated in the lockAnimTime, then set this to true! | DEFAULT: false
		- customFunc() = TODO: NOT FINISHED
	Returns
		- Animation, this may be an activity number or a string depending on how the animation played
			- ACT_INVALID = No animation was played or found
		- Number, Accurate animation play time after taking everything in account
			- WARNING: If "animDelay" parameter is used, result may be inaccurate!
		- Enum, Type of animation it played, such as activity, sequence, and gesture
			- Enums are VJ.ANIM_TYPE_*
-----------------------------------------------------------]]
local varGes = "vjges_"
local varSeq = "vjseq_"
--
function ENT:PlayAnim(animation, lockAnim, lockAnimTime, faceEnemy, animDelay, extraOptions, customFunc)
	animation = PICK(animation)
	if !animation then return ACT_INVALID, 0, ANIM_TYPE_NONE end
	
	lockAnim = lockAnim or false
	if lockAnimTime == nil then -- If user didn't put anything, then default it to 0
		lockAnimTime = 0 -- Set this value to false to let the base calculate the time
	end
	faceEnemy = faceEnemy or false -- Should it face the enemy while playing this animation?
	animDelay = tonumber(animDelay) or 0 -- How much time until it starts playing the animation (seconds)
	extraOptions = extraOptions or {}
	local isGesture = false
	local isSequence = false
	local isString = isstring(animation)
	
	-- Handle "vjges_" and "vjseq_"
	if isString then
		local finalString; -- Only define a table if we need to!
		local posCur = 1
		for i = 1, #animation do
			local posStartGes, posEndGes = string_find(animation, varGes, posCur) -- Check for "vjges_"
			local posStartSeq, posEndSeq = string_find(animation, varSeq, posCur) -- Check for "vjges_"
			if !posStartGes && !posStartSeq then -- No ges or seq was found, end the loop!
				if finalString then
					finalString[#finalString + 1] = string_sub(animation, posCur)
				end
				break
			end
			if !finalString then finalString = {} end -- Found a match, create table if needed
			if posStartGes then
				isGesture = true
				finalString[i] = string_sub(animation, posCur, posStartGes - 1)
				posCur = posEndGes + 1
			end
			if posStartSeq then
				isSequence = true
				finalString[i] = string_sub(animation, posCur, posStartSeq - 1)
				posCur = posEndSeq + 1
			end
		end
		if finalString then
			animation = table_concat(finalString)
		end
		-- If animation is -1 then it's probably an activity, so turn it into an activity
		-- EX: "vjges_"..ACT_MELEE_ATTACK1
		if isGesture && !isSequence && self:LookupSequence(animation) == -1 then
			animation = tonumber(animation)
			isString = false
		end
	end
	
	if extraOptions.AlwaysUseGesture then isGesture = true end -- Must play as a gesture
	if extraOptions.AlwaysUseSequence then -- Must play as a sequence
		//isGesture = false -- Leave this alone to allow gesture-sequences to play even when "AlwaysUseSequence" is true!
		isSequence = true
		if isnumber(animation) then -- If it's an activity, then convert it to a string
			animation = self:GetSequenceName(self:SelectWeightedSequence(animation))
		end
	elseif isString && !isSequence then -- Only for regular & gesture strings
		-- If it can be played as an activity, then convert it!
		local result = self:GetSequenceActivity(self:LookupSequence(animation))
		if result == nil or result == -1 then -- Leave it as string
			isSequence = true
		else -- Set it as an activity
			animation = result
			isString = false
		end
	end
	
	-- If the given animation doesn't exist, then check to see if it does in the weapon translation list
	if VJ.AnimExists(self, animation) == false then
		if !isString then -- If it's an activity then check for possible translation
			-- If it returns the same activity as "animation", then there isn't even a translation for it so don't play any animation =(
			if self:TranslateActivity(animation) == animation then
				return ACT_INVALID, 0, ANIM_TYPE_NONE
			end
		else -- No animation =(
			return ACT_INVALID, 0, ANIM_TYPE_NONE
		end
	end
	
	local animType = ((isGesture and ANIM_TYPE_GESTURE) or isSequence and ANIM_TYPE_SEQUENCE) or ANIM_TYPE_ACTIVITY -- Find the animation type
	local seed = CurTime() -- Seed the current animation, used for animation delaying & on complete check
	self.LastAnimationType = animType
	self.LastAnimationSeed = seed
	
	local function PlayAct()
		local originalPlaybackRate = self.TruePlaybackRate
		local customPlaybackRate = extraOptions.PlayBackRate
		local playbackRate = customPlaybackRate or originalPlaybackRate
		self:SetPlaybackRate(playbackRate) -- Call this to change "self.TruePlaybackRate" so "DecideAnimationLength" can be calculated correctly
		local animTime = self:DecideAnimationLength(animation, false)
		self.TruePlaybackRate = originalPlaybackRate -- Change it back to the true rate
		local doRealAnimTime = true -- Only for activities, recalculate the animTime after the schedule starts to get the real sequence time, if `lockAnimTime` is NOT set!
		
		if lockAnim && !isGesture then
			if isbool(lockAnimTime) then -- false = Let the base calculate the time
				lockAnimTime = animTime
			else -- Manually calculated
				doRealAnimTime = false
				if !extraOptions.PlayBackRateCalculated then -- Make sure not to calculate the playback rate when it already has!
					lockAnimTime = lockAnimTime / playbackRate
				end
				animTime = lockAnimTime
			end
			
			local curTime = CurTime()
			self.NextChaseTime = curTime + lockAnimTime
			self.NextIdleTime = curTime + lockAnimTime
			self.AnimLockTime = curTime + lockAnimTime
			
			if lockAnim != "LetAttacks" then
				self:StopAttacks(true)
				self.PauseAttacks = true
				timer.Create("timer_pauseattacks_reset"..self:EntIndex(), lockAnimTime, 1, function() self.PauseAttacks = false end)
			end
		end
		self.LastAnimationSeed = seed -- We need to set it again because self:StopAttacks() above will reset it when it calls to chase enemy!
		
		if isGesture then
			-- If it's an activity gesture AND it's already playing it, then remove it! Fixes same activity gestures bugging out when played right after each other!
			if !isSequence && self:IsPlayingGesture(animation) then
				self:RemoveGesture(animation)
				//self:RemoveAllGestures() -- Disallows the ability to layer multiple gestures!
			end
			local gesture = isSequence and self:AddGestureSequence(self:LookupSequence(animation)) or self:AddGesture(animation)
			if gesture != -1 then
				self:SetLayerPriority(gesture, 1) // 2
				//self:SetLayerWeight(gesture, 1)
				self:SetLayerPlaybackRate(gesture, playbackRate * 0.5)
			end
		else -- Sequences & Activities
			local schedule = vj_ai_schedule.New("PlayAnim_"..animation)
			
			-- For humans NPCs, internally the base will set these variables back to true after this function if it's called by weapon attack animations!
			self.DoingWeaponAttack = false
			self.DoingWeaponAttack_Standing = false
			
			//self:StartEngineTask(ai.GetTaskID("TASK_RESET_ACTIVITY"), 0) //schedule:EngTask("TASK_RESET_ACTIVITY", 0)
			//if self.Dead then schedule:EngTask("TASK_STOP_MOVING", 0) end
			//self:FrameAdvance(0)
			self:TaskComplete()
			self:StopMoving()
			self:ClearSchedule()
			self:ClearGoal()
			
			if isSequence then
				doRealAnimTime = false -- Sequences already have the correct time
				local seqID = self:LookupSequence(animation)
				--
				-- START: Experimental transition system for sequences
				local transitionAnim = self:FindTransitionSequence(self:GetSequence(), seqID) -- Find the transition sequence
				local transitionAnimTime = 0
				if transitionAnim != -1 && seqID != transitionAnim then -- If it exists AND it's not the same as the animation
					transitionAnimTime = self:SequenceDuration(transitionAnim) / playbackRate
					schedule:AddTask("TASK_VJ_PLAY_SEQUENCE", {
						animation = transitionAnim,
						playbackRate = customPlaybackRate or false,
						duration = transitionAnimTime
					})
				end
				-- END: Experimental transition system for sequences
				--
				schedule:AddTask("TASK_VJ_PLAY_SEQUENCE", {
					animation = animation,
					playbackRate = customPlaybackRate or false,
					duration = animTime
				})
				//self:PlaySequence(animation, playbackRate, extraOptions.SequenceDuration != false, dur)
				animTime = animTime + transitionAnimTime -- Adjust the animation time in case we have a transition animation!
			else -- Only if activity
				//self:SetActivity(ACT_RESET)
				schedule:AddTask("TASK_VJ_PLAY_ACTIVITY", {
					animation = animation,
					playbackRate = customPlaybackRate or false,
					duration = doRealAnimTime or animTime
				})
				-- Old engine task animation system
				/*if self.MovementType == VJ_MOVETYPE_AERIAL or self.MovementType == VJ_MOVETYPE_AQUATIC then
					self:ResetIdealActivity(animation)
					//schedule:EngTask("TASK_SET_ACTIVITY", animation) -- To avoid AutoMovement stopping the velocity
				//elseif faceEnemy == true then
					//schedule:EngTask("TASK_PLAY_SEQUENCE_FACE_ENEMY", animation)
				else
					-- Engine's default animation task
					-- REQUIRED FOR TASK_PLAY_SEQUENCE: It fixes animations NOT applying walk frames if the previous animation was the same!
					if self:GetActivity() == animation then
						self:ResetSequenceInfo()
						self:SetSaveValue("sequence", 0)
					end
					schedule:EngTask("TASK_PLAY_SEQUENCE", animation)
				end*/
			end
			schedule.IsPlayActivity = true
			schedule.CanBeInterrupted = !lockAnim
			if (customFunc) then customFunc(schedule, animation) end
			self:StartSchedule(schedule)
			if doRealAnimTime then
				-- Get the calculated duration (Only done in Activity type)
				animTime = self.CurrentTask.TaskData.duration
			end
			if faceEnemy then
				self:SetTurnTarget("Enemy", animTime, false, faceEnemy == "Visible")
			end
		end
		
		-- If it has a OnFinish function, then set the timer to run it when it finishes!
		if (extraOptions.OnFinish) then
			timer.Simple(animTime, function()
				if IsValid(self) && !self.Dead then
					extraOptions.OnFinish(self.LastAnimationSeed != seed, animation)
				end
			end)
		end
		return animTime
	end
	
	-- For delay system
	if animDelay > 0 then
		timer.Simple(animDelay, function()
			if IsValid(self) && self.LastAnimationSeed == seed then
				PlayAct()
			end
		end)
		return animation, animDelay + self:DecideAnimationLength(animation, false), animType -- Approximation, this may be inaccurate!
	else
		return animation, PlayAct(), animType
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks if the NPC is playing an animation that shouldn't be interrupted OR is playing an attack!
	NAV_JUMP & NAV_CLIMB is based on "IsInterruptable()" from engine: https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/ai_navigator.h#L397
	Returns
		- false, NOT busy
		- true, Busy
-----------------------------------------------------------]]
function ENT:BusyWithActivity()
	return self.PauseAttacks or self.AnimLockTime > CurTime() or self.CurrentAttackAnimationTime > CurTime() or self:GetNavType() == NAV_JUMP or self:GetNavType() == NAV_CLIMB
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks if the NPC is busy with advanced behaviors like following player or moving to heal an ally
	Returns
		- false, NOT busy
		- true, Busy
-----------------------------------------------------------]]
function ENT:IsBusyWithBehavior()
	return self.FollowData.Moving or self.Medic_Status
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks if the NPC is busy with an animation or activity AND if it's busy with an advanced behavior
	Returns
		- false, NOT busy
		- true, Busy
-----------------------------------------------------------]]
function ENT:IsBusy()
	return self:BusyWithActivity() or self:IsBusyWithBehavior()
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Sets the state of the NPC, states are prefixed with VJ_STATE_*
		- state = The state it should set it to | DEFAULT = VJ_STATE_NONE
		- time = How long should the state apply before it's reset to VJ_STATE_NONE?  | DEFAULT = -1
			-1 = State stays indefinitely until reset or changed
-----------------------------------------------------------]]
function ENT:SetState(state, time)
	state = state or VJ_STATE_NONE
	time = time or -1
	self.AIState = state
	if state == VJ_STATE_FREEZE or self:IsEFlagSet(EFL_IS_BEING_LIFTED_BY_BARNACLE) then -- Reset the tasks
		self:TaskComplete()
		self:SCHEDULE_IDLE_STAND()
	end
	if time >= 0 then
		timer.Create("timer_state_reset"..self:EntIndex(), time, 1, function()
			self:SetState()
		end)
	else
		timer.Remove("timer_state_reset"..self:EntIndex())
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Returns the current state of the NPC
-----------------------------------------------------------]]
function ENT:GetState()
	return self.AIState
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Helps you decide the pitch for the NPC, very useful for speech-type of sounds!
		- pitch1 = Random min, set to false to self.GeneralSoundPitch1 | DEFAULT = self.GeneralSoundPitch1
		- pitch2 = Random max, set to false to self.GeneralSoundPitch2 | DEFAULT = self.GeneralSoundPitch2
		NOTE: if self.UseTheSameGeneralSoundPitch is true then the default values will be self.UseTheSameGeneralSoundPitch_PickedNumber
	Returns
		- Number, the randomized number between pitch1 & pitch2
-----------------------------------------------------------]]
function ENT:GetSoundPitch(pitch1, pitch2)
	local finalPitch1 = self.GeneralSoundPitch1
	local finalPitch2 = self.GeneralSoundPitch2
	local pickedNum = self.UseTheSameGeneralSoundPitch_PickedNumber
	-- If the NPC is set to use the same sound pitch all the time and it's not 0 then use that pitch
	if self.UseTheSameGeneralSoundPitch && pickedNum != 0 then
		finalPitch1 = pickedNum
		finalPitch2 = pickedNum
	end
	if pitch1 && isnumber(pitch1) then finalPitch1 = pitch1 end
	if pitch2 && isnumber(pitch2) then finalPitch2 = pitch2 end
	return math.random(finalPitch1, finalPitch2)
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Stops most sounds played by the NPC | Excludes: Death, impact, attack misses, attack impacts
-----------------------------------------------------------]]
function ENT:StopAllSounds()
	StopSound(self.CurrentSpeechSound)
	StopSound(self.CurrentExtraSpeechSound)
	StopSound(self.CurrentBreathSound)
	StopSound(self.CurrentIdleSound)
	StopSound(self.CurrentMedicAfterHealSound)
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Gets the forward vector that the NPC is moving towards and returns it
		- ignoreZ = Ignores the Z axis of the direction during calculations | DEFAULT = false
	Returns
		- Vector, direction the NPC is moving towards
		- false, currently NOT moving
-----------------------------------------------------------]]
function ENT:GetMoveDirection(ignoreZ)
	if !self:IsMoving() then return false end
	local myPos = self:GetPos()
	local dir = ((self:GetCurWaypointPos() or myPos) - myPos)
	if ignoreZ then dir.z = 0 end
	return (self:GetAngles() - dir:Angle()):Forward()
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Quickly patches the given angle to the rotations the NPC is allowed to use (pitch, yaw, roll)
		- ang = The angle to patch
	Returns
		- Angle, the turn angle it should use
-----------------------------------------------------------]]
function ENT:GetFaceAngle(ang)
	return self.TurningUseAllAxis and ang or Angle(0, ang.y, 0)
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Resets the current turn target
-----------------------------------------------------------]]
function ENT:ResetTurnTarget()
	self.TurnData.Type = VJ.NPC_FACE_NONE
	self.TurnData.Target = nil
	self.TurnData.StopOnFace = false
	self.TurnData.IsSchedule = false
	self.TurnData.LastYaw = 0
	timer.Remove("timer_turning"..self:EntIndex())
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Makes the NPC turn and face the given target
		- target = The turn target | Valid inputs: Entity, Vector, "Enemy"
		- faceTime = How long should it face the given target? | DEFAULT = 0 | -1 : face forever unless overridden, 0 : Only set it for a single frame!
		- stopOnFace = If at any point the NPC ends up facing the target it will complete the facing! | DEFAULT: false
			- This will also be triggered if something else (ex: movements) overrides the ideal yaw!
			- If called on "Enemy" target and there is currently no active enemy, this will be triggered instantly!
		- visibleOnly = Should it only face if the given target is visible? | DEFAULT: false
	Returns
		- Angle, the final angle it's going to face
		- false, turning failed
-----------------------------------------------------------]]
function ENT:SetTurnTarget(target, faceTime, stopOnFace, visibleOnly)
	if (self.MovementType == VJ_MOVETYPE_STATIONARY && !self.CanTurnWhileStationary) then return false end
	local resultAng = false -- The final angle it's going to face
	local updateTurn = true -- An override to disallow applying the angle now
	-- Enemy facing
	if target == "Enemy" then
		//VJ.DEBUG_Print(self, "SetTurnTarget", "ENEMY")
		self:ResetTurnTarget()
		local ene = self:GetEnemy()
		-- If enemy is valid do normal facing otherwise return my angles because we didn't actually face an enemy
		if IsValid(ene) then
			resultAng = self:GetFaceAngle((ene:GetPos() - self:GetPos()):Angle())
		else
			resultAng = self:GetFaceAngle(self:GetAngles())
			updateTurn = false
		end
		if faceTime != 0 then -- 0 = Face only this frame, so don't actually set turning data!
			self.TurnData.Type = visibleOnly and VJ.NPC_FACE_ENEMY_VISIBLE or VJ.NPC_FACE_ENEMY
		end
	-- Vector facing
	elseif isvector(target) then
		//VJ.DEBUG_Print(self, "SetTurnTarget", "VECTOR")
		self:ResetTurnTarget()
		resultAng = self:GetFaceAngle((target - self:GetPos()):Angle())
		if faceTime != 0 then -- 0 = Face only this frame, so don't actually set turning data!
			self.TurnData.Type = visibleOnly and VJ.NPC_FACE_POSITION_VISIBLE or VJ.NPC_FACE_POSITION
			self.TurnData.Target = target
		end
	-- Entity facing
	elseif IsValid(target) then
		//VJ.DEBUG_Print(self, "SetTurnTarget", "ENTITY")
		self:ResetTurnTarget()
		resultAng = self:GetFaceAngle((target:GetPos() - self:GetPos()):Angle())
		if faceTime != 0 then -- 0 = Face only this frame, so don't actually set turning data!
			self.TurnData.Type = visibleOnly and VJ.NPC_FACE_ENTITY_VISIBLE or VJ.NPC_FACE_ENTITY
			self.TurnData.Target = target
		end
	end
	if resultAng then
		if updateTurn then
			if self.TurningUseAllAxis then
				local myAng = self:GetAngles()
				self:SetAngles(LerpAngle(FrameTime()*self.TurningSpeed, myAng, Angle(resultAng.p, myAng.y, resultAng.r)))
			end
			self:SetIdealYawAndUpdate(resultAng.y)
			//if self:IsSequenceFinished() then self:UpdateTurnActivity() end
		else -- Only set it, do NOT update it!
			self:SetIdealYaw(resultAng.y)
		end
		if faceTime != 0 then -- 0 = Face only this frame, so don't actually set turning data!
			self.TurnData.StopOnFace = stopOnFace or false
			self.TurnData.LastYaw = resultAng.y
			if faceTime != -1 then -- -1 = Face forever and never reset unless overridden
				timer.Create("timer_turning"..self:EntIndex(), faceTime or 0.2, 1, function()
					self:ResetTurnTarget()
				end)
			end
		end
	end
	return resultAng
end
---------------------------------------------------------------------------------------------------------------------------------------------
-- Based on: https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/game/server/ai_motor.cpp#L780
function ENT:DeltaIdealYaw()
    local flCurrentYaw = (360 / 65536) * (math.floor(self:GetLocalAngles().y * (65536 / 360)) % 65535)
    if flCurrentYaw == self:GetIdealYaw() then
        return 0
    end
    return math_angDif(self:GetIdealYaw(), flCurrentYaw)
end
---------------------------------------------------------------------------------------------------------------------------------------------
local function UTIL_VecToYaw(vec) -- Based on: https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/shared/util_shared.cpp#L44
	if (vec.y == 0 && vec.x == 0) then return 0 end
	local yaw = math_deg(math_atan2(vec.y, vec.x))
	return yaw < 0 and yaw + 360 or yaw;
end
--
function ENT:OverrideMoveFacing(flInterval, move)
	if !self.DisableFootStepSoundTimer then self:FootStepSoundCode() end
	//VJ.DEBUG_Print(self, "OverrideMoveFacing", flInterval)
	//PrintTable(move)
	
	-- Maintain turning
	local didTurn = false -- Did the NPC do any turning?
	local curTurnData = self.TurnData
	if curTurnData.Type && curTurnData.LastYaw != 0 then
		self:UpdateYaw() -- Use "UpdateYaw" instead of "SetIdealYawAndUpdate" to avoid pose parameter glitches!
		self:SetPoseParameter("move_yaw", math_angDif(UTIL_VecToYaw( move.dir ), self:GetLocalAngles().y))
		-- Need to set the yaw pose parameter, otherwise when face moving, certain directions will look broken (such as Combine soldier facing forward while moving backwards)
		-- Based on: "CAI_Motor::MoveFacing( const AILocalMoveGoal_t &move )" | Link: https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/ai_motor.cpp#L631
		didTurn = true
		return true -- Disable engine move facing
	end
	
	-- Handle the unique movement system for player models | Only face move direction if I have NOT faced anything else!
	if !didTurn && self.UsePoseParameterMovement && self.MovementType == VJ_MOVETYPE_GROUND then
		//self:SetTurnTarget(self:GetCurWaypointPos()) -- Because it will reset the current turning (if any), this will break "firing while moving" turning
		local resultAng = self:GetFaceAngle((self:GetCurWaypointPos() - self:GetPos()):Angle())
		if self.TurningUseAllAxis then
			local myAng = self:GetAngles()
			self:SetAngles(LerpAngle(FrameTime()*self.TurningSpeed, myAng, Angle(resultAng.p, myAng.y, resultAng.r)))
		end
		self:SetIdealYawAndUpdate(resultAng.y)
		return true -- Disable engine move facing
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:OverrideMove(flInterval)
	-- Maintain and handle jumping movements | Handle here instead of "RunAI" to fix landing problems
	-- If (Nav type == NAV_JUMP and Goal type == GOALTYPE_NONE) then we are probably running a custom/forced jump! (non-task based jump)
	if self:GetNavType() == NAV_JUMP && self:GetCurGoalType() == 0 then
		if self:OnGround() then
			local result = self:MoveJumpStop()
			if result == AIMR_CHANGE_TYPE then -- Landed and completed ACT_LAND animation
				self:SetNavType(NAV_GROUND)
			else -- AIMR_OK, still landing or playing ACT_LAND animation
				self:MoveJumpExec()
			end
		else
			self:MoveJumpExec()
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Get the aim position of the given entity for the NPC to aim at | EX: Position the NPC should fire at
		- target = The entity to aim at
		- aimOrigin = The starting point of the aim | EX: Muzzle of a gun the NPC is holding
		- predictionRate = Predication rate | DEFAULT = 0
			-- 0 : No prediction   |   0 < to > 1 : Closer to target   |   1 : Perfect prediction   |   1 < : Ahead of the prediction (will be very ahead/inaccurate)
		- projectileSpeed = Used if prediction is being used, helps it properly calculate the predicted aim position | DEFAULT = 1
	Returns
		- Vector, the best aim position it found | Normalize this return to get the aim direction!
-----------------------------------------------------------]]
function ENT:GetAimPosition(target, aimOrigin, predictionRate, projectileSpeed)
	local result;
	if self:Visible(target) then
		result = target:BodyTarget(aimOrigin)
		if target:IsPlayer() then -- Decrease player's Z axis as it's placed very high by the engine
			result.z = result.z - 15
		end
		if !self:VisibleVec(result) then
			result = target:HeadTarget(aimOrigin) or target:EyePos() -- Certain non player/NPC targets will return nil, so just use "EyePos"
		end
	else -- If not visible, use the last known position!
		result = self.EnemyData.LastVisiblePos
		predictionRate = 0 -- Enemy is not visible, do NOT predict!
	end
	if (predictionRate or 0) > 0 then -- If prediction is enabled
		-- 1. Calculate the distance between the origin and enemy position
		-- 2. Calculate the time it takes for the projectile to reach the enemy
		-- 3. Calculate the predicted enemy position based on their current position and velocity
		result = result + (target:GetMovementVelocity() * ((aimOrigin - result):Length() / (projectileSpeed or 1))) * predictionRate
	end
	return result
end
--[[---------------------------------------------------------
	Calculate the aim spread of the NPC depending on the given factors (Useful for bullets!)
		- target = When given, it will apply more modifiers based on the given entity (Assumes its an enemy!) | DEFAULT: NULL
		- goalPos = Position we are trying to hit
		- modifier = Final spread will be multiplied by this number | DEFAULT = 1 (no change)
	Returns
		- Number, the aim spread
	Calculation
		-- Target distance modifier
		1. Get Distance from NPC to goal position
		2. Multiply it by the max distance at which the bullet spread is at its max
		3. Normalize it between the calculated value and 0.05 where 0 is bullseye and 0.05 is max inaccuracy from distance
		--
		-- Target movement modifier
		4. Get the given target's movement speed (If target exists)
		5. Multiply it by the move speed at which the bullet spread is at its max
		6. Normalize it between the calculated value and 0.05 where 0 is bullseye and 0.05 is max inaccuracy from move speed
		7. Add it to the spread result
		--
		-- Suppression modifier
		8. Get the elapsed time since the NPC was last damaged based on "CurTime"
		9. Divide it by the cooldown time, amount of time until this modifier no longer affects the spread
		10. Normalize it between the calculated value and 1.5 as it should never go above 1.5!
		11. Negate the calculated value and subtract it against 2.5
			-> This will make sure it will return 1 if cooldown is over, otherwise it will cause the final spread result to be 0!
		12. Multiply the spread result by the calculated value
		--
		-- Other modifiers
		13. Multiply it by the owner's weapon accuracy (Weapon_Accuracy)
		14. Apply the modifier parameter, if any
-----------------------------------------------------------]]
-- To convert division to multiplication do (1 / division_number) | NOTE: Multiplication a bit faster!
local aimMaxDist = 0.0000001 -- Distance at which the bullet spread is at its max (most inaccurate) | Equivalent = Dividing by 10000000
local aimMaxMove = 0.0000001 -- Move speed at which the bullet spread is at its max (most inaccurate) | Equivalent = Dividing by 10000000
local damageCooldown = 4 -- Cooldown time in seconds, amount of time until this modifier no longer affects the spread
--
function ENT:GetAimSpread(target, goalPos, modifier)
	local result = math.min(self:GetPos():DistToSqr(goalPos) * aimMaxDist, 0.05) -- Target distance modifier
	if target then
		result = result + math.min(target:GetMovementVelocity():LengthSqr() * aimMaxMove, 0.05) -- Target movement modifier
		result = result * (2.5 - math.min((CurTime() - self:GetLastDamageTime()) / damageCooldown, 1.5)) -- Suppression modifier (Inverse effect over time)
	end
	return result * (self.Weapon_Accuracy or 1) * modifier
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Performs a group formation
		- formType = Type of formation it should do
			- Types: "Diamond"
		- baseEnt = The entity to base its position on, should be the same for all the members in the group!
		- it = The place of the NPC in the group | DEFAULT = 0
		- spacing = How far apart should they be?  | DEFAULT = 50
-----------------------------------------------------------]]
function ENT:DoGroupFormation(formType, baseEnt, it, spacing)
	it = it or 0
	spacing = spacing or 50
	if formType == "Diamond" then
		if it == 0 then
			self:SetLastPosition(baseEnt:GetPos() + baseEnt:GetForward()*spacing + baseEnt:GetRight()*spacing)
		elseif it == 1 then
			self:SetLastPosition(baseEnt:GetPos() + baseEnt:GetForward()*-spacing + baseEnt:GetRight()*spacing)
		elseif it == 2 then
			self:SetLastPosition(baseEnt:GetPos() + baseEnt:GetForward()*spacing + baseEnt:GetRight()*-spacing)
		elseif it == 3 then
			self:SetLastPosition(baseEnt:GetPos() + baseEnt:GetForward()*-spacing + baseEnt:GetRight()*-spacing)
		else
			self:SetLastPosition(baseEnt:GetPos() + baseEnt:GetForward()*(spacing + (3 * it)) + baseEnt:GetRight()*(spacing + (3 * it)))
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks if the front of the NPC can be used to take cover.
		- startPos = Start position of the trace | DEFAULT = Center of the NPC
		- endPos = End position of the trace | DEFAULT = Enemy's eye position
		- acceptWorld = If it hits the world, it will accept it as a cover | DEFAULT = false
		- extraOptions = Table that holds extra options to modify parts of the code
			- SetLastHiddenTime = If true, it will reset the "LastHidden" time, which makes the NPC stick to a position if it's well covered | DEFAULT = false
			- Debug = Used for debugging, spawns a cube at the hit position and prints the trace result | DEFAULT = false
	Returns 2 values
		- 1:
			- true, Hidden
			- false, NOT hidden
		- 2:
			- Table, trace result
-----------------------------------------------------------]]
function ENT:DoCoverTrace(startPos, endPos, acceptWorld, extraOptions)
	local ene = self:GetEnemy()
	if !IsValid(ene) then return false, {} end
	startPos = startPos or (self:GetPos() + self:OBBCenter())
	endPos = endPos or ene:EyePos()
	extraOptions = extraOptions or {}
		local setLastHiddenTime = extraOptions.SetLastHiddenTime or false
	local tr = util.TraceLine({
		start = startPos,
		endpos = endPos,
		filter = self,
		mask = MASK_SHOT
	})
	local hitPos = tr.HitPos
	local hitEnt = tr.Entity
	if extraOptions.Debug then
		debugoverlay.Box(startPos, Vector(-2, -2, -2), Vector(2, 2, 2), 1, Color(0, 255, 0))
		debugoverlay.Text(startPos, "DoCoverTrace - startPos", 1)
		debugoverlay.Box(endPos, Vector(-2, -2, -2), Vector(2, 2, 2), 1, Color(255, 0, 0))
		debugoverlay.Text(endPos, "DoCoverTrace - endPos", 1)
		debugoverlay.Box(hitPos, Vector(-2, -2, -2), Vector(2, 2, 2), 1, Color(255, 255, 0))
		debugoverlay.Line(startPos, hitPos, 1, Color(255, 255, 0))
		debugoverlay.Text(hitPos, "DoCoverTrace - tr.HitPos", 1)
	end
	
	-- Sometimes tracing isn't 100%, a tiny find in sphere check fixes this issue...
	local sphereInvalidate = false
	for _, v in ipairs(ents.FindInSphere(hitPos, 5)) do
		if v == ene or v.VJ_ID_Living then
			sphereInvalidate = true
		end
	end
	
	-- Hiding zone: It hit world AND it's close, override "acceptWorld" option!
	if tr.HitWorld && startPos:Distance(hitPos) < 200 then
		if setLastHiddenTime then self.LastHiddenZoneT = CurTime() + 20 end
		return true, tr
	-- Not a hiding zone: (Sphere found an enemy/NPC/Player) OR (World is NOT accepted as a hiding zone) OR (Trace ent is an enemy/NPC/Player) OR (End pos is far from the hit position)
	elseif sphereInvalidate or (!acceptWorld && tr.HitWorld) or (IsValid(hitEnt) && (hitEnt == ene or hitEnt.VJ_ID_Living or hitEnt:GetVelocity():LengthSqr() > 1000)) or endPos:Distance(hitPos) <= 10 then
		if setLastHiddenTime then self.LastHiddenZoneT = 0 end
		return false, tr
	else -- Hidden!
		if setLastHiddenTime then self.LastHiddenZoneT = CurTime() + 20 end
		return true, tr
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Runs traces around the entity based on the number of given directions
		- trType [string] = Type of trace to perform
			- "Quick" = High performance, but limited to 4 or 8 directions
			- "Radial" = Traces in a circular pattern based on directionCount
		- maxDist [number] = Max distance a trace can travel | DEFAULT = 200
		- requireFullDist [boolean] = If true, only traces reaching "maxDist" or beyond are included | DEFAULT = false
			- Useful for checking if a direction is obstructed
			- WARNING: Enabling this reduces performance
		- returnAsDict [boolean] = If true, returns results as a dictionary table classified by directions | DEFAULT = false
			- WARNING: Enabling this reduces performance compared to returning a flat table of positions
		- numDirections [number] = Number of directions to trace | DEFAULT = 4
		- excludeForward [boolean] = If true, it will exclude positions within the forward direction | DEFAULT = false
		- excludeBack [boolean] = If true, it will exclude positions within the backward direction | DEFAULT = false
		- excludeLeft [boolean] = If true, it will exclude positions within the left direction | DEFAULT = false
		- excludeRight [boolean] = If true, it will exclude positions within the right direction | DEFAULT = false
	Returns
		- Based on "returnAsDict"
-----------------------------------------------------------]]
function ENT:TraceDirections(trType, maxDist, requireFullDist, returnAsDict, numDirections, excludeForward, excludeBack, excludeLeft, excludeRight)
    maxDist = maxDist or 200
    numDirections = numDirections or 4
    local myPos = self:GetPos()
    local myPosZ = myPos.z
    local myPosCentered = myPos + self:OBBCenter()
	local myForward = self:GetForward()
    local myRight = self:GetRight()
	local trData = {start = myPosCentered, endpos = myPosCentered, filter = self} -- For optimization purposes
	local resultIndex = 1 -- For optimization purposes
	if trType == "Quick" then
		local result = returnAsDict and {Forward=false, Back=false, Left=false, Right=false, ForwardLeft=false, ForwardRight=false, BackLeft=false, BackRight=false} or {}
		
		-- Helper function for tracing a direction
		local function runTrace(dir, dirName)
			trData.endpos = myPosCentered + (dir * maxDist)
			local tr = util.TraceLine(trData)
			local hitPos = tr.HitPos
			if !requireFullDist or myPos:Distance(hitPos) >= maxDist then
				//VJ.DEBUG_TempEnt(hitPos)
				hitPos.z = myPosZ -- Reset it to self:GetPos() z-axis
				if returnAsDict then
					result.dirName = hitPos
				else
					result[resultIndex] = hitPos
					resultIndex = resultIndex + 1
				end
			end
		end
		
		-- Run the traces (Up to 8)
		if !excludeForward then
			runTrace(myForward, "Forward")
			if numDirections >= 5 then
				runTrace((myForward - myRight):GetNormalized(), "ForwardLeft")
				runTrace((myForward + myRight):GetNormalized(), "ForwardRight")
			end
		end
		if !excludeBack then
			runTrace(-myForward, "Back")
			if numDirections >= 5 then
				runTrace((-myForward - myRight):GetNormalized(), "BackLeft")
				runTrace((-myForward + myRight):GetNormalized(), "BackRight")
			end
		end
		if !excludeLeft then
			runTrace(-myRight, "Left")
		end
		if !excludeRight then
			runTrace(myRight, "Right")
		end
		return result
	else -- "Radial"
		local result = returnAsDict and {Forward = {}, Back = {}, Left = {}, Right = {}} or {}
		local angleIncrement = (2 * math.pi) / numDirections -- Angle increment based on the number of directions

		-- Calculate all directions and run traces
		for i = 0, numDirections - 1 do
			local angle = i * angleIncrement
			local dir = myForward * math_cos(angle) + myRight * math_sin(angle)
			local forwardDot = dir:Dot(myForward)
            local rightDot = dir:Dot(myRight)
			
			-- Check which sides we are allowed to calculate
			if (excludeForward && forwardDot > 0.7) or (excludeBack && forwardDot < -0.7) or (excludeLeft && rightDot < -0.7) or (excludeRight && rightDot > 0.7) then
				continue
			end

			trData.endpos = myPosCentered + (dir * maxDist)
			local tr = util.TraceLine(trData)
			local hitPos = tr.HitPos
			if !requireFullDist or myPos:Distance(hitPos) >= maxDist then
				//VJ.DEBUG_TempEnt(hitPos)
				hitPos.z = myPosZ -- Reset it to self:GetPos() z-axis
				if returnAsDict then
					if forwardDot > 0.7 then
						local resultForward = result.Forward
						resultForward[#resultForward + 1] = hitPos
					elseif forwardDot < -0.7 then
						local resultBack = result.Back
						resultBack[#resultBack + 1] = hitPos
					elseif rightDot < -0.7 then
						local resultLeft = result.Left
						resultLeft[#resultLeft + 1] = hitPos
					elseif rightDot > 0.7 then
						local resultRight = result.Right
						resultRight[#resultRight + 1] = hitPos
					end
				else
					result[resultIndex] = hitPos
					resultIndex = resultIndex + 1
				end
			end
		end
		return result
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Forces the NPC to jump.
		- vel = Velocity for the jump
	EX: Force the NPC to jump to the location of another entity:
		self:ForceMoveJump((activator:GetPos() - self:GetPos()):GetNormal()*200 + Vector(0, 0, 300))
-----------------------------------------------------------]]
function ENT:ForceMoveJump(vel)
	self:SetNavType(NAV_JUMP)
	self:MoveJumpStart(vel)
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	The last damage hit group that the NPC received.
	Returns
		- number, the hit group
-----------------------------------------------------------]]
function ENT:GetLastDamageHitGroup()
	return self:GetInternalVariable("m_LastHitGroup")
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Time since the NPC has been damaged (Used CurTime!)
	Returns
		- number, time
-----------------------------------------------------------]]
function ENT:GetLastDamageTime()
	return self:GetInternalVariable("m_flLastDamageTime")
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Number of times NPC has been damaged. Useful for tracking 1-shot kills
	Returns
		- number, the damage count
-----------------------------------------------------------]]
function ENT:GetTotalDamageCount()
	return self:GetInternalVariable("m_iDamageCount")
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Scale the amount of energy used to calculate damage this NPC takes due to physics
		- EXAMPLES: 0 = Take no physics damage | 0.001 = Take extremely minimum damage (manhack level) | 0.1 = Take little damage | 999999999 = Instant death
-----------------------------------------------------------]]
function ENT:SetPhysicsDamageScale(scale)
	self:SetSaveValue("m_impactEnergyScale", scale)
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Finds the nearest position from the NPC to the entity and from the entity to the nearest NPC position found previously, then returns both positions
		- ent = The entity to find the nearest position of in respect to the NPC
		- centerNPC = Should the X-axis and Y-axis for the NPC stay at the NPC's origin with ONLY the Z-axis changing? | DEFAULT: false
			- WARNING: This will override "groundedZ" to false because if both are enabled then the NPC's near position just becomes its origin
	Returns
		1:
			- Vector, NPC's nearest position to the given entity
		2:
			- Vector, Given entity's nearest position to the NPC's nearest position
-----------------------------------------------------------]]
function ENT:GetNearestPositions(ent, centerNPC)
	local myNearPos = self:NearestPoint(ent:GetPos() + ent:OBBCenter())
	if centerNPC then
		local myPos = self:GetPos()
		myNearPos.x = myPos.x
		myNearPos.y = myPos.y
	//elseif groundedZ then -- No need to have it built-in, can just be grounded after the function call
		//myNearPos.z = myPos.z
		//otherNearPos.z = myPos.z
	end
	local otherNearPos = ent:NearestPoint(myNearPos)
	//VJ.DEBUG_TempEnt(myNearPos, Angle(0, 0, 0), Color(0, 255, 0))
	//VJ.DEBUG_TempEnt(otherNearPos)
	return myNearPos, otherNearPos
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Finds the nearest position from the NPC to the entity and from the entity to the nearest NPC position found previously, then returns the distance between them
		NOTE: Identical to "GetNearestPositions", this is just a convenience function
		- ent = The entity to find the nearest position of in respect to the NPC
		- centerNPC = Should the X-axis and Y-axis for the NPC stay at the NPC's origin with ONLY the Z-axis changing? | DEFAULT: false
	Returns
		number, The distance from the NPC nearest position to the given NPC's nearest position
-----------------------------------------------------------]]
function ENT:GetNearestDistance(ent, centerNPC)
	local myNearPos = self:NearestPoint(ent:GetPos() + ent:OBBCenter())
	if centerNPC then
		local myPos = self:GetPos()
		myNearPos.x = myPos.x
		myNearPos.y = myPos.y
	end
	local otherNearPos = ent:NearestPoint(myNearPos)
	//VJ.DEBUG_TempEnt(myNearPos, Angle(0, 0, 0), Color(0, 255, 0))
	//VJ.DEBUG_TempEnt(otherNearPos)
	return otherNearPos:Distance(myNearPos)
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Takes the given number and returns a scaled number according to the difficulty that NPC is set to
		- num = The number to scale
	Returns
		- number, the scaled number
-----------------------------------------------------------]]
function ENT:ScaleByDifficulty(num)
	local dif = self.SelectedDifficulty
	if dif == 0 then
		return num
	elseif dif == -3 then
		return math_clamp(num - (num * 0.99), 1, num)
	elseif dif == -2 then
		return math_clamp(num - (num * 0.75), 1, num)
	elseif dif == -1 then
		return num * 0.5
	elseif dif == 1 then
		return num * 1.5
	elseif dif == 2 then
		return num * 2
	elseif dif == 3 then
		return num * 2.5
	elseif dif == 4 then
		return num * 3.5
	elseif dif == 5 then
		return num * 4.5
	elseif dif == 6 then
		return num * 6
	end
	return num -- Normal (default)
end
---------------------------------------------------------------------------------------------------------------------------------------------
local vecZN100 = Vector(0, 0, -100)
--
function ENT:IsJumpLegal(startPos, apex, endPos)
	local jumpData = self.JumpVars
	if !jumpData.Enabled then return false end
	if ((endPos.z - startPos.z) > jumpData.MaxRise) or ((apex.z - startPos.z) > jumpData.MaxRise) or ((startPos.z - endPos.z) > jumpData.MaxDrop) or (startPos:Distance(endPos) > jumpData.MaxDistance) then
		return false
	end
	
	-- Make sure there is a ground under where it will land!
	local tr = util.TraceLine({
		start = endPos,
		endpos = endPos + vecZN100,
	})
	/*VJ.DEBUG_TempEnt(startPos, Angle(0,0,0), Color(0,255,0))
	VJ.DEBUG_TempEnt(apex, Angle(0,0,0), Color(255,115,0))
	VJ.DEBUG_TempEnt(endPos, Angle(0,0,0), Color(255,0,0))
	VJ.DEBUG_TempEnt(tr.HitPos, Angle(0,0,0), Color(132,0,255))*/
	return tr.Hit
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:OnChangeActivity(newAct)
	//VJ.DEBUG_Print(self, "OnChangeActivity", newAct)
	//if newAct == ACT_TURN_LEFT or newAct == ACT_TURN_RIGHT then
		//self.NextIdleStandTime = CurTime() + VJ.AnimDuration(self, self:GetSequenceName(self:GetSequence()))
	//end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:KeyValue(key, value)
	//VJ.DEBUG_Print(self, "KeyValue", key, value)
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:OnRestore()
	//VJ.DEBUG_Print(self, "OnRestore")
	self:StopMoving()
	self:ResetMoveCalc()
	-- Reset the current schedule because often times GMod attempts to run it before AI task modules have loaded!
	if self.CurrentSchedule then
		self.CurrentSchedule = nil
		self.CurrentScheduleName = nil
		self.CurrentTask = nil
		self.CurrentTaskID = nil
	end
	-- Readd the weapon think hook because the transition / save does NOT do it!
	local wep = self:GetActiveWeapon()
	if IsValid(wep) then
		hook.Add("Think", wep, wep.NPC_ServerNextFire)
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:AcceptInput(key, activator, caller, data)
	//VJ.DEBUG_Print(self, "AcceptInput", key, activator, caller, data)
	local funcCustom = self.OnInput; if funcCustom then funcCustom(self, key, activator, caller, data) end
	if key == "Use" then
		-- 1. Add a delay so the game registers other key presses
		-- 2. Check for mouse 1, mouse 2, and reload
		timer.Simple(0.1, function()
			if IsValid(self) && self.FollowPlayer && !activator:KeyDown(IN_ATTACK) && !activator:KeyDownLast(IN_ATTACK) && !activator:KeyPressed(IN_ATTACK) && !activator:KeyReleased(IN_ATTACK) && !activator:KeyDown(IN_ATTACK2) && !activator:KeyDownLast(IN_ATTACK2) && !activator:KeyPressed(IN_ATTACK2) && !activator:KeyReleased(IN_ATTACK2) && !activator:KeyDown(IN_RELOAD) && !activator:KeyDownLast(IN_RELOAD) && !activator:KeyPressed(IN_RELOAD) && !activator:KeyReleased(IN_RELOAD) then
				self:Follow(activator, true)
			end
		end)
	elseif key == "StartScripting" then
		self:SetState(VJ_STATE_FREEZE)
	elseif key == "StopScripting" then
		self:SetState(VJ_STATE_NONE)
	elseif key == "SetHealth" then
		self:SetHealth(data)
		self:SetMaxHealth(data)
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:HandleAnimEvent(ev, evTime, evCycle, evType, evOptions)
	//VJ.DEBUG_Print(self, "HandleAnimEvent", ev, evTime, evCycle, evType, evOptions)
	local funcCustom = self.OnAnimEvent; if funcCustom then funcCustom(self, ev, evTime, evCycle, evType, evOptions) end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:Touch(entity)
	if self.VJ_DEBUG && GetConVar("vj_npc_debug_touch"):GetInt() == 1 then VJ.DEBUG_Print(self, "Touch", entity:GetClass()) end
	local funcCustom = self.OnTouch; if funcCustom then funcCustom(self, entity) end
	if !VJ_CVAR_AI_ENABLED or self.VJ_IsBeingControlled then return end
	
	-- If it's a passive SNPC...
	if self.Behavior == VJ_BEHAVIOR_PASSIVE or self.Behavior == VJ_BEHAVIOR_PASSIVE_NATURE then
		if self.Passive_RunOnTouch && entity.VJ_ID_Living && CurTime() > self.TakingCoverT && entity.Behavior != VJ_BEHAVIOR_PASSIVE && entity.Behavior != VJ_BEHAVIOR_PASSIVE_NATURE && self:CheckRelationship(entity) != D_LI then
			self:SCHEDULE_COVER_ORIGIN("TASK_RUN_PATH")
			self:PlaySoundSystem("Alert")
			self.TakingCoverT = CurTime() + math.Rand(self.Passive_NextRunOnTouchTime.a, self.Passive_NextRunOnTouchTime.b)
			return
		end
	elseif !self.DisableTouchFindEnemy && !self.IsFollowing && entity.VJ_ID_Living && !IsValid(self:GetEnemy()) && self:CheckRelationship(entity) != D_LI && !self:IsBusy() then
		self:StopMoving()
		self:SetTarget(entity)
		self:SCHEDULE_FACE("TASK_FACE_TARGET")
		return
	end
	
	-- Handle "MoveOutOfFriendlyPlayersWay" system
	if self.MoveOutOfFriendlyPlayersWay && !self.IsGuard then
		-- entity is player
		if entity:IsPlayer() then
			if self:CheckRelationship(entity) == D_LI then
				self:SetCondition(COND_PLAYER_PUSHING)
				if !IsValid(self:GetTarget()) then -- Only set the target if it does NOT have one to not interfere with other behaviors!
					self:SetTarget(entity)
				end
			end
		-- entity is held by a player
		elseif entity:IsPlayerHolding() then
			local findPly = entity:GetOwner()
			if !IsValid(findPly) then -- No owner found, try physics attacker
				findPly = entity:GetPhysicsAttacker()
				if !IsValid(findPly) then -- No physics attacker found, return it
					findPly = false
					return
				end
			end
			-- Player was found, check if we are allied
			if findPly && self:CheckRelationship(findPly) == D_LI then
				self:SetCondition(COND_PLAYER_PUSHING)
				if !IsValid(self:GetTarget()) then -- Only set the target if it does NOT have one to not interfere with other behaviors!
					self:SetTarget(findPly)
				end
			end
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Resets and stops following the current entity (If it's following any)
-----------------------------------------------------------]]
function ENT:ResetFollowBehavior()
	local followData = self.FollowData
	local followEnt = followData.Ent
	if IsValid(followEnt) && followEnt:IsPlayer() && self.CanChatMessage then
		if self.Dead then
			followEnt:PrintMessage(HUD_PRINTTALK, self:GetName().." has been killed.")
		else
			followEnt:PrintMessage(HUD_PRINTTALK, self:GetName().." is no longer following you.")
		end
	end
	self.IsFollowing = false
	followData.Ent = NULL -- Need to recall it here because localized can't update the table
	followData.MinDist = 0
	followData.Moving = false
	followData.StopAct = false
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Attempts to start following an entity, if it's already following another entity, it will return false!
		- ent = Entity to follow
		- stopIfFollowing = If true, it will stop following if it's already following the same entity
	Returns
		1 = Boolean
			- true, successfully started following the entity
			- false, failed or stopped following the entity
		2 = Failure reason (If it failed)
			0 = Unknown reason
			1 = NPC is stationary and unable to follow
			2 = NPC is already following another entity
			3 = NPC is hostile or neutral the entity
-----------------------------------------------------------]]
function ENT:Follow(ent, stopIfFollowing)
	if !IsValid(ent) or self.Dead or !VJ_CVAR_AI_ENABLED or self == ent then return false, 0 end
	
	local isPly = ent:IsPlayer()
	local isLiving = ent.VJ_ID_Living
	if (!isLiving) or (VJ.IsAlive(ent) && ((isPly && !VJ_CVAR_IGNOREPLAYERS) or (!isPly))) then
		local followData = self.FollowData
		-- Refusal messages
		if isLiving && self:GetClass() != ent:GetClass() && (self:Disposition(ent) == D_HT or self:Disposition(ent) == D_NU) then -- Check for enemy/neutral
			if isPly && self.CanChatMessage then
				ent:PrintMessage(HUD_PRINTTALK, self:GetName().." isn't friendly so it won't follow you.")
			end
			return false, 3
		elseif self.IsFollowing && ent != followData.Ent then -- Already following another entity
			if isPly && self.CanChatMessage then
				ent:PrintMessage(HUD_PRINTTALK, self:GetName().." is following another entity so it won't follow you.")
			end
			return false, 2
		elseif self.MovementType == VJ_MOVETYPE_STATIONARY or self.MovementType == VJ_MOVETYPE_PHYSICS then
			if isPly && self.CanChatMessage then
				ent:PrintMessage(HUD_PRINTTALK, self:GetName().." is currently stationary so it can't follow you.")
			end
			return false, 1
		end
		
		if !self.IsFollowing then
			if isPly then
				if self.CanChatMessage then
					ent:PrintMessage(HUD_PRINTTALK, self:GetName().." is now following you.")
				end
				self.GuardingPosition = false -- Reset the guarding position
				self.GuardingDirection = false
				self:PlaySoundSystem("FollowPlayer")
			end
			followData.Ent = ent
			followData.MinDist = self.FollowMinDistance + self:OBBMaxs().y + ent:OBBMaxs().y
			self.IsFollowing = true
			self:SetTarget(ent)
			if !self:BusyWithActivity() then -- Face the entity and then move to it
				self:StopMoving()
				self:SCHEDULE_FACE("TASK_FACE_TARGET", function(x)
					x.RunCode_OnFinish = function()
						if IsValid(self.FollowData.Ent) then
							self:SCHEDULE_GOTO_TARGET(((self:GetPos():Distance(self.FollowData.Ent:GetPos()) < (followData.MinDist * 1.5)) and "TASK_WALK_PATH") or "TASK_RUN_PATH", function(y) y.CanShootWhenMoving = true y.FaceData = {Type = VJ.NPC_FACE_ENEMY} end)
						end
					end
				end)
			end
			self:OnFollow("Start", ent)
			return true, 0
		elseif stopIfFollowing then -- Unfollow the entity
			if isPly then
				self:PlaySoundSystem("UnFollowPlayer")
			end
			self:StopMoving()
			self.NextWanderTime = CurTime() + 2
			if !self:BusyWithActivity() then
				self:SCHEDULE_FACE("TASK_FACE_TARGET")
			end
			self:ResetFollowBehavior()
			self:OnFollow("Stop", ent)
		end
	end
	return false, 0
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:ResetMedicBehavior()
	self:OnMedicBehavior("OnReset", "End")
	if IsValid(self.Medic_CurrentEntToHeal) then self.Medic_CurrentEntToHeal.VJ_ST_Healing = false end
	if IsValid(self.Medic_SpawnedProp) then self.Medic_SpawnedProp:Remove() end
	self.Medic_NextHealT = CurTime() + math.Rand(self.Medic_NextHealTime.a, self.Medic_NextHealTime.b)
	self.Medic_Status = false
	self.Medic_CurrentEntToHeal = NULL
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:MaintainMedicBehavior()
	if !self.IsMedic or self.Weapon_UnarmedBehavior_Active then return end -- Do NOT heal if playing scared animations!
	if !self.Medic_Status then -- Not healing anyone, so check around for allies
		if CurTime() < self.Medic_NextHealT then return end
		for _,v in ipairs(ents.FindInSphere(self:GetPos(), self.Medic_CheckDistance)) do
			-- Only allow VJ Base NPCs and players
			if (v.IsVJBaseSNPC or v:IsPlayer()) && v != self && !v.VJ_ST_Healing && !v.VJ_ID_Vehicle && (v:Health() <= v:GetMaxHealth() * 0.75) && ((v.Medic_CanBeHealed && !IsValid(self:GetEnemy()) && (!IsValid(v:GetEnemy()) or v.VJ_IsBeingControlled)) or (v:IsPlayer() && !VJ_CVAR_IGNOREPLAYERS)) && self:CheckRelationship(v) == D_LI then
				self.Medic_CurrentEntToHeal = v
				self.Medic_Status = "Active"
				v.VJ_ST_Healing = true
				self:StopMoving()
				self:MaintainMedicBehavior()
				return
			end
		end
	elseif self.Medic_Status != "Healing" then
		local ally = self.Medic_CurrentEntToHeal
		if !IsValid(ally) or !VJ.IsAlive(ally) or (ally:Health() > ally:GetMaxHealth() * 0.75) or self:CheckRelationship(ally) != D_LI then self:ResetMedicBehavior() return end
		if self:Visible(ally) && self:GetNearestDistance(ally) <= self.Medic_HealDistance then -- Are we in healing distance?
			self.Medic_Status = "Healing"
			self:OnMedicBehavior("BeforeHeal")
			self:PlaySoundSystem("MedicBeforeHeal")
			
			-- Spawn the prop
			if self.Medic_SpawnPropOnHeal && self:LookupAttachment(self.Medic_SpawnPropOnHealAttachment) != 0 then
				local prop = ents.Create("prop_physics")
				prop:SetModel(self.Medic_SpawnPropOnHealModel)
				prop:SetLocalPos(self:GetPos())
				prop:SetOwner(self)
				prop:SetParent(self)
				prop:Fire("SetParentAttachment", self.Medic_SpawnPropOnHealAttachment)
				prop:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
				prop:Spawn()
				prop:Activate()
				prop:SetSolid(SOLID_NONE)
				//prop:AddEffects(EF_BONEMERGE)
				prop:SetRenderMode(RENDERMODE_TRANSALPHA)
				self:DeleteOnRemove(prop)
				self.Medic_SpawnedProp = prop
			end
			
			-- Handle the heal time and animation
			local timeUntilHeal = self.Medic_TimeUntilHeal
			if !self.Medic_DisableAnimation then
				local _, animTime = self:PlayAnim(self.AnimTbl_Medic_GiveHealth, true, false)
				if !timeUntilHeal then -- Only change the heal time if "self.Medic_TimeUntilHeal" is set to false!
					timeUntilHeal = animTime
				end
			end
			
			self:SetTurnTarget(ally, timeUntilHeal)
			
			-- Make the ally turn and look at me
			if !ally:IsPlayer() && (ally.MovementType != VJ_MOVETYPE_STATIONARY or (ally.MovementType == VJ_MOVETYPE_STATIONARY && ally.CanTurnWhileStationary == false)) then
				self.NextWanderTime = CurTime() + 2
				self.NextChaseTime = CurTime() + 2
				ally:StopMoving()
				ally:SetTarget(self)
				ally:SCHEDULE_FACE("TASK_FACE_TARGET")
			end
			
			timer.Simple(timeUntilHeal, function()
				if IsValid(self) then
					if !IsValid(ally) then -- Ally doesn't exist anymore, reset
						self:ResetMedicBehavior()
					else -- If it exists...
						if self:CheckRelationship(ally) != D_LI then self:ResetMedicBehavior() return end -- I no longer like them, stop healing them!
						if self:GetNearestDistance(ally) <= (self.Medic_HealDistance + 20) then -- Are we still in healing distance?
							if self:OnMedicBehavior("OnHeal", ally) != false then
								local friCurHP = ally:Health()
								ally:SetHealth(math_clamp(friCurHP + self.Medic_HealthAmount, friCurHP, ally:GetMaxHealth()))
								timer.Remove("timer_melee_bleed"..ally:EntIndex())
								timer.Adjust("timer_melee_slowply"..ally:EntIndex(), 0)
								ally.VJ_SpeedEffectT = 0
								ally:RemoveAllDecals()
							end
							self:PlaySoundSystem("MedicOnHeal", nil, VJ.EmitSound)
							if ally.IsVJBaseSNPC then
								ally:PlaySoundSystem("MedicReceiveHeal")
							end
							self:ResetMedicBehavior()
						else -- If we are no longer in healing distance, go after the ally again
							self.Medic_Status = "Active"
							if IsValid(self.Medic_SpawnedProp) then self.Medic_SpawnedProp:Remove() end
							self:OnMedicBehavior("OnReset", "Retry")
						end
					end
				end
			end)
		elseif !self:BusyWithActivity() then -- If we aren't in healing distance, then go after the ally
			self.NextIdleTime = CurTime() + 4
			self.NextChaseTime = CurTime() + 4
			self:SetTarget(ally)
			self:SCHEDULE_GOTO_TARGET()
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:MaintainConstantlyFaceEnemy()
	if self.LatestEnemyDistance < self.ConstantlyFaceEnemyDistance then
		-- Handle "IfVisible" and "IfAttacking" cases
		if (self.ConstantlyFaceEnemy_IfVisible && !self.EnemyData.IsVisible) or (!self.ConstantlyFaceEnemy_IfAttacking && self.AttackType) then return end
		local postures = self.ConstantlyFaceEnemy_Postures
		if (postures == "Both") or (postures == "Moving" && self:IsMoving()) or (postures == "Standing" && !self:IsMoving()) then
			self:SetTurnTarget("Enemy")
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
local angY45 = Angle(0, 45, 0)
local angYN45 = Angle(0, -45, 0)
local angY90 = Angle(0, 90, 0)
local angYN90 = Angle(0, -90, 0)
--
function ENT:Controller_Movement(cont, ply, bullseyePos)
	if self.MovementType == VJ_MOVETYPE_STATIONARY then return false end
	local left = ply:KeyDown(IN_MOVELEFT)
	local right = ply:KeyDown(IN_MOVERIGHT)
	local sprint = ply:KeyDown(IN_SPEED)
	local aimVector = ply:GetAimVector()
	
	if ply:KeyDown(IN_FORWARD) then
		if self.MovementType == VJ_MOVETYPE_AERIAL or self.MovementType == VJ_MOVETYPE_AQUATIC then
			self:AA_MoveTo(cont.VJCE_Bullseye, true, sprint and "Alert" or "Calm", {IgnoreGround=true})
		else
			if left then
				cont:StartMovement(aimVector, angY45)
			elseif right then
				cont:StartMovement(aimVector, angYN45)
			else
				cont:StartMovement(aimVector, defAng)
			end
		end
	elseif ply:KeyDown(IN_BACK) then
		if left then
			cont:StartMovement(aimVector*-1, angYN45)
		elseif right then
			cont:StartMovement(aimVector*-1, angY45)
		else
			cont:StartMovement(aimVector*-1, defAng)
		end
	elseif left then
		cont:StartMovement(aimVector, angY90)
	elseif right then
		cont:StartMovement(aimVector, angYN90)
	else
		self:StopMoving()
		if self.MovementType == VJ_MOVETYPE_AERIAL or self.MovementType == VJ_MOVETYPE_AQUATIC then
			self:AA_StopMoving()
		end
	end
	return true
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:PlaySequence(animation)
	if !animation then return false end
	//self.VJ_PlayingSequence = true -- No longer needed as it is handled by ACT_DO_NOT_DISTURB
	self:SetActivity(ACT_DO_NOT_DISTURB) -- So `self:GetActivity()` will return the current result (alongside other immediate calls after `PlaySequence`)
	self:SetIdealActivity(ACT_DO_NOT_DISTURB) -- Avoids the engine from progressing to an ideal activity that was set very recently | EX: Fixes melee attack anims breaking when called right after `self:SCHEDULE_IDLE_STAND()`
		-- Keeps MaintainActivity from overriding sequences as seen here: https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/ai_basenpc.cpp#L6331
		-- If `m_IdealActivity` is set to ACT_DO_NOT_DISTURB, the engine will understand it's a sequence and will avoid messing with it, described here: https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/shared/ai_activity.h#L215
	local seqID = isstring(animation) and self:LookupSequence(animation) or animation
	self:ResetSequence(seqID)
	self:ResetSequenceInfo()
	self:SetCycle(0) -- Start from the beginning
	/*if useDuration then -- No longer needed as it is handled by ACT_DO_NOT_DISTURB
		timer.Create("timer_act_seqreset"..self:EntIndex(), duration, 1, function()
			self.VJ_PlayingSequence = false
			//self.PauseAttacks = false
		end)
	end*/
	return seqID
end
--------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Creates more timers for an attack | Note: it calculates playback rate!
		- name = The name of the timer, ent index is concatenated at the end | DEFAULT: "timer_unknown"
		- time = How long until the timer expires | DEFAULT: 0.5
		- func = The function to run when timer expires
-----------------------------------------------------------]]
function ENT:AddExtraAttackTimer(name, time, func)
	name = name or "timer_unknown"
	self.TimersToRemove[#self.TimersToRemove + 1] = name
	timer.Create(name..self:EntIndex(), (time or 0.5) / self.TruePlaybackRate, 1, func)
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Forces the NPC to switch to the given entity as the enemy if certain criteria passes
		- ent = The entity to set as the enemy
		- stopMoving = Should it stop moving? Will not run it already has an enemy! | DEFAULT = false
		- skipChecks = Used in "MaintainRelationships", skips all the initial checks for max performance | DEFAULT = false
-----------------------------------------------------------]]
function ENT:ForceSetEnemy(ent, stopMoving, skipChecks)
	if !skipChecks && (!IsValid(ent) or self.Behavior == VJ_BEHAVIOR_PASSIVE_NATURE or !ent:Alive() or (ent:IsPlayer() && VJ_CVAR_IGNOREPLAYERS)) then return end
	local noEne = !IsValid(self:GetEnemy())
	self:AddEntityRelationship(ent, D_HT, 0)
	self:SetEnemy(ent)
	self:UpdateEnemyMemory(ent, ent:GetPos())
	-- Must be called after "UpdateEnemyMemory"
		-- Let the engine know that our reaction time is instant otherwise it will reset the enemy if it's the first time it has seen this
	self:IgnoreEnemyUntil(ent, 0)
	self:SetNPCState(NPC_STATE_COMBAT)
	self.EnemyData.TimeSet = CurTime()
	if noEne or !self.Alerted then
		if stopMoving then
			self:ClearGoal()
			self:StopMoving()
		end
		self:DoEnemyAlert(ent)
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
-- Makes the NPC alerted but only as ready, useful when it's alerted by something unknown
function ENT:DoReadyAlert()
	self.EnemyData.Reset = false
	self.Alerted = NPC_ALERT_STATE_READY
	self:SetNPCState(NPC_STATE_ALERT)
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:DoEnemyAlert(ent)
	//VJ.DEBUG_Print(self, "DoEnemyAlert", ent, self:GetEnemy(), self.Alerted)
	if !IsValid(ent) then return end
	self.LatestEnemyDistance = self:GetPos():Distance(ent:GetPos())
	if self.Alerted == NPC_ALERT_STATE_ENEMY then return end
	local curTime = CurTime()
	local eneData = self.EnemyData
	self.Alerted = NPC_ALERT_STATE_ENEMY
	-- Fixes the NPC switching from combat to alert to combat after it sees an enemy because `DoEnemyAlert` is called after NPC_STATE_COMBAT is set
	if self:GetNPCState() != NPC_STATE_COMBAT then
		self:SetNPCState(NPC_STATE_ALERT)
	end
	eneData.TimeSinceAcquired = curTime
	eneData.LastVisibleTime = curTime
	self:OnAlert(ent)
	if curTime > self.NextAlertSoundT then
		self:PlaySoundSystem("Alert")
		self.NextAlertSoundT = curTime + math.Rand(self.NextSoundTime_Alert.a, self.NextSoundTime_Alert.b)
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks the relationship towards the given entity and converts custom dispositions such as "D_VJ_INTEREST" to a default source engine disposition
		- ent = The entity to check its relation with
	Returns
		- Disposition value, list: https://wiki.facepunch.com/gmod/Enums/D
-----------------------------------------------------------]]
function ENT:CheckRelationship(ent)
	if ent:IsFlagSet(FL_NOTARGET) or !ent:Alive() or (ent:IsPlayer() && VJ_CVAR_IGNOREPLAYERS) then return D_NU end
	if self:GetClass() == ent:GetClass() then return D_LI end
	local myDisp = self:Disposition(ent)
	if myDisp == D_VJ_INTEREST then return D_HT end
	return myDisp
end
---------------------------------------------------------------------------------------------------------------------------------------------
local cosRad20 = math_cos(math_rad(20))
--
function ENT:MaintainRelationships()
	if self.Behavior == VJ_BEHAVIOR_PASSIVE_NATURE then return false end // or self.Behavior == VJ_BEHAVIOR_PASSIVE
	local posEnemies = self.CurrentPossibleEnemies
	if posEnemies == nil then return false end
	//print("---------------------------------------")
	//VJ.DEBUG_Print(self, "MaintainRelationships")
	//PrintTable(posEnemies)
	//print("----------")
	
	local eneSeen = false
	local eneVisCount = 0
	local myPos = self:GetPos()
	local mySightDist = self:GetMaxLookDistance()
	local myClasses = self.VJ_NPC_Class
	local myHandlePerceived = self.HandlePerceivedRelationship
	local nearestDist = false
	local canAlly = self.HasAllies
	local friPlyAllies = self.FriendsWithAllPlayerAllies
	local notIsNeutral = self.Behavior != VJ_BEHAVIOR_NEUTRAL
	local customFunc = self.OnMaintainRelationships
	local it = 1
	//for k, ent in ipairs(posEnemies) do
	//for it = 1, #posEnemies do
	while it <= #posEnemies do
		local ent = posEnemies[it]
		if !IsValid(ent) then
			table_remove(posEnemies, it)
		else
			it = it + 1
			
			-- Handle no target and health below 0
			if ent:IsFlagSet(FL_NOTARGET) or !ent:Alive() then
				if IsValid(self:GetEnemy()) && self:GetEnemy() == ent then
					self:ResetEnemy(true, false)
				end
				self:AddEntityRelationship(ent, D_NU, 0)
				continue
			end
			
			local entPos = ent:GetPos()
			local distanceToEnt = myPos:Distance(entPos)
			if distanceToEnt > mySightDist then
				-- If ent is our current enemy then reset it!
				local ene = self:GetEnemy()
				if IsValid(ene) && ene == ent then
					self:PlaySoundSystem("LostEnemy")
					self:ResetEnemy(true, false)
				end
				continue
			end
			local calculatedDisp = false
			local entIsNPC = ent:IsNPC()
			local entIsPLY = ent:IsPlayer()
			
			//if !entIsPLY then
			//	print(ent:GetFOV())
			//	ent:SetSaveValue("m_debugOverlays", bit.bor(0x00000001, 0x00000002, 0x00000004, 0x00000008, 0x00000010, 0x00000020, 0x00000040, 0x00000080, 0x00000100, 0x00000200, 0x00001000, 0x00002000, 0x00004000, 0x00008000, 0x00020000, 0x00040000, 0x00080000, 0x00100000, 0x00200000, 0x00400000, 0x04000000, 0x08000000, 0x10000000, 0x20000000, 0x40000000))
			//end
			
			-- Handle "self.VJ_AddCertainEntityAsEnemy", "self.VJ_AddCertainEntityAsFriendly", "self.VJ_NPC_Class"
			if canAlly && ent.VJ_ID_Living && !VJ.HasValue(self.VJ_AddCertainEntityAsEnemy, ent) then
				-- Handle "self.VJ_NPC_Class"
				for _, friClass in ipairs(myClasses) do
					if friClass == varCPly && !self.PlayerFriendly then self.PlayerFriendly = true end -- If player ally then set the PlayerFriendly to true
					if ent.VJ_NPC_Class && VJ.HasValue(ent.VJ_NPC_Class, friClass) then
						-- Since we both have "CLASS_PLAYER_ALLY" then we need to do a special check if we both also have "self.FriendsWithAllPlayerAllies"
						-- If we both do NOT have that, then we both like players but not each other!
						if friClass == varCPly then
							if friPlyAllies && ent.FriendsWithAllPlayerAllies then
								calculatedDisp = D_LI
							end
						else
							calculatedDisp = D_LI
						end
					end
				end
				
				-- Handle "self.FriendsWithAllPlayerAllies" (As a backup in case the NPC doesn't have the "CLASS_PLAYER_ALLY" class) AND "self.PlayerFriendly" AND "self.VJ_AddCertainEntityAsFriendly"
				if !calculatedDisp && ((self.PlayerFriendly && (entIsPLY or (entIsNPC && friPlyAllies && ent.PlayerFriendly && ent.FriendsWithAllPlayerAllies))) or (VJ.HasValue(self.VJ_AddCertainEntityAsFriendly, ent))) then
					calculatedDisp = D_LI
				end
			end
			
			//print(self:HasEnemyEluded(ent))
			//print(self:HasEnemyMemory(ent))
			//print(CurTime() - self:GetEnemyLastTimeSeen(ent))
			//print(CurTime() - self:GetEnemyFirstTimeSeen(ent))
			
			local entHandlePerceived = ent.HandlePerceivedRelationship
            if entHandlePerceived then
                -- Return false to let rest of the function run otherwise return a disposition to override
				local result = entHandlePerceived(ent, self, distanceToEnt, calculatedDisp == D_LI)
                if result then
                    self:AddEntityRelationship(ent, result, 0)
					calculatedDisp = result
                    //continue
                end
            end
			
			-- If the ent is a friend then set the relation as D_LI
			if calculatedDisp == D_LI then
				//print("MaintainRelationships 2 - friendly!")
				-- Reset the enemy if it's currently this friendly ent
				local ene = self:GetEnemy()
				if IsValid(ene) && ene == ent then
					self:ResetEnemy(true, false)
				end
				
				//ent:AddEntityRelationship(self, D_LI, 0)
				self:AddEntityRelationship(ent, D_LI, 0)
				
				-- Handle how non-VJ NPCs feel towards us
				if entIsNPC && !ent.IsVJBaseSNPC then
					-- This is here to make sure non VJ NPCs will respect how entities should feel towards this NPC in case it's overridden
					if myHandlePerceived then
						local result = myHandlePerceived(self, ent, distanceToEnt, calculatedDisp == D_LI)
						if result then
							ent:AddEntityRelationship(self, result, 0)
						else
							ent:AddEntityRelationship(self, D_LI, 0)
						end
					else
						ent:AddEntityRelationship(self, D_LI, 0)
					end
				end
				
				-- MoveOutOfFriendlyPlayersWay system, Based on:
					-- "CNPC_PlayerCompanion::PredictPlayerPush"	--> https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/hl2/npc_playercompanion.cpp#L548
					-- "CAI_BaseNPC::TestPlayerPushing"				--> https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/ai_basenpc.cpp#L12676
				if entIsPLY && self.MoveOutOfFriendlyPlayersWay && !self.IsGuard && ent:GetMoveType() != MOVETYPE_NOCLIP then // && !self:BusyWithActivity()
					local plyVel = ent:GetInternalVariable("m_vecSmoothedVelocity")
					if plyVel:LengthSqr() >= 19600 then -- 140 * 140 = 19600
						local delta = self:WorldSpaceCenter() - (ent:WorldSpaceCenter() + plyVel * 0.4);
						local myMaxs = self:OBBMaxs()
						local myMins = self:OBBMins()
						local zCalc = (myMaxs.z - myMins.z) * 0.5
						local yCalc = myMaxs.y - myMins.y
						-- (ply not under me) + (ply not very above me) + (ply is close to me)   |   All calculations depend on the NPC's collision size AND player's current speed
						if delta.z < zCalc && (delta.z + zCalc + 150) > zCalc && delta:Length2DSqr() < ((yCalc * yCalc) * 1.999396) then -- 1.414 * 1.414 = 1.999396
							self:SetCondition(COND_PLAYER_PUSHING)
							if !IsValid(self:GetTarget()) then -- Only set the target if it does NOT have one to not interfere with other behaviors!
								self:SetTarget(ent)
							end
						end
					end
				end
			else
				-- Handle how non-VJ NPCs feel towards us
				if entIsNPC && !ent.IsVJBaseSNPC then
					-- This is here to make sure non VJ NPCs will respect how entities should feel towards this NPC in case it's overridden
					if myHandlePerceived then
						local result = myHandlePerceived(self, ent, distanceToEnt, calculatedDisp == D_LI)
						if result then
							ent:AddEntityRelationship(self, result, 0)
						else
							ent:AddEntityRelationship(self, D_HT, 0)
						end
					else
						ent:AddEntityRelationship(self, D_HT, 0)
					end
				end
				
				local ene = self:GetEnemy()
				local eneValid = IsValid(ene)
				if !calculatedDisp or calculatedDisp == D_VJ_INTEREST or calculatedDisp == D_HT then
					-- Check if this NPC should be engaged, if not then set it as an interest but don't engage it
					-- Restriction: If the current enemy is this entity then skip as it we want to engage regardless
					local entCanEngage = ent.CanBeEngaged
					if entCanEngage && !entCanEngage(ent, self, distanceToEnt) && (!eneValid or ene != ent) then
						//print("MaintainRelationships 2 - entCanEngage")
						self:AddEntityRelationship(ent, D_VJ_INTEREST, 0)
						calculatedDisp = D_VJ_INTEREST
					else
						-- FindEnemy: In order - Can find enemy + Not neutral or alerted + Is visible + In sight cone
						if !self.DisableFindEnemy && (notIsNeutral or self.Alerted == NPC_ALERT_STATE_ENEMY) && (self.FindEnemy_CanSeeThroughWalls or self:Visible(ent)) && self:IsInViewCone(entPos) then
							//print("MaintainRelationships 2 - set enemy")
							eneSeen = true
							eneVisCount = eneVisCount + 1
							self:AddEntityRelationship(ent, D_HT, 0)
							calculatedDisp = D_HT
							-- If the detected enemy is closer than the previous enemies, the set this as the enemy!
							if !nearestDist or (distanceToEnt < nearestDist) then
								nearestDist = distanceToEnt
								self:ForceSetEnemy(ent, true, true)
							end
						-- If all else failed then check if we hate this entity, if not then set it as an interest
						elseif self:Disposition(ent) != D_HT then
							//print("MaintainRelationships 2 - regular D_VJ_INTEREST")
							self:AddEntityRelationship(ent, D_VJ_INTEREST, 0)
							calculatedDisp = D_VJ_INTEREST
						end
					end
				else
					calculatedDisp = D_NU
				end
				
				-- Investigation detection: Sound and player flashlight systems
				if !eneValid && self.CanInvestigate && self.NextInvestigationMove < CurTime() then
					-- Investigation: Sound detection
					if ent.VJ_SD_InvestLevel && distanceToEnt < (self.InvestigateSoundDistance * ent.VJ_SD_InvestLevel) && ((CurTime() - ent.VJ_SD_InvestTime) <= 1) then
						self:DoReadyAlert()
						if self:Visible(ent) then
							self:StopMoving()
							self:SetTarget(ent)
							self:SCHEDULE_FACE("TASK_FACE_TARGET")
							self.NextInvestigationMove = CurTime() + 0.3 -- Short delay, since it's only turning
						elseif !self.IsFollowing then
							self:SetLastPosition(entPos)
							self:SCHEDULE_GOTO_POSITION("TASK_WALK_PATH", function(schedule)
								//if eneValid then schedule:EngTask("TASK_FORGET", ene) end
								//schedule:EngTask("TASK_IGNORE_OLD_ENEMIES", 0)
								schedule.CanShootWhenMoving = true
								//schedule.CanBeInterrupted = true
								schedule.FaceData = {Type = VJ.NPC_FACE_ENEMY}
							end)
							self.NextInvestigationMove = CurTime() + 2 -- Long delay, so it doesn't spam movement
						end
						self:OnInvestigate(ent)
						self:PlaySoundSystem("InvestigateSound")
					-- Investigation: Player shining flashlight onto the NPC
					elseif entIsPLY && distanceToEnt < 350 && ent:FlashlightIsOn() && (ent:GetForward():Dot((myPos - entPos):GetNormalized()) > cosRad20) then
						//			   Asiga hos-er ^ (!ent:Crouching() && ent:GetVelocity():Length() > 0 && ent:GetMoveType() != MOVETYPE_NOCLIP && ((!ent:KeyDown(IN_WALK) && (ent:KeyDown(IN_FORWARD) or ent:KeyDown(IN_BACK) or ent:KeyDown(IN_MOVELEFT) or ent:KeyDown(IN_MOVERIGHT))) or (ent:KeyDown(IN_SPEED) or ent:KeyDown(IN_JUMP)))) or
						self:StopMoving()
						self:SetTarget(ent)
						self:SCHEDULE_FACE("TASK_FACE_TARGET")
						self.NextInvestigationMove = CurTime() + 0.1 -- Short delay, since it's only turning
					end
				end
			end
			
			-- HasOnPlayerSight system, used to do certain actions when it sees the player
			if entIsPLY && self.HasOnPlayerSight && ent:Alive() && (CurTime() > self.OnPlayerSightNextT) && (distanceToEnt < self.OnPlayerSightDistance) && self:Visible(ent) && self:IsInViewCone(entPos) then
				-- 0 = Run it every time | 1 = Run it only when friendly to player | 2 = Run it only when enemy to player
				local disp = self.OnPlayerSightDispositionLevel
				if (disp == 0) or (disp == 1 && (self:Disposition(ent) == D_LI or self:Disposition(ent) == D_NU)) or (disp == 2 && self:Disposition(ent) != D_LI) then
					self:OnPlayerSight(ent)
					self:PlaySoundSystem("OnPlayerSight")
					if self.OnPlayerSightOnlyOnce then -- If it's only suppose to play it once then turn the system off
						self.HasOnPlayerSight = false
					else
						self.OnPlayerSightNextT = CurTime() + math.Rand(self.OnPlayerSightNextTime.a, self.OnPlayerSightNextTime.b)
					end
				end
			end
			
			if customFunc then customFunc(self, ent, calculatedDisp, distanceToEnt) end
		end
	end
	self.EnemyData.VisibleCount = eneVisCount
	//print("---------------------------------------")
	return eneSeen
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks allies around the NPC and call them to come to help the NPC
		- dist = How far to check for allies | DEFAULT: 800
-----------------------------------------------------------]]
function ENT:Allies_CallHelp(dist)
	local myClass = self:GetClass()
	local curTime = CurTime()
	local isFirst = true -- Is this the first ally that received this call?
	local ene = self:GetEnemy()
	if !IsValid(ene) then return end
	for _, ally in ipairs(ents.FindInSphere(self:GetPos(), dist or 800)) do
		if ally != self && ally.IsVJBaseSNPC && ally:IsNPC() && VJ.IsAlive(ally) && (ally:GetClass() == myClass or ally:Disposition(self) == D_LI) && ally.Behavior != VJ_BEHAVIOR_PASSIVE_NATURE && ally.CanReceiveOrders && ene:GetClass() != ally:GetClass() && !IsValid(ally:GetEnemy()) then
			-- If it's guarding and enemy is not visible, then don't call!
			if ally.IsGuard && !ally:Visible(ene) then continue end
			
			local eneIsPlayer = ene:IsPlayer()
			if ((!eneIsPlayer && ally:Disposition(ene) != D_LI) or eneIsPlayer) then
				-- Enemy too far away for ally
				if ally:GetPos():Distance(ene:GetPos()) > ally:GetMaxLookDistance() then
					-- See if you can move to the ally's location to get closer
					if !ally.IsFollowing && !ally:IsBusy() then
						-- If it's wandering, then just override it as it's not important
						if ally:IsMoving() && self.CurrentScheduleName != "SCHEDULE_IDLE_WANDER" then
							continue
						end
						ally:SetLastPosition(self:GetPos() + self:GetRight()*math.random(-50, 50) + self:GetForward()*math.random(-50, 50))
						ally:SCHEDULE_GOTO_POSITION("TASK_RUN_PATH", function(x) x.CanShootWhenMoving = true x.FaceData = {Type = VJ.NPC_FACE_ENEMY} end)
					else
						continue
					end
				else
					-- If the enemy is a player and the ally is player-friendly then make that player an enemy to the ally
					if eneIsPlayer && ally.PlayerFriendly then
						ally.VJ_AddCertainEntityAsEnemy[#ally.VJ_AddCertainEntityAsEnemy + 1] = ene
					end
					ally:ForceSetEnemy(ene, true)
					if curTime > ally.NextChaseTime then
						if ally.Behavior != VJ_BEHAVIOR_PASSIVE && ally:Visible(ene) then
							ally:SetTarget(ene)
							ally:SCHEDULE_FACE("TASK_FACE_TARGET")
						else
							ally:PlaySoundSystem("OnReceiveOrder")
							ally:MaintainAlertBehavior()
						end
					end
				end
				
				self:OnCallForHelp(ally, isFirst)
				self:PlaySoundSystem("CallForHelp")
				-- Play the animation
				if self.HasCallForHelpAnimation && curTime > self.NextCallForHelpAnimationT then
					self:PlayAnim(self.AnimTbl_CallForHelp, true, false, self.CallForHelpAnimationFaceEnemy)
					self.NextCallForHelpAnimationT = curTime + self.NextCallForHelpAnimationTime
				end
				isFirst = false
			end
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks allies around the NPC and return all of them as a table
		- dist = How far to check for allies | DEFAULT: 800
	Returns
		- false, Failed to find any allies
		- Table, table of allies it found
-----------------------------------------------------------]]
function ENT:Allies_Check(dist)
	local allies = {}
	local alliesNum = 0
	local isPassive = self.Behavior == VJ_BEHAVIOR_PASSIVE or self.Behavior == VJ_BEHAVIOR_PASSIVE_NATURE
	local myClass = self:GetClass()
	for _, v in ipairs(ents.FindInSphere(self:GetPos(), dist or 800)) do
		if v != self && v:IsNPC() && v.IsVJBaseSNPC && VJ.IsAlive(v) && (v:GetClass() == myClass or (v:Disposition(self) == D_LI or v.Behavior == VJ_BEHAVIOR_PASSIVE_NATURE)) && v.CanReceiveOrders then
			if isPassive then
				if v.Behavior == VJ_BEHAVIOR_PASSIVE or v.Behavior == VJ_BEHAVIOR_PASSIVE_NATURE then
					alliesNum = alliesNum + 1
					allies[alliesNum] = v
				end
			else
				alliesNum = alliesNum + 1
				allies[alliesNum] = v
			end
		end
	end
	return alliesNum > 0 and allies or false
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks allies around the NPC and brings them to the NPC
		- formType = Type of formation the allies should do | DEFAULT: "Random"
			- Types: "Random" | "Diamond"
		- dist = How far to check for allies | DEFAULT: 800
		- entsTbl = Pass in a table of entities to use, otherwise it will run a sphere check | DEFAULT: Sphere check
		- limit = How many allies can it bring? | DEFAULT: 3
			- 0 = Unlimited
		- onlyVis = Should it only allow allies that are visible? | DEFAULT: false
	Returns
		- false, Failed to find any allies
		- true, Number of allies surpassed or reached the limit
		- nil, Allies found but within the limit
-----------------------------------------------------------]]
function ENT:Allies_Bring(formType, dist, entsTbl, limit, onlyVis)
	local myPos = self:GetPos()
	formType = formType or "Random"
	dist = dist or 800
	limit = limit or 3
	local myClass = self:GetClass()
	local it = 0
	for _, v in ipairs(entsTbl or ents.FindInSphere(myPos, dist)) do
		if v != self && v.IsVJBaseSNPC && v:IsNPC() && VJ.IsAlive(v) && (v:GetClass() == myClass or v:Disposition(self) == D_LI) && v.Behavior != VJ_BEHAVIOR_PASSIVE && v.Behavior != VJ_BEHAVIOR_PASSIVE_NATURE && !v.IsFollowing && !v.IsGuard && v.CanReceiveOrders then
			if onlyVis && !v:Visible(self) then continue end
			if !IsValid(v:GetEnemy()) && myPos:Distance(v:GetPos()) < dist then
				self.NextWanderTime = CurTime() + 8
				v.NextWanderTime = CurTime() + 8
				it = it + 1
				-- Formation
				if formType == "Random" then
					local randPos = math.random(1, 4)
					if randPos == 1 then
						v:SetLastPosition(myPos + self:GetRight()*math.random(20, 50))
					elseif randPos == 2 then
						v:SetLastPosition(myPos + self:GetRight()*math.random(-20, -50))
					elseif randPos == 3 then
						v:SetLastPosition(myPos + self:GetForward()*math.random(20, 50))
					elseif randPos == 4 then
						v:SetLastPosition(myPos + self:GetForward()*math.random(-20, -50))
					end
				elseif formType == "Diamond" then
					v:DoGroupFormation("Diamond", self, it)
				end
				-- Move type
				if v.IsVJBaseSNPC_Human && !IsValid(v:GetActiveWeapon()) then
					v:SCHEDULE_COVER_ORIGIN("TASK_RUN_PATH")
				else
					v:SCHEDULE_GOTO_POSITION("TASK_WALK_PATH", function(x) x.CanShootWhenMoving = true x.FaceData = {Type = VJ.NPC_FACE_ENEMY} end)
				end
			end
			if limit != 0 && it >= limit then return true end -- Return true if it reached the limit
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Decides the attack time.
		- timer2 = Use for randomization, leave to "false" to just use timer1
		- untilDamage = Used for timer-based attacks, decreases timer1
		- animDur = Used when timer1 is set to "false", it over takes timer1
	Returns
		- Number, the decided time
-----------------------------------------------------------]]
function ENT:DecideAttackTimer(timer1, timer2, untilDamage, animDur)
	local result = timer1
	-- animDur has already calculated the playback rate!
	if timer1 == false then -- Let the base decide..
		if untilDamage == false then -- Event-based
			result = animDur
		else -- Timer-based
			if animDur <= 0 then -- If it's 0 or less, then this attack probably did NOT play an animation, so don't use animDur!
				result = untilDamage / self.TruePlaybackRate
			else
				result = animDur - (untilDamage / self.TruePlaybackRate)
			end
		end
	else -- If a specific number has been put then make sure to calculate its playback rate
		result = result / self.TruePlaybackRate
	end
	
	-- If a 2nd value is given (Used for randomization), calculate its playback rate as well and then get a random value between it and the result
	if isnumber(timer2) then
		result = math.Rand(result, timer2 / self.TruePlaybackRate)
	end
	
	return result // / self.TruePlaybackRate -- No need, playback is already calculated above
end
---------------------------------------------------------------------------------------------------------------------------------------------
local function flinchDamageTypeCheck(checkTbl, dmgType)
	for k = 1, #checkTbl do
		if bAND(dmgType, checkTbl[k]) != 0 then
			return true
		end
	end
end
--
function ENT:Flinch(dmginfo, hitgroup)
	local curTime = CurTime()
	if self.CanFlinch == 0 or self.Flinching or self.AnimLockTime > curTime or self.NextFlinchT > curTime or self:GetNavType() == NAV_JUMP or self:GetNavType() == NAV_CLIMB then return end
	
	-- DMG_FORCE_FLINCH: Skip secondary checks, flinch chance, and damage types!
	local customDmgType = dmginfo:GetDamageCustom()
	if customDmgType == VJ.DMG_FORCE_FLINCH or (customDmgType != VJ.DMG_BLEED && self.TakingCoverT < curTime && math.random(1, self.FlinchChance) == 1 && ((self.CanFlinch == 1) or (self.CanFlinch == 2 && flinchDamageTypeCheck(self.FlinchDamageTypes, dmginfo:GetDamageType())))) then
		if self:OnFlinch(dmginfo, hitgroup, "PriorExecution") then return end
		
		local function RunFlinch(hitgroupInfo)
			self.Flinching = true
			self:StopAttacks(true)
			self.CurrentAttackAnimationTime = 0
			local anim = PICK(hitgroupInfo and hitgroupInfo.Animation or self.AnimTbl_Flinch)
			local _, animDur = self:PlayAnim(anim, true, self:DecideAnimationLength(anim, self.NextMoveAfterFlinchTime), false, 0, {PlayBackRateCalculated=true})
			timer.Create("timer_flinch_reset"..self:EntIndex(), animDur, 1, function() self.Flinching = false end)
			self:OnFlinch(dmginfo, hitgroup, "Execute")
			self.NextFlinchT = curTime + (!self.NextFlinchTime and animDur or self.NextFlinchTime)
		end
		
		local hitgroupTbl = self.HitGroupFlinching_Values
		-- Hitgroup flinching
		if hitgroupTbl then
			for _, v in ipairs(hitgroupTbl) do
				local hitGroups = v.HitGroup
				-- Sub-table of hitGroups
				for hitgroupX = 1, #hitGroups do
					if hitGroups[hitgroupX] == hitgroup then
						RunFlinch(v)
						return
					end
				end
			end
			if self.HitGroupFlinching_DefaultWhenNotHit then
				RunFlinch(nil)
			end
		-- Non-hitgroup flinching
		else
			RunFlinch(nil)
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Sets the NPC's blood color (particle, decal, blood pool)
		- blColor = The blood color to set it to | Must be a string, check the list below
-----------------------------------------------------------]]
local bloodNames = {
	[VJ.BLOOD_COLOR_RED] = {
		particle = "blood_impact_red_01", // vj_blood_impact_red
		decal = "VJ_Blood_Red",
		decal_gmod = "Blood",
		pool = {
			[0] = "vj_blood_pool_red_tiny",
			[1] = "vj_blood_pool_red_small",
			[2] = "vj_blood_pool_red"
		}
	},
	[VJ.BLOOD_COLOR_YELLOW] = {
		particle = "blood_impact_yellow_01", // vj_blood_impact_yellow
		decal = "VJ_Blood_Yellow",
		decal_gmod = "YellowBlood",
		pool = {
			[0] = "vj_blood_pool_yellow_tiny",
			[1] = "vj_blood_pool_yellow_small",
			[2] = "vj_blood_pool_yellow"
		}
	},
	[VJ.BLOOD_COLOR_GREEN] = {
		particle = "vj_blood_impact_green",
		decal = "VJ_Blood_Green",
		pool = {
			[0] = "vj_blood_pool_green_tiny",
			[1] = "vj_blood_pool_green_small",
			[2] = "vj_blood_pool_green"
		}
	},
	[VJ.BLOOD_COLOR_ORANGE] = {
		particle = "vj_blood_impact_orange",
		decal = "VJ_Blood_Orange",
		pool = {
			[0] = "vj_blood_pool_orange_tiny",
			[1] = "vj_blood_pool_orange_small",
			[2] = "vj_blood_pool_orange"
		}
	},
	[VJ.BLOOD_COLOR_BLUE] = {
		particle = "vj_blood_impact_blue",
		decal = "VJ_Blood_Blue",
		pool = {
			[0] = "vj_blood_pool_blue_tiny",
			[1] = "vj_blood_pool_blue_small",
			[2] = "vj_blood_pool_blue"
		}
	},
	[VJ.BLOOD_COLOR_PURPLE] = {
		particle = "vj_blood_impact_purple",
		decal = "VJ_Blood_Purple",
		pool = {
			[0] = "vj_blood_pool_purple_tiny",
			[1] = "vj_blood_pool_purple_small",
			[2] = "vj_blood_pool_purple"
		}
	},
	[VJ.BLOOD_COLOR_WHITE] = {
		particle = "vj_blood_impact_white",
		decal = "VJ_Blood_White",
		pool = {
			[0] = "vj_blood_pool_white_tiny",
			[1] = "vj_blood_pool_white_small",
			[2] = "vj_blood_pool_white"
		}
	},
	[VJ.BLOOD_COLOR_OIL] = {
		particle = "vj_blood_impact_oil",
		decal = "VJ_Blood_Oil",
		pool = {
			[0] = "vj_blood_pool_oil_tiny",
			[1] = "vj_blood_pool_oil_small",
			[2] = "vj_blood_pool_oil"
		}
	},
}
--
function ENT:SetupBloodColor(blColor)
	if !isstring(blColor) then return end -- Only strings allowed!
	local npcSize = self:OBBMaxs():Distance(self:OBBMins())
	npcSize = ((npcSize < 25 and 0) or npcSize < 50 and 1) or 2 -- 0 = tiny | 1 = small | 2 = normal
	local blood = bloodNames[blColor]
	if blood then
		if !PICK(self.BloodParticle) then
			self.BloodParticle = blood.particle
		end
		if !PICK(self.BloodDecal) then
			self.BloodDecal = self.BloodDecalUseGMod and blood.decal_gmod or blood.decal
		end
		if !PICK(self.BloodPool) then
			self.BloodPool = blood.pool[npcSize]
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:SpawnBloodParticles(dmginfo, hitgroup)
	local particleName = PICK(self.BloodParticle)
	if particleName then
		local dmgPos = dmginfo:GetDamagePosition()
		local particle = ents.Create("info_particle_system")
		particle:SetKeyValue("effect_name", particleName)
		particle:SetPos((dmgPos == defPos and (self:GetPos() + self:OBBCenter())) or dmgPos)
		particle:Spawn()
		particle:Activate()
		particle:Fire("Start")
		particle:Fire("Kill", "", 0.1)
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:SpawnBloodDecal(dmginfo, hitgroup)
	local decals = self.BloodDecal
	if !PICK(decals) then return end
	
	local dmgForce = dmginfo:GetDamageForce()
	local dmgPos = dmginfo:GetDamagePosition()
	if dmgPos == defPos then dmgPos = self:GetPos() + self:OBBCenter() end
	local clampedLength = math_clamp(dmgForce:Length() * 10, 100, self.BloodDecalDistance)
	
	-- Badi ayroun
	local tr = util.TraceLine({start = dmgPos, endpos = dmgPos + dmgForce:GetNormal() * clampedLength, filter = self})
	local trNormalP = tr.HitPos + tr.HitNormal
	local trNormalN = tr.HitPos - tr.HitNormal
	util.Decal(PICK(decals), trNormalP, trNormalN, self)
	for _ = 1, 2 do
		if math.random(1, 2) == 1 then util.Decal(PICK(decals), trNormalP + Vector(math.random(-70, 70), math.random(-70, 70), 0), trNormalN, self) end
	end
	
	-- Kedni ayroun
	if math.random(1, 2) == 1 then
		local d2_endpos = dmgPos + Vector(0, 0, - clampedLength)
		util.Decal(PICK(decals), dmgPos, d2_endpos, self)
		if math.random(1, 2) == 1 then util.Decal(PICK(decals), dmgPos, d2_endpos + Vector(math.random(-120, 120), math.random(-120, 120), 0), self) end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
local vecZ30 = Vector(0, 0, 30)
local vecZ1 = Vector(0, 0, 1)
--
function ENT:SpawnBloodPool(dmginfo, hitgroup, corpse)
	local getBloodPool = PICK(self.BloodPool)
	if getBloodPool then
		timer.Simple(2.2, function()
			if IsValid(corpse) then
				local pos = corpse:GetPos() + corpse:OBBCenter()
				local tr = util.TraceLine({
					start = pos,
					endpos = pos - vecZ30,
					filter = corpse, //function( ent ) if ( ent:GetClass() == "prop_physics" ) then return true end end
					mask = CONTENTS_SOLID
				})
				if tr.HitWorld && (tr.HitNormal == vecZ1) then // (tr.Fraction <= 0.405)
					ParticleEffect(getBloodPool, tr.HitPos, defAng, nil)
				end
			end
		end)
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:IdleSoundCode(customSD, sdType)
	if !self.HasSounds or !self.HasIdleSounds or self.Dead then return end
	
	if self.NextIdleSoundT_RegularChange < CurTime() && self.NextIdleSoundT < CurTime() then
		sdType = sdType or VJ.CreateSound
		customSD = PICK(customSD)
		local setTimer = true
		
		local hasEnemy = IsValid(self:GetEnemy())
		-- Yete CombatIdle tsayn chouni YEV gerna barz tsayn hanel, ere vor barz tsayn han e
		if hasEnemy && !PICK(self.SoundTbl_CombatIdle) && !self.IdleSounds_NoRegularIdleOnAlerted then
			hasEnemy = false
		end
		
		if hasEnemy then
			local pickedSD = PICK(self.SoundTbl_CombatIdle)
			if (math.random(1,self.CombatIdleSoundChance) == 1 && pickedSD) or customSD then
				if customSD then pickedSD = customSD end
				StopSound(self.CurrentIdleSound)
				self.CurrentIdleSound = sdType(self, pickedSD, self.CombatIdleSoundLevel, self:GetSoundPitch(self.CombatIdleSoundPitch.a, self.CombatIdleSoundPitch.b))
			end
		else
			local pickedSD = PICK(self.SoundTbl_Idle)
			local sdtbl2 = PICK(self.SoundTbl_IdleDialogue)
			local sdrand = math.random(1, self.IdleSoundChance)
			local function RegularIdle()
				if (sdrand == 1 && pickedSD) or customSD then
					if customSD then pickedSD = customSD end
					StopSound(self.CurrentIdleSound)
					self.CurrentIdleSound = sdType(self, pickedSD, self.IdleSoundLevel, self:GetSoundPitch(self.IdleSoundPitch.a, self.IdleSoundPitch.b))
				end
			end
			if sdtbl2 != false && sdrand == 1 && self.HasIdleDialogueSounds && math.random(1, 2) == 1 then
				local foundEnt;
				local canAnswer = false
				
				-- Don't break the loop unless we hit a VJ NPC that can answer break
				-- If above failed, then simply return the last checked ally
				for _, v in ipairs(ents.FindInSphere(self:GetPos(), self.IdleDialogueDistance)) do
					if v != self then
						if v:IsPlayer() then
							if self:CheckRelationship(v) == D_LI && !self:OnIdleDialogue(v, "CheckEnt", false) then
								foundEnt = v
							end
						elseif v:IsNPC() && !v.Dead && ((self:GetClass() == v:GetClass()) or (self:CheckRelationship(v) == D_LI)) && self:Visible(v) then
							local hasDialogueAnswer = (v.IsVJBaseSNPC and PICK(v.SoundTbl_IdleDialogueAnswer)) or false
							if !self:OnIdleDialogue(v, "CheckEnt", hasDialogueAnswer) then
								foundEnt = v
								if hasDialogueAnswer then
									canAnswer = true
									break
								end
							end
						end
					end
				end
	
				if foundEnt then
					StopSound(self.CurrentIdleSound)
					self.CurrentIdleSound = sdType(self, sdtbl2, self.IdleDialogueSoundLevel, self:GetSoundPitch(self.IdleDialogueSoundPitch.a, self.IdleDialogueSoundPitch.b))
					if canAnswer then -- If we have a VJ NPC that can answer
						local dur = SoundDuration(sdtbl2)
						if dur == 0 then dur = 3 end -- Since some file types don't return a proper duration =(
						local talkTime = CurTime() + (dur + 0.5)
						setTimer = false
						self.NextIdleSoundT = talkTime
						self.NextWanderTime = talkTime
						foundEnt.NextIdleSoundT = talkTime
						foundEnt.NextWanderTime = talkTime
						
						self:OnIdleDialogue(foundEnt, "Speak", talkTime)
						
						-- Stop moving and look at each other
						if self.IdleDialogueCanTurn then
							self:StopMoving()
							self:SetTarget(foundEnt)
							self:SCHEDULE_FACE("TASK_FACE_TARGET")
						end
						if foundEnt.IdleDialogueCanTurn then
							foundEnt:StopMoving()
							foundEnt:SetTarget(self)
							foundEnt:SCHEDULE_FACE("TASK_FACE_TARGET")
						end
						
						-- For the other NPC to answer back:
						timer.Simple(dur + 0.3, function()
							if IsValid(self) && IsValid(foundEnt) && !foundEnt:OnIdleDialogue(self, "Answer") then
								local response = foundEnt:IdleDialogueAnswerSoundCode()
								if response > 0 then -- If the ally responded, then make sure both SNPCs stand still & don't play another idle sound until the whole conversation is finished!
									local curTime = CurTime()
									self.NextIdleSoundT = curTime + response + 0.5
									self.NextWanderTime = curTime + response + 1
									foundEnt.NextIdleSoundT = curTime + response + 0.5
									foundEnt.NextWanderTime = curTime + response + 1
								end
							end
						end)
					end
				else
					RegularIdle()
				end
			else
				RegularIdle()
			end
		end
		if setTimer then
			self.NextIdleSoundT = CurTime() + math.Rand(self.NextSoundTime_Idle.a, self.NextSoundTime_Idle.b)
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:IdleDialogueAnswerSoundCode(customSD, sdType)
	if self.Dead or !self.HasSounds or !self.HasIdleDialogueAnswerSounds then return 0 end
	sdType = sdType or VJ.CreateSound
	customSD = PICK(customSD)
	local pickedSD = PICK(self.SoundTbl_IdleDialogueAnswer)
	if (math.random(1, self.IdleDialogueAnswerSoundChance) == 1 && pickedSD) or customSD then
		if customSD then pickedSD = customSD end
		StopSound(self.CurrentSpeechSound)
		StopSound(self.CurrentExtraSpeechSound)
		StopSound(self.CurrentIdleSound)
		self.NextIdleSoundT_RegularChange = CurTime() + math.random(2, 3)
		self.CurrentSpeechSound = sdType(self, pickedSD, self.IdleDialogueAnswerSoundLevel, self:GetSoundPitch(self.IdleDialogueAnswerSoundPitch.a, self.IdleDialogueAnswerSoundPitch.b))
		return SoundDuration(pickedSD) -- Return the duration of the sound, which will be used to make the other SNPC stand still
	end
	return 0
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:RemoveTimers()
	local myIndex = self:EntIndex()
	for _,v in ipairs(self.TimersToRemove) do
		timer.Remove(v .. myIndex)
	end
	if self.AttackTimersCustom then -- !!!!!!!!!!!!!! DO NOT USE THIS VARIABLE !!!!!!!!!!!!!! [Backwards Compatibility!]
		for _,v in ipairs(self.AttackTimersCustom) do
			timer.Remove(v .. myIndex)
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Check if the given entity is in the "self.EntitiesToNoCollide" table, if it's then apply no collide
		- ent = Entity to check and apply no collide to if it's in the table
-----------------------------------------------------------]]
function ENT:ValidateNoCollide(ent)
	local noCollTbl = self.EntitiesToNoCollide
	if noCollTbl then
		local entClass = ent:GetClass()
		for i = 1, #noCollTbl do
			if noCollTbl[i] == entClass then
				constraint.NoCollide(self, ent, 0, 0)
				-- Check if the other entity has bone followers, if it does then make them no collide
				local boneFollowers = ent:GetBoneFollowers()
				if #boneFollowers > 0 then
					for _, v in ipairs(boneFollowers) do
						constraint.NoCollide(self, v.follower, 0, 0)
					end
				end
			end
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks if the given damage type(s) contains 1 or more of the default gibbing damage types.
		- dmgType = The damage type(s) to check for
			EX: dmginfo:GetDamageType()
	Returns
		- true, At least 1 damage type is included
		- false, NO damage type is included
	Notes
		- DMG_ALWAYSGIB = Skip if it's a bullet because engine sets DMG_ALWAYSGIB for "FireBullets" if it's more than 16 otherwise it sets DMG_NEVERGIB
-----------------------------------------------------------]]
local GIB_DAMAGE_MASK = bit.bor(DMG_ALWAYSGIB, DMG_ENERGYBEAM, DMG_BLAST, DMG_VEHICLE, DMG_CRUSH, DMG_DISSOLVE, DMG_SLOWBURN, DMG_PHYSGUN, DMG_PLASMA, DMG_SONIC)
//DMG_DIRECT -- Disabled because default fire and intended weapons use it!
--
function ENT:IsGibDamage(dmgType)
	return bAND(dmgType, DMG_NEVERGIB) == 0 && bAND(dmgType, GIB_DAMAGE_MASK) != 0 && (bAND(dmgType, DMG_ALWAYSGIB) == 0 || bAND(dmgType, DMG_BULLET) == 0)
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:GibOnDeath(dmginfo, hitgroup)
	if !self.CanGib or !self.CanGibOnDeath or self.GibbedOnDeath then return false end
	if !self.GibOnDeathFilter or (self.GibOnDeathFilter && self:IsGibDamage(dmginfo:GetDamageType())) then
		local gibbed, overrides = self:HandleGibOnDeath(dmginfo, hitgroup)
		if gibbed then
			self.GibbedOnDeath = true
			if overrides then
				if !overrides.AllowCorpse then self.HasDeathCorpse = false end
				if !overrides.AllowAnim then self.HasDeathAnimation = false end
				if overrides.AllowSound != false then self:PlaySoundSystem("Gib") end -- nil/true = Play gib sound
			else -- Default
				self.HasDeathCorpse = false
				self.HasDeathAnimation = false
				self:PlaySoundSystem("Gib")
			end
			return true
		end
	end
	return false
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:StartSoundTrack()
	if !self.HasSounds or !self.HasSoundTrack then return end
	if math.random(1, self.SoundTrackChance) == 1 then
		self.VJ_SD_PlayingMusic = true
		net.Start("vj_music_run")
			net.WriteEntity(self)
			net.WriteString(PICK(self.SoundTbl_SoundTrack))
			net.WriteFloat(self.SoundTrackVolume)
			net.WriteFloat(self.SoundTrackPlaybackRate)
			//net.WriteFloat(self.SoundTrackFadeOutTime)
		net.Broadcast()
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:CreateDeathLoot(dmginfo, hitgroup)
	if math.random(1, self.DeathLootChance) == 1 then
		local pickedEnt = PICK(self.DeathLoot)
		if pickedEnt != false then
			local ent = ents.Create(pickedEnt)
			ent:SetPos(self:GetPos() + self:OBBCenter())
			ent:SetAngles(self:GetAngles())
			ent:Spawn()
			ent:Activate()
			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then
				local dmgForce = (self.SavedDmgInfo.force / 40) + self:GetMoveVelocity() + self:GetVelocity()
				if self.DeathAnimationCodeRan then
					dmgForce = self:GetMoveVelocity() == defPos and self:GetGroundSpeedVelocity() or self:GetMoveVelocity()
				end
				phys:SetMass(1)
				phys:ApplyForceCenter(dmgForce)
			end
		end
	end
end
---------------------------------------------------------------------------------------------------------------------------------------------
function ENT:OnRemove()
	self:CustomOnRemove()
	hook.Remove("Think", self)
	self.Dead = true
	if self.Medic_Status then self:ResetMedicBehavior() end
	if self.VJ_ST_Eating then self:ResetEatingBehavior("Dead") end
	self:RemoveTimers()
	self:StopAllSounds()
	self:StopParticles()
	self:DestroyBoneFollowers()
end
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------ ///// OBSOLETE FUNCTIONS | Do not to use! \\\\\ ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- !!!!!!!!!!!!!! DO NOT USE THESE !!!!!!!!!!!!!! [Backwards Compatibility!]
local dispToVal = {[D_LI] = false, [D_HT] = true, [D_NU] = "Neutral"}
function ENT:DoRelationshipCheck(ent) return dispToVal[self:CheckRelationship(ent)] end
function ENT:FaceCertainPosition(target, faceTime) return self:SetTurnTarget(target, faceTime, false, false) end
function ENT:FaceCertainEntity(target, faceCurEnemy, faceTime) return self:SetTurnTarget(faceCurEnemy and "Enemy" or target, faceTime, false, false) end
function ENT:VJ_DoSetEnemy(ent, stopMoving, doQuickIfActiveEnemy) return self:ForceSetEnemy(ent, stopMoving) end
function ENT:DoChaseAnimation(alwaysChase) self:MaintainAlertBehavior(alwaysChase) end
function ENT:VJ_TASK_CHASE_ENEMY(doLOSChase) self:SCHEDULE_ALERT_CHASE(doLOSChase) end
function ENT:VJ_TASK_FACE_X(faceType, customFunc) self:SCHEDULE_FACE(faceType, customFunc) end
function ENT:VJ_TASK_GOTO_LASTPOS(moveType, customFunc) self:SCHEDULE_GOTO_POSITION(moveType, customFunc) end
function ENT:VJ_TASK_GOTO_TARGET(moveType, customFunc) self:SCHEDULE_GOTO_TARGET(moveType, customFunc) end
function ENT:VJ_TASK_COVER_FROM_ENEMY(moveType, customFunc) self:SCHEDULE_COVER_ENEMY(moveType, customFunc) end
function ENT:VJ_TASK_COVER_FROM_ORIGIN(moveType, customFunc) self:SCHEDULE_COVER_ORIGIN(moveType, customFunc) end
function ENT:VJ_TASK_IDLE_WANDER() self:SCHEDULE_IDLE_WANDER() end
function ENT:VJ_TASK_IDLE_STAND() self:SCHEDULE_IDLE_STAND() end
function ENT:VJ_ACT_PLAYACTIVITY(animation, lockAnim, lockAnimTime, faceEnemy, animDelay, extraOptions, customFunc) return self:PlayAnim(animation, lockAnim, lockAnimTime, faceEnemy, animDelay, extraOptions, customFunc) end
function ENT:VJ_DecideSoundPitch(pitch1, pitch2) return self:GetSoundPitch(pitch1, pitch2) end
function ENT:VJ_GetDifficultyValue(num) return self:ScaleByDifficulty(num) end
function ENT:VJ_GetNearestPointToEntity(ent, centerNPC) return self:GetNearestPositions(ent, centerNPC) end
function ENT:VJ_GetNearestPointToEntityDistance(ent, centerNPC) return self:GetNearestDistance(ent, centerNPC) end
---------------------------------------------------------------------------------------------------------------------------------------------
--[[---------------------------------------------------------
	Checks all 4 sides around the NPC
		- checkDist = How far should each trace go? | DEFAULT = 200
		- returnPos = Instead of returning a table of sides, it will return a table of actual positions | DEFAULT: false
			- Use this whenever possible as it is much more optimized to utilize!
		- sides = Use this to disable checking certain positions by setting the 1 to 0, "Forward-Backward-Right-Left" | DEFAULT = "1111"
	Returns
		- When returnPos is true:
			- Table of positions (4 max)
		- When returnPos is false:
			- Table dictionary, includes 4 values, if true then that side isn't blocked!
				- Values: Forward, Backward, Right, Left
-----------------------------------------------------------]]
local str1111 = "1111"
local str1 = "1"
--
function ENT:VJ_CheckAllFourSides(checkDist, returnPos, sides)
	checkDist = checkDist or 200
	sides = sides or str1111
	local result = returnPos == true and {} or {Forward=false, Backward=false, Right=false, Left=false}
	local i = 0
	local myPos = self:GetPos()
	local myPosCentered = myPos + self:OBBCenter()
	local myForward = self:GetForward()
	local myRight = self:GetRight()
	local positions = { -- Set the positions that we need to check
		string_sub(sides, 1, 1) == str1 and myForward or 0,
		string_sub(sides, 2, 2) == str1 and -myForward or 0,
		string_sub(sides, 3, 3) == str1 and myRight or 0,
		string_sub(sides, 4, 4) == str1 and -myRight or 0
	}
	for _, v in ipairs(positions) do
		i = i + 1
		if v == 0 then continue end -- If 0 then we have the tag to skip this!
		local tr = util.TraceLine({
			start = myPosCentered,
			endpos = myPosCentered + v*checkDist,
			filter = self
		})
		local hitPos = tr.HitPos
		if myPos:Distance(hitPos) >= checkDist then
			if returnPos then
				hitPos.z = myPos.z -- Reset it to self:GetPos() z-axis
				result[#result + 1] = hitPos
			elseif i == 1 then
				result.Forward = true
			elseif i == 2 then
				result.Backward = true
			elseif i == 3 then
				result.Right = true
			elseif i == 4 then
				result.Left = true
			end
		end
	end
	return result
end
--------------------------------------------------------------------------------------------------------------------------------------------
/* -- Was used in the Human base to handle firing guns while moving
function ENT:DoWeaponAttackMovementCode(override, moveType)
	override = override or false -- Overrides some of the checks, only used for the internal task system!
	moveType = moveType or 0 -- This is used with override | 0 = Run, 1 = Walk
	if (self.CurrentWeaponEntity.IsMeleeWeapon) then
		self.DoingWeaponAttack = true
	elseif self.Weapon_CanFireWhileMoving == true then
		if self.EnemyData.IsVisible && self:CanFireWeapon(true, false) == true && ((self:IsMoving() && (self.CurrentSchedule != nil && self.CurrentSchedule.CanShootWhenMoving == true)) or (override == true)) then
			if (override == true && moveType == 0) or (self.CurrentSchedule != nil && self.CurrentSchedule.MoveType == 1) then
				local anim = self:TranslateToWeaponAnim(PICK(self.AnimTbl_ShootWhileMovingRun))
				if VJ.AnimExists(self,anim) == true then
					self.DoingWeaponAttack = true
					self.DoingWeaponAttack_Standing = false
					self:CapabilitiesAdd(CAP_MOVE_SHOOT)
					self:SetMovementActivity(anim)
					self:SetArrivalActivity(self.CurrentWeaponAnimation)
				end
			elseif (override == true && moveType == 1) or (self.CurrentSchedule != nil && self.CurrentSchedule.MoveType == 0) then
				local anim = self:TranslateToWeaponAnim(PICK(self.AnimTbl_ShootWhileMovingWalk))
				if VJ.AnimExists(self,anim) == true then
					self.DoingWeaponAttack = true
					self.DoingWeaponAttack_Standing = false
					self:CapabilitiesAdd(CAP_MOVE_SHOOT)
					self:SetMovementActivity(anim)
					self:SetArrivalActivity(self.CurrentWeaponAnimation)
				end
			end
		end
	else -- Can't move shoot!
		self:CapabilitiesRemove(CAP_MOVE_SHOOT) -- Remove the capability if it can't even move-shoot
	end
end
*/