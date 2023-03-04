/* LTS Rebalance replaces this file for the following reasons:
   1. Implement baseline Sword Core changes
   2. Implement LTS Rebalance Highlander
*/
untyped
global function OnWeaponActivate_titanweapon_sword
global function OnWeaponDeactivate_titanweapon_sword
global function MpTitanWeaponSword_Init

global const asset SWORD_GLOW_FP = $"P_xo_sword_core_hld_FP"
global const asset SWORD_GLOW = $"P_xo_sword_core_hld"

global const asset SWORD_GLOW_PRIME_FP = $"P_xo_sword_core_PRM_FP"
global const asset SWORD_GLOW_PRIME = $"P_xo_sword_core_PRM"

const float WAVE_SEPARATION = 100
const float PAS_RONIN_SWORDCORE_COOLDOWN = 0.15 // .15

void function MpTitanWeaponSword_Init()
{
	PrecacheParticleSystem( SWORD_GLOW_FP )
	PrecacheParticleSystem( SWORD_GLOW )

	PrecacheParticleSystem( SWORD_GLOW_PRIME_FP )
	PrecacheParticleSystem( SWORD_GLOW_PRIME )

	#if SERVER
		if ( LTSRebalance_EnabledOnInit() )
		{
       	 	AddDamageCallbackSourceID( eDamageSourceId.melee_titan_sword, Sword_DamagedTarget )
			RegisterSignal( "HighlanderDeploy" )
			RegisterSignal( "HighlanderEnd" )
		}

		AddDamageCallbackSourceID( eDamageSourceId.mp_titancore_shift_core, Sword_DamagedTarget )
	#endif
}

void function OnWeaponActivate_titanweapon_sword( entity weapon )
{
	if ( weapon.HasMod( "super_charged" ) || weapon.HasMod( "LTSRebalance_super_charged" ) )
	{
		if ( weapon.HasMod( "modelset_prime" ) )
			weapon.PlayWeaponEffectNoCull( SWORD_GLOW_PRIME_FP, SWORD_GLOW_PRIME, "sword_edge" )
		else
			weapon.PlayWeaponEffectNoCull( SWORD_GLOW_FP, SWORD_GLOW, "sword_edge" )
	}
}

/*void function DelayedSwordCoreFX( entity weapon )
{
	weapon.EndSignal( "WeaponDeactivateEvent" )
	weapon.EndSignal( "OnDestroy" )

	WaitFrame()

	weapon.PlayWeaponEffectNoCull( SWORD_GLOW_FP, SWORD_GLOW, "sword_edge" )
}*/

void function OnWeaponDeactivate_titanweapon_sword( entity weapon )
{
	if ( weapon.HasMod( "modelset_prime" ) )
		weapon.StopWeaponEffect( SWORD_GLOW_PRIME_FP, SWORD_GLOW_PRIME )
	else
		weapon.StopWeaponEffect( SWORD_GLOW_FP, SWORD_GLOW )

}

#if SERVER
void function Sword_DamagedTarget( entity target, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity soul = attacker.GetTitanSoul()

    if ( LTSRebalance_Enabled() && IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_RONIN_SWORDCORE ) )
    {
		thread LTSRebalance_HighlanderFastDeploy( attacker )
        entity offhand
        foreach ( index in [ OFFHAND_LEFT, OFFHAND_ANTIRODEO, OFFHAND_RIGHT ] )
        {
            offhand = attacker.GetOffhandWeapon( index )
            if ( !offhand )
                continue

            int maxAmmo = offhand.GetWeaponPrimaryClipCountMax()
            int newAmmo = minint( maxAmmo, offhand.GetWeaponPrimaryClipCount() + int( maxAmmo * PAS_RONIN_SWORDCORE_COOLDOWN ) )
            offhand.SetWeaponPrimaryClipCountNoRegenReset( newAmmo )
        }
    }

    if ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) != eDamageSourceId.mp_titancore_shift_core )
        return

	entity coreWeapon = attacker.GetOffhandWeapon( OFFHAND_EQUIPMENT )
	if ( !IsValid( coreWeapon ) )
		return

	if ( ( coreWeapon.HasMod( "fd_duration" ) || coreWeapon.HasMod( "LTSRebalance_fd_duration" ) ) && IsValid( soul ) )
	{
		int shieldRestoreAmount = target.GetArmorType() == ARMOR_TYPE_HEAVY ? 500 : 250
		soul.SetShieldHealth( min( soul.GetShieldHealth() + shieldRestoreAmount, soul.GetShieldHealthMax() ) )
	}
}

void function LTSRebalance_HighlanderFastDeploy( entity titan )
{
	titan.Signal( "HighlanderDeploy" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "HighlanderDeploy" )
	foreach ( index in [ OFFHAND_LEFT, OFFHAND_RIGHT, OFFHAND_MELEE ] )
	{
		entity offhand = titan.GetOffhandWeapon( index )
		if ( IsValid( offhand ) )
			offhand.AddMod( "fast_deploy" )
	}

	wait 0.2

	waitthread WaitSignalOrTimeout( titan, 9999.0, "HighlanderEnd", "OnPrimaryAttack" )

	foreach ( index in [ OFFHAND_LEFT, OFFHAND_RIGHT, OFFHAND_MELEE ] )
	{
		entity offhand = titan.GetOffhandWeapon( index )
		if ( IsValid( offhand ) )
			offhand.RemoveMod( "fast_deploy" )
	}
}
#endif