//	------------------------------------------------------------------------------------
//	Filename:		donator.deathperks.sp
//	Author:			Malachi
//	Version:		(see PLUGIN_VERSION)
//	Description:
//					Plugin spawns various options when donator dies during afterround.
//
// * Changelog (date/version/description):
// * 2013-07-24	-	0.1.1		-	initial test version
// * 2013-07-25	-	0.1.2		-	add pumpkin spawn
// * 2013-07-25	-	0.1.3		-	find ground to spawn pumpkin on
// * 2013-07-26	-	0.1.4		-	add ball item
// * 2013-07-26	-	0.1.5		-	add exploding oildrum item, add missing donator check, change Prop_Data to Prop_Send
// * 							-	the event_player_death function is getting kinda ugly - mark for cleanup?
// * 2013-07-27	-	0.1.6		-	add frog
// * 2013-07-27	-	0.1.7		-	make frog explosive, fix ignored offset heights
// * 2013-07-27	-	0.1.8		-	add frog lightning, fix explosion keyvalues
// * 2013-07-27	-	0.1.9		-	add timer to deal with explosion causing multple death events
// * 2013-07-27	-	0.1.10		-	adjust explosion/lightning values
// * 2013-08-09	-	0.1.11		-	unused
// * 2013-08-09	-	0.1.12		-	add ghost - handle remnant particle/glow effects, use array to enable/disable
// * 2013-08-17	-	0.1.13		-	add ball scale, disable ghost until particle/glow is fixed
// * 2013-11-03	-	0.1.14		-	use newly added tfcondition ghost mode, trigger oildrum+pumpkin to explode, disable ball scale
// * 2013-11-05	-	0.2.14		-   Who knows!? type "git log" to find out!!!
//	------------------------------------------------------------------------------------


// INCLUDES
#include <sourcemod>
#include <donator>
#include <clientprefs>
#include <sdktools>
#include <tf2>					// TF2_AddCondition
#include <tf2_stocks>			// TF2_IsPlayerInCondition
#include <sdkhooks>				// SDKHooks_TakeDamage

#pragma semicolon 1


// DEFINES
#define PLUGIN_VERSION	"0.1.14"

// These define the text players see in the donator menu
#define MENUTEXT_SPAWN_ITEM				"After-round Perks"
#define MENUTITLE_SPAWN_ITEM			"Donator: Change After-round Perk:"
#define MENUSELECT_ITEM_NULL			"Disabled"
#define MENUSELECT_ITEM_PUMPKIN			"Pumpkin on Death"
#define MENUSELECT_ITEM_BALL			"Beach Ball on Death"
#define MENUSELECT_ITEM_OILDRUM			"Barrel on Death"
#define MENUSELECT_ITEM_FROG			"Frog on Death"
#define MENUSELECT_ITEM_GHOST			"Ghost Mode"

// cookie names
#define COOKIENAME_SPAWN_ITEM			"donator_deathperks"
#define COOKIEDESCRIPTION_SPAWN_ITEM	"Spawn pumpkin/misc on donator death."

// Entity names
#define ENTITY_NAME_PUMPKIN				"tf_pumpkin_bomb"
#define ENTITY_NAME_BALL				"prop_physics_multiplayer"
#define ENTITY_NAME_OILDRUM				"prop_physics"
#define ENTITY_NAME_FROG				"prop_dynamic"
#define ENTITY_NAME_PROPANETANK			""
#define ENTITY_NAME_EXPLOSION			"env_explosion"
#define ENTITY_NAME_GHOST				""

// Model paths
#define MODEL_PATH_PUMPKIN				"models/props_halloween/pumpkin_explode.mdl"
#define MODEL_PATH_BALL					"models/props_gameplay/ball001.mdl"
#define MODEL_PATH_OILDRUM				"models/props_c17/oildrum001_explosive.mdl"
#define MODEL_PATH_FROG					"models/props_2fort/frog.mdl"
#define MODEL_PATH_PROPANETANK			"models/props_junk/propane_tank001a.mdl"	// HL2 content!
#define MODEL_PATH_GHOST				"models/props_halloween/ghost.mdl"
//#define MODEL_PATH_GHOST				"models/props_halloween/ghost_no_hat.mdl"	// alternate ghost model

