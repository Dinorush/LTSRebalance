/* LTS Rebalance replaces this file for the following reasons:
   1. Implement Perfect Kits Refraction Lens
   2. Fix double hit bug
   3. Fix energy consumption during terminations
*/
untyped
global function MpTitanWeaponLaserLite_Init

global function OnWeaponAttemptOffhandSwitch_titanweapon_laser_lite
global function OnWeaponPrimaryAttack_titanweapon_laser_lite
global function LTSRebalance_ReduceLaserCost

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_laser_lite
#endif

#if CLIENT
struct {
	float[3] boltOffsets = [
		0.0,
		0.014,
		-0.014,
	]
	
	var LTSRebalance_discount_text
} file;
#else
struct {
	float[3] boltOffsets = [
		0.0,
		0.014,
		-0.014,
	]
} file;
#endif

const float LTSREBALANCE_LASER_TRIP_COST_REDUCTION_TIME = 4.0
const int LTSREBALANCE_PAS_ION_WEAPON_BONUS_COST = 150

void function MpTitanWeaponLaserLite_Init()
{
	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_laser_lite, LaserLite_DamagedTarget )
	#endif

	if ( LTSRebalance_EnabledOnInit() )
	{
		RegisterSignal( "LaserResetCost" )
		#if CLIENT
		var text = RuiCreate( $"ui/cockpit_console_text_center.rpak", clGlobal.topoCockpitHudPermanent, RUI_DRAW_COCKPIT, -1 )
		RuiSetInt( text, "maxLines", 1 )
		RuiSetInt( text, "lineNum", 1 )
		RuiSetFloat2( text, "msgPos", < -0.225, 0.34, 0> )
		RuiSetFloat3( text, "msgColor", <0.4, 2.0, 0.4> )
		RuiSetString( text, "msgText", "0" )
		RuiSetFloat( text, "msgFontSize", 40.0 )
		RuiSetFloat( text, "msgAlpha", 0.0 )
		RuiSetFloat( text, "thicken", 0.0 )
		file.LTSRebalance_discount_text = text
		#endif
	}
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_laser_lite( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()

	// Use default energy cost as base since Grand Cannon can modify current cost
	int curCost = weapon.GetWeaponDefaultEnergyCost( 1 )
	curCost = LTSRebalance_GetEnergyCostWithReduction( weapon, true, curCost )

	bool canUse = owner.CanUseSharedEnergy( curCost )

	#if CLIENT
		if ( !canUse )
			FlashEnergyNeeded_Bar( curCost )
	#endif

	return canUse && WeaponHasAmmoToUse( weapon )
}

bool function LTSRebalance_HasEnergyToFire( entity weapon, int burstIndex )
{
	if ( burstIndex > 0 )
		return true
	
	return OnWeaponAttemptOffhandSwitch_titanweapon_laser_lite( weapon )
}

int function LTSRebalance_GetEnergyCostWithReduction( entity weapon, bool stored = false, int curCost = 0 )
{
	if ( curCost == 0 )
		curCost = weapon.GetWeaponCurrentEnergyCost()

	string key = stored ? "storedCostReduction" : "costReduction"
	// Convert flat amount to fraction of default cost since Grand Cannon uses energy cost per shot
	if ( key in weapon.s )
		return int( max( 1.0, curCost * ( 1.0 - float( weapon.s[key] ) / float( weapon.GetWeaponDefaultEnergyCost( 1 ) ) ) ) )

	return curCost
}

var function OnWeaponPrimaryAttack_titanweapon_laser_lite( entity weapon, WeaponPrimaryAttackParams attackParams )
{
    entity weaponOwner = weapon.GetWeaponOwner()

    if ( LTSRebalance_Enabled() && !weaponOwner.ContextAction_IsBusy() && !LTSRebalance_HasEnergyToFire( weapon, attackParams.burstIndex ) )
        return 0

	if ( LTSRebalance_Enabled() && attackParams.burstIndex == 0 && "storedCostReduction" in weapon.s )
	{
		weapon.s.costReduction <- weapon.s.storedCostReduction
		weapon.s.storedCostReduction = 0
		weapon.Signal( "LaserResetCost" )
	}

    weapon.s.entitiesHit <- {}
	weapon.s.perfectKitsRefrac <- false

	#if CLIENT
		// Sync up energy consumption
		if ( weapon.HasMod( "LTSRebalance_pas_ion_lasercannon" ) )
			weapon.SetWeaponEnergyCost( weapon.GetWeaponCurrentEnergyCost() / weapon.GetWeaponBurstFireCount() )

		if ( !weapon.ShouldPredictProjectiles() )
			return 1
	#endif

	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	array<entity> weapons = weaponOwner.GetMainWeapons()
	if ( PerfectKits_Enabled() && weapons.len() > 0 && weapons[0].HasMod( "PerfectKits_pas_ion_weapon_ads" ) )
	{
		weapon.s.perfectKitsRefrac <- true
		int cost = weapon.GetWeaponCurrentEnergyCost()
		weapon.SetWeaponEnergyCost( cost / 3 )
		if ( "costReduction" in weapon.s )
			weapon.SetWeaponEnergyCost( LTSRebalance_GetEnergyCostWithReduction( weapon ) )

		vector attackAngles = VectorToAngles( attackParams.dir )
		vector baseRightVec = AnglesToRight( attackAngles )

		for ( int i = 0; i < 3; i++ )
			ShotgunBlast( weapon, attackParams.pos, attackParams.dir + baseRightVec * file.boltOffsets[i], 1, DF_GIB | DF_EXPLOSION )
		weapon.ResetWeaponToDefaultEnergyCost()
	}
	else
	{
		weapon.ResetWeaponToDefaultEnergyCost()
		if ( weapon.HasMod( "LTSRebalance_pas_ion_lasercannon" ) )
			weapon.SetWeaponEnergyCost( weapon.GetWeaponCurrentEnergyCost() / weapon.GetWeaponBurstFireCount() )

		if ( "costReduction" in weapon.s )
			weapon.SetWeaponEnergyCost( LTSRebalance_GetEnergyCostWithReduction( weapon ) )

		ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	}

	if ( LTSRebalance_Enabled() && weapon.GetBurstFireShotsPending() <= 1 && "costReduction" in weapon.s )
		weapon.s.costReduction = 0

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.SetWeaponChargeFractionForced(1.0)
	return weapon.GetAmmoPerShot()
}

