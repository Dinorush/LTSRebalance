global function LTSRebalance_LogInit
global function LTSRebalance_GetLogStruct
global function LTSRebalance_LogDamageBlocked
global function LTSRebalance_LogDamageBlockedRaw
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
	pas_auto_eject =			"Spectate"

	pas_ion_vortex =            "Point-Five Tripwire",
	pas_tone_wall =             "Light Particle Wall"
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

const table<string, string> MAPNAME_TO_STRING = {
	mp_angel_city = "Angel City",
	mp_black_water_canal = "Black Water Canal",
	mp_grave = "Boomtown",
	mp_colony02 = "Colony",
	mp_complex3 = "Complex",
	mp_crashsite3 = "Crash Site",
	mp_drydock = "Drydock",
	mp_eden = "Eden",
	mp_thaw = "Exoplanet",
	mp_forwardbase_kodai = "Forwardbase Kodai",
	mp_glitch = "Glitch",
	mp_homestead = "Homestead",
	mp_relic02 = "Relic",
	mp_rise = "Rise",
	mp_wargames = "War Games"
}

/*
	Contains all the data specific to the player to be recorded and printed out to logs for external analysis.
	If a value does not specify pilot, it will not be affected if the player is a pilot. Conversely, titans will not affect pilot stats.
	Values that can be acquired globally (e.g. win, round, rebalance) are not held by the struct.
*/

global struct LTSRebalance_LogStruct {
	string name = ""
	string uid = ""
	int team = 0

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
	int damageDealtBlockedTarget = 0 // Damage to defensives that would've hit an enemy titan
	int damageDealtSelf = 0 // Includes health, shields, temp shields. Self damage is not tracked by other dealt values
	int damageDealtCloseAlly = 0
	int damageDealtCloseEnemy = 0
	float critRateDealt = 0.0

	int damageTaken = 0 // Excludes damage blocked
	int damageTakenShields = 0
	int damageTakenTempShields = 0
	int damageTakenAuto = 0
	int damageTakenBlocked = 0 // Damage to defensives
	int damageTakenBlockedTarget = 0 // Damage to defensives that would've hit a friendly titan (exc. self blocked damage)
	float critRateTaken = 0.0

	int kills = 0
	int killsPilot = 0
	int terminations = 0
	int terminationDamage = 0 // Health + Shields skipped by termination. Damage dealt includes this.
	float coreFracEarned = 0.0
	int coresUsed = 0

	int batteriesPicked = 0
	int batteriesToSelf = 0
	int batteriesToAllyPilot = 0
	int shieldsGained = 0
	int tempShieldsGained = 0
	int healthWasted = 0 // Health + permanent shield overflow and loss from ejection/termination. Damage taken includes wasted health + shield from termination.
	int shieldsWasted = 0

	float timeAsTitan = 0.0
	float timeDeathTitan = 0.0
	float timeAsPilot = 0.0
	float timeDeathPilot = 0.0
	bool ejection = false

	float distanceToAllies = 0.0 // All distance values except 'travelled' are averages.
	float distanceToCloseAlly = 0.0
	float distanceToCenterAllies = 0.0
	float distanceToEnemies = 0.0
	float distanceToCloseEnemy = 0.0
	float distanceToCenterEnemies = 0.0
	float distanceToBatteries = 0.0
	float distanceToCloseBattery = 0.0
	float distanceBetweenCenters = 0.0
	float distanceOnCritDealt = 0.0
	float distanceOnNonCritDealt = 0.0
	float distanceTravelled = 0.0

	float distanceToAlliesPilot = 0.0
	float distanceToCloseAllyPilot = 0.0
	float distanceToEnemiesPilot = 0.0
	float distanceToCloseEnemyPilot = 0.0
	float distanceTravelledPilot = 0.0

	int[4] critRateHelper = [0, 0, 0, 0] // Non-crit counter, crit counter, non-crit received counter, crit-received counter
	array<entity> closeTitanDamageHelper
}

struct {
	table< entity, LTSRebalance_LogStruct > trackerTable
	string matchID
	int matchTimestamp
	bool logDistance = false
	array< entity > batteries
} file


