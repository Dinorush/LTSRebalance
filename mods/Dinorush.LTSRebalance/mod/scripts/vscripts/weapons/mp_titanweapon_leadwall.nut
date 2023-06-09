/* LTS Rebalance replaces this file for the following reasons:
   1. Implement baseline changes
   2. Implement Ricochet Rounds changes (LTS Rebalance + Perfect Kits)
*/
untyped

global function OnWeaponPrimaryAttack_titanweapon_leadwall
global function OnProjectileCollision_titanweapon_leadwall

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_leadwall
#endif // #if SERVER

const float LEADWALL_LIFETIME_MIN = 0.3
const float LEADWALL_LIFETIME_MAX = 0.35
const LEADWALL_MAX_BOLTS = 8 // this is the code limit for bolts per frame... do not increase.
const float LTSREBALANCE_SPREAD_FRAC = 0.043
const float LTSREBALANCE_LEADWALL_VELOCITY = 4400
const float LTSREBALANCE_RICOCHET_SEEK_DOT_MIN = 0.87
const float LTSREBALANCE_RICOCHET_SEEK_DOT_MAX = 1
const float LTSREBALANCE_RICOCHET_SEEK_RANGE_MAX = LEADWALL_LIFETIME_MAX * LTSREBALANCE_LEADWALL_VELOCITY // max lifetime * velocity * scalar
const float LTSREBALANCE_RICOCHET_SEEK_RANGE_MIN = LEADWALL_LIFETIME_MAX * LTSREBALANCE_LEADWALL_VELOCITY * 0.25 // max lifetime * velocity * scalar
const float LTSREBALANCE_RICOCHET_SPREAD_MOD = 4 // Increase spread of ricochet'd shots to better match normal spread fired at the target
const float LTSREBALANCE_RICOCHET_MAX_COMPENSATE = 10

struct
{
	float[2][LEADWALL_MAX_BOLTS] boltOffsets = [
		[0.2, 0.8], // right
		[0.2, -0.8], // left
		[-0.2, 0.65],
		[-0.2, -0.65],
		[0.2, 0.2],
		[0.2, -0.2],
		[-0.2, 0.2],
		[-0.2, -0.2]
	]

	int maxAmmo
	float ammoRegenTime
} file

var function OnWeaponPrimaryAttack_titanweapon_leadwall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireWeaponPlayerAndNPC( attackParams, true, weapon )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_leadwall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireWeaponPlayerAndNPC( attackParams, false, weapon )
}
#endif // #if SERVER

function FireWeaponPlayerAndNPC( WeaponPrimaryAttackParams attackParams, bool playerFired, entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	vector attackAngles = VectorToAngles( attackParams.dir )
	vector baseUpVec = AnglesToUp( attackAngles )
	vector baseRightVec = AnglesToRight( attackAngles )

	if ( shouldCreateProjectile )
	{
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
		int numProjectiles = weapon.GetProjectilesPerShot()
		float adsMultiplier
		if ( owner.IsPlayer() )
			adsMultiplier = GraphCapped( owner.GetZoomFrac(), 0, 1, 1.0, 0.5 )
		else
			adsMultiplier = 1.0

		bool perfectRicochet = PerfectKits_Enabled() && weapon.HasMod( "PerfectKitsReplace_pas_ronin_weapon" )
		float spreadFrac = LTSRebalance_Enabled() ? LTSREBALANCE_SPREAD_FRAC : 0.05
		for ( int index = 0; index < numProjectiles; index++ )
		{
			vector upVec = baseUpVec * file.boltOffsets[index][0] * spreadFrac * RandomFloatRange( 1.2, 1.7 ) * adsMultiplier
			vector rightVec = baseRightVec * file.boltOffsets[index][1] * spreadFrac * RandomFloatRange( 1.2, 1.7 ) * adsMultiplier

			vector attackDir = attackParams.dir + upVec + rightVec
			float projectileSpeed = LTSRebalance_Enabled() ? LTSREBALANCE_LEADWALL_VELOCITY : 4400.0

			if ( weapon.GetWeaponClassName() == "mp_weapon_shotgun_doublebarrel" )
				{
					attackDir = attackParams.dir
					projectileSpeed = 3800
				}

			entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackDir, projectileSpeed, damageTypes.largeCaliber | DF_SHOTGUN, damageTypes.largeCaliber | DF_SHOTGUN, playerFired, index )
			if ( bolt )
			{
				bolt.kv.gravity = 0.4 // 0.09

				if ( weapon.GetWeaponClassName() == "mp_weapon_shotgun_doublebarrel" )
					bolt.SetProjectileLifetime( RandomFloatRange( 1.0, 1.3 ) )
				else if ( perfectRicochet )
				{
					bolt.SetProjectileLifetime( 30.0 )
					#if SERVER
					thread PerfectKits_RicochetLeadwallThink( bolt )
					#endif
				}
				else
				    bolt.SetProjectileLifetime( RandomFloatRange( LEADWALL_LIFETIME_MIN, LEADWALL_LIFETIME_MAX ) ) 

				// Need to store some info of leadwall shots so they properly target their offset when bouncing toward a target
				#if SERVER
				if ( LTSRebalance_Enabled() && weapon.HasMod( "LTSRebalance_pas_ronin_weapon" ) )
				{
					bolt.s.index <- index
					bolt.s.adsMultiplier <- adsMultiplier
				}
				#endif

				EmitSoundOnEntity( bolt, "wpn_leadwall_projectile_crackle" )
			}
		}
	}

	return 1
}

