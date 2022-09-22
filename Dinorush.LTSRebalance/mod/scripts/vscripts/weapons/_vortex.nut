/* LTS Rebalance replaces this file for the following reasons:
   1. Fix one part of what despawns wave attacks inside Vortex
   2. Implement Amped Vortex's ability to amp projectiles
   3. Implement validate function for held Vortexes that checks direction of the shot
      • This is so that you can't block someone from behind them
   4. Implement Perfect Kits Amped Vortex absorbing every attack type
   5. Fix Vortex refiring without attachments (for weapons with damage changing attachments)
   6. Implement data logging (for blocked damage)
*/
untyped

global function Vortex_Init

global function CreateVortexSphere
global function DestroyVortexSphereFromVortexWeapon
global function EnableVortexSphere
global function RegisterNewVortexIgnoreClassname
global function RegisterNewVortexIgnoreClassnames
#if SERVER
global function ValidateVortexImpact
global function ValidateVortexDirection
global function TryVortexAbsorb
global function SetVortexSphereBulletHitRules
global function SetVortexSphereProjectileHitRules
#endif
global function VortexDrainedByImpact
global function VortexPrimaryAttack
global function GetVortexSphereCurrentColor
global function GetShieldTriLerpColor
global function IsVortexing
#if SERVER
global function Vortex_HandleElectricDamage
global function VortexSphereDrainHealthForDamage
global function Vortex_CreateImpactEventData
global function Vortex_SpawnHeatShieldPingFX
global function LTSRebalance_GetProjectileDamage // Needed for logging damage blocked on Vortex/Thermal
global function LTSRebalance_GetWeaponDamage
#endif

global function Vortex_SetTagName
global function Vortex_SetBulletCollectionOffset

global function CodeCallback_OnVortexHitBullet
global function CodeCallback_OnVortexHitProjectile

const AMPED_WALL_IMPACT_FX = $"P_impact_xo_shield_cp"

global const PROTO_AMPED_WALL = "proto_amped_wall"
global const GUN_SHIELD_WALL = "gun_shield_wall"
const PROX_MINE_MODEL = $"models/weapons/caber_shot/caber_shot_thrown.mdl"

const VORTEX_SPHERE_COLOR_CHARGE_FULL		= <115, 247, 255>	// blue
const VORTEX_SPHERE_COLOR_CHARGE_MED		= <200, 128, 80>	// orange
const VORTEX_SPHERE_COLOR_CHARGE_EMPTY		= <200, 80, 80>	// red
const VORTEX_SPHERE_COLOR_PAS_ION_VORTEX	= <115, 174, 255>	// blue
const AMPED_DAMAGE_SCALAR = 1.5

const VORTEX_SPHERE_COLOR_CROSSOVERFRAC_FULL2MED	= 0.75  // from zero to this fraction, fade between full and medium charge colors
const VORTEX_SPHERE_COLOR_CROSSOVERFRAC_MED2EMPTY	= 0.95  // from "full2med" to this fraction, fade between medium and empty charge colors

const VORTEX_BULLET_ABSORB_COUNT_MAX = 32
const VORTEX_PROJECTILE_ABSORB_COUNT_MAX = 32

const VORTEX_TIMED_EXPLOSIVE_FUSETIME				= 2.75	// fuse time for absorbed projectiles
const VORTEX_TIMED_EXPLOSIVE_FUSETIME_WARNINGFRAC	= 0.75	// wait this fraction of the fuse time before warning the player it's about to explode

const VORTEX_EXP_ROUNDS_RETURN_SPREAD_XY = 0.15
const VORTEX_EXP_ROUNDS_RETURN_SPREAD_Z = 0.075

const VORTEX_ELECTRIC_DAMAGE_CHARGE_DRAIN_MIN = 0.1  // fraction of charge time
const VORTEX_ELECTRIC_DAMAGE_CHARGE_DRAIN_MAX = 0.3

//The shotgun spams a lot of pellets that deal too much damage if they return full damage.
const VORTEX_SHOTGUN_DAMAGE_RATIO = 0.25


const SHIELD_WALL_BULLET_FX = $"P_impact_xo_shield_cp"
const SHIELD_WALL_EXPMED_FX = $"P_impact_exp_med_xo_shield_CP"

const SIGNAL_ID_BULLET_HIT_THINK = "signal_id_bullet_hit_think"

const VORTEX_EXPLOSIVE_WARNING_SFX_LOOP = "Weapon_Vortex_Gun.ExplosiveWarningBeep"

const VORTEX_PILOT_WEAPON_WEAKNESS_DAMAGESCALE = 6.0

// These match the strings in the WeaponEd dropdown box for vortex_refire_behavior
global const VORTEX_REFIRE_NONE					= ""
global const VORTEX_REFIRE_ABSORB				= "absorb"
global const VORTEX_REFIRE_BULLET				= "bullet"
global const VORTEX_REFIRE_EXPLOSIVE_ROUND		= "explosive_round"
global const VORTEX_REFIRE_ROCKET				= "rocket"
global const VORTEX_REFIRE_GRENADE				= "grenade"
global const VORTEX_REFIRE_GRENADE_LONG_FUSE	= "grenade_long_fuse"

#if SERVER
const array<int> LTSREBALANCE_FIX_VORTEX_REFIRE_IDS = [
	eDamageSourceId.mp_titanweapon_leadwall,
	eDamageSourceId.mp_titanweapon_salvo_rockets,
	eDamageSourceId.mp_titanweapon_shoulder_rockets,
	eDamageSourceId.mp_titanweapon_tracker_rockets,
	eDamageSourceId.mp_titanweapon_sniper,
	eDamageSourceId.mp_titanweapon_sticky_40mm,
	eDamageSourceId.mp_titanweapon_flightcore_rockets,
	eDamageSourceId.mp_titanweapon_dumbfire_rockets,
	eDamageSourceId.mp_titanweapon_meteor
]
#endif

table<string, bool> VortexIgnoreClassnames = {
	["mp_titancore_flame_wave"] = true,
	["mp_ability_grapple"] = true,
	["mp_ability_shifter"] = true,
}
void function RegisterNewVortexIgnoreClassnames(table<string, bool> classTable)
{
	foreach(string classname, bool shouldignore in classTable)
	{
		RegisterNewVortexIgnoreClassname(classname, shouldignore)
	}
}
void function RegisterNewVortexIgnoreClassname(string classname, bool shouldignore)
{
	VortexIgnoreClassnames[classname] <- shouldignore
}
table vortexImpactWeaponInfo
table< int, int > ampDamageSourceIdCounts

const DEG_COS_60 = cos( 60 * DEG_TO_RAD )

function Vortex_Init()
{
	PrecacheParticleSystem( SHIELD_WALL_BULLET_FX )
	GetParticleSystemIndex( SHIELD_WALL_BULLET_FX )
	PrecacheParticleSystem( SHIELD_WALL_EXPMED_FX )
	GetParticleSystemIndex( SHIELD_WALL_EXPMED_FX )
	PrecacheParticleSystem( AMPED_WALL_IMPACT_FX )
	GetParticleSystemIndex( AMPED_WALL_IMPACT_FX )

	RegisterSignal( SIGNAL_ID_BULLET_HIT_THINK )
	RegisterSignal( "VortexStopping" )

	RegisterSignal( "VortexAbsorbed" )
	RegisterSignal( "VortexFired" )
	RegisterSignal( "Script_OnDamaged" )

	#if SERVER
	// Vortex does not inherit attachments from projectiles. LTS Rebalance uses attachments.
	// These damage source callbacks fix damage differences and damage dropoff differences for reflected attacks.
	// Particle Wall damage and projectile collision are handled in their corresponding functions.
	if ( LTSRebalance_EnabledOnInit() )
	{
		foreach ( id in LTSREBALANCE_FIX_VORTEX_REFIRE_IDS )
			AddDamageCallbackSourceID( id, LTSRebalance_FixVortexRefire )
	}
	#endif
}

#if SERVER
var function VortexBulletHitRules_Default( entity vortexSphere, var damageInfo )
{
	return damageInfo
}

bool function VortexProjectileHitRules_Default( entity vortexSphere, entity attacker, bool takesDamageByDefault )
{
	return takesDamageByDefault
}

void function SetVortexSphereBulletHitRules( entity vortexSphere, var functionref( entity, var ) customRules  )
{
	vortexSphere.e.BulletHitRules = customRules
}

void function SetVortexSphereProjectileHitRules( entity vortexSphere, bool functionref( entity, entity, bool ) customRules  )
{
	vortexSphere.e.ProjectileHitRules = customRules
}
#endif
function CreateVortexSphere( entity vortexWeapon, bool useCylinderCheck, bool blockOwnerWeapon, int sphereRadius = 40, int bulletFOV = 180 )
{
	entity owner = vortexWeapon.GetWeaponOwner()
	Assert( owner )

	#if SERVER
		//printt( "util ent:", vortexWeapon.GetWeaponUtilityEntity() )
		Assert ( !vortexWeapon.GetWeaponUtilityEntity(), "Tried to create more than one vortex sphere on a vortex weapon!" )

		entity vortexSphere = CreateEntity( "vortex_sphere" )
		Assert( vortexSphere )

		int spawnFlags = SF_ABSORB_BULLETS | SF_BLOCK_NPC_WEAPON_LOF

		if ( useCylinderCheck )
		{
			spawnFlags = spawnFlags | SF_ABSORB_CYLINDER
			vortexSphere.kv.height = sphereRadius * 2
		}

		if ( blockOwnerWeapon )
			spawnFlags = spawnFlags | SF_BLOCK_OWNER_WEAPON

		vortexSphere.kv.spawnflags = spawnFlags

		vortexSphere.kv.enabled = 0
		vortexSphere.kv.radius = sphereRadius
		vortexSphere.kv.bullet_fov = bulletFOV
		vortexSphere.kv.physics_pull_strength = 25
		vortexSphere.kv.physics_side_dampening = 6
		vortexSphere.kv.physics_fov = 360
		vortexSphere.kv.physics_max_mass = 2
		vortexSphere.kv.physics_max_size = 6
		Assert( owner.IsNPC() || owner.IsPlayer(), "Vortex script expects the weapon owner to be a player or NPC." )

		SetVortexSphereBulletHitRules( vortexSphere, VortexBulletHitRules_Default )
		SetVortexSphereProjectileHitRules( vortexSphere, VortexProjectileHitRules_Default )

		DispatchSpawn( vortexSphere )

		vortexSphere.SetOwner( owner )

		if ( owner.IsNPC() )
		{
			vortexSphere.SetParent( owner, "PROPGUN" )
			vortexSphere.SetLocalOrigin( Vector( 0, 35, 0 ) )
		}
		else
		{
			vortexSphere.SetParent( owner )
			vortexSphere.SetLocalOrigin( Vector( 0, 10, -30 ) )
		}
		vortexSphere.SetAbsAngles( Vector( 0, 0, 0 ) ) //Setting local angles on a parented object is not supported

		vortexSphere.SetOwnerWeapon( vortexWeapon )
		vortexWeapon.SetWeaponUtilityEntity( vortexSphere )
	#endif

	SetVortexAmmo( vortexWeapon, 0 )
}


