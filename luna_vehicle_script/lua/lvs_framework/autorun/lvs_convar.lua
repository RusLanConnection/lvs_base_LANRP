-- 2022 and i still havent bothered creating a system that does this automatically

LVS.cVar_playerignore = CreateConVar( "lvs_ai_ignoreplayers", "0", {FCVAR_REPLICATED , FCVAR_ARCHIVE},"should LVS-AI ignore Players?" )
LVS.cVar_IgnoreNPCs = CreateConVar( "lvs_ai_ignorenpcs", "0", {FCVAR_REPLICATED , FCVAR_ARCHIVE},"should LVS-AI ignore NPCs?" )

LVS.FreezeTeams = CreateConVar( "lvs_freeze_teams", "0", {FCVAR_REPLICATED , FCVAR_ARCHIVE},"enable/disable auto ai-team switching" )
LVS.TeamPassenger = CreateConVar( "lvs_teampassenger", "0", {FCVAR_REPLICATED , FCVAR_ARCHIVE},"only allow players of matching ai-team to enter the vehicle? 1 = team only, 0 = everyone can enter" )
LVS.PlayerDefaultTeam = CreateConVar( "lvs_default_teams", "0", {FCVAR_REPLICATED , FCVAR_ARCHIVE},"set default player ai-team" )

LVS.IgnoreNPCs = LVS.cVar_IgnoreNPCs and LVS.cVar_IgnoreNPCs:GetBool() or false
LVS.IgnorePlayers = cVar_playerignore and cVar_playerignore:GetBool() or false

cvars.AddChangeCallback( "lvs_ai_ignoreplayers", function( convar, oldValue, newValue ) 
	LVS.IgnorePlayers = tonumber( newValue ) ~=0
end)

cvars.AddChangeCallback( "lvs_ai_ignorenpcs", function( convar, oldValue, newValue ) 
	LVS.IgnoreNPCs = tonumber( newValue ) ~=0
end)

if SERVER then
	util.AddNetworkString( "lvs_admin_setconvar" )

	net.Receive( "lvs_admin_setconvar", function( length, ply )
		if not IsValid( ply ) or not ply:IsSuperAdmin() then return end

		local ConVar = net.ReadString()
		local Value = tonumber( net.ReadString() )

		RunConsoleCommand( ConVar, Value ) 
	end)

	return
end

local cvarVolume = CreateClientConVar( "lvs_volume", 0.25, true, false)
local cvarDirectInput = CreateClientConVar( "lvs_mouseaim", 0, true, true)

local cvarShowPlaneIdent = CreateClientConVar( "lvs_show_identifier", 1, true, false)
local cvarHitMarker = CreateConVar( "lvs_hitmarker", 1, true, false)

LVS.cvarCamFocus = CreateClientConVar( "lvs_camerafocus", 0, true, false)

LVS.ShowPlaneIdent = cvarShowPlaneIdent and cvarShowPlaneIdent:GetBool() or true
LVS.ShowHitMarker = cvarHitMarker and cvarHitMarker:GetBool() or false
LVS.EngineVolume = cvarVolume and cvarVolume:GetFloat() or 0.25

cvars.AddChangeCallback( "lvs_volume", function( convar, oldValue, newValue ) 
	LVS.EngineVolume = math.Clamp( tonumber( newValue ), 0, 1 )
end)

cvars.AddChangeCallback( "lvs_show_identifier", function( convar, oldValue, newValue ) 
	LVS.ShowPlaneIdent = tonumber( newValue ) ~=0
end)

cvars.AddChangeCallback( "lvs_hitmarker", function( convar, oldValue, newValue ) 
	LVS.ShowHitMarker = tonumber( newValue ) ~=0
end)