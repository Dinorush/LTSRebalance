untyped

global function MpTitanabilityBubbleShield_Init

global function OnWeaponPrimaryAttack_particle_wall

#if SERVER
global function OnWeaponNpcPrimaryAttack_particle_wall
#endif // #if SERVER

global const SP_PARTICLE_WALL_DURATION = 8.0
global const MP_PARTICLE_WALL_DURATION = 6.0
global const LTSREBALANCE_MP_PARTICLE_WALL_DURATION = 4.0
const LTSREBALANCE_PAS_TONE_WALL_REFUND_SCALAR = 1.5

function MpTitanabilityBubbleShield_Init()
{
	RegisterSignal( "RegenAmmo" )

    #if CLIENT
	    PrecacheHUDMaterial( $"vgui/hud/dpad_bubble_shield_charge_0" )
	    PrecacheHUDMaterial( $"vgui/hud/dpad_bubble_shield_charge_1" )
	    PrecacheHUDMaterial( $"vgui/hud/dpad_bubble_shield_charge_2" )
    #endif
}

var function OnWeaponPrimaryAttack_particle_wall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

#if SERVER
	float duration
	if ( IsSingleplayer() )
		duration = SP_PARTICLE_WALL_DURATION
	else if ( LTSRebalance_Enabled() )
		duration = LTSREBALANCE_MP_PARTICLE_WALL_DURATION
	else
		duration = MP_PARTICLE_WALL_DURATION

	entity particleWall = CreateParticleWallFromOwner( weapon.GetWeaponOwner(), duration, attackParams )
    entity soul = weaponOwner.GetTitanSoul()

    if ( LTSRebalance_Enabled() && IsValid( particleWall ) && IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_TONE_WALL ) )
        thread PasToneWallWatchForEnd( weapon, particleWall )
#endif
	return weapon.GetWeaponInfoFileKeyField( "ammo_per_shot" )
}

#if SERVER

void function PasToneWallWatchForEnd( entity weapon, entity particleWall )
{
    particleWall.EndSignal( "OnDestroy" )
	weapon.EndSignal( "OnDestroy" )
    float startTime = Time()
    OnThreadEnd(
    function() : ( weapon, startTime )
        {
			if ( !IsValid( weapon ) )
				return

            float lostTime = startTime + MP_PARTICLE_WALL_DURATION - Time()
            if ( lostTime < 0.1 )
                return

            // Wall broken early
            float regenRate = weapon.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_rate )
			lostTime *= LTSREBALANCE_PAS_TONE_WALL_REFUND_SCALAR
            int newAmmo = minint( weapon.GetWeaponPrimaryClipCountMax(), weapon.GetWeaponPrimaryClipCount() + int( regenRate * lostTime ) )
            weapon.SetWeaponPrimaryClipCount( newAmmo )
        }
    )

    wait MP_PARTICLE_WALL_DURATION + 0.1
}

var function OnWeaponNpcPrimaryAttack_particle_wall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	float duration
	if ( IsSingleplayer() )
		duration = SP_PARTICLE_WALL_DURATION
	else
		duration = MP_PARTICLE_WALL_DURATION
	entity particleWall = CreateParticleWallFromOwner( weapon.GetWeaponOwner(), duration, attackParams )
	return weapon.GetWeaponInfoFileKeyField( "ammo_per_shot" )
}
#endif // #if SERVER