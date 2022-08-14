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
global function WeaponIsIonVortex

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
	RegisterNetworkedVariable( "LTSRebalance_CounterReadyCharge", SNDC_PLAYER_EXCLUSIVE, SNVT_FLOAT_RANGE, 0.0, 0.0, 1.0 )
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
		AddSpawnCallback( "npc_titan", LTSRebalance_ApplyChanges )
		AddSoulTransferFunc( LTSRebalance_TransferSharedEnergy )
		AddCallback_OnPlayerRespawned( LTSRebalance_GiveWeaponMod )
		AddCallback_OnPilotBecomesTitan( LTSRebalance_HandleSetfiles )
		AddCallback_OnTitanBecomesPilot( LTSRebalance_GiveBatteryOnEject )
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
	table damageSourceTable = expect table( getconsttable()["eDamageSourceId"] )
	damageSourceTable.mp_titanweapon_predator_cannon_ltsrebalance <- eDamageSourceId.mp_titanweapon_predator_cannon
	damageSourceTable.mp_titanweapon_predator_cannon_perfectkits <- eDamageSourceId.mp_titanweapon_predator_cannon
	damageSourceTable.mp_titanweapon_vortex_shield_ion_ltsrebalance <- eDamageSourceId.mp_titanweapon_vortex_shield_ion

	#if SERVER
	PrecacheWeapon( "mp_titanability_unstable_reactor")
	PrecacheWeapon( "mp_titanweapon_shift_core_sword" )
	PrecacheWeapon( "mp_titanweapon_predator_cannon_ltsrebalance" )
	PrecacheWeapon( "mp_titanweapon_predator_cannon_perfectkits" )
	PrecacheWeapon( "mp_titanweapon_vortex_shield_ion_ltsrebalance" )
	#endif
}

// Similar to Precache, called client & server. However, only occurs if Rebalance is on, which can mess some things up
void function LTSRebalance_WeaponInit()
{
	LTSRebalance_AddPassive( "PAS_UNSTABLE_REACTOR" )
	LTSRebalance_AddPassive( "PAS_BATTERY_EJECT" )
	MpTitanweaponShiftCoreSword_Init()
	RegisterWeaponDamageSourceName( "mp_weapon_arc_blast", "Unstable Reactor" ) // monopolizing Arc Blast for our purposes (it doesn't have a name anyway)
}

void function LTSRebalance_AddPassive( string name )
{
	if ( name in ePassives )
		return

	table passives = expect table( getconsttable()["ePassives"] )
	passives[name] <- passives.len() // ePassives starts at 0
}

#if SERVER
void function LTSRebalance_GiveWeaponMod( entity player )
{
	player.GiveExtraWeaponMod( "LTSRebalance" )
}