function EnableVortexSphere( entity vortexWeapon )
{
	string tagname = GetVortexTagName( vortexWeapon )
	entity weaponOwner = vortexWeapon.GetWeaponOwner()
	local hasBurnMod = vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod )

	#if SERVER
		entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
		Assert( vortexSphere )
		vortexSphere.FireNow( "Enable" )

		thread SetPlayerUsingVortex( weaponOwner, vortexWeapon )

		Vortex_CreateAbsorbFX_ControlPoints( vortexWeapon )

		// world (3P) version of the vortex sphere FX
		vortexSphere.s.worldFX <- CreateEntity( "info_particle_system" )

		if ( hasBurnMod )
		{
			if ( "fxChargingControlPointBurn" in vortexWeapon.s )
				vortexSphere.s.worldFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxChargingControlPointBurn ) )
		}
		else
		{
			if ( "fxChargingControlPoint" in vortexWeapon.s )
				vortexSphere.s.worldFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxChargingControlPoint ) )
		}

		vortexSphere.s.worldFX.kv.start_active = 1
		vortexSphere.s.worldFX.SetOwner( weaponOwner )
		vortexSphere.s.worldFX.SetParent( vortexWeapon, tagname )
		vortexSphere.s.worldFX.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY) // not owner only
		vortexSphere.s.worldFX.kv.cpoint1 = vortexWeapon.s.vortexSphereColorCP.GetTargetName()
		vortexSphere.s.worldFX.SetStopType( "destroyImmediately" )

		DispatchSpawn( vortexSphere.s.worldFX )
	#endif

	SetVortexAmmo( vortexWeapon, 0 )

	#if CLIENT
		if ( IsLocalViewPlayer( weaponOwner ) )
	{
		local fxAlias = null

		if ( hasBurnMod )
		{
			if ( "fxChargingFPControlPointBurn" in vortexWeapon.s )
				fxAlias = vortexWeapon.s.fxChargingFPControlPointBurn
		}
		else
		{
			if ( "fxChargingFPControlPoint" in vortexWeapon.s )
				fxAlias = vortexWeapon.s.fxChargingFPControlPoint
		}

		if ( fxAlias )
		{
			int sphereClientFXHandle = vortexWeapon.PlayWeaponEffectReturnViewEffectHandle( fxAlias, $"", tagname )
			thread VortexSphereColorUpdate( vortexWeapon, sphereClientFXHandle )
		}
	}
	#elseif  SERVER
		asset fxAlias = $""

		if ( hasBurnMod )
		{
			if ( "fxChargingFPControlPointReplayBurn" in vortexWeapon.s )
				fxAlias = expect asset( vortexWeapon.s.fxChargingFPControlPointReplayBurn )
		}
		else
		{
			if ( "fxChargingFPControlPointReplay" in vortexWeapon.s )
				fxAlias = expect asset( vortexWeapon.s.fxChargingFPControlPointReplay )
		}

		if ( fxAlias != $"" )
			vortexWeapon.PlayWeaponEffect( fxAlias, $"", tagname )

		thread VortexSphereColorUpdate( vortexWeapon )
	#endif
}


function DestroyVortexSphereFromVortexWeapon( entity vortexWeapon )
{
	DisableVortexSphereFromVortexWeapon( vortexWeapon )

	#if SERVER
		DestroyVortexSphere( vortexWeapon.GetWeaponUtilityEntity() )
		vortexWeapon.SetWeaponUtilityEntity( null )
	#endif
}

void function DestroyVortexSphere( entity vortexSphere )
{
	if ( IsValid( vortexSphere ) )
	{
		vortexSphere.s.worldFX.Destroy()
		vortexSphere.Destroy()
	}
}


function DisableVortexSphereFromVortexWeapon( entity vortexWeapon )
{
	vortexWeapon.Signal( "VortexStopping" )

	// server cleanup
	#if SERVER
		DisableVortexSphere( vortexWeapon.GetWeaponUtilityEntity() )
		Vortex_CleanupAllEffects( vortexWeapon )
		Vortex_ClearImpactEventData( vortexWeapon )
	#endif

	// client & server cleanup

	if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	{
		if ( "fxChargingFPControlPointBurn" in vortexWeapon.s )
			vortexWeapon.StopWeaponEffect( expect asset( vortexWeapon.s.fxChargingFPControlPointBurn ), $"" )
		if ( "fxChargingFPControlPointReplayBurn" in vortexWeapon.s )
			vortexWeapon.StopWeaponEffect( expect asset( vortexWeapon.s.fxChargingFPControlPointReplayBurn ), $"" )
	}
	else
	{
		if ( "fxChargingFPControlPoint" in vortexWeapon.s )
			vortexWeapon.StopWeaponEffect( expect asset( vortexWeapon.s.fxChargingFPControlPoint ), $"" )
		if ( "fxChargingFPControlPointReplay" in vortexWeapon.s )
			vortexWeapon.StopWeaponEffect( expect asset( vortexWeapon.s.fxChargingFPControlPointReplay ), $"" )
	}
}

void function DisableVortexSphere( entity vortexSphere )
{
	if ( IsValid( vortexSphere ) )
	{
		vortexSphere.FireNow( "Disable" )
		vortexSphere.Signal( SIGNAL_ID_BULLET_HIT_THINK )
	}

}


#if SERVER
function Vortex_CreateAbsorbFX_ControlPoints( entity vortexWeapon )
{
	entity player = vortexWeapon.GetWeaponOwner()
	Assert( player )

	// vortex swirling incoming rounds FX location control point
	if ( !( "vortexBulletEffectCP" in vortexWeapon.s ) )
		vortexWeapon.s.vortexBulletEffectCP <- null
	vortexWeapon.s.vortexBulletEffectCP = CreateEntity( "info_placement_helper" )
	SetTargetName( expect entity( vortexWeapon.s.vortexBulletEffectCP ), UniqueString( "vortexBulletEffectCP" ) )
	vortexWeapon.s.vortexBulletEffectCP.kv.start_active = 1

	DispatchSpawn( vortexWeapon.s.vortexBulletEffectCP )

	vector offset = GetBulletCollectionOffset( vortexWeapon )
	vector origin = player.OffsetPositionFromView( player.EyePosition(), offset )

	vortexWeapon.s.vortexBulletEffectCP.SetOrigin( origin )
	vortexWeapon.s.vortexBulletEffectCP.SetParent( player )

	// vortex sphere color control point
	if ( !( "vortexSphereColorCP" in vortexWeapon.s ) )
		vortexWeapon.s.vortexSphereColorCP <- null
	vortexWeapon.s.vortexSphereColorCP = CreateEntity( "info_placement_helper" )
	SetTargetName( expect entity( vortexWeapon.s.vortexSphereColorCP ), UniqueString( "vortexSphereColorCP" ) )
	vortexWeapon.s.vortexSphereColorCP.kv.start_active = 1

	DispatchSpawn( vortexWeapon.s.vortexSphereColorCP )
}


function Vortex_CleanupAllEffects( entity vortexWeapon )
{
	Assert( IsServer() )

	Vortex_CleanupImpactAbsorbFX( vortexWeapon )

	if ( ( "vortexBulletEffectCP" in vortexWeapon.s ) && IsValid_ThisFrame( expect entity( vortexWeapon.s.vortexBulletEffectCP ) ) )
		vortexWeapon.s.vortexBulletEffectCP.Destroy()

	if ( ( "vortexSphereColorCP" in vortexWeapon.s ) && IsValid_ThisFrame( expect entity( vortexWeapon.s.vortexSphereColorCP ) ) )
		vortexWeapon.s.vortexSphereColorCP.Destroy()
}
#endif // SERVER


function SetPlayerUsingVortex( entity weaponOwner, entity vortexWeapon )
{
	weaponOwner.EndSignal( "OnDeath" )

	weaponOwner.s.isVortexing <- true

	vortexWeapon.WaitSignal( "VortexStopping" )

	OnThreadEnd
	(
		function() : ( weaponOwner )
		{
			if ( IsValid_ThisFrame( weaponOwner ) && "isVortexing" in weaponOwner.s )
			{
				delete weaponOwner.s.isVortexing
			}
		}
	)
}


function IsVortexing( entity ent )
{
	Assert( IsServer() )

	if ( "isVortexing" in ent.s )
		return true
}


#if SERVER
function Vortex_HandleElectricDamage( entity ent, entity attacker, damage, entity weapon )
{
	if ( !IsValid( ent ) )
		return damage

	if ( !ent.IsTitan() )
		return damage

	if ( !ent.IsPlayer() && !ent.IsNPC() )
		return damage

	if ( !IsVortexing( ent ) )
		return damage

	entity vortexWeapon = ent.GetActiveWeapon()
	if ( !IsValid( vortexWeapon ) )
		return damage

	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !IsValid( vortexSphere ) )
		return damage

	if ( !IsValid( vortexWeapon ) || !IsValid( vortexSphere ) )
		return damage

	// vortex FOV check
	//printt( "sphere FOV:", vortexSphere.kv.bullet_fov )
	local sphereFOV = vortexSphere.kv.bullet_fov.tointeger()
	entity attackerWeapon = attacker.GetActiveWeapon()
	int attachIdx = attackerWeapon.LookupAttachment( "muzzle_flash" )
	vector beamOrg = attackerWeapon.GetAttachmentOrigin( attachIdx )
	vector firingDir = beamOrg - vortexSphere.GetOrigin()
	firingDir = Normalize( firingDir )
	vector vortexDir = AnglesToForward( vortexSphere.GetAngles() )

	float dot = DotProduct( vortexDir, firingDir )

	float degCos = DEG_COS_60
	if ( sphereFOV != 120 )
		deg_cos( sphereFOV * 0.5 )

	// not in the vortex cone
	if ( dot < degCos )
		return damage

	if ( "fxElectricalExplosion" in vortexWeapon.s )
	{
			entity fxRef = CreateEntity( "info_particle_system" )
			fxRef.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxElectricalExplosion ) )
			fxRef.kv.start_active = 1
			fxRef.SetStopType( "destroyImmediately" )
			//fxRef.kv.VisibilityFlags = ENTITY_VISIBLE_TO_OWNER  // HACK this turns on owner only visibility. Uncomment when we hook up dedicated 3P effects
			fxRef.SetOwner( ent )
			fxRef.SetOrigin( vortexSphere.GetOrigin() )
			fxRef.SetParent( ent )

			DispatchSpawn( fxRef )
			fxRef.Kill_Deprecated_UseDestroyInstead( 1 )
	}

	return 0
}

