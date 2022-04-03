untyped
global function MpTitanWeaponSmokeBomb_Init
global function OnWeaponPrimaryAttack_titanweapon_smoke_bomb
global function OnProjectileCollision_titanweapon_smoke_bomb
global function OnWeaponAttemptOffhandSwitch_titanweapon_smoke_bomb

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_smoke_bomb
#endif // #if SERVER

const FUSE_TIME = 0.5
const FUSE_TIME_EXT = 0.75 //Applies if the grenade hits an entity
const FUSE_OFFSET = 0.0

global const FX_ELECTRIC_SMOKESCREEN2 = $"P_wpn_smk_electric_pilot"
global const FX_ELECTRIC_SMOKESCREEN_AIR2 = $"P_wpn_smk_electric_pilot_air"

void function MpTitanWeaponSmokeBomb_Init()
{
	PrecacheParticleSystem( FX_ELECTRIC_SMOKESCREEN2 )
	PrecacheParticleSystem( FX_ELECTRIC_SMOKESCREEN_AIR2 )
  PrecacheWeapon("mp_titanweapon_smoke_bomb")
  #if SERVER
    AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_smoke_bomb, SmokeBomb_DamagedTarget )
  #endif
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_smoke_bomb( entity weapon )
{
	int minAmmo = weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
	int currAmmo = weapon.GetWeaponPrimaryClipCount()
	if ( currAmmo < minAmmo )
		return false

	return true
}

var function OnWeaponPrimaryAttack_titanweapon_smoke_bomb( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetWeaponOwner()

	#if CLIENT
		return weapon.GetAmmoPerShot()
	#endif

	int ammoToSpend = weapon.GetAmmoPerShot()

	if ( player.IsPlayer() )
		PlayerUsedOffhand( player, weapon )

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	//vector bulletVec = ApplyVectorSpread( attackParams.dir, player.GetAttackSpreadAngle() * 2.0 )
	//attackParams.dir = bulletVec

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
	{
		// vector offset = Vector( 30.0, 6.0, -4.0 )
		// if ( weapon.IsWeaponInAds() )
		// 	offset = Vector( 30.0, 0.0, -3.0 )
		// vector attackPos = player.OffsetPositionFromView( attackParams[ "pos" ], offset )	// forward, right, up
		int numProjectiles = weapon.GetProjectilesPerShot()
		for (int i = 0; i < numProjectiles; i++) {
			FireGrenade( weapon, attackParams )
		}
	}
	return ammoToSpend
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_smoke_bomb( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_titanweapon_smoke_bomb(  weapon, attackParams )
//	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
//	FireGrenade( weapon, attackParams, true )
}
#endif // #if SERVER

function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, isNPCFiring = false )
{
	vector angularVelocity = Vector( RandomFloatRange( -100, 100 ), 100, 0 )

	int damageType = DF_RAGDOLL | DF_EXPLOSION

	entity weaponOwner = weapon.GetWeaponOwner()
	vector bulletVec = ApplyVectorSpread( attackParams.dir, (weaponOwner.GetAttackSpreadAngle() - 1.0) * 2 )

	#if SERVER
	if (IsNPCTitan( weaponOwner ))
	{
		entity nade = weapon.FireWeaponGrenade( attackParams.pos, bulletVec, angularVelocity, 0.0 , damageType, damageType, false, true, false )

		if ( nade )
		{
			#if SERVER
				EmitSoundOnEntity( nade, "Weapon_softball_Grenade_Emitter" )
				Grenade_Init( nade, weapon )
			#else
				SetTeam( nade, weaponOwner.GetTeam() )
			#endif
		}
	}
	else
	{
		entity nade = weapon.FireWeaponGrenade( attackParams.pos, bulletVec, angularVelocity, 0.0 , damageType, damageType, true, true, false )

		if ( nade )
		{
			#if SERVER
				EmitSoundOnEntity( nade, "Weapon_softball_Grenade_Emitter" )
				Grenade_Init( nade, weapon )
			#else
				SetTeam( nade, weaponOwner.GetTeam() )
			#endif
		}
	}
	#endif
}

void function OnProjectileCollision_titanweapon_smoke_bomb( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
//	bool didStick = PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
//	if ( !didStick )
//		return


	#if SERVER
// 		if ( hitEnt.IsTitan() )
// 		{
// //			PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
// //			thread DetonateStickyAfterTime( projectile, FUSE_TIME, normal )
// 		}

	if ( projectile.proj.projectileBounceCount > 0 )
		return

	projectile.proj.projectileBounceCount++

	EmitSoundOnEntity( projectile, "weapon_softball_grenade_attached_3P" )

	// if ( IsAlive( hitEnt ) )
	// {
	//     PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
	//     EmitSoundOnEntityOnlyToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_1P" )
	//     EmitSoundOnEntityExceptToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_3P" )
	//     thread DetonateStickyAfterTime( projectile, FUSE_TIME, normal )
	//     thread DetonateStickyAfterTime( projectile, FUSE_TIME_EXT + RandomFloatRange(-FUSE_OFFSET, FUSE_OFFSET), normal )
	// }
	// else
		thread SmokeBombSmokescreen( projectile, FX_ELECTRIC_SMOKESCREEN )
    projectile.Destroy()

	#endif
}

#if SERVER
// need this so grenade can use the normal to explode
void function DetonateStickyAfterTime( entity projectile, float delay, vector normal )
{
	wait delay
	if ( IsValid( projectile ) )
		projectile.GrenadeExplode( normal )
}
#endif


#if SERVER
void function SmokeBombSmokescreen( entity projectile, asset fx )
{
	entity owner = projectile.GetThrower()

  if ( !IsValid( owner ) )
		return

	RadiusDamageData radiusDamageData = GetRadiusDamageDataFromProjectile( projectile, owner )

	SmokescreenStruct smokescreen
	smokescreen.smokescreenFX = fx
	smokescreen.lifetime = 12.0
	smokescreen.ownerTeam = owner.GetTeam()
	smokescreen.damageSource = eDamageSourceId.mp_titanweapon_smoke_bomb
  smokescreen.deploySound1p = "explo_electric_smoke_impact"
	smokescreen.deploySound3p = "explo_electric_smoke_impact"
	smokescreen.attacker = owner
	smokescreen.inflictor = owner
	smokescreen.weaponOrProjectile = projectile
	smokescreen.damageInnerRadius = 50
	smokescreen.damageOuterRadius = 210
	//smokescreen.dangerousAreaRadius = smokescreen.damageOuterRadius * 1.5
	smokescreen.damageDelay = 1.0
	smokescreen.dpsPilot = 150
	smokescreen.dpsTitan = 800

	smokescreen.origin = projectile.GetOrigin()
	smokescreen.angles = projectile.GetAngles()
	smokescreen.fxUseWeaponOrProjectileAngles = true

  float fxOffset = 200.0
	float fxHeightOffset = 148.0

  smokescreen.fxOffsets = [ < -fxOffset, 0.0, 20.0>,
							  <0.0, fxOffset, 20.0>,
							  <0.0, -fxOffset, 20.0>,
							  <0.0, 0.0, fxHeightOffset>,
							  < -fxOffset, 0.0, fxHeightOffset> ]

	Smokescreen( smokescreen )
}
#endif

#if SERVER
void function SmokeBomb_DamagedTarget( entity target, var damageInfo )
{
    entity attacker = DamageInfo_GetAttacker( damageInfo )

    if ( attacker == target )
    {
        DamageInfo_SetDamage( damageInfo, 0 )
    }
}
#endif
