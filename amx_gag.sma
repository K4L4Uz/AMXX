#include < amxmodx >
#include < amxmisc >
#include < engine >

#define MAX_PLAYERS 32

enum ( <<= 1 )
{
	GAG_CHAT = 1,
	GAG_TEAMSAY,
	GAG_VOICE
};

enum _:GagData
{
	GAG_AUTHID[ 35 ],
	GAG_TIME,
	GAG_START,
	GAG_FLAGS
};

new Array:g_aGagData;
new g_iGagged;
new Trie:g_tArrayPos;
new g_iMsgSayText;

new Array:g_aGagTimes;
new g_iTotalGagTimes;

new g_szAuthid[ MAX_PLAYERS + 1 ][ 35 ];
new g_iMenuOption[ MAX_PLAYERS + 1 ];
new g_iMenuPosition[ MAX_PLAYERS + 1 ];
new g_iMenuPlayers[ MAX_PLAYERS + 1 ][ 32 ];
new g_iMenuFlags[ MAX_PLAYERS + 1 ];

new g_szGagFile[ 64 ];

new bool:g_bColoredMenus;

new g_iThinker;

new g_pCvarDefaultFlags;
new g_pCvarDefaultTime;

public plugin_init( )
{
	register_plugin( "AMXX Gag", "1.4.1", "xPaw & Exolent" );
	
	register_clcmd( "say",        "CmdSay" );
	register_clcmd( "say_team",   "CmdTeamSay" );
	
	register_concmd( "amx_gag",       "CmdGagPlayer",   ADMIN_KICK, "<nick or #userid> <time> <a|b|c> -- Use 0 time for permanent" );
	register_concmd( "amx_ungag",     "CmdUnGagPlayer", ADMIN_KICK, "<nick or #userid>" );
	register_concmd( "amx_gagmenu",   "CmdGagMenu",     ADMIN_KICK, "- displays gag menu" );
	register_srvcmd( "amx_gag_times", "CmdSetBanTimes" );
	
	register_menu( "Gag Menu", 1023, "ActionGagMenu" );
	register_menu( "Gag Flags", 1023, "ActionGagFlags" );
	register_message( get_user_msgid( "SayText" ), "MessageSayText" );
	
	g_pCvarDefaultFlags = register_cvar( "amx_gag_default_flags", "abc" );
	g_pCvarDefaultTime  = register_cvar( "amx_gag_default_time",  "120" );
	
	g_tArrayPos = TrieCreate( );
	g_aGagData  = ArrayCreate( GagData );
	g_aGagTimes = ArrayCreate( );
	g_bColoredMenus = bool:colored_menus( );
	g_iMsgSayText = get_user_msgid( "SayText" );
	
	ArrayPushCell( g_aGagTimes, 0 );
	
	ArrayPushCell( g_aGagTimes, 60 );
	ArrayPushCell( g_aGagTimes, 120 );
	ArrayPushCell( g_aGagTimes, 300 );
	ArrayPushCell( g_aGagTimes, 600 );
	ArrayPushCell( g_aGagTimes, 1800 );
	ArrayPushCell( g_aGagTimes, 3600 );
	ArrayPushCell( g_aGagTimes, 7200 );
	ArrayPushCell( g_aGagTimes, 86400 );
	ArrayPushCell( g_aGagTimes, 0 );
	
	g_iTotalGagTimes = ArraySize( g_aGagTimes );
	
	new const szClassname[ ] = "gag_thinker";
	
	g_iThinker = create_entity( "info_target" );
	entity_set_string( g_iThinker, EV_SZ_classname, szClassname );
	
	register_think( szClassname, "FwdThink" );
	
	get_datadir( g_szGagFile, charsmax( g_szGagFile ) );
	add( g_szGagFile, charsmax( g_szGagFile ), "/gags.txt" );
	copy( g_szAuthid[ 0 ], charsmax( g_szAuthid[ ] ), "SERVER" );
	LoadFromFile( );
}