// this function handles all incoming vortex impact events
bool function TryVortexAbsorb( entity vortexSphere, entity attacker, vector origin, int damageSourceID, entity weapon, string weaponName, string impactType, entity projectile = null, damageType = null, reflect = false )
{
	if ( weaponName in VortexIgnoreClassnames && VortexIgnoreClassnames[weaponName] )
		return false

	entity vortexWeapon = vortexSphere.GetOwnerWeapon()
	entity owner = vortexWeapon.GetWeaponOwner()

	// HACK - make XO-16 be caught as hitscan. Need to save projectile since weapon is null and VortexDrainedByImpact needs one of the two.
	entity xo16_proj = projectile
	if ( LTSRebalance_Enabled() && weaponName == "mp_titanweapon_xo16_vanguard" && attacker.GetTeam() != owner.GetTeam() )
	{
		projectile = null
		impactType = "hitscan"
	}

	// keep cycling the oldest hitscan bullets out
	if( !reflect )
	{
		if ( impactType == "hitscan" )
			Vortex_ClampAbsorbedBulletCount( vortexWeapon )
		else
			Vortex_ClampAbsorbedProjectileCount( vortexWeapon )
	}

	// vortex spheres tag refired projectiles with info about the original projectile for accurate duplication when re-absorbed
	if ( projectile )
	{

		// specifically for tether, since it gets moved to the vortex area and can get absorbed in the process, then destroyed
		if ( !IsValid( projectile ) )
			return false

		entity projOwner = projectile.GetOwner()
		if ( IsValid( projOwner ) && projOwner.GetTeam() == owner.GetTeam() )
			return false

		if ( projectile.proj.hasBouncedOffVortex )
			return false

		if ( projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_ignores_vortex" ) == "fall_vortex" )
		{
			vector velocity = projectile.GetVelocity()
			vector multiplier = < -0.25, -0.25, -0.25 >
			velocity = < velocity.x * multiplier.x, velocity.y * multiplier.y, velocity.z * multiplier.z >
			projectile.SetVelocity( velocity )
			projectile.proj.hasBouncedOffVortex = true
			return false
		}
		// Fix for wave attacks getting despawned by vortex when allowed to pass through them
		else if ( LTSRebalance_Enabled() && projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_ignores_vortex" ) == "mirror" )
		{
			projectile.proj.hasBouncedOffVortex = true
			return false
		}

		// if ( projectile.GetParent() == owner )
		// 	return false

		if ( "originalDamageSource" in projectile.s )
		{
			damageSourceID = expect int( projectile.s.originalDamageSource )

			// Vortex Volley Achievement
			if ( IsValid( owner ) && owner.IsPlayer() )
			{
				//if ( PlayerProgressionAllowed( owner ) )
				//	SetAchievement( owner, "ach_vortexVolley", true )
			}
		}

		// Max projectile stat tracking
		int projectilesInVortex = 1
		projectilesInVortex += vortexWeapon.w.vortexImpactData.len()

		if ( IsValid( owner ) && owner.IsPlayer() )
		{
		 	if ( PlayerProgressionAllowed( owner ) )
		 	{
				int record = owner.GetPersistentVarAsInt( "mostProjectilesCollectedInVortex" )
				if ( projectilesInVortex > record )
					owner.SetPersistentVar( "mostProjectilesCollectedInVortex", projectilesInVortex )
		 	}

			var impact_sound_1p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_1p" )
			if ( impact_sound_1p != null )
				EmitSoundOnEntityOnlyToPlayer( vortexSphere, owner, impact_sound_1p )
		}

		var impact_sound_3p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_3p" )
		if ( impact_sound_3p != null )
			EmitSoundAtPosition( TEAM_UNASSIGNED, origin, impact_sound_3p )
	}
	else
	{
		if ( IsValid( owner ) && owner.IsPlayer() )
		{
			var impact_sound_1p = GetWeaponInfoFileKeyField_Global( weaponName, "vortex_impact_sound_1p" )
			if ( impact_sound_1p != null )
				EmitSoundOnEntityOnlyToPlayer( vortexSphere, owner, impact_sound_1p )
		}

		var impact_sound_3p = GetWeaponInfoFileKeyField_Global( weaponName, "vortex_impact_sound_3p" )
		if ( impact_sound_3p != null )
			EmitSoundAtPosition( TEAM_UNASSIGNED, origin, impact_sound_3p )
	}

	local impactData = Vortex_CreateImpactEventData( vortexWeapon, attacker, origin, damageSourceID, weaponName, impactType )

	VortexDrainedByImpact( vortexWeapon, weapon, projectile == null ? xo16_proj : projectile, damageType )
	Vortex_NotifyAttackerDidDamage( expect entity( impactData.attacker ), owner, impactData.origin )

	if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
		return true

	if ( vortexWeapon.GetWeaponClassName() == "mp_titanweapon_heat_shield" )
		return true

	if ( PerfectKits_Enabled() && ( vortexWeapon.HasMod( "LTSRebalance_pas_ion_vortex" ) || vortexWeapon.HasMod( "pas_ion_vortex" ) ) )
		return true

	if ( !Vortex_ScriptCanHandleImpactEvent( impactData ) )
		return false

	Vortex_StoreImpactEvent( vortexWeapon, impactData )

	VortexImpact_PlayAbsorbedFX( vortexWeapon, impactData )

	if ( impactType == "hitscan" )
		vortexSphere.AddBulletToSphere();
	else
	{
		if ( LTSRebalance_Enabled() )
			impactData.storedReflectMods <- projectile.ProjectileGetMods()
		vortexSphere.AddProjectileToSphere();
	}

	local maxShotgunPelletsToIgnore = VORTEX_BULLET_ABSORB_COUNT_MAX * ( 1 - VORTEX_SHOTGUN_DAMAGE_RATIO )
	if ( IsPilotShotgunWeapon( weaponName ) && ( vortexWeapon.s.shotgunPelletsToIgnore + 1 ) <  maxShotgunPelletsToIgnore )
			vortexWeapon.s.shotgunPelletsToIgnore += ( 1 - VORTEX_SHOTGUN_DAMAGE_RATIO )

	if ( reflect )
	{
		local attackParams = {}
		attackParams.pos <- owner.EyePosition()
		attackParams.dir <- owner.GetPlayerOrNPCViewVector()

		int bulletsFired = VortexReflectAttack( vortexWeapon, attackParams, expect vector( impactData.origin ) )

		Vortex_CleanupImpactAbsorbFX( vortexWeapon )
		Vortex_ClearImpactEventData( vortexWeapon )

		while ( vortexSphere.GetBulletAbsorbedCount() > 0 )
			vortexSphere.RemoveBulletFromSphere();

		while ( vortexSphere.GetProjectileAbsorbedCount() > 0 )
			vortexSphere.RemoveProjectileFromSphere();
	}

	return true
}
#endif // SERVER

function VortexDrainedByImpact( entity vortexWeapon, entity weapon, entity projectile, damageType )
{
	if ( vortexWeapon.HasMod( "unlimited_charge_time" ) )
		return
	if ( vortexWeapon.HasMod( "vortex_extended_effect_and_no_use_penalty" ) )
		return

	float amount
	if ( projectile )
		amount = projectile.GetProjectileWeaponSettingFloat( eWeaponVar.vortex_drain )
	else
		amount = weapon.GetWeaponSettingFloat( eWeaponVar.vortex_drain )

	if ( amount <= 0.0 )
		return

	if ( vortexWeapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion" )
	{
		entity owner = vortexWeapon.GetWeaponOwner()
		int totalEnergy = owner.GetSharedEnergyTotal()
		owner.TakeSharedEnergy( int( float( totalEnergy ) * amount ) )
	}
	else
	{
		float frac = min ( vortexWeapon.GetWeaponChargeFraction() + amount, 1.0 )
		vortexWeapon.SetWeaponChargeFraction( frac )
	}
}


function VortexSlowOwnerFromAttacker( entity player, entity attacker, vector velocity, float multiplier )
{
	vector damageForward = player.GetOrigin() - attacker.GetOrigin()
	damageForward.z = 0
	damageForward.Norm()

	vector velForward = player.GetVelocity()
	velForward.z = 0
	velForward.Norm()

	float dot = DotProduct( velForward, damageForward )
	if ( dot >= -0.5 )
		return

	dot += 0.5
	dot *= -2.0

	vector negateVelocity = velocity * -multiplier
	negateVelocity *= dot

	velocity += negateVelocity
	player.SetVelocity( velocity )
}


#if SERVER
function Vortex_ClampAbsorbedBulletCount( entity vortexWeapon )
{
	if ( GetBulletsAbsorbedCount( vortexWeapon ) >= ( VORTEX_BULLET_ABSORB_COUNT_MAX - 1 ) )
		Vortex_RemoveOldestAbsorbedBullet( vortexWeapon )
}

function Vortex_ClampAbsorbedProjectileCount( entity vortexWeapon )
{
	if ( GetProjectilesAbsorbedCount( vortexWeapon ) >= ( VORTEX_PROJECTILE_ABSORB_COUNT_MAX - 1 ) )
		Vortex_RemoveOldestAbsorbedProjectile( vortexWeapon )
}

function Vortex_RemoveOldestAbsorbedBullet( entity vortexWeapon )
{
	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()

	local bulletImpacts = Vortex_GetHitscanBulletImpacts( vortexWeapon )
	local impactDataToRemove = bulletImpacts[ 0 ]  // since it's an array, the first one will be the oldest

	Vortex_RemoveImpactEvent( vortexWeapon, impactDataToRemove )

	vortexSphere.RemoveBulletFromSphere()
}

function Vortex_RemoveOldestAbsorbedProjectile( entity vortexWeapon )
{
	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()

	local projImpacts = Vortex_GetProjectileImpacts( vortexWeapon )
	local impactDataToRemove = projImpacts[ 0 ]  // since it's an array, the first one will be the oldest

	Vortex_RemoveImpactEvent( vortexWeapon, impactDataToRemove )

	vortexSphere.RemoveProjectileFromSphere()
}

function Vortex_CreateImpactEventData( entity vortexWeapon, entity attacker, vector origin, int damageSourceID, string weaponName, string impactType )
{
	entity player = vortexWeapon.GetWeaponOwner()
	local impactData = {}

	impactData.attacker				<- attacker
	impactData.origin				<- origin
	impactData.damageSourceID		<- damageSourceID
	impactData.weaponName			<- weaponName
	impactData.impactType			<- impactType

	impactData.refireBehavior		<- VORTEX_REFIRE_NONE
	impactData.absorbSFX			<- "Vortex_Shield_AbsorbBulletSmall"
	impactData.absorbSFX_1p_vs_3p	<- null

	impactData.team 				<- null
	// sets a team even if the attacker disconnected
	if ( IsValid_ThisFrame( attacker ) )
	{
		impactData.team = attacker.GetTeam()
	}
	else
	{
		// default to opposite team
		if ( player.GetTeam() == TEAM_IMC )
			impactData.team = TEAM_MILITIA
		else
			impactData.team = TEAM_IMC
	}

	impactData.absorbFX				<- null
	impactData.absorbFX_3p			<- null
	impactData.fxEnt_absorb			<- null

	impactData.explosionradius		<- null
	impactData.explosion_damage		<- null
	impactData.impact_effect_table	<- -1
	// -- everything from here down relies on being able to read a megaweapon file
	if ( !( impactData.weaponName in vortexImpactWeaponInfo ) )
	{
		vortexImpactWeaponInfo[ impactData.weaponName ] <- {}
		vortexImpactWeaponInfo[ impactData.weaponName ].absorbFX 						<- GetWeaponInfoFileKeyFieldAsset_Global( impactData.weaponName, "vortex_absorb_effect" )
		vortexImpactWeaponInfo[ impactData.weaponName ].absorbFX_3p 					<- GetWeaponInfoFileKeyFieldAsset_Global( impactData.weaponName, "vortex_absorb_effect_third_person" )
		vortexImpactWeaponInfo[ impactData.weaponName ].refireBehavior 					<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "vortex_refire_behavior" )
		vortexImpactWeaponInfo[ impactData.weaponName ].absorbSound 					<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "vortex_absorb_sound" )
		vortexImpactWeaponInfo[ impactData.weaponName ].absorbSound_1p_vs_3p			<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "vortex_absorb_sound_1p_vs_3p" )
		vortexImpactWeaponInfo[ impactData.weaponName ].explosionradius 				<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "explosionradius" )
		vortexImpactWeaponInfo[ impactData.weaponName ].explosion_damage_heavy_armor	<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "explosion_damage_heavy_armor" )
		vortexImpactWeaponInfo[ impactData.weaponName ].explosion_damage				<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "explosion_damage" )
		vortexImpactWeaponInfo[ impactData.weaponName ].impact_effect_table				<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "impact_effect_table" )
		vortexImpactWeaponInfo[ impactData.weaponName ].grenade_ignition_time			<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "grenade_ignition_time" )
		vortexImpactWeaponInfo[ impactData.weaponName ].grenade_fuse_time				<- GetWeaponInfoFileKeyField_Global( impactData.weaponName, "grenade_fuse_time" )
	}

	impactData.absorbFX				= vortexImpactWeaponInfo[ impactData.weaponName ].absorbFX
	impactData.absorbFX_3p			= vortexImpactWeaponInfo[ impactData.weaponName ].absorbFX_3p
	if ( impactData.absorbFX )
		Assert( impactData.absorbFX_3p, "Missing 3rd person absorb effect for " + impactData.weaponName )
	impactData.refireBehavior		= vortexImpactWeaponInfo[ impactData.weaponName ].refireBehavior

	local absorbSound = vortexImpactWeaponInfo[ impactData.weaponName ].absorbSound
	if ( absorbSound )
		impactData.absorbSFX = absorbSound

	local absorbSound_1p_vs_3p = vortexImpactWeaponInfo[ impactData.weaponName ].absorbSound_1p_vs_3p
	if ( absorbSound_1p_vs_3p )
		impactData.absorbSFX_1p_vs_3p = absorbSound_1p_vs_3p

	// info we need for refiring (some types of) impacts
	impactData.explosionradius		= vortexImpactWeaponInfo[ impactData.weaponName ].explosionradius
	impactData.explosion_damage		= vortexImpactWeaponInfo[ impactData.weaponName ].explosion_damage_heavy_armor
	if ( impactData.explosion_damage == null )
		impactData.explosion_damage		= vortexImpactWeaponInfo[ impactData.weaponName ].explosion_damage
	impactData.impact_effect_table	= vortexImpactWeaponInfo[ impactData.weaponName ].impact_effect_table

	return impactData
}

