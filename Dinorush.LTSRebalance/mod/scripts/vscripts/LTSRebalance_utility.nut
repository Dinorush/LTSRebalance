untyped
global function LTSRebalance_PreInit
global function LTSRebalance_Init
global function LTSRebalance_Enabled
global function LTSRebalance_EnabledOnInit
global function LTSRebalance_Precache
global function PerfectKits_Enabled
global function PerfectKits_EnabledOnInit
global function LTSRebalance_DamageInfo_GetWeapon

global function OnWeaponAttemptOffhandSwitch_WeaponHasAmmoToUse
global function WeaponHasAmmoToUse

#if SERVER
global function LTSRebalance_OvercoreShieldDamage
#endif

struct {
	bool ltsrebalance_enabled = false
	bool perfectkits_enabled = false
	int perfectkits_friendlies = 0
} file

const float PERFECTKITS_OVERCORE_GAIN = 0.01
const float PERFECTKITS_OVERCORE_DRAIN_FRAC = 0.01
const int PERFECTKITS_OVERCORE_MIN_DAMAGE = 50

global const float PERFECTKITS_COUNTER_READY_MOD = 5.0

const float PERFECTKITS_FRIENDLY_MODE_DOWNTIME = 10.0
const float PERFECTKITS_FRIENDLY_MODE_UPTIME = 5.0
const float PERFECTKITS_FRIENDLY_MODE_FRAGILE_MOD = 2.0

const float PERFECTKITS_ICE_THRESHOLD_STOP_DIST_FRAC = 0.6
const int PERFECTKITS_ICE_THRESHOLD_STOP_ITER = 3

const float PERFECTKITS_TURBO_DAMAGE_CONV = 0.0004

void function LTSRebalance_PreInit()
{
	AddCallback_OnRegisteringCustomNetworkVars( LTSRebalance_RegisterRemote )
}

void function LTSRebalance_RegisterRemote()
{
	Remote_RegisterFunction( "ServerCallback_TemperedPlating_UpdateBurnTime" )
	Remote_RegisterFunction( "ServerCallback_UnstableReactor_Ready" )
	RegisterNetworkedVariable( "LTSRebalance_Kit1Charge", SNDC_PLAYER_EXCLUSIVE, SNVT_FLOAT_RANGE, 0.0, 0.0, 1.0 )
}

void function LTSRebalance_Init()
{
	// Rebalance enum is inverted so it is on by default
	AddPrivateMatchModeSettingEnum( "#MODE_SETTING_CATEGORY_PROMODE", "ltsrebalance_enable", [ "#SETTING_ENABLED", "#SETTING_DISABLED" ], "0" )
	AddPrivateMatchModeSettingEnum( "#MODE_SETTING_CATEGORY_PROMODE", "perfectkits_enable", [ "#SETTING_DISABLED", "#SETTING_ENABLED" ], "0" )
	AddPrivateMatchModeSettingEnum( "#MODE_SETTING_CATEGORY_PROMODE", "ltsrebalance_log_ranked", [ "#SETTING_DISABLED", "#SETTING_ENABLED" ], "0" )

	LTSRebalance_Precache()

	file.ltsrebalance_enabled = LTSRebalance_EnabledOnInit()
	file.perfectkits_enabled = PerfectKits_EnabledOnInit()

	#if SERVER
	if ( file.perfectkits_enabled )
	{
		RegisterSignal( "PerfectKitsIceDash" )
		AddDamageFinalCallback( "player", PerfectKits_FriendlyModeDamage )
		AddDamageFinalCallback( "npc_titan", PerfectKits_FriendlyModeDamage )
		AddPostDamageCallback( "player", PerfectKits_TurboDamage )
		AddPostDamageCallback( "npc_titan", PerfectKits_TurboDamage )
		AddCallback_OnPilotBecomesTitan( PerfectKits_FriendlyMode )
		AddCallback_OnPilotBecomesTitan( PerfectKits_HandleSetfiles )
		AddCallback_OnTitanBecomesPilot( PerfectKits_NukeDisembark )
	}
	#endif

	if ( !file.ltsrebalance_enabled )
	{
		// If spawn callbacks call LTSRebalance first, it will mess up kit checks, so call it in Rebalance if both are on
		#if SERVER
		if ( file.perfectkits_enabled )
			AddSpawnCallback( "npc_titan", PerfectKits_HandleAttachments )
		#endif
		return
	}

	LTSRebalance_WeaponInit()
	#if SERVER
		if ( GAMETYPE == LAST_TITAN_STANDING && GetConVarBool( "randomize_rebal_lts_spawn" ) && RandomFloat( 1.0 ) < 0.5 )
			AddSpawnCallback( "info_spawnpoint_titan_start", LTSRebalance_FlipSpawns )
		AddSpawnCallback( "npc_titan", LTSRebalance_ApplyChanges )
		AddSoulTransferFunc( LTSRebalance_TransferSharedEnergy )
		AddCallback_OnPlayerRespawned( LTSRebalance_GiveWeaponMod )
		AddCallback_OnPilotBecomesTitan( LTSRebalance_HandleSetfiles )
		AddCallback_OnTitanBecomesPilot( LTSRebalance_GiveBatteryOnEject )
		AddPostDamageCallback( "player", LTSRebalance_OvercoreDamage )
		AddPostDamageCallback( "npc_titan", LTSRebalance_OvercoreDamage )
	#endif
}

