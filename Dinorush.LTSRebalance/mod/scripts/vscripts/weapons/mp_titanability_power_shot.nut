/* LTS Rebalance replaces this file for the following reasons:
   1. Implement baseline changes
   2. Fix Power Shot limitations not being terminated
   3. Implement Perfect Kits Hidden Compartment
*/
global function OnWeaponPrimaryAttack_power_shot
global function MpTitanAbilityPowerShot_Init
global function PowerShotCleanup
#if SERVER
global function OnWeaponNpcPrimaryAttack_power_shot
#endif

void function MpTitanAbilityPowerShot_Init()
{
	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_predator_cannon, PowerShot_DamagedEntity )
	RegisterSignal( "PowerShotCleanup" )
	#endif
}

var function OnWeaponPrimaryAttack_power_shot( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.ContextAction_IsActive() || ( weaponOwner.IsPlayer() && weaponOwner.PlayerMelee_GetState() != PLAYER_MELEE_STATE_NONE ) )
		return 0

	array<entity> weapons = GetPrimaryWeapons( weaponOwner )
	entity primaryWeapon = weapons[0]
	if ( !IsValid( primaryWeapon ) || primaryWeapon.IsReloading() || weaponOwner.e.ammoSwapPlaying == true )
		return 0

	if ( primaryWeapon.HasMod( "LongRangePowerShot" ) || primaryWeapon.HasMod( "CloseRangePowerShot" ) )
		return 0

	int rounds = primaryWeapon.GetWeaponPrimaryClipCount()
	if ( rounds == 0 )
		return 0
	//	primaryWeapon.SetWeaponPrimaryClipCount( 1 )

	int milestone = primaryWeapon.GetReloadMilestoneIndex()
	if ( milestone != 0 )
		return 0

	if ( weaponOwner.IsPlayer() )
	{
		if ( LTSRebalance_Enabled() )
			thread SetPowershotLimits( weaponOwner, primaryWeapon )
		else
		{
			weaponOwner.SetTitanDisembarkEnabled( false )
			primaryWeapon.SetForcedADS()
			weaponOwner.SetMeleeDisabled()
		}
		PlayerUsedOffhand( weaponOwner, weapon )
		#if SERVER
		if ( LTSRebalance_Enabled() )
			thread ClearPowerShotLimits( weaponOwner, weapon )
		else
			thread MonitorEjectStatus( weaponOwner )
		#endif
	}

	#if CLIENT
    if ( !weapon.ShouldPredictProjectiles() )
		return weapon.GetAmmoPerShot()
	#endif

    if ( primaryWeapon.HasMod( "Smart_Core_Spread" ) )
        primaryWeapon.RemoveMod( "Smart_Core_Spread" )

	if ( primaryWeapon.HasMod( "LongRangeAmmo" ) )
	{
        array<string> mods = primaryWeapon.GetMods()
		mods.fastremovebyvalue( "LongRangeAmmo" )
		if( LTSRebalance_Enabled() || PerfectKits_Enabled() )
        	mods.append( "BasePowerShot" )
		mods.append( "LongRangePowerShot" )
		if ( mods.contains( "fd_longrange_helper" ) )
			mods.append( "fd_LongRangePowerShot" )
		if ( weapon.HasMod( "pas_legion_chargeshot" ) )
			mods.append( "pas_LongRangePowerShot" )
		if ( weapon.HasMod( "PerfectKits_pas_legion_chargeshot" ) )
			mods.append( "PerfectKits_pas_PowerShot" )
		primaryWeapon.SetMods( mods )
	}
	else
	{
        array<string> mods = primaryWeapon.GetMods()
        if( LTSRebalance_Enabled() || PerfectKits_Enabled() )
        	mods.append( "BasePowerShot" )
		mods.append( "CloseRangePowerShot" )
		if ( mods.contains( "fd_closerange_helper" ) )
			mods.append( "fd_CloseRangePowerShot" )
		if ( weapon.HasMod( "pas_legion_chargeshot" ) )
			mods.append( "pas_CloseRangePowerShot" )
		if ( weapon.HasMod( "PerfectKits_pas_legion_chargeshot" ) )
			mods.append( "PerfectKits_pas_PowerShot" )
		primaryWeapon.SetMods( mods )
	}
    
	#if SERVER
	if ( LTSRebalance_Enabled() )
    	thread StopRegenDuringPowerShot( weapon, weaponOwner )
	#endif
	return weapon.GetAmmoPerShot()
}

void function SetPowershotLimits( entity weaponOwner, entity primaryWeapon )
{
    do {
        weaponOwner.SetTitanDisembarkEnabled( false )
        primaryWeapon.SetForcedADS()
        weaponOwner.SetMeleeDisabled()
        WaitFrame()
    } while( !primaryWeapon.GetForcedADS() )
}

#if SERVER
void function StopRegenDuringPowerShot( entity weapon, entity weaponOwner )
{
    weapon.AddMod( "LTSRebalance_stop_regen" )

    weaponOwner.EndSignal( "PowerShotCleanup" )

    OnThreadEnd(
    function() : ( weapon )
        {
            if ( IsValid( weapon ) )
            {
                weapon.RemoveMod( "LTSRebalance_stop_regen" )
                weapon.RegenerateAmmoReset()
            }
        }
    )

    // Wait for more than ADS in + Power Shot charge. Don't do forever; the thread relies on the wait ending to clear edge cases.
    wait 3.0 
}