function Vortex_ScriptCanHandleImpactEvent( impactData )
{
	if ( impactData.refireBehavior == VORTEX_REFIRE_NONE )
		return false

	if ( !impactData.absorbFX )
		return false

	if ( impactData.impactType == "projectile" && !impactData.impact_effect_table )
		return false

	return true
}

function Vortex_StoreImpactEvent( entity vortexWeapon, impactData )
{
	vortexWeapon.w.vortexImpactData.append( impactData )
}

// safely removes data for a single impact event
function Vortex_RemoveImpactEvent( entity vortexWeapon, impactData )
{
	Vortex_ImpactData_KillAbsorbFX( impactData )

	vortexWeapon.w.vortexImpactData.fastremovebyvalue( impactData )
}

function Vortex_GetAllImpactEvents( entity vortexWeapon )
{
	return vortexWeapon.w.vortexImpactData
}

function Vortex_ClearImpactEventData( entity vortexWeapon )
{
	vortexWeapon.w.vortexImpactData = []
}

function VortexImpact_PlayAbsorbedFX( entity vortexWeapon, impactData )
{
	// generic shield ping FX
	Vortex_SpawnShieldPingFX( vortexWeapon, impactData )

	// specific absorb FX
	impactData.fxEnt_absorb = Vortex_SpawnImpactAbsorbFX( vortexWeapon, impactData )
}

// FX played when something first enters the vortex sphere
function Vortex_SpawnShieldPingFX( entity vortexWeapon, impactData )
{
	entity player = vortexWeapon.GetWeaponOwner()
	Assert( player )

	local absorbSFX = impactData.absorbSFX
	//printt( "SFX absorb sound:", absorbSFX )
	if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
		EmitSoundOnEntity( vortexWeapon, "Vortex_Shield_Deflect_Amped" )
	else
	{
		EmitSoundOnEntity( vortexWeapon, absorbSFX )
		if ( impactData.absorbSFX_1p_vs_3p != null )
		{
			if ( IsValid( impactData.attacker ) && impactData.attacker.IsPlayer() )
			{
				EmitSoundOnEntityOnlyToPlayer( vortexWeapon, impactData.attacker, impactData.absorbSFX_1p_vs_3p )
			}
		}
	}

	entity pingFX = CreateEntity( "info_particle_system" )

	if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	{
		if ( "fxBulletHitBurn" in vortexWeapon.s )
			pingFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxBulletHitBurn ) )
	}
	else
	{
		if ( "fxBulletHit" in vortexWeapon.s )
			pingFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxBulletHit ) )
	}

	pingFX.kv.start_active = 1

	DispatchSpawn( pingFX )

	pingFX.SetOrigin( impactData.origin )
	pingFX.SetParent( player )
	pingFX.Kill_Deprecated_UseDestroyInstead( 0.25 )
}

function Vortex_SpawnHeatShieldPingFX( entity vortexWeapon, impactData, bool impactTypeIsBullet )
{
	entity player = vortexWeapon.GetWeaponOwner()
	Assert( player )

	if ( impactTypeIsBullet )
		EmitSoundOnEntity( vortexWeapon, "heat_shield_stop_bullet" )
	else
		EmitSoundOnEntity( vortexWeapon, "heat_shield_stop_projectile" )

	entity pingFX = CreateEntity( "info_particle_system" )

	if ( "fxBulletHit" in vortexWeapon.s )
		pingFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxBulletHit ) )

	pingFX.kv.start_active = 1

	DispatchSpawn( pingFX )

	pingFX.SetOrigin( impactData.origin )
	pingFX.SetParent( player )
	pingFX.Kill_Deprecated_UseDestroyInstead( 0.25 )
}

function Vortex_SpawnImpactAbsorbFX( entity vortexWeapon, impactData )
{
	// in case we're in the middle of cleaning the weapon up
	if ( !IsValid( vortexWeapon.s.vortexBulletEffectCP ) )
		return

	entity owner = vortexWeapon.GetWeaponOwner()
	Assert( owner )

	local fxRefs = []

	// owner
	{
		entity fxRef = CreateEntity( "info_particle_system" )

		fxRef.SetValueForEffectNameKey( expect asset( impactData.absorbFX ) )
		fxRef.kv.start_active = 1
		fxRef.SetStopType( "destroyImmediately" )
		fxRef.kv.VisibilityFlags = ENTITY_VISIBLE_TO_OWNER
		fxRef.kv.cpoint1 = vortexWeapon.s.vortexBulletEffectCP.GetTargetName()

		DispatchSpawn( fxRef )

		fxRef.SetOwner( owner )
		fxRef.SetOrigin( impactData.origin )
		fxRef.SetParent( owner )

		fxRefs.append( fxRef )
	}

	// everyone else
	{
		entity fxRef = CreateEntity( "info_particle_system" )

		fxRef.SetValueForEffectNameKey( expect asset( impactData.absorbFX_3p ) )
		fxRef.kv.start_active = 1
		fxRef.SetStopType( "destroyImmediately" )
		fxRef.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY)  // other only visibility
		fxRef.kv.cpoint1 = vortexWeapon.s.vortexBulletEffectCP.GetTargetName()

		DispatchSpawn( fxRef )

		fxRef.SetOwner( owner )
		fxRef.SetOrigin( impactData.origin )
		fxRef.SetParent( owner )

		fxRefs.append( fxRef )
	}

	return fxRefs
}

function Vortex_CleanupImpactAbsorbFX( entity vortexWeapon )
{
	foreach ( impactData in Vortex_GetAllImpactEvents( vortexWeapon ) )
	{
		Vortex_ImpactData_KillAbsorbFX( impactData )
	}
}

function Vortex_ImpactData_KillAbsorbFX( impactData )
{
	foreach ( fxRef in impactData.fxEnt_absorb )
	{
		if ( !IsValid( fxRef ) )
			continue

		fxRef.Fire( "DestroyImmediately" )
		fxRef.Kill_Deprecated_UseDestroyInstead()
	}
}

bool function PlayerDiedOrDisconnected( entity player )
{
	if ( !IsValid( player ) )
		return true

	if ( !IsAlive( player ) )
		return true

	if ( IsDisconnected( player ) )
		return true

	return false
}

#endif // SERVER

int function VortexPrimaryAttack( entity vortexWeapon, WeaponPrimaryAttackParams attackParams )
{
	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !vortexSphere )
		return 0

	#if SERVER
		Assert( vortexSphere )
	#endif

	int totalfired = 0
	int totalAttempts = 0

	bool forceReleased = false
	// in this case, it's also considered "force released" if the charge time runs out
	if ( vortexWeapon.IsForceRelease() || vortexWeapon.GetWeaponChargeFraction() == 1 )
		forceReleased = true

	// PREDICTED REFIRES
	// bullet impact events don't individually fire back per event because we aggregate and then shotgun blast them
	int bulletsFired = Vortex_FireBackBullets( vortexWeapon, attackParams )
	totalfired += bulletsFired

	// UNPREDICTED REFIRES
	#if SERVER
		//printt( "server: force released?", forceReleased )

		local unpredictedRefires = Vortex_GetProjectileImpacts( vortexWeapon )

		// HACK we don't actually want to refire them with a spiral but
		//   this is to temporarily ensure compatibility with the Titan rocket launcher
		if ( !( "spiralMissileIdx" in vortexWeapon.s ) )
			vortexWeapon.s.spiralMissileIdx <- null
		vortexWeapon.s.spiralMissileIdx = 0

		foreach ( impactData in unpredictedRefires )
		{
			table fakeAttackParams = {pos = attackParams.pos, dir = attackParams.dir, firstTimePredicted = attackParams.firstTimePredicted, burstIndex = attackParams.burstIndex}
			bool didFire = DoVortexAttackForImpactData( vortexWeapon, fakeAttackParams, impactData, totalAttempts )
			if ( didFire )
				totalfired++
			totalAttempts++
		}
		//printt( "totalfired", totalfired )
	#else
		totalfired += GetProjectilesAbsorbedCount( vortexWeapon )
	#endif

	SetVortexAmmo( vortexWeapon, 0 )

	vortexWeapon.Signal( "VortexFired" )

	if ( forceReleased )
		DestroyVortexSphereFromVortexWeapon( vortexWeapon )
	else
		DisableVortexSphereFromVortexWeapon( vortexWeapon )

	return totalfired
}

int function Vortex_FireBackBullets( entity vortexWeapon, WeaponPrimaryAttackParams attackParams )
{
	int bulletCount = GetBulletsAbsorbedCount( vortexWeapon )
	//Defensive Check - Couldn't repro error.
	if ( "shotgunPelletsToIgnore" in vortexWeapon.s )
		bulletCount = int( ceil( bulletCount - vortexWeapon.s.shotgunPelletsToIgnore ) )

	if ( bulletCount )
	{
		bulletCount = minint( bulletCount, MAX_BULLET_PER_SHOT )

		//if ( IsClient() && GetLocalViewPlayer() == vortexWeapon.GetWeaponOwner() )
		//	printt( "vortex firing", bulletCount, "bullets" )

		float radius = LOUD_WEAPON_AI_SOUND_RADIUS_MP;
		vortexWeapon.EmitWeaponNpcSound( radius, 0.2 )
		int damageType = damageTypes.shotgun | DF_VORTEX_REFIRE
		if ( bulletCount == 1 )
			vortexWeapon.FireWeaponBullet( attackParams.pos, attackParams.dir, bulletCount, damageType )
		else
			ShotgunBlast( vortexWeapon, attackParams.pos, attackParams.dir, bulletCount, damageType )
	}

	return bulletCount
}

#if SERVER
bool function Vortex_FireBackExplosiveRound( vortexWeapon, attackParams, impactData, sequenceID )
{
	expect entity( vortexWeapon )

	// common projectile data
	float projSpeed		= 8000.0
	int damageType		= damageTypes.explosive | DF_VORTEX_REFIRE

	vortexWeapon.EmitWeaponSound( "Weapon.Explosion_Med" )

	vector attackPos
	//Requires code feature to properly fire tracers from offset positions.
	//if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	//	attackPos = impactData.origin
	//else
		attackPos = Vortex_GenerateRandomRefireOrigin( vortexWeapon )

	vector fireVec = Vortex_GenerateRandomRefireVector( vortexWeapon, VORTEX_EXP_ROUNDS_RETURN_SPREAD_XY, VORTEX_EXP_ROUNDS_RETURN_SPREAD_Z )

	// fire off the bolt
	entity bolt = vortexWeapon.FireWeaponBolt( attackPos, fireVec, projSpeed, DF_IMPACT | damageType, damageType, PROJECTILE_NOT_PREDICTED, sequenceID )
	if ( bolt )
	{
		bolt.kv.gravity = 0.3
		bolt.s.storedFlags <- damageType
		Vortex_ProjectileCommonSetup( bolt, impactData )
	}

	return true
}

bool function Vortex_FireBackProjectileBullet( vortexWeapon, attackParams, impactData, sequenceID )
{
	expect entity( vortexWeapon )

	// common projectile data
	float projSpeed		= 12000.0
	int damageType		= damageTypes.bullet | DF_VORTEX_REFIRE

	vortexWeapon.EmitWeaponSound( "Weapon.Explosion_Med" )

	vector attackPos
	//Requires code feature to properly fire tracers from offset positions.
	//if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	//	attackPos = impactData.origin
	//else
		attackPos = Vortex_GenerateRandomRefireOrigin( vortexWeapon )

	vector fireVec = Vortex_GenerateRandomRefireVector( vortexWeapon, 0.15, 0.1 )
	//printt( Time(), fireVec ) // print for bug with random

	// fire off the bolt
	entity bolt = vortexWeapon.FireWeaponBolt( attackPos, fireVec, projSpeed, DF_IMPACT | damageType, damageType, PROJECTILE_NOT_PREDICTED, sequenceID )
	if ( bolt )
	{
		bolt.kv.gravity = 0.0
		bolt.s.storedFlags <- damageType
		Vortex_ProjectileCommonSetup( bolt, impactData )
	}

	return true
}

