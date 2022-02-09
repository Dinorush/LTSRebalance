untyped

global function MpTitanWeaponpredatorcannon_Init
global function OnWeaponActivate_titanweapon_predator_cannon
global function OnWeaponDeactivate_titanweapon_predator_cannon
global function OnWeaponPrimaryAttack_titanweapon_predator_cannon
global function OnWeaponStartZoomIn_titanweapon_predator_cannon
global function OnWeaponStartZoomOut_titanweapon_predator_cannon
global function OnWeaponOwnerChanged_titanweapon_predator_cannon
global function OnWeaponChargeBegin_titanweapon_predator_cannon
global function IsPredatorCannonActive

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_predator_cannon
global function OnWeaponNpcPreAttack_titanweapon_predator_cannon
#endif

const SPIN_EFFECT_1P = $"P_predator_barrel_blur_FP"
const SPIN_EFFECT_3P = $"P_predator_barrel_blur"

const float PAS_LEGION_SMARTCORE_MAX_MOD = 0.5 // added to 1
const float PAS_LEGION_SMARTCORE_MAX_TIME = 3.0

void function MpTitanWeaponpredatorcannon_Init()
{
	PrecacheParticleSystem( SPIN_EFFECT_1P )
	PrecacheParticleSystem( SPIN_EFFECT_3P )
	#if SERVER
	//if ( GetCurrentPlaylistVarInt( "aegis_upgrades", 0 ) == 1 )
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_predator_cannon, PredatorCannon_DamagedTarget )
	#endif
}

void function OnWeaponStartZoomIn_titanweapon_predator_cannon( entity weapon )
{
	StopSoundOnEntity( weapon, "weapon_predator_winddown_1p" )
	StopSoundOnEntity( weapon, "weapon_predator_winddown_3p" )
	weapon.EmitWeaponSound_1p3p( "Weapon_Predator_MotorLoop_1P", "Weapon_Predator_MotorLoop_3P" )
	weapon.PlayWeaponEffect( SPIN_EFFECT_1P, SPIN_EFFECT_3P, "fx_barrel" )
	entity weaponOwner = weapon.GetWeaponOwner()
	float zoomFrac = weaponOwner.GetZoomFrac()
	float zoomTimeIn = weapon.GetWeaponSettingFloat( eWeaponVar.zoom_time_in )

	#if SERVER
		EmitSoundOnEntityExceptToPlayerWithSeek( weapon, weaponOwner, "weapon_predator_windup_3p", zoomFrac * zoomTimeIn )
	#endif
	#if CLIENT
		StopSoundOnEntity( weaponOwner, "wpn_predator_cannon_ads_out_mech_fr00_1p" )
		float soundDuration = GetSoundDuration( "wpn_predator_cannon_ads_in_mech_fr00_1p" )
		EmitSoundOnEntityWithSeek( weaponOwner, "wpn_predator_cannon_ads_in_mech_fr00_1p", zoomFrac * soundDuration )
		EmitSoundOnEntityWithSeek( weapon, "weapon_predator_windup_1p", zoomFrac * zoomTimeIn )
	#endif
}

void function OnWeaponStartZoomOut_titanweapon_predator_cannon( entity weapon )
{
	StopSpinSounds( weapon )
	entity weaponOwner = weapon.GetWeaponOwner()
	float zoomFrac = weaponOwner.GetZoomFrac()
	float zoomOutTime = weapon.GetWeaponSettingFloat( eWeaponVar.zoom_time_out )

	#if SERVER
		EmitSoundOnEntityExceptToPlayerWithSeek( weapon, weaponOwner, "weapon_predator_winddown_3P", ( 1 - zoomFrac ) * zoomOutTime )
	#endif
	#if CLIENT
		if ( !IsValid( weaponOwner ) )
			return
		float soundDuration = GetSoundDuration( "wpn_predator_cannon_ads_out_mech_fr00_1p" )
		EmitSoundOnEntityWithSeek( weaponOwner, "wpn_predator_cannon_ads_out_mech_fr00_1p", ( 1 - zoomFrac ) * soundDuration )
		EmitSoundOnEntityWithSeek( weapon, "weapon_predator_winddown_1p", ( 1 - zoomFrac ) * zoomOutTime )
	#endif
}

void function OnWeaponOwnerChanged_titanweapon_predator_cannon( entity weapon, WeaponOwnerChangedParams changeParams )
{
	StopSpinSounds( weapon )
}

