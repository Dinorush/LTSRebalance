global function UpgradeCore_Init
global function OnWeaponPrimaryAttack_UpgradeCore
#if SERVER
global function OnWeaponNpcPrimaryAttack_UpgradeCore
#endif
#if CLIENT
global function ServerCallback_VanguardUpgradeMessage
#endif

const LASER_CHAGE_FX_1P = $"P_handlaser_charge"
const LASER_CHAGE_FX_3P = $"P_handlaser_charge"
const FX_SHIELD_GAIN_SCREEN		= $"P_xo_shield_up"
const int SUPERIOR_CHASSIS_HEALTH_AMOUNT = 2500
const int SUPERIOR_CHASSIS_SHIELD_AMOUNT = 1875
const int PAS_VANGUARD_COREMETER_SHIELD = 500
const int PAS_VANGUARD_DOOM_HEAL = 1000

void function UpgradeCore_Init()
{
	RegisterSignal( "OnSustainedDischargeEnd" )

	PrecacheParticleSystem( FX_SHIELD_GAIN_SCREEN )
	PrecacheParticleSystem( LASER_CHAGE_FX_1P )
	PrecacheParticleSystem( LASER_CHAGE_FX_3P )

    #if SERVER
	if ( !LTSRebalance_EnabledOnInit() )
		return
	AddCallback_OnTitanHealthSegmentLost( EnergyThief_OnSegmentLost )
	AddCallback_OnPlayerKilled( EnergyThief_OnPlayerOrNPCKilled )
	AddCallback_OnNPCKilled( EnergyThief_OnPlayerOrNPCKilled )
    #endif
}

#if SERVER
void function EnergyThief_OnSegmentLost( entity victim, entity attacker )
{
    EnergyThief_GrantShield( victim, attacker )
}

void function EnergyThief_OnPlayerOrNPCKilled( entity victim, entity attacker, var damageInfo )
{
	EnergyThief_GrantShield( victim, attacker )
}

void function EnergyThief_GrantShield( entity victim, entity attacker )
{
	if ( !victim.IsTitan() || !attacker.IsTitan() )
		return

	entity soul = attacker.GetTitanSoul()
	if ( !IsValid( soul ) || !SoulHasPassive( soul, ePassives.PAS_VANGUARD_COREMETER ) )
		return

	StunLaser_HandleTempShieldChange( soul, PAS_VANGUARD_COREMETER_SHIELD )
    int newShield = minint( soul.GetShieldHealthMax(), soul.GetShieldHealth() + PAS_VANGUARD_COREMETER_SHIELD )
    soul.SetShieldHealth( newShield )
}


var function OnWeaponNpcPrimaryAttack_UpgradeCore( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_UpgradeCore( weapon, attackParams )
	return 1
}
#endif

