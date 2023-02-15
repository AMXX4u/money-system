#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <reapi>
#include <amxx4u>

// #define USE_AMXX4U_VIP
#define USE_OTHER_VIP

#if defined USE_OTHER_VIP
	#define VIP_FLAG "t"
#endif

static const NAME[]			= "Money system";
static const VERSION[]		= "1.0";
static const AUTHOR[]		= "dredek";
static const URL_AUTHOR[]	= "https://amxx4u.pl/";

enum _:CVARS
{
	SQL_HOST[MAX_IP_PORT],
	SQL_USER[MAX_NAME],
	SQL_PASS[MAX_NAME],
	SQL_DATA[MAX_NAME],

	KILL,
	KILL_HS,
	KILL_VIP,
	KILL_HS_VIP,
	PLANTED,
	PLANTED_VIP,
	DEFUSED,
	DEFUSED_VIP
};

enum _:PLAYER_INFO (+= 1)
{
	PLAYER_NAME[MAX_NAME],
	PLAYER_AUTH[MAX_AUTHID]
};

static const MONEY_CONFIG[] = "/addons_configs/amxx4u/money/system.cfg";

new player_coins[MAX_PLAYERS + 1];
new player_data[MAX_PLAYERS + 1][PLAYER_INFO];

new Handle:sql;
new Handle:connection;
new bool:sql_connected;
new data_loaded;

new cvars[CVARS];

public plugin_init()
{
	register_plugin(NAME, VERSION, AUTHOR, URL_AUTHOR);

	RegisterHookChain(RG_CSGameRules_DeathNotice, "DeathNotice", .post = true);

	_register_cvars();
}

public plugin_cfg()
{
	new file_path[MAX_PATH];
	get_configsdir(file_path, charsmax(file_path));
	add(file_path, charsmax(file_path), MONEY_CONFIG);

	#if defined DEBUG_MODE
		log_amx("Config path: %s", file_path);
	#endif

	if(!file_exists(file_path))
		set_fail_state(fmt("Nie znaleziono pliku %s (full path: %s)", MONEY_CONFIG, file_path));

	server_cmd("exec %s", file_path);
	_register_sql();
}

public plugin_natives()
{
	register_native("amxx4u_get_money", "_amxx4u_get_money", 1);
	register_native("amxx4u_set_money", "_amxx4u_set_money", 1);
}
public client_putinserver(index)
{
	if(is_user_hltv(index))
		return;

	get_user_name(index, player_data[index][PLAYER_NAME], charsmax(player_data[][PLAYER_NAME]));
	mysql_escape_string(player_data[index][PLAYER_NAME], player_data[index][PLAYER_NAME], charsmax(player_data[][PLAYER_NAME]));

	get_user_authid(index, player_data[index][PLAYER_AUTH], charsmax(player_data[][PLAYER_AUTH]));
	set_task(1.0, "load_data", index);
}

public client_disconnected(index)
{
	if(is_user_hltv(index))
		return;

	save_data(index, 0);
}

public DeathNotice(const player, const killer, inflictor)
{	
	if(!is_user_connected(killer) || !is_user_connected(player) || player == killer)
		return HC_CONTINUE

	new headshot = get_member(player, m_bHeadshotKilled);

	#if defined USE_AMXX4U_VIP
		if(get_user_vip(killer))
			player_coins[killer] += headshot ? cvars[KILL_HS_VIP] : cvars[KILL_VIP];
	#else
		if(has_flag(killer, VIP_FLAG))
			player_coins[killer] += headshot ? cvars[KILL_HS_VIP] : cvars[KILL_VIP];
	#endif

	player_coins[killer] += headshot ? cvars[KILL_HS] : cvars[KILL];
	return HC_CONTINUE;
}

public bomb_planted(planter)
{
	#if defined USE_AMXX4U_VIP
		if(get_user_vip(planter))
			player_coins[planter] += cvars[PLANTED_VIP];
	#else
		if(has_flag(planter, VIP_FLAG))
			player_coins[planter] += cvars[PLANTED_VIP];
	#endif
}

public bomb_defused(defuser)
{
	#if defined USE_AMXX4U_VIP
		if(get_user_vip(defuser))
			player_coins[defuser] += cvars[DEFUSED_VIP];
	#else
		if(has_flag(defuser, VIP_FLAG))
			player_coins[defuser] += cvars[DEFUSED_VIP];
	#endif
}

public _register_sql()
{
	new error[128];
	new error_num;

	get_cvar_string("amxx4u_money_host", cvars[SQL_HOST], charsmax(cvars[SQL_HOST]));
	get_cvar_string("amxx4u_money_user", cvars[SQL_USER], charsmax(cvars[SQL_USER]));
	get_cvar_string("amxx4u_money_pass", cvars[SQL_PASS], charsmax(cvars[SQL_PASS]));
	get_cvar_string("amxx4u_money_data", cvars[SQL_DATA], charsmax(cvars[SQL_DATA]));

	sql         = SQL_MakeDbTuple(cvars[SQL_HOST], cvars[SQL_USER], cvars[SQL_PASS], cvars[SQL_DATA]);
	connection  = SQL_Connect(sql, error_num, error, charsmax(error));

	#if defined DEBUG_MODE
		log_amx("%s Database: %s %s %s %s", debug_prefix, cvars[SQL_HOST], cvars[SQL_USER], cvars[SQL_PASS], cvars[SQL_DATA]);
	#endif

	if(error_num)
	{
		log_amx("MySQL ERROR: Query [%d] %s", error_num, error);
		sql = Empty_Handle;

		set_task(1.0, "_register_sql");
		return;
	}

	new query_data[MAX_DESC];
	formatex(query_data, charsmax(query_data), "\
		CREATE TABLE IF NOT EXISTS `amxx4u_money` (\
		`id` INT(11) NOT NULL AUTO_INCREMENT,\
		`player_name` VARCHAR(64) NOT NULL,\
		`player_auth` VARCHAR(64) NOT NULL DEFAULT 0,\
		`money` INT(11) NOT NULL DEFAULT 0,\
		PRIMARY KEY(`id`));");

	new Handle:query = SQL_PrepareQuery(connection, query_data);

	SQL_Execute(query);
	SQL_FreeHandle(query);

	sql_connected = true;
}

