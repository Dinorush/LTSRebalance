/* LTS Rebalance replaces this file for the following reasons:
   1. Implement baseline changes
   2. Implement Highlander changes (LTS Rebalance)
   3. Implement Phase Reflex changes (LTS Rebalance + Perfect Kits)
*/
global function OnWeaponPrimaryAttack_DoNothing

global function Shift_Core_Init
#if SERVER
global function Shift_Core_UseMeter
#endif

global function OnCoreCharge_Shift_Core
global function OnCoreChargeEnd_Shift_Core
global function OnAbilityStart_Shift_Core

void function Shift_Core_Init()
{
	RegisterSignal( "RestoreWeapon" )
	#if SERVER
	if ( !LTSRebalance_EnabledOnInit() )
	{
		AddCallback_OnPlayerKilled( SwordCore_OnPlayedOrNPCKilled )
		AddCallback_OnNPCKilled( SwordCore_OnPlayedOrNPCKilled )
	}
	if ( PerfectKits_EnabledOnInit() )
		AddCallback_OnTitanHealthSegmentLost( PerfectKits_PhaseReflexTrigger )
	#endif
}

#if SERVER
void function SwordCore_OnPlayedOrNPCKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !victim.IsTitan() )
		return

	if ( !attacker.IsPlayer() || !PlayerHasPassive( attacker, ePassives.PAS_SHIFT_CORE ) )
		return

	entity soul = attacker.GetTitanSoul()
	if ( !IsValid( soul ) || !SoulHasPassive( soul, ePassives.PAS_RONIN_SWORDCORE ) )
		return

	float curTime = Time()
	float highlanderBonus = 8.0
	float remainingTime = highlanderBonus + soul.GetCoreChargeExpireTime() - curTime
	float duration = soul.GetCoreUseDuration()
	float coreFrac = min( 1.0, remainingTime / duration )
	//Defensive fix for this sometimes resulting in a negative value.
	if ( coreFrac > 0.0 )
	{
		soul.SetTitanSoulNetFloat( "coreExpireFrac", coreFrac )
		soul.SetTitanSoulNetFloatOverTime( "coreExpireFrac", 0.0, remainingTime )
		soul.SetCoreChargeExpireTime( remainingTime + curTime )
	}
}

void function PerfectKits_PhaseReflexTrigger( entity victim, entity attacker )
{
	if ( !victim.IsTitan() )
		return

	entity soul = victim.GetTitanSoul()
	if ( !IsValid( soul ) || !SoulHasPassive( soul, ePassives.PAS_RONIN_AUTOSHIFT ) )
		return

	if ( IsValid ( attacker ) )
	{
		table attackerDotS = expect table( attacker.s )
		attackerDotS.PerfectReflexForced <- true
		PhaseShift( attacker, 0, 6.0 )
	}
	PhaseShift( victim, 0, 6.0 )
}
#endif

var function OnWeaponPrimaryAttack_DoNothing( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return 0
}

bool function OnCoreCharge_Shift_Core( entity weapon )
{
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

#if SERVER
	entity owner = weapon.GetWeaponOwner()
	string swordCoreSound_1p
	string swordCoreSound_3p
	if ( weapon.HasMod( "fd_duration" ) || weapon.HasMod( "LTSRebalance_fd_duration" ) )
	{
		swordCoreSound_1p = "Titan_Ronin_Sword_Core_Activated_Upgraded_1P"
		swordCoreSound_3p = "Titan_Ronin_Sword_Core_Activated_Upgraded_3P"
	}
	else
	{
		swordCoreSound_1p = "Titan_Ronin_Sword_Core_Activated_1P"
		swordCoreSound_3p = "Titan_Ronin_Sword_Core_Activated_3P"
	}
	if ( owner.IsPlayer() )
	{
		owner.HolsterWeapon() //TODO: Look into rewriting this so it works with HolsterAndDisableWeapons()
		thread RestoreWeapon( owner, weapon )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, swordCoreSound_1p )
		EmitSoundOnEntityExceptToPlayer( owner, owner, swordCoreSound_3p )
	}
	else
	{
		EmitSoundOnEntity( weapon, swordCoreSound_3p )
	}
