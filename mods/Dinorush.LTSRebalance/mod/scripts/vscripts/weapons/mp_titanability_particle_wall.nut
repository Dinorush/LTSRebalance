/* LTS Rebalance replaces this file for the following reasons:
   1. Implement Reinforced Particle Wall changes (LTS Rebalance + Perfect Kits)
*/
untyped

global function MpTitanabilityBubbleShield_Init

global function OnWeaponPrimaryAttack_particle_wall

#if SERVER
global function OnWeaponNpcPrimaryAttack_particle_wall
#endif // #if SERVER

global const SP_PARTICLE_WALL_DURATION = 8.0
global const MP_PARTICLE_WALL_DURATION = 6.0
global const LTSREBALANCE_MP_PARTICLE_WALL_DURATION = 4.0

function MpTitanabilityBubbleShield_Init()
{
	RegisterSignal( "RegenAmmo" )

    #if CLIENT
	    PrecacheHUDMaterial( $"vgui/hud/dpad_bubble_shield_charge_0" )
	    PrecacheHUDMaterial( $"vgui/hud/dpad_bubble_shield_charge_1" )
	    PrecacheHUDMaterial( $"vgui/hud/dpad_bubble_shield_charge_2" )
    #endif
}

var function OnWeaponPrimaryAttack_particle_wall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

#if SERVER
	float duration
	if ( IsSingleplayer() )
		duration = SP_PARTICLE_WALL_DURATION
	else if ( LTSRebalance_Enabled() )
		duration = LTSREBALANCE_MP_PARTICLE_WALL_DURATION
	else
		duration = MP_PARTICLE_WALL_DURATION

	entity particleWall = CreateParticleWallFromOwner( weapon.GetWeaponOwner(), duration, attackParams )
    entity soul = weaponOwner.GetTitanSoul()
	if ( PerfectKits_Enabled() && IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_TONE_WALL ))
	{
		CreateParticleWallFromOwner( weapon.GetWeaponOwner(), duration, attackParams )
		vector dir = AnglesToForward( particleWall.GetAngles() )
		dir *= -1
		particleWall.SetOrigin( particleWall.GetOrigin() - dir * ( SHIELD_WALL_RADIUS * 2 + 20 ) )
		particleWall.SetAngles( VectorToAngles( dir ) )
	}
#endif
	return weapon.GetAmmoPerShot()
}

#if SERVER

var function OnWeaponNpcPrimaryAttack_particle_wall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	float duration
	if ( IsSingleplayer() )
		duration = SP_PARTICLE_WALL_DURATION
	else
		duration = MP_PARTICLE_WALL_DURATION
	entity particleWall = CreateParticleWallFromOwner( weapon.GetWeaponOwner(), duration, attackParams )
	return weapon.GetWeaponInfoFileKeyField( "ammo_per_shot" )
}
#endif // #if SERVER