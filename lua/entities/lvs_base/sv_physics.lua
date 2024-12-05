
function ENT:GetWorldGravity()
	local PhysObj = self:GetPhysicsObject()

	if not IsValid( PhysObj ) or not PhysObj:IsGravityEnabled() then return 0 end

	return physenv.GetGravity():Length()
end

function ENT:GetWorldUp()
	local Gravity = physenv.GetGravity()

	if Gravity:Length() > 0 then
		return -Gravity:GetNormalized()
	else
		return Vector(0,0,1)
	end
end

function ENT:PhysicsSimulate( phys, deltatime )
end

function ENT:PhysicsStopScape()
	if self._lvsScrapeData then
		if self._lvsScrapeData.sound then
			self._lvsScrapeData.sound:Stop()
		end
	end

	self._lvsScrapeData = nil
end

function ENT:PhysicsStartScrape( pos, dir )
	local startpos = self:LocalToWorld( pos )

	local trace = util.TraceLine( {
		start = startpos - dir * 5,
		endpos = startpos + dir * 5,
		filter = self:GetCrosshairFilterEnts()
	} )

	if trace.Hit then
		local sound

		if self._lvsScrapeData and self._lvsScrapeData.sound then
			sound = self._lvsScrapeData.sound
		else
			sound = CreateSound( self, "LVS.Physics.Scrape" )
			sound:PlayEx( 0, 90 + math.min( (self:GetVelocity():Length() / 2000) * 10,10) )
		end

		self._lvsScrapeData = {
			dir = dir,
			pos = pos,
			sound = sound,
		}

		self:CallOnRemove( "stop_scraping", function( self )
			self:PhysicsStopScape()
		end)
	end
end

function ENT:PhysicsThink()
	if not self._lvsScrapeData then return end

	local startpos = self:LocalToWorld( self._lvsScrapeData.pos )

	local trace = util.TraceLine( {
		start = startpos - self._lvsScrapeData.dir,
		endpos = startpos + self._lvsScrapeData.dir * 5,
		filter = self:GetCrosshairFilterEnts()
	} )

	local Vel = self:GetVelocity():Length()

	if trace.Hit and Vel > 25 then
		local vol = math.min(math.max(Vel - 50,0) / 1000,1)

		local effectdata = EffectData()
		effectdata:SetOrigin( trace.HitPos + trace.HitNormal )
		effectdata:SetNormal( trace.HitNormal )
		effectdata:SetMagnitude( vol )
		util.Effect( "lvs_physics_scrape", effectdata, true, true )

		self._lvsScrapeData.sound:ChangeVolume( vol, 0.1 )
	else
		self:PhysicsStopScape()
	end
end

function ENT:TakeCollisionDamage( damage, attacker )
	if not IsValid( attacker ) then
		attacker = game.GetWorld()
	end

	local dmginfo = DamageInfo()
	dmginfo:SetDamage( damage / 100)
	dmginfo:SetAttacker( attacker )
	dmginfo:SetInflictor( attacker )
	dmginfo:SetDamageType( DMG_CRUSH + DMG_VEHICLE ) -- this will communicate to the damage system to handle this kind of damage differently.
	self:TakeDamageInfo( dmginfo )
end

function ENT:OnCollision( data, physobj )
	return false
end

function ENT:OnSkyCollide( data, physobj )
	return true
end