// Called by Tripwire
void function LTSRebalance_ReduceLaserCost( entity weapon, entity owner )
{ 
	entity laser = owner.GetOffhandWeapon( OFFHAND_RIGHT )
	if ( !IsValid( laser ) )
		return
	
	laser.EndSignal( "OnDestroy" )
	laser.EndSignal( "LaserResetCost" )
	
	int costReduction = weapon.GetWeaponCurrentEnergyCost()

	if ( laser.HasMod( "LTSRebalance_pas_ion_weapon_helper" ) )
		costReduction += LTSREBALANCE_PAS_ION_WEAPON_BONUS_COST

	// Laser Shot stores the cost reduction, then applies it on shot, rather than using one variable for both.
	// This fixes the case where Tripwire is deployed while Grand Cannon is firing.
	table laserDotS = expect table( laser.s )
	if ( !( "storedCostReduction" in laserDotS ) )
		laserDotS.storedCostReduction <- 0

	#if CLIENT
	OnThreadEnd(
		function() : ( laser, laserDotS )
		{
			ClWeaponStatus_RefreshWeaponStatus( GetLocalViewPlayer() )
			RuiSetString( file.LTSRebalance_discount_text, "msgText", format( "-%.1f%%", laserDotS.storedCostReduction / 10.0 ) )
			if ( !IsValid( laser ) || laserDotS.storedCostReduction == 0 )
				RuiSetFloat( file.LTSRebalance_discount_text, "msgAlpha", 0.0 )
		}
	)

	if ( laserDotS.storedCostReduction == 0 )
		RuiSetFloat( file.LTSRebalance_discount_text, "msgAlpha", 0.7 )

	RuiSetString( file.LTSRebalance_discount_text, "msgText", format( "-%.1f%%", ( laserDotS.storedCostReduction + costReduction ) / 10.0 ) )
	#endif

	int laserCost = laser.GetWeaponDefaultEnergyCost( 1 )
	laserDotS.storedCostReduction += costReduction
	laser.SetWeaponEnergyCost( LTSRebalance_GetEnergyCostWithReduction( laser, true, laserCost ) ) // Only affects ability bar. Weapon doesn't stay affected for client
	#if CLIENT
	ClWeaponStatus_RefreshWeaponStatus( GetLocalViewPlayer() )
	#endif

	wait LTSREBALANCE_LASER_TRIP_COST_REDUCTION_TIME

	laserDotS.storedCostReduction -= costReduction
	laser.SetWeaponEnergyCost( LTSRebalance_GetEnergyCostWithReduction( laser, true, laserCost ) ) // Only affects ability bar. Weapon doesn't stay affected for client
	// Visuals updated on Thread End
}

#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_laser_lite( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_laser_lite( weapon, attackParams )
}

void function LaserLite_DamagedTarget( entity target, var damageInfo )
{
	entity weapon = DamageInfo_GetInflictor( damageInfo )
	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if ( attacker == target )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}

	if ( LTSRebalance_Enabled() )
	{
		if ( !IsValid( weapon ) )
			return

		if ( "entitiesHit" in weapon.s )
		{
			if ( !( target in weapon.s.entitiesHit ) )
				weapon.s.entitiesHit[ target ] <- 1
			else if ( PerfectKits_Enabled() && weapon.s.perfectKitsRefrac && weapon.s.entitiesHit[ target ] < 3 )
				weapon.s.entitiesHit[ target ] += 1
			else
			{
				DamageInfo_SetDamage( damageInfo, 0 )
				return
			}
		}
	}
}
#endif