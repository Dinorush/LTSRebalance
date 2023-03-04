/* LTS Rebalance replaces this file for the following reasons:
   1. Fix double tick rate & multi-spawn bugs
   2. Implement baseline changes
   3. Implement Fuel for the Fire changes (LTS Rebalance + Perfect Kits)
   4. Implement Rebalance Scorched Earth changes
*/
#if SERVER
untyped
#endif

global function MpTitanAbilitySlowTrap_Init
global function OnWeaponPrimaryAttack_titanweapon_slow_trap

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_slow_trap
#endif

//TODO: Need to reassign ownership to whomever destroys the Barrel.
const asset DAMAGE_AREA_MODEL = $"models/fx/xo_shield.mdl"
const asset SLOW_TRAP_MODEL = $"models/weapons/titan_incendiary_trap/w_titan_incendiary_trap.mdl"
const asset SLOW_TRAP_FX_ALL = $"P_meteor_Trap_start"
const float LTSREBALANCE_SLOW_TRAP_LIFETIME = 8.0
const float LTSREBALANCE_SLOW_TRAP_BUILD_TIME = 0.5
const float SLOW_TRAP_LIFETIME = 12.0
const float SLOW_TRAP_BUILD_TIME = 1.0
const float SLOW_TRAP_RADIUS = 240
const asset TOXIC_FUMES_FX 	= $"P_meteor_trap_gas"
const asset TOXIC_FUMES_S2S_FX 	= $"P_meteor_trap_gas_s2s"
const asset FIRE_CENTER_FX = $"P_meteor_trap_center"
const asset BARREL_EXP_FX = $"P_meteor_trap_EXP"
const asset FIRE_LINES_FX = $"P_meteor_trap_burn"
const asset FIRE_LINES_S2S_FX = $"P_meteor_trap_burn_s2s"
const float FIRE_TRAP_MINI_EXPLOSION_RADIUS = 75
const float FIRE_TRAP_LIFETIME = 3.9
const int GAS_FX_HEIGHT = 45
const LTSREBALANCE_SLOWTRAP_DAMAGE_TICK = 30.0
const LTSREBALANCE_SLOWTRAP_DAMAGE_TICK_PILOT = 13.0

void function MpTitanAbilitySlowTrap_Init()
{
	PrecacheModel( SLOW_TRAP_MODEL )
	PrecacheParticleSystem( SLOW_TRAP_FX_ALL )
	PrecacheParticleSystem( TOXIC_FUMES_FX )
	PrecacheParticleSystem( FIRE_CENTER_FX )
	PrecacheParticleSystem( FIRE_LINES_FX )
	PrecacheParticleSystem( BARREL_EXP_FX )

	if ( GetMapName() == "sp_s2s" )
	{
		PrecacheParticleSystem( TOXIC_FUMES_S2S_FX )
		PrecacheParticleSystem( FIRE_LINES_S2S_FX )
	}


	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanability_slow_trap, FireTrap_DamagedPlayerOrNPC )
	#endif
}

#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_slow_trap( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_slow_trap( weapon, attackParams )
}
#endif