public CmdSetBanTimes( )
{
	new iArgs = read_argc( );
	
	if( iArgs <= 1 )
	{
		server_print( "Usage: amx_gag_times <time1> [time2] [time3] ..." );
		return PLUGIN_HANDLED;
	}
	
	ArrayClear( g_aGagTimes );
	
	ArrayPushCell( g_aGagTimes, 0 );
	
	new szBuffer[ 32 ], iTime;
	for( new i = 1; i < iArgs; i++ )
	{
		read_argv( i, szBuffer, 31 );
		
		if( !is_str_num( szBuffer ) )
		{
			server_print( "[KC] Time must be an integer! (%s)", szBuffer );
			continue;
		}
		
		iTime = str_to_num( szBuffer );
		
		if( iTime < 0 )
		{
			server_print( "[KC] Time must be a positive integer! (%d)", iTime );
			continue;
		}
		
		if( iTime > 86400 )
		{
			server_print( "[KC] Time more then 86400 is not allowed! (%d)", iTime );
			continue;
		}
		
		ArrayPushCell( g_aGagTimes, iTime );
	}
	
	g_iTotalGagTimes = ArraySize( g_aGagTimes );
	
	return PLUGIN_HANDLED;
}

public plugin_end( )
{
	SaveToFile( );
	
	TrieDestroy( g_tArrayPos );
	ArrayDestroy( g_aGagData );
	ArrayDestroy( g_aGagTimes );
}

public client_putinserver( id )
{
	if( CheckGagFlag( id, GAG_VOICE ) )
		set_speak( id, SPEAK_MUTED );
	
	g_iMenuFlags[ id ] = GAG_CHAT | GAG_TEAMSAY | GAG_VOICE;
}

public client_authorized( id )
	get_user_authid( id, g_szAuthid[ id ], 34 );

public client_disconnect( id )
{
	if( TrieKeyExists( g_tArrayPos, g_szAuthid[ id ] ) )
	{
		new szName[ 32 ];
		get_user_name( id, szName, 31 );
		
		new aPlayers[ 32 ], pnum, pl;
		get_players( aPlayers, pnum, "ch" );
		
		for( new i; i < pnum; i++ )
		{
			pl = aPlayers[ i ];
			
			if( get_user_flags( pl ) & ADMIN_KICK )
				GreenPrint( pl, "^4[KC]^1 Gagged player ^"^3%s^1<^4%s^1>^" has disconnected!", szName, g_szAuthid[ id ] );
		}
	}
	
	g_szAuthid[ id ][ 0 ] = '^0';
}

public client_infochanged( id )
{
	if( !CheckGagFlag( id, ( GAG_CHAT | GAG_TEAMSAY ) ) )
		return;
	
	static const name[ ] = "name";
	
	static szNewName[ 32 ], szOldName[ 32 ];
	get_user_info( id, name, szNewName, 31 );
	get_user_name( id, szOldName, 31 );
	
	if( !equal( szNewName, szOldName ) )
	{
		GreenPrint( id, "^4[KC]^1 Gagged players cannot change their names!" );
		
		set_user_info( id, name, szOldName );
	}
}

public MessageSayText( )
{
	static const Cstrike_Name_Change[ ] = "#Cstrike_Name_Change";
	
	new szMessage[ sizeof( Cstrike_Name_Change ) + 1 ];
	get_msg_arg_string( 2, szMessage, sizeof( szMessage ) - 1 );
	
	if( equal( szMessage, Cstrike_Name_Change ) )
	{
		new szName[ 32 ], id;
		for( new i = 3; i <= 4; i++ )
		{
			get_msg_arg_string( i, szName, 31 );
			
			id = get_user_index( szName );
			
			if( is_user_connected( id ) )
			{
				if( CheckGagFlag( id, ( GAG_CHAT | GAG_TEAMSAY ) ) )
					return PLUGIN_HANDLED;
				
				break;
			}
		}
	}
	
	return PLUGIN_CONTINUE;
}

public FwdThink( const iEntity )
{
	if( !g_iGagged )
		return;
	
	new Float:fGametime;
	fGametime = get_gametime( );
	
	new data[ GagData ], id, szName[ 32 ];
	for( new i = 0; i < g_iGagged; i++ )
	{
		ArrayGetArray( g_aGagData, i, data );
		
		if( Float:data[ GAG_TIME ] > 0.0 && ( Float:data[ GAG_START ] + Float:data[ GAG_TIME ] - 0.5 ) <= fGametime )
		{
			id = find_player( "c", data[ GAG_AUTHID ] );
			
			if( is_user_connected( id ) )
			{
				get_user_name( id, szName, 31 );
				
				GreenPrint( 0, "^4[KC]^1 Player ^"^3%s^1^" is no longer gagged", szName );
			}
			
			DeleteGag( i-- );
		}
	}
	
	if( !g_iGagged )
		return;
	
	new Float:flNextTime = 999999.9;
	for( new i = 0; i < g_iGagged; i++ )
	{
		ArrayGetArray( g_aGagData, i, data );
		
		if( Float:data[ GAG_TIME ] > 0.0 )
			flNextTime = floatmin( flNextTime, Float:data[ GAG_START ] + Float:data[ GAG_TIME ] );
	}
	
	if( flNextTime < 999999.9 )
		entity_set_float( iEntity, EV_FL_nextthink, flNextTime );
}

