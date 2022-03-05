global function OnWeaponPrimaryAttack_titanweapon_salvo_rockets
global function OnWeaponAttemptOffhandSwitch_titanweapon_salvo_rockets

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_salvo_rockets
#endif

const SALVOROCKETS_MISSILE_SFX_LOOP			= "Weapon_Sidwinder_Projectile"
const SALVOROCKETS_NUM_ROCKETS_PER_SHOT 	= 1
const SALVOROCKETS_APPLY_RANDOM_SPREAD 		= true
const SALVOROCKETS_LAUNCH_OUT_ANG 			= 2.5
const SALVOROCKETS_LAUNCH_OUT_TIME 			= 0.20
const SALVOROCKETS_LAUNCH_IN_LERP_TIME 		= 0.2
const SALVOROCKETS_LAUNCH_IN_ANG 			= -5
const SALVOROCKETS_LAUNCH_IN_TIME 			= 0.10
const SALVOROCKETS_LAUNCH_STRAIGHT_LERP_TIME = 0.1
const SALVOROCKETS_MISSILE_SPEED            = 3000.0
const SALVOROCKETS_DEBUG_DRAW_PATH 			= false

bool function OnWeaponAttemptOffhandSwitch_titanweapon_salvo_rockets( entity weapon )
{
	if( !LTSRebalance_Enabled() )
		return true
	return WeaponHasAmmoToUse( weapon )
}

var function OnWeaponPrimaryAttack_titanweapon_salvo_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	bool shouldPredict = weapon.ShouldPredictProjectiles()

	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif

	entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	var missileSpeed = LTSRebalance_Enabled() ? SALVOROCKETS_MISSILE_SPEED : VANGUARD_SHOULDER_MISSILE_SPEED
	array<entity> firedMissiles = FireExpandContractMissiles( weapon, attackParams, attackParams.pos, attackParams.dir, damageTypes.projectileImpact, damageTypes.explosive, shouldPredict, SALVOROCKETS_NUM_ROCKETS_PER_SHOT, missileSpeed, SALVOROCKETS_LAUNCH_OUT_ANG, SALVOROCKETS_LAUNCH_OUT_TIME, SALVOROCKETS_LAUNCH_IN_ANG, SALVOROCKETS_LAUNCH_IN_TIME, SALVOROCKETS_LAUNCH_IN_LERP_TIME, SALVOROCKETS_LAUNCH_STRAIGHT_LERP_TIME, SALVOROCKETS_APPLY_RANDOM_SPREAD, -1, SALVOROCKETS_DEBUG_DRAW_PATH )
	foreach( missile in firedMissiles )
	{
		#if SERVER
			missile.SetOwner( player )
			EmitSoundOnEntity( missile, SALVOROCKETS_MISSILE_SFX_LOOP )
		#endif
		SetTeam( missile, player.GetTeam() )
	}

	if ( player.IsPlayer() )
		PlayerUsedOffhand( player, weapon )

	return firedMissiles.len() * weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}


#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_salvo_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_salvo_rockets( weapon, attackParams )
}
#endif