var function OnWeaponPrimaryAttack_UpgradeCore( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if ( !CheckCoreAvailable( weapon ) )
		return false

	entity owner = weapon.GetWeaponOwner()
	entity soul = owner.GetTitanSoul()
	#if SERVER
		float coreDuration = weapon.GetCoreDuration()
		thread UpgradeCoreThink( weapon, coreDuration )
		int currentUpgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
		if ( currentUpgradeCount == 0 )
		{
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE1 ) )  // Arc Rounds
			{
				array<entity> weapons = GetPrimaryWeapons( owner )
				if ( weapons.len() > 0 )
				{
					entity primaryWeapon = weapons[0]
					if ( IsValid( primaryWeapon ) )
					{
						array<string> mods = primaryWeapon.GetMods()
						if ( !LTSRebalance_Enabled() )
						{
							mods.append( "arc_rounds" )
							primaryWeapon.SetMods( mods )
							primaryWeapon.SetWeaponPrimaryClipCount( primaryWeapon.GetWeaponPrimaryClipCount() + 10 )
						}
						else
						{
							mods.append( "LTSRebalance_base_arc_rounds" )
							mods.append( "LTSRebalance_arc_rounds" )
							primaryWeapon.SetMods( mods )
						}
					}
				}
				if ( owner.IsPlayer() )
				{
					int conversationID = GetConversationIndex( "upgradeTo1" )
					Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
					Remote_CallFunction_NonReplay( owner, "ServerCallback_VanguardUpgradeMessage", 1 )
				}
			}
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE2 ) ) //Missile Racks
			{
				entity offhandWeapon = owner.GetOffhandWeapon( OFFHAND_RIGHT )
				if ( IsValid( offhandWeapon ) )
				{
					array<string> mods = offhandWeapon.GetMods()
					if ( LTSRebalance_Enabled() )
						mods.append( "LTSRebalance_missile_racks" )
					else
						mods.append( "missile_racks" )
					offhandWeapon.SetMods( mods )
				}
				if ( owner.IsPlayer() )
				{
					int conversationID = GetConversationIndex( "upgradeTo1" )
					Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
					Remote_CallFunction_NonReplay( owner, "ServerCallback_VanguardUpgradeMessage", 2 )
				}
			}
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE3 ) ) //Energy Transfer
			{
				entity offhandWeapon = owner.GetOffhandWeapon( OFFHAND_LEFT )
				if ( IsValid( offhandWeapon ) )
				{
					array<string> mods = offhandWeapon.GetMods()
					mods.append( "energy_transfer" )
					offhandWeapon.SetMods( mods )
				}
				if ( owner.IsPlayer() )
				{
					int conversationID = GetConversationIndex( "upgradeTo1" )
					Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
					Remote_CallFunction_NonReplay( owner, "ServerCallback_VanguardUpgradeMessage", 3 )
				}
			}
		}
		else if ( currentUpgradeCount == 1 )
		{
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE4 ) )  // Rapid Rearm
			{
				entity offhandWeapon = owner.GetOffhandWeapon( OFFHAND_ANTIRODEO )
				if ( IsValid( offhandWeapon ) )
				{
					array<string> mods = offhandWeapon.GetMods()
					mods.append( "rapid_rearm" )
					offhandWeapon.SetMods( mods )
				}
				array<entity> weapons = GetPrimaryWeapons( owner )
				if ( !LTSRebalance_Enabled() && weapons.len() > 0 )
				{
					entity primaryWeapon = weapons[0]
					if ( IsValid( primaryWeapon ) )
					{
						array<string> mods = primaryWeapon.GetMods()
						mods.append( "rapid_reload" )
						primaryWeapon.SetMods( mods )
					}
				}
				if ( owner.IsPlayer() )
				{
					int conversationID = GetConversationIndex( "upgradeTo2" )
					Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
					Remote_CallFunction_NonReplay( owner, "ServerCallback_VanguardUpgradeMessage", 4 )
				}
			}
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE5 ) ) //Maelstrom
			{
				entity offhandWeapon = owner.GetOffhandWeapon( OFFHAND_INVENTORY )
				if ( IsValid( offhandWeapon ) )
				{
					array<string> mods = offhandWeapon.GetMods()
					mods.append( "maelstrom" )
					offhandWeapon.SetMods( mods )
				}
				if ( owner.IsPlayer() )
				{
					int conversationID = GetConversationIndex( "upgradeTo2" )
					Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
					Remote_CallFunction_NonReplay( owner, "ServerCallback_VanguardUpgradeMessage", 5 )
				}
			}
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE6 ) ) //Energy Field
			{
				entity offhandWeapon = owner.GetOffhandWeapon( OFFHAND_LEFT )
				if ( IsValid( offhandWeapon ) )
				{
					array<string> mods = offhandWeapon.GetMods()
					if ( mods.contains( "energy_transfer" ) )
					{
						array<string> mods = offhandWeapon.GetMods()
						mods.fastremovebyvalue( "energy_transfer" )
						if ( LTSRebalance_Enabled() )
							mods.append( "LTSRebalance_energy_field_energy_transfer" )
						else
							mods.append( "energy_field_energy_transfer" )
						offhandWeapon.SetMods( mods )
					}
					else
					{
						array<string> mods = offhandWeapon.GetMods()
						if ( LTSRebalance_Enabled() )
							mods.append( "LTSRebalance_energy_field" )
						else
							mods.append( "energy_field" )
						offhandWeapon.SetMods( mods )
					}
				}
				if ( owner.IsPlayer() )
				{
					int conversationID = GetConversationIndex( "upgradeTo2" )
					Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
					Remote_CallFunction_NonReplay( owner, "ServerCallback_VanguardUpgradeMessage", 6 )
				}
			}
		}
		else if ( currentUpgradeCount == 2 )
		{
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE7 ) )  // Multi-Target Missiles
			{
				if ( owner.IsPlayer() )
				{
					array<string> conversations = [ "upgradeTo3", "upgradeToFin" ]
					int conversationID = GetConversationIndex( conversations.getrandom() )
					Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
					Remote_CallFunction_NonReplay( owner, "ServerCallback_VanguardUpgradeMessage", 7 )
				}

				entity ordnance = owner.GetOffhandWeapon( OFFHAND_RIGHT )
				array<string> mods
				if ( LTSRebalance_Enabled() )
				{
					if ( ordnance.HasMod( "LTSRebalance_missile_racks") )
						mods = [ "LTSRebalance_upgradeCore_MissileRack_Vanguard" ]
					else
						mods = [ "LTSRebalance_upgradeCore_Vanguard" ]
				}
				else
				{
					if ( ordnance.HasMod( "missile_racks") )
						mods = [ "upgradeCore_MissileRack_Vanguard" ]
					else
						mods = [ "upgradeCore_Vanguard" ]
				}

				if ( ordnance.HasMod( "fd_balance" ) )
					mods.append( "fd_balance" )

				float ammoFrac = float( ordnance.GetWeaponPrimaryClipCount() ) / float( ordnance.GetWeaponPrimaryClipCountMax() )
				owner.TakeWeaponNow( ordnance.GetWeaponClassName() )
				owner.GiveOffhandWeapon( "mp_titanweapon_shoulder_rockets", OFFHAND_RIGHT, mods )
				ordnance = owner.GetOffhandWeapon( OFFHAND_RIGHT )
				ordnance.SetWeaponChargeFractionForced( 1 - ammoFrac )
			}
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE8 ) ) //Superior Chassis
			{
				int HEALTH_AMOUNT = LTSRebalance_Enabled() ? SUPERIOR_CHASSIS_HEALTH_AMOUNT : VANGUARD_CORE8_HEALTH_AMOUNT
				if ( owner.IsPlayer() )
				{
					array<string> conversations = [ "upgradeTo3", "upgradeToFin" ]
					int conversationID = GetConversationIndex( conversations.getrandom() )
					Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
					Remote_CallFunction_NonReplay( owner, "ServerCallback_VanguardUpgradeMessage", 8 )

					if ( !GetDoomedState( owner ) )
					{
						int missingHealth = owner.GetMaxHealth() - owner.GetHealth()
						array<string> settingMods = owner.GetPlayerSettingsMods()
						if ( LTSRebalance_Enabled() )
							settingMods.append( "LTSRebalance_core_health_upgrade" )
						else
							settingMods.append( "core_health_upgrade" )
						owner.SetPlayerSettingsWithMods( owner.GetPlayerSettings(), settingMods )
						owner.SetHealth( max( owner.GetMaxHealth() - missingHealth, HEALTH_AMOUNT ) )

						//Hacky Hack - Append core_health_upgrade to setFileMods so that we have a way to check that this upgrade is active.
						if ( LTSRebalance_Enabled() )
							soul.soul.titanLoadout.setFileMods.append( "LTSRebalance_core_health_upgrade" )
						else
							soul.soul.titanLoadout.setFileMods.append( "core_health_upgrade" )
					}
					else
					{
						owner.SetHealth( owner.GetMaxHealth() )
					}
				}
				else
				{
					if ( !GetDoomedState( owner ) )
					{
						owner.SetMaxHealth( owner.GetMaxHealth() + HEALTH_AMOUNT )
						owner.SetHealth( owner.GetHealth() + HEALTH_AMOUNT )
					}
				}
				entity soul = owner.GetTitanSoul()
				soul.SetPreventCrits( true )
			}
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE9 ) ) //XO-16 Battle Rifle
			{
				array<entity> weapons = GetPrimaryWeapons( owner )
				if ( weapons.len() > 0 )
				{
					entity primaryWeapon = weapons[0]
					if ( IsValid( primaryWeapon ) )
					{
						if ( !LTSRebalance_Enabled() )
						{
							if ( primaryWeapon.HasMod( "arc_rounds" ) )
							{
								primaryWeapon.RemoveMod( "arc_rounds" )
								array<string> mods = primaryWeapon.GetMods()
								mods.append( "arc_rounds_with_battle_rifle" )
								primaryWeapon.SetMods( mods )
							}
							else
							{
								array<string> mods = primaryWeapon.GetMods()
								mods.append( "battle_rifle" )
								mods.append( "battle_rifle_icon" )
								primaryWeapon.SetMods( mods )
							}
						}
						else
						{
							array<string> mods = primaryWeapon.GetMods()
							mods.append( "LTSRebalance_base_battle_rifle" )
							if ( mods.contains( "LTSRebalance_arc_rounds" ) )
							{
								mods.fastremovebyvalue( "LTSRebalance_arc_rounds" )
								mods.append( "LTSRebalance_arc_rounds_with_battle_rifle" )
							}
							else
								mods.append( "LTSRebalance_battle_rifle")
							primaryWeapon.SetMods( mods )
						}
					}
				}

				if ( owner.IsPlayer() )
				{
					array<string> conversations = [ "upgradeTo3", "upgradeToFin" ]
					int conversationID = GetConversationIndex( conversations.getrandom() )
					Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
					Remote_CallFunction_NonReplay( owner, "ServerCallback_VanguardUpgradeMessage", 9 )
				}
			}
		}
		else
		{
			if ( owner.IsPlayer() )
			{
				int conversationID = GetConversationIndex( "upgradeShieldReplenish" )
				Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", conversationID )
			}
		}
		PasVanguardDoom_HealOnCore( owner, soul ) // By calling this here, Superior Chassis will not grant its full health increase if Monarch undooms with it.

		soul.SetTitanSoulNetInt( "upgradeCount", currentUpgradeCount + 1 )
		int statesIndex = owner.FindBodyGroup( "states" )
		owner.SetBodygroup( statesIndex, 1 )
	#endif

	#if CLIENT
		if ( owner.IsPlayer() )
		{
			entity cockpit = owner.GetCockpit()
			if ( IsValid( cockpit ) )
				StartParticleEffectOnEntity( cockpit, GetParticleSystemIndex( FX_SHIELD_GAIN_SCREEN	), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		}
	#endif
	OnAbilityCharge_TitanCore( weapon )
	OnAbilityStart_TitanCore( weapon )

	return 1
}