void function LTSRebalance_LogInit()
{
	if ( GAMETYPE != LAST_TITAN_STANDING || GetMapName() == "mp_lobby" )
		return
	// Not a unique random! Also not sure how it's seeded. Solely a shortstop to separate matches among the log for parsers. 
	// If needed as a unique ID after pulling logs, generate a new ID instead with a more robust algorithm to ensure uniqueness.
	file.matchID = RandomInt(10000000).tostring()
	file.matchTimestamp = GetUnixTimestamp()

	AddSpawnCallback( "npc_titan", LTSRebalance_InitTracker )
	AddCallback_OnPlayerRespawned( LTSRebalance_StartTracking )
	AddCallback_OnRoundEndCleanup( LTSRebalance_ClearLogTrackers )
	AddPostDamageCallback( "player", LTSRebalance_LogDamage )
	AddPostDamageCallback( "npc_titan", LTSRebalance_LogDamage )
	AddCallback_OnPlayerKilled( LTSRebalance_LogKill )
	AddCallback_OnNPCKilled( LTSRebalance_LogKill )
	AddSyncedMeleeServerCallback( GetSyncedMeleeChooser( "titan", "titan" ), LTSRebalance_LogTermination )

	AddSpawnCallbackEditorClass( "script_ref", "script_power_up_other", LTSRebalance_TrackBattery )
}

void function LTSRebalance_TrackBattery( entity batt )
{
	// Adds the entity so we can later get its origin
	PowerUp powerupDef = GetPowerUpFromItemRef( expect string( batt.kv.powerUpType ) )
	if ( powerupDef.spawnFunc() )
		file.batteries.append( batt )
}

// Initializes the data for a player's log struct tracker and stores it in the tracker table.
void function LTSRebalance_InitTracker( entity titan )
{
	entity player = GetPetTitanOwner( titan )
	if ( !IsValid( player ) || player in file.trackerTable )
		return

	LTSRebalance_LogStruct ls
	entity soul = titan.GetTitanSoul()
	TitanLoadoutDef loadout = soul.soul.titanLoadout

	ls.name = player.GetPlayerName()
	ls.uid = player.GetUID()
	ls.team = player.GetTeam()

	ls.titan = TITANCLASS_TO_STRING[ loadout.titanClass ]

	ls.kit1 = PASSIVE_TO_STRING[ loadout.passive1 ]
	if ( LTSRebalance_Enabled() && loadout.passive1 in LTSREBALANCE_PASSIVE_TO_STRING )
		ls.kit1 = LTSREBALANCE_PASSIVE_TO_STRING[ loadout.passive1 ]

	ls.kit2 = PASSIVE_TO_STRING[ loadout.passive2 ]
	if ( LTSRebalance_Enabled() && loadout.passive2 in LTSREBALANCE_PASSIVE_TO_STRING )
		ls.kit2 = LTSREBALANCE_PASSIVE_TO_STRING[ loadout.passive2 ]

	if ( ls.kit2 == "Spectate" )
		return

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

// Logs the ejection stat and health/shields wasted as a result.
void function LTSRebalance_LogEject( entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )

	player.WaitSignal( "TitanEjectionStarted" )

	if ( IsRoundOver() )
		return

	LTSRebalance_LogStruct ls = file.trackerTable[player]
	ls.ejection = true
	ls.healthWasted += player.GetHealth()

	entity soul = player.GetTitanSoul()
	if ( !IsValid( soul ) )
		return
	
	if ( !soul.IsDoomed() )
		ls.healthWasted += 2500
	ls.shieldsWasted += soul.GetShieldHealth()
}