void function ClearPowerShotLimits( entity weaponOwner, entity weapon )
{
    OnThreadEnd(
    function() : ( weaponOwner, weapon )
        {
            if ( IsValid( weaponOwner ) )
            {
				if ( !IsValid( weapon ) || !weapon.e.gunShieldActive )
            		weaponOwner.ClearMeleeDisabled()
                weaponOwner.SetTitanDisembarkEnabled( true )
            }
        }
    )
	weaponOwner.EndSignal( "PowerShotCleanup" )
    weaponOwner.EndSignal( "OnDeath" )
	weaponOwner.WaitSignal( "TitanEjectionStarted" )
}

void function MonitorEjectStatus( entity weaponOwner )
{
	weaponOwner.EndSignal( "PowerShotCleanup" )

	weaponOwner.WaitSignal( "TitanEjectionStarted" )

	if ( IsValid( weaponOwner ) )
	{
		weaponOwner.ClearMeleeDisabled()
		weaponOwner.SetTitanDisembarkEnabled( true )
	}
}
#endif
void function PowerShotCleanup( entity owner, entity weapon, array<string> modNames, array<string> modsToAdd )
{
	#if SERVER
	if ( IsValid( owner ) && owner.IsPlayer() )
	{
		if ( !LTSRebalance_Enabled() )
		{
			owner.ClearMeleeDisabled()
			owner.SetTitanDisembarkEnabled( true )
		}
		owner.Signal( "PowerShotCleanup")
	}
	#endif
	if ( IsValid( weapon ) )
	{
		if ( !weapon.e.gunShieldActive && !weapon.HasMod( "SiegeMode" ) )
		{
			while( weapon.GetForcedADS() )
				weapon.ClearForcedADS()
		}
		#if SERVER
		array<string> mods = weapon.GetMods()
        mods.fastremovebyvalue( "BasePowerShot" )
		if ( weapon.HasMod( "PerfectKits_pas_PowerShot" ) )
			mods.fastremovebyvalue( "PerfectKits_pas_PowerShot" )
		foreach( modName in modNames )
			mods.fastremovebyvalue( modName )
		foreach( mod in modsToAdd )
			mods.append( mod )
        if( LTSRebalance_Enabled() && weapon.HasMod( "Smart_Core" ) )
            mods.append( "Smart_Core_Spread" )

		weapon.SetMods( mods )
		#endif
	}
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_power_shot( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_power_shot( weapon, attackParams )
}

void function RemoveCloseRangeMod( entity weapon, entity weaponOwner )
{
	if ( !weapon.HasMod( "CloseRangeShot" ) )
		return
	array<string> mods = weapon.GetMods()
	mods.fastremovebyvalue( "CloseRangeShot" )
	weapon.SetMods( mods )
}

void function GiveCloseRangeMod( entity weapon, entity weaponOwner )
{
	if ( weapon.HasMod( "CloseRangeShot" ) )
		return

	array<string> mods = weapon.GetMods()
	mods.append( "CloseRangeShot" )
	weapon.SetMods( mods )
}

void function PowerShot_DamagedEntity( entity victim, var damageInfo )
{
	int scriptDamageType = DamageInfo_GetCustomDamageType( damageInfo )
	
	if ( scriptDamageType & DF_KNOCK_BACK && !IsHumanSized( victim ) )
	{
		entity attacker = DamageInfo_GetAttacker( damageInfo )
		if ( !IsValid( attacker ) || attacker.IsProjectile() ) // Need to check for PerfectKits since LR Power Shot can trigger this (attacker becomes projectile if attacker dies)
			return

		if ( LTSRebalance_Enabled() )
			LTSRebalance_FixVortexShotgunBlast( attacker, victim, damageInfo )

		float distance = Distance( victim.GetOrigin(), attacker.GetOrigin() )
		vector pushback = Normalize( victim.GetOrigin() - attacker.GetOrigin() )
		pushback *= 500 * 1.0 - StatusEffect_Get( victim, eStatusEffect.pushback_dampen ) * GraphCapped( distance, 0, 1200, 1.0, 0.25 )
		
		entity offhand = attacker.GetOffhandWeapon( OFFHAND_RIGHT )
		if ( IsValid( offhand ) && offhand.HasMod( "PerfectKits_pas_legion_chargeshot" ) )
		{
			entity inflictor = DamageInfo_GetInflictor( damageInfo )
			if ( IsValid( inflictor ) && inflictor.IsProjectile() )
				pushback *= -4
			else
				pushback *= 100
		}
		PushPlayerAway( victim, pushback )
	}
}

// If Shotgun Blast hits a Vortex entity that does not absorb the bullets, pellets will stack damage on targets behind it.
// The damageInfo comes in with total damage, not separate instances, so we must manually calculate the correct damage.
// One separate instance can occur for the shot that goes to Vortex though, so we have to account for duplicates.
void function LTSRebalance_FixVortexShotgunBlast( entity attacker, entity victim, var damageInfo )
{
	entity weapon = DamageInfo_GetWeapon( damageInfo )
	if ( !IsValid( weapon ) )
		return

	table weaponDotS = expect table( weapon.s )
	if ( !( "powerShotTargets" in weaponDotS ) )
		weaponDotS.powerShotTargets <- []

	array targets = expect array( weaponDotS.powerShotTargets )
	if ( targets.contains( victim ) )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}
	else
		targets.append( victim )

	float singleDamage = CalcWeaponDamage( attacker, victim, weapon, Distance( attacker.EyePosition(), DamageInfo_GetDamagePosition( damageInfo ) ), 0 )
	if ( IsCriticalHit( attacker, victim, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamage( damageInfo ), DamageInfo_GetDamageType( damageInfo ) ) )
		singleDamage *= weapon.GetWeaponSettingFloat( eWeaponVar.critical_hit_damage_scale )
	DamageInfo_SetDamage( damageInfo, min( DamageInfo_GetDamage( damageInfo ), singleDamage ) )
}
#endif