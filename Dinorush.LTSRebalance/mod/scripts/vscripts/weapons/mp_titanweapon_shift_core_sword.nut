untyped
global function OnWeaponActivate_titanweapon_shift_core_sword
global function OnWeaponDeactivate_titanweapon_shift_core_sword
global function OnWeaponPrimaryAttack_titanweapon_shift_core_sword
global function MpTitanweaponShiftCoreSword_Init

// This file would normally be < 50 lines, but Respawn stinky and I have to add in semi-auto functionality manually
// since the Sword Core viewmodel has basically 0 forgiveness for timing a "shot" after melee

void function MpTitanweaponShiftCoreSword_Init()
{
	#if SERVER
	AddClientCommandCallback( "AllowShiftCoreMelee", AllowShiftCoreMelee )
	#endif
}

#if SERVER
bool function AllowShiftCoreMelee( entity player, array<string> args )
{
	if ( !( "ShiftCore_HoldFire" in player.s ) )
	{
		player.s.ShiftCore_HoldFire <- false
		AddButtonReleasedPlayerInputCallback( player, IN_ATTACK, ShiftCore_Released )
	}
	else
		player.s.ShiftCore_HoldFire = false
	return true
}

void function ShiftCore_Released( entity player )
{
	player.s.ShiftCore_HoldFire = false
}
#else
void function Cl_ShiftCore_ReleasedThink( entity player, entity weapon )
{
	player.EndSignal( "OnDestroy" )
	weapon.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( player )
		{
			if ( IsValid( player ) )
				player.s.ShiftCore_HoldFire = false
		}
	)

	while( player.IsInputCommandHeld( IN_ATTACK ) )
		WaitFrame()
}
#endif

void function OnWeaponActivate_titanweapon_shift_core_sword( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	if ( owner.IsPlayer() && !( "ShiftCore_HoldFire" in owner.s ) )
	{
		#if SERVER
		owner.s.ShiftCore_HoldFire <- true
		AddButtonReleasedPlayerInputCallback( owner, IN_ATTACK, ShiftCore_Released )
		#else
		owner.s.ShiftCore_HoldFire <- false
		owner.ClientCommand( "AllowShiftCoreMelee" )
		#endif
	}

	if ( weapon.HasMod( "modelset_prime" ) )
		weapon.PlayWeaponEffectNoCull( SWORD_GLOW_PRIME_FP, SWORD_GLOW_PRIME, "sword_edge" )
	else
		weapon.PlayWeaponEffectNoCull( SWORD_GLOW_FP, SWORD_GLOW, "sword_edge" )
}

void function OnWeaponDeactivate_titanweapon_shift_core_sword( entity weapon )
{
	if ( weapon.HasMod( "modelset_prime" ) )
		weapon.StopWeaponEffect( SWORD_GLOW_PRIME_FP, SWORD_GLOW_PRIME )
	else
		weapon.StopWeaponEffect( SWORD_GLOW_FP, SWORD_GLOW )
}

var function OnWeaponPrimaryAttack_titanweapon_shift_core_sword( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	if ( !( "ShiftCore_HoldFire" in owner.s ) || owner.s.ShiftCore_HoldFire )
		return 0

	owner.s.ShiftCore_HoldFire = true
	#if CLIENT
	thread Cl_ShiftCore_ReleasedThink( owner, weapon )
	#endif
	CodeCallback_OnMeleePressed( owner )
	return 1
}