// Sprite paths
#define SPRITE_PATH_LIGHTNING			"sprites/lgtning.vmt"

// Vector angles
#define VECTOR_ANGLE_DOWN				{90.0, 0.0, 0.0}							// vector angle pointing straight down
#define VECTOR_ANGLE_PUMPKIN			{0.0, 0.0, 0.0}								// vector angle for pumpkin to spawn at
#define VECTOR_ANGLE_BALL				{0.0, 0.0, 0.0}								// vector angle for beach ball to spawn at
#define VECTOR_ANGLE_OILDRUM			{0.0, 0.0, 0.0}								// vector angle for oil drum to spawn at
#define VECTOR_ANGLE_FROG				{0.0, 0.0, 0.0}								// vector angle for frog to spawn at
#define VECTOR_ANGLE_PROPANETANK		{0.0, 0.0, 0.0}								// vector angle for propane tank to spawn at

// Distances
#define MAX_SPAWN_DISTANCE				1024.0										// max distance to spawn items beneath players

// Z-Axis offset heights
#define OFFSET_HEIGHT_PUMPKIN			10.0										// adjust height of pumpkins off ground
#define OFFSET_HEIGHT_BALL				-20.0										// adjust height of beach balls off ground
#define OFFSET_HEIGHT_OILDRUM			30.0										// adjust height of oildrum off ground
#define OFFSET_HEIGHT_FROG				0.0											// adjust height of propane tank off ground
#define OFFSET_HEIGHT_PROPANETANK		0.0											// adjust height of propane tank off ground

// Masks
#define MASK_PROP_SPAWN					(CONTENTS_SOLID|CONTENTS_WINDOW|CONTENTS_GRATE)		// contents mask to spawn items on

// Explosion parameters
#define EXPLOSIONKEYVALUE_MAGNITUDE			"iMagnitude"							// Key value: Magnitude
#define EXPLOSIONKEYVALUE_SPAWNFLAGS		"spawnflags"							// Key value: flags
#define EXPLOSIONKEYVALUE_RADIUS			"iRadiusOverride"						// Key value: radius
#define EXPLOSION_MAGNITUDE					"500"									// Magnitude
#define EXPLOSION_SPAWNFLAGS				"0"										// flags
#define EXPLOSION_RADIUS					"256"									// radius

// Lightning parameters
#define LIGHTNING_HALOINDEX				0											// Precached model index.
#define LIGHTNING_STARTFRAME			0											// Initital frame to render.
#define LIGHTNING_FRAMERATE				0											// Beam frame rate.
#define LIGHTNING_LIFE					0.75										// Time duration of the beam.
#define LIGHTNING_STARTWIDTH			20.0										// Initial beam width.
#define LIGHTNING_ENDWIDTH				10.0										// Final beam width.
#define LIGHTNING_FADELENGTH			0											// Beam fade time duration.
#define LIGHTNING_AMPLITUDE				1.0											// Beam amplitude.
#define LIGHTNING_COLOR					{255, 255, 255, 255}						// Color array (r, g, b, a).
#define LIGHTNING_SPEED					3											// Speed of the beam.
#define LIGHTNING_SOUND_THUNDER 		"ambient/explosions/explode_9.wav"

// Ball Parameters
#define BALLPARAM_SCALE					2.0											// Scale of ball

// Frog Parameters
#define FROGTIMER_SPAWN_DELAY			0.75										// How soon after player death does frog spawn.

// Drum Parameters
#define DRUMTIMER_EXPLODE_DELAY			1.5											// How soon after player death does drum explode.
#define DRUMTIMER_EXPLODE_DAMAGE		100.0										// Amount of damage to make drum explode.

// Pumpkin Parameters
#define PUMPKINTIMER_EXPLODE_DELAY		1.5											// How soon after player death does drum explode.
#define PUMPKINTIMER_EXPLODE_DAMAGE		100.0										// Amount of damage to make drum explode.

