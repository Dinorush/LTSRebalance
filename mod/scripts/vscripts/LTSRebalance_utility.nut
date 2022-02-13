untyped
global function WeaponHasAmmoToUse
global function LTSRebalance_Init
global function LTSRebalance_Enabled
global function LTSRebalance_EnabledOnInit
global function LTSRebalance_Precache

struct {
	bool ltsrebalance_enabled = false
} file

void function LTSRebalance_Init()
{
	RegisterWeaponDamageSourceName( "mp_weapon_arc_blast", "Unstable Reactor" ) // monopolizing Arc Blast for our purposes (it doesn't have a name anyway)
	AddPrivateMatchModeSettingEnum( "#MODE_SETTING_CATEGORY_PROMODE", "ltsrebalance_enable", [ "#SETTING_DISABLED", "#SETTING_ENABLED" ], "0" )

	file.ltsrebalance_enabled = LTSRebalance_EnabledOnInit()
	LTSRebalance_Precache()
	#if SERVER
		LTSRebalance_RecompileKeyValues() // Recompiles KeyValues if it detects that LTSRebalance weapon mods are missing
		if ( !file.ltsrebalance_enabled )
			return
		MpTitanweaponShiftCoreSword_Init()
		
		AddSpawnCallback( "npc_titan", GiveLTSRebalanceTitanMod )
		AddCallback_OnTitanHealthSegmentLost( UnstableReactor_OnSegmentLost )
		AddCallback_OnPlayerKilled( UnstableReactor_OnDeath )
		AddCallback_OnNPCKilled( UnstableReactor_OnDeath )
		AddCallback_OnPlayerRespawned( GiveLTSRebalanceWeaponMod )
		AddCallback_OnPilotBecomesTitan( LTSRebalance_HandleSetfiles )
	#endif
}

// For use in inits, when the file variable may not have been set yet
bool function LTSRebalance_EnabledOnInit()
{
	return GetCurrentPlaylistVarInt( "ltsrebalance_enable", 0 ) == 1
}

// For general use, since I dunno if getting the playlist var as many times as I need to is performant
bool function LTSRebalance_Enabled() 
{
	return file.ltsrebalance_enabled
}

void function LTSRebalance_Precache()
{
	if ( !file.ltsrebalance_enabled )
		return

	PrecacheWeapon( "mp_titanweapon_predator_cannon_ltsrebalance" )
	PrecacheWeapon( "mp_titanweapon_sticky_40mm_ltsrebalance" )
	table damageSourceTable = expect table( getconsttable()["eDamageSourceId"] )
	damageSourceTable.mp_titanweapon_predator_cannon_ltsrebalance <- eDamageSourceId.mp_titanweapon_predator_cannon
	damageSourceTable.mp_titanweapon_sticky_40mm_ltsrebalance <- eDamageSourceId.mp_titanweapon_sticky_40mm
}

#if SERVER
void function LTSRebalance_RecompileKeyValues()
{
	if ( !GetConVarBool( "ltsrebalance_force_recompile" ) )
		return

	thread LTSRebalance_RecompileKeyValues_Think()
}

void function LTSRebalance_RecompileKeyValues_Think()
{
	wait 1.0 // Sometimes, reparse can fail if done too early. Might be a better way to handle it, but wait is ez

	string[2] testDummy = [ "mp_titanweapon_sniper", "LTSRebalance" ] // Some weapon and a LTSRebalance mod to check if it was compiled

	int netChanModeOriginal = GetConVarInt( "net_chan_limit_mode" )
	bool svCheatsOriginal = GetConVarBool( "sv_cheats" )
	SetConVarInt( "net_chan_limit_mode", 0 )	// Don't want to kick the player back to main menu when recompiling
	SetConVarBool( "sv_cheats", true )			// Need sv_cheats to execute command
	
	// tries limits this to not run for more than 10s; there are probably bigger issues if that happens
	for ( int tries = 0; !GetWeaponMods_Global( testDummy[0] ).contains( testDummy[1] ) && tries < 10; tries++ )
	{
		ServerCommand( "weapon_reparse" )
		wait 1.0
	}

	SetConVarBool( "sv_cheats", svCheatsOriginal )
	SetConVarInt( "net_chan_limit_mode", netChanModeOriginal )
}

void function GiveLTSRebalanceWeaponMod( entity player )
{
	player.GiveExtraWeaponMod( "LTSRebalance" )
}