// For use in inits, when the file variable may not have been set yet
bool function LTSRebalance_EnabledOnInit()
{
	return GetCurrentPlaylistVarInt( "ltsrebalance_enable", 0 ) == 0
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
	LTSRebalance_AddPassive( "PAS_UNSTABLE_REACTOR" )
	LTSRebalance_AddPassive( "PAS_BATTERY_EJECT" )
	LTSRebalance_AddPassive( "PAS_BIG_PUNCH" )
	RegisterWeaponDamageSourceName( "damagedef_nuclear_core", "Nuclear Disembark" )

	#if SERVER
	PrecacheWeapon( "mp_titanweapon_shift_core_sword" )
	PrecacheWeapon( "mp_titanweapon_predator_cannon_ltsrebalance" )
	PrecacheWeapon( "mp_titanweapon_predator_cannon_perfectkits" )
	RegisterWeaponDamageSource( "mp_titanability_thermite_burn", "#DEATH_THERMITE_BURN" )
	RegisterWeaponDamageSource( "mp_titanability_overcore", "#DEATH_OVERCORE_DRAIN" )
	#endif
}

// Similar to Precache, called client & server. However, only occurs if Rebalance is on, which can mess some things up
void function LTSRebalance_WeaponInit()
{
	MpTitanweaponShiftCoreSword_Init()
	MpTitanabilityPhaseDashInit()
	#if SERVER
	MpTitanabilityUnstableReactorInit()
	#endif
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

// We have to delay this so map-specific spawn point editors can run their code first
void function LTSRebalance_FlipSpawns( entity spawn )
{
	thread LTSRebalance_FlipSpawnDelayed( spawn )
}

void function LTSRebalance_FlipSpawnDelayed( entity spawn )
{
	WaitEndFrame()
	if ( IsValid( spawn ) )
		SetTeam( spawn, TEAM_IMC + TEAM_MILITIA - spawn.GetTeam() )
}

void function LTSRebalance_ApplyChanges( entity titan )
{
	LTSRebalance_HandleAttachments( titan )

	entity soul = titan.GetTitanSoul()
	if( !IsValid( soul ) )
		return

	entity player = soul.GetBossPlayer()
	if ( IsValid( player ) )
		player.SetPlayerNetFloat( "LTSRebalance_Kit1Charge", 0.0 )

	// HACK - Extend passives array since we can't edit the method that returns the number of existing passives.
	//        Need to add one for each new passive and one to account for PAS_NUMBER (as we need the array to align above it)
	if ( soul.passives.len() == GetNumPassives() )
		soul.passives.append( false )
	soul.passives.extend( [ false, false, false ] )

	int uiPassive = -1
	if ( SoulHasPassive( soul, ePassives.PAS_ANTI_RODEO ) )
	{
		uiPassive = ePassives.PAS_ANTI_RODEO
		thread LTSRebalance_SyncCounterReadyCharge( soul )
	}

	if ( SoulHasPassive( soul, ePassives.PAS_HYPER_CORE ) )
	{
		uiPassive = ePassives.PAS_HYPER_CORE
		SoulTitanCore_SetNextAvailableTime( soul, 0.0 )
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
		GivePassive( soul, ePassives.PAS_BIG_PUNCH )
		titan.SetTitle( "#NPC_AUTO_TITAN" )
		UpdateNPCForAILethality( titan ) // JFS - I don't know if AI lethality would get updated anyway
	}

	if ( SoulHasPassive( soul, ePassives.PAS_BUILD_UP_NUCLEAR_CORE ) )
	{
		uiPassive = ePassives.PAS_UNSTABLE_REACTOR
		TakePassive( soul, ePassives.PAS_BUILD_UP_NUCLEAR_CORE )
		GivePassive( soul, ePassives.PAS_UNSTABLE_REACTOR )
		if ( IsValid( player ) )
			UnstableReactor_InitForPlayer( player, soul )
	}

	if ( SoulHasPassive( soul, ePassives.PAS_AUTO_EJECT ) )
	{
		uiPassive = ePassives.PAS_BATTERY_EJECT
		TakePassive( soul, ePassives.PAS_AUTO_EJECT )
		GivePassive( soul, ePassives.PAS_BATTERY_EJECT )
	}

	if ( IsValid( player ) )
		ServerToClientStringCommand( player, "ltsrebalance_set_ui_passive " + uiPassive.tostring() )
}

void function PerfectKits_HandlePassives( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return

	if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_COREMETER ) )
		soul.s.energy_thief_dash_scale <- 1.0

	if ( SoulHasPassive( soul, ePassives.PAS_SCORCH_SELFDMG ) )
		thread PerfectKits_TemperedPlating_SlowThink( soul )

	if ( SoulHasPassive( soul, ePassives.PAS_HYPER_CORE ) )
		thread PerfectKits_OvercoreThink( soul )

	if ( SoulHasPassive( soul, ePassives.PAS_BUILD_UP_NUCLEAR_CORE ) )
	{
	}

	if ( SoulHasPassive( soul, ePassives.PAS_RONIN_SWORDCORE ) )
		titan.TakeOffhandWeapon( OFFHAND_LEFT )

	entity player = soul.GetBossPlayer()
	if ( IsValid( player ) && SoulHasPassive( soul, ePassives.PAS_AUTO_EJECT ) )
	{
		TakePassive( soul, ePassives.PAS_AUTO_EJECT )
		AddPlayerMovementEventCallback( player, ePlayerMovementEvents.DODGE, PerfectKits_IceDash )
	}
}

