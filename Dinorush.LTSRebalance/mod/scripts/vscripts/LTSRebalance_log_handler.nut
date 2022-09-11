global function LTSRebalance_LogInit
global function LTSRebalance_GetLogStruct
global function LTSRebalance_LogDamageBlocked
global function LTSRebalance_LogShieldDamage

const table<string, string> PASSIVE_TO_STRING = {
	pas_enhanced_titan_ai =     "Assault Chip",
	pas_anti_rodeo =            "Counter Ready",
	pas_build_up_nuclear_core = "Nuclear Ejection",
	pas_hyper_core =            "Overcore",
	pas_auto_eject =            "Stealth Auto-Eject",
	pas_mobility_dash_capacity ="Turbo Engine",

	pas_ion_weapon =            "Entangled Energy",
	pas_ion_lasercannon =       "Grand Cannon",
	pas_ion_weapon_ads =        "Refraction Lens",
	pas_ion_vortex =            "Vortex Amplifier",
	pas_ion_tripwire =          "Zero-Point Tripwire",

	pas_legion_gunshield =      "Bulwark",
	pas_legion_weapon =         "Enhanced Ammo Capacity",
	pas_legion_chargeshot =     "Hidden Compartment",
	pas_legion_spinup =         "Light-Weight Alloys",
	pas_legion_smartcore =      "Sensor Array",

	pas_northstar_cluster =     "Enhanced Payload",
	pas_northstar_weapon =      "Piercing Shot",
	pas_northstar_optics =      "Threat Optics",
	pas_northstar_trap =        "Twin Traps",
	pas_northstar_flightcore =  "Viper Thrusters",

	pas_ronin_swordcore =       "Highlander",
	pas_ronin_autoshift =       "Phase Reflex",
	pas_ronin_weapon =          "Ricochet Rounds",
	pas_ronin_phase =           "Temporal Anomaly",
	pas_ronin_arcwave =         "Thunderstorm",

	pas_scorch_firewall =       "Fuel for the Fire",
	pas_scorch_shield =         "Inferno Shield",
	pas_scorch_flamecore =      "Scorched Earth",
	pas_scorch_selfdmg =        "Tempered Plating",
	pas_scorch_weapon =         "Wildfire",

	pas_tone_burst =            "Burst Loader",
	pas_tone_weapon =           "Enhanced Tracker Rounds",
	pas_tone_sonar =            "Pulse Echo",
	pas_tone_wall =             "Reinforced Particle Wall",
	pas_tone_rockets =          "Rocket Barrage",

	pas_vanguard_coremeter =    "Energy Thief",
	pas_vanguard_rearm =        "Rapid Rearm",
	pas_vanguard_shield =       "Shield Amplifier",
	pas_vanguard_doom =         "Survival of the Fittest",

	pas_vanguard_core1 =        "Arc Rounds",
	pas_vanguard_core6 =        "Energy Field",
	pas_vanguard_core3 =        "Energy Transfer",
	pas_vanguard_core5 =        "Maelstrom",
	pas_vanguard_core2 =        "Missile Racks",
	pas_vanguard_core7 =        "Multi-Target Missiles",
	pas_vanguard_core4 =        "Rearm and Reload",
	pas_vanguard_core8 =        "Superior Chassis",
	pas_vanguard_core9 =        "XO-16 Accelerator"
}

const table<string, string> LTSREBALANCE_PASSIVE_TO_STRING = {
	pas_enhanced_titan_ai =     "Big Punch",
	pas_build_up_nuclear_core = "Unstable Reactor",

	pas_ion_lasercannon =       "Light Cannon"
}

const table<string, string> TITANCLASS_TO_STRING = {
	ion = "Ion",
	legion = "Legion",
	northstar = "Northstar",
	ronin = "Ronin",
	scorch = "Scorch",
	tone = "Tone",
	vanguard = "Monarch"
}

