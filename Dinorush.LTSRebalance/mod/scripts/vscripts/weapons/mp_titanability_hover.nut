global function MpTitanAbilityHover_Init
global function OnWeaponPrimaryAttack_TitanHover
const LERP_IN_FLOAT = 0.5

#if SERVER
global function NPC_OnWeaponPrimaryAttack_TitanHover
global function FlyerHovers
#endif

void function MpTitanAbilityHover_Init()
{
	PrecacheParticleSystem( $"P_xo_jet_fly_large" )
	PrecacheParticleSystem( $"P_xo_jet_fly_small" )

	RegisterSignal( "VTOLHoverBegin" )
}

var function OnWeaponPrimaryAttack_TitanHover( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity flyer = weapon.GetWeaponOwner()
	if ( !IsAlive( flyer ) )
		return

	if ( flyer.IsPlayer() )
		PlayerUsedOffhand( flyer, weapon )

	#if SERVER
		HoverSounds soundInfo
		soundInfo.liftoff_1p = "titan_flight_liftoff_1p"
		soundInfo.liftoff_3p = "titan_flight_liftoff_3p"
		soundInfo.hover_1p = "titan_flight_hover_1p"
		soundInfo.hover_3p = "titan_flight_hover_3p"
		soundInfo.descent_1p = "titan_flight_descent_1p"
		soundInfo.descent_3p = "titan_flight_descent_3p"
		soundInfo.landing_1p = "core_ability_land_1p"
		soundInfo.landing_3p = "core_ability_land_3p"
		float horizontalVelocity
		entity soul = flyer.GetTitanSoul()
		if ( LTSRebalance_Enabled() || ( IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_NORTHSTAR_FLIGHTCORE ) ) )
			horizontalVelocity = 350.0
		else
			horizontalVelocity = 250.0

		thread FlyerHovers( flyer, soundInfo, 3.0, horizontalVelocity )
	#endif

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

#if SERVER

var function NPC_OnWeaponPrimaryAttack_TitanHover( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_TitanHover( weapon, attackParams )
}

