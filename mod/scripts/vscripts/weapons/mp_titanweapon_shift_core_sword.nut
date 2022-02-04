untyped
global function OnWeaponActivate_titanweapon_shift_core_sword
global function OnWeaponDeactivate_titanweapon_shift_core_sword
global function OnWeaponPrimaryAttack_titanweapon_shift_core_sword
global function MpTitanweaponShiftCoreSword_Init

void function MpTitanweaponShiftCoreSword_Init()
{
	PrecacheWeapon( "mp_titanweapon_shift_core_sword" )

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
		AddButtonPressedPlayerInputCallback( player, IN_ATTACK, ShiftCore_Released )
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

	bool pressed = false
	bool nowPressed = false
	while( player.IsInputCommandHeld( IN_ATTACK ) )
		WaitFrame()
}
#endif

void function OnWeaponActivate_titanweapon_shift_core_sword( entity weapon )
{
	print( "START: " + Time() )
	entity owner = weapon.GetWeaponOwner()
	if ( owner.IsPlayer() && !( "ShiftCore_HoldFire" in owner.s ) )
	{
		#if SERVER
		owner.s.ShiftCore_HoldFire <- true
		AddButtonPressedPlayerInputCallback( owner, IN_ATTACK, ShiftCore_Released )
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
	print( "ATTACK CALLED: " + Time() )
	if ( ( "ShiftCore_HoldFire" in owner.s ) )
		print( "Hold: " + owner.s.ShiftCore_HoldFire )
	if ( !( "ShiftCore_HoldFire" in owner.s ) || owner.s.ShiftCore_HoldFire )
		return 0	
	
	owner.s.ShiftCore_HoldFire = true
	#if CLIENT
	thread Cl_ShiftCore_ReleasedThink( owner, weapon )
	#endif
	CodeCallback_OnMeleePressed( owner )
	return 1
}