/*
	Contains all the data to be recorded and printed out to logs for external analysis.
	If a value does not specify pilot, it will not be affected if the player is a pilot. Conversely, titans will not affect pilot stats.
*/
global struct LTSRebalance_LogStruct {
	bool rebalance = false
	bool perfectKits = false
	int round = 0
	string mapName = ""

	string name = ""
	string titan = ""
	string kit1 = ""
	string kit2 = ""
	string core1 = ""
	string core2 = ""
	string core3 = ""

	int damageDealt = 0 // Excludes damage blocked
	int damageDealtShields = 0
	int damageDealtTempShields = 0
	int damageDealtPilot = 0
	int damageDealtAuto = 0
	int damageDealtBlocked = 0 // Damage to defensives
	int damageTaken = 0 // Excludes damage blocked
	int damageTakenShields = 0
	int damageTakenTempShields = 0
	int damageTakenAuto = 0
	int damageTakenBlocked = 0 // Damage to defensives

	int kills = 0
	int killsPilot = 0
	int terminations = 0
	int terminationDamage = 0 // Health + Shields skipped by termination. Damage dealt includes this.
	float coreFracEarned = 0.0
	int coresUsed = 0

	int batteriesPicked = 0
	int batteriesToSelf = 0
	int batteriesToAlly = 0
	int shieldsGained = 0
	int tempShieldsGained = 0
	int healthWasted = 0 // Health + permanent shield overflow and loss from ejection/termination. Damage taken includes wasted health + shield from termination.
	int shieldsWasted = 0

	float timeLeftStart = 0.0
	float timeAsTitan = 0.0
	float timeLeftDeathTitan = 0.0
	float timeAsPilot = 0.0
	float timeLeftDeathPilot = 0.0
	bool ejection = false

	float distanceToAllies = 0.0 // All distance values except 'travelled' are averages.
	float distanceToCloseAlly = 0.0
	float distanceToEnemies = 0.0
	float distanceToCloseEnemy = 0.0
	float distanceTravelled = 0.0
	float distanceToAlliesPilot = 0.0
	float distanceToCloseAllyPilot = 0.0
	float distanceToEnemiesPilot = 0.0
	float distanceToCloseEnemyPilot = 0.0
	float distanceTravelledPilot = 0.0
}

struct {
	table< entity, LTSRebalance_LogStruct > trackerTable
	int matchID
} file


void function LTSRebalance_LogInit()
{
	if ( GAMETYPE != LAST_TITAN_STANDING || GetMapName() == "mp_lobby" )
		return
	// Not a fallible random! Also not sure how it's seeded. Solely a shortstop to separate matches among the log for parsers. 
	// If needed as a unique ID after pulling logs, generate a new ID instead with a more robust algorithm to ensure uniqueness.
	file.matchID = RandomInt(10000000)

	AddSpawnCallback( "npc_titan", LTSRebalance_InitTracker )
	AddCallback_OnPlayerRespawned( LTSRebalance_StartTracking )
	AddCallback_OnRoundEndCleanup( LTSRebalance_ClearLogTrackers )
	AddPostDamageCallback( "player", LTSRebalance_LogDamage )
	AddPostDamageCallback( "npc_titan", LTSRebalance_LogDamage )
	AddCallback_OnPlayerKilled( LTSRebalance_LogKill )
	AddCallback_OnNPCKilled( LTSRebalance_LogKill )
	AddSyncedMeleeServerCallback( GetSyncedMeleeChooser( "titan", "titan" ), LTSRebalance_LogTermination )
}

void function LTSRebalance_InitTracker( entity titan )
{
	entity player = GetPetTitanOwner( titan )
	if ( !IsValid( player ) || player in file.trackerTable )
		return

	LTSRebalance_LogStruct ls
	entity soul = titan.GetTitanSoul()
	TitanLoadoutDef loadout = soul.soul.titanLoadout

	ls.name = player.GetPlayerName()
	ls.titan = TITANCLASS_TO_STRING[ loadout.titanClass ]

	ls.kit1 = PASSIVE_TO_STRING[ loadout.passive1 ]
	if ( LTSRebalance_Enabled() && loadout.passive1 in LTSREBALANCE_PASSIVE_TO_STRING )
		ls.kit1 = LTSREBALANCE_PASSIVE_TO_STRING[ loadout.passive1 ]

	ls.kit2 = PASSIVE_TO_STRING[ loadout.passive2 ]
	if ( LTSRebalance_Enabled() && loadout.passive2 in LTSREBALANCE_PASSIVE_TO_STRING )
		ls.kit2 = LTSREBALANCE_PASSIVE_TO_STRING[ loadout.passive2 ]

	if ( loadout.titanClass == "vanguard" )
	{
		ls.core1 = PASSIVE_TO_STRING[ loadout.passive4 ]
		ls.core2 = PASSIVE_TO_STRING[ loadout.passive5 ]
		ls.core3 = PASSIVE_TO_STRING[ loadout.passive6 ]
	}
	else
	{
		ls.core1 = "N/A"
		ls.core2 = "N/A"
		ls.core3 = "N/A"
	}

	if ( loadout.passive1 == "pas_hyper_core" ) // Account for first spawn Overcore (Overcore % after using core is handled in sh_titancore_utility)
		ls.coreFracEarned += 0.20

	file.trackerTable[player] <- ls
}