void function PerfectKits_HandleAttachments( entity titan )
{
	PerfectKits_HandlePassives( titan )

	entity soul = titan.GetTitanSoul()
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

		if ( IsValid( soul ) )
		{
			switch ( weapon.GetWeaponClassName() )
			{
				case "mp_titanability_particle_wall":
					if ( SoulHasPassive( soul, ePassives.PAS_TONE_WALL ) )
						weaponMods.append( "PerfectKits_pas_tone_wall" )
					break

				case "mp_titanweapon_salvo_rockets":
				case "mp_titanweapon_shoulder_rockets":
					if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_REARM ) )
						weaponMods.append( "PerfectKits_rapid_rearm" )
					break

				case "mp_titanweapon_stun_laser":
					if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) )
						weaponMods.append( "PerfectKits_pas_vanguard_shield" )
					if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_REARM ) )
						weaponMods.append( "PerfectKits_rapid_rearm" )
					break
			}
		}

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
	}

	if ( file.perfectkits_enabled )
		PerfectKits_HandleAttachments( titan )

	weapons = titan.GetMainWeapons()
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
				weaponMods.remove( i )
				weaponMods.append( rebalMod )
			}
		}

		entity soul = titan.GetTitanSoul()
		if ( IsValid( soul ) )
		{
			switch ( weapon.GetWeaponClassName() )
			{
				case "mp_titanweapon_laser_lite":
					if ( SoulHasPassive( soul, ePassives.PAS_ION_LASERCANNON ) )
						weaponMods.append( "LTSRebalance_pas_ion_lasercannon" )
					if ( SoulHasPassive( soul, ePassives.PAS_ION_WEAPON ) )
						weaponMods.append( "LTSRebalance_pas_ion_weapon_helper" )
					break

				case "mp_titanability_particle_wall":
					if ( SoulHasPassive( soul, ePassives.PAS_TONE_WALL ) )
						weaponMods.append( "LTSRebalance_pas_tone_wall" )
					break

				case "mp_titancore_salvo_core":
					if ( SoulHasPassive( soul, ePassives.PAS_TONE_ROCKETS ) )
						weaponMods.append( "LTSRebalance_pas_tone_rockets" )
					break
				default:
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

void function PerfectKits_HandleSetfiles( entity player, entity titan )
{
	entity soul = player.GetTitanSoul()
	if ( SoulHasPassive( soul, ePassives.PAS_RONIN_SWORDCORE ) )
	{
		array<string> settingsMods = player.GetPlayerSettingsMods()
		settingsMods.append( "PerfectKits_highlander" )
		player.SetPlayerSettingsWithMods( player.GetPlayerSettings(), settingsMods )
	}
}

void function LTSRebalance_HandleSetfiles( entity player, entity titan )
{
	entity soul = player.GetTitanSoul()
	if ( SoulHasPassive( soul, ePassives.PAS_BATTERY_EJECT ) )
		thread LTSRebalance_SpectateKitDelayed( player )

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

void function LTSRebalance_SpectateKitDelayed( entity player )
{
	player.NotSolid()
	wait 1.0
	
	if ( IsValid( player ) && !player.IsTitan() && IsValid( player.GetPetTitan() ) )
		player.GetPetTitan().Die()

	player.Die()
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
		entity player = soul.GetBossPlayer()
		if ( IsValid( player ) )
			player.SetPlayerNetFloat( "LTSRebalance_Kit1Charge", charge )

		if ( charge == 1.0 )
		{
			if ( titan == player )
				Remote_CallFunction_NonReplay( player, "ServerCallback_RewardReadyMessage", (Time() - GetPlayerLastRespawnTime( player )) )
			GiveOffhandElectricSmoke( titan )
			entity smoke = titan.GetOffhandWeapon( OFFHAND_INVENTORY )
			smoke.WaitSignal( "CounterReadyUse" )
			charge = 0
			player = soul.GetBossPlayer()
			if ( IsValid( player ) )
				player.SetPlayerNetFloat( "LTSRebalance_Kit1Charge", charge )
		}

		lastTime = Time()
	}
}

void function LTSRebalance_OvercoreDamage( entity victim, var damageInfo )
{
	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_DOOMED_HEALTH_LOSS )
		return

	float damage = DamageInfo_GetDamage( damageInfo )
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) && attacker.IsTitan() && attacker != victim )
	{
		entity soul = attacker.GetTitanSoul()
		LTSRebalance_UpdateSoulOvercore( soul, damage )
	}
	
	if ( IsValid( victim ) && victim.IsTitan() )
	{
		entity soul = victim.GetTitanSoul()
		LTSRebalance_UpdateSoulOvercore( soul, -damage )
	}
}

