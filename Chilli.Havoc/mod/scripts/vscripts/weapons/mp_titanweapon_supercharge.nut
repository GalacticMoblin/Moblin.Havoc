global function MpTitanweaponSuperCharge_Init

global function OnWeaponPrimaryAttack_ability_supercharge
global function OnWeaponActivate_titanability_supercharge
global function OnWeaponDeactivate_titanability_supercharge

struct
{
	float earn_meter_titan_multiplier = 1.0
} file

const float TITAN_BLOCK_DAMAGE_REDUCTION = 0.5
const float SWORD_CORE_BLOCK_DAMAGE_REDUCTION = 0.15

void function MpTitanweaponSuperCharge_Init()
{
  PrecacheWeapon("mp_titanweapon_supercharge")
  #if SERVER
	AddDamageFinalCallback( "player", BasicBlock_OnDamage )
	AddDamageFinalCallback( "npc_titan", BasicBlock_OnDamage )
#endif
}

const int TITAN_BLOCK = 1
const int PILOT_BLOCK = 2

void function OnWeaponActivate_titanability_supercharge( entity weapon )
{
  #if SERVER
  	entity weaponOwner = weapon.GetWeaponOwner()
  	weaponOwner.e.blockActive = true
    wait 12
    weaponOwner.e.blockActive = false
  #endif
}
void function OnWeaponDeactivate_titanability_supercharge( entity weapon )
{
  #if SERVER
  	entity weaponOwner = weapon.GetWeaponOwner()
  	weaponOwner.e.blockActive = false
  #endif
}

void function OnActivate( entity weapon, int blockType )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )
	StartShield( weapon )
	entity offhandWeapon = weaponOwner.GetOffhandWeapon( OFFHAND_MELEE )
	if ( IsValid( offhandWeapon ) && offhandWeapon.HasMod( "super_charged" ) )
		thread BlockSwordCoreFXThink( weapon, weaponOwner )
}

void function OnDeactivate( entity weapon, int blockType )
{
	EndShield( weapon )

	asset first_fx
	asset third_fx

	if ( weapon.HasMod( "modelset_prime" ) )
	{
		first_fx = SWORD_GLOW_PRIME_FP
		third_fx = SWORD_GLOW_PRIME
	}
	else
	{
		first_fx = SWORD_GLOW_FP
		third_fx = SWORD_GLOW
	}

	weapon.StopWeaponEffect( first_fx, third_fx )
}

void function EndShield( entity weapon )
{
#if SERVER
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.e.blockActive = false
#endif
}

void function StartShield( entity weapon )
{
#if SERVER
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.e.blockActive = true
#endif
}

void function BlockSwordCoreFXThink( entity weapon, entity weaponOwner )
{
	weapon.EndSignal( "WeaponDeactivateEvent" )
	weapon.EndSignal( "OnDestroy" )

	asset first_fx
	asset third_fx

	if ( weapon.HasMod( "modelset_prime" ) )
	{
		first_fx = SWORD_GLOW_PRIME_FP
		third_fx = SWORD_GLOW_PRIME
	}
	else
	{
		first_fx = SWORD_GLOW_FP
		third_fx = SWORD_GLOW
	}

	OnThreadEnd(
	function() : ( weapon, first_fx, third_fx )
		{
			if ( IsValid( weapon ) )
				weapon.StopWeaponEffect( first_fx, third_fx )
		}
	)

	weapon.PlayWeaponEffectNoCull( first_fx, third_fx, "sword_edge" )

#if SERVER
	weaponOwner.WaitSignal( "CoreEnd" )
#endif

#if CLIENT
	entity offhandWeapon = weaponOwner.GetOffhandWeapon( OFFHAND_MELEE )
	while ( IsValid( offhandWeapon ) && offhandWeapon.HasMod("super_charged" ) )
		WaitFrame()
#endif
}

var function OnWeaponPrimaryAttack_ability_supercharge( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity ownerPlayer = weapon.GetWeaponOwner()
	Assert( IsValid( ownerPlayer) && ownerPlayer.IsPlayer() )
	if ( IsValid( ownerPlayer ) && ownerPlayer.IsPlayer() )
	{
		if ( ownerPlayer.GetCinematicEventFlags() & CE_FLAG_CLASSIC_MP_SPAWNING )
			return false

		if ( ownerPlayer.GetCinematicEventFlags() & CE_FLAG_INTRO )
			return false
	}

	float duration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
	StimPlayer( ownerPlayer, duration )

	PlayerUsedOffhand( ownerPlayer, weapon )

#if SERVER
#if BATTLECHATTER_ENABLED
	TryPlayWeaponBattleChatterLine( ownerPlayer, weapon )
#endif //
#else //
	Rumble_Play( "rumble_stim_activate", {} )
#endif //

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )

  //wait duration
  //EndShield( weapon )
}


//TriggerBlockVisualEffect( blockingEnt, originalDamage, damageScale )