var function OnWeaponPrimaryAttack_titanweapon_slow_trap( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	ThrowDeployable( weapon, attackParams, LTSRebalance_Enabled() ? 2000.0 : 1500.0, OnSlowTrapPlanted, <0,0,0> )
	if ( PerfectKits_Enabled() )
	{
		#if CLIENT
		entity firewall = weaponOwner.GetOffhandWeapon( OFFHAND_RIGHT )
		// Client can't check titan passives, so check mod on RH weapon instead (we want client to throw the deployables)
		if ( IsValid( firewall ) && ( firewall.HasMod( "pas_scorch_firewall" ) || firewall.HasMod( "LTSRebalance_pas_scorch_firewall" ) ) )
		#else
		if ( weaponOwner.IsTitan() && IsValid( weaponOwner.GetTitanSoul() ) && SoulHasPassive( weaponOwner.GetTitanSoul(), ePassives.PAS_SCORCH_FIREWALL ) )
		#endif
		{
			vector angles = VectorToAngles( attackParams.dir )
			angles.x = 240.0 // Static upwards arc
			angles.y += 45.0
			for ( int i = 0; i < 4; i++ )
			{
				angles.y += 90.0
				attackParams.dir  = AnglesToForward( angles + < 0, RandomFloatRange( -20, 20), 0 > )
				ThrowDeployable( weapon, attackParams, 1000.0, OnSlowTrapPlanted, <0,0,0> )
			}
		}
	}
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function OnSlowTrapPlanted( entity projectile )
{
	#if SERVER
		thread DeploySlowTrap( projectile )
	#endif
}

#if SERVER
function DeploySlowTrap( entity projectile )
{
	vector origin = OriginToGround( projectile.GetOrigin() )
	vector angles = projectile.proj.savedAngles
	angles = < angles.x+90, angles.y, angles.z > // rotate 90 to face up
	entity owner = projectile.GetOwner()
	entity _parent = projectile.GetParent()
	if ( !IsValid( owner ) )
		return

	array<string> projectileMods = projectile.ProjectileGetMods()
	bool isExplosiveBarrel = false
	if ( projectileMods.contains( "fd_explosive_barrel" ) )
		isExplosiveBarrel = true

	owner.EndSignal( "OnDestroy" )
	if ( IsValid( projectile ) )
		projectile.Destroy()

	int team = owner.GetTeam()
	entity tower = CreatePropScript( SLOW_TRAP_MODEL, origin, angles, SOLID_VPHYSICS )
	tower.kv.collisionGroup = TRACE_COLLISION_GROUP_BLOCK_WEAPONS
	tower.SetMaxHealth( 100 )
	tower.SetHealth( 100 )
	tower.SetTakeDamageType( DAMAGE_NO )
	tower.SetDamageNotifications( false )
	tower.SetDeathNotifications( false )
	tower.SetArmorType( ARMOR_TYPE_HEAVY )
	tower.SetTitle( "#WPN_TITAN_SLOW_TRAP" )
	SetTargetName( tower, "#WPN_TITAN_SLOW_TRAP" )
	tower.EndSignal( "OnDestroy" )
	string noSpawnIdx = CreateNoSpawnArea( TEAM_INVALID, team, origin, SLOW_TRAP_BUILD_TIME + SLOW_TRAP_LIFETIME, SLOW_TRAP_RADIUS )
	SetTeam( tower, team )
	SetObjectCanBeMeleed( tower, false )
	SetVisibleEntitiesInConeQueriableEnabled( tower, false )
	thread TrapDestroyOnRoundEnd( owner, tower )
	if ( IsValid( _parent ) )
		tower.SetParent( _parent, "", true, 0 )

	//make npc's fire at their own traps to cut off lanes
	if ( owner.IsNPC() )
	{
		owner.SetSecondaryEnemy( tower )
		tower.EnableAttackableByAI( AI_PRIORITY_NO_THREAT, 0, AI_AP_FLAG_NONE )		// don't let other AI target this
	}

	EmitSoundOnEntity( tower, "incendiary_trap_land" )
	EmitSoundOnEntity( tower, "incendiary_trap_gas" )
	PlayLoopFXOnEntity( SLOW_TRAP_FX_ALL, tower, "smoke" )

	if ( GetMapName() != "sp_s2s" )
		CreateToxicFumesFXSpot( origin, tower )
	else
		CreateToxicFumesInWindFX( origin, tower )

	//TODO - HACK : Update to use Vortex Sphere once the Vortex Sphere explosion code feature is done.
	entity damageArea = CreatePropScript( DAMAGE_AREA_MODEL, origin, angles, 0 )
	damageArea.SetOwner( owner )
	if ( owner.IsPlayer() )
		damageArea.SetBossPlayer( owner )
	damageArea.SetMaxHealth( 100 )
	damageArea.SetHealth( 100 )
	damageArea.SetTakeDamageType( DAMAGE_NO )
	damageArea.SetDamageNotifications( false )
	damageArea.SetDeathNotifications( false )
	damageArea.SetArmorType( ARMOR_TYPE_HEAVY )
	damageArea.Hide()
	if ( IsValid( _parent ) )
		damageArea.SetParent( _parent, "", true, 0 )
	damageArea.LinkToEnt( tower )
	if ( isExplosiveBarrel )
		damageArea.SetScriptName( "explosive_barrel" )
	SetTeam( damageArea, TEAM_UNASSIGNED )
	SetObjectCanBeMeleed( damageArea, false )
	SetVisibleEntitiesInConeQueriableEnabled( damageArea, false )

	OnThreadEnd(
	function() : ( tower, noSpawnIdx, damageArea )
		{
			DeleteNoSpawnArea( noSpawnIdx )

			if ( IsValid( tower ) )
			{
				foreach ( fx in tower.e.fxArray )
				{
					if ( IsValid( fx ) )
						fx.Destroy()
				}
				tower.Destroy()
			}

			if ( IsValid( damageArea ) )
			{
				//Naturally Timed Out
				EmitSoundAtPosition( TEAM_UNASSIGNED, damageArea.GetOrigin() + <0,0,GAS_FX_HEIGHT>, "incendiary_trap_gas_stop" )
				damageArea.Destroy()
			}
		}
	)

	damageArea.EndSignal( "OnDestroy" )

	wait LTSRebalance_Enabled() ? LTSREBALANCE_SLOW_TRAP_BUILD_TIME : SLOW_TRAP_BUILD_TIME

	AddEntityCallback_OnDamaged( damageArea, OnSlowTrapDamaged )
	damageArea.SetTakeDamageType( DAMAGE_YES )

	wait LTSRebalance_Enabled() ? LTSREBALANCE_SLOW_TRAP_LIFETIME : SLOW_TRAP_LIFETIME
}

void function OnSlowTrapDamaged( entity damageArea, var damageInfo )
{
    
	//HACK - Should use damage flags, but we might be capped?
	bool shouldExplode = false
	int damageSourceID = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	switch( damageSourceID )
	{
		//case eDamageSourceId.mp_titanweapon_meteor: Secondary explosions to hit it, not the flying projectile.
		case eDamageSourceId.mp_titanweapon_meteor:
		case eDamageSourceId.mp_titanweapon_meteor_thermite:
		case eDamageSourceId.mp_weapon_thermite_grenade:
		case eDamageSourceId.mp_titancore_flame_wave:
		case eDamageSourceId.mp_titancore_flame_wave_secondary:
		case eDamageSourceId.mp_titanweapon_flame_wall:
		case eDamageSourceId.mp_titanweapon_heat_shield:
		case eDamageSourceId.mp_titanability_slow_trap:
			shouldExplode = true
			break
	}
	if ( shouldExplode )
	{
		bool isExplosiveBarrel = damageArea.GetScriptName() == "explosive_barrel"
		if ( isExplosiveBarrel )
			CreateExplosiveBarrelExplosion( damageArea )
		IgniteTrap( damageArea, damageInfo, isExplosiveBarrel )
		DamageInfo_SetDamage( damageInfo, 1001 )
	}
	else
	{
		DamageInfo_SetDamage( damageInfo, 0 )
	}
}

function CreateExplosiveBarrelExplosion( entity damageArea )
{
	entity owner = damageArea.GetOwner()
	if ( !IsValid( owner ) )
		return

	Explosion_DamageDefSimple( damagedef_fd_explosive_barrel, damageArea.GetOrigin(),owner, owner, damageArea.GetOrigin() )
}

function IgniteTrap( entity damageArea, var damageInfo, bool isExplosiveBarrel = false )
{
	entity owner = damageArea.GetOwner()
	Assert( IsValid( owner ) )
	if ( !IsValid( owner ) )
		return

	entity weapon = owner.GetOffhandWeapon( OFFHAND_ANTIRODEO )
	if ( !IsValid( weapon ) || weapon.GetWeaponClassName() != "mp_titanability_slow_trap"  )
		return

	vector originNoHeightAdjust = damageArea.GetOrigin()
	vector origin = originNoHeightAdjust + <0,0,GAS_FX_HEIGHT>
	float range = SLOW_TRAP_RADIUS

	//DebugDrawTrigger( origin, range, 255, 0, 0 )
	if ( isExplosiveBarrel )
	{
		entity initialExplosion = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( BARREL_EXP_FX ), origin, <0,0,0> )
		EntFireByHandle( initialExplosion, "Kill", "", 3.0, null, null )
		EmitSoundAtPosition( TEAM_UNASSIGNED, origin, "incendiary_trap_explode_large" )
	}
	else
	{
		entity initialExplosion = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( FIRE_CENTER_FX ), origin, <0,0,0> )
		EntFireByHandle( initialExplosion, "Kill", "", 3.0, null, null )
		EmitSoundAtPosition( TEAM_UNASSIGNED, origin, "incendiary_trap_explode" )

	}

	float duration = LTSRebalance_Enabled() ? FIRE_TRAP_LIFETIME * GetThermiteDurationBonus( owner ) : FLAME_WALL_THERMITE_DURATION
	if ( GAMETYPE == GAMEMODE_SP )
		duration *= SP_FLAME_WALL_DURATION_SCALE

	entity inflictor = CreateOncePerTickDamageInflictorHelper( duration )
	inflictor.SetOrigin( origin )

	// Increase the radius a bit so AI proactively try to get away before they have a chance at taking damage
	float dangerousAreaRadius = SLOW_TRAP_RADIUS + 50

	array<entity> ignoreArray = damageArea.GetLinkEntArray()
	ignoreArray.append( damageArea )
	entity myParent = damageArea.GetParent()
	entity movingGeo = ( myParent && myParent.HasPusherRootParent() ) ? myParent : null
	if ( movingGeo )
	{
		inflictor.SetParent( movingGeo, "", true, 0 )
		AI_CreateDangerousArea( inflictor, weapon, dangerousAreaRadius, owner.GetTeam(), true, true )
	}
	else
	{
		AI_CreateDangerousArea_Static( inflictor, weapon, dangerousAreaRadius, owner.GetTeam(), true, true, originNoHeightAdjust )
	}

	for ( int i = 0; i < 12; i++ )
	{
		vector trailAngles = < 30 * i, 30 * i, 0 >
		vector forward = AnglesToForward( trailAngles )
		vector startPosition = origin + forward * FIRE_TRAP_MINI_EXPLOSION_RADIUS
		vector direction = forward * 150
		if ( i > 5 )
			direction *= -1
		const float FUSE_TIME = 0.0
		entity projectile = weapon.FireWeaponGrenade( origin, <0,0,0>, <0,0,0>, FUSE_TIME, damageTypes.projectileImpact, damageTypes.explosive, PROJECTILE_NOT_PREDICTED, true, true )
		if ( !IsValid( projectile ) )
			continue
		projectile.SetModel( $"models/dev/empty_model.mdl" )
		projectile.SetOrigin( origin )
		projectile.SetVelocity( Vector( 0, 0, 0 ) )
		projectile.StopPhysics()
		projectile.SetTakeDamageType( DAMAGE_NO )
		projectile.Hide()
		projectile.NotSolid()
		projectile.SetProjectilTrailEffectIndex( 1 )
		thread SpawnFireLine( projectile, i, inflictor, origin, direction )
	}
	thread IncendiaryTrapFireSounds( inflictor )

	if ( !movingGeo )
		thread FlameOn( duration, inflictor )
	else
		thread FlameOnMovingGeo( duration, inflictor )
    
    damageArea.Destroy()
}