void function LTSRebalance_StartTracking( entity player )
{
	if ( !( player in file.trackerTable ) )
	{
		print( "LTS Rebalance log tracker error: Player respawned, but no logging struct exists for them")
		return
	}

	thread LTSRebalance_LogTracker( player )
}

void function LTSRebalance_LogEject( entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	svGlobal.levelEnt.EndSignal( "RoundEnd" )

	player.WaitSignal( "TitanEjectionStarted" )

	LTSRebalance_LogStruct ls = file.trackerTable[player]
	ls.ejection = true
	ls.healthWasted += player.GetHealth()

	entity soul = player.GetTitanSoul()
	if ( !IsValid( soul ) )
		return
	
	if ( soul.IsDoomed() )
		ls.healthWasted += 2500
	ls.shieldsWasted += soul.GetShieldHealth()
}

void function LTSRebalance_LogTitanDeath( entity titan, LTSRebalance_LogStruct ls )
{
	svGlobal.levelEnt.EndSignal( "RoundEnd" )
	titan.EndSignal( "OnDestroy" )
	titan.WaitSignal( "OnDeath" )

	if ( !IsRoundOver() )
		ls.timeLeftDeathTitan = GetGameTimeLeft()
}

void function LTSRebalance_LogTracker( entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )

	LTSRebalance_LogStruct ls = file.trackerTable[player]
	int[8] counters = [ 0, 0, 0, 0, 0, 0, 0, 0 ]
	OnThreadEnd(
		function() : ( player, ls, counters )
		{
			print( "THREAD ENDED")
			if ( !IsAlive( player ) )
			{
				if ( player.IsTitan() )
					ls.timeLeftDeathTitan = GetGameTimeLeft()
				else if ( IsValid( player ) && IsAlive( player.GetPetTitan() ) )
					thread LTSRebalance_LogTitanDeath( player.GetPetTitan(), ls )
				ls.timeLeftDeathPilot = GetGameTimeLeft()
			}

			// Average out some values (we want the average in logs)
			if ( counters[0] > 0 )
			{
				ls.distanceToAllies /= counters[0]
				ls.distanceToCloseAlly /= counters[1]
			}
			if ( counters[2] > 0 )
			{
				ls.distanceToEnemies /= counters[2]
				ls.distanceToCloseEnemy /= counters[3]
			}
			if ( counters[4] > 0 )
			{
				ls.distanceToAlliesPilot /= counters[4]
				ls.distanceToCloseAllyPilot /= counters[5]
			}
			if ( counters[6] > 0 )
			{
				ls.distanceToEnemiesPilot /= counters[6]
				ls.distanceToCloseEnemyPilot /= counters[7]
			}

			LTSRebalance_PrintLogTracker( ls )
		}
	)

	ls.rebalance = LTSRebalance_Enabled()
	ls.perfectKits = PerfectKits_Enabled()
	ls.round = GetRoundsPlayed() + 1
	ls.mapName = GetMapName()
	ls.timeLeftStart = GetGameTimeLeft()
	int curScore = GameRules_GetTeamScore2( TEAM_IMC ) + GameRules_GetTeamScore2( TEAM_MILITIA )
	bool hasBattery = false

	player.WaitSignal( "PlayerEmbarkedTitan" )

	vector lastOrigin = player.GetOrigin()

	float lastTime = Time()
	while ( GameRules_GetTeamScore2( TEAM_IMC ) + GameRules_GetTeamScore2( TEAM_MILITIA ) == curScore )
	{
		WaitFrame()
		float timePassed = Time() - lastTime
		
		float closestAllyDist = 99999.0
		float closestEnemyDist = 99999.0
		if ( player.IsTitan() )
		{
			array<entity> titans = GetPlayerArray()
			titans.extend( GetNPCArrayByClass( "npc_titan" ) )
			foreach ( titan in titans )
			{
				if ( !titan.IsTitan() || titan == player )
					continue
				
				if ( titan.GetTeam() == player.GetTeam() )
				{
					counters[0]++
					
					float dist = Distance( titan.GetOrigin(), player.GetOrigin() )
					ls.distanceToAllies += dist
					if ( dist < closestAllyDist )
						closestAllyDist = dist
				}
				else
				{
					counters[2]++
					
					float dist = Distance( titan.GetOrigin(), player.GetOrigin() )
					ls.distanceToEnemies += dist
					if ( dist < closestEnemyDist )
						closestEnemyDist = dist
				}
			}

			if ( closestAllyDist < 99999.0 )
			{
				counters[1]++
				ls.distanceToCloseAlly += closestAllyDist
			}
			if ( closestEnemyDist < 99999.0 )
			{
				counters[3]++
				ls.distanceToCloseEnemy += closestEnemyDist 
			}
			ls.distanceTravelled += Distance( lastOrigin, player.GetOrigin() )
			ls.timeAsTitan += timePassed
		}
		else
		{
			if ( !hasBattery && PlayerHasBattery( player ) )
				ls.batteriesPicked++
			hasBattery = PlayerHasBattery( player )
		
			if ( ls.timeLeftDeathTitan == 0.0 && !IsAlive( player.GetPetTitan() ) )
				ls.timeLeftDeathTitan = GetGameTimeLeft()

			array<entity> titans = GetPlayerArray()
			titans.extend( GetNPCArrayByClass( "npc_titan" ) )
			foreach ( titan in titans )
			{
				if ( !titan.IsTitan() || titan == player.GetPetTitan() )
					continue
				
				if ( titan.GetTeam() == player.GetTeam() )
				{
					counters[4]++
					
					float dist = Distance( titan.GetOrigin(), player.GetOrigin() )
					ls.distanceToAlliesPilot += dist
					if ( dist < closestAllyDist )
						closestAllyDist = dist
				}
				else
				{
					counters[6]++
					
					float dist = Distance( titan.GetOrigin(), player.GetOrigin() )
					ls.distanceToEnemiesPilot += dist
					if ( dist < closestEnemyDist )
						closestEnemyDist = dist
				}
			}

			if ( closestAllyDist < 99999.0 )
			{
				counters[5]++
				ls.distanceToCloseAllyPilot += closestAllyDist
			}
			if ( closestEnemyDist < 99999.0 )
			{
				counters[7]++
				ls.distanceToCloseEnemyPilot += closestEnemyDist
			}
			ls.timeAsPilot += timePassed
			ls.distanceTravelledPilot += Distance( lastOrigin, player.GetOrigin() )
		}
		
		lastOrigin = player.GetOrigin()
		lastTime = Time()
	}
}

