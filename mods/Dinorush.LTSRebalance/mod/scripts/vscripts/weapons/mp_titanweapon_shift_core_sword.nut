untyped
global function OnWeaponActivate_titanweapon_shift_core_sword
global function OnWeaponDeactivate_titanweapon_shift_core_sword
global function OnWeaponPrimaryAttack_titanweapon_shift_core_sword
global function MpTitanweaponShiftCoreSword_Init

void function MpTitanweaponShiftCoreSword_Init()
{

}

void function OnWeaponActivate_titanweapon_shift_core_sword( entity weapon )
{
	thread PlaySwordCoreFX_OnShow( weapon )
}

void function PlaySwordCoreFX_OnShow( entity weapon )
{
	weapon.EndSignal( "OnDestroy" )
	while( weapon.GetModelName() == $"models/dev/empty_model.mdl" )
		WaitFrame()

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
	CodeCallback_OnMeleePressed( owner )
	return 1
}