void function IncendiaryTrapFireSounds( entity inflictor )
{
	inflictor.EndSignal( "OnDestroy" )

	vector position = inflictor.GetOrigin()
	EmitSoundAtPosition( TEAM_UNASSIGNED, position, "incendiary_trap_burn" )
	OnThreadEnd(
	function() : ( position )
		{
			StopSoundAtPosition( position, "incendiary_trap_burn" )
			EmitSoundAtPosition( TEAM_UNASSIGNED, position, "incendiary_trap_burn_stop" )
		}
	)

	WaitForever()
}

void function FlameOn( float duration, entity inflictor )
{
	inflictor.EndSignal( "OnDestroy")

	float intialWaitTime = 0.3
	wait intialWaitTime

	if ( GAMETYPE == GAMEMODE_SP )
		duration *= SP_FLAME_WALL_DURATION_SCALE
	foreach( key, pos in inflictor.e.fireTrapEndPositions )
	{
		entity fireLine = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( FIRE_LINES_FX ), pos, inflictor.GetAngles() )
		EntFireByHandle( fireLine, "Kill", "", duration, null, null )
		EffectSetControlPointVector( fireLine, 1, inflictor.GetOrigin() )
	}
}

void function FlameOnMovingGeo( float duration, entity inflictor )
{
	inflictor.EndSignal( "OnDestroy")

	float intialWaitTime = 0.3
	wait intialWaitTime

	if ( GAMETYPE == GAMEMODE_SP )
		duration *= SP_FLAME_WALL_DURATION_SCALE
	vector angles = inflictor.GetAngles()
	int fxID = GetParticleSystemIndex( FIRE_LINES_FX )
	if ( GetMapName() == "sp_s2s" )
	{
		angles = <0,-90,0> // wind dir
		fxID = GetParticleSystemIndex( FIRE_LINES_S2S_FX )
	}

	foreach( key, relativeDelta in inflictor.e.fireTrapEndPositions )
	{
		if ( ( key in inflictor.e.fireTrapMovingGeo ) )
		{
			entity movingGeo = inflictor.e.fireTrapMovingGeo[ key ]
			if ( !IsValid( movingGeo ) )
				continue
			vector pos = GetWorldOriginFromRelativeDelta( relativeDelta, movingGeo )

			entity script_mover = CreateScriptMover( pos, angles )
			script_mover.SetParent( movingGeo, "", true, 0 )

			int attachIdx 		= script_mover.LookupAttachment( "REF" )
			entity fireLine 	= StartParticleEffectOnEntity_ReturnEntity( script_mover, fxID, FX_PATTACH_POINT_FOLLOW, attachIdx )

			EntFireByHandle( script_mover, "Kill", "", duration, null, null )
			EntFireByHandle( fireLine, "Kill", "", duration, null, null )
			thread EffectUpdateControlPointVectorOnMovingGeo( fireLine, 1, inflictor )
		}
		else
		{
			entity fireLine = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( FIRE_LINES_FX ), relativeDelta, inflictor.GetAngles() )
			EntFireByHandle( fireLine, "Kill", "", duration, null, null )
			EffectSetControlPointVector( fireLine, 1, inflictor.GetOrigin() )
		}
	}
}