void function LTSRebalance_LogKill( entity victim, entity attacker, var damageInfo )
{
	if ( !victim.IsTitan() )
		return

	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( attacker )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		if ( attacker.IsTitan() )
			ls.kills++
		else
			ls.killsPilot++
	}
}

void function LTSRebalance_LogTermination( SyncedMeleeChooser actions, SyncedMelee action, entity attacker, entity victim )
{
	int shieldHealth = 0
	entity soul = victim.GetTitanSoul()
	if ( IsValid( soul ) )
		shieldHealth = soul.GetShieldHealth()
	
	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( attacker )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.terminations++
		ls.terminationDamage += victim.GetHealth() + shieldHealth
	}

	ls = LTSRebalance_GetLogStruct( victim )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.healthWasted += victim.GetHealth()
		ls.shieldsWasted += shieldHealth
	}
}

void function LTSRebalance_LogDamage( entity victim, var damageInfo )
{
	if ( !victim.IsTitan() )
		return

	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( victim )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.damageTaken += int( DamageInfo_GetDamage( damageInfo ) )
		if ( victim.IsNPC() )
			ls.damageTakenAuto += int( DamageInfo_GetDamage( damageInfo ) )
	}

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) )
	{
		ls = LTSRebalance_GetLogStruct( attacker )
		if ( ls != null )
		{
			expect LTSRebalance_LogStruct( ls )
			if ( attacker.IsTitan() )
			{
				ls.damageDealt += int( DamageInfo_GetDamage( damageInfo ) )
				if ( attacker.IsNPC() )
					ls.damageDealtAuto += int( DamageInfo_GetDamage( damageInfo ) )
			}
			else
				ls.damageDealtPilot += int( DamageInfo_GetDamage( damageInfo ) )
		}
	}
}