// Main log tracker thread for a given player. Tracks data that lacks callbacks.
// Namely, batteries, time as class, distance values, and ejections.
// Stops collecting data on player death/disconnect and prints the results at the end of the round.
void function LTSRebalance_LogTracker( entity player )
{
	LTSRebalance_LogStruct ls = file.trackerTable[player]
	table< string, array<int> > counters = {
		allies = [0, 0],
		enemies = [0, 0],
		centers = [0, 0, 0],
		batteries = [0, 0],
		alliesPilot = [0, 0],
		enemiesPilot = [0, 0]
	}


	int curScore = GameRules_GetTeamScore2( TEAM_IMC ) + GameRules_GetTeamScore2( TEAM_MILITIA )

	if ( IsValid( player ) )
		waitthread WaitUntilEmbarkOrDeath( player )

	if ( !IsValid( player ) )
		return

	OnThreadEnd(
		function() : ( ls, counters )
		{

			// Average out some values (we want the average in logs)
			if ( counters.allies[0] > 0 )
			{
				ls.distanceToAllies /= counters.allies[0]
				ls.distanceToCloseAlly /= counters.allies[1]
			}

			if ( counters.enemies[0] > 0 )
			{
				ls.distanceToEnemies /= counters.enemies[0]
				ls.distanceToCloseEnemy /= counters.enemies[1]
			}

			if ( counters.centers[0] > 0 )
				ls.distanceToCenterAllies /= counters.centers[0]
			if ( counters.centers[1] > 0 )
				ls.distanceToCenterEnemies /= counters.centers[1]
			if ( counters.centers[2] > 0 )
				ls.distanceBetweenCenters /= counters.centers[2]

			if ( counters.batteries[0] > 0 )
			{
				ls.distanceToBatteries /= counters.batteries[0]
				ls.distanceToCloseBattery /= counters.batteries[1]
			}

			if ( counters.alliesPilot[0] > 0 )
			{
				ls.distanceToAlliesPilot /= counters.alliesPilot[0]
				ls.distanceToCloseAllyPilot /= counters.alliesPilot[1]
			}
			
			if ( counters.enemiesPilot[0] > 0 )
			{
				ls.distanceToEnemiesPilot /= counters.enemiesPilot[0]
				ls.distanceToCloseEnemyPilot /= counters.enemiesPilot[1]
			}

			ls.distanceOnCritDealt = ls.distanceOnCritDealt > 0 ? ls.distanceOnCritDealt / ls.critRateHelper[1] : 0.0
			ls.distanceOnNonCritDealt = ls.distanceOnNonCritDealt > 0 ? ls.distanceOnNonCritDealt / ls.critRateHelper[0] : 0.0
			if ( ls.critRateHelper[0] == 0 )
				ls.critRateDealt = ls.critRateHelper[1] > 0 ? 1.0 : 0.0
			else
				ls.critRateDealt = float( ls.critRateHelper[1] ) / float( ls.critRateHelper[1] + ls.critRateHelper[0] )

			if ( ls.critRateHelper[2] == 0 )
				ls.critRateTaken = ls.critRateHelper[3] > 0 ? 1.0 : 0.0
			else
				ls.critRateTaken = float( ls.critRateHelper[3] ) / float( ls.critRateHelper[3] + ls.critRateHelper[2] )

			LTSRebalance_PrintLogTracker( ls )
		}
	)
	
	thread LTSRebalance_LogEject( player )
	waitthread LTSRebalance_LogThink( player, ls, counters )
}

void function LTSRebalance_LogThink( entity player, LTSRebalance_LogStruct ls, table< string, array<int> > counters )
{
	svGlobal.levelEnt.EndSignal( "RoundEnd" )

	vector lastOrigin = player.GetOrigin()
	entity[2] closeTitans = [null, null] // Ally, enemy
	bool hasBattery = false
	float lastTime = Time()
	while ( IsAlive( player ) )
	{
		float timePassed = Time() - lastTime

		if ( file.logDistance )
			LTSRebalance_LogDistanceToOthers( player, ls, counters, closeTitans )

		if ( player.IsTitan() )
		{
			ls.distanceTravelled += Distance( lastOrigin, player.GetOrigin() )
			ls.timeAsTitan += timePassed
		}
		else
		{
			if ( !hasBattery && PlayerHasBattery( player ) )
				ls.batteriesPicked++
			hasBattery = PlayerHasBattery( player )

			ls.distanceTravelledPilot += Distance( lastOrigin, player.GetOrigin() )
			ls.timeAsPilot += timePassed
		}
		
		lastOrigin = player.GetOrigin()
		lastTime = Time()

		WaitFrame()
	}

	// Thread uses Round End signal to end
	WaitForever()
}

