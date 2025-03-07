--[[
		Aeth Development - Essential
			> Proudly created and founded by trzistan

			Modern Administration Yet Finest



		For social links and other contact information such as discord, look at
			https://devforum.roblox.com/t/essential-administration-contact-information/3528386

			^ Aeth Development discord is posted here!!
]]

local settings = {}

-- DATASTORE SETTINGS --
settings.Datastore_Allow = false -- Is datastore enabled?

-- || Changing these settings will affect the saved datas ||
settings.Datastore_EncryptKeys = false -- Encrypts datastore keys only
settings.Datastore_ProtectIndex = true -- Encrypts datastore key and scope
settings.Datastore_Compression = true -- (RECOMMENDED) Compresses datastore values to smaller chunks which allows to save larger data
settings.Datastore_UseLegacyHash = false
settings.Datastore_EncryptKey = "[[CHANGE THIS]]" -- (required for encrypting data) Encrypt key to encrypt/decrypt the encrypted datastore data
settings.Datastore_Key = "[[CHANGE THIS]]" -- Datastore main key
settings.Datastore_Scope = "[[CHANGE THIS]]" -- (Optional encrypted) Datastore default scope
settings.Datastore_PlayerData = "[[CHANGE THIS]]" -- (datastore scope for player data) Change this to something random

-- MEMORY SETTINGS [COMING SOON] --
settings.MemoryStore_Key = "EssentialMemoryStore" -- Memorystore main key
settings.MemoryStore_PlayerData = "PlayerData" -- Memorystore scope of player data
settings.MemoryStore_ProtectIndex = true
settings.MemoryStore_QueuePlayerDataSaves = true

settings.CrossAPI_Allow = true -- Used to send remote signals to servers
settings.CrossAPI_Key = "[[CHANGE THIS]]" -- The key name of the cross communication
settings.CrossAPI_Global = false -- (Not recommended) Allow use of this in _G API?

-- PDATA SETTINGS --
settings.playerData_Datastore = true -- Allow player data saved in data stores?
settings.playerData_EncryptData = false -- Allow player data saved in data stores?
settings.playerData_AllowTransfer = true -- Allow players to transfer their player data to another player?
settings.playerData_MaxActivityLogs = 30 -- Maximum activity logs saved in player data

-- CHAT SETTINGS --
-- settings.chatAccess = true -- Allow features to run in chat like Slash commands
-- settings.chatCommands = true -- (Required: ChatAccess) Allow running commands via chat
-- settings.slashCommands = true -- (Required: ChatCommands) Allow running commands via chat using slash (e.g. :ff me -> /ff me)

settings.ChatService_Enabled = true -- Allows the ChatService module to provide functionality for chat moderation, ranks, and more. ChatService will support for 
settings.ChatService_IgnoreChannels = {} -- List channels to bypass mute system and internal chat callbacks
settings.ChatService_OverrideChatCallback = true -- Allows ChatService to support chat tags, 
settings.ChatService_SecureInput = false -- Turns off input chatbar for players before Essential loads
settings.ChatService_FilterSupport = false -- Include Essential's text filtering system; This is useful for filtering bypassed messages with rich text tags
settings.ChatService_SlashCommandsEnabled = true -- Allow player commands to become a slash command in chat? (Excludes sensitive commands with Manage_Game perm or no chat allowed)
settings.ChatService_SlashCommandsPrefix = "e-" -- (Recommended) Adds a prefix to the slash commands; This is helpful to prevent overlapping with other slash commands
settings.ChatService_SlashCommandsConfirmation = false -- Asks the player to confirm the use of the slash command after execution 

settings.chatMaxCommands = 30 -- (Required: ChatAccess) 

