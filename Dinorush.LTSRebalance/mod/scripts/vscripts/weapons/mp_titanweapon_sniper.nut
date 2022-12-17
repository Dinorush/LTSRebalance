/* LTS Rebalance replaces this file for the following reasons:
   1. Implement Piercing Rounds changes (LTS Rebalance + Perfect Kits)
   2. Implement Threat Optics changes (LTS Rebalance + Perfect Kits)
   3. Implement Perfect Kits Viper Thrusters (damage buff)
   4. Implement Perfect Kits Enhanced Payload (Railgun nerf)
*/
untyped


global function OnWeaponActivate_titanweapon_sniper
global function OnWeaponPrimaryAttack_titanweapon_sniper
global function OnWeaponChargeLevelIncreased_titanweapon_sniper
global function GetTitanSniperChargeLevel
global function MpTitanWeapon_SniperInit
global function OnWeaponStartZoomIn_titanweapon_sniper
global function OnWeaponStartZoomOut_titanweapon_sniper
global function OnWeaponOwnerChanged_titanweapon_sniper

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_sniper

global function LTSRebalance_ApplyThreatOptics
#endif // #if SERVER

const INSTANT_SHOT_DAMAGE 				= 1200
//const INSTANT_SHOT_MAX_CHARGES		= 2 // can't change this without updating crosshair
//const INSTANT_SHOT_TIME_PER_CHARGE	= 0
const SNIPER_PROJECTILE_SPEED			= 10000

const float PERFECTKITS_VIPER_HEIGHT_MIN = 750
const float PERFECTKITS_VIPER_HEIGHT_CONV = 0.0005

const float LTSREBALANCE_PAS_NORTHSTAR_WEAPON_MOD = 1.25
const float LTSREBALANCE_PAS_NORTHSTAR_WEAPON_DURATION = 6.0

const float LTSREBALANCE_THREAT_OPTICS_SONAR_DURATION = 1.6
global const float LTSREBALANCE_THREAT_OPTICS_TRAP_SONAR_DURATION = 2.4
const asset LTSREBALANCE_THREAT_OPTICS_DEBUFF_P = $"smk_elec_nrg_heal"
const float LTSREBALANCE_THREAT_OPTICS_DEBUFF_DURATION_MOD = 2.5
const float LTSREBALANCE_THREAT_OPTICS_DEBUFF_MOD = 0.10

struct {
	float chargeDownSoundDuration = 1.0 //"charge_cooldown_time"
} file

void function OnWeaponActivate_titanweapon_sniper( entity weapon )
{
	file.chargeDownSoundDuration = expect float( weapon.GetWeaponInfoFileKeyField( "charge_cooldown_time" ) )
}

var function OnWeaponPrimaryAttack_titanweapon_sniper( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireSniper( weapon, attackParams, true )
}

void function MpTitanWeapon_SniperInit()
{
	PrecacheParticleSystem( LTSREBALANCE_THREAT_OPTICS_DEBUFF_P )

	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_sniper, OnHit_TitanWeaponSniper )
	if ( LTSRebalance_EnabledOnInit() )
	{
		RegisterSignal( "PiercingRoundsHit" )
		AddSoulTransferFunc( LTSRebalance_TransferDebuffs )
	}

	if ( PerfectKits_EnabledOnInit() )
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_flightcore_rockets, PerfectKits_ApplyHeightDamage )
	#endif
}
#if SERVER

void function LTSRebalance_TransferDebuffs( entity soul, entity titan, entity oldTitan )
{
	if ( !IsValid( soul ) || !IsValid( titan ) )
		return

	thread LTSRebalance_TransferDebuffsDelayed( soul, titan )
}