function ENT:PhysicsCollide( data, physobj )
	local HitEnt = data.HitEntity

	if not IsValid( HitEnt ) and util.GetSurfacePropName( data.TheirSurfaceProps ) == "default_silent" then
		if self:OnSkyCollide( data, physobj ) then return end
	end

	if self:IsDestroyed() then
		self.MarkForDestruction = true
	end

	if self:OnCollision( data, physobj ) then return end

	self:PhysicsStartScrape( self:WorldToLocal( data.HitPos ), data.HitNormal )

	if IsValid( HitEnt ) then
		if HitEnt:IsPlayer() or HitEnt:IsNPC() then
			return
		end
	end

	if self:GetAI() and not self:IsPlayerHolding() then
		if self:WaterLevel() >= self.WaterLevelDestroyAI then
			self:SetDestroyed( true )
			self.MarkForDestruction = true

			return
		end

		self:TakeCollisionDamage( data.OurOldVelocity:Length() - data.OurNewVelocity:Length(), HitEnt )

		return
	end

	if data.Speed > 60 and data.DeltaTime > 0.2 then
		local VelDif = data.OurOldVelocity:Length() - data.OurNewVelocity:Length()

		self:CalcPDS( data )

		local effectdata = EffectData()
		effectdata:SetOrigin( data.HitPos )
		util.Effect( "lvs_physics_impact", effectdata, true, true )

		if VelDif > 300 then
			self:EmitSound( "lvs/physics/impact_hard.wav", 75, 95 + math.min(VelDif / 1000,1) * 10, math.min(VelDif / 800,1) )

			if not self:IsPlayerHolding() then
				self:TakeCollisionDamage( VelDif, HitEnt )
			end
		else
			self:EmitSound( "lvs/physics/impact_soft"..math.random(1,5)..".wav", 75, 100, math.min(0.1 + VelDif / 700,1) )
		end
	end

	self:TakeCustomBomb(data, physobj)

	if data.Speed > 10 and data.DeltaTime > 0.2 and data.HitEntity:GetClass() == "ent_jack_gmod_ezfuel" then
		local fuel = data.HitEntity
		local FuelTank = self:GetFuelTank()

		if self:GetVehicleType() == "LBaseTrailer" then return end
		if FuelTank:GetSize() == FuelTank:GetFuel() then return end

		local NeedFuel = FuelTank:GetSize() - FuelTank:GetFuel()
		--local Accepted = fuel:GetResource() - NeedFuel

		if NeedFuel < 200 then
			fuel:SetResource(fuel:GetResource() - NeedFuel)

			if fuel:GetResource() <= 0 then
				timer.Simple(0.1, function()
					SafeRemoveEntity(fuel)
				end)
			end

			FuelTank:SetFuel(FuelTank:GetFuel() + NeedFuel)
		else
			FuelTank:SetFuel(FuelTank:GetFuel() + fuel:GetResource())
			SafeRemoveEntity(fuel)
		end

		--fuel:SetResource(fuel:GetResource() - )
		JMod.ResourceEffect(fuel.EZsupplies, fuel:LocalToWorld(fuel:OBBCenter()), self:LocalToWorld(self:OBBCenter()), fuel:GetResource(), 1, 1, 1)
		self:OnRefueled()
	end

	if data.Speed > 10 and data.DeltaTime > 0.2 and data.HitEntity:GetClass() == "ent_jack_gmod_ezmunitions" then
		local ammobox = data.HitEntity
		local AmmoIsSet = false

		for PodID, data in pairs( self.WEAPONS ) do
			for id, weapon in pairs( data ) do
				local MaxAmmo = weapon.Ammo or -1
				local CurAmmo = weapon._CurAmmo or MaxAmmo

				if MaxAmmo >= 100 then continue end

				local NeedAmmo = (MaxAmmo - CurAmmo) * 20

				print(NeedAmmo, CurAmmo)
				if CurAmmo == MaxAmmo then continue end
				if CurAmmo == -1 then continue end

				if NeedAmmo < 200 then
					ammobox:SetResource(ammobox:GetResource() - NeedAmmo)

					if ammobox:GetResource() <= 0 then
						timer.Simple(0.1, function()
							SafeRemoveEntity(ammobox)
						end)
					end

					self.WEAPONS[PodID][ id ]._CurAmmo = math.min( CurAmmo + NeedAmmo, MaxAmmo )
					AmmoIsSet = true
				else
					self.WEAPONS[PodID][ id ]._CurAmmo = math.min( CurAmmo + ammobox:GetResource() / 20, MaxAmmo )
					SafeRemoveEntity(ammobox)
					AmmoIsSet = true
				end
			end
		end

		if AmmoIsSet then
			self:SetNWAmmo( self:GetAmmo() )

			for _, pod in pairs( self:GetPassengerSeats() ) do
				local weapon = pod:lvsGetWeapon()

				if not IsValid( weapon ) then continue end

				weapon:SetNWAmmo( weapon:GetAmmo() )
			end

			JMod.ResourceEffect(ammobox.EZsupplies, ammobox:LocalToWorld(ammobox:OBBCenter()), self:LocalToWorld(self:OBBCenter()), ammobox:GetResource(), 1, 1, 1)
			self:OnRefueled()
		end
	end

	if data.Speed > 10 and data.DeltaTime > 0.2 and data.HitEntity:GetClass() == "ent_jack_gmod_ezammo" then
		local ammobox = data.HitEntity
		local AmmoIsSet = false

		for PodID, data in pairs( self.WEAPONS ) do
			for id, weapon in pairs( data ) do
				local MaxAmmo = weapon.Ammo or -1
				local CurAmmo = weapon._CurAmmo or MaxAmmo

				if MaxAmmo <= 100 then continue end

				local NeedAmmo = (MaxAmmo - CurAmmo) / 2

				print(NeedAmmo, CurAmmo)
				if CurAmmo == MaxAmmo then continue end
				if CurAmmo == -1 then continue end

				if NeedAmmo < 200 then
					ammobox:SetResource(ammobox:GetResource() - NeedAmmo)

					if ammobox:GetResource() <= 0 then
						timer.Simple(0.1, function()
							SafeRemoveEntity(ammobox)
						end)
					end

					self.WEAPONS[PodID][ id ]._CurAmmo = math.min( CurAmmo + (MaxAmmo - CurAmmo), MaxAmmo )
					AmmoIsSet = true
				else
					self.WEAPONS[PodID][ id ]._CurAmmo = math.min( CurAmmo + ammobox:GetResource(), MaxAmmo )
					SafeRemoveEntity(ammobox)
					AmmoIsSet = true
				end
			end
		end

		if AmmoIsSet then
			self:SetNWAmmo( self:GetAmmo() )

			for _, pod in pairs( self:GetPassengerSeats() ) do
				local weapon = pod:lvsGetWeapon()

				if not IsValid( weapon ) then continue end

				weapon:SetNWAmmo( weapon:GetAmmo() )
			end

			JMod.ResourceEffect(ammobox.EZsupplies, ammobox:LocalToWorld(ammobox:OBBCenter()), self:LocalToWorld(self:OBBCenter()), ammobox:GetResource(), 1, 1, 1)
			self:OnRefueled()
		end
	end