void function WaitUntilEmbarkOrDeath( entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )

	player.WaitSignal( "PlayerEmbarkedTitan" )
}

bool function PlayerOrTitanAlive( entity player )
{
	if ( !IsValid( player ) )
		return false
	
	return IsAlive( player ) || IsAlive( player.GetPetTitan() )
}

// Logs all distance values excluding crit-related distance stats.
void function LTSRebalance_LogDistanceToOthers( entity player, LTSRebalance_LogStruct ls, table< string, array<int> > counters, entity[2] closeTitans )
{
	bool isTitan = player.IsTitan()

	float closestAllyDist = 99999.0
	entity closestAlly = null
	float closestEnemyDist = 99999.0
	entity closestEnemy = null
	vector allyCenter = <0, 0, 0>
	vector enemyCenter = <0, 0, 0>
	int allyCounter = 0
	int enemyCounter = 0

	array<entity> titans = GetPlayerArray()
	titans.extend( GetNPCArrayByClass( "npc_titan" ) )
	foreach ( titan in titans )
	{	
		if ( !titan.IsTitan() || !IsAlive( titan ) )
			continue

		if ( titan == player )
			continue

		if ( titan.GetTeam() == player.GetTeam() )
		{
			if ( isTitan )
			{
				allyCounter++
				allyCenter += titan.GetOrigin()
				counters.allies[0]++
			}
			else
				counters.alliesPilot[0]++
			
			float dist = Distance( titan.GetOrigin(), player.GetOrigin() )
			if ( isTitan )
				ls.distanceToAllies += dist
			else
				ls.distanceToAlliesPilot += dist

			if ( dist < closestAllyDist )
			{
				closestAllyDist = dist
				closestAlly = titan
			}
		}
		else
		{
			if ( isTitan )
			{
				enemyCounter++
				enemyCenter += titan.GetOrigin()
				counters.enemies[0]++
			}
			else
				counters.enemiesPilot[0]++
			
			float dist = Distance( titan.GetOrigin(), player.GetOrigin() )
			if ( isTitan )
				ls.distanceToEnemies += dist
			else
				ls.distanceToEnemiesPilot += dist

			if ( dist < closestEnemyDist )
			{
				closestEnemyDist = dist
				closestEnemy = titan
			}
		}
	}

	if ( isTitan )
	{
		LTSRebalance_LogStruct ornull cls
		if ( closestAlly != closeTitans[0] )
		{
			cls = LTSRebalance_GetLogStruct( closeTitans[0] )
			if ( cls != null )
				( expect LTSRebalance_LogStruct( cls ) ).closeTitanDamageHelper.fastremovebyvalue( player )

			cls = LTSRebalance_GetLogStruct( closestAlly )
			if ( cls != null )
				( expect LTSRebalance_LogStruct( cls ) ).closeTitanDamageHelper.append( player )

			closeTitans[0] = closestAlly
		}
		if ( closestEnemy != closeTitans[1] )
		{
			cls = LTSRebalance_GetLogStruct( closeTitans[1] )
			if ( cls != null )
				( expect LTSRebalance_LogStruct( cls ) ).closeTitanDamageHelper.fastremovebyvalue( player )

			cls = LTSRebalance_GetLogStruct( closestEnemy )
			if ( cls != null )
				( expect LTSRebalance_LogStruct( cls ) ).closeTitanDamageHelper.append( player )

			closeTitans[1] = closestEnemy
		}
	}

	if ( closestAllyDist < 99999.0 )
	{
		
		if ( isTitan )
		{
			ls.distanceToCloseAlly += closestAllyDist
			counters.allies[1]++
		}
		else
		{
			ls.distanceToCloseAllyPilot += closestAllyDist
			counters.alliesPilot[1]++
		}
	}
	if ( closestEnemyDist < 99999.0 )
	{
		if ( isTitan )
		{
			ls.distanceToCloseEnemy += closestEnemyDist
			counters.enemies[1]++
		}
		else
		{
			ls.distanceToCloseEnemyPilot += closestEnemyDist
			counters.enemiesPilot[1]++
		} 
	}

	if ( allyCounter > 1 )
	{
		allyCenter /= allyCounter
		ls.distanceToCenterAllies += Distance( player.GetOrigin(), allyCenter )
		counters.centers[0]++
	}
	if ( enemyCounter > 1 )
	{
		enemyCenter /= enemyCounter
		ls.distanceToCenterEnemies += Distance( player.GetOrigin(), enemyCenter )
		counters.centers[1]++
	}
	if ( allyCounter > 1 && enemyCounter > 1 )
	{
		ls.distanceBetweenCenters += Distance( allyCenter, enemyCenter )
		counters.centers[2]++
	}
	if ( !isTitan )
		return

	float closestBattDist = 99999.0
	for ( int i = file.batteries.len() - 1; i >= 0; i-- )
	{
		entity batt = file.batteries[i]
		if ( !IsValid( batt ) )
		{
			file.batteries.remove( i )
			continue
		}
		
		counters.batteries[0]++

		float dist = Distance( player.GetOrigin(), batt.GetOrigin() )
		ls.distanceToBatteries += dist

		if ( dist < closestBattDist )
			closestBattDist = dist
	}

	if ( closestBattDist < 99999.0 )
	{
		ls.distanceToCloseBattery += closestBattDist
		counters.batteries[1]++
	}
}