void function StopSpinSounds( entity weapon )
{
		weapon.StopWeaponSound( "Weapon_Predator_MotorLoop_1P" )
		weapon.StopWeaponSound( "Weapon_Predator_MotorLoop_3P" )
		StopSoundOnEntity( weapon, "weapon_predator_windup_1p" )
		StopSoundOnEntity( weapon, "weapon_predator_windup_3p" )
		weapon.StopWeaponEffect( SPIN_EFFECT_1P, SPIN_EFFECT_3P )
		#if CLIENT
			entity weaponOwner = weapon.GetWeaponOwner()
			if ( !IsValid( weaponOwner ) )
				return
			StopSoundOnEntity( weaponOwner, "wpn_predator_cannon_ads_out_mech_fr00_1p" )
			StopSoundOnEntity( weaponOwner, "wpn_predator_cannon_ads_in_mech_fr00_1p" )
		#endif
}

void function OnWeaponActivate_titanweapon_predator_cannon( entity weapon )
{
	StopSpinSounds( weapon )
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.damageValue <- weapon.GetWeaponInfoFileKeyField( "damage_near_value" )
		SmartAmmo_SetAllowUnlockedFiring( weapon, true )
		SmartAmmo_SetUnlockAfterBurst( weapon, false )
		SmartAmmo_SetWarningIndicatorDelay( weapon, 9999.0 )

		weapon.s.initialized <- true
		#if SERVER
			weapon.s.lockStartTime <- Time()
			weapon.s.locking <- true
			weapon.s.smartArrayTargets <- {}
		#endif
	}

	#if SERVER
	weapon.s.locking = true
	weapon.s.lockStartTime = Time()
	if ( LTSRebalance_Enabled() )
	{
		entity core = weapon.GetOwner().GetOffhandWeapon( OFFHAND_EQUIPMENT )
		if( IsValid( core ) && core.HasMod( "pas_legion_smartcore" ) )
			thread TrackSmartArrayMultiplier( weapon )
	}
	#endif
}

void function TrackSmartArrayMultiplier( entity weapon )
{
    entity player = weapon.GetOwner()
    player.EndSignal( "DisembarkingTitan" )
	player.EndSignal( "TitanEjectionStarted" )
    player.EndSignal( "OnDeath" )
    weapon.EndSignal( "WeaponDeactivateEvent" )

	OnThreadEnd(
		function() : ( weapon )
		{
			if ( IsValid( weapon ) )
				weapon.s.smartArrayTargets.clear()
		}
	)

    while( 1 )
    {
        if( !weapon.SmartAmmo_IsEnabled() )
        {
			if( weapon.s.smartArrayTargets.len() > 0 )
				weapon.s.smartArrayTargets.clear()
            WaitFrame()
            continue
        }

        array<entity> trackedList = SmartAmmo_GetWeaponTargets( weapon )
        array<entity> untrackedList = []

        foreach( key, value in weapon.s.smartArrayTargets )
		{
			entity eKey = expect entity( key )
            if ( !trackedList.contains( eKey ) )
                untrackedList.append( eKey )
		}

        foreach( ent in untrackedList )
            delete weapon.s.smartArrayTargets[ent]

        foreach( ent in trackedList )
            if ( !( ent in weapon.s.smartArrayTargets ) )
                weapon.s.smartArrayTargets[ent] <- Time()

        WaitFrame()
    }
}

void function OnWeaponDeactivate_titanweapon_predator_cannon( entity weapon )
{
	if ( LTSRebalance_Enabled() )
   		weapon.Signal( "WeaponDeactivateEvent" )
	StopSpinSounds( weapon )
}

bool function OnWeaponChargeBegin_titanweapon_predator_cannon ( entity weapon )
{
	if( !LTSRebalance_Enabled() )
		return true

    entity owner = weapon.GetWeaponOwner()
	var needsZoom = weapon.GetWeaponInfoFileKeyField( "attack_button_presses_ads" )

	if ( owner.IsPlayer() && needsZoom )
	{
		float zoomFrac = owner.GetZoomFrac()
		if ( zoomFrac < 1 )
			return false
	}

    return true
}