end

function ENT:TakeCustomBomb(data, physobj)
	local ent = data.HitEntity
	local Ammo = self:GetAmmo()
	local MaxAmmo = self:GetMaxAmmo() 

	local RefilBlackList = {
		["lvs_trailer_schneider"] = true,
		["lvs_wheeldrive_pz1bison"] = true,
	}

	if not RefilBlackList[self:GetClass()] then return end
	
	if ( data.Speed > 50 ) 
	and self.AmmoWhiteList[ent:GetClass()] and Ammo < MaxAmmo then  

		for PodID, data in pairs( self.WEAPONS ) do
			for id, weapon in pairs( data ) do
				local MaxAmmo = weapon.Ammo or -1
				local CurAmmo = weapon._CurAmmo or MaxAmmo
	
				if CurAmmo == MaxAmmo then continue end
	
				self.WEAPONS[PodID][ id ]._CurAmmo = math.min( CurAmmo + 1, MaxAmmo )
	
				AmmoIsSet = true
			end
		end
	
		if AmmoIsSet then
			self:SetNWAmmo( self:GetAmmo() )
	
			for _, pod in pairs( self:GetPassengerSeats() ) do
				local weapon = pod:lvsGetWeapon()
	
				if not IsValid( weapon ) then continue end
	
				weapon:SetNWAmmo( weapon:GetAmmo() )
			end
		end

		self:EmitSound("items/ammo_pickup.wav")

		table.insert(self.AmmoTable, ent:GetClass())

		PrintTable(self.AmmoTable)

		ent:Remove()
	end
end