void function EffectUpdateControlPointVectorOnMovingGeo( entity fireLine, int cpIndex, entity inflictor )
{
	fireLine.EndSignal( "OnDestroy" )
	inflictor.EndSignal( "OnDestroy" )

	while ( 1 )
	{
		EffectSetControlPointVector( fireLine, cpIndex, inflictor.GetOrigin() )
		WaitFrame()
	}
}


void function SpawnFireLine( entity projectile, int projectileCount, entity inflictor, vector origin, vector direction )
{
	if ( !IsValid( projectile ) ) //unclear why this is necessary. We check for validity before creating the thread.
		return

	projectile.EndSignal( "OnDestroy" )
	entity owner = projectile.GetOwner()
	owner.EndSignal( "OnDestroy" )

	OnThreadEnd(
	function() : ( projectile )
		{
			if ( IsValid( projectile ) )
				projectile.Destroy()
		}
	)
	projectile.SetAbsOrigin( origin )
	projectile.SetAbsAngles( direction )
	projectile.proj.savedOrigin = < -999999.0, -999999.0, -999999.0 >

	wait RandomFloatRange( 0.0, 0.1 )

	waitthread WeaponAttackWave( projectile, projectileCount, inflictor, origin, direction, CreateSlowTrapSegment )
}

void function CreateToxicFumesFXSpot( vector origin, entity tower )
{
	int fxID = GetParticleSystemIndex( TOXIC_FUMES_FX )
	int attachID = tower.LookupAttachment( "smoke" )
	entity particleSystem = StartParticleEffectOnEntityWithPos_ReturnEntity( tower, fxID, FX_PATTACH_POINT_FOLLOW, attachID, <0,0,0>, <0,0,0> )

	tower.e.fxArray.append( particleSystem )
}