var function OnWeaponPrimaryAttack_titanweapon_predator_cannon( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	var needsZoom = weapon.GetWeaponInfoFileKeyField( "attack_button_presses_ads" )

	if ( owner.IsPlayer() && needsZoom )
	{
		float zoomFrac = owner.GetZoomFrac()
		if ( zoomFrac < 1 )
			return 0
	}

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	bool hasLongRangePowerShot = weapon.HasMod( "LongRangePowerShot" )
	bool hasCloseRangePowerShot = weapon.HasMod( "CloseRangePowerShot" )
	if ( hasLongRangePowerShot || hasCloseRangePowerShot )
	{
#if SERVER
		if ( owner.IsPlayer() && IsMultiplayer() )
		{
			owner.Anim_PlayGesture( "ACT_SCRIPT_CUSTOM_ATTACK2", 0.2, 0.2, -1.0 )
		}
		else if ( owner.IsNPC() )
		{
			string anim = "ACT_RANGE_ATTACK1_SINGLE"
			if ( owner.IsCrouching() )
				anim = "ACT_RANGE_ATTACK1_LOW_SINGLE"
			owner.Anim_ScriptedPlayActivityByName( anim, true, 0.0 )
		}
#endif
		if ( hasCloseRangePowerShot )
		{
			if ( owner.IsPlayer() )
				weapon.EmitWeaponSound_1p3p( "Weapon_Predator_Powershot_ShortRange_1P", "Weapon_Predator_Powershot_ShortRange_3P" )
			else
				EmitSoundAtPosition( TEAM_UNASSIGNED, attackParams.pos, "Weapon_Predator_Powershot_ShortRange_3P" )

			int damageType
			if ( weapon.HasMod( "fd_CloseRangePowerShot" ) )
				damageType = DF_GIB | DF_EXPLOSION | DF_KNOCK_BACK | DF_SKIPS_DOOMED_STATE
			else
				damageType = DF_GIB | DF_EXPLOSION | DF_KNOCK_BACK

			ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 16, damageType, 1.0, 10.0 )

			#if CLIENT
			if( !LTSRebalance_Enabled() )
				PowerShotCleanup( owner, weapon, ["CloseRangePowerShot","fd_CloseRangePowerShot","pas_CloseRangePowerShot"] , [] )
			#else
			PowerShotCleanup( owner, weapon, ["CloseRangePowerShot","fd_CloseRangePowerShot","pas_CloseRangePowerShot"], [] )
			#endif

			return 1
		}
		else
		{
			if ( owner.IsPlayer() )
				weapon.EmitWeaponSound_1p3p( "Weapon_Predator_Powershot_LongRange_1P", "Weapon_Predator_Powershot_LongRange_3P" )
			else
				EmitSoundAtPosition( TEAM_UNASSIGNED, attackParams.pos, "Weapon_Predator_Powershot_LongRange_3P" )

			entity bolt
			#if CLIENT
			if ( weapon.ShouldPredictProjectiles() )
			#endif
			bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, 10000, damageTypes.gibBullet | DF_IMPACT | DF_EXPLOSION , DF_EXPLOSION | DF_RAGDOLL , PROJECTILE_NOT_PREDICTED, 0 )
			if ( bolt )
			{
				bolt.kv.gravity = -0.1
				#if SERVER
				bolt.e.onlyDamageEntitiesOnce = true
				#endif
			}
		}
		
		#if CLIENT
		if( !LTSRebalance_Enabled() )
			PowerShotCleanup( owner, weapon, ["LongRangePowerShot","fd_LongRangePowerShot","pas_LongRangePowerShot"], [ "LongRangeAmmo" ] )
		#else
		PowerShotCleanup( owner, weapon, ["LongRangePowerShot","fd_LongRangePowerShot","pas_LongRangePowerShot"], [ "LongRangeAmmo" ] )
		#endif
		
		return 1
	}
	else
	{
		return FireWeaponPlayerAndNPC( weapon, attackParams, true )
	}
}

#if SERVER
void function OnWeaponNpcPreAttack_titanweapon_predator_cannon( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	thread PredatorSpinup( weaponOwner, weapon )
}

void function PredatorSpinup( entity weaponOwner, entity weapon )
{
	if ( !IsAlive( weaponOwner ) )
		return

	weapon.EndSignal( "OnDestroy" )
	weaponOwner.EndSignal( "OnDeath" )
	weaponOwner.EndSignal( "OnDestroy" )

	EmitSoundOnEntity( weaponOwner, "Weapon_Predator_MotorLoop_3P" )
	EmitSoundOnEntity( weaponOwner, "Weapon_Predator_Windup_3P" )

	float npc_pre_fire_delay = expect float( weapon.GetWeaponInfoFileKeyField( "npc_pre_fire_delay" ) )

	OnThreadEnd(
		function() : ( weapon, weaponOwner )
		{
			if ( IsValid( weaponOwner ) )
			{
				// foreach ( elem in weaponOwner.e.fxArray )
				// {
				// 	if ( IsValid( elem ) )
				// 		elem.Destroy()
				// }
				// weaponOwner.e.fxArray = []

				StopSoundOnEntity( weaponOwner, "Weapon_Predator_Windup_3P" )
				StopSoundOnEntity( weaponOwner, "Weapon_Predator_MotorLoop_3P" )
			}
		}
	)

	wait npc_pre_fire_delay

	// weaponOwner.e.fxArray.append( PlayLoopFXOnEntity( $"P_wpn_lasercannon_aim_short", weaponOwner, "PROPGUN", null, null, ENTITY_VISIBLE_TO_EVERYONE ) )

	float npc_pre_fire_delay_interval = expect float( weapon.GetWeaponInfoFileKeyField( "npc_pre_fire_delay_interval" ) )

	wait npc_pre_fire_delay_interval
}

