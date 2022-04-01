untyped
global function LTSRebalance_PreInit
global function LTSRebalance_Init
global function LTSRebalance_Enabled
global function LTSRebalance_EnabledOnInit
global function LTSRebalance_Precache
global function PerfectKits_Enabled
global function PerfectKits_EnabledOnInit
global function OnWeaponAttemptOffhandSwitch_WeaponHasAmmoToUse
global function WeaponHasAmmoToUse

struct {
	bool ltsrebalance_enabled = false
	bool perfectkits_enabled = false
} file

void function LTSRebalance_PreInit()
{
	AddCallback_OnRegisteringCustomNetworkVars( LTSRebalance_RegisterRemote )
}

void function LTSRebalance_RegisterRemote()
{
	Remote_RegisterFunction( "ServerCallback_TemperedPlating_UpdateBurnTime" )
}

void function LTSRebalance_Init()
{
	AddPrivateMatchModeSettingEnum( "#MODE_SETTING_CATEGORY_PROMODE", "ltsrebalance_enable", [ "#SETTING_DISABLED", "#SETTING_ENABLED" ], "0" )
	AddPrivateMatchModeSettingEnum( "#MODE_SETTING_CATEGORY_PROMODE", "perfectkits_enable", [ "#SETTING_DISABLED", "#SETTING_ENABLED" ], "0" )
	LTSRebalance_Precache()

	file.ltsrebalance_enabled = LTSRebalance_EnabledOnInit()
	file.perfectkits_enabled = PerfectKits_EnabledOnInit()

	// If spawn callbacks call LTSRebalance first, it will mess up kit checks, so call it in Rebalance if both are on
	if ( file.perfectkits_enabled )
	{

		#if SERVER
		if ( !file.ltsrebalance_enabled )
			AddSpawnCallback( "npc_titan", PerfectKits_HandleAttachments )
		#endif
	}

	if ( !file.ltsrebalance_enabled )
		return

	LTSRebalance_WeaponInit()
	#if SERVER
		AddSpawnCallback( "npc_titan", GiveLTSRebalanceTitanMod )
		AddCallback_OnTitanHealthSegmentLost( UnstableReactor_OnSegmentLost )
		AddCallback_OnPlayerKilled( UnstableReactor_OnDeath )
		AddCallback_OnNPCKilled( UnstableReactor_OnDeath )
		AddCallback_OnPlayerRespawned( GiveLTSRebalanceWeaponMod )
		AddCallback_OnPilotBecomesTitan( LTSRebalance_HandleSetfiles )
	#else
		AddCallback_OnClientScriptInit( ClLTSRebalance_ClientScripts )
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

bool function PerfectKits_EnabledOnInit()
{
	return GetCurrentPlaylistVarInt( "perfectkits_enable", 0 ) == 1
}

bool function PerfectKits_Enabled() 
{
	return file.perfectkits_enabled
}

void function LTSRebalance_Precache()
{
	PrecacheWeapon( "mp_titanweapon_shift_core_sword" )
	PrecacheWeapon( "mp_titanweapon_predator_cannon_ltsrebalance" )
	PrecacheWeapon( "mp_titanweapon_predator_cannon_perfectkits" )
	table damageSourceTable = expect table( getconsttable()["eDamageSourceId"] )
	damageSourceTable.mp_titanweapon_predator_cannon_ltsrebalance <- eDamageSourceId.mp_titanweapon_predator_cannon
	damageSourceTable.mp_titanweapon_predator_cannon_perfectkits <- eDamageSourceId.mp_titanweapon_predator_cannon
}

void function LTSRebalance_WeaponInit()
{
	MpTitanweaponShiftCoreSword_Init()
	RegisterWeaponDamageSourceName( "mp_weapon_arc_blast", "Unstable Reactor" ) // monopolizing Arc Blast for our purposes (it doesn't have a name anyway)
}

#if SERVER
void function GiveLTSRebalanceWeaponMod( entity player )
{
	player.GiveExtraWeaponMod( "LTSRebalance" )
}

void function GiveLTSRebalanceTitanMod( entity titan )
{
	LTSRebalance_HandleAttachments( titan )

	entity soul = titan.GetTitanSoul()
	if( !IsValid( soul ) )
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

void function PerfectKits_HandleAttachments( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_VANGUARD_COREMETER ) )
		soul.s.energy_thief_dash_scale <- 1.0

	if ( IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_SCORCH_SELFDMG ) )
		thread PerfectKits_TemperedPlating_SlowThink( soul )

	array<entity> weapons = titan.GetMainWeapons()
	if ( weapons.len() > 0 ) // We replace certain weapons that would cause errors in vanilla or need new files for other reasons
	{
		string weaponName = weapons[0].GetWeaponClassName()
		switch ( weaponName )
		{
			case "mp_titanweapon_predator_cannon":
				array<string> mods = weapons[0].GetMods()
				titan.TakeWeaponNow( weaponName )
				titan.GiveWeapon( weaponName + "_perfectkits", mods )
		}
		weapons = titan.GetMainWeapons()
	}
	weapons.extend( titan.GetOffhandWeapons() )

	foreach ( weapon in weapons )
	{
		array<string> weaponMods = weapon.GetMods()
		array<string> globalMods = GetWeaponMods_Global( weapon.GetWeaponClassName() )
		for ( int i = weaponMods.len() - 1; i >= 0; i-- )
		{
			string replaceMod = "PerfectKitsReplace_" + weaponMods[i]
			string perfectMod = "PerfectKits_" + weaponMods[i]
			if ( globalMods.contains( replaceMod ) )
			{
				weaponMods.remove(i)
				weaponMods.append( replaceMod )
			}
			else if ( globalMods.contains( perfectMod ) )
				weaponMods.append( perfectMod )
		}

		if ( weapon.GetWeaponClassName() == "mp_titanability_particle_wall" && IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_TONE_WALL ) )
			weaponMods.append( "PerfectKits_pas_tone_wall" )

		if ( weapon.GetWeaponClassName() == "mp_titanweapon_stun_laser" && IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) )
			weaponMods.append( "PerfectKits_pas_vanguard_shield" )

		weapon.SetMods( weaponMods )
		if( weapon.GetWeaponPrimaryClipCountMax() > 0 )
			weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
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
				array<string> mods = weapons[0].GetMods()
				titan.TakeWeaponNow( weaponName )
				titan.GiveWeapon( weaponName + "_ltsrebalance", mods )
		}
		weapons = titan.GetMainWeapons()
	}
	if ( file.perfectkits_enabled )
		PerfectKits_HandleAttachments( titan )

	weapons.extend( titan.GetOffhandWeapons() )

	string prefix = "LTSRebalance_"
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

		if ( weaponMods.contains( "PerfectKits_pas_ion_weapon_ads" ) )
		{
			entity laser = titan.GetOffhandWeapon( OFFHAND_RIGHT )
			if ( IsValid( laser ) && laser.GetWeaponClassName() == "mp_titanweapon_laser_lite" )
				laser.AddMod( "PerfectKits_refrac_balance" )
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
#else
void function ClLTSRebalance_ClientScripts( entity player )
{
	thread ClLTSRebalance_LightCannonUIThink()
}

void function ClLTSRebalance_LightCannonUIThink()
{
	LTSRebalance_BarTopoData bg = LTSRebalance_BasicImageBar_CreateRuiTopo( <0, 0, 0>, < -0.417, 0.25, 0.0 >, 0.11, 0.03 )
	RuiSetFloat3( bg.imageRuis[0], "basicImageColor", < 0, 0, 0 > )
	RuiSetFloat( bg.imageRuis[0], "basicImageAlpha", 0 )
	LTSRebalance_BarTopoData coreCharges = LTSRebalance_BasicImageBar_CreateRuiTopo( <0, 0, 0>, < -0.417, 0.25, 0.0 >, 0.1, 0.01 )
	LTSRebalance_BasicImageBar_UpdateSegmentCount( coreCharges, 3, 0.075 )
	LTSRebalance_BasicImageBar_SetFillFrac( coreCharges, 0.0 )
	int last = 0
	while( true )
	{
		WaitFrame()

		entity player = GetLocalClientPlayer()

		if ( !ClLTSRebalance_ShouldRenderLightCannonUI( player ) )
		{				
			LTSRebalance_BasicImageBar_SetFillFrac( coreCharges, 0.0 )

			// Only clear background when the last core finishes
			if ( IsValid( player ) )
			{
				entity core = player.GetOffhandWeapon( OFFHAND_EQUIPMENT )
				if ( !IsValid( core ) || !("laserCoreCount" in core.s) || core.s.laserCoreCount == 0 )
					RuiSetFloat( bg.imageRuis[0], "basicImageAlpha", 0.0 )
			}
			continue
		}
		
		RuiSetFloat( bg.imageRuis[0], "basicImageAlpha", 0.5 )
		entity core = player.GetOffhandWeapon( OFFHAND_EQUIPMENT )
		int count = LTSREBALANCE_PAS_ION_LASERCANNON_COUNT
		if ( "laserCoreCount" in core.s )
			count -= expect int( core.s.laserCoreCount )
		LTSRebalance_BasicImageBar_SetFillFrac( coreCharges, float( count ) / float( LTSREBALANCE_PAS_ION_LASERCANNON_COUNT ) )
	}
}

bool function ClLTSRebalance_ShouldRenderLightCannonUI( entity player )
{
	if ( !IsValid( player ) || !player.IsTitan() )
		return false

	entity soul = player.GetTitanSoul()
	if ( !IsValid( soul ) )
		return false

	entity core = player.GetOffhandWeapon( OFFHAND_EQUIPMENT )
	if ( !IsValid( core ) || !core.HasMod( "LTSRebalance_pas_ion_lasercannon" ) )
		return false

	float coreAvailableFrac = soul.GetTitanSoulNetFloat( "coreAvailableFrac" )
	if ( coreAvailableFrac < 1.0 )
		return false

	return true
}
#endif

bool function WeaponHasAmmoToUse( entity weapon )
{
	return weapon.GetWeaponPrimaryClipCount() >= weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}

bool function OnWeaponAttemptOffhandSwitch_WeaponHasAmmoToUse( entity weapon )
{
	if ( !LTSRebalance_Enabled() )
		return true

	return WeaponHasAmmoToUse( weapon )
}