vector function Vortex_GenerateRandomRefireOrigin( entity vortexWeapon, float distFromCenter = 3.0 )
{
	float distFromCenter_neg = distFromCenter * -1

	vector attackPos = expect vector( vortexWeapon.s.vortexBulletEffectCP.GetOrigin() )

	float x = RandomFloatRange( distFromCenter_neg, distFromCenter )
	float y = RandomFloatRange( distFromCenter_neg, distFromCenter )
	float z = RandomFloatRange( distFromCenter_neg, distFromCenter )

	attackPos = attackPos + Vector( x, y, z )

	return attackPos
}

vector function Vortex_GenerateRandomRefireVector( entity vortexWeapon, float vecSpread, float vecSpreadZ )
{
	float x = RandomFloatRange( vecSpread * -1, vecSpread )
	float y = RandomFloatRange( vecSpread * -1, vecSpread )
	float z = RandomFloatRange( vecSpreadZ * -1, vecSpreadZ )

	vector fireVec = vortexWeapon.GetWeaponOwner().GetPlayerOrNPCViewVector() + Vector( x, y, z )
	return fireVec
}

bool function Vortex_FireBackRocket( vortexWeapon, attackParams, impactData, sequenceID )
{
	expect entity( vortexWeapon )

	// TODO prediction for clients
	Assert( IsServer() )

	entity rocket = vortexWeapon.FireWeaponMissile( attackParams.pos, attackParams.dir, 1800.0, DF_IMPACT | damageTypes.largeCaliberExp | DF_VORTEX_REFIRE, damageTypes.largeCaliberExp | DF_VORTEX_REFIRE, false, PROJECTILE_NOT_PREDICTED )

	if ( rocket )
	{
		rocket.kv.lifetime = RandomFloatRange( 2.6, 3.5 )
		rocket.s.storedFlags <- damageTypes.largeCaliberExp | DF_VORTEX_REFIRE
		InitMissileForRandomDriftForVortexLow( rocket, expect vector( attackParams.pos ), expect vector( attackParams.dir ) )

		Vortex_ProjectileCommonSetup( rocket, impactData )
	}

	return true
}

bool function Vortex_FireBackGrenade( entity vortexWeapon, attackParams, impactData, int attackSeedCount, float baseFuseTime )
{
	float x = RandomFloatRange( -0.2, 0.2 )
	float y = RandomFloatRange( -0.2, 0.2 )
	float z = RandomFloatRange( -0.2, 0.2 )

	vector velocity = ( expect vector( attackParams.dir ) + Vector( x, y, z ) ) * 1500
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )

	bool hasIgnitionTime = vortexImpactWeaponInfo[ impactData.weaponName ].grenade_ignition_time > 0
	float fuseTime = hasIgnitionTime ? 0.0 : baseFuseTime
	const int HARDCODED_DAMAGE_TYPE = (damageTypes.explosive | DF_VORTEX_REFIRE)

	entity grenade = vortexWeapon.FireWeaponGrenade( attackParams.pos, velocity, angularVelocity, fuseTime, DF_IMPACT | HARDCODED_DAMAGE_TYPE, HARDCODED_DAMAGE_TYPE, PROJECTILE_NOT_PREDICTED, true, true )
	if ( grenade )
	{
		grenade.s.storedFlags <- HARDCODED_DAMAGE_TYPE
		Grenade_Init( grenade, vortexWeapon )
		Vortex_ProjectileCommonSetup( grenade, impactData )
		if ( hasIgnitionTime )
			grenade.SetGrenadeIgnitionDuration( vortexImpactWeaponInfo[ impactData.weaponName ].grenade_ignition_time )
	}

	return (grenade ? true : false)
}

bool function DoVortexAttackForImpactData( entity vortexWeapon, attackParams, impactData, int attackSeedCount )
{
	bool didFire = false

    //Projectiles don't actually preserve the mod, so store it in impactData
    impactData.ampedVortex <- vortexWeapon.HasMod( "LTSRebalance_pas_ion_vortex" )
	switch ( impactData.refireBehavior )
	{
		case VORTEX_REFIRE_EXPLOSIVE_ROUND:
			didFire = Vortex_FireBackExplosiveRound( vortexWeapon, attackParams, impactData, attackSeedCount )
			break

		case VORTEX_REFIRE_ROCKET:
			didFire = Vortex_FireBackRocket( vortexWeapon, attackParams, impactData, attackSeedCount )
			break

		case VORTEX_REFIRE_GRENADE:
			didFire = Vortex_FireBackGrenade( vortexWeapon, attackParams, impactData, attackSeedCount, 1.25 )
			break

		case VORTEX_REFIRE_GRENADE_LONG_FUSE:
			didFire = Vortex_FireBackGrenade( vortexWeapon, attackParams, impactData, attackSeedCount, 10.0 )
			break

		case VORTEX_REFIRE_BULLET:
			didFire = Vortex_FireBackProjectileBullet( vortexWeapon, attackParams, impactData, attackSeedCount )
			break

		case VORTEX_REFIRE_NONE:
			break
	}

	return didFire
}

function Vortex_ProjectileCommonSetup( entity projectile, impactData )
{
	// custom tag it so it shows up correctly if it hits another vortex sphere
	projectile.s.originalDamageSource <- impactData.damageSourceID

	Vortex_SetImpactEffectTable_OnProjectile( projectile, impactData )  // set the correct impact effect table

	projectile.SetVortexRefired( true ) // This tells code the projectile was refired from the vortex so that it uses "projectile_vortex_vscript"
	projectile.SetModel( GetWeaponInfoFileKeyFieldAsset_Global( impactData.weaponName, "projectilemodel" ) )
	projectile.SetWeaponClassName( impactData.weaponName )  // causes the projectile to use its normal trail FX

	projectile.ProjectileSetDamageSourceID( impactData.damageSourceID ) // obit will show the owner weapon

	if ( LTSRebalance_Enabled() )
	{
		projectile.s.storedReflectMods <- impactData.storedReflectMods
		AddEntityDestroyedCallback( projectile, LTSRebalance_FixVortexRefireExplosion )
	}

    if ( impactData.ampedVortex )
        OnFireAmpProjectile( projectile )
}

// gives a refired projectile the correct impact effect table
function Vortex_SetImpactEffectTable_OnProjectile( projectile, impactData )
{
	//Getting more info for bug 207595, don't check into Staging.
	#if DEV
	printt( "impactData.impact_effect_table ", impactData.impact_effect_table )
	if ( impactData.impact_effect_table == "" )
		PrintTable( impactData )
	#endif

	local fxTableHandle = GetImpactEffectTable( impactData.impact_effect_table )

	projectile.SetImpactEffectTable( fxTableHandle )
}

/*	Since there's no way to set projectile damage or scale it without making an attachment
	for everything, we instead use damage callbacks.
	We're just utilizing the DF_VORTEX_REFIRE damage type since it's convenient, but technically
	any projectile of the same type that gets reflected and lands while an Amped Vortex's projectiles
	are in flight will take the amp for themselves. This is a very rare edge case, though, so it
	shouldn't be an issue.
*/
void function OnFireAmpProjectile( entity projectile )
{
    int id = projectile.ProjectileGetDamageSourceID()

	// Add the bonus damage callback for these projectiles and count each one fired
	// We want to remove the callback once all have died (so normal Vortexes are unaffected)
    if ( !( id in ampDamageSourceIdCounts ) )
    {
        ampDamageSourceIdCounts[id] <- 0
        AddDamageCallbackSourceID( id, OnDamageAmpProjectile )
        AddEntityDestroyedCallback( projectile, DecrementAmpCountOnDestroy )
    }
    ampDamageSourceIdCounts[id]++
}

void function OnDamageAmpProjectile( entity victim, var damageInfo )
{
	// Causes only reflected projectiles to receive the amp
    if ( !( DamageInfo_GetCustomDamageType( damageInfo ) & DF_VORTEX_REFIRE ) )
        return

    DamageInfo_ScaleDamage( damageInfo, PAS_ION_VORTEX_AMP )
}

function DecrementAmpCountOnDestroy( projectile )
{
    int id = expect int( projectile.ProjectileGetDamageSourceID() )
    ampDamageSourceIdCounts[id]--
    if ( ampDamageSourceIdCounts[id] == 0 )
    {
        delete ampDamageSourceIdCounts[id]
        shGlobal.damageSourceIdCallbacks[id].fastremovebyvalue( OnDamageAmpProjectile )
    }
}
#endif // SERVER

// absorbed bullets are tracked with a special networked kv variable because clients need to know how many bullets to fire as well, when they are doing the client version of FireWeaponBullet
int function GetBulletsAbsorbedCount( entity vortexWeapon )
{
	if ( !vortexWeapon )
		return 0

	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !vortexSphere )
		return 0

	return vortexSphere.GetBulletAbsorbedCount()
}

int function GetProjectilesAbsorbedCount( entity vortexWeapon )
{
	if ( !vortexWeapon )
		return 0

	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !vortexSphere )
		return 0

	return vortexSphere.GetProjectileAbsorbedCount()
}

#if SERVER
function Vortex_GetProjectileImpacts( entity vortexWeapon )
{
	local impacts = []
	foreach ( impactData in Vortex_GetAllImpactEvents( vortexWeapon ) )
	{
		if ( impactData.impactType == "projectile" )
			impacts.append( impactData )
	}

	return impacts
}

function Vortex_GetHitscanBulletImpacts( entity vortexWeapon )
{
	local impacts = []
	foreach ( impactData in Vortex_GetAllImpactEvents( vortexWeapon ) )
	{
		if ( impactData.impactType == "hitscan" )
			impacts.append( impactData )
	}

	return impacts
}

int function GetHitscanBulletImpactCount( entity vortexWeapon )
{
	int count = 0
	foreach ( impactData in Vortex_GetAllImpactEvents( vortexWeapon ) )
	{
		if ( impactData.impactType == "hitscan" )
			count++
	}

	return count
}
#endif // SERVER

// // lets the damage callback communicate to the attacker that he hit a vortex shield
function Vortex_NotifyAttackerDidDamage( entity attacker, entity vortexOwner, hitPos )
{
	if ( !IsValid( attacker ) || !attacker.IsPlayer() )
		return

	if ( !IsValid( vortexOwner ) )
		return

	Assert( hitPos )

	attacker.NotifyDidDamage( vortexOwner, 0, hitPos, 0, 0, DAMAGEFLAG_VICTIM_HAS_VORTEX, 0, null, 0 )
}

function SetVortexAmmo( entity vortexWeapon, count )
{
	entity owner = vortexWeapon.GetWeaponOwner()
	if ( !IsValid_ThisFrame( owner ) )
		return
	#if CLIENT
		if ( !IsLocalViewPlayer( owner ) )
		return
	#endif

	vortexWeapon.SetWeaponPrimaryAmmoCount( count )
}


// sets the RGB color value for the vortex sphere FX based on current charge fraction
function VortexSphereColorUpdate( entity weapon, sphereClientFXHandle = null )
{
	weapon.EndSignal( "VortexStopping" )

	#if CLIENT
		Assert( sphereClientFXHandle != null )
	#endif
	bool isIonVortex = weapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion"
	entity weaponOwner = weapon.GetWeaponOwner()
	float energyTotal = float ( weaponOwner.GetSharedEnergyTotal() )
	while( IsValid( weapon ) && IsValid( weaponOwner ) )
	{
		vector colorVec
		if ( isIonVortex )
		{
			float energyFrac = 1.0 - float( weaponOwner.GetSharedEnergyCount() ) / energyTotal
			if ( weapon.HasMod( "pas_ion_vortex" ) || weapon.HasMod( "LTSRebalance_pas_ion_vortex" ) )
				colorVec = GetVortexSphereCurrentColor( energyFrac, VORTEX_SPHERE_COLOR_PAS_ION_VORTEX )
			else
				colorVec = GetVortexSphereCurrentColor( energyFrac )
		}
		else
		{
			colorVec = GetVortexSphereCurrentColor( weapon.GetWeaponChargeFraction() )
		}


		// update the world entity that is linked to the world FX playing on the server
		#if SERVER
			weapon.s.vortexSphereColorCP.SetOrigin( colorVec )
		#else
			// handles the server killing the vortex sphere without the client knowing right away,
			//  for example if an explosive goes off and we short circuit the charge timer
			if ( !EffectDoesExist( sphereClientFXHandle ) )
				break

			EffectSetControlPointVector( sphereClientFXHandle, 1, colorVec )
		#endif

		WaitFrame()
	}
}