#if SERVER
void function PerfectKits_RicochetLeadwallThink( entity projectile )
{
	projectile.EndSignal( "OnDestroy" )
	float speed = Length( projectile.GetVelocity() )
	var group = projectile.kv.CollisionGroup
	wait RandomFloatRange(LEADWALL_LIFETIME_MIN, LEADWALL_LIFETIME_MAX)
	if ( projectile.IsSolid() )
	{
		projectile.kv.CollisionGroup = TRACE_COLLISION_GROUP_NONE
		projectile.SetVelocity( projectile.GetVelocity() * .03 )
		projectile.NotSolid()
		projectile.s.hasBoomeranged <- true
	}
	wait 3.0
	projectile.kv.CollisionGroup = group
	projectile.Solid()
	float accelSpeed = speed * -.07
	float endTime = Time() + 3
	while( endTime > Time() )
	{
		vector curVel = projectile.GetVelocity()
		projectile.SetVelocity( projectile.GetVelocity() + Normalize( projectile.GetVelocity() ) * accelSpeed )
		if ( curVel.Dot( projectile.GetVelocity() ) < 0 )
			accelSpeed *= -1

		WaitFrame()
	}

	projectile.Destroy()
}
#endif

void function OnProjectileCollision_titanweapon_leadwall( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{

	#if SERVER
		int bounceCount = projectile.GetProjectileWeaponSettingInt( eWeaponVar.projectile_ricochet_max_count )

		if ( projectile.proj.projectileBounceCount >= bounceCount )
			return

		projectile.proj.projectileBounceCount++

		if ( hitEnt != svGlobal.worldspawn )
			return

		EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "Bullets.DefaultNearmiss" )

		// We only want to run the following stuff on first bounce
		if ( projectile.proj.projectileBounceCount > 2 )
		{
			// HACK - using bounce count to check whether we are in the middle of homing delay
			if ( projectile.proj.projectileBounceCount < 100 )
				projectile.Destroy()
			return
		}

		if ( PerfectKits_Enabled() )
		{
			if ( !( "hasBoomeranged" in projectile.s ) )
			{
				projectile.kv.CollisionGroup = TRACE_COLLISION_GROUP_NONE
				projectile.SetVelocity( projectile.GetVelocity() * .03 )
				projectile.NotSolid()
				projectile.s.hasBoomeranged <- true
			}
		}
		else if ( LTSRebalance_Enabled() )
		{
			projectile.SetProjectileLifetime( LEADWALL_LIFETIME_MAX )
			LTSRebalance_RicochetSeek( projectile, normal )
		}
	#endif
}