// Logs kills and the victim's time of death.
void function LTSRebalance_LogKill( entity victim, entity attacker, var damageInfo )
{
	LTSRebalance_LogStruct ornull ls
	if ( victim.IsPlayer() )
	{
		ls = LTSRebalance_GetLogStruct( victim )
		if ( ls != null )
		{
			expect LTSRebalance_LogStruct( ls )
			ls.timeDeathPilot = GetTimeSinceRoundStart()
		}
	}

	if ( !victim.IsTitan() )
		return

	ls = LTSRebalance_GetLogStruct( victim )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.timeDeathTitan = GetTimeSinceRoundStart()
	}

	if ( attacker == victim )
		return

	ls = LTSRebalance_GetLogStruct( attacker )

	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		if ( attacker.IsTitan() )
			ls.kills++
		else
			ls.killsPilot++
	}
}

// Logs terminations and the damage they've dealt, as well as the health and shields wasted on the victim.
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

// Logs health damage done to a titan, as well as crit-related stats.
void function LTSRebalance_LogDamage( entity victim, var damageInfo )
{
	if ( !victim.IsTitan() )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	bool selfDmg = victim == attacker
	if ( !selfDmg && !IsRoundOver() )
		file.logDistance = true

	int critHit = CritWeaponInDamageInfo( damageInfo ) && !selfDmg ? 1 : 0
	if ( critHit > 0 )
		critHit = IsCriticalHit( DamageInfo_GetAttacker( damageInfo ), victim, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamage( damageInfo ), DamageInfo_GetDamageType( damageInfo ) ).tointeger() + 1

	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( victim )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.damageTaken += int( DamageInfo_GetDamage( damageInfo ) )
		if ( victim.IsNPC() )
			ls.damageTakenAuto += int( DamageInfo_GetDamage( damageInfo ) )
		if ( critHit > 0 )
			ls.critRateHelper[ critHit + 1 ]++
	}

	if ( IsValid( attacker ) )
	{
		ls = LTSRebalance_GetLogStruct( attacker )
		if ( ls != null )
		{
			expect LTSRebalance_LogStruct( ls )
			if ( attacker.IsTitan() )
			{
				if ( selfDmg )
					ls.damageDealtSelf += int( DamageInfo_GetDamage( damageInfo ) )
				else
				{
					ls.damageDealt += int( DamageInfo_GetDamage( damageInfo ) )
					if ( attacker.IsNPC() )
						ls.damageDealtAuto += int( DamageInfo_GetDamage( damageInfo ) )
					LTSRebalance_LogCloseTitanDamage( ls, int( DamageInfo_GetDamage( damageInfo ) ) )

					if ( critHit > 0 )
					{
						if ( critHit == 1 )
							ls.distanceOnNonCritDealt += DamageInfo_GetDistFromAttackOrigin( damageInfo )
						else
							ls.distanceOnCritDealt += DamageInfo_GetDistFromAttackOrigin( damageInfo )
						ls.critRateHelper[ critHit - 1 ]++
					}
				}
			}
			else
				ls.damageDealtPilot += int( DamageInfo_GetDamage( damageInfo ) )
		}
	}
}