#endif

	return true
}

void function OnCoreChargeEnd_Shift_Core( entity weapon )
{
	#if SERVER
	entity owner = weapon.GetWeaponOwner()
	OnAbilityChargeEnd_TitanCore( weapon )
	if ( IsValid( owner ) && owner.IsPlayer() )
		owner.DeployWeapon() //TODO: Look into rewriting this so it works with HolsterAndDisableWeapons()
	else if ( !IsValid( owner ) )
		Signal( weapon, "RestoreWeapon" )
	#endif
}

#if SERVER
void function RestoreWeapon( entity owner, entity weapon )
{
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "CoreBegin" )

	WaitSignal( weapon, "RestoreWeapon", "OnDestroy" )

	if ( IsValid( owner ) && owner.IsPlayer() )
	{
		owner.DeployWeapon() //TODO: Look into rewriting this so it works with DeployAndEnableWeapons()
	}
}
#endif

var function OnAbilityStart_Shift_Core( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnAbilityStart_TitanCore( weapon )

	entity owner = weapon.GetWeaponOwner()

	if ( !owner.IsTitan() )
		return 0

	if ( !IsValid( owner ) )
		return

	entity offhandWeapon = owner.GetOffhandWeapon( OFFHAND_MELEE )
	if ( !IsValid( offhandWeapon ) )
		return 0

	if ( offhandWeapon.GetWeaponClassName() != "melee_titan_sword" )
		return 0

#if SERVER
	if ( owner.IsPlayer() )
	{
		owner.Server_SetDodgePower( 100.0 )
		owner.SetPowerRegenRateScale( 6.5 )

		GivePassive( owner, ePassives.PAS_FUSION_CORE )
		GivePassive( owner, ePassives.PAS_SHIFT_CORE )
	}

	StoredWeapon storedWeapon
    entity soul = owner.GetTitanSoul()
	if ( soul != null )
	{
		entity titan = soul.GetTitan()
		if ( titan.IsNPC() )
		{
			titan.SetAISettings( "npc_titan_stryder_leadwall_shift_core" )
			titan.EnableNPCMoveFlag( NPCMF_PREFER_SPRINT )
			titan.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, false )
			AddAnimEvent( titan, "shift_core_use_meter", Shift_Core_UseMeter_NPC )
		}

		entity meleeWeapon = titan.GetOffhandWeapon( OFFHAND_MELEE )
		if ( LTSRebalance_Enabled() && titan.IsPlayer() )
			meleeWeapon.AddMod( "LTSRebalance_super_charged" )
		else
			meleeWeapon.AddMod( "super_charged" )

		if ( IsSingleplayer() )
		{
			meleeWeapon.AddMod( "super_charged_SP" )
		}

		entity mainWeapon = titan.GetMainWeapons()[0]
		if ( LTSRebalance_Enabled() && titan.IsPlayer() )
		{
			// Take Leadwall away to skip holstering anim
			storedWeapon = StoreMainWeapon( titan )
			int clipSize = mainWeapon.GetWeaponPrimaryClipCountMax()

			titan.TakeWeaponNow( storedWeapon.name )

			array<string> mods = []
			if( meleeWeapon.HasMod( "modelset_prime" ) )
				mods.append( "modelset_prime" )

			titan.GiveWeapon( "mp_titanweapon_shift_core_sword", mods )
			titan.SetActiveWeaponByName( "mp_titanweapon_shift_core_sword" )

			entity block = titan.GetOffhandWeapon( OFFHAND_LEFT )
			if ( IsValid( block ) && block.GetWeaponClassName() == "mp_titanability_basic_block" )
			{
				block.AddMod( "LTSRebalance_core_regen" )
				block.SetWeaponPrimaryClipCount( block.GetWeaponPrimaryClipCountMax() )
			}

			entity ordnance = titan.GetOffhandWeapon( OFFHAND_RIGHT )
			if ( IsValid( ordnance ) && ordnance.GetWeaponClassName() == "mp_titanweapon_arc_wave" )
				ordnance.AddMod( "LTSRebalance_core_regen" )
		}
		else
		{
			titan.SetActiveWeaponByName( "melee_titan_sword" )

			mainWeapon.AllowUse( false )
		}
	}

	float delay = weapon.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
	thread Shift_Core_End( weapon, owner, delay, storedWeapon )