void function LTSRebalance_OvercoreShieldDamage( entity victim, var damageInfo, TitanDamage titanDamage )
{
	float shieldDamage = float( titanDamage.shieldDamage )
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) && attacker.IsTitan() && attacker != victim )
	{
		entity soul = attacker.GetTitanSoul()
		LTSRebalance_UpdateSoulOvercore( soul, shieldDamage )
	}
	
	if ( IsValid( victim ) && victim.IsTitan() )
	{
		entity soul = victim.GetTitanSoul()
		LTSRebalance_UpdateSoulOvercore( soul, -shieldDamage )
	}
}

void function LTSRebalance_UpdateSoulOvercore( entity soul, float change )
{
	if ( !IsValid( soul ) || !SoulHasPassive( soul, ePassives.PAS_HYPER_CORE ) )
		return

	entity player = soul.GetBossPlayer()
	if ( !IsValid( player ) )
		return
	
	float curFrac = player.GetPlayerNetFloat( "LTSRebalance_Kit1Charge" )
	float newFrac = max( 0.0, min( 1.0, curFrac + change / LTSREBALANCE_PAS_OVERCORE_MAX_DAMAGE ) )
	player.SetPlayerNetFloat( "LTSRebalance_Kit1Charge", newFrac )
}

void function PerfectKits_OvercoreThink( entity soul )
{
	soul.EndSignal( "OnDestroy" )
	entity titan = null
	while( true )
	{
		wait 1.0
		titan = soul.GetTitan()
		if ( !IsAlive( titan ) || TitanCoreInUse( titan ) )
			continue

		int selfDamage = soul.IsDoomed() ? PERFECTKITS_OVERCORE_MIN_DAMAGE : int( titan.GetMaxHealth() * PERFECTKITS_OVERCORE_DRAIN_FRAC )
		titan.TakeDamage( selfDamage, titan, titan, { scriptType = DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.mp_titanability_overcore, origin = titan.GetWorldSpaceCenter() } )
		float oldTotalCredit = SoulTitanCore_GetNextAvailableTime( soul )
		float newTotalCredit = PERFECTKITS_OVERCORE_GAIN + oldTotalCredit
		if ( newTotalCredit >= 0.998 ) //JFS - the rui has a +0.001 for showing the meter as full. This fixes the case where the core meter displays 100 but can't be fired.
			newTotalCredit = 1.0
		SoulTitanCore_SetNextAvailableTime( soul, newTotalCredit )
	}
}