public save_data(index, end)
{
	if(!get_bit(index, data_loaded))
		return;

	new query_data[MAX_DESC];
	formatex(query_data, charsmax(query_data), "\
		UPDATE `amxx4u_money` SET\
		`player_auth` = ^"%s^",\
		`money` = '%i'\
		WHERE `player_name` = ^"%s^";",
		player_data[index][PLAYER_AUTH],
		player_coins[index],
		player_data[index][PLAYER_NAME]);

	switch(end)
	{
		case 0: SQL_ThreadQuery(sql, "ignore_handle", query_data);
		case 1:
		{
			new error[128];
			new error_num;
			new Handle:query;

			query = SQL_PrepareQuery(connection, query_data);

			if(!SQL_Execute(query))
			{
				error_num = SQL_QueryError(query, error, charsmax(error));
				log_amx("MySQL ERROR: Non-threaded query failed. [%d] %s", error_num, error);
			}

			SQL_FreeHandle(query);
			SQL_FreeHandle(connection);
		}
	}

	if(end)
		rem_bit(index, data_loaded);
}

public load_data(index)
{
	if(!sql_connected)
	{
		set_task(1.0, "load_data", index);
		return;
	}

	new temp[1];
	temp[0] = index;

	SQL_ThreadQuery(sql, "load_data_handle", fmt("SELECT * FROM `amxx4u_money` WHERE `player_name` = ^"%s^"", player_data[index][PLAYER_NAME]), temp, sizeof(temp));
}

public load_data_handle(fail_state, Handle:query, error[], error_num, temp_id[], data_size)
{
	if(fail_state)
	{
		log_amx("MySQL ERROR: %s [%d]", error, error_num);
		return;
	}

	new index = temp_id[0];

	if(SQL_NumRows(query))
		player_coins[index]  = SQL_ReadResult(query, SQL_FieldNameToNum(query, "money"));
	else
		SQL_ThreadQuery(sql, "ignore_handle", fmt("INSERT IGNORE INTO `amxx4u_money` (`player_name`) VALUES (^"%s^");", player_data[index][PLAYER_NAME]));

	set_bit(index, data_loaded);
}

public ignore_handle(fail_state, Handle:query, error[], error_num, data[], data_size)
{
	if(fail_state)
	{
		log_amx("MySQL ERROR: ignore_Handle %s (%d)", error, error_num);
		return;
	}

	return;
}

public _amxx4u_set_money(index, amount)
	player_coins[index] = amount;

public _amxx4u_get_money(index)
	return player_coins[index];

_register_cvars()
{
	bind_pcvar_string(create_cvar("amxx4u_money_host", "localhost",  FCVAR_SPONLY | FCVAR_PROTECTED), cvars[SQL_HOST], charsmax(cvars[SQL_HOST]));
	bind_pcvar_string(create_cvar("amxx4u_money_user", "user",       FCVAR_SPONLY | FCVAR_PROTECTED), cvars[SQL_USER], charsmax(cvars[SQL_USER]));
	bind_pcvar_string(create_cvar("amxx4u_money_pass", "pass",       FCVAR_SPONLY | FCVAR_PROTECTED), cvars[SQL_PASS], charsmax(cvars[SQL_PASS]));
	bind_pcvar_string(create_cvar("amxx4u_money_data", "data",  	  FCVAR_SPONLY | FCVAR_PROTECTED), cvars[SQL_DATA], charsmax(cvars[SQL_DATA]));

	bind_pcvar_num(create_cvar("amxx4u_money_kill", "1",
		.description = "Ile monet za zabojstwo"), cvars[KILL]);

	bind_pcvar_num(create_cvar("amxx4u_money_kill_hs", "2",
		.description = "Ile monet za zabojstwo HS"), cvars[KILL_HS]);

	bind_pcvar_num(create_cvar("amxx4u_money_kill_vip", "3",
		.description = "Ile monet za zabojstwo dla VIPA"), cvars[KILL_VIP]);

	bind_pcvar_num(create_cvar("amxx4u_money_kill_hs_vip", "3",
		.description = "Ile monet za zabojstwo HS dla VIPA"), cvars[KILL_HS_VIP]);

	bind_pcvar_num(create_cvar("amxx4u_money_planted", "1",
		.description = "Ile monet za podlozenie bomby"), cvars[PLANTED]);

	bind_pcvar_num(create_cvar("amxx4u_money_planted_vip", "2",
		.description = "Ile monet za podlozenie bomby dla VIPA"), cvars[PLANTED_VIP]);

	bind_pcvar_num(create_cvar("amxx4u_money_defused", "1",
		.description = "Ile monet za rozbrojenie bomby"), cvars[DEFUSED]);

	bind_pcvar_num(create_cvar("amxx4u_money_defused_vip", "2",
		.description = "Ile monet za rozbrojenie bomby dla VIPA"), cvars[DEFUSED_VIP]);

	create_cvar("amxx4u_pl", VERSION, FCVAR_SERVER);
}