-- PERMISSIONS SETTINGS --
--[[
	
		Specifying/Targeting members:
			
			Groups: (takes 5 minutes to update player's cache)
				****** Within ranges
					Group:[Group_Id]:[Minimum-Rank]-[Maximum-Rank]
				
				****** Only minimum rank or higher
					Group:[Group_Id]:>=[Minimum-Rank]

				****** Only maximum rank or lower
					Group:[Group_Id]:<=[Maximum-Rank]

				****** Only that rank
					Group:[Group_Id]:=[Rank]

				-> TABLE SUPPORTED:
				
				{
					Type = "Group";
					
					Id = Group_Id;					-- Group Id
					Value = Group_Rank; 			-- (Cannot be used in range values)
					MinValue = Minimum_Group_Rank; 	-- (Used in range values)
					MaxValue = Maximum_Group_Rank;	-- (Used in range values)
					Operator = Operator_Type; 		-- (range value)
					
					-- Operator types:
					--
					--	"<=" - Less than or equal to
					-- 	"<" - Less than
					--	">=" - Greater than or equal to
					-- 	">" - Greater than
					--	"==" - Equal to
					--	"-" - Range value (min value to max value)
				}
				
			Memberships:
				****** Premium
					Membership:Premium

				****** Non-Premium
					Membership:NonPremium

				****** Essential Donor (takes 5 minutes to update player's donor cache)
					Membership:Donator/Donor
				
				-> TABLE SUPPORTED:
				
				{
					Type = "Membership";
					List = {User_Ids}; 				-- Supported memberships: NonPremium/Premium/Donator
				}
			
			Subscriptions:
				Subscription:[Subscription_Id]
				
				-> TABLE SUPPORTED:
				
				{
					Type = "Subscription";
					List = {List_Of_Subscription_Ids}; 	-- ( i.g. {"14148266", "72385", "1651667"} )
				}
			
			Gamepasses:
				Gamepass:[Gamepass_Id]
				
				-> TABLE SUPPORTED:
				
				{
					Type = "Gamepass";
					List = {List_Of_Gamepass_Ids}; 	-- ( i.g. {14148266, 72385, 1651667} )
				}
				
			Badges:
				Badge:[Badge_Id]
				
				-> TABLE SUPPORTED:
				
				{
					Type = "Badge";
					List = {List_Of_Badge_Ids}; 	-- ( i.g. {2124680861, 2124693446, 2124639542} )
				}
				
			Asset:
				Asset:[Asset_Id]
				
				-> TABLE SUPPORTED:
				
				{
					Type = "Asset";
					List = {List_Of_Asset_Ids}; 	-- ( i.g. {1277377028, 331554374, 303608907} )
				}
				
			Friends:
				FriendsWith:[User_Id]
				
				-> TABLE SUPPORTED:
				
				{
					Type = "FriendsWith";
					List = {User_Ids}; 				-- ( i.g. {327713710, 2025110, 32652133} )
				}
			
			Private Servers:
				Owner: *PrivateServerOwner
				Member: *PrivateServerMember
			
			Users/Players:
				"Username" (string) / Userid (number)
			
				--> TABLE SUPPORTED:
				
				{
					Type = "Users";
					List = {User_Name/User_Id}; 				-- ( i.g. {327713710, 2025110, "Roblox"} )
				}
			
			Place Owner:
				*PlaceOwner
			
			Everyone:
				@everyone, @all
			
		Roles Accessibility & Management: (Idea from crywink and discord's roles')
			
			ADVANCED:
			
				Manage_Server 		=		 	( true / false )	(default: false)
					-- Allow use of server management such as server locking, whitelisting, etc.
					
				Manage_Game			= 			( true / false )	(default: false)
					-- This is a dangerous permission to grant to people. This allows them to manage everything in Essential.
					
				Manage_Roles		= 			( true / false )	(default: false)
					-- Allows managing the in-game roles + saving roles to players
				
			UTILITY:
			
				Use_Utility			= 			( true / false )	(default: true)
					-- Allow the use of utility commands such as !rejoin.
				
				Mention_Roles		=			( true / false )	(default: false)
					-- Allow to mention unmentionable roles
				
				Use_Fun_Commands	=			( true / false )	(default: false)
					-- Allow the players to execute commands
				
				Use_Console			=			( true / false )	(default: false)
					-- Allow access to use console
				
				Bypass_Chat_Slowmode	=		( true / false )	(default: false)
					-- Allow bypassing chat slowmode. Slowmode can be enabled via setting.
				
				View_Logs			=			( true / false )	(default: false)
					-- Allow viewing general logs such as Chat, Commands, etc.
				
				Send_Polls			=			( true / false )	(default: false)
					-- Making and sending polls
				
				HandTo_Utility		=			( true / false )	(default: false)
					-- Allow the use of handTo
					
				PromptDev_Commands	=		( true / false )	(default: false)
					-- Allow access to prompt user commands such as promptpremium, promptgamepass, promptproduct, etc.
				
				Hide_Incognito		=		( true / false )	(default: false)
					-- Allows the player to hide from people's player list while using incognito mode
					
				Character_Incognito		=		( true / false )	(default: false)
					-- Allows the player to hide their character from other people in incognito mode
				
			FUN: (require perm: Use_Fun_Commands)
			
				Use_External_Gears	=			( true / false )	(default: false)
					-- Allow access to gears that aren't owned by Roblox and from the game creator's inventory
					
			MUSIC:
			
				Manage_MusicPlayer	=			( true / false )	(default: false)
					-- Allow the players to run music player commands such as playsound, stopsound, pausesound,
						and resumesound.
					
			MODERATION:
			
				Kick_Player 			= 			( true / false )	(default: false)
					-- Allow the use of kicking players?
				
				Ban_Player				= 			( true / false )	(default: false)
					-- Allow the use of banning players?
					
				Request_Ban 		= 			( true / false )	(default: false)
					-- Allow the use of requesting ban modifications. This applies to banning/resolving.
					-- BUT NOT ALLOWED to create/clear ban notes.
						
				Mute_Player 			= 			( true / false )	(default: false)
					-- Allow the use of muting players?
					
				Warn_Player				= 			( true / false )	(default: false)
					-- Allow the use of warning players?
					
				Deafen_Player			= 			( true / false )	(default: false)
					-- Allow the use of deafening players? This deafens the players' chat.
				
				Manage_Map				=			( true / false )	(default: false)
					-- Allow the use of managing the map? This includes restoring, backing up map, and deleting the map.
				
				Private_Messaging 		=			( true / false )	(default: false)
					-- Allow the use of private messaging to players? You could also leave them a message in their inbox.
				
				Message_Commands		=			( true / false )	(default: false)
					-- Grants access to several commands such as message, hint, alert, etc.
				
				Manage_Characters		=			( true / false )	(default: false)
					-- Grants access to several character commands such as bring, tp, freeze, etc.
				
				Help_Assistance 		=			( true / false )	(default: false)
					-- Grants access to receive help assistance calls.
				
				Manage_Game_Servers 	=			( true / false )	(default: false)
					-- Allows to manage running servers
				
				Manage_Camera			=			( true / false )	(default: false)
					-- Manages players' cameras
				
			ADMINISTRATION:
			
				Manage_Players		=			( true / false )	(default: false)
					-- Allow the use of managing players' permission. Just NOTE that they are unable to manage user permissions
						above or around their current level.
					
				Manage_Bans			= 			( true / false )	(default: false)
					-- Allow the use of managing bans. This allows the player to delete, add, and manage bans. Be careful giving this permission!
				
				Ignore_Command_Cooldown	=		( true / false )	(default: false)
					-- Allow administrators to ignore command cooldowns/slowmodes?
				
				Execute_Scripts 	= 			( true / false )	(default: false)
					-- WARNING! This is a very dangerous permission to grant. Allow administrators execute scripts?
					
				Admin_Terminal		=			( true / false )	(default: false)
					-- (COMNG SOON) Allow the use of TerminalX Console
					
				Cross_Commands		=			( true / false )	(default: false)
					-- Allows the use of cross commands; for instance, crossshutdown
					
				Manage_PlayerData_Transfer	=	( true / false ) 	(default: false)
					-- (Must have permission Manage_Players) Allows player to manage a player's player's data and force transfer
					
			SCRIPTS PERMISSION (Execute_Scripts permission must be enabled)
			
				Script_Explicit_Safe		= 	( true / false )	(default: true)
					-- Disables requiring external modules, using a few environmental functions, and remove access to several game services.
					
				Use_External_Modules		=	( true / false )	(default: false)
					-- (NOT RECOMMENDED) Allow scripts run external modules that don't exist in the game files? For example, "require(Asset_Id)"
					
				Script_No_Hiding 			=	( true / false )	(default: true)
					-- (RECOMMENDED) Disables scripts to hide themselves while running? This is to prevent scripts from
						hiding to execute malware or other external modules
						
				Blacklisted_Script_Access	= {
					script		=	( true / false )	(default: false);
					newproxy	=	( true / false )	(default: false);
					
					-- Add more if you would like..
				}
]]

settings.Permissions = {
	--[[ 
		["PERMISSION_NAME"] = {
			Priority = Priority; -- (number) Priority level
			Color = Color; -- Supported actions: number or Color3
			Members = { List_Of_Members }; -- (table/string) Refer to "specifying/targeting members" section above
			Permissions = {
				-- List of Permissions here. Refer to "Roles Accessibility & Management" section above.
				-- Here's an example..
				
				Use_Utility = false;
			};
			ChatTag = {
				Enabled = false;
				Text = "";
				Font = Enum.Font["Gotham"];
					-- (LEGACY font NOT HIGHLY RECOMMENDED)
					-- See https://create.roblox.com/docs/reference/engine/enums/Font for more fonts
				UseRoleColor = false;
				CustomColor = Color3.fromRGB(255,255,255);
			};
		};
	]]
}

settings.DefaultRolePermissions = {
	-- List of Permissions here. Refer to "Roles Accessibility & Management" section above.
	-- Here's an example..
	Use_Utility = true;
}

-- MUSIC SETTINGS --
settings.musicPlayer_Enabled = true
settings.musicPlayer_Songs = {
	-- FORMAT:
	-- [song_name] = song_id;
	-- -> "song_name" must be in string and "song_id" as a number.

}
settings.musicPlayer_Playlists = { -- Only available with queue enabled
	-- FORMAT:
	-- [playlist_name] = {song_id, song_id, etc..};
	["triz"] = {1846619127, 1843536398};
}
settings.musicPlayer_NoDuplication = false -- (Required: Queue) Whether duplicated songs should be removed or not
settings.musicPlayer_SongAnnouncement = true -- Announce playing music to everyone?
settings.musicPlayer_MaxSongs = 100 -- (Required: Queue) (Minimum: 1) Max songs the queue can have
settings.musicPlayer_MaxPlayerCreations = 10 -- (Required: Queue) (Minimum: 1) Max songs a player can add
	
-- LIST SETTINGS --
settings.BanList = {} -- List of people banned from the game
settings.GearBlacklist = {} -- List of gears banned in all servers, even private ones

-- PRIVATE SERVER SETTINGS --
settings.PServer_CommandsBlacklist = {} -- List of commands disabled in private servers
settings.PServer_GearBlacklist = {} -- List of gears banned in private servers

-- WHITELIST SETTINGS --
settings.Whitelist_Enabled = false -- Whitelist enabled?
settings.WhiteList_Players = {}	-- List of members whitelisted to join a whitelist server. Players with permission "Manage_Game" or "Manage_Server" are also whitelisted.

-- ACTION MESSAGES --
settings.banMessage = "\n[Essential Ban {{$statusCode}}]\nModerator: {{$moderator}}\nStarted: {{$startDate}}\nDueDate: {{$dueDate}}\nIssued in ban {{$id}}"
--	> BAN MESSAGE VARIABLES (CASE SENSITIVE)

--		{{$statusCode}}		 			- Ban status code
--		{{$moderator}}		 			- Responsible moderator's name and id
--		{{$mod_id}}						- Responsible moderator's id
--		{{$id}}, {{$caseId}}			- Ban's id
--		{{$reason}} 					- Ban reason
--		{{$dueDate}}					- When the ban will expire in (DD MMMM YYYY HH:MM format)
--		{{$startDate}}					- When the ban started in (DD MMMM YYYY HH:MM format)
--		{{$relativeStartTime}}			- When the ban started in relative time (e.g. 30 seconds ago)
--		{{$relativeEndTime}}			- When the ban ended in relative time (e.g. 30 seconds ago)

settings.lockMessage = "Whitelisted since {startTime}"
--	> LOCK/WHITELIST MESSAGE VARIABLES (CASE SENSITIVE)
--
--		{user} 						- User's name
--		{displayname}, {name}		- User's displayname
--		{userid} 					- User's id
--		{moderator}, {mod} 			- Responsible moderator
--		{startTime}					- When the lock started
--		{adminsonly}				- Admins only to join?

settings.shutdownMessage = "Game Shutdown:\n{reason}"
--	> SHUTDOWN MESSAGE VARIABLES (CASE SENSITIVE)
--
--		{reason} 					- Shutdown reason
--		{user} 						- User's name
--		{userid} 					- User's id
--		{moderator}, {mod} 			- Responsible moderator
--		{startTime}					- When the shutdown started

settings.kickMessage = "Essential:\n{reason}"
--	> KICK MESSAGE VARIABLES (CASE SENSITIVE)
--
--		{reason}					- Kick reason
--		{user} 						- User's name
--		{displayname}, {name}		- User's displayname
--		{userid} 					- User's id
--		{moderator}, {mod} 			- Responsible moderator
--		{startTime}					- When the kick started

settings.welcome_Allow = false 	-- Allow welcome notifications
settings.welcomeMessages = {
	nonAdmins = "Hello {{$displayname}}. Welcome!";
	admins = "Hello {{$displayname}}. Welcome!";
}
--	> WELCOME MESSAGE VARIABLES (CASE SENSITIVE)
--
--		{{$user}} 						- User's name
--		{displayname}, {name}		- User's displayname
--		{userid} 					- User's id
--		{membership}				- Returns "donator" if the uesr is a donator, else it returns "non-donator"
--		{startTime}					- When the user joined
--		{serverId}					- Server id
--		{serverType}				- "personal" (personally owned), "private" (private), "public" (public), "studio" (studio)

settings.systemMessage = "<b>System Message</b>" -- Title of the system message shown to everyone when executing :sm

-- PREFIX SETTINGS --
settings.playerPrefix 	= "!"	-- Player command prefix
settings.actionPrefix 	= ":"	-- Server command prefix
settings.delimiter 		= " "	-- Used to separate every part of the string (i.g. "." ":ff.me")
settings.batchSeperator = "|"	-- Used in commands to seperate commands in a messsage (must have at least one character)

-- AUTOMATED BACKUPS
settings.automatedTasks_Enabled = true
settings.automatedTasks = {
	--[[
		Map:
		
			{
				name = "Map task";		-- Task name
				type = "Map";			-- Task type
				mode = "Load"; 			-- Options: Load/Save
				maxHold = 30;			-- ONLY WORKS IF MODE IS SET TO SAVE: Max amount of backups stored
				-- Modes
				--
				-- 	 Load		- Loads the initial map from task
				--	 Save		- Saves the map
				--	 Refresh	- Reloads the latest backup
				
				interval = 20; 			-- (Minimum: 20) The amount of interval looped to create a backup
				announceChat = false;	-- Announce task completion to roblox chat
			}	
		
		Command:
		
			{
				name = "Command_Run"; 	-- Task name
				type = "Command";		-- Task type
				command = ":explode"; 	-- Command line (e.g. :kill)
				arguments = "all"; 		-- (Valid type: string, table) | Arguments supplied after the command (e.g 1. {"all"}) (e.g 2. "all")
				playerName = nil; 		-- (Valid type: string, nil) | Player executing this command. If specified player is found in-game, the task will use that player.
								  		-- ... Otherwise, it'll use a fake player instead.'
					
				interval = 30; 			-- (Minimum: 1) The amount of interval looped to run the command with specified arguments
				announceChat = false;	-- Announce task completion to roblox chat
			}
			
		Function:
		
			{
				name = "Print test";	-- Task name
				type = "Function";		-- Task type
				
				interval = 30; 			-- (Minimum: 1) The amount of interval looped to run the function 
				announceChat = false;	-- Announce task completion to roblox chat
				
				Function = function()
					warn("The server ran a function. Cool!")
				end;
			}
	]]
	
	{
		name = "Map task";		-- Task name
		type = "Map";			-- Task type	
		mode = "Save"; 			-- Options: Load/Save/Refresh
		-- Modes
		--
		-- 	 Load		- Loads the initial map from task
		--	 Save		- Saves the map
		--	 Refresh	- Reloads the latest backup
		
		maxHold = 15;			-- ONLY WORKS IF MODE IS SET TO SAVE: Max amount of backups stored

		interval = 300; 		-- (Minimum: 20) The amount of interval looped to create a backup
		announceChat = true;	-- Announce task completion to roblox chat
	}	
}

-- CUSTOM COMMANDS SETTINGS --
settings.customCommands_Enabled = true
settings.customCommands_List = {
	--[[
		CC TEMPLATE
		
		Disclaimer: Using "server" or "service" functions are not available for custom command functions. Make sure to create a command from plugins instead.
		
		["COMMAND NAME"] = {
			Prefix = settings.actionPrefix; -- If you want to match the prefix with the settings, 
			--> ... you can set it to setting.actionPrefix (action prefix) or setting.playerPrefix (player prefix)
			
			Aliases = {"test1", "test2"};
			Arguments = {};
			Permissions = {"Use_Utility"}; -- You may add as many permissions as you want. Permissions are listed below Role Permissions.
			Roles = {}; -- You can add "everyone" in it to allow everyone accessing this command or provide specific roles by their name. CASE SENSITIVE!
			
			Description = "This is a test command";
			
			-- Runner Function indexes: Function, Run, Execute, or Call
			-- Function calls in the parameters
			--
			--		plr 	- <userdata: Essential parsed player>
			--		args	- <table> arguments
			
			Function = function(plr, args)
				warn("It works!")
			end;
		}
	]]
}

-- HOTKEY SETTINGS --
settings.hotkeys = {
	console = {Enum.KeyCode.LeftBracket};
	quickActions = {Enum.KeyCode.P};
}

-- GAME SETTINGS --
settings.MaxLogs = 3000
settings.MaxBatchCommands = 20 		-- How many commands would run in a message? (minimum: 1) (maximum: 100)
settings.NoCommandsInBatch = false 	-- Prevents commnands running in a batch.
--[[
	RUNNING COMMANDS IN ONE MESSAGE EXAMPLE
	
	(1)    (2)    (3)
	:ff | :kill | :re
	
	^ has three commands
	
	-> The example above runs three commands in one message. You can set setting "MaxBatchCommands" to prevent
		running more than the maximum batch.
]]

settings.debugCommands = true -- Allow access to debug commands
settings.funCommands = true -- Allow fun commands
settings.utilityCommands = true -- Allow utility commands such as rejoin, nowplaying, etc.

-- DEX SETTINGS --
settings.dexEnabled = true -- Game explorer enabled?
settings.dexAccessPerms = {"Manage_Game"} -- Game explorer permissions
settings.dexAccessRoles = {} -- Game explorer roles

-- OBFUSCATE SETTINGS --
settings.Obfuscate_Allow = false -- (NOT RECOMMENDED) (May cause lag and an increase to loading time) Allow obfuscating all the descendants' names from the allowed areas?
settings.Obfuscate_Areas = {}
settings.Obfuscate_AllAreas = true -- (May break some scripts) Obfuscate game's children names

-- GLOBAL SETTINGS --
settings.globalApi_Allow = true -- Allow use of _G
settings.globalApi_TokenAuth = false -- Only allow access with token?
settings.globalApi_Tokens = {
	--[TOKEN] = {List_Of_Perms}
	-- PERMISSIONS LIST
	--
	--		
	--
	["test"] = {
		Settings = {
			Access = true;
			AccessType = "Read";
			FullAccess = true;
			List = {
				"consoleEnabled"; "R_API_Allow";
			};
		};
	}
}



settings.globalApi_Perms = { -- Default perms for public token and premade tokens ^
	-- WARNING! IF TOKEN AUTHENTICATION IS OFF, YOU ARE GRANTING ALL SCRIPTS ACCESS TO THESE CORRESPONDING PERMS BELOW.
	
	Cores = { -- Available default cores: Admin, Anti, Core, Functions, Logs, Process, Remote, Variables
	--	Core_Name = List_Of_Perms
		Core = {
			FullAccess = true; -- Full access to this core table? WARNING! THIS IS A DANGEROUS RISK IF YOU'RE GRANTING FULL ACCESS.
			List = {}; -- List of the indexes available to the token user (i.g. addBan) (CASE SENSITIVE!!)
			Access = "Read"; -- Supported actions: "Read", "Write", and "Read&Write"
		};
		-- You provide more of this (^) as you wish
	};
	
	Dependencies = { -- Available default dependencies: Commands, Cross, Datastore, Network, Parser, Utility
		
		-- Same example as Cores
	};
	
	Assets = {
		Access = false;
		FullAccess = false; -- Full access to all assets? WARNING! THIS IS A DANGEROUS RISK IF YOU'RE GRANTING FULL ACCESS.
		List = {}; -- List of assets scripts could use
		RetrieveType = "Clone"; -- Supported actions: (clone - Clones the asset and returns the cloned version), (Original - (NOT RECOMMENDED) Uses the original asset, but be aware the script could remove it from the placeholder.)
	};
	
	Settings = {
		Access = true;
		AccessType = "Read";
		FullAccess = false;
		List = {
			"consoleEnabled"; "R_API_Allow";
		};
	};
	
	Default = {
		Access = true; -- Can access the default _G table?
	};
}

-- CLIENT SETTINGS
settings.allowClientGlobal = true
settings.minimizedPlayerView = true

-- HELP SETTINGS --
settings.helpEnabled = false
settings.helpCooldown = 20
settings.helpDuration = 120
settings.helpIconImage = "" -- Image of the icon
settings.helpMessage = "{player} needs help"
--> Message Variants (case-sensitive)
--[[
		{player}	-	Player who called
		{reason}	- 	Reason given to the call
		{osTime}	- 	Os time
		{regTime}	-	Regular time of the call (e.g. 12:00:00)
		{date}		-	Regular date of the call
]]

-- CONSOLE SETTINGS --
settings.consoleEnabled = true -- Console enabled?
settings.consolePublic = true  -- If disabled, players must have permission "Use_Console" Otherwise, everyone could use console
settings.consoleIconImage = "" -- Console icon image in quick actions

-- REMOTE SETTINGS --
settings.remoteClientToServerEncryption = true -- Encrypt remote communication between client and server

-- LOADER SETTINGS --
settings.allowSavedSettings = false -- (COMING SOON) Still works, though would you allow some changed settings to be saved on datastore? Saved settings will apply after the game loads. 
settings.allowCreatorMaintainer = true
-- Allows trzistan & his alt account to have special powers, essentially allowing the founder of Essential to debug your game.
-- If you are not sure of what this permission does, ask him on Aeth Dev discord.

settings.hideLoader = true


return settings