void function GiveLTSRebalanceTitanMod( entity titan )
{
	LTSRebalance_HandleAttachments( titan )

	entity soul = titan.GetTitanSoul()
	if( !IsValid( soul ) ) // Should only occur on eject
		return

	if ( SoulHasPassive( soul, ePassives.PAS_ANTI_RODEO ) )
		GiveOffhandElectricSmoke( titan )

	if ( SoulHasPassive( soul, ePassives.PAS_HYPER_CORE ) )
	{
		entity smoke = titan.GetOffhandWeapon( OFFHAND_INVENTORY )
		if ( IsValid( smoke ) )
		{
			if ( smoke.GetWeaponPrimaryAmmoCount() == 0 )
				titan.TakeOffhandWeapon( OFFHAND_INVENTORY )
			else // Should only occur if some mod/sv_cheats gives the titan both Counter Ready and Overcore
				smoke.SetWeaponPrimaryAmmoCount( smoke.GetWeaponPrimaryAmmoCount() - 1 )
		}
	}
	if ( SoulHasPassive( soul, ePassives.PAS_ENHANCED_TITAN_AI ) )
	{
		entity melee = titan.GetMeleeWeapon()
		if ( IsValid( melee ) )
			melee.AddMod( "LTSRebalance_big_punch" )
		TakePassive( soul, ePassives.PAS_ENHANCED_TITAN_AI )
		UpdateNPCForAILethality( titan ) // JFS - I don't know if AI lethality would get updated anyway
	}

	entity owner = titan.GetBossPlayer()
	if ( IsValid( owner ) && PlayerHasPassive( owner, ePassives.PAS_BUILD_UP_NUCLEAR_CORE ) )
	{
		TakePassive( owner, ePassives.PAS_BUILD_UP_NUCLEAR_CORE ) // We don't want normal nuke eject behavior
		array passives = expect array( soul.passives )
		passives[ ePassives.PAS_BUILD_UP_NUCLEAR_CORE ] = true
	}
}

void function LTSRebalance_HandleAttachments( entity titan )
{
	array<entity> weapons = titan.GetMainWeapons()
	if ( weapons.len() > 0 ) // We replace certain weapons that would cause errors in vanilla or need new files for other reasons
	{
		string weaponName = weapons[0].GetWeaponClassName()
		switch ( weaponName )
		{
			case "mp_titanweapon_predator_cannon":
			case "mp_titanweapon_sticky_40mm":
				array<string> mods = weapons[0].GetMods()
				titan.TakeWeaponNow( weaponName )
				titan.GiveWeapon( weaponName + "_ltsrebalance", mods )
		}
	}
	weapons.extend( titan.GetOffhandWeapons() )

	string prefix = "LTSRebalance_"
	int prefixLen = prefix.len()
	foreach ( weapon in weapons )
	{
		array<string> weaponMods = weapon.GetMods()
		array<string> globalMods = GetWeaponMods_Global( weapon.GetWeaponClassName() )
		for ( int i = weaponMods.len() - 1; i >= 0; i-- )
		{
			string rebalMod = prefix + weaponMods[i]
			if ( globalMods.contains( rebalMod ) )
			{
				weaponMods.remove(i)
				weaponMods.append( rebalMod )
			}
		}

		if ( weaponMods.contains( "LTSRebalance_arc_rounds" ) ) // Specific case for Aegis Monarch
			weaponMods.append( "LTSRebalance_base_arc_rounds" )

		if ( globalMods.contains( "LTSRebalance" ) ) // Adds base rebalancing to weapon
			weaponMods.append( "LTSRebalance" )

		weapon.SetMods( weaponMods )
		if( weapon.GetWeaponPrimaryClipCountMax() > 0 )
			weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
	}
}

void function LTSRebalance_HandleSetfiles( entity player, entity titan )
{
	switch( GetTitanCharacterName( player ) )
	{
		case "scorch":
		case "legion":
			array<string> settingsMods = player.GetPlayerSettingsMods()

			if ( settingsMods.contains( "pas_mobility_dash_capacity" ) )
				return
			settingsMods.append( "LTSRebalance" )
			player.SetPlayerSettingsWithMods( player.GetPlayerSettings(), settingsMods )
	}
}

void function UnstableReactor_Blast( entity titan )
{
	thread UnstableReactor_MakeFX( titan )
	RadiusDamage(
		titan.GetWorldSpaceCenter(),			// center
		titan,									// attacker
		titan,									// inflictor
		50,										// damage
		500,									// damageHeavyArmor
		200,									// innerRadius
		500,									// outerRadius
		SF_ENVEXPLOSION_NO_DAMAGEOWNER,			// flags
		0,										// distanceFromAttacker
		0,										// explosionForce
		DF_EXPLOSION|DF_ELECTRICAL,				// scriptDamageFlags
		eDamageSourceId.mp_weapon_arc_blast		// scriptDamageSourceIdentifier
	)			
}

void function UnstableReactor_MakeFX( entity titan )
{
	entity particleSystem = CreateEntity( "info_particle_system" )
	particleSystem.kv.start_active = 1
	particleSystem.SetValueForEffectNameKey( $"P_xo_emp_field" )
	particleSystem.SetOrigin( titan.GetWorldSpaceCenter() )
	DispatchSpawn( particleSystem )

	wait 0.6
	particleSystem.Destroy()
}

void function UnstableReactor_OnSegmentLost( entity titan, entity attacker )
{
	if ( SoulHasPassive( titan.GetTitanSoul(), ePassives.PAS_BUILD_UP_NUCLEAR_CORE ) )
		UnstableReactor_Blast( titan )
}

void function UnstableReactor_OnDeath( entity titan, entity attacker, var damageInfo )
{
	if ( !titan.IsTitan() )
		return

	entity soul = titan.GetTitanSoul()
	if ( SoulHasPassive( titan.GetTitanSoul(), ePassives.PAS_BUILD_UP_NUCLEAR_CORE ) )
		UnstableReactor_Blast( titan )
}
#endif

bool function WeaponHasAmmoToUse( entity weapon )
{
	return weapon.GetWeaponPrimaryClipCount() >= weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}