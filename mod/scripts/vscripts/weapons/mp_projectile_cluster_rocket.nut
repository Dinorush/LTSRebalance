
global function OnProjectileCollision_ClusterRocket

void function OnProjectileCollision_ClusterRocket( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = projectile.ProjectileGetMods()
    bool enhanced = mods.contains( "pas_northstar_cluster" )
	float duration = enhanced ? 7.5 : CLUSTER_ROCKET_DURATION
    float range = CLUSTER_ROCKET_BURST_RANGE * (enhanced ? 1.25 : 1.0)

	#if SERVER
		float explosionDelay = expect float( projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_explosion_delay" ) )

		ClusterRocket_Detonate( projectile, normal )
		CreateNoSpawnArea( TEAM_INVALID, TEAM_INVALID, pos, duration + explosionDelay, range + 300 )
	#endif
}