public CmdSay( const id )
	return CheckSay( id, 0 );

public CmdTeamSay( const id )
	return CheckSay( id, 1 );

CheckSay( const id, const bTeam )
{
	new iArrayPos;
	if( TrieGetCell( g_tArrayPos, g_szAuthid[ id ], iArrayPos ) )
	{
		new data[ GagData ];
		ArrayGetArray( g_aGagData, iArrayPos, data );
		
		new const iFlags[ ] = { GAG_CHAT, GAG_TEAMSAY };
		
		if( data[ GAG_FLAGS ] & iFlags[ bTeam ] )
		{
			if( Float:data[ GAG_TIME ] > 0.0 )
			{
				new szInfo[ 32 ], iLen, iTime = floatround( ( Float:data[ GAG_START ] + Float:data[ GAG_TIME ] ) - get_gametime( ) ), iMinutes = iTime / 60, iSeconds = iTime % 60;
				
				if( iMinutes > 0 )
					iLen = formatex( szInfo, 31, "%i minute%s", iMinutes, iMinutes == 1 ? "" : "s" );
				if( iSeconds > 0 )
					formatex( szInfo[ iLen ], 31 - iLen, "%s%i second%s", iLen ? " and " : "", iSeconds, iSeconds == 1 ? "" : "s" );
				
				GreenPrint( id, "^4[KC]^3 %s^1 left before your ungag!", szInfo );
			}
			else
				GreenPrint( id, "^4[KC]^3 You are gagged permanently!" );
			
			client_print( id, print_center, "** You are gagged from%s chat! **", bTeam ? " team" : "" );
			
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_CONTINUE;
}

public CmdGagPlayer( const id, const iLevel, const iCid )
{
	if( !cmd_access( id, iLevel, iCid, 2 ) )
	{
		console_print( id, "Flags: a - Chat | b - Team Chat | c - Voice communications" );
		return PLUGIN_HANDLED;
	}
	
	new szArg[ 32 ];
	read_argv( 1, szArg, 31 );
	
	new iPlayer = cmd_target( id, szArg, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_NO_BOTS );
	
	if( !iPlayer )
		return PLUGIN_HANDLED;
	
	new szName[ 20 ];
	get_user_name( iPlayer, szName, 19 );
	
	if( TrieKeyExists( g_tArrayPos, g_szAuthid[ iPlayer ] ) )
	{
		console_print( id, "User ^"%s^" is already gagged!", szName );
		return PLUGIN_HANDLED;
	}
	
	get_pcvar_string( g_pCvarDefaultFlags, szArg, charsmax( szArg ) );
	new iFlags = read_flags( szArg );
	
	new Float:flGagTime = get_pcvar_float( g_pCvarDefaultTime );
	
	if( flGagTime < 0 )
		flGagTime = 600.0;
	else if( flGagTime > 86400.0 )
		flGagTime = 86400.0;
	
	read_argv( 2, szArg, 31 );
	
	if( szArg[ 0 ] ) // No time entered
	{
		if( is_str_num( szArg ) ) // Seconds entered
		{
			flGagTime = floatstr( szArg );
			
			if( flGagTime > 86400.0 )
				flGagTime = 86400.0;
		}
		else
		{
			console_print( id, "The value must be in seconds!" );
			return PLUGIN_HANDLED;
		}
		
		read_argv( 3, szArg, 31 );
		
		if( szArg[ 0 ] )
			iFlags = read_flags( szArg );
	}
	
	new data[ GagData ];
	data[ GAG_START ] = _:get_gametime( );
	data[ GAG_TIME ]  = _:flGagTime;
	data[ GAG_FLAGS ] = iFlags;
	copy( data[ GAG_AUTHID ], 34, g_szAuthid[ iPlayer ] );
	
	TrieSetCell( g_tArrayPos, g_szAuthid[ iPlayer ], g_iGagged );
	ArrayPushArray( g_aGagData, data );
	
	new szFrom[ 64 ];
	
	if( iFlags & GAG_CHAT )
		copy( szFrom, 63, "say" );
	
	if( iFlags & GAG_TEAMSAY )
	{
		if( !szFrom[ 0 ] )
			copy( szFrom, 63, "say_team" );
		else
			add( szFrom, 63, " / say_team" );
	}
	
	if( iFlags & GAG_VOICE )
	{
		set_speak( iPlayer, SPEAK_MUTED );
		
		if( !szFrom[ 0 ] )
			copy( szFrom, 63, "voicecomm" );
		else
			add( szFrom, 63, " / voicecomm" );
	}
	
	g_iGagged++;
	
	if( flGagTime > 0.0 )
	{
		new Float:flGametime = get_gametime( ), Float:flNextThink;
		flNextThink = entity_get_float( g_iThinker, EV_FL_nextthink );
		
		if( !flNextThink || flNextThink > ( flGametime + flGagTime ) )
			entity_set_float( g_iThinker, EV_FL_nextthink, flGametime + flGagTime );
	}
	
	new szInfo[ 32 ], szAdmin[ 32 ], iTime = floatround( flGagTime ), iMinutes = iTime / 60, iSeconds = iTime % 60;
	get_user_name( id, szAdmin, 31 );
	
	if( iTime )
	{
		if( !iMinutes )
			formatex( szInfo, 31, "na %i sekund%s", iSeconds, iSeconds == 1 ? "" : "s" );
		else
			formatex( szInfo, 31, "na %i minut%s", iMinutes, iMinutes == 1 ? "" : "s" );
	}
	else
		copy( szInfo, 31, "permanently" );
	
	GreenPrint( 0, "^4[KC]^3 Admin^4 %s^1 has gagged^3 %s^1 from speaking^3 %s^1! (^3%s^1)", szAdmin, szName, szInfo, szFrom );
	
	console_print( id, "You have gagged ^"%s^" (%s) !", szName, szFrom );
	
	log_amx( "Gag: ^"%s<%s>^" has gagged ^"%s<%s>^" %s. (%s)", szAdmin, g_szAuthid[ id ], szName, g_szAuthid[ iPlayer ], szInfo, szFrom );
	
	return PLUGIN_HANDLED;
}

public CmdUnGagPlayer( const id, const iLevel, const iCid )
{
	if( !cmd_access( id, iLevel, iCid, 2 ) )
		return PLUGIN_HANDLED;
	
	new szArg[ 32 ];
	read_argv( 1, szArg, 31 );
	
	if( szArg[ 0 ] == '@' && equali( szArg[ 1 ], "all" ) )
	{
		if( !g_iGagged )
		{
			console_print( id, "No gagged players!" );
			return PLUGIN_HANDLED;
		}
		
		while( g_iGagged ) DeleteGag( 0 );
		
		if( entity_get_float( g_iThinker, EV_FL_nextthink ) > 0.0 )
			entity_set_float( g_iThinker, EV_FL_nextthink, 0.0 );
		
		console_print( id, "You have ungagged all players!" );
		
		new szAdmin[ 32 ];
		get_user_name( id, szAdmin, 31 );
		
		show_activity( id, szAdmin, "Has ungagged all players." );
		
		log_amx( "UnGag: ^"%s<%s>^" has ungagged all players.", szAdmin, g_szAuthid[ id ] );
		
		return PLUGIN_HANDLED;
	}
	
	new iPlayer = cmd_target( id, szArg, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_NO_BOTS );
	
	if( !iPlayer )
		return PLUGIN_HANDLED;
	
	new szName[ 32 ];
	get_user_name( iPlayer, szName, 31 );
	
	new iArrayPos;
	if( !TrieGetCell( g_tArrayPos, g_szAuthid[ iPlayer ], iArrayPos ) )
	{
		console_print( id, "User ^"%s^" is not gagged!", szName );
		return PLUGIN_HANDLED;
	}
	
	DeleteGag( iArrayPos );
	
	new szAdmin[ 32 ];
	get_user_name( id, szAdmin, 31 );
	
	GreenPrint( 0, "^4[KC]^3 Admin^4 %s^1 has ungagged^3 %s", szAdmin, szName );
	
	console_print( id, "You have ungagged ^"%s^" !", szName );
	
	log_amx( "UnGag: ^"%s<%s>^" has ungagged ^"%s<%s>^"", szAdmin, g_szAuthid[ id ], szName, g_szAuthid[ iPlayer ] );
	
	return PLUGIN_HANDLED;
}

public CmdGagMenu( const id, const iLevel, const iCid )
{
	if( !cmd_access( id, iLevel, iCid, 1 ) )
		return PLUGIN_HANDLED;
	
	g_iMenuOption[ id ] = 0;
	arrayset( g_iMenuPlayers[ id ], 0, 32 );
	
	DisplayGagMenu( id, g_iMenuPosition[ id ] = 0 );
	
	return PLUGIN_HANDLED;
}

#define PERPAGE 6

public ActionGagMenu( const id, const iKey )
{
	switch( iKey )
	{
		case 6: DisplayGagFlags( id );
		case 7:
		{
			++g_iMenuOption[ id ];
			g_iMenuOption[ id ] %= g_iTotalGagTimes;
			
			DisplayGagMenu( id, g_iMenuPosition[ id ] );
		}
		case 8: DisplayGagMenu( id, ++g_iMenuPosition[ id ] );
		case 9: DisplayGagMenu( id, --g_iMenuPosition[ id ] );
		default:
		{
			new iPlayer = g_iMenuPlayers[ id ][ g_iMenuPosition[ id ] * PERPAGE + iKey ];
			
			if( !g_iMenuOption[ id ] )
				client_cmd( id, "amx_ungag #%i", get_user_userid( iPlayer ) );
			else
			{
				new szFlags[ 4 ];
				get_flags( g_iMenuFlags[ id ], szFlags, 3 );
				
				client_cmd( id, "amx_gag #%i %i %s", get_user_userid( iPlayer ), ArrayGetCell( g_aGagTimes, g_iMenuOption[ id ] ), szFlags );
			}
			
			DisplayGagMenu( id, g_iMenuPosition[ id ] );
		}
	}
}

DisplayGagMenu( const id, iPosition )
{
	if( iPosition < 0 )
	{
		arrayset( g_iMenuPlayers[ id ], 0, 32 );
		return;
	}
	
	new aPlayers[ 32 ], pnum, iCount, szMenu[ 512 ], pl, iFlags, szName[ 32 ];
	get_players( aPlayers, pnum, "ch" );
	
	new iStart = iPosition * PERPAGE;
	
	if( iStart >= pnum )
		iStart = iPosition = g_iMenuPosition[ id ] = 0;
	
	new iEnd = iStart + PERPAGE, iKeys = MENU_KEY_0 | MENU_KEY_8;
	new iLen = formatex( szMenu, 511, g_bColoredMenus ? "\rGag Menu\R%i/%i^n^n" : "Gag Menu %i/%i^n^n", iPosition + 1, ( ( pnum + PERPAGE - 1 ) / PERPAGE ) );
	
	new bool:bUngag = bool:!g_iMenuOption[ id ];
	
	if( iEnd > pnum ) iEnd = pnum;
	
	for( new i = iStart; i < iEnd; ++i )
	{
		pl = aPlayers[ i ];
		iFlags  = get_user_flags( pl );
		get_user_name( pl, szName, 31 );
		
		if( pl == id || ( iFlags & ADMIN_IMMUNITY ) || bUngag != TrieKeyExists( g_tArrayPos, g_szAuthid[ pl ] ) )
		{
			++iCount;
			
			if( g_bColoredMenus )
				iLen += formatex( szMenu[ iLen ], 511 - iLen, "\d%i. %s^n", iCount, szName );
			else
				iLen += formatex( szMenu[ iLen ], 511 - iLen, "#. %s^n", szName );
		}
		else
		{
			iKeys |= ( 1 << iCount );
			++iCount;
			
			iLen += formatex( szMenu[ iLen ], 511 - iLen, g_bColoredMenus ? "\r%i.\w %s\y%s\r%s^n" : "%i. %s%s%s^n", iCount, szName, TrieKeyExists( g_tArrayPos, g_szAuthid[ pl ] ) ? " GAGGED" : "", ( ~iFlags & ADMIN_USER ? " *" : "" ) );
		}
	}
	
	g_iMenuPlayers[ id ] = aPlayers;
	
	new szFlags[ 4 ];
	get_flags( g_iMenuFlags[ id ], szFlags, 3 );
	
	iLen += formatex( szMenu[ iLen ], 511 - iLen, g_bColoredMenus ? ( bUngag ? "^n\d7. Flags: %s" : "^n\r7.\y Flags:\w %s" ) : ( bUngag ? "^n#. Flags: %s" : "^n7. Flags: %s" ), szFlags );
	
	if( !bUngag )
	{
		iKeys |= MENU_KEY_7;
		
		new iSeconds = ArrayGetCell( g_aGagTimes, g_iMenuOption[ id ] );
		
		if( iSeconds )
		{
			new iTime = iSeconds / 60;
			
			iLen += formatex( szMenu[ iLen ], 511 - iLen, g_bColoredMenus ? "^n\r8.\y Time:\w %i %s^n" : "^n8. Time: %i %s^n", ( iSeconds > 60 ? iTime : iSeconds ), ( iSeconds > 60 ? "minutes" : "seconds" ) );
		}
		else
			iLen += copy( szMenu[ iLen ], 511 - iLen, g_bColoredMenus ? "^n\r8.\y Time: Permanent^n" : "^n8. Time: Permanent^n" );
	}
	else
		iLen += copy( szMenu[ iLen ], 511 - iLen, g_bColoredMenus ? "^n\r8.\w Ungag^n" : "^n8. Ungag^n" );
	
	if( iEnd != pnum )
	{
		formatex( szMenu[ iLen ], 511 - iLen, g_bColoredMenus ? "^n\r9.\w More...^n\r0.\w %s" : "^n9. More...^n0. %s", iPosition ? "Back" : "Exit" );
		iKeys |= MENU_KEY_9;
	}
	else
		formatex( szMenu[ iLen ], 511 - iLen, g_bColoredMenus ? "^n\r0.\w %s" : "^n0. %s", iPosition ? "Back" : "Exit" );
	
	show_menu( id, iKeys, szMenu, -1, "Gag Menu" );
}

public ActionGagFlags( const id, const iKey )
{
	switch( iKey )
	{
		case 9: DisplayGagMenu( id, g_iMenuPosition[ id ] );
		default:
		{
			g_iMenuFlags[ id ] ^= ( 1 << iKey );
			
			DisplayGagFlags( id );
		}
	}
}

DisplayGagFlags( const id )
{
	new szMenu[ 512 ];
	new iLen = copy( szMenu, 511, g_bColoredMenus ? "\rGag Flags^n^n" : "Gag Flags^n^n" );
	
	if( g_bColoredMenus )
	{
		iLen += formatex( szMenu[ iLen ], 511 - iLen, "\r1.\w Chat: %s^n", ( g_iMenuFlags[ id ] & GAG_CHAT ) ? "\yYES" : "\rNO" );
		iLen += formatex( szMenu[ iLen ], 511 - iLen, "\r2.\w TeamSay: %s^n", ( g_iMenuFlags[ id ] & GAG_TEAMSAY ) ? "\yYES" : "\rNO" );
		iLen += formatex( szMenu[ iLen ], 511 - iLen, "\r3.\w Voice: %s^n", ( g_iMenuFlags[ id ] & GAG_VOICE ) ? "\yYES" : "\rNO" );
	}
	else
	{
		iLen += formatex( szMenu[ iLen ], 511 - iLen, "1. Chat: %s^n", ( g_iMenuFlags[ id ] & GAG_CHAT ) ? "YES" : "NO" );
		iLen += formatex( szMenu[ iLen ], 511 - iLen, "2. TeamSay: %s^n", ( g_iMenuFlags[ id ] & GAG_TEAMSAY ) ? "YES" : "NO" );
		iLen += formatex( szMenu[ iLen ], 511 - iLen, "3. Voice: %s^n", ( g_iMenuFlags[ id ] & GAG_VOICE ) ? "YES" : "NO" );
	}
	
	copy( szMenu[ iLen ], 511 - iLen, g_bColoredMenus ? "^n\r0. \wBack to Gag Menu" : "^n0. Back to Gag Menu" );
	
	show_menu( id, ( MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3 | MENU_KEY_0 ), szMenu, -1, "Gag Flags" );
}

CheckGagFlag( const id, const iFlag )
{
	new iArrayPos;
	
	if( TrieGetCell( g_tArrayPos, g_szAuthid[ id ], iArrayPos ) )
	{
		new data[ GagData ];
		ArrayGetArray( g_aGagData, iArrayPos, data );
		
		return ( data[ GAG_FLAGS ] & iFlag );
	}
	
	return 0;
}

DeleteGag( const iArrayPos )
{
	new data[ GagData ];
	ArrayGetArray( g_aGagData, iArrayPos, data );
	
	if( data[ GAG_FLAGS ] & GAG_VOICE )
	{
		new iPlayer = find_player( "c", data[ GAG_AUTHID ] );
		if( is_user_connected( iPlayer ) )
			set_speak( iPlayer, SPEAK_NORMAL );
	}
	
	TrieDeleteKey( g_tArrayPos, data[ GAG_AUTHID ] );
	ArrayDeleteItem( g_aGagData, iArrayPos );
	g_iGagged--;
	
	for( new i = iArrayPos; i < g_iGagged; i++ )
	{
		ArrayGetArray( g_aGagData, i, data );
		TrieSetCell( g_tArrayPos, data[ GAG_AUTHID ], i );
	}
}

LoadFromFile( )
{
	new hFile = fopen( g_szGagFile, "rt" );
	
	if( hFile )
	{
		new szData[ 128 ], szTime[ 16 ], szStart[ 16 ], szFlags[ 4 ];
		new data[ GagData ], Float:flGameTime = get_gametime( ), Float:flTime, Float:flShortestTime = 0.0;
		
		while( !feof( hFile ) )
		{
			fgets( hFile, szData, charsmax( szData ) );
			trim( szData );
			
			if( !szData[ 0 ] ) continue;
			
			parse( szData,
				data[ GAG_AUTHID ], charsmax( data[ GAG_AUTHID ] ),
				szTime, charsmax( szTime ),
				szStart, charsmax( szStart ),
				szFlags, charsmax( szFlags )
			);
			
			data[ GAG_TIME ] = _:str_to_float( szTime );
			data[ GAG_START ] = _:str_to_float( szStart );
			data[ GAG_FLAGS ] = read_flags( szFlags );
			
			if( Float:data[ GAG_TIME ] > 0.0 )
			{
				flTime = Float:data[ GAG_START ] + Float:data[ GAG_TIME ] - flGameTime;
				
				if( flTime <= 0.0 ) continue;
				
				flShortestTime = floatmin( flShortestTime, flTime );
			}
			
			TrieSetCell( g_tArrayPos, data[ GAG_AUTHID ], g_iGagged );
			ArrayPushArray( g_aGagData, data );
			g_iGagged++;
		}
		
		fclose( hFile );
		
		if( flShortestTime > 0.0 )
			entity_set_float( g_iThinker, EV_FL_nextthink, flGameTime + flShortestTime );
	}
}

SaveToFile( )
{
	new hFile = fopen( g_szGagFile, "wt" );
	
	if( hFile )
	{
		new data[ GagData ], szFlags[ 4 ];
		
		for( new i = 0; i < g_iGagged; i++ )
		{
			ArrayGetArray( g_aGagData, i, data );
			
			get_flags( data[ GAG_FLAGS ], szFlags, charsmax( szFlags ) );
			
			fprintf( hFile, "^"%s^" ^"%f^" ^"%f^" ^"%s^"^n", data[ GAG_AUTHID ], data[ GAG_TIME ], data[ GAG_START ], szFlags );
		}
		
		fclose( hFile );
	}
}

GreenPrint( const id, const input[], any:... )
{
	new szMessage[ 192 ];
	vformat( szMessage, charsmax( szMessage ), input, 3 );
	
	new aPlayers[ 32 ], pnum, pl;
	
	if ( id ) {
		aPlayers[ 0 ] = id;
		pnum = 1;
	} else
		get_players( aPlayers, pnum, "ch" );
	
	for ( new i = 0; i < pnum; i++ ) {
		pl = aPlayers[ i ];
		if ( is_user_connected( pl ) ) {
			message_begin( MSG_ONE_UNRELIABLE, g_iMsgSayText, _, pl );
			write_byte( pl );
			write_string( szMessage );
			message_end( );
		}
	}
}