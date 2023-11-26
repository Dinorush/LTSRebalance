untyped
global function OnWeaponPrimaryAttack_titanweapon_shift_core_sword
global function MpTitanweaponShiftCoreSword_Init

void function MpTitanweaponShiftCoreSword_Init()
{

}

var function OnWeaponPrimaryAttack_titanweapon_shift_core_sword( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	CodeCallback_OnMeleePressed( owner )
	return 1
}