void function LTSRebalance_TransferDebuffsDelayed( entity soul, entity titan )
{
	WaitEndFrame()
	if ( !IsValid( soul ) || !IsValid( titan ) )
		return

	if ( "piercingRoundsFXs" in soul.s && soul.s.piercingRoundsFXs.len() > 0 )
	{
		foreach( fx in soul.s.piercingRoundsFXs )
		{
			expect entity( fx )
			if ( IsValid( fx ) )
				EffectStop( fx )
		}
		soul.s.piercingRoundsFXs = LTSRebalance_StartDebuffFX( titan )
	}

	if ( "threatOpticsFXs" in soul.s && soul.s.threatOpticsFXs.len() > 0)
	{
		foreach( fx in soul.s.threatOpticsFXs )
		{
			expect entity( fx )
			if ( IsValid( fx ) )
				EffectStop( fx )
		}
		soul.s.threatOpticsFXs = LTSRebalance_StartDebuffFX( titan )
	}
}

void function OnHit_TitanWeaponSniper( entity victim, var damageInfo )
{
	OnHit_TitanWeaponSniper_Internal( victim, damageInfo )
}

void function OnHit_TitanWeaponSniper_Internal( entity victim, var damageInfo )
{
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if ( !IsValid( inflictor ) )
		return
	if ( !inflictor.IsProjectile() )
		return
	int extraDamage = int( CalculateTitanSniperExtraDamage( inflictor, victim ) )
	float damage = DamageInfo_GetDamage( damageInfo )

	float f_extraDamage = float( extraDamage )
	f_extraDamage *= 1.0 + StatusEffect_Get( victim, eStatusEffect.damage_received_multiplier )

	entity owner = inflictor.GetOwner()
	if ( IsValid( owner ) && f_extraDamage > 0 )
	{
		entity dumbfire = owner.GetOffhandWeapon( OFFHAND_RIGHT )
		if ( IsValid( dumbfire ) && dumbfire.HasMod( "PerfectKits_pas_northstar_cluster" ) )
		{
			f_extraDamage /= 2.0
			damage += float( victim.IsTitan() ? inflictor.s.extraDamagePerBullet_Titan : inflictor.s.extraDamagePerBullet ) / 2.0
		}
	}

	bool isCritical = IsCriticalHit( DamageInfo_GetAttacker( damageInfo ), victim, DamageInfo_GetHitBox( damageInfo ), damage, DamageInfo_GetDamageType( damageInfo ) )
    array<string> projectileMods = inflictor.ProjectileGetMods()

	if ( isCritical )
	{
		float critMod = expect float( inflictor.ProjectileGetWeaponInfoFileKeyField( "critical_hit_damage_scale" ) )
		if ( projectileMods.contains( "fd_upgrade_crit" ) )
			critMod = 2.0
		if ( projectileMods.contains( "PerfectKits_pas_northstar_optics" ) )
			critMod += 2.5
		f_extraDamage *= critMod
	}

	//Check to see if damage has been see to zero so we don't override it.
	if ( damage > 0 && extraDamage > 0 )
	{
		damage += f_extraDamage
		DamageInfo_SetDamage( damageInfo, damage )
	}

	float nearRange = LTSRebalance_Enabled() ? 1250.0 : 1000.0
	float farRange = LTSRebalance_Enabled() ? 2000.0 : 1500.0
	float nearScale = 0.5
	float farScale = 0

	bool perfectPush = false
	if ( damage > 0 && PerfectKits_Enabled() && projectileMods.contains( "pas_northstar_weapon" ) )
	{
		damage = 900.0
		nearScale = 0
		if ( "bulletsToFire" in inflictor.s && inflictor.s.bulletsToFire > 1 )
		{
			damage = 10.0
			if ( expect int( inflictor.s.bulletsToFire ) == 6 )
			{
				perfectPush = true
			}
		}

		DamageInfo_SetDamage( damageInfo, damage )
	}

	PerfectKits_ApplyHeightDamage( victim, damageInfo )

	if ( victim.IsTitan() )
    {
		if ( LTSRebalance_Enabled() && projectileMods.contains( "pas_northstar_weapon" ) )
		{
			entity soul = victim.GetTitanSoul()
			if ( "piercingRoundsEndTime" in soul.s && soul.s.piercingRoundsEndTime > Time() )
			{
				soul.s.piercingRoundsEndTime = 0.0
				soul.Signal( "PiercingRoundsHit" )
				DamageInfo_ScaleDamage( damageInfo, LTSREBALANCE_PAS_NORTHSTAR_WEAPON_MOD )
			}

			if ( "bulletsToFire" in inflictor.s && expect int( inflictor.s.bulletsToFire ) == 6 )
			{
				soul.s.piercingRoundsEndTime <- Time() + LTSREBALANCE_PAS_NORTHSTAR_WEAPON_DURATION
				LTSRebalance_ApplyPiercingRoundsFX( victim )
			}
		}

        if ( LTSRebalance_Enabled() && projectileMods.contains( "pas_northstar_optics" ) )
            LTSRebalance_ApplyThreatOptics( victim, inflictor.GetOrigin(), DamageInfo_GetAttacker( damageInfo ), LTSREBALANCE_THREAT_OPTICS_SONAR_DURATION )

		PushEntWithDamageInfoAndDistanceScale( victim, damageInfo, nearRange, farRange, nearScale, farScale, 0.25 )
    }
	
	if ( perfectPush )
		victim.SetVelocity( Normalize( inflictor.GetVelocity() ) * 10000 )
}

