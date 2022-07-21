untyped
global function MpTitanWeaponLaserLite_Init

global function OnWeaponAttemptOffhandSwitch_titanweapon_laser_lite
global function OnWeaponPrimaryAttack_titanweapon_laser_lite
// global function OnWeaponActivate_titanweapon_laser_lite

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_laser_lite
#endif

struct {
	float[3] boltOffsets = [
		0.0,
		0.014,
		-0.014,
	]
} file;

void function MpTitanWeaponLaserLite_Init()
{
	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_laser_lite, LaserLite_DamagedTarget )
	#endif
}

// void function OnWeaponActivate_titanweapon_laser_lite( entity weapon )
// {
// 	#if CLIENT
// 		//TODO - Charge Level UI
// 	#endif
// }

bool function OnWeaponAttemptOffhandSwitch_titanweapon_laser_lite( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	int curCost = weapon.GetWeaponCurrentEnergyCost()
	bool canUse = owner.CanUseSharedEnergy( curCost )

	#if CLIENT
		if ( !canUse )
			FlashEnergyNeeded_Bar( curCost )
	#endif

	return canUse
}

var function OnWeaponPrimaryAttack_titanweapon_laser_lite( entity weapon, WeaponPrimaryAttackParams attackParams )
{
    entity weaponOwner = weapon.GetWeaponOwner()
    // Prevent from firing without required energy
    if ( LTSRebalance_Enabled() && !weaponOwner.ContextAction_IsBusy() && !OnWeaponAttemptOffhandSwitch_titanweapon_laser_lite( weapon ) )
        return 0

    weapon.s.entitiesHit <- {}
	weapon.s.perfectKitsRefrac <- false

	#if CLIENT
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
		vector attackAngles = VectorToAngles( attackParams.dir )
		vector baseRightVec = AnglesToRight( attackAngles )

		for ( int i = 0; i < 3; i++ )
			ShotgunBlast( weapon, attackParams.pos, attackParams.dir + baseRightVec * file.boltOffsets[i], 1, DF_GIB | DF_EXPLOSION )
		weapon.ResetWeaponToDefaultEnergyCost()
	}
	else
		ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.SetWeaponChargeFractionForced(1.0)
	return 1
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

		// int level = minint( 5, weapon.GetWeaponChargeLevel() )
		// float f_extraDamage = CalculateLaserShotExtraDamage( weapon, target )
		// float damage = DamageInfo_GetDamage( damageInfo )

		// bool isCritical = IsCriticalHit( attacker, target, DamageInfo_GetHitBox( damageInfo ), damage, DamageInfo_GetDamageType( damageInfo ) )

		// if ( isCritical )
		// {
		// 	float critMod = weapon.GetWeaponSettingFloat( eWeaponVar.critical_hit_damage_scale )
		// 	f_extraDamage *= critMod
		// }

		// //Check to see if damage has been see to zero so we don't override it.
		// if ( damage > 0 && f_extraDamage > 0 )
		// {
		// 	damage += f_extraDamage
		// 	DamageInfo_SetDamage( damageInfo, damage )
		// }
	}
}

// float function CalculateLaserShotExtraDamage( entity weapon, entity hitent )
// {
// 	int damagePerBullet
// 	if ( hitent.IsTitan() )
// 		damagePerBullet = weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets )
// 	else
// 		damagePerBullet = weapon.GetWeaponSettingInt( eWeaponVar.damage_additional_bullets_titanarmor )

// 	int cap = expect int( weapon.GetWeaponInfoFileKeyField( "charge_levels_cap" ) )
// 	float extraDamage = float( minint( weapon.GetWeaponChargeLevel(), cap ) * damagePerBullet )

// 	if ( extraDamage <= 0 )
// 		return 0

// 	return extraDamage
// }
#endif