// Logs shield damage done to a titan.
void function LTSRebalance_LogShieldDamage( entity victim, var damageInfo, TitanDamage titanDamage )
{
	if ( GAMETYPE != LAST_TITAN_STANDING )
		return

	int tempShieldDamage = 0
	int shieldDamage = titanDamage.shieldDamage

	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( victim )
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
				if ( attacker == victim )
					ls.damageDealtSelf += shieldDamage + tempShieldDamage
				else
				{
					ls.damageDealt += shieldDamage + tempShieldDamage
					ls.damageDealtShields += shieldDamage
					ls.damageDealtTempShields += tempShieldDamage
					if ( attacker.IsNPC() )
						ls.damageDealtAuto += shieldDamage + tempShieldDamage
					LTSRebalance_LogCloseTitanDamage( ls, shieldDamage + tempShieldDamage )
				}
			}
			else
				ls.damageDealtPilot += shieldDamage
		}
	}
}

// Logs damage blocked from a source entity. If inflictor is a weapon, damageInfo must exist. Otherwise, inflictor must be a projectile.
// Will check whether the damage blocked would have hit an enemy by tracing along the travel path for weapons or the velocity for projectiles.
void function LTSRebalance_LogDamageBlocked( entity victim, entity attacker, entity inflictor, var damageInfo = null )
{
	if ( GAMETYPE != LAST_TITAN_STANDING )
		return
	
	if ( !IsValid( victim ) )
	{
		print( "LTS Rebalance tracker log error: Tried to log damage blocked for invalid victim")
		return
	}

	if ( !IsValid( inflictor ) )
		return
	
	bool isPlayer = !IsValid( attacker ) || attacker.IsPlayer()
	float damage = 0.0
	bool hit = false
	if ( inflictor.IsProjectile() )
	{
		damage = LTSRebalance_GetProjectileDamage( inflictor, true, isPlayer )
		TraceResults hitResult = TraceLine( inflictor.GetOrigin(), inflictor.GetOrigin() + Normalize( inflictor.GetVelocity() )*5000, [ inflictor, attacker ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
		hit = IsValid( hitResult.hitEnt ) && hitResult.hitEnt.IsTitan() && hitResult.hitEnt.GetTeam() == victim.GetTeam() && victim != attacker
	}
	else
	{
		vector hitPos = DamageInfo_GetDamagePosition( damageInfo )
		damage = LTSRebalance_GetWeaponDamage( inflictor, damageInfo, true, isPlayer )
		TraceResults hitResult = TraceLine( hitPos, hitPos + Normalize( hitPos - attacker.EyePosition() )*5000, [ attacker ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
		hit = IsValid( hitResult.hitEnt ) && hitResult.hitEnt.IsTitan() && hitResult.hitEnt.GetTeam() == victim.GetTeam() && victim != attacker
	}

	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( victim )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.damageTakenBlocked += int( damage + 0.5 )
		if ( hit )
			ls.damageTakenBlockedTarget += int( damage + 0.5 )
	}

	if ( !IsValid( attacker ) || !attacker.IsTitan() )
		return

	ls = LTSRebalance_GetLogStruct( attacker )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.damageDealtBlocked += int( damage + 0.5 )
		if ( hit )
			ls.damageDealtBlockedTarget += int( damage + 0.5 )
	}
}

// Logs damage blocked by a given amount. Hit boolean controls whether the damage would have hit the target.
// Primarily for functions that can already assume whether the shot would have hit (e.g. damage reduction).
void function LTSRebalance_LogDamageBlockedRaw( entity victim, entity attacker, float damage, bool hit = false )
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
		if ( hit )
			ls.damageTakenBlockedTarget += int( damage + 0.5 )
	}

	if ( !IsValid( attacker ) || !attacker.IsTitan() )
		return

	ls = LTSRebalance_GetLogStruct( attacker )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.damageDealtBlocked += int( damage + 0.5 )
		if ( hit )
			ls.damageDealtBlockedTarget += int( damage + 0.5 )
	}
}