void function LTSRebalance_ApplyPiercingRoundsFX( entity enemy )
{
	thread LTSRebalance_ApplyPiercingRoundsFXThink( enemy )
}

void function LTSRebalance_ApplyPiercingRoundsFXThink( entity enemy )
{
	if ( !enemy.IsTitan() )
		return

	entity soul = enemy.GetTitanSoul()

	soul.EndSignal( "OnDestroy" )
	soul.EndSignal( "PiercingRoundsHit" )

	soul.s.piercingRoundsFXs <- LTSRebalance_StartDebuffFX( enemy )

	OnThreadEnd(
		function() : ( soul )
		{
			if ( !IsValid( soul ) )
				return

			foreach( fx in soul.s.piercingRoundsFXs )
			{
				expect entity( fx )
				if ( IsValid( fx ) )
					EffectStop( fx )
			}
			soul.s.piercingRoundsFXs.clear()
		}
	)

	wait LTSREBALANCE_PAS_NORTHSTAR_WEAPON_DURATION
}

void function LTSRebalance_ApplyThreatOptics( entity enemy, vector position, entity owner, float duration )
{
	thread LTSRebalance_ApplyThreatOpticsThink( enemy, position, owner, duration )
}

void function LTSRebalance_ApplyThreatOpticsThink( entity enemy, vector position, entity owner, float duration )
{
	if ( !enemy.IsTitan() )
		return

	enemy.EndSignal( "OnDeath" )
	enemy.EndSignal( "OnDestroy" )
	enemy.EndSignal( "DisembarkingTitan" )

    int team = owner.GetTeam()
	SonarStart( enemy, position, team, owner )
	IncrementSonarPerTeam( team )
	
	OnThreadEnd(
		function() : ( enemy, team )
		{
			DecrementSonarPerTeam( team )
			if ( IsValid( enemy ) )
				SonarEnd( enemy, team )
		}
	)

	thread LTSRebalance_ApplyThreatOpticsDebuff( enemy, duration )

	wait duration
}

void function LTSRebalance_ApplyThreatOpticsDebuff( entity enemy, float baseDuration )
{
	entity soul = enemy.GetTitanSoul()
	soul.EndSignal( "OnDestroy" )

	if ( !( "threatOpticsEndTime" in soul.s ) )
	{
		soul.s.threatOpticsEndTime <- 0.0
		soul.s.threatOpticsFXs <- []
	}

	if ( soul.s.threatOpticsEndTime < Time() )
		soul.s.threatOpticsFXs = LTSRebalance_StartDebuffFX( enemy )

	OnThreadEnd(
		function() : ( soul )
		{
			if ( !IsValid( soul ) || soul.s.threatOpticsEndTime > Time() )
				return

			foreach ( fx in soul.s.threatOpticsFXs )
			{
				expect entity( fx )
				if ( IsValid( fx ) )
					EffectStop( fx )
			}
			soul.s.threatOpticsFXs.clear()
		}
	)

	float duration = baseDuration * LTSREBALANCE_THREAT_OPTICS_DEBUFF_DURATION_MOD
	soul.s.threatOpticsEffect <- StatusEffect_AddTimed( enemy, eStatusEffect.damage_received_multiplier, LTSREBALANCE_THREAT_OPTICS_DEBUFF_MOD, duration, 0.0 )
	soul.s.threatOpticsEndTime = max( soul.s.threatOpticsEndTime, Time() + duration )

	wait duration + .1
}