#endif

	return 1
}

#if SERVER
void function Shift_Core_End( entity weapon, entity player, float delay, StoredWeapon storedWeapon )
{
	weapon.EndSignal( "OnDestroy" )

	if ( player.IsNPC() && !IsAlive( player ) )
		return

	player.EndSignal( "OnDestroy" )
	if ( IsAlive( player ) )
		player.EndSignal( "OnDeath" )
	player.EndSignal( "TitanEjectionStarted" )
	player.EndSignal( "DisembarkingTitan" )
	player.EndSignal( "OnSyncedMelee" )
	player.EndSignal( "InventoryChanged" )

	OnThreadEnd(
	function() : ( weapon, player, storedWeapon )
		{
			OnAbilityEnd_Shift_Core( weapon, player, storedWeapon )

			if ( IsValid( player ) )
			{
				entity soul = player.GetTitanSoul()
				if ( soul != null )
					CleanupCoreEffect( soul )
			}
		}
	)

	entity soul = player.GetTitanSoul()
	if ( soul == null )
		return

	while ( 1 )
	{
		if ( soul.GetCoreChargeExpireTime() <= Time() )
			break;
		wait 0.1
	}
}

void function OnAbilityEnd_Shift_Core( entity weapon, entity player, StoredWeapon storedWeapon )
{
	OnAbilityEnd_TitanCore( weapon )

	if ( player.IsPlayer() )
	{
		player.SetPowerRegenRateScale( 1.0 )
		EmitSoundOnEntityOnlyToPlayer( player, player, "Titan_Ronin_Sword_Core_Deactivated_1P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "Titan_Ronin_Sword_Core_Deactivated_3P" )
		int conversationID = GetConversationIndex( "swordCoreOffline" )
		Remote_CallFunction_Replay( player, "ServerCallback_PlayTitanConversation", conversationID )
	}
	else
	{
		DeleteAnimEvent( player, "shift_core_use_meter" )
		EmitSoundOnEntity( player, "Titan_Ronin_Sword_Core_Deactivated_3P" )
	}

	RestorePlayerWeapons( player, storedWeapon )
}

void function RestorePlayerWeapons( entity player, StoredWeapon storedWeapon )
{
	if ( !IsValid( player ) )
		return

	if ( player.IsNPC() && !IsAlive( player ) )
		return // no need to fix up dead NPCs

	entity soul = player.GetTitanSoul()

	if ( player.IsPlayer() )
	{
		TakePassive( player, ePassives.PAS_FUSION_CORE )
		TakePassive( player, ePassives.PAS_SHIFT_CORE )

		soul = GetSoulFromPlayer( player )
	}

	if ( soul != null )
	{
		entity titan = soul.GetTitan()

		entity meleeWeapon = titan.GetOffhandWeapon( OFFHAND_MELEE )
		if ( IsValid( meleeWeapon ) )
		{
			if( LTSRebalance_Enabled() && titan.IsPlayer() )
			{
				array<string> mods = meleeWeapon.GetMods()
				mods.fastremovebyvalue( "LTSRebalance_super_charged" )
				mods.fastremovebyvalue( "LTSRebalance_super_charged_beam" )
				mods.fastremovebyvalue( "LTSRebalance_fd_sword_upgrade_beam" )
				meleeWeapon.SetMods( mods )
			}
			else
				meleeWeapon.RemoveMod( "super_charged" )

			if ( IsSingleplayer() )
			{
				meleeWeapon.RemoveMod( "super_charged_SP" )
			}
		}

		if ( LTSRebalance_Enabled() && titan.IsPlayer() )
		{
			entity block = titan.GetOffhandWeapon( OFFHAND_LEFT )
			if ( IsValid( block ) && block.GetWeaponClassName() == "mp_titanability_basic_block" )
				block.RemoveMod( "LTSRebalance_core_regen" )	

			entity ordnance = titan.GetOffhandWeapon( OFFHAND_RIGHT )
			if ( IsValid( ordnance ) && ordnance.GetWeaponClassName() == "mp_titanweapon_arc_wave" )
				ordnance.RemoveMod( "LTSRebalance_core_regen" )			

			if ( storedWeapon.name != "" )
				GiveStoredMainWeapon( titan, storedWeapon )

			titan.TakeWeapon( "mp_titanweapon_shift_core_sword" )
		}
		else if ( titan.GetMainWeapons().len() > 0 )
			titan.GetMainWeapons()[0].AllowUse( true )

		if ( titan.IsNPC() )
		{
			string settings = GetSpawnAISettings( titan )
			if ( settings != "" )
				titan.SetAISettings( settings )

			titan.DisableNPCMoveFlag( NPCMF_PREFER_SPRINT )
			titan.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, true )
		}
	}
}

