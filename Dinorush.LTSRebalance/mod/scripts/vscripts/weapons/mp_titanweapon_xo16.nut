/* LTS Rebalance replaces this file for the following reasons:
   1. Implement baseline changes (Add functionality for projectile weapon)
*/
global function MpTitanweaponXo16_Init

global function OnWeaponActivate_titanweapon_xo16
global function OnWeaponPrimaryAttack_titanweapon_xo16
global function OnWeaponStartZoomIn_titanweapon_xo16
global function OnWeaponStartZoomOut_titanweapon_xo16
global function OnWeaponOwnerChanged_titanweapon_xo16

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_xo16
#endif // #if SERVER

const XO16_TRACER_FX = $"weapon_tracers_xo16_speed"
const XO16_TRACER_BURN_FX = $"weapon_tracers_xo16_speed"

global const float LTSREBALANCE_ARC_ROUNDS_DRAIN_MOD_MIN = 0.5

void function MpTitanweaponXo16_Init()
{
	#if CLIENT
		PrecacheParticleSystem( XO16_TRACER_FX )
		PrecacheParticleSystem( XO16_TRACER_BURN_FX )
	#endif
}

void function OnWeaponActivate_titanweapon_xo16( entity weapon )
{
#if CLIENT
	UpdateViewmodelAmmo( false, weapon )
#endif // #if CLIENT

	if ( !weapon.HasMod( "accelerator" ) && !weapon.HasMod( "burst" ) )
	{
		// SetLoopingWeaponSound_1p3p( "Weapon_XO16_Fire_First_1P", "Weapon_XO16_Fire_Loop_1P", "Weapon_XO16_Fire_Last_1P",
		//                             "Weapon_XO16_Fire_First_3P", "Weapon_XO16_Fire_Loop_3P", "Weapon_XO16_Fire_Last_3P", weapon )
	}
}

var function OnWeaponPrimaryAttack_titanweapon_xo16( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if ( LTSRebalance_Enabled() )
		return OnWeaponPrimaryAttack_GenericBoltWithDrop_Player( weapon, attackParams )

	return FireWeaponPlayerAndNPC( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_xo16( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if ( LTSRebalance_Enabled() )
		return OnWeaponPrimaryAttack_GenericBoltWithDrop_NPC( weapon, attackParams )

	return FireWeaponPlayerAndNPC( weapon, attackParams, false )
}
#endif // #if SERVER

int function FireWeaponPlayerAndNPC( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, weapon.GetWeaponDamageFlags() )

	return 1
}


vector function ApplySpread( entity player, vector forward, float spread )
{
	// not correct to use these... they should be based on forward but we don't have those script
	// functions and this is just a quick prototype
	vector right = player.GetViewRight()
	vector up = player.GetViewUp()

	float v = 0.0
	float u = 0.0
	float s = 0.0

	do
	{
		u = RandomFloatRange( -1.0, 1.0 )
		v = RandomFloatRange( -1.0, 1.0 )
		s = u * u + v * v
	}
	while ( s == 0.0 || s > 1.0 )

	float c = sqrt( ( -2.0 * log( s ) ) / ( s * log( 2.71828182845904523536 ) ) )
	float x = u * c
	float y = v * c

	float sigmaComponent = 0.5 * tan( DegToRad( spread / 2.0 ) )

	vector result = Normalize( forward + x * sigmaComponent * right + y * sigmaComponent * up )
	return result
}

void function OnWeaponStartZoomIn_titanweapon_xo16( entity weapon )
{
	#if SERVER
	if ( weapon.HasMod( "fd_vanguard_weapon_2" ) )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		if ( !IsValid( weaponOwner ) )
			return
		AddThreatScopeColorStatusEffect( weaponOwner )
	}
	#endif
}

void function OnWeaponStartZoomOut_titanweapon_xo16( entity weapon )
{
	#if SERVER
	if ( weapon.HasMod( "fd_vanguard_weapon_2" ) )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		if ( !IsValid( weaponOwner ) )
			return
		RemoveThreatScopeColorStatusEffect( weaponOwner )
	}
	#endif
}

void function OnWeaponOwnerChanged_titanweapon_xo16( entity weapon, WeaponOwnerChangedParams changeParams )
{
	#if SERVER
	if ( IsValid( changeParams.oldOwner ) && changeParams.oldOwner.IsPlayer() )
		RemoveThreatScopeColorStatusEffect( changeParams.oldOwner )
	#endif
}
