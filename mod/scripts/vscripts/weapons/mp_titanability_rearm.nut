//TODO: FIX REARM WHILE FIRING SALVO ROCKETS

global function OnWeaponPrimaryAttack_titanability_rearm
global function OnWeaponAttemptOffhandSwitch_titanability_rearm

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanability_rearm
#endif

const float REARM_AND_RELOAD_BUFF_TIME = 3.0

var function OnWeaponPrimaryAttack_titanability_rearm( entity weapon, WeaponPrimaryAttackParams attackParams )
{
    if ( weapon.GetWeaponChargeFraction() < 1 )
        return 0
        
	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	entity ordnance = weaponOwner.GetOffhandWeapon( OFFHAND_RIGHT )
	if ( IsValid( ordnance ) )
	{
		ordnance.SetWeaponPrimaryClipCount( ordnance.GetWeaponPrimaryClipCountMax() )
		#if SERVER
		if ( ordnance.IsChargeWeapon() )
			ordnance.SetWeaponChargeFractionForced( 0 )
		#endif
	}
	entity defensive = weaponOwner.GetOffhandWeapon( OFFHAND_LEFT )
	if ( IsValid( defensive ) )
		defensive.SetWeaponPrimaryClipCount( defensive.GetWeaponPrimaryClipCountMax() )

    if( weapon.HasMod( "rapid_rearm" ) && weaponOwner.GetMainWeapons().len() > 0)
    { 
		thread GiveReloadBuffThink( weaponOwner.GetMainWeapons()[0], weaponOwner )
    }
        
	#if SERVER
	if ( weaponOwner.IsPlayer() )//weapon.HasMod( "rapid_rearm" ) &&  )
			weaponOwner.Server_SetDodgePower( 100.0 )
	#endif
	weapon.SetWeaponPrimaryClipCount( 0 )//used to skip the fire animation
	return 0
}

void function GiveReloadBuffThink( entity weapon, entity weaponOwner )
{
    #if CLIENT
    entity cockpit = weaponOwner.GetCockpit()
    int cockpitHandle = StartParticleEffectOnEntity( cockpit, GetParticleSystemIndex( $"P_core_DMG_boost_screen" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
    #else
    weapon.AddMod( "rapid_reload" )
	#endif

    wait REARM_AND_RELOAD_BUFF_TIME

	#if CLIENT
	if ( EffectDoesExist( cockpitHandle ) )
        EffectStop( cockpitHandle, false, true )
	#else
	if ( IsValid( weapon ) && weapon.HasMod( "rapid_reload" ) )
		weapon.RemoveMod( "rapid_reload" )
    #endif
}

#if SERVER
var function OnWeaponNPCPrimaryAttack_titanability_rearm( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanability_rearm( weapon, attackParams )
}
#endif

bool function OnWeaponAttemptOffhandSwitch_titanability_rearm( entity weapon )
{
	bool allowSwitch = true
	entity weaponOwner = weapon.GetWeaponOwner()

	entity ordnance = weaponOwner.GetOffhandWeapon( OFFHAND_RIGHT )
	entity defensive = weaponOwner.GetOffhandWeapon( OFFHAND_LEFT )

	if ( ordnance.GetWeaponPrimaryClipCount() == ordnance.GetWeaponPrimaryClipCountMax() && defensive.GetWeaponPrimaryClipCount() == defensive.GetWeaponPrimaryClipCountMax() )
		allowSwitch = false

	if ( ordnance.IsBurstFireInProgress() )
		allowSwitch = false

	if ( ordnance.IsChargeWeapon() && ordnance.GetWeaponChargeFraction() > 0.0 )
		allowSwitch = true

	//if ( weapon.HasMod( "rapid_rearm" ) )
	//{
		if ( weaponOwner.GetDodgePower() < 100 )
			allowSwitch = true
	//}

	if( !allowSwitch && IsFirstTimePredicted() )
	{
		// Play SFX and show some HUD feedback here...
		#if CLIENT
			AddPlayerHint( 1.0, 0.25, $"rui/titan_loadout/tactical/titan_tactical_rearm", "#WPN_TITANABILITY_REARM_ERROR_HINT" )
			if ( weaponOwner == GetLocalViewPlayer() )
				EmitSoundOnEntity( weapon, "titan_dryfire" )
		#endif
	}

	return allowSwitch
}

//UPDATE TO RESTORE CHARGE FOR THE MTMS