void function CreateToxicFumesInWindFX( vector origin, entity tower )
{
	int fxID = GetParticleSystemIndex( TOXIC_FUMES_S2S_FX )
	int attachID = tower.LookupAttachment( "smoke" )

	entity particleSystem = StartParticleEffectOnEntityWithPos_ReturnEntity( tower, fxID, FX_PATTACH_POINT_FOLLOW_NOROTATE, attachID, <0,0,0>, <0,90,0> )

	tower.e.fxArray.append( particleSystem )
}

bool function CreateSlowTrapSegment( entity projectile, int projectileCount, entity inflictor, entity movingGeo, vector pos, vector angles, int waveCount )
{
	projectile.SetOrigin( pos )
	entity owner = projectile.GetOwner()

	if ( projectile.proj.savedOrigin != < -999999.0, -999999.0, -999999.0 > )
	{
		float duration = LTSRebalance_Enabled() ? FIRE_TRAP_LIFETIME * GetThermiteDurationBonus( owner ) : FLAME_WALL_THERMITE_DURATION

		if ( GAMETYPE == GAMEMODE_SP )
			duration *= SP_FLAME_WALL_DURATION_SCALE

		if ( !movingGeo )
		{
			if ( projectileCount in inflictor.e.fireTrapEndPositions )
				inflictor.e.fireTrapEndPositions[projectileCount] = pos
			else
				inflictor.e.fireTrapEndPositions[projectileCount] <- pos

			thread FireTrap_DamageAreaOverTime( owner, inflictor, pos, duration )
		}
		else
		{
			vector relativeDelta = GetRelativeDelta( pos, movingGeo )

			if ( projectileCount in inflictor.e.fireTrapEndPositions )
				inflictor.e.fireTrapEndPositions[projectileCount] = relativeDelta
			else
				inflictor.e.fireTrapEndPositions[projectileCount] <- relativeDelta

			if ( projectileCount in inflictor.e.fireTrapMovingGeo )
				inflictor.e.fireTrapMovingGeo[projectileCount] = movingGeo
			else
				inflictor.e.fireTrapMovingGeo[projectileCount] <- movingGeo

			thread FireTrap_DamageAreaOverTimeOnMovingGeo( owner, inflictor, movingGeo, relativeDelta, duration )
		}

	}

	projectile.proj.savedOrigin = pos
	return true
}

