untyped

global function OnWeaponPrimaryAttack_titanweapon_leadwall
global function OnProjectileCollision_titanweapon_leadwall

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_leadwall
#endif // #if SERVER

const LEADWALL_MAX_BOLTS = 8 // this is the code limit for bolts per frame... do not increase.

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
		[-0.2, -0.2],

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
		float spreadFrac = LTSRebalance_Enabled() ? 0.043 : 0.05
		for ( int index = 0; index < numProjectiles; index++ )
		{
			vector upVec = baseUpVec * file.boltOffsets[index][0] * spreadFrac * RandomFloatRange( 1.2, 1.7 ) * adsMultiplier
			vector rightVec = baseRightVec * file.boltOffsets[index][1] * spreadFrac * RandomFloatRange( 1.2, 1.7 ) * adsMultiplier

			vector attackDir = attackParams.dir + upVec + rightVec
			float projectileSpeed = LTSRebalance_Enabled() ? 5280.0 : 4400.0

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
				    bolt.SetProjectileLifetime( RandomFloatRange( 0.30, 0.35 ) ) 

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
	wait RandomFloatRange(0.3, 0.35)
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

		if ( hitEnt == svGlobal.worldspawn )
			EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "Bullets.DefaultNearmiss" )
		
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
        	projectile.SetProjectileLifetime( RandomFloatRange( 0.30, 0.35 ) )
		projectile.proj.projectileBounceCount++
	#endif
}