var function OnWeaponNpcPrimaryAttack_titanweapon_predator_cannon( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_titanweapon_predator_cannon( weapon, attackParams )
}
#endif

int function FireWeaponPlayerAndNPC( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired )
{
	int damageType = DF_BULLET | DF_STOPS_TITAN_REGEN | DF_GIB
    
	if ( weapon.HasMod( "Smart_Core" ) )
	{
        entity owner = weapon.GetOwner()
        if( !LTSRebalance_Enabled() || owner.IsNPC() )
            return SmartAmmo_FireWeapon( weapon, attackParams, damageType, damageTypes.largeCaliber | DF_STOPS_TITAN_REGEN )

        TraceResults result = TraceLine( owner.EyePosition(), owner.EyePosition() + attackParams.dir*10000, [ owner ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
        if( IsValid( result.hitEnt ) && !result.hitEnt.IsWorld() )
        {
            weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, damageType )
            return 1
        }
        else
		    return SmartAmmo_FireWeapon( weapon, attackParams, damageType, damageTypes.largeCaliber | DF_STOPS_TITAN_REGEN )
	}
	else
	{
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, damageType )
		if ( weapon.HasMod( "LongRangeAmmo" ) )
			return 2
		else
			return 1
	}
	unreachable
}

bool function IsPredatorCannonActive( entity owner, bool reqZoom = true )
{
	if ( !owner.IsNPC() )
	{
		if ( reqZoom && owner.GetZoomFrac() != 1.0 )
			return false

		if ( owner.GetViewModelEntity().GetModelName() != $"models/weapons/titan_predator/atpov_titan_predator.mdl" )
			return false

		if ( owner.PlayerMelee_IsAttackActive() )
			return false
	}
	else
	{
		return owner.GetActiveWeapon().GetWeaponClassName() == "mp_titanweapon_predator_cannon" || owner.GetActiveWeapon.GetWeaponClassName() == "mp_titanweapon_predator_cannon_ltsrebalance"
	}

	return true
}

#if SERVER
void function PredatorCannon_DamagedTarget( entity target, var damageInfo )
{
    int flags = DamageInfo_GetCustomDamageType( damageInfo )
	if ( !IsValid( target ) )
		return
	
	if ( LTSRebalance_Enabled() )
	{
		entity attacker = DamageInfo_GetAttacker( damageInfo )
		entity weapon = attacker.GetMainWeapons()[0]

		// Smart array bonus damage for normal shots
		if ( !( flags & DF_KNOCK_BACK || DamageInfo_GetInflictor( damageInfo ).IsProjectile() ) && weapon.s.smartArrayTargets.len() > 0 )
		{
			if ( target in weapon.s.smartArrayTargets )
			{
				float percent = min( 1, ( Time() - weapon.s.smartArrayTargets[ target ] ) / PAS_LEGION_SMARTCORE_MAX_TIME )
				DamageInfo_ScaleDamage( damageInfo, 1 + percent * PAS_LEGION_SMARTCORE_MAX_MOD )
			}
		}

		if ( !target.IsTitan() )
			return
		
		if ( weapon.HasMod( "pas_legion_weapon" ) )
		{
			bool isCritical = IsCriticalHit( attacker, target, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamage( damageInfo ), DamageInfo_GetDamageType( damageInfo ) )
			if( isCritical )
			{
				int newAmmo = int( min ( weapon.GetWeaponPrimaryClipCountMax(), weapon.GetWeaponPrimaryClipCount() + 1 ) )
				weapon.SetWeaponPrimaryClipCount( newAmmo ) 
			}
		}
	}

	if ( !target.IsTitan() )
			return

	if ( !( flags & DF_SKIPS_DOOMED_STATE ) )
		return

	if ( GetDoomedState( target ) )
		DamageInfo_SetDamage( damageInfo, target.GetHealth() + 1 )
}
#endif