// Logs damage dealt by a player to all players who register it as their closest titan.
void function LTSRebalance_LogCloseTitanDamage( LTSRebalance_LogStruct ls, int damage )
{
	for ( int i = ls.closeTitanDamageHelper.len() - 1; i >= 0; i-- )
	{
		entity closeTitan = ls.closeTitanDamageHelper[i]
		if ( !IsValid( closeTitan ) )
		{
			ls.closeTitanDamageHelper.remove( i )
			continue
		}
		
		LTSRebalance_LogStruct ornull cls = LTSRebalance_GetLogStruct( closeTitan )
		if ( cls == null )
			continue

		expect LTSRebalance_LogStruct( cls )
		if ( closeTitan.GetTeam() == ls.team )
			cls.damageDealtCloseAlly += damage
		else
			cls.damageDealtCloseEnemy += damage
	}
}

// Returns the log struct corresponding to an ent, or null if not found.
// Can find the log struct for the auto titan or titan soul of the player, or the player themselves.
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

float function GetTimeSinceRoundStart()
{
	return Time() - expect float( GetServerVar( "roundStartTime" ) )
}

// Prints out all the data for a given log struct.
void function LTSRebalance_PrintLogTracker( LTSRebalance_LogStruct ls )
{
	int round = GetRoundsPlayed()
	string result = "Draw"
	if ( GetWinningTeam() != TEAM_UNASSIGNED )
		result = GetWinningTeam() == ls.team ? "Win" : "Loss"

	// Can't print everything in one line if it's too long, so we segment the data into blocks.
	string block1 = "[LTSRebalanceData] {\"uid\":\"" + ls.uid + "\""
	block1 += ",\"round\":" + round.tostring()
	block1 += ",\"matchID\":\"" + file.matchID + "\""
	block1 += ",\"ranked\":" + ( GetCurrentPlaylistVarInt( "ltsrebalance_log_ranked", 0 ) == 1 ).tostring()
	block1 += ",\"matchTimestamp\":" + file.matchTimestamp.tostring()
	block1 += ",\"version\":\"" + NSGetModVersionByModName( "Dinorush's LTS Rebalance" ) + "\""

	block1 += ",\"name\":\"" + ls.name + "\""
	block1 += ",\"rebalance\":" + LTSRebalance_Enabled().tostring()
	block1 += ",\"perfectKits\":" + PerfectKits_Enabled().tostring()
	block1 += ",\"mapName\":\"" + MAPNAME_TO_STRING[ GetMapName() ] + "\""
	block1 += ",\"team\":" + ls.team.tostring()
	block1 += ",\"result\":\"" + result + "\""
	block1 += ",\"roundDuration\":" + GetTimeSinceRoundStart().tostring()

	block1 += ",\"titan\":\"" + ls.titan + "\""
	block1 += ",\"kit1\":\"" + ls.kit1 + "\""
	block1 += ",\"kit2\":\"" + ls.kit2 + "\""
	block1 += ",\"core1\":\"" + ls.core1 + "\""
	block1 += ",\"core2\":\"" + ls.core2 + "\""
	block1 += ",\"core3\":\"" + ls.core3 + "\""

	block1 += ",\"damageDealt\":" + ls.damageDealt.tostring()
	block1 += ",\"damageDealtShields\":" + ls.damageDealtShields.tostring()
	block1 += ",\"damageDealtTempShields\":" + ls.damageDealtTempShields.tostring()
	block1 += ",\"damageDealtAuto\":" + ls.damageDealtAuto.tostring()
	block1 += ",\"damageDealtPilot\":" + ls.damageDealtPilot.tostring()
	block1 += ",\"damageDealtBlocked\":" + ls.damageDealtBlocked.tostring()
	block1 += ",\"damageDealtBlockedTarget\":" + ls.damageDealtBlockedTarget.tostring()
	block1 += ",\"damageDealtSelf\":" + ls.damageDealtSelf.tostring()
	block1 += ",\"damageDealtCloseAlly\":" + ls.damageDealtCloseAlly.tostring()
	block1 += ",\"damageDealtCloseEnemy\":" + ls.damageDealtCloseEnemy.tostring()
	block1 += ",\"critRateDealt\":" + ls.critRateDealt.tostring()
	block1 += "}"

	string block2 = "[LTSRebalanceData] {\"uid\":\"" + ls.uid + "\""
	block2 += ",\"round\":" + round.tostring()
	block2 += ",\"matchID\":\"" + file.matchID + "\""
	
	block2 += ",\"damageTaken\":" + ls.damageTaken.tostring()
	block2 += ",\"damageTakenShields\":" + ls.damageTakenShields.tostring()
	block2 += ",\"damageTakenTempShields\":" + ls.damageTakenTempShields.tostring()
	block2 += ",\"damageTakenAuto\":" + ls.damageTakenAuto.tostring()
	block2 += ",\"damageTakenBlocked\":" + ls.damageTakenBlocked.tostring()
	block2 += ",\"damageTakenBlockedTarget\":" + ls.damageTakenBlockedTarget.tostring()
	block2 += ",\"critRateTaken\":" + ls.critRateTaken.tostring()
	block2 += ",\"kills\":" + ls.kills.tostring()
	block2 += ",\"killsPilot\":" + ls.killsPilot.tostring()
	block2 += ",\"terminations\":" + ls.terminations.tostring()
	block2 += ",\"terminationDamage\":" + ls.terminationDamage.tostring()
	block2 += ",\"coreFracEarned\":" + ls.coreFracEarned.tostring()
	block2 += ",\"coresUsed\":" + ls.coresUsed.tostring()

	block2 += ",\"batteriesPicked\":" + ls.batteriesPicked.tostring()
	block2 += ",\"batteriesToSelf\":" + ls.batteriesToSelf.tostring()
	block2 += ",\"batteriesToAllyPilot\":" + ls.batteriesToAllyPilot.tostring()
	block2 += ",\"shieldsGained\":" + ls.shieldsGained.tostring()
	block2 += ",\"tempShieldsGained\":" + ls.tempShieldsGained.tostring()
	block2 += ",\"healthWasted\":" + ls.healthWasted.tostring()
	block2 += ",\"shieldsWasted\":" + ls.shieldsWasted.tostring()
	block2 += "}"

	string block3 = "[LTSRebalanceData] {\"uid\":\"" + ls.uid + "\""
	block3 += ",\"round\":" + round.tostring()
	block3 += ",\"matchID\":\"" + file.matchID + "\""

	block3 += ",\"timeAsTitan\":" + ls.timeAsTitan.tostring()
	block3 += ",\"timeDeathTitan\":" + ls.timeDeathTitan.tostring()
	block3 += ",\"timeAsPilot\":" + ls.timeAsPilot.tostring()
	block3 += ",\"timeDeathPilot\":" + ls.timeDeathPilot.tostring()
	block3 += ",\"ejection\":" + ls.ejection.tostring()

	block3 += ",\"avgDistanceToAllies\":" + ls.distanceToAllies.tostring()
	block3 += ",\"avgDistanceToCloseAlly\":" + ls.distanceToCloseAlly.tostring()
	block3 += ",\"avgDistanceToCenterAllies\":" + ls.distanceToCenterAllies.tostring()
	block3 += ",\"avgDistanceToEnemies\":" + ls.distanceToEnemies.tostring()
	block3 += ",\"avgDistanceToCloseEnemy\":" + ls.distanceToCloseEnemy.tostring()
	block3 += ",\"avgDistanceToCenterEnemies\":" + ls.distanceToCenterEnemies.tostring()
	block3 += ",\"avgDistanceBetweenCenters\":" + ls.distanceBetweenCenters.tostring()
	block3 += ",\"avgDistanceToBatteries\":" + ls.distanceToBatteries.tostring()
	block3 += ",\"avgDistanceToCloseBattery\":" + ls.distanceToCloseBattery.tostring()
	block3 += ",\"avgDistanceOnCritDealt\":" + ls.distanceOnCritDealt.tostring()
	block3 += ",\"avgDistanceOnNonCritDealt\":" + ls.distanceOnNonCritDealt.tostring()

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
	file.logDistance = false
	file.trackerTable.clear()
	file.batteries.clear()
}