vector function GetVortexSphereCurrentColor( float chargeFrac, vector fullHealthColor = VORTEX_SPHERE_COLOR_CHARGE_FULL )
{
	return GetTriLerpColor( chargeFrac, fullHealthColor, VORTEX_SPHERE_COLOR_CHARGE_MED, VORTEX_SPHERE_COLOR_CHARGE_EMPTY )
}

vector function GetShieldTriLerpColor( float frac )
{
	return GetTriLerpColor( frac, VORTEX_SPHERE_COLOR_CHARGE_FULL, VORTEX_SPHERE_COLOR_CHARGE_MED, VORTEX_SPHERE_COLOR_CHARGE_EMPTY )
}

vector function GetTriLerpColor( float fraction, vector color1, vector color2, vector color3 )
{
	float crossover1 = VORTEX_SPHERE_COLOR_CROSSOVERFRAC_FULL2MED  // from zero to this fraction, fade between color1 and color2
	float crossover2 = VORTEX_SPHERE_COLOR_CROSSOVERFRAC_MED2EMPTY  // from crossover1 to this fraction, fade between color2 and color3

	float r, g, b

	// 0 = full charge, 1 = no charge remaining
	if ( fraction < crossover1 )
	{
		r = Graph( fraction, 0, crossover1, color1.x, color2.x )
		g = Graph( fraction, 0, crossover1, color1.y, color2.y )
		b = Graph( fraction, 0, crossover1, color1.z, color2.z )
		return <r, g, b>
	}
	else if ( fraction < crossover2 )
	{
		r = Graph( fraction, crossover1, crossover2, color2.x, color3.x )
		g = Graph( fraction, crossover1, crossover2, color2.y, color3.y )
		b = Graph( fraction, crossover1, crossover2, color2.z, color3.z )
		return <r, g, b>
	}
	else
	{
		// for the last bit of overload timer, keep it max danger color
		r = color3.x
		g = color3.y
		b = color3.z
		return <r, g, b>
	}

	unreachable
}

// generic impact validation
#if SERVER
bool function ValidateVortexImpact( entity vortexSphere, entity projectile = null )
{
	Assert( IsServer() )

	if ( !IsValid( vortexSphere ) )
		return false

	if ( !vortexSphere.GetOwnerWeapon() )
		return false

	entity vortexWeapon = vortexSphere.GetOwnerWeapon()
	if ( !IsValid( vortexWeapon ) )
		return false

	if ( projectile )
	{
		if ( !IsValid_ThisFrame( projectile ) )
			return false

		if ( projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_ignores_vortex" ) == 1 )
			return false

		if ( projectile.ProjectileGetWeaponClassName() == "" )
			return false

		// TEMP HACK
		if ( projectile.ProjectileGetWeaponClassName() == "mp_weapon_tether" )
			return false
	}

	return true
}

// Only for mobile shields (would not work for Particle)
// Returns false on attacks that are in the same direction as the Vortex.
// This is mainly to prevent Vortex/Thermal from blocking someone's attacks when used behind them.
bool function ValidateVortexDirection( entity vortexWeapon, entity attacker, entity inflictor )
{
	if ( !LTSRebalance_Enabled() )
		return true

    if ( !IsValid( vortexWeapon ) )
		return false

    vector ownerDir = vortexWeapon.GetWeaponOwner().GetPlayerOrNPCViewVector()
    vector enemyDir
    if( inflictor.IsProjectile() )
    {
        if( inflictor.GetVelocity() == <0, 0, 0>)
            return true
        else
            enemyDir = Normalize( inflictor.GetVelocity() )
    }
    else if ( IsValid( attacker ) && ( attacker.IsPlayer() || attacker.IsNPC() ) )
        enemyDir = attacker.GetPlayerOrNPCViewVector()
	else
		return true

    // Reject all bullets caught moving in the direction of the shield
    if ( DotProduct( ownerDir, enemyDir ) > 0 )
        return false

    return true
}
#endif

/********************************/
/*	Setting override functions	*/
/********************************/

function Vortex_SetTagName( entity weapon, string tagName )
{
	Vortex_SetWeaponSettingOverride( weapon, "vortexTagName", tagName )
}

function Vortex_SetBulletCollectionOffset( entity weapon, vector offset )
{
	Vortex_SetWeaponSettingOverride( weapon, "bulletCollectionOffset", offset )
}

function Vortex_SetWeaponSettingOverride( entity weapon, string setting, value )
{
	if ( !( setting in weapon.s ) )
		weapon.s[ setting ] <- null
	weapon.s[ setting ] = value
}

string function GetVortexTagName( entity weapon )
{
	if ( "vortexTagName" in weapon.s )
		return expect string( weapon.s.vortexTagName )

	return "vortex_center"
}

vector function GetBulletCollectionOffset( entity weapon )
{
	if ( "bulletCollectionOffset" in weapon.s )
		return expect vector( weapon.s.bulletCollectionOffset )

	entity owner = weapon.GetWeaponOwner()
	if ( owner.IsTitan() )
		return Vector( 300.0, -90.0, -70.0 )
	else
		return Vector( 80.0, 17.0, -11.0 )

	unreachable
}


#if SERVER
function VortexSphereDrainHealthForDamage( entity vortexSphere, damage )
{
	// don't drain the health of vortex_spheres that are set to be invulnerable. This is the case for the Particle Wall
	if ( vortexSphere.IsInvulnerable() )
		return

	local result = {}
	result.damage <- damage
	vortexSphere.Signal( "Script_OnDamaged", result )

	int currentHealth = vortexSphere.GetHealth()
	Assert( damage >= 0 )
	// JFS to fix phone home bug; we never hit the assert above locally...
	damage = max( damage, 0 )
	vortexSphere.SetHealth( currentHealth - damage )

	entity vortexWeapon = vortexSphere.GetOwnerWeapon()
	if ( IsValid( vortexWeapon ) && vortexWeapon.HasMod( "fd_gun_shield_redirect" ) )
	{
		entity owner = vortexWeapon.GetWeaponOwner()
		if ( IsValid( owner ) && owner.IsTitan() )
		{
			entity soul = owner.GetTitanSoul()
			if ( IsValid( soul ) )
			{
				int shieldRestoreAmount = int( damage ) //Might need tuning
				soul.SetShieldHealth( min( soul.GetShieldHealth() + shieldRestoreAmount, soul.GetShieldHealthMax() ) )
			}
		}
	}

	UpdateShieldWallColorForFrac( vortexSphere.e.shieldWallFX, GetHealthFrac( vortexSphere ) )
}
#endif


bool function CodeCallback_OnVortexHitBullet( entity weapon, entity vortexSphere, var damageInfo )
{
	bool isAmpedWall = vortexSphere.GetTargetName() == PROTO_AMPED_WALL
	bool takesDamage = !isAmpedWall
	bool adjustImpactAngles = !(vortexSphere.GetTargetName() == GUN_SHIELD_WALL)

	#if SERVER
		if ( vortexSphere.e.BulletHitRules != null )
		{
			vortexSphere.e.BulletHitRules( vortexSphere, damageInfo )
			takesDamage = takesDamage && (DamageInfo_GetDamage( damageInfo ) > 0)
		}
	#endif

	vector damageAngles = vortexSphere.GetAngles()

	if ( adjustImpactAngles )
		damageAngles = AnglesCompose( damageAngles, Vector( 90, 0, 0 ) )

	int teamNum = vortexSphere.GetTeam()

	#if CLIENT
		vector damageOrigin = DamageInfo_GetDamagePosition( damageInfo )
		if ( !isAmpedWall )
		{
			// TODO: slightly change angles to match radius rotation of vortex cylinder
			int effectHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( SHIELD_WALL_BULLET_FX ), damageOrigin, damageAngles )
			//local color = GetShieldTriLerpColor( 1 - GetHealthFrac( vortexSphere ) )
			vector color = GetShieldTriLerpColor( 0.0 )
			EffectSetControlPointVector( effectHandle, 1, color )
		}

		if ( takesDamage )
		{
			float damage = ceil( DamageInfo_GetDamage( damageInfo ) )
			int damageType = DamageInfo_GetCustomDamageType( damageInfo )
			DamageFlyout( damage, damageOrigin, vortexSphere, false, false )
		}

		if ( DamageInfo_GetAttacker( damageInfo ) && DamageInfo_GetAttacker( damageInfo ).IsTitan() )
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Heavy.BulletImpact_1P_vs_3P" )
		else
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Light.BulletImpact_1P_vs_3P" )
	#else
		if ( !isAmpedWall )
		{
			int fxId = GetParticleSystemIndex( SHIELD_WALL_BULLET_FX )
			PlayEffectOnVortexSphere( fxId, DamageInfo_GetDamagePosition( damageInfo ), damageAngles, vortexSphere )
		}

		entity weapon = DamageInfo_GetWeapon( damageInfo )
		float damage = ceil( DamageInfo_GetDamage( damageInfo ) )

		entity logWeapon = IsValid( weapon ) ? weapon : DamageInfo_GetInflictor( damageInfo )
		if ( logWeapon.IsPlayer() || logWeapon.IsNPC() )
			logWeapon = null
		LTSRebalance_LogDamageBlocked( vortexSphere.GetOwner(), DamageInfo_GetAttacker( damageInfo ), logWeapon, damageInfo )


		Assert( damage >= 0, "Bug 159851 - Damage should be greater than or equal to 0.")
		damage = max( 0.0, damage )

		if ( IsValid( weapon ) )
			damage = HandleWeakToPilotWeapons( vortexSphere, weapon.GetWeaponClassName(), damage )

		if ( takesDamage )
		{
			// LTS Rebalance doesn't need to remove this since this callback only occurs for hitscans
			ShieldDamageModifier damageModifier = GetShieldDamageModifier( damageInfo )
			damage *= damageModifier.damageScale
			VortexSphereDrainHealthForDamage( vortexSphere, damage )
		}

		if ( DamageInfo_GetAttacker( damageInfo ) && DamageInfo_GetAttacker( damageInfo ).IsTitan() )
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Heavy.BulletImpact_3P_vs_3P" )
		else
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Light.BulletImpact_3P_vs_3P" )
	#endif

	if ( isAmpedWall )
	{
		#if SERVER
		DamageInfo_ScaleDamage( damageInfo, AMPED_DAMAGE_SCALAR )
		#endif
		return false
	}

	return true
}