void function LTSRebalance_LogShieldDamage( entity victim, var damageInfo, TitanDamage titanDamage )
{
	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( victim )
	int tempShieldDamage = 0
	int shieldDamage = titanDamage.shieldDamage
	if ( ls != null )
	{
		entity soul = victim.GetTitanSoul()
		tempShieldDamage = minint( titanDamage.shieldDamage, LTSRebalance_GetTempShieldHealth( soul ) )
		shieldDamage -= tempShieldDamage

		expect LTSRebalance_LogStruct( ls )
		ls.damageTaken += shieldDamage + tempShieldDamage
		ls.damageTakenShields += shieldDamage
		ls.damageTakenTempShields += tempShieldDamage
		if ( victim.IsNPC() )
			ls.damageTakenAuto += shieldDamage + tempShieldDamage
	}

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) )
	{
		ls = LTSRebalance_GetLogStruct( attacker )
		if ( ls != null )
		{
			expect LTSRebalance_LogStruct( ls )
			if ( attacker.IsTitan() )
			{
				ls.damageDealt += shieldDamage + tempShieldDamage
				ls.damageDealtShields += shieldDamage
				ls.damageDealtTempShields += tempShieldDamage
				if ( attacker.IsNPC() )
					ls.damageDealtAuto += shieldDamage + tempShieldDamage
			}
			else
				ls.damageDealtPilot += shieldDamage
		}
	}
}

void function LTSRebalance_LogDamageBlocked( entity victim, entity attacker, float damage )
{
	if ( GAMETYPE != LAST_TITAN_STANDING )
		return
	
	if ( !IsValid( victim ) )
	{
		print( "LTS Rebalance tracker log error: Tried to log damage blocked for invalid victim")
		return
	}

	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( victim )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.damageTakenBlocked += int( damage + 0.5 )
	}

	if ( !IsValid( attacker ) || !attacker.IsTitan() )
		return

	ls = LTSRebalance_GetLogStruct( attacker )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.damageDealtBlocked += int( damage + 0.5 )
	}
}

LTSRebalance_LogStruct ornull function LTSRebalance_GetLogStruct( entity ent )
{
	if ( GAMETYPE != LAST_TITAN_STANDING )
		return null

	if ( !IsValid( ent ) )
		return null

	if ( ent.IsPlayer() )
		return file.trackerTable[ent]
	
	if ( !ent.IsTitan() )
	{
		if ( IsSoul( ent ) )
			return LTSRebalance_GetLogStruct( ent.GetTitan() )
		return null
	}

	entity owner = GetPetTitanOwner( ent )
	if ( !IsValid( owner ) )
		return null
	
	return file.trackerTable[owner]
}

bool function IsRoundOver()
{
	return expect float( GetServerVar( "roundEndTime" ) ) <= Time()
}

float function GetGameTimeLeft()
{
	return Time() - expect float( GetServerVar( "roundStartTime" ) )
}