#if SERVER
float function HandleBlockingAndCalcDamageScaleForHit( entity blockingEnt, var damageInfo )
{
	if ( blockingEnt.IsTitan() )
	{
		bool shouldPassThroughDamage = (( DamageInfo_GetCustomDamageType( damageInfo ) & (DF_RODEO | DF_MELEE | DF_DOOMED_HEALTH_LOSS) ) > 0)
		if ( shouldPassThroughDamage )
			return 1.0

		if ( blockingEnt.IsPlayer() && PlayerHasPassive( blockingEnt, ePassives.PAS_SHIFT_CORE ) )
			return SWORD_CORE_BLOCK_DAMAGE_REDUCTION

		return TITAN_BLOCK_DAMAGE_REDUCTION
	}

	entity weapon = blockingEnt.GetActiveWeapon()
	if ( !IsValid( weapon ) )
	{
		printt( "swordblock: no valid activeweapon" )
		return 1.0
	}

	int damageType = DamageInfo_GetCustomDamageType( damageInfo )
	if ( damageType & DF_RADIUS_DAMAGE )
	{
		printt( "swordblock: not blocking radius damage" )
		return 1.0
	}

	int originalDamage = int( DamageInfo_GetDamage( damageInfo ) + 0.5 )
	int originalAmmo = weapon.GetWeaponPrimaryAmmoCount()

	int ammoCost = 0
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) && attacker.IsTitan() && (damageType & DF_MELEE) )
		ammoCost = 40	// auto-titan ground-pounds do 2x damage events right now
	else if ( damageType & DF_MELEE )
		ammoCost = 25
	else if ( originalDamage <= 10 )
		ammoCost = 1
	else if ( originalDamage <= 30 )
		ammoCost = 3
	else if ( originalDamage <= 50 )
		ammoCost = 5
	else if ( originalDamage <= 70 )
		ammoCost = 10
	else if ( originalDamage <= 100 )
		ammoCost = 15
	else if ( originalDamage <= 200 )
		ammoCost = 30
	else if ( originalDamage <= 500 )
		ammoCost = 50
	else
		ammoCost = 100


	int newAmmoTotalRaw = (originalAmmo - ammoCost)
	int newAmmoTotal
	float resultDamageScale
	if ( newAmmoTotalRaw >= 0 )
	{
		newAmmoTotal = newAmmoTotalRaw
		resultDamageScale = 0.0
	}
	else
	{
		newAmmoTotal = 0
		resultDamageScale = (float( -newAmmoTotalRaw ) / float( ammoCost ))
	}

	printt( "swordblock: finalDamageScale(" + resultDamageScale + "), ammoTotal(" + newAmmoTotal + ") - originalDamage(" + originalDamage + "), has cost(" + ammoCost + "), of remaining(" + originalAmmo + "), attacker '" + attacker + "', " + GetDescStringForDamageFlags( damageType ) )

	weapon.SetWeaponPrimaryAmmoCount( newAmmoTotal )
	weapon.RegenerateAmmoReset()
	return resultDamageScale
}

void function BasicBlock_OnDamage( entity blockingEnt, var damageInfo )
{
	if ( !blockingEnt.e.blockActive )
		return

	float damageScale = HandleBlockingAndCalcDamageScaleForHit( blockingEnt, damageInfo )
	if ( damageScale == 1.0 )
		return

	entity weapon = blockingEnt.GetOffhandWeapon( OFFHAND_LEFT )
	if ( blockingEnt.IsPlayer() && weapon.HasMod( "fd_sword_block" ) )
	{
		float meterReward = DamageInfo_GetDamage( damageInfo ) * (1.0 - damageScale) * CORE_BUILD_PERCENT_FROM_TITAN_DAMAGE_INFLICTED * 0.015 * file.earn_meter_titan_multiplier
		PlayerEarnMeter_AddEarnedAndOwned( blockingEnt, 0.0, meterReward )
	}

	entity attacker = DamageInfo_GetAttacker( damageInfo )

	int attachId = blockingEnt.LookupAttachment( "PROPGUN" )
	vector origin = GetDamageOrigin( damageInfo, blockingEnt )
	vector eyePos = blockingEnt.GetAttachmentOrigin( attachId )
	vector blockAngles = blockingEnt.GetAttachmentAngles( attachId )
	vector fwd = AnglesToForward( blockAngles )

	vector vec1 = Normalize( origin - eyePos )
	float dot = DotProduct( vec1, fwd )
	float angleRange = GetAngleForBlock( blockingEnt )
	float minDot = AngleToDot( angleRange )
	if ( dot < minDot )
		return

	EmitSoundOnEntity( blockingEnt, "ronin_sword_bullet_impacts" )
	if ( blockingEnt.IsPlayer() )
	{
		int originalDamage = int( DamageInfo_GetDamage( damageInfo ) + 0.5 )
		//TriggerBlockVisualEffect( blockingEnt, originalDamage, damageScale )
		blockingEnt.RumbleEffect( 1, 0, 0 )
	}

	StartParticleEffectInWorldWithControlPoint( GetParticleSystemIndex( $"P_impact_xo_sword" ), DamageInfo_GetDamagePosition( damageInfo ) + vec1*200, VectorToAngles( vec1 ) + <90,0,0>, <255,255,255> )

	DamageInfo_ScaleDamage( damageInfo, damageScale )

	// ideally this would be DF_INEFFECTIVE, but we are out of damage flags
	DamageInfo_AddCustomDamageType( damageInfo, DF_NO_INDICATOR )
	DamageInfo_RemoveCustomDamageType( damageInfo, DF_DOOM_FATALITY )
}

const float TITAN_BLOCK_ANGLE = 150
const float PILOT_BLOCK_ANGLE = 150
float function GetAngleForBlock( entity blockingEnt )
{
	if ( blockingEnt.IsTitan() )
		return TITAN_BLOCK_ANGLE
	return PILOT_BLOCK_ANGLE
}
#endif