void function FireTrap_DamageAreaOverTime( entity owner, entity inflictor, vector pos, float duration )
{
	Assert( IsValid( owner ) )
	owner.EndSignal( "OnDestroy" )
	if ( LTSRebalance_Enabled() )
    	inflictor.EndSignal( "OnDestroy" )

	float endTime = Time() + duration
	while ( Time() < endTime )
	{
		FireTrap_RadiusDamage( pos, owner, inflictor )
		if ( LTSRebalance_Enabled() )
			WaitFrame()
		else
			wait 0.2
	}
}

void function FireTrap_DamageAreaOverTimeOnMovingGeo( entity owner, entity inflictor, entity movingGeo, vector relativeDelta, float duration )
{
	Assert( IsValid( owner ) )
	owner.EndSignal( "OnDestroy" )
	movingGeo.EndSignal( "OnDestroy" )
	inflictor.EndSignal( "OnDestroy" )

	float endTime = Time() + duration
	while ( Time() < endTime )
	{
		vector pos = GetWorldOriginFromRelativeDelta( relativeDelta, movingGeo )
		FireTrap_RadiusDamage( pos, owner, inflictor )
		if ( LTSRebalance_Enabled() )
			WaitFrame()
		else
			wait 0.2
	}
}

void function FireTrap_RadiusDamage( vector pos, entity owner, entity inflictor )
{
	var pilotDamage = LTSRebalance_Enabled() ? LTSREBALANCE_SLOWTRAP_DAMAGE_TICK_PILOT : PLAYER_METEOR_DAMAGE_TICK_PILOT
	var titanDamage = LTSRebalance_Enabled() ? LTSREBALANCE_SLOWTRAP_DAMAGE_TICK : PLAYER_METEOR_DAMAGE_TICK
	RadiusDamage(
		pos,												// origin
		owner,												// owner
		inflictor,		 									// inflictor
		pilotDamage,							// pilot damage
		titanDamage,									// heavy armor damage
		FIRE_TRAP_MINI_EXPLOSION_RADIUS,					// inner radius
		FIRE_TRAP_MINI_EXPLOSION_RADIUS,					// outer radius
		SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,					// explosion flags
		0, 													// distanceFromAttacker
		0, 													// explosionForce
		DF_EXPLOSION,										// damage flags
		eDamageSourceId.mp_titanability_slow_trap			// damage source id
	)
}

void function FireTrap_DamagedPlayerOrNPC( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if ( !IsValid( inflictor ) )
		return

	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_DOOMED_HEALTH_LOSS )
		return

	Thermite_DamagePlayerOrNPCSounds( ent )

	float originDistance2D = Distance2D( inflictor.GetOrigin(), DamageInfo_GetDamagePosition( damageInfo ) )
	if ( originDistance2D > SLOW_TRAP_RADIUS )
		DamageInfo_SetDamage( damageInfo, 0 )
	else
		Scorch_SelfDamageReduction( ent, damageInfo )

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || attacker.GetTeam() == ent.GetTeam() )
		return

	array<entity> weapons = attacker.GetMainWeapons()
	if ( weapons.len() > 0 )
	{
		if ( weapons[0].HasMod( "fd_fire_damage_upgrade" )  )
			DamageInfo_ScaleDamage( damageInfo, FD_FIRE_DAMAGE_SCALE )
		if ( weapons[0].HasMod( "fd_hot_streak" ) )
			UpdateScorchHotStreakCoreMeter( attacker, DamageInfo_GetDamage( damageInfo ) )
	}

	PasScorchFirewall_ReduceCooldowns( attacker, DamageInfo_GetDamage( damageInfo ) )
	LTSRebalance_TriggerThermiteBurn( ent, attacker, inflictor )
}
#endif

//	TODO:
//	Reassign damage to person who triggers the trap for FF reasons.