array function LTSRebalance_StartDebuffFX( entity enemy )
{
	array returnArray = [ null, null ]

	int attachId = enemy.LookupAttachment( "exp_torso_main" )
	int particleId = GetParticleSystemIndex( LTSREBALANCE_THREAT_OPTICS_DEBUFF_P )
	entity debuffFX = StartParticleEffectOnEntity_ReturnEntity( enemy, particleId, FX_PATTACH_POINT_FOLLOW_NOROTATE, attachId )
	debuffFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_OWNER
	debuffFX.SetOwner( enemy )
	returnArray[0] = debuffFX 

	attachId = enemy.LookupAttachment( "exp_torso_front" )
	particleId = GetParticleSystemIndex( $"P_emp_body_titan" )
	debuffFX = StartParticleEffectOnEntity_ReturnEntity( enemy, particleId, FX_PATTACH_POINT_FOLLOW, attachId )
	debuffFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY
	debuffFX.SetOwner( enemy )
	returnArray[1] = debuffFX

	return returnArray
}

void function PerfectKits_ApplyHeightDamage( entity victim, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || !attacker.IsTitan() )
		return
	
	entity soul = attacker.GetTitanSoul()
	if ( !IsValid( soul ) || !SoulHasPassive( soul, ePassives.PAS_NORTHSTAR_FLIGHTCORE ) )
		return
	
	float downDist = TraceLine( attacker.GetOrigin(), attacker.GetOrigin() + <0, 0, -1>*5000, null, TRACE_MASK_SOLID_BRUSHONLY, TRACE_COLLISION_GROUP_DEBRIS ).fraction * 5000
	float bonus = 1.0 + max( 0, downDist - PERFECTKITS_VIPER_HEIGHT_MIN ) * PERFECTKITS_VIPER_HEIGHT_CONV
	DamageInfo_ScaleDamage( damageInfo, bonus )
}

var function OnWeaponNpcPrimaryAttack_titanweapon_sniper( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireSniper( weapon, attackParams, false )
}
#endif // #if SERVER


bool function OnWeaponChargeLevelIncreased_titanweapon_sniper( entity weapon )
{
	#if CLIENT
		if ( InPrediction() && !IsFirstTimePredicted() )
			return true
	#endif

	int level = weapon.GetWeaponChargeLevel()
	int maxLevel = weapon.GetWeaponChargeLevelMax()

	if ( level == maxLevel )
		weapon.EmitWeaponSound( "Weapon_Titan_Sniper_LevelTick_Final" )
	else
		weapon.EmitWeaponSound( "Weapon_Titan_Sniper_LevelTick_" + level )

	return true
}