void function PerfectKits_FriendlyModeDamage( entity victim, var damageInfo )
{
	if ( victim.IsTitan() )
	{
		if ( "perfectKitsFriendly" in victim.s )
			DamageInfo_ScaleDamage( damageInfo, PERFECTKITS_FRIENDLY_MODE_FRAGILE_MOD )
	}

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || !attacker.IsTitan() )
		return

	if ( !( "perfectKitsFriendly" in attacker.s ) || !attacker.s.perfectKitsFriendly )
		return
	
	float damage = DamageInfo_GetDamage( damageInfo )
	DamageInfo_SetDamage( damageInfo, 0 )
	if ( attacker.IsPlayer() )
		attacker.NotifyDidDamage( victim, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamagePosition( damageInfo ), DamageInfo_GetCustomDamageType( damageInfo ), damage, DamageInfo_GetDamageFlags( damageInfo ), DamageInfo_GetHitGroup( damageInfo ), DamageInfo_GetWeapon( damageInfo ), DamageInfo_GetDistFromAttackOrigin( damageInfo ) )
	victim.SetHealth( minint( victim.GetMaxHealth(), int( victim.GetHealth() + damage ) ) )
}

void function PerfectKits_FriendlyMode( entity player, entity oldTitan )
{
	entity soul = player.GetTitanSoul()
	if ( IsValid( soul ) && ( SoulHasPassive( soul, ePassives.PAS_ENHANCED_TITAN_AI ) || SoulHasPassive( soul, ePassives.PAS_BIG_PUNCH ) ) )
		thread PerfectKits_FriendlyModeThink( player )
}

