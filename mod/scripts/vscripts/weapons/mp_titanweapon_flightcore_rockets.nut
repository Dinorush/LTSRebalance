global function OnWeaponPrimaryAttack_titanweapon_flightcore_rockets

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_flightcore_rockets
#endif

var function OnWeaponPrimaryAttack_titanweapon_flightcore_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	bool shouldPredict = weapon.ShouldPredictProjectiles()
	#if CLIENT
	if ( !shouldPredict )
		return 1
	#endif

	// Get missile firing information
	entity owner = weapon.GetWeaponOwner()
	vector offset
	int altFireIndex = weapon.GetCurrentAltFireIndex()
	float horizontalMultiplier
	if ( LTSRebalance_Enabled() )
	{
		if ( altFireIndex == 1 )
			horizontalMultiplier = RandomFloatRange( 0.3, 0.4 )
		else
			horizontalMultiplier = RandomFloatRange( -0.4, -0.3 )
	}
	else
	{
		if ( altFireIndex == 1 )
			horizontalMultiplier = RandomFloatRange( 0.25, 0.45 )
		else
			horizontalMultiplier = RandomFloatRange( -0.45, -0.25 )
	}

	if ( owner.IsPlayer() )
		offset = AnglesToRight( owner.CameraAngles() ) * horizontalMultiplier
	#if SERVER
	else
		offset = owner.GetPlayerOrNPCViewRight() * horizontalMultiplier
	#endif

	vector attackDir = attackParams.dir + offset + <0,0,RandomFloatRange(-0.25,0.55)>
	if( LTSRebalance_Enabled() )
		attackDir = attackParams.dir + offset + <0,0,RandomFloatRange(-0.25,0.35)>
	vector attackPos = attackParams.pos + offset*32
	attackDir = Normalize( attackDir )
	entity missile = weapon.FireWeaponMissile( attackPos, attackDir, 1, (damageTypes.projectileImpact | DF_DOOM_FATALITY), damageTypes.explosive, false, shouldPredict )

	if ( missile )
	{
		TraceResults result = TraceLine( owner.EyePosition(), owner.EyePosition() + attackParams.dir*50000, [ owner ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_BLOCK_WEAPONS )
		vector endPos = result.endPos
        if ( LTSRebalance_Enabled() )
		{
			// In LTS Rebalance, rockets aim ahead of the enemy based on their velocity.
			// Trace again, with a different collision group - specifically, locating the titan the player is looking at.
			TraceResults hitResult = TraceLine( owner.EyePosition(), owner.EyePosition() + attackParams.dir*50000, [ owner ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
			entity hitEnt = hitResult.hitEnt

			// TODO: May want to check if the target entity is a Vortex Shield/Gun Shield. Don't know if they share the velocity of their owner; needs testing.

			// Check that the target is a living titan.
			if (IsAlive(hitEnt) && hitEnt.GetArmorType() == ARMOR_TYPE_HEAVY)
			{
				endPos = hitResult.endPos
				float dist = Distance(owner.GetOrigin(), hitEnt.GetOrigin())
				vector flat_vel = hitEnt.GetVelocity()
				flat_vel.z = min(flat_vel.z, 0)

				// Auto-targeting only compensates up to 400 dist. For instance, a sprinting Stryder would be compensated up to 70m away. 
				float compensate = min(dist/Length(missile.GetVelocity()) * Length(flat_vel), 400)
				endPos += Normalize(flat_vel)*compensate
			}
		}
        missile.kv.lifetime = 10
		missile.InitMissileForRandomDriftFromWeaponSettings( attackPos, attackDir )
		thread DelayedTrackingStart( missile, endPos )
	#if SERVER
		missile.SetOwner( owner )
		EmitSoundAtPosition( owner.GetTeam(), endPos, "Weapon_FlightCore_Incoming_Projectile" )

		thread MissileThink( missile )
	#endif // SERVER
	}
	return 1
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_flightcore_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_flightcore_rockets( weapon, attackParams )
}

void function MissileThink( entity missile )
{
	missile.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( missile )
		{
			if ( IsValid( missile ) )
				missile.Destroy()
		}
	)

	float life = float( missile.kv.lifetime )

	wait life
}
#endif // SERVER

void function DelayedTrackingStart( entity missile, vector targetPos )
{
	missile.EndSignal( "OnDestroy" )
	wait ( LTSRebalance_Enabled() ? 0.05 : 0.1 )
	missile.SetHomingSpeeds( 2000, 0 )
	missile.SetMissileTargetPosition( targetPos )
}