untyped

global function GiveHavoc
global function Havoc_Init

global function HavocPrecache




struct {
	var  chassis

}titanchassis

void function Havoc_Init()
{


	//MpTitanAbilityBrute4DomeShield_Init()
	//MpTitanweaponShockShield_Init()
//	MpTitanAbilityArcPylon_Init()
}
void function HavocPrecache()
{
	RegisterWeaponDamageSources(
		{
			mp_titanweapon_havoc_launcher = "Havoc Launcher"
			mp_titanweapon_smoke_bomb = "Smoke Bomb"
		}
	)
	//RegisterNewVortexIgnoreClassname("mp_titancore_stormcore", true)
	PrimeTitanPlusHavoc_Init()
	MpTitanweaponHavocLauncher_Init()
	MpTitanweaponSuperCharge_Init()
	MpTitanWeaponSmokeBomb_Init()
	#if SERVER
		//GameModeRulesRegisterTimerCreditException(eDamageSourceId.mp_titancore_storm_core)
	#endif
}

void function GiveHavoc(int i = 0)
{
	#if SERVER
		entity player = GetPlayerArray()[i]

		if( player.IsTitan() && GetTitanCharacterName( player ) == "ion" )
		{
			array<entity> weapons = player.GetMainWeapons()
			player.TakeWeapon(weapons[0].GetWeaponClassName() )
			player.GiveWeapon("mp_titanweapon_arc_cannon")
			player.SetActiveWeaponByName("mp_titanweapon_arc_cannon")
			player.TakeOffhandWeapon(OFFHAND_SPECIAL)
			player.GiveOffhandWeapon("mp_titanweapon_shock_shield", OFFHAND_SPECIAL)
			player.TakeOffhandWeapon(OFFHAND_ANTIRODEO)
			player.GiveOffhandWeapon("mp_titanweapon_tesla_node", OFFHAND_ANTIRODEO)
			player.TakeOffhandWeapon(OFFHAND_RIGHT)
			player.GiveOffhandWeapon("mp_titanweapon_charge_ball", OFFHAND_RIGHT)
			player.TakeOffhandWeapon(OFFHAND_EQUIPMENT)
			player.GiveOffhandWeapon("mp_titancore_storm_core", OFFHAND_EQUIPMENT)
		}
	#endif
}
