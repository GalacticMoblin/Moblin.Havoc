global function MpTitanabilitySuperCharge_Init

global function OnWeaponPrimaryAttack_titanability_supercharge

const float SUPER_CHARGE_DAMAGE_REDUCTION = 0.5

void function MpTitanabilitySuperCharge_Init()
{
  PrecacheWeapon("mp_titanability_supercharge")
  #if SERVER
	AddDamageFinalCallback( "player", SuperCharge_DamageReduction )
	AddDamageFinalCallback( "npc_titan", SuperCharge_DamageReduction )
#endif
}

var function OnWeaponPrimaryAttack_titanability_supercharge( entity weapon, WeaponPrimaryAttackParams attackParams )
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
	if ( ownerPlayer.IsTitan() && IsValid ( ownerPlayer.GetTitanSoul() ) )
	{
		table soulDotS = expect table( ownerPlayer.GetTitanSoul().s )
		soulDotS.havocSuperChargeEnd <- Time() + duration
	}
#if BATTLECHATTER_ENABLED
	TryPlayWeaponBattleChatterLine( ownerPlayer, weapon )
#endif //
#else //
	Rumble_Play( "rumble_stim_activate", {} )
#endif //

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}


//TriggerBlockVisualEffect( blockingEnt, originalDamage, damageScale )

#if SERVER
void function SuperCharge_DamageReduction( entity titan, var damageInfo )
{
	if ( !titan.IsTitan() )
		return

	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return
		
	table soulDotS = expect table( soul.s )
	if ( "havocSuperChargeEnd" in soulDotS && soulDotS.havocSuperChargeEnd >= Time() )
		DamageInfo_ScaleDamage( damageInfo, 1.0 - SUPER_CHARGE_DAMAGE_REDUCTION )
}
#endif