#if SERVER
void function PasVanguardDoom_HealOnCore ( entity owner, entity soul  )
{
    if( LTSRebalance_Enabled() && SoulHasPassive( soul, ePassives.PAS_VANGUARD_DOOM ) )
    {
        if( soul.IsDoomed() )
        {
            int trgtHealth = PAS_VANGUARD_DOOM_HEAL + owner.GetHealth()
            int maxHealth = owner.GetMaxHealth()
            if ( trgtHealth > maxHealth )
            {
				int shields = soul.GetShieldHealth()
                UndoomTitan( owner, 1 )
                owner.SetHealth( trgtHealth - maxHealth )
				soul.SetShieldHealth( shields )
            }
            else
                owner.SetHealth( trgtHealth )
        }
        else if ( owner.GetHealth() < PAS_VANGUARD_DOOM_HEAL )
            owner.SetHealth( PAS_VANGUARD_DOOM_HEAL )
    }
}
void function UpgradeCoreThink( entity weapon, float coreDuration )
{
	weapon.EndSignal( "OnDestroy" )
	entity owner = weapon.GetWeaponOwner()
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "DisembarkingTitan" )
	owner.EndSignal( "TitanEjectionStarted" )

	EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Monarch_Smart_Core_Activated_1P" )
	EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Monarch_Smart_Core_ActiveLoop_1P" )
	EmitSoundOnEntityExceptToPlayer( owner, owner, "Titan_Monarch_Smart_Core_Activated_3P" )
	entity soul = owner.GetTitanSoul()
	int shieldAmount = soul.GetShieldHealthMax()
    if ( LTSRebalance_Enabled() )
		shieldAmount = ( weapon.HasMod( "LTSRebalance_superior_chassis" ) ? SUPERIOR_CHASSIS_SHIELD_AMOUNT : soul.GetShieldHealthMax() / 2 )
    StunLaser_HandleTempShieldChange( soul, shieldAmount )
    int newShield = minint( soul.GetShieldHealthMax(), soul.GetShieldHealth() + shieldAmount)
	soul.SetShieldHealth( newShield )

	OnThreadEnd(
	function() : ( weapon, owner, soul )
		{
			if ( IsValid( owner ) )
			{
				StopSoundOnEntity( owner, "Titan_Monarch_Smart_Core_ActiveLoop_1P" )
				//EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Monarch_Smart_Core_Activated_1P" )
			}

			if ( IsValid( weapon ) )
			{
				OnAbilityChargeEnd_TitanCore( weapon )
				OnAbilityEnd_TitanCore( weapon )
			}

			if ( IsValid( soul ) )
			{
				CleanupCoreEffect( soul )
			}
		}
	)

	wait coreDuration
}
#endif


#if CLIENT
void function ServerCallback_VanguardUpgradeMessage( int upgradeID )
{
	switch ( upgradeID )
	{
		case 1:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE1" ), Localize( "#GEAR_VANGUARD_CORE1_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 2:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE2" ), Localize( "#GEAR_VANGUARD_CORE2_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 3:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE3" ), Localize( "#GEAR_VANGUARD_CORE3_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 4:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE4" ), Localize( "#GEAR_VANGUARD_CORE4_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 5:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE5" ), Localize( "#GEAR_VANGUARD_CORE5_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 6:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE6" ), Localize( "#GEAR_VANGUARD_CORE6_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 7:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE7" ), Localize( "#GEAR_VANGUARD_CORE7_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 8:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE8" ), Localize( "#GEAR_VANGUARD_CORE8_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 9:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE9" ), Localize( "#GEAR_VANGUARD_CORE9_UPGRADEDESC" ), <255, 135, 10> )
			break
	}
}
#endif