void function FlyerHovers( entity player, HoverSounds soundInfo, float flightTime = 3.0, float horizVel = 350.0 )
{
    float RISE_VEL = 450
    // HACK: use friction and velocity to detect if the user was in hover and rising
    // Going to use this to make limiting Core height feasible, while fixing jammed thrusters
    bool stallHover = LTSRebalance_Enabled() && player.GetGroundFrictionScale() == 0 && player.GetVelocity().z >= RISE_VEL * 0.5
    player.Signal( "VTOLHoverBegin" )
    
	player.EndSignal( "OnDeath" )
	player.EndSignal( "TitanEjectionStarted" )
	if ( LTSRebalance_Enabled() )
    	player.EndSignal( "VTOLHoverBegin" )
    
    entity soul = player.GetTitanSoul()
	
	thread AirborneThink( player, soundInfo )
	if ( player.IsPlayer() )
	{
        if ( !LTSRebalance_Enabled() || !IsValid( soul ) || !SoulHasPassive( soul, ePassives.PAS_NORTHSTAR_FLIGHTCORE ) )
		    player.Server_TurnDodgeDisabledOn()
	    player.kv.airSpeed = horizVel
	    player.kv.airAcceleration = LTSRebalance_Enabled() ? 600 : 540
	    player.kv.gravity = 0.0
	}

	bool perfectViper = PerfectKits_Enabled() && IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_NORTHSTAR_FLIGHTCORE )

	if ( soul == null )
		soul = player

	CreateShake( player.GetOrigin(), 16, 150, 1.00, 400 )
	PlayFX( FLIGHT_CORE_IMPACT_FX, player.GetOrigin() )

	float startTime = Time()

	array<entity> activeFX

	player.SetGroundFrictionScale( 0 )

	OnThreadEnd(
		function() : ( activeFX, player, soundInfo, soul )
		{
			if ( IsValid( player ) )
			{
				StopSoundOnEntity( player, soundInfo.hover_1p )
				StopSoundOnEntity( player, soundInfo.hover_3p )
				player.SetGroundFrictionScale( 1 )
				if ( player.IsPlayer() )
				{
					if ( LTSRebalance_Enabled() )
					{
						float fadeTime = 0.75
						StatusEffect_AddTimed( soul, eStatusEffect.dodge_speed_slow, 0.5, fadeTime, fadeTime )
					}
					player.Server_TurnDodgeDisabledOff()
					player.kv.airSpeed = player.GetPlayerSettingsField( "airSpeed" )
					player.kv.airAcceleration = player.GetPlayerSettingsField( "airAcceleration" )
					player.kv.gravity = player.GetPlayerSettingsField( "gravityScale" )
					if ( player.IsOnGround() )
					{
						EmitSoundOnEntityOnlyToPlayer( player, player, soundInfo.landing_1p )
						EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.landing_3p )
					}
				}
				else
				{
					if ( player.IsOnGround() )
						EmitSoundOnEntity( player, soundInfo.landing_3p )
				}
			}

			foreach ( fx in activeFX )
			{
				if ( IsValid( fx ) )
					fx.Destroy()
			}
		}
	)

	if ( player.LookupAttachment( "FX_L_BOT_THRUST" ) != 0 ) // BT doesn't have this attachment
	{
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_large" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "FX_L_BOT_THRUST" ) ) )
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_large" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "FX_R_BOT_THRUST" ) ) )
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_small" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "FX_L_TOP_THRUST" ) ) )
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_small" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "FX_R_TOP_THRUST" ) ) )
	}

	EmitSoundOnEntityOnlyToPlayer( player, player,  soundInfo.liftoff_1p )
	EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.liftoff_3p )
	EmitSoundOnEntityOnlyToPlayer( player, player,  soundInfo.hover_1p )
	EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.hover_3p )

	float movestunEffect = 1.0 - StatusEffect_Get( player, eStatusEffect.dodge_speed_slow )

	if ( !LTSRebalance_Enabled() )
	{
		float fadeTime = 0.75
		StatusEffect_AddTimed( soul, eStatusEffect.dodge_speed_slow, 0.65, flightTime + fadeTime, fadeTime )
	}

	vector startOrigin = player.GetOrigin()
	for ( ;; )
	{
		float timePassed = Time() - startTime
		if ( timePassed > flightTime )
			break

		float height
        if ( stallHover )
            height = 70
		else if ( perfectViper )
			height = RISE_VEL
        else
        {
            if ( timePassed < LERP_IN_FLOAT )
                height = GraphCapped( timePassed, 0, LERP_IN_FLOAT, RISE_VEL * 0.5, RISE_VEL )
            else
                height = GraphCapped( timePassed, LERP_IN_FLOAT, LERP_IN_FLOAT + 0.75, RISE_VEL, 70 )
        }

		height *= movestunEffect

		vector vel = player.GetVelocity()
		vel.z = height
		vel = LimitVelocityHorizontal( vel, horizVel + 50 )
		player.SetVelocity( vel )
		WaitFrame()
	}

    // One last check, since player could dash with Viper Thrusters in last 0.1s of loop
    vector vel = player.GetVelocity()
    vel = LimitVelocityHorizontal( vel, horizVel + 50 )
    player.SetVelocity( vel )

	vector endOrigin = player.GetOrigin()

	// printt( endOrigin - startOrigin )
	EmitSoundOnEntityOnlyToPlayer( player, player, soundInfo.descent_1p )
	EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.descent_3p )
}

void function AirborneThink( entity player, HoverSounds soundInfo )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "TitanEjectionStarted" )
	player.EndSignal( "DisembarkingTitan" )

	if ( player.IsPlayer() )
		player.SetTitanDisembarkEnabled( false )

	OnThreadEnd(
	function() : ( player )
		{
			if ( IsValid( player ) && player.IsPlayer() )
				player.SetTitanDisembarkEnabled( true )
		}
	)
	wait 0.1

	while( !player.IsOnGround() )
	{
		wait 0.1
	}

	if ( player.IsPlayer() )
	{
		EmitSoundOnEntityOnlyToPlayer( player, player, soundInfo.landing_1p )
		EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.landing_3p )
	}
	else
	{
		EmitSoundOnEntity( player, soundInfo.landing_3p )
	}
}

vector function LimitVelocityHorizontal( vector vel, float speed )
{
	vector horzVel = <vel.x, vel.y, 0>
	if ( Length( horzVel ) <= speed )
		return vel

	horzVel = Normalize( horzVel )
	horzVel *= speed
	vel.x = horzVel.x
	vel.y = horzVel.y
	return vel
}
#endif // SERVER