bool function OnVortexHitBullet_BubbleShieldNPC( entity vortexSphere, var damageInfo )
{
	vector vortexOrigin 	= vortexSphere.GetOrigin()
	vector damageOrigin 	= DamageInfo_GetDamagePosition( damageInfo )

	float distSq = DistanceSqr( vortexOrigin, damageOrigin )
	if ( distSq < MINION_BUBBLE_SHIELD_RADIUS_SQR )
		return false//the damage is coming from INSIDE the sphere

	vector damageVec 	= damageOrigin - vortexOrigin
	vector damageAngles = VectorToAngles( damageVec )
	damageAngles = AnglesCompose( damageAngles, Vector( 90, 0, 0 ) )

	int teamNum = vortexSphere.GetTeam()

	#if CLIENT
		int effectHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( SHIELD_WALL_BULLET_FX ), damageOrigin, damageAngles )

		vector color = GetShieldTriLerpColor( 0.9 )
		EffectSetControlPointVector( effectHandle, 1, color )

		if ( DamageInfo_GetAttacker( damageInfo ) && DamageInfo_GetAttacker( damageInfo ).IsTitan() )
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Heavy.BulletImpact_1P_vs_3P" )
		else
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Light.BulletImpact_1P_vs_3P" )
	#else
		int fxId = GetParticleSystemIndex( SHIELD_WALL_BULLET_FX )
		PlayEffectOnVortexSphere( fxId, DamageInfo_GetDamagePosition( damageInfo ), damageAngles, vortexSphere )
		//VortexSphereDrainHealthForDamage( vortexSphere, DamageInfo_GetWeapon( damageInfo ), null )

		if ( DamageInfo_GetAttacker( damageInfo ) && DamageInfo_GetAttacker( damageInfo ).IsTitan() )
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Heavy.BulletImpact_3P_vs_3P" )
		else
			EmitSoundAtPosition( teamNum, DamageInfo_GetDamagePosition( damageInfo ), "TitanShieldWall.Light.BulletImpact_3P_vs_3P" )
	#endif
	return true
}

bool function CodeCallback_OnVortexHitProjectile( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos )
{
	// code shouldn't call this on an invalid vortexsphere!
	if ( !IsValid( vortexSphere ) )
		return false

	var ignoreVortex = projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_ignores_vortex" )
	if ( ignoreVortex != null )
	{
		#if SERVER
		if ( projectile.proj.hasBouncedOffVortex )
			return false

		vector velocity = projectile.GetVelocity()
		vector multiplier

		switch ( ignoreVortex )
		{
			case "drop":
				multiplier = < -0.25, -0.25, 0.0 >
				break

			case "fall_vortex":
			case "fall":
				multiplier = < -0.25, -0.25, -0.25 >
				break

			case "mirror":
				// bounce back, assume along xy axis
				multiplier = < -1.0, -1.0, 1.0 >
				break

			default:
				CodeWarning( "Unknown projectile_ignores_vortex " + ignoreVortex )
				break
		}

		velocity = < velocity.x * multiplier.x, velocity.y * multiplier.y, velocity.z * multiplier.z >
		projectile.proj.hasBouncedOffVortex = true
		projectile.SetVelocity( velocity )
		#endif
		return false
	}

	bool adjustImpactAngles = !(vortexSphere.GetTargetName() == GUN_SHIELD_WALL)

	vector damageAngles = vortexSphere.GetAngles()

	if ( adjustImpactAngles )
		damageAngles = AnglesCompose( damageAngles, Vector( 90, 0, 0 ) )

	asset projectileSettingFX = projectile.GetProjectileWeaponSettingAsset( eWeaponVar.vortex_impact_effect )
	asset impactFX = (projectileSettingFX != $"") ? projectileSettingFX : SHIELD_WALL_EXPMED_FX

	bool isAmpedWall = vortexSphere.GetTargetName() == PROTO_AMPED_WALL
	bool takesDamage = !isAmpedWall

	#if SERVER
		if ( vortexSphere.e.ProjectileHitRules != null )
			takesDamage = vortexSphere.e.ProjectileHitRules( vortexSphere, attacker, takesDamage )
	#endif
	// hack to let client know about amped wall, and to amp the shot
	if ( isAmpedWall )
		impactFX = AMPED_WALL_IMPACT_FX

	int teamNum = vortexSphere.GetTeam()

	#if CLIENT
		if ( !isAmpedWall )
		{
			int effectHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( impactFX ), contactPos, damageAngles )
			//local color = GetShieldTriLerpColor( 1 - GetHealthFrac( vortexSphere ) )
			vector color = GetShieldTriLerpColor( 0.0 )
			EffectSetControlPointVector( effectHandle, 1, color )
		}

		var impact_sound_1p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_1p" )
		if ( impact_sound_1p == null )
			impact_sound_1p = "TitanShieldWall.Explosive.BulletImpact_1P_vs_3P"

		EmitSoundAtPosition( teamNum, contactPos, impact_sound_1p )
	#else
		if ( !isAmpedWall )
		{
			int fxId = GetParticleSystemIndex( impactFX )
			PlayEffectOnVortexSphere( fxId, contactPos, damageAngles, vortexSphere )
		}

		float damage = float( projectile.GetProjectileWeaponSettingInt( eWeaponVar.damage_near_value ) )
		if ( LTSRebalance_Enabled() )
			damage = GetProjectileDamageToParticle( projectile, false )
		
		entity logAttacker = IsValid( attacker ) ? attacker : projectile.GetOwner()
		LTSRebalance_LogDamageBlocked( vortexSphere.GetOwner(), logAttacker, projectile )

		//	once damageInfo is passed correctly we'll use that instead of looking up the values from the weapon .txt file.
		//	local damage = ceil( DamageInfo_GetDamage( damageInfo ) )

		damage = HandleWeakToPilotWeapons( vortexSphere, projectile.ProjectileGetWeaponClassName(), damage )
		damage = damage + CalculateTitanSniperExtraDamage( projectile, vortexSphere )

		if ( takesDamage )
		{
			VortexSphereDrainHealthForDamage( vortexSphere, damage )
			if ( IsValid( attacker ) && attacker.IsPlayer() )
				attacker.NotifyDidDamage( vortexSphere, 0, contactPos, 0, damage, DF_NO_HITBEEP, 0, null, 0 )
		}

		var impact_sound_3p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_3p" )

		if ( impact_sound_3p == null )
			impact_sound_3p = "TitanShieldWall.Explosive.BulletImpact_3P_vs_3P"

		EmitSoundAtPosition( teamNum, contactPos, impact_sound_3p )

		int damageSourceID = projectile.ProjectileGetDamageSourceID()
		switch ( damageSourceID )
		{
			case eDamageSourceId.mp_titanweapon_dumbfire_rockets:
				vector normal = projectile.GetVelocity() * -1
				normal = Normalize( normal )
				ClusterRocket_Detonate( projectile, normal )
				CreateNoSpawnArea( TEAM_INVALID, TEAM_INVALID, contactPos, ( CLUSTER_ROCKET_BURST_COUNT / 5.0 ) * 0.5 + 1.0, CLUSTER_ROCKET_BURST_RANGE + 100 )
				break

			case eDamageSourceId.mp_weapon_grenade_electric_smoke:
				ElectricGrenadeSmokescreen( projectile, FX_ELECTRIC_SMOKESCREEN_PILOT_AIR )
				break

			// Adds bonus damage by just doing damage again
            case eDamageSourceId.mp_titanweapon_xo16_vanguard:
                if ( TEMP_GetDamageFlagsFromProjectile( projectile ) & DF_ELECTRICAL )
                    VortexSphereDrainHealthForDamage( vortexSphere, damage * 0.25 )
                break

			case eDamageSourceId.mp_weapon_grenade_emp:

				if ( StatusEffect_Get( vortexSphere, eStatusEffect.destroyed_by_emp ) )
					VortexSphereDrainHealthForDamage( vortexSphere, vortexSphere.GetHealth() )
				break

			case eDamageSourceId.mp_titanability_sonar_pulse:
				if ( IsValid( attacker ) && attacker.IsTitan() )
				{
					int team = attacker.GetTeam()
					PulseLocation( attacker, team, contactPos, false, false )
					array<string> mods = projectile.ProjectileGetMods()
					if ( mods.contains( "pas_tone_sonar" ) )
						thread DelayedPulseLocation( attacker, team, contactPos, false, false )
				}
				break

		}
	#endif

	// hack to let client know about amped wall, and to amp the shot
	if ( isAmpedWall )
	{
		#if SERVER
		projectile.proj.damageScale = AMPED_DAMAGE_SCALAR
		#endif

		return false
	}

	return true
}

bool function OnVortexHitProjectile_BubbleShieldNPC( entity vortexSphere, entity attacker, entity projectile, vector contactPos )
{
	vector vortexOrigin 	= vortexSphere.GetOrigin()

	float dist = DistanceSqr( vortexOrigin, contactPos )
	if ( dist < MINION_BUBBLE_SHIELD_RADIUS_SQR )
		return false // the damage is coming from INSIDE THE SPHERE

	vector damageVec 	= Normalize( contactPos - vortexOrigin )
	vector damageAngles 	= VectorToAngles( damageVec )
	damageAngles = AnglesCompose( damageAngles, Vector( 90, 0, 0 ) )

	asset projectileSettingFX = projectile.GetProjectileWeaponSettingAsset( eWeaponVar.vortex_impact_effect )
	asset impactFX = (projectileSettingFX != $"") ? projectileSettingFX : SHIELD_WALL_EXPMED_FX

	int teamNum = vortexSphere.GetTeam()

	#if CLIENT
		int effectHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( impactFX ), contactPos, damageAngles )

		vector color = GetShieldTriLerpColor( 0.9 )
		EffectSetControlPointVector( effectHandle, 1, color )

		EmitSoundAtPosition( teamNum, contactPos, "TitanShieldWall.Explosive.BulletImpact_1P_vs_3P" )
	#else
		int fxId = GetParticleSystemIndex( impactFX )
		PlayEffectOnVortexSphere( fxId, contactPos, damageAngles, vortexSphere )
//		VortexSphereDrainHealthForDamage( vortexSphere, null, projectile )

		EmitSoundAtPosition( teamNum, contactPos, "TitanShieldWall.Explosive.BulletImpact_3P_vs_3P" )

		if ( projectile.ProjectileGetDamageSourceID() == eDamageSourceId.mp_titanweapon_dumbfire_rockets )
		{
			vector normal = projectile.GetVelocity() * -1
			normal = Normalize( normal )
			ClusterRocket_Detonate( projectile, normal )
			CreateNoSpawnArea( TEAM_INVALID, TEAM_INVALID, contactPos, ( CLUSTER_ROCKET_BURST_COUNT / 5.0 ) * 0.5 + 1.0, CLUSTER_ROCKET_BURST_RANGE + 100 )
		}
	#endif
	return true
}

#if SERVER
float function HandleWeakToPilotWeapons( entity vortexSphere, string weaponName, float damage )
{
	if ( vortexSphere.e.proto_weakToPilotWeapons ) //needs code for real, but this is fine for prototyping
	{
		// is weapon a pilot weapon?
		local refType = GetWeaponInfoFileKeyField_Global( weaponName, "weaponClass" )
		if ( refType == "human" )
		{
			damage *= VORTEX_PILOT_WEAPON_WEAKNESS_DAMAGESCALE
		}
	}

	return damage
}

void function LTSRebalance_FixVortexRefire( entity victim, var damageInfo )
{
	// Only affect reflected attacks
	if ( !( DamageInfo_GetCustomDamageType( damageInfo ) & DF_VORTEX_REFIRE ) )
        return
	
	entity projectile = DamageInfo_GetInflictor( damageInfo )
	if ( projectile && "directHit" in projectile.s && projectile.s.directHit == victim )
		DamageInfo_SetDamage( damageInfo, 0 )

	if ( !IsValid( projectile ) || !projectile.IsProjectile() )
		return
	
	array var_mods = ( "storedReflectMods" in projectile.s ) ? expect array( projectile.s.storedReflectMods ) : []
	array<string> mods
	foreach ( str in var_mods )
		mods.append( expect string( str ) )

	// No mods, no difference
	if ( mods.len() == 0 )
		return

	float damage = DamageInfo_GetDamage( damageInfo )
	// If we set damage directly, we could override other callbacks that modify the damage in some way.
	// Hence, we instead scale the damage to the intended value.
	DamageInfo_ScaleDamage( damageInfo, GetProjectileDamageScaleToMods( victim, damageInfo, projectile.ProjectileGetWeaponClassName(), mods ) )
}