#if SERVER
void function LTSRebalance_RicochetSeek( entity projectile, vector normal )
{
	vector projectilePos = projectile.GetOrigin()
	vector ricochetDir = Normalize( projectile.GetVelocity() - 2 * ( projectile.GetVelocity().Dot( normal ) ) * normal )

	array<entity> enemyTitans = GetNPCArrayEx( "npc_titan", TEAM_ANY, projectile.GetTeam(), projectilePos, LTSREBALANCE_RICOCHET_SEEK_RANGE_MAX )
	array<entity> enemyPlayers = GetPlayerArrayOfEnemies_Alive( projectile.GetTeam() )
	
	float minDistSqr = LTSREBALANCE_RICOCHET_SEEK_RANGE_MAX * LTSREBALANCE_RICOCHET_SEEK_RANGE_MAX
	entity minEnt = null

	foreach ( player in enemyPlayers )
		if ( player.IsTitan() )
			enemyTitans.append( player )

	foreach ( titan in enemyTitans )
	{
		float distSqr = DistanceSqr( titan.GetWorldSpaceCenter(), projectilePos ) 
		if ( distSqr >= minDistSqr )
			continue

		float dist = sqrt( distSqr )
		float minDot = GraphCapped( dist, LTSREBALANCE_RICOCHET_SEEK_RANGE_MIN, LTSREBALANCE_RICOCHET_SEEK_RANGE_MAX, LTSREBALANCE_RICOCHET_SEEK_DOT_MIN, LTSREBALANCE_RICOCHET_SEEK_DOT_MAX )
		float dot = ricochetDir.Dot( Normalize( titan.GetWorldSpaceCenter() - projectilePos ) )

		if ( dot < minDot )
			continue

		TraceResults hitResult = TraceLine( projectilePos, titan.GetWorldSpaceCenter(), [ projectile ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_BLOCK_WEAPONS )
		if ( hitResult.hitEnt == null )
		{
			minDistSqr = distSqr
			minEnt = titan
		}
	}

	if ( minEnt != null )
	{
		projectile.SetProjectileLifetime( 0.3 ) // Some duration of time so it doesn't die before tracking the target
		thread LTSRebalance_SetRicochetVelocity( projectile, minEnt )
	}
}

void function LTSRebalance_SetRicochetVelocity( entity projectile, entity ent )
{
	float bounceTime = Time()
	float oldDist = Distance( projectile.GetOrigin(), ent.GetWorldSpaceCenter() )
	projectile.proj.projectileBounceCount = 100 // An arbitrarily high value tied to a check on collision, basically just gives infinite ricochet until it homes
	WaitEndFrame()
	
	if ( !IsValid( projectile ) )
		return
	
	projectile.proj.projectileBounceCount = 3 // An arbitrary value between 2 and 100. Basically marks the projectile as no longer ricochet-able
	if ( !IsValid( ent ) )
	{
		return
	}

	float dist = Distance( projectile.GetOrigin(), ent.GetWorldSpaceCenter() )
	vector dir = Normalize( ent.GetWorldSpaceCenter() - projectile.GetOrigin() )

	vector angle = VectorToAngles( dir )
	vector baseUpVec = AnglesToUp( angle )
	vector baseRightVec = AnglesToRight( angle )

	// Preserved values from when the shot is fired to match the box spread pattern and ads spread reduction.
	int index = expect int( projectile.s.index )
	float adsMult = expect float( projectile.s.adsMultiplier )

	// Additional thingy to make the spread bigger or smaller to compensate for delay between hitting the environment and seeking the target
	float distMod = min( LTSREBALANCE_RICOCHET_MAX_COMPENSATE, oldDist / dist )

	vector upVec = baseUpVec * file.boltOffsets[index][0] * LTSREBALANCE_SPREAD_FRAC * RandomFloatRange( 1.2, 1.7 ) * adsMult
	vector rightVec = baseRightVec * file.boltOffsets[index][1] * LTSREBALANCE_SPREAD_FRAC * RandomFloatRange( 1.2, 1.7 ) * adsMult

	dir += ( upVec + rightVec ) * LTSREBALANCE_RICOCHET_SPREAD_MOD * distMod
	projectile.SetVelocity( dir * LTSREBALANCE_LEADWALL_VELOCITY )
}
#endif