void function LTSRebalance_ApplyChanges( entity titan )
{
	LTSRebalance_HandleAttachments( titan )

	entity soul = titan.GetTitanSoul()
	if( !IsValid( soul ) )
		return

	// HACK - Extend passives array since we can't edit the method that returns the number of existing passives.
	//        Need to add one for each new passive and one to account for PAS_NUMBER (as we need the array to align above it)
	if ( soul.passives.len() == GetNumPassives() )
		soul.passives.append( false )
	soul.passives.extend( [ false, false ] )

	if ( SoulHasPassive( soul, ePassives.PAS_ANTI_RODEO ) )
		thread LTSRebalance_SyncCounterReadyCharge( soul )

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
		titan.SetTitle( "#NPC_AUTO_TITAN" )
		UpdateNPCForAILethality( titan ) // JFS - I don't know if AI lethality would get updated anyway
	}

	if ( SoulHasPassive( soul, ePassives.PAS_BUILD_UP_NUCLEAR_CORE ) )
	{
		TakePassive( soul, ePassives.PAS_BUILD_UP_NUCLEAR_CORE )
		GivePassive( soul, ePassives.PAS_UNSTABLE_REACTOR )
		titan.GiveOffhandWeapon( "mp_titanability_unstable_reactor", OFFHAND_INVENTORY )
	}

	if ( SoulHasPassive( soul, ePassives.PAS_AUTO_EJECT ) )
	{
		TakePassive( soul, ePassives.PAS_AUTO_EJECT )
		GivePassive( soul, ePassives.PAS_BATTERY_EJECT )
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

	entity defensive = titan.GetOffhandWeapon( OFFHAND_LEFT )
	if ( IsValid( defensive ) )
	{
		string weaponName = defensive.GetWeaponClassName()
		switch ( weaponName )
		{
			case "mp_titanweapon_vortex_shield_ion":
				array<string> mods = defensive.GetMods()
				titan.TakeOffhandWeapon( OFFHAND_LEFT )
				titan.GiveOffhandWeapon( weaponName + "_ltsrebalance", OFFHAND_LEFT, mods )
		}
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

		entity soul = titan.GetTitanSoul()
		switch ( weapon.GetWeaponClassName() )
		{
			case "mp_titanability_hover":
				if ( IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_NORTHSTAR_FLIGHTCORE ) )
					weaponMods.append( "LTSRebalance_pas_northstar_hover" )
			default:
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

// We need to thread the shared energy transfer since the energy is set after transfer callbacks
void function LTSRebalance_TransferSharedEnergy( entity soul, entity destEnt, entity srcEnt )
{
	if ( IsValid( srcEnt ) )
    	thread TransferSharedEnergy_Think( destEnt, srcEnt )
}

void function TransferSharedEnergy_Think( entity destEnt, entity srcEnt )
{
	int energy = srcEnt.GetSharedEnergyCount()
	WaitEndFrame()
	if ( IsValid ( destEnt ) )
	{
		destEnt.TakeSharedEnergy( destEnt.GetSharedEnergyCount() )
    	destEnt.AddSharedEnergy( energy )
	}
}

void function LTSRebalance_GiveBatteryOnEject( entity player, entity titan )
{
	if ( player.p.lastEjectTime == Time() && SoulHasPassive( titan.GetTitanSoul(), ePassives.PAS_BATTERY_EJECT ) )
	{
		Rodeo_GiveBatteryToPlayer( player )
		EnableCloak( player, 7.0 )
	}
}

void function LTSRebalance_SyncCounterReadyCharge( entity soul )
{
	soul.EndSignal( "OnDestroy" )

	float charge = 1.0
	float lastTime = Time()
	while( true )
	{
		WaitFrame()
		entity titan = soul.GetTitan()
		if ( !IsValid( titan ) )
		{
			lastTime = Time()
			continue
		}
		
		charge = min( 1.0, charge + ( Time() - lastTime ) / LTSREBALANCE_COUNTER_READY_REGEN_TIME )
		entity player = titan.IsPlayer() ? titan : GetPetTitanOwner( titan )
		if ( IsValid( player ) )
			player.SetPlayerNetFloat( "LTSRebalance_CounterReadyCharge", charge )

		if ( charge == 1.0 )
		{
			if ( IsValid( player ) )
				Remote_CallFunction_NonReplay( player, "ServerCallback_RewardReadyMessage", (Time() - GetPlayerLastRespawnTime( player )) )
			GiveOffhandElectricSmoke( titan )
			entity smoke = titan.GetOffhandWeapon( OFFHAND_INVENTORY )
			smoke.WaitSignal( "CounterReadyUse" )
			charge = 0
			player.SetPlayerNetFloat( "LTSRebalance_CounterReadyCharge", charge )
		}

		lastTime = Time()
	}
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

bool function WeaponIsIonVortex( entity weapon )
{
	if ( !IsValid( weapon ) )
		return false

	string name = weapon.GetWeaponClassName()
	return name == "mp_titanweapon_vortex_shield_ion" || name == "mp_titanweapon_vortex_shield_ion_ltsrebalance"
}