void function PerfectKits_FriendlyModeThink( entity player )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	player.EndSignal( "DisembarkingTitan" )

	int team = player.GetTeam()
	player.s.perfectKitsFriendly <- false

	file.perfectkits_friendlies++
	OnThreadEnd(
		function() : ( player, team )
		{
			if ( IsValid( player ) )
				SetTeam( player, team )

			file.perfectkits_friendlies--
		}
	)

	wait PERFECTKITS_FRIENDLY_MODE_DOWNTIME + float( file.perfectkits_friendlies ) * 0.1
	
	while( true )
	{
		player.s.perfectKitsFriendly = true
		SetTeam( player, TEAM_IMC + TEAM_MILITIA - team )
		MessageToPlayer( player, eEventNotifications.Rodeo_PilotAppliedBatteryToYou, player, true )
		wait PERFECTKITS_FRIENDLY_MODE_UPTIME

		player.s.perfectKitsFriendly = false
		SetTeam( player, team )
		MessageToPlayer( player, eEventNotifications.Rodeo_PilotAppliedBatteryToYou, player, true )
		wait PERFECTKITS_FRIENDLY_MODE_DOWNTIME
	}
}

void function PerfectKits_IceDash( entity player )
{
	thread PerfectKits_IceDashThink( player )
}

void function PerfectKits_IceDashThink( entity player )
{
	player.Signal( "PerfectKitsIceDash" )

	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnSyncedMelee" )
	player.EndSignal( "TitanEjectionStarted" )
	player.EndSignal( "DisembarkingTitan" )
	player.EndSignal( "PerfectKitsIceDash" )

	OnThreadEnd(
		function() : ( player )
		{
			player.SetTitanDisembarkEnabled( true )
			player.SetGroundFrictionScale( 1.0 )
		}
	)

	player.SetGroundFrictionScale( 0.0 )
	player.SetTitanDisembarkEnabled( false )
	float threshold = expect float( GetSettingsForPlayer_DodgeTable( player )["dodgeSpeed"] ) * PERFECTKITS_ICE_THRESHOLD_STOP_DIST_FRAC

	WaitEndFrame()

	vector startVel = player.GetVelocity()
	float startPower = player.GetDodgePower()

	int stopIter = 0
	vector lastPos = player.GetOrigin()
	while ( stopIter < PERFECTKITS_ICE_THRESHOLD_STOP_ITER )
	{
		WaitFrame()

		if ( Distance2DSqr( lastPos, player.GetOrigin() ) < threshold * threshold * 0.01 )
			stopIter++
		else
			stopIter = 0
		
		vector newVel = startVel
		newVel.z = player.GetVelocity().z
		player.SetVelocity( newVel )
		player.Server_SetDodgePower( startPower )
		lastPos = player.GetOrigin()
	}
}

void function PerfectKits_TurboDamage( entity victim, var damageInfo )
{
	if ( !victim.IsTitan() )
		return

	entity soul = victim.GetTitanSoul()
	bool turboEngine = IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_MOBILITY_DASH_CAPACITY )

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || !attacker.IsTitan() || !attacker.IsPlayer() )
		return

	soul = attacker.GetTitanSoul()
	turboEngine = turboEngine || ( IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_MOBILITY_DASH_CAPACITY ) )

	if ( turboEngine )
	{
		float damageConverted = DamageInfo_GetDamage( damageInfo ) * PERFECTKITS_TURBO_DAMAGE_CONV
		float dashAmount = expect float( GetSettingsForPlayer_DodgeTable( attacker )["dodgePowerDrain"] ) * damageConverted
		attacker.Server_SetDodgePower( min( 100.0, attacker.GetDodgePower() + dashAmount ) )
	}
}

void function PerfectKits_NukeDisembark( entity player, entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) || ( !SoulHasPassive( soul, ePassives.PAS_BUILD_UP_NUCLEAR_CORE ) && !SoulHasPassive( soul, ePassives.PAS_UNSTABLE_REACTOR ) ) )
		return

	thread PerfectKits_NukeDrop( player, titan )
}

