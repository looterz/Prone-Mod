-- Copyright 2016 George "Stalker" Petrou, enjoy!

local GameMode = tobool(DarkRP) and "darkrp" or engine.ActiveGamemode()

local function GetSequenceForWeapon(holdtype, moving)
	return moving and prone.WeaponAnims.moving[holdtype] or prone.WeaponAnims.idle[holdtype]
end

hook.Add("UpdateAnimation", "Prone_Animations", function(ply, velocity, maxSeqGroundSpeed)
	if ply:IsProne() then
		local length = velocity:Length()
		local movement = 1.0
		local seq = "ProneAim_SPADE"
		local AnimState = ply:GetProneAnimState()

		if length > 0.2 then
			movement = length/maxSeqGroundSpeed
		end

		local rate = math.min(movement, 2)

		if not ply:IsOnGround() and length >= 1000 then
			rate = 0.1
		end

		if CLIENT then
			local EyeAngP = ply:EyeAngles().p 
			if not (EyeAngP >= 89) then
				ply:SetPoseParameter("body_pitch", math.Clamp(EyeAngP * -1, -10, 50))
				ply:SetPoseParameter("body_yaw", 0)
				ply:InvalidateBoneCache()
			end
		end

		if AnimState == 1 then -- Normal Prone
			local weapon = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon() or false
			local WepHoldType
			if weapon then
				WepHoldType = weapon:GetHoldType() ~= "" and weapon:GetHoldType() or weapon.HoldType
			end

			seq = GetSequenceForWeapon(WepHoldType or "normal", length >= 15) or "ProneAim_SPADE"
		elseif AnimState == 0 then -- Getting Down
			if ply:GetProneAnimLength() > CurTime() then
				seq = "ProneDown_Stand"

				local DownVect = LerpVector(FrameTime()*4, ply:GetViewOffset(), Vector(0, 0, 18))
				ply:SetViewOffset(DownVect)
				ply:SetViewOffsetDucked(DownVect)
			else
				ply:SetProneAnimState(1)
				if SERVER and prone.MoveSound then
					timer.Create("prone_walksound_"..ply:SteamID(), prone.StepSoundTime, 0, function()
						if ply:GetVelocity():Length() >= 20 then	-- We can't use the length variable here for some reaason, not sure why
							ply:EmitSound("prone.MoveSound")
						end
					end)
				end
			end
		elseif AnimState == 2 then -- Getting Up
			if ply:GetProneAnimLength() + 0.1 > CurTime() then
				seq = "ProneUp_Stand"

				local DownVect = LerpVector(FrameTime()*4, ply:GetViewOffset(), Vector(0, 0, 64))
				ply:SetViewOffset(DownVect)
				ply:SetViewOffsetDucked(DownVect)
			else
				ply:SetProneAnimState(4)
			end
		elseif SERVER then	-- If we get here then exit prone
			prone.ExitProne(ply)

			if not ply:CanExitProne() then
				prone.StartProne(ply)
				ply:SetViewOffset(Vector(0, 0, 18))
				ply:SetViewOffsetDucked(Vector(0, 0, 18))
			end
		end

		ply:SetSequence(seq)
		ply:SetPlaybackRate(rate)
	end
end)

hook.Add("SetupMove", "Prone_PreventJumpWehenProne", function(ply, cmd)
	if ply:IsProne() then
		if cmd:KeyDown(IN_JUMP) then
			cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_JUMP)))	-- Disables jumping
		end

		if ply:GetProneAnimLength() >= CurTime() then
			cmd:SetForwardSpeed(prone.GetUpOrDownSpeed)
			cmd:SetSideSpeed(prone.GetUpOrDownSpeed)
		else
			cmd:SetMaxClientSpeed(prone.ProneSpeed or 50)
		end
	end
end)

if not prone.CanMoveAndShoot then
	hook.Add("SetupMove", "Prone_PreventMoveAndShoot", function(ply, mv, cmd)
		if ply:IsProne() and (cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2)) then
			local weapon = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon() or false

			if weapon then
				local WepClass = weapon:GetClass()
				local IsWhitelistedWeapon = prone.WhitelistedWeapons[WepClass]

				if not IsWhitelistedWeapon then
					local ShouldStopMovement = true

					if cmd:KeyDown(IN_ATTACK) then
						ShouldStopMovement = weapon:Clip1() > 0
					else
						ShouldStopMovement = weapon:Clip2() > 0
					end

					if GameMode == "darkrp" and weapon.Base == "weapon_cs_base2" and GAMEMODE.Config.ironshoot and not weapon:GetIronsights() then
						ShouldStopMovement = false
					end

					if ShouldStopMovement or WepClass == "weapon_crowbar" then
						mv:SetForwardSpeed(0)
						mv:SetSideSpeed(0)
						mv:SetVelocity(Vector(0, 0, 0))
					end
				end
			end
		end
	end)
end

if GameMode == "terrortown" then
	hook.Add("TTTPlayerSpeed", "Prone_SlowSpeed", function(ply)
		if ply:IsProne() then
			return prone.ProneSpeed/220	-- 220 is the default run speed in TTT
		end
	end)
end