void function LTSRebalance_PrintLogTracker( LTSRebalance_LogStruct ls )
{
	// Can't print everything in one line if it's too long, so we segment the data into blocks.
	string block1 = "[LTSRebalanceData] {\"name\":\"" + ls.name + "\""
	block1 += ",\"round\":" + ls.round.tostring()
	block1 += ",\"block\":1"
	block1 += ",\"matchID\":" + file.matchID.tostring()

	block1 += ",\"rebalance\":" + ls.rebalance.tostring()
	block1 += ",\"perfectKits\":" + ls.perfectKits.tostring()
	block1 += ",\"mapName\":\"" + ls.mapName + "\""

	block1 += ",\"titan\":\"" + ls.titan + "\""
	block1 += ",\"kit1\":\"" + ls.kit1 + "\""
	block1 += ",\"kit1\":\"" + ls.kit2 + "\""
	block1 += ",\"core1\":\"" + ls.core1 + "\""
	block1 += ",\"core2\":\"" + ls.core2 + "\""
	block1 += ",\"core3\":\"" + ls.core3 + "\""

	block1 += ",\"damageDealt\":" + ls.damageDealt.tostring()
	block1 += ",\"damageDealtShields\":" + ls.damageDealtShields.tostring()
	block1 += ",\"damageDealtTempShields\":" + ls.damageDealtTempShields.tostring()
	block1 += ",\"damageDealtAuto\":" + ls.damageDealtAuto.tostring()
	block1 += ",\"damageDealtPilot\":" + ls.damageDealtPilot.tostring()
	block1 += ",\"damageDealtBlocked\":" + ls.damageDealtBlocked.tostring()
	block1 += "}"

	string block2 = "[LTSRebalanceData] {\"name\":\"" + ls.name + "\""
	block2 += ",\"round\":" + ls.round.tostring()
	block2 += ",\"block\":2"
	block2 += ",\"matchID\":" + file.matchID.tostring()
	
	block2 += ",\"damageTaken\":" + ls.damageTaken.tostring()
	block2 += ",\"damageTakenShields\":" + ls.damageTakenShields.tostring()
	block2 += ",\"damageTakenTempShields\":" + ls.damageTakenTempShields.tostring()
	block2 += ",\"damageTakenAuto\":" + ls.damageTakenAuto.tostring()
	block2 += ",\"damageTakenBlocked\":" + ls.damageTakenBlocked.tostring()
	block2 += ",\"kills\":" + ls.kills.tostring()
	block2 += ",\"killsPilot\":" + ls.killsPilot.tostring()
	block2 += ",\"terminations\":" + ls.terminations.tostring()
	block2 += ",\"terminationDamage\":" + ls.terminationDamage.tostring()
	block2 += ",\"coreFracEarned\":" + ls.coreFracEarned.tostring()
	block2 += ",\"coresUsed\":" + ls.coresUsed.tostring()

	block2 += ",\"batteriesPicked\":" + ls.batteriesPicked.tostring()
	block2 += ",\"batteriesToSelf\":" + ls.batteriesToSelf.tostring()
	block2 += ",\"batteriesToAlly\":" + ls.batteriesToAlly.tostring()
	block2 += ",\"shieldsGained\":" + ls.shieldsGained.tostring()
	block2 += ",\"tempShieldsGained\":" + ls.tempShieldsGained.tostring()
	block2 += ",\"healthWasted\":" + ls.healthWasted.tostring()
	block2 += ",\"shieldsWasted\":" + ls.shieldsWasted.tostring()
	block2 += "}"

	string block3 = "[LTSRebalanceData] {\"name\":\"" + ls.name + "\""
	block3 += ",\"round\":" + ls.round.tostring()
	block3 += ",\"block\":3"
	block3 += ",\"matchID\":" + file.matchID.tostring()

	block3 += ",\"timeLeftStart\":" + ls.timeLeftStart.tostring()
	block3 += ",\"timeAsTitan\":" + ls.timeAsTitan.tostring()
	block3 += ",\"timeLeftDeathTitan\":" + ls.timeLeftDeathTitan.tostring()
	block3 += ",\"timeAsPilot\":" + ls.timeAsPilot.tostring()
	block3 += ",\"timeLeftDeathPilot\":" + ls.timeLeftDeathPilot.tostring()
	block3 += ",\"ejection\":" + ls.ejection.tostring()

	block3 += ",\"avgDistanceToAllies\":" + ls.distanceToAllies.tostring()
	block3 += ",\"avgDistanceToCloseAlly\":" + ls.distanceToCloseAlly.tostring()
	block3 += ",\"avgDistanceToEnemies\":" + ls.distanceToEnemies.tostring()
	block3 += ",\"avgDistanceToCloseEnemy\":" + ls.distanceToCloseEnemy.tostring()
	block3 += ",\"avgDistanceToAlliesPilot\":" + ls.distanceToAlliesPilot.tostring()
	block3 += ",\"avgDistanceToCloseAllyPilot\":" + ls.distanceToCloseAllyPilot.tostring()
	block3 += ",\"avgDistanceToEnemiesPilot\":" + ls.distanceToEnemiesPilot.tostring()
	block3 += ",\"avgDistanceToCloseEnemyPilot\":" + ls.distanceToCloseEnemyPilot.tostring()
	block3 += ",\"distanceTravelled\":" + ls.distanceTravelled.tostring()
	block3 += ",\"distanceTravelledPilot\":" + ls.distanceTravelledPilot.tostring()
	block3 += "}"

	print( block1 )
	print( block2 )
	print( block3 )
}

void function LTSRebalance_ClearLogTrackers()
{
	file.trackerTable.clear()
}