StoredWeapon function StoreMainWeapon( entity player )
{
	StoredWeapon sw
	entity activeWeapon = player.GetActiveWeapon()
	array<entity> mainWeapons = player.GetMainWeapons()

	if ( mainWeapons.len() == 0 )
		return sw

	entity weapon = mainWeapons[0]

	sw.name = weapon.GetWeaponClassName()
	sw.weaponType = eStoredWeaponType.main
	sw.activeWeapon = ( weapon == activeWeapon )
	sw.inventoryIndex = 0
	sw.mods = weapon.GetMods()
	sw.modBitfield = weapon.GetModBitField()
	sw.ammoCount = weapon.GetWeaponPrimaryAmmoCount()
	sw.clipCount = weapon.GetWeaponPrimaryClipCount()
	sw.nextAttackTime = weapon.GetNextAttackAllowedTime()
	sw.skinIndex = weapon.GetSkin()
	sw.camoIndex = weapon.GetCamo()
	sw.isProScreenOwner = weapon.GetProScreenOwner() == player

	return sw
}

void function GiveStoredMainWeapon( entity player, StoredWeapon storedWeapon )
{
	entity weapon = player.GiveWeapon( storedWeapon.name, storedWeapon.mods )
	weapon.SetWeaponSkin( storedWeapon.skinIndex )
	weapon.SetWeaponCamo( storedWeapon.camoIndex )

	#if MP
	if ( storedWeapon.isProScreenOwner )
	{
		weapon.SetProScreenOwner( player )
		if ( weapon.HasMod( "pro_screen" ) )
			UpdateProScreen( player, weapon )
	}
	string weaponCategory = ""
	if ( IsWeaponKeyFieldDefined(weapon.GetWeaponClassName(), "menu_category") )
	{
		weaponCategory = GetWeaponInfoFileKeyField_GlobalString( weapon.GetWeaponClassName(), "menu_category" )
	}
	#endif

	weapon.SetWeaponPrimaryAmmoCount( storedWeapon.ammoCount )
	if ( weapon.GetWeaponPrimaryClipCountMax() > 0 )
		weapon.SetWeaponPrimaryClipCount( storedWeapon.clipCount )
}

void function Shift_Core_UseMeter( entity player )
{
	if ( IsMultiplayer() )
		return

	entity soul = player.GetTitanSoul()
	float curTime = Time()
	float remainingTime = soul.GetCoreChargeExpireTime() - curTime

	if ( remainingTime > 0 )
	{
		const float USE_TIME = 5

		remainingTime = max( remainingTime - USE_TIME, 0 )
		float startTime = soul.GetCoreChargeStartTime()
		float duration = soul.GetCoreUseDuration()

		soul.SetTitanSoulNetFloat( "coreExpireFrac", remainingTime / duration )
		soul.SetTitanSoulNetFloatOverTime( "coreExpireFrac", 0.0, remainingTime )
		soul.SetCoreChargeExpireTime( remainingTime + curTime )
	}
}

void function Shift_Core_UseMeter_NPC( entity npc )
{
	Shift_Core_UseMeter( npc )
}
#endif