// Ghost Parameters
#define GHOSTPOV_DISABLE			0												// turn off third person pov
#define GHOSTPOV_ENABLE				2												// turn on third person pov
#define TFCONDITION_GHOST			76						// the tf condition # for ghost mode
#define	SOUND_NAME_GHOST_1			"vo/halloween_boo1.wav"
#define	SOUND_NAME_GHOST_2			"vo/halloween_boo2.wav"
#define	SOUND_NAME_GHOST_3			"vo/halloween_boo3.wav"
#define	SOUND_NAME_GHOST_4			"vo/halloween_boo4.wav"
#define	SOUND_NAME_GHOST_5			"vo/halloween_boo5.wav"
#define	SOUND_NAME_GHOST_6			"vo/halloween_boo6.wav"
#define	SOUND_NAME_GHOST_7			"vo/halloween_boo7.wav"


enum _:CookieActionType
{
	Action_Null = 0,
	Action_Pumpkin = 1,
	Action_Ball = 2,
	Action_Oildrum = 3,
	Action_Frog = 4,
	Action_Ghost = 5
//	Action_Grave = 6,
//	Action_Bird = 7,
};

// GLOBALS
new Handle:g_hDeathItemCookie = INVALID_HANDLE;
new bool:g_bRoundEnded = false;
new g_iLightningSprite = 0;
new Handle:g_hFrogTimerHandle[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
new Handle:g_hDrumTimerHandle[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
new Handle:g_hPumpkinTimerHandle[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};


public Plugin:myinfo = 
{
	name = "Donator Death Perks",
	author = "Malachi",
	description = "handles after-round donator perks",
	version = PLUGIN_VERSION,
	url = "www.necrophix.com"
}


public OnPluginStart()
{
	PrintToServer("[Donator:DeathPerks] Plugin start...");

	// Cookie time
	g_hDeathItemCookie = RegClientCookie(COOKIENAME_SPAWN_ITEM, COOKIEDESCRIPTION_SPAWN_ITEM, CookieAccess_Private);

	// Event Hooks
	HookEventEx("teamplay_round_start", Event_StartRound, EventHookMode_PostNoCopy);
	HookEventEx("arena_round_start", Event_StartRound, EventHookMode_PostNoCopy);
	HookEventEx("teamplay_round_win", Event_WinRound, EventHookMode_PostNoCopy);
	HookEventEx("arena_win_panel", Event_WinRound, EventHookMode_PostNoCopy);
	HookEventEx("player_death", Event_PlayerDeath, EventHookMode_Post);
}


// Required: Basic donator interface
public OnAllPluginsLoaded()
{
	if(!LibraryExists("donator.core"))
		SetFailState("[Donator:DeathPerks] Unable to find plugin: Basic Donator Interface");

	if(GetExtensionFileStatus("sdkhooks.ext") < 1)
		SetFailState("[Donator:DeathPerks] SDK Hooks is not loaded.");
		
	Donator_RegisterMenuItem(MENUTEXT_SPAWN_ITEM, ChangeDeathItemCallback);
}


public OnMapStart()
{
	PrecacheModel(MODEL_PATH_OILDRUM, true);
	PrecacheModel(MODEL_PATH_FROG, true);
	PrecacheModel(MODEL_PATH_PUMPKIN, true);
	PrecacheModel(MODEL_PATH_GHOST, true);
	PrecacheSound(SOUND_NAME_GHOST_1, true);
	PrecacheSound(SOUND_NAME_GHOST_2, true);
	PrecacheSound(SOUND_NAME_GHOST_3, true);
	PrecacheSound(SOUND_NAME_GHOST_4, true);
	PrecacheSound(SOUND_NAME_GHOST_5, true);
	PrecacheSound(SOUND_NAME_GHOST_6, true);
	PrecacheSound(SOUND_NAME_GHOST_7, true);
	PrecacheSound(LIGHTNING_SOUND_THUNDER, true);
	g_iLightningSprite = PrecacheModel(SPRITE_PATH_LIGHTNING, true);
}


public DonatorMenu:ChangeDeathItemCallback(client) Panel_ChangeDeathItem(client);


public Event_StartRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	CleanUpTimers();
	g_bRoundEnded = false;
}


public Event_WinRound(Handle:event, const String:name[], bool:dontBroadcast)
{	
	g_bRoundEnded = true;

	// Handle Ghost
	for (new client=1; client <= MaxClients; client++)
	{
        if(!IsDonatorInGame(client))
        {
            continue;
        }
		decl String:iTmp[32];
		new iSelected;

		GetClientCookie(client, g_hDeathItemCookie, iTmp, sizeof(iTmp));
		iSelected = StringToInt(iTmp);

		if (_:iSelected == Action_Ghost)
		{
			// apparently will crash server if you try to set this twice (like on plr_hightower_event)
			if (!TF2_IsPlayerInCondition(client, TFCond:TFCONDITION_GHOST))
			{
				PrintToChat (client, "[DeathPerks] Ghost spawned.");
				TF2_AddCondition(client, TFCond:TFCONDITION_GHOST, 60.0, 0);
			}
			else
			{
				PrintToChat (client, "[DeathPerks] ERROR - Already a ghost.");
			}
		}
	}

}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Round ended check
	if(!g_bRoundEnded)
		return Plugin_Continue;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
		
	// Donator check
	if (!IsPlayerDonator(client)) 
		return Plugin_Continue;
		
	decl String:iTmp[32];
	new iSelected;

	// Get player's choice of item to spawn
	GetClientCookie(client, g_hDeathItemCookie, iTmp, sizeof(iTmp));	
	iSelected = StringToInt(iTmp);

	switch (iSelected)
	{
		case Action_Null:
		{
			PrintToChat (client, "[DeathPerks] Nothing spawned.");
		}
		
		case Action_Pumpkin:
		{
			SpawnPumpkin(client);
		}
		
		case Action_Ball:
		{
			SpawnBeachBall(client);
		}
		
		case Action_Oildrum:
		{
			SpawnOildrum(client);
		}

		case Action_Frog:
		{
			SpawnFrog(client);
		}

		case Action_Ghost:
		{
			//PrintToChat (client, "[DeathPerks] Ghost spawned.");
		}
		
		// If we get here, the cookie hasn't been set properly - so set it!
		// (do we really need this?)
		default:
		{
			new String:iTemp[32];
			IntToString(Action_Null, iTemp, sizeof(iTemp));
			SetClientCookie(client, g_hDeathItemCookie, iTemp);		
			PrintToChat (client, "[DeathPerks] Normalizing cookie - for extra yum!");
		}
		
	}

	return Plugin_Continue;
}