void function PerfectKits_NukeDrop( entity player, entity titan )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	player.EndSignal( "player_embarks_titan" )

	WaittillAnimDone( player )
	wait 0.3
	player.ConsumeDoubleJump()
	float speed = RandomFloatRange( 1200, 1400 ) // Normal is 1500, 1700 + 400 for nuke

	float gravityScale = expect float ( player.GetPlayerSettingsField( "gravityscale" ) )

	vector dir = <0, 0, 1>
	if ( IsValid( titan ) )
	{
		vector ejectAngles = titan.GetAngles()
		ejectAngles.x = 270
		ejectAngles = AnglesCompose( ejectAngles, < -5, 0, 0 > )
		dir = AnglesToForward( ejectAngles )
	}

	vector velocity = dir * speed * sqrt( gravityScale )
	player.SetVelocity( velocity )

	while( !player.IsOnGround() )
		WaitFrame()
	
	thread PerfectKits_NukeDropTrigger( player )
}

void function PerfectKits_NukeDropTrigger( entity player )
{
	vector origin = player.GetWorldSpaceCenter()
	EmitSoundAtPosition( player.GetTeam(), origin, "titan_nuclear_death_explode" )

	int explosions = 11
	local innerRadius = 350
	float time = 1.0
	bool IsNPC = false

	local heavyArmorDamage = 500
	local normalDamage = 40

	float waitPerExplosion = time / explosions

	thread __CreateFxInternal( TITAN_NUCLEAR_CORE_FX_1P, null, "", origin, Vector(0,RandomInt(360),0), C_PLAYFX_SINGLE, null, 1, player )
	thread __CreateFxInternal( TITAN_NUCLEAR_CORE_FX_3P, null, "", origin + Vector( 0, 0, -100 ), Vector(0,RandomInt(360),0), C_PLAYFX_SINGLE, null, 6, player )

	local outerRadius

	local baseNormalDamage 		= normalDamage
	local baseHeavyArmorDamage 	= heavyArmorDamage
	local baseInnerRadius 		= innerRadius
	local baseOuterRadius 		= outerRadius

	// all damage must have an inflictor currently
	entity inflictor = CreateEntity( "script_ref" )
	inflictor.SetOrigin( origin )
	inflictor.kv.spawnflags = SF_INFOTARGET_ALWAYS_TRANSMIT_TO_CLIENT
	DispatchSpawn( inflictor )

	OnThreadEnd(
		function() : ( inflictor )
		{
			if ( IsValid( inflictor ) )
				inflictor.Destroy()
		}
	)

	int team = player.GetTeam()
	for ( int i = 0; i < explosions; i++ )
	{
		local normalDamage 		= baseNormalDamage
		local heavyArmorDamage 	= baseHeavyArmorDamage
		local innerRadius 		= baseInnerRadius
		local outerRadius 		= baseOuterRadius

		if ( i == 0 )
		{
			normalDamage = 40
			heavyArmorDamage = 0
			outerRadius = 600
		}
		else
		{
			outerRadius = 750
		}

		if ( outerRadius < innerRadius )
			outerRadius = innerRadius

		entity owner = IsValid( player ) ? player : GetTeamEnt( team )
		RadiusDamage(
			origin,								// origin
			owner,								// owner
			inflictor,							// inflictor
			normalDamage,						// normal damage
			heavyArmorDamage,					// heavy armor damage
			innerRadius,						// inner radius
			outerRadius,						// outer radius
			SF_ENVEXPLOSION_NO_DAMAGEOWNER,		// flags
			0,									// dist from attacker
			0,									// explosionForce
			DF_RAGDOLL | DF_EXPLOSION,
			eDamageSourceId.damagedef_nuclear_core
		)									

		wait waitPerExplosion
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

entity function LTSRebalance_DamageInfo_GetWeapon( var damageInfo, entity defaultWeapon = null )
{
	entity ent = DamageInfo_GetWeapon( damageInfo )
	
	if ( !IsValid( ent ) )
		ent = DamageInfo_GetInflictor( damageInfo )
	
	if ( !IsValid( ent ) || ent.IsPlayer() || ent.IsNPC() )
		ent = defaultWeapon

	return ent
}