function FireSniper( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired )
{
	int chargeLevel = GetTitanSniperChargeLevel( weapon )
	entity weaponOwner = weapon.GetWeaponOwner()
	bool weaponHasInstantShotMod = weapon.HasMod( "instant_shot" )
	if ( chargeLevel == 0 )
		return 0

	//printt( "GetTitanSniperChargeLevel():", chargeLevel )

	if ( chargeLevel > 4 )
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Sniper_Level_4_1P", "Weapon_Titan_Sniper_Level_4_3P" )
	else if ( chargeLevel > 3 || weaponHasInstantShotMod )
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Sniper_Level_3_1P", "Weapon_Titan_Sniper_Level_3_3P" )
	else if ( chargeLevel > 2  )
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Sniper_Level_2_1P", "Weapon_Titan_Sniper_Level_2_3P" )
	else
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Sniper_Level_1_1P", "Weapon_Titan_Sniper_Level_1_3P" )

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 * chargeLevel )

	if ( chargeLevel > 5 )
	{
		weapon.SetAttackKickScale( 1.0 )
		weapon.SetAttackKickRollScale( 3.0 )
	}
	else if ( chargeLevel > 4 )
	{
		weapon.SetAttackKickScale( 0.75 )
		weapon.SetAttackKickRollScale( 2.5 )
	}
	else if ( chargeLevel > 3 )
	{
		weapon.SetAttackKickScale( 0.60 )
		weapon.SetAttackKickRollScale( 2.0 )
	}
	else if ( chargeLevel > 2 || weaponHasInstantShotMod )
	{
		weapon.SetAttackKickScale( 0.45 )
		weapon.SetAttackKickRollScale( 1.60 )
	}
	else if ( chargeLevel > 1 )
	{
		weapon.SetAttackKickScale( 0.30 )
		weapon.SetAttackKickRollScale( 1.35 )
	}
	else
	{
		weapon.SetAttackKickScale( 0.20 )
		weapon.SetAttackKickRollScale( 1.0 )
	}

	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	if ( !shouldCreateProjectile )
		return 1

    int damageFlags = ( DF_GIB | DF_BULLET | DF_ELECTRICAL )
    
	entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, SNIPER_PROJECTILE_SPEED, damageFlags, damageFlags, playerFired, 0 )
	if ( bolt )
	{
		bolt.kv.gravity = 0.001
		bolt.s.bulletsToFire <- chargeLevel

		bolt.s.extraDamagePerBullet <- weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets )
		bolt.s.extraDamagePerBullet_Titan <- weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets_titanarmor )
		if ( weaponHasInstantShotMod )
		{
			local damage_far_value_titanarmor = weapon.GetWeaponSettingInt( eWeaponVar.damage_far_value_titanarmor )
			Assert( INSTANT_SHOT_DAMAGE > damage_far_value_titanarmor )
			bolt.s.extraDamagePerBullet_Titan = INSTANT_SHOT_DAMAGE - damage_far_value_titanarmor
			bolt.s.bulletsToFire = 2
		}

		if ( chargeLevel > 4 )
			bolt.SetProjectilTrailEffectIndex( 2 )
		else if ( chargeLevel > 2 )
			bolt.SetProjectilTrailEffectIndex( 1 )

		#if SERVER
			Assert( weaponOwner == weapon.GetWeaponOwner() )
			bolt.SetOwner( weaponOwner )
		#endif
	}

	return 1
}

int function GetTitanSniperChargeLevel( entity weapon )
{
	if ( !IsValid( weapon ) )
		return 0

	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return 0

	if ( !owner.IsPlayer() )
		return 3

	if ( !weapon.IsReadyToFire() )
		return 0

	int charges = weapon.GetWeaponChargeLevel()
	return (1 + charges)
}

void function OnWeaponStartZoomIn_titanweapon_sniper( entity weapon )
{
	#if SERVER
	if ( weapon.HasMod( "pas_northstar_optics" ) )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		if ( !IsValid( weaponOwner ) )
			return
		AddThreatScopeColorStatusEffect( weaponOwner )
	}
	#endif
}

void function OnWeaponStartZoomOut_titanweapon_sniper( entity weapon )
{
	#if SERVER
	if ( weapon.HasMod( "pas_northstar_optics" ) )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		if ( !IsValid( weaponOwner ) )
			return
		RemoveThreatScopeColorStatusEffect( weaponOwner )
	}
	#endif
}

void function OnWeaponOwnerChanged_titanweapon_sniper( entity weapon, WeaponOwnerChangedParams changeParams )
{
	#if SERVER
	if ( IsValid( changeParams.oldOwner ) && changeParams.oldOwner.IsPlayer() )
		RemoveThreatScopeColorStatusEffect( changeParams.oldOwner )
	#endif
}