// Returns the amount that a projectile's damage should be scaled to match its damage with mods (attachments).
float function GetProjectileDamageScaleToMods( entity victim, var damageInfo, string weaponName, array<string> mods )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	bool isPlayer = true

	if ( IsValid( attacker ) && !attacker.IsProjectile() )
		isPlayer = attacker.IsPlayer()

	bool heavyArmor = victim.GetArmorType() == ARMOR_TYPE_HEAVY

	if ( ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_IMPACT ) )
	{
		entity projectile = DamageInfo_GetInflictor( damageInfo )
		if ( IsValid( projectile ) )
			projectile.s.directHit <- victim

		bool critHit = IsCriticalHit( DamageInfo_GetAttacker( damageInfo ), victim, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamage( damageInfo ), DamageInfo_GetDamageType( damageInfo ) )

		float nearDamage = 0.0
		float farDamage = 0.0
		float nearDamageMod = 0.0
		float farDamageMod = 0.0
		float critScale = 1.0
		if ( critHit )
			critScale = expect float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "critical_hit_damage_scale" ) / GetWeaponInfoFileKeyField_Global( weaponName, "critical_hit_damage_scale" ) )

		array<string> keys = [ "npc_damage_near_value_titanarmor", "npc_damage_near_value", 
							"damage_near_value_titanarmor", "damage_near_value" ]

		int start = 2 * isPlayer.tointeger()
		int inc = ( !heavyArmor ).tointeger() + 1
		for ( int i = start + inc - 1; i < keys.len(); i += inc )
		{
			nearDamage = float( GetWeaponInfoFileKeyField_Global( weaponName, keys[i] ) )
			if ( nearDamageMod <= 0 ) // Attachments may add new values
				nearDamageMod = float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, keys[i] ) )
			if ( nearDamage > 0 )
				break
		}

		if ( nearDamage <= 0 )
			return 0.0

		keys = [ "npc_damage_far_value_titanarmor", "npc_damage_far_value", 
				"damage_far_value_titanarmor", "damage_far_value" ]

		for ( int i = start + inc - 1; i < keys.len(); i += inc )
		{
			farDamage = float( GetWeaponInfoFileKeyField_Global( weaponName, keys[i] ) )
			if ( farDamageMod <= 0 ) // Attachments may add new values
				farDamageMod = float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, keys[i] ) )
			if ( farDamage > 0 )
				break
		}

		if ( farDamage <= 0 || farDamage >= nearDamage )
			return nearDamageMod / nearDamage * critScale

		// Could check these just in case, but no titan weapons lack these values.
		// Similarly, won't check very far distance since no titan weapons use it.
		float nearDistance = expect float( GetWeaponInfoFileKeyField_Global( weaponName, "damage_near_distance" ) )
		float farDistance = expect float( GetWeaponInfoFileKeyField_Global( weaponName, "damage_far_distance" ) )
		float nearDistanceMod = expect float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "damage_near_distance" ) )
		float farDistanceMod = expect float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "damage_far_distance" ) )
		float dist = DamageInfo_GetDistFromAttackOrigin( damageInfo )

		float damage = GraphCapped( dist, nearDistance, farDistance, nearDamage, farDamage )
		float damageMod = GraphCapped( dist, nearDistanceMod, farDistanceMod, nearDamageMod, farDamageMod )

		return damageMod / damage * critScale
	}

	// Explosion damage corrected with Projectile OnDestroy callback by creating a new explosion.
	// Zero out this explosion's damage since the callback will do the damage.
	return 0.0 
}

function LTSRebalance_FixVortexRefireExplosion( projectile )
{
	expect entity( projectile )
	if ( !( "storedFlags" in projectile.s ) )
		return

	array var_mods = ( "storedReflectMods" in projectile.s ) ? expect array( projectile.s.storedReflectMods ) : []
	array<string> mods
	foreach ( str in var_mods )
		mods.append( expect string( str ) )

	// No mods, no difference
	if ( mods.len() == 0 )
		return

	array<string> keys = [ "npc_explosion_damage_heavy_armor", "npc_explosion_damage", 
							"explosion_damage_heavy_armor", "explosion_damage" ]

	entity owner = projectile.GetOwner()
	bool isPlayer = !IsValid( owner ) ? owner.IsPlayer() : true
	string weaponName = projectile.ProjectileGetWeaponClassName()

	int start = 2 * isPlayer.tointeger() 
	float explosionDamageMod = float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, keys[start+1] ) )
	float explosionDamageModTitan = float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, keys[start] ) )

	// Calculate the damage falloff at the distance for 
	float innerRadiusMod = expect float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "explosion_inner_radius" ) )
	float outerRadiusMod = expect float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "explosionradius" ) )

	if ( outerRadiusMod <= 0 || ( explosionDamageMod == 0 && explosionDamageModTitan == 0 ) )
		return

	float impulseForce = expect float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "impulse_force_explosions" ) )
	if ( impulseForce <= 0 )
		impulseForce = expect float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "impulse_force" ) )
	
	int flags = SF_ENVEXPLOSION_MASK_BRUSHONLY | SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT
	if ( !( expect bool( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "explosion_damages_owner" ) ) ) )
		flags = flags | SF_ENVEXPLOSION_NO_DAMAGEOWNER
	
	// At this stage the projectile is not valid but still not null, so it will not have its damage set to 0 by Refire's damage callback
	RadiusDamage(
		projectile.GetOrigin(),
		owner,
		projectile,
		explosionDamageMod,
		explosionDamageModTitan,
		innerRadiusMod,
		outerRadiusMod,
		flags,
		0,
		impulseForce,
		expect int( projectile.s.storedFlags ),
		projectile.ProjectileGetDamageSourceID()
		)
}

float function LTSRebalance_GetProjectileDamage( entity projectile, bool heavyArmor = true, bool isPlayer = true )
{
	return GetProjectileDamageToParticle( projectile, heavyArmor, isPlayer )
}

float function LTSRebalance_GetWeaponDamage( entity weapon, var damageInfo = null, bool heavyArmor = true, bool isPlayer = true )
{
	return GetWeaponDamageToParticle( weapon, damageInfo, heavyArmor, isPlayer )
}

float function GetWeaponDamageToParticle( entity weapon, var damageInfo = null, bool heavyArmor = true, bool isPlayer = true )
{
	if ( !IsValid( weapon ) )
		return 0.0

	float nearDamage = 0.0
	array<int> keys = [ eWeaponVar.npc_damage_near_value_titanarmor, eWeaponVar.npc_damage_near_value, 
						   eWeaponVar.damage_near_value_titanarmor, eWeaponVar.damage_near_value ]

	int start = 2 * isPlayer.tointeger()
	int inc = ( !heavyArmor ).tointeger() + 1
	for ( int i = start + inc - 1; i < keys.len(); i += inc )
	{
		nearDamage = float( weapon.GetWeaponSettingInt( keys[i] ) )
		if ( nearDamage > 0 )
			break
	}

	if ( nearDamage <= 0 )
		return 0.0

	float farDamage = 0.0
	keys = [ eWeaponVar.npc_damage_far_value_titanarmor, eWeaponVar.npc_damage_far_value, 
			 eWeaponVar.damage_far_value_titanarmor, eWeaponVar.damage_far_value ]

	for ( int i = start + inc - 1; i < keys.len(); i += inc )
	{
		farDamage = float( weapon.GetWeaponSettingInt( keys[i] ) )
		if ( farDamage > 0 )
			break
	}

	if ( farDamage <= 0 || farDamage >= nearDamage || damageInfo == null )
		return nearDamage

	float dist = DamageInfo_GetDistFromAttackOrigin( damageInfo )
	float nearDistance = weapon.GetWeaponSettingFloat( eWeaponVar.damage_near_distance )
	float farDistance = weapon.GetWeaponSettingFloat( eWeaponVar.damage_far_distance )
	return GraphCapped( dist, nearDistance, farDistance, nearDamage, farDamage )
}

float function GetProjectileDamageToParticle( entity projectile, bool heavyArmor = true, bool isPlayer = true )
{
	string weaponName = projectile.ProjectileGetWeaponClassName()
	array<string> mods = projectile.ProjectileGetMods()
	if ( "storedReflectMods" in projectile.s )
	{
		foreach( mod in projectile.s.storedReflectMods )
			mods.append( expect string( mod ) )
	}
	
	float nearDamage = 0.0
	array<string> keys = [ "npc_damage_near_value_titanarmor", "npc_damage_near_value", 
						   "damage_near_value_titanarmor", "damage_near_value" ]

	int start = 2 * isPlayer.tointeger()
	int inc = ( !heavyArmor ).tointeger() + 1
	for ( int i = start + inc - 1; i < keys.len(); i += inc )
	{
		nearDamage = float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, keys[i] ) )
		if ( nearDamage > 0 )
			break
	}

	if ( nearDamage <= 0 )
		return 0.0

	float farDamage = 0.0
	keys = [ "npc_damage_far_value_titanarmor", "npc_damage_far_value", 
			 "damage_far_value_titanarmor", "damage_far_value" ]

	for ( int i = start + inc - 1; i < keys.len(); i += inc )
	{
		farDamage = float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, keys[i] ) )
		if ( farDamage > 0 )
			break
	}

	if ( farDamage <= 0 || farDamage >= nearDamage )
		return nearDamage

	float nearDistance = expect float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "damage_near_distance" ) )
	float farDistance = expect float( GetWeaponInfoFileKeyField_WithMods_Global( weaponName, mods, "damage_far_distance" ) )
	float speed = Length( projectile.GetVelocity() )
	float dist = ( Time() - projectile.GetProjectileCreationTime() ) * speed

	return GraphCapped( dist, nearDistance, farDistance, nearDamage, farDamage )
}
#endif

// ???: reflectOrigin not used
int function VortexReflectAttack( entity vortexWeapon, attackParams, vector reflectOrigin )
{
	entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
	if ( !vortexSphere )
		return 0

	#if SERVER
		Assert( vortexSphere )
	#endif

	int totalfired = 0
	int totalAttempts = 0

	bool forceReleased = false
	// in this case, it's also considered "force released" if the charge time runs out
	if ( vortexWeapon.IsForceRelease() || vortexWeapon.GetWeaponChargeFraction() == 1 )
		forceReleased = true

	//Requires code feature to properly fire tracers from offset positions.
	//if ( vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
	//	attackParams.pos = reflectOrigin

	// PREDICTED REFIRES
	// bullet impact events don't individually fire back per event because we aggregate and then shotgun blast them

	//Remove the below script after FireWeaponBulletBroadcast
	//local bulletsFired = Vortex_FireBackBullets( vortexWeapon, attackParams )
	//totalfired += bulletsFired
	int bulletCount = GetBulletsAbsorbedCount( vortexWeapon )
	if ( bulletCount > 0 )
	{
		if ( "ampedBulletCount" in vortexWeapon.s )
			vortexWeapon.s.ampedBulletCount++
		else
			vortexWeapon.s.ampedBulletCount <- 1
		vortexWeapon.Signal( "FireAmpedVortexBullet" )
		totalfired += 1
	}

	// UNPREDICTED REFIRES
	#if SERVER
		//printt( "server: force released?", forceReleased )

		local unpredictedRefires = Vortex_GetProjectileImpacts( vortexWeapon )

		// HACK we don't actually want to refire them with a spiral but
		//   this is to temporarily ensure compatibility with the Titan rocket launcher
		if ( !( "spiralMissileIdx" in vortexWeapon.s ) )
			vortexWeapon.s.spiralMissileIdx <- null
		vortexWeapon.s.spiralMissileIdx = 0
		foreach ( impactData in unpredictedRefires )
		{
			bool didFire = DoVortexAttackForImpactData( vortexWeapon, attackParams, impactData, totalAttempts )
			if ( didFire )
				totalfired++
			totalAttempts++
		}
	#endif

	SetVortexAmmo( vortexWeapon, 0 )
	vortexWeapon.Signal( "VortexFired" )

#if SERVER
	vortexSphere.ClearAllBulletsFromSphere()
#endif

	/*
	if ( forceReleased )
		DestroyVortexSphereFromVortexWeapon( vortexWeapon )
	else
		DisableVortexSphereFromVortexWeapon( vortexWeapon )
	*/

	return totalfired
}