public bool:GetTraceRayDownVectors(client, Float:vOrigin[3], Float:vEnd[3])
{
	decl Handle:trace_ray;
	GetClientEyePosition(client, vOrigin);
	new Float:vDown[3] = VECTOR_ANGLE_DOWN;
	trace_ray = TR_TraceRayFilterEx(vOrigin, vDown, MASK_PROP_SPAWN, RayType_Infinite, TraceRayProp);

	if (!TR_DidHit(trace_ray))
	{
		CloseHandle(trace_ray);
		return false;
	}

	TR_GetEndPosition(vEnd, trace_ray);
	CloseHandle(trace_ray);

	if (GetVectorDistance(vOrigin, vEnd) < MAX_SPAWN_DISTANCE)
	{
		return false;
	}

	return true;
}
public SpawnPumpkin(client)
{
	decl Float:vOrigin[3], Float:vEnd[3];

	if (CanSpawnEntity() && GetTraceRayDownVectors(client, vOrigin, vEnd))
	{
		new iPumpkin = CreateEntityByName(ENTITY_NAME_PUMPKIN);

		if(IsValidEntity(iPumpkin))
		{
			DispatchSpawn(iPumpkin);
			vEnd[2] += OFFSET_HEIGHT_PUMPKIN;

			new Float:ModelAngle[3] = VECTOR_ANGLE_PUMPKIN;
			TeleportEntity(iPumpkin, vEnd, ModelAngle, NULL_VECTOR);

			// explode pumpkin
			new Handle:pack;
			g_hPumpkinTimerHandle[client] = CreateDataTimer(PUMPKINTIMER_EXPLODE_DELAY, CallExplodePumpkin, pack);

			WritePackCell(pack, client);
			WritePackCell(pack, iPumpkin);
		}
	}
}

public SpawnBeachBall(client)
{
	if(CanSpawnEntity())
	{
		new iBall = CreateEntityByName(ENTITY_NAME_BALL);

		if(IsValidEntity(iBall))
		{
			decl Float:vOrigin[3];
			GetClientEyePosition(client, vOrigin);

			vOrigin[2] += OFFSET_HEIGHT_BALL;

			DispatchKeyValue(iBall, "model", MODEL_PATH_BALL);
			DispatchKeyValue(iBall, "disableshadows", "1");
			DispatchKeyValue(iBall, "skin", "0");
			DispatchKeyValue(iBall, "physicsmode", "1");
			DispatchKeyValue(iBall, "spawnflags", "256");
			DispatchSpawn(iBall);

			// Set ball size
			//SetEntPropFloat(iBall, Prop_Send, "m_flModelScale", BALLPARAM_SCALE);

			new Float:ModelAngle[3] = VECTOR_ANGLE_BALL;
			TeleportEntity(iBall, vOrigin, ModelAngle, NULL_VECTOR);

			PrintToChat (client, "[DeathPerks] Ball spawned.");
		}
	}

}

public SpawnOildrum(client)
{
	decl Float:vOrigin[3], Float:vEnd[3];

	if (CanSpawnEntity() && GetTraceRayDownVectors(client, vOrigin, vEnd))
	{
		new iOildrum = CreateEntityByName(ENTITY_NAME_OILDRUM);

		if(IsValidEntity(iOildrum))
		{		
			PrintToChat (client, "[DeathPerks] Oildrum spawned.");

			SetEntityModel(iOildrum, MODEL_PATH_OILDRUM);
			vEnd[2] += OFFSET_HEIGHT_OILDRUM;

			DispatchSpawn(iOildrum);
			SetEntityMoveType(iOildrum, MOVETYPE_VPHYSICS);
			SetEntProp(iOildrum, Prop_Send, "m_CollisionGroup", 5);
			SetEntProp(iOildrum, Prop_Send, "m_nSolidType", 6);

			new Float:ModelAngle[3] = VECTOR_ANGLE_OILDRUM;
			TeleportEntity(iOildrum, vEnd, ModelAngle, NULL_VECTOR);

			// explode drum
			new Handle:pack;
			g_hDrumTimerHandle[client] = CreateDataTimer(DRUMTIMER_EXPLODE_DELAY, CallExplodeDrum, pack);

			WritePackCell(pack, client);
			WritePackCell(pack, iOildrum);
		}
		else
		{
			PrintToChat (client, "[DeathPerks] ERROR - Unknown error, oildrum spawn failed.");
		}
	}
}

public SpawnFrog(client)
{
	decl Float:vOrigin[3], Float:vEnd[3];

	if (CanSpawnEntity() && GetTraceRayDownVectors(client, vOrigin, vEnd))
	{
		LightningStrike(client, vEnd);
		// spawn frog
		new Handle:pack;
		g_hFrogTimerHandle[client] = CreateDataTimer(FROGTIMER_SPAWN_DELAY, CallSpawnFrog, pack);

		WritePackCell(pack, client);
		WritePackFloat(pack, vEnd[0]);
		WritePackFloat(pack, vEnd[1]);
		WritePackFloat(pack, vEnd[2]);
	}
}

public LightningStrike(client, Float:vOrigin[3])
{
	// define where the lightning strike starts
	new Float:vStart[3];
	vStart[0] = vOrigin[0] + GetRandomInt(-500, 500);
	vStart[1] = vOrigin[1] + GetRandomInt(-500, 500);
	vStart[2] = vOrigin[2] + 800;

	// define the color of the strike
	new aColor[4] = LIGHTNING_COLOR;

	TE_SetupBeamPoints(		vStart, 
			vOrigin, 
			g_iLightningSprite, 
			LIGHTNING_HALOINDEX, 
			LIGHTNING_STARTFRAME, 
			LIGHTNING_FRAMERATE, 
			LIGHTNING_LIFE, 
			LIGHTNING_STARTWIDTH, 
			LIGHTNING_ENDWIDTH, 
			LIGHTNING_FADELENGTH, 
			LIGHTNING_AMPLITUDE, 
			aColor, 
			LIGHTNING_SPEED
			);
	TE_SendToAll();

	// Lightning sound
	EmitSoundToAll(LIGHTNING_SOUND_THUNDER, client, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE, SND_NOFLAGS, SNDVOL_NORMAL);

}

public Explosion(Float:vOrigin[3])
{
	new hExplosion = CreateEntityByName(ENTITY_NAME_EXPLOSION);
	DispatchKeyValue(hExplosion, EXPLOSIONKEYVALUE_MAGNITUDE, EXPLOSION_MAGNITUDE);
	DispatchKeyValue(hExplosion, EXPLOSIONKEYVALUE_SPAWNFLAGS, EXPLOSION_SPAWNFLAGS);
	DispatchKeyValue(hExplosion, EXPLOSIONKEYVALUE_RADIUS, EXPLOSION_RADIUS);

	if ( DispatchSpawn(hExplosion) )
	{
		ActivateEntity(hExplosion);
		TeleportEntity(hExplosion, vOrigin, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(hExplosion, "Explode");
		AcceptEntityInput(hExplosion, "Kill");
	}
}

// Create Menu 
public Action:Panel_ChangeDeathItem(client)
{
	new Handle:menu = CreateMenu(DeathItemMenuHandler);
	decl String:iTmp[32];
	new iSelected;

	SetMenuTitle(menu, MENUTITLE_SPAWN_ITEM);

	GetClientCookie(client, g_hDeathItemCookie, iTmp, sizeof(iTmp));
	iSelected = StringToInt(iTmp);

	if (_:iSelected == Action_Null)
	{
		new String:iCompare[32];
		IntToString(Action_Null, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_NULL, ITEMDRAW_DISABLED);
	}
	else
	{
		new String:iCompare[32];
		IntToString(Action_Null, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_NULL, ITEMDRAW_DEFAULT);
	}

	// Exploding pumpkin
	if (_:iSelected == Action_Pumpkin)
	{
		new String:iCompare[32];
		IntToString(Action_Pumpkin, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_PUMPKIN, ITEMDRAW_DISABLED);
	}
	else
	{
		new String:iCompare[32];
		IntToString(Action_Pumpkin, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_PUMPKIN, ITEMDRAW_DEFAULT);
	}

	// Ball
	if (_:iSelected == Action_Ball)
	{
		new String:iCompare[32];
		IntToString(Action_Ball, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_BALL, ITEMDRAW_DISABLED);
	}
	else
	{
		new String:iCompare[32];
		IntToString(Action_Ball, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_BALL, ITEMDRAW_DEFAULT);
	}

	// Oildrum
	if (_:iSelected == Action_Oildrum)
	{
		new String:iCompare[32];
		IntToString(Action_Oildrum, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_OILDRUM, ITEMDRAW_DISABLED);
	}
	else
	{
		new String:iCompare[32];
		IntToString(Action_Oildrum, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_OILDRUM, ITEMDRAW_DEFAULT);
	}

	// Frog
	if (_:iSelected == Action_Frog)
	{
		new String:iCompare[32];
		IntToString(Action_Frog, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_FROG, ITEMDRAW_DISABLED);
	}
	else
	{
		new String:iCompare[32];
		IntToString(Action_Frog, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_FROG, ITEMDRAW_DEFAULT);
	}

	// Ghost
	if (_:iSelected == Action_Ghost)
	{
		new String:iCompare[32];
		IntToString(Action_Ghost, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_GHOST, ITEMDRAW_DISABLED);
	}
	else
	{
		new String:iCompare[32];
		IntToString(Action_Ghost, iCompare, sizeof(iCompare));
		AddMenuItem(menu, iCompare, MENUSELECT_ITEM_GHOST, ITEMDRAW_DEFAULT);
	}

	DisplayMenu(menu, client, 20);
}


// Menu Handler
public DeathItemMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	decl String:iSelected[32];
	GetMenuItem(menu, param2, iSelected, sizeof(iSelected));

	switch (action)
	{
		case MenuAction_Select:
			{
				SetClientCookie(param1, g_hDeathItemCookie, iSelected);
			}
			//		case MenuAction_Cancel: ;
		case MenuAction_End: CloseHandle(menu);
	}
}


public bool:TraceRayProp(entityhit, mask)
{
	if (entityhit == 0)												// I only want it to hit terrain, no models or debris
	{
		return true;
	}
	return false;
}

public bool:IsDonatorInGame(client)
{
	return IsClientInGame(client) && !IsFakeClient(client) && IsPlayerDonator(client);
}

public bool:CanSpawnEntity()
{
	return GetEntityCount() < GetMaxEntities()-32;
}


// timer: spawn donator frog/lightning/explosion
public Action:CallSpawnFrog(Handle:Timer, Handle:pack)
{
	// Set to the beginning and unpack it
	ResetPack(pack);
	new client = ReadPackCell(pack);

	decl Float:vEnd[3];
	vEnd[0] = ReadPackFloat(pack);
	vEnd[1] = ReadPackFloat(pack);
	vEnd[2] = ReadPackFloat(pack);

	//	PrintToChat (client, "[DeathPerks] Attempting to create frog at (%f, %f, %f) for client #%d.", vEnd[0], vEnd[1], vEnd[2], client);

	if(CanSpawnEntity())
	{
		new iFrog = CreateEntityByName(ENTITY_NAME_FROG);
		if(IsValidEntity(iFrog))
		{		
			SetEntityModel(iFrog, MODEL_PATH_FROG);
			DispatchSpawn(iFrog);
			vEnd[2] += OFFSET_HEIGHT_FROG;

			new Float:ModelAngle[3] = VECTOR_ANGLE_FROG;
			TeleportEntity(iFrog, vEnd, ModelAngle, NULL_VECTOR);

			// Explosion
			Explosion(vEnd);

			PrintToChat (client, "[DeathPerks] Frog spawned.");
		}
	}

	g_hFrogTimerHandle[client] = INVALID_HANDLE;
}


// timer: explode drum
public Action:CallExplodeDrum(Handle:Timer, Handle:pack)
{
	// Set to the beginning and unpack it
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iOildrum = ReadPackCell(pack);

	// will this cover if the oil drum is already exploded by a player?	
	if ( IsValidEntity(iOildrum) )
	{	
		SDKHooks_TakeDamage(iOildrum, client, client, DRUMTIMER_EXPLODE_DAMAGE, DMG_GENERIC);
	}
	else
	{
		PrintToServer ("[DeathPerks] CATCH - Oildrum no longer exists.");
	}

	g_hDrumTimerHandle[client] = INVALID_HANDLE;

}


// timer: explode pumpkin
public Action:CallExplodePumpkin(Handle:Timer, Handle:pack)
{
	// Set to the beginning and unpack it
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new iPumpkin = ReadPackCell(pack);

	// will this cover if the pumpkin is already exploded by a player?	
	if ( IsValidEntity(iPumpkin) )
	{	
		SDKHooks_TakeDamage(iPumpkin, client, client, PUMPKINTIMER_EXPLODE_DAMAGE, DMG_GENERIC);
	}
	else
	{
		PrintToServer ("[DeathPerks] CATCH - Pumpkin no longer exists.");
	}

	g_hPumpkinTimerHandle[client] = INVALID_HANDLE;

}


// Cleanup when player leaves
public OnClientDisconnect(client)
{
	CleanUpTimersForClient(client);
}


public OnMapEnd()
{
	CleanUpTimers();
}


// Cleanup all timers
public CleanUpTimers()
{
	for (new client=1; client <= MaxClients; client++)
	{
		CleanUpTimersForClient(client);
	}
}

public CleanUpTimersForClient(client)
{
	SafeKillTimer(g_hFrogTimerHandle[client]);
	SafeKillTimer(g_hDrumTimerHandle[client]);
	SafeKillTimer(g_hPumpkinTimerHandle[client]);
}

public SafeKillTimer(&Handle:timer)
{
	if(timer != INVALID_HANDLE)
	{
		KillTimer(timer);
		timer = INVALID_HANDLE;
	}
}

