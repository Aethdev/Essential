-- Essential changelog

return {
	lastUpdated = 1691049152,
	updateDuration = 60 * 60 * 24 * 7, -- 1 week
	updateVers = "0.6.2 pre-release 1",
	updateInformation = {
		"Check back later during the full release to see the full changelog of the update",
		--"<u>Utility</u>";
		--"- Increased player cooldown for {$actionprefix}cmds to 4 seconds instead of 2 seconds";
		--"- Hidden commands are no longer shown in the console bar";
		--"- Added five client settings commands: {$selfprefix}settings, {$selfprefix}shortcuts, {$selfprefix}ccaliases, & {$selfprefix}actionaliases, {$selfprefix}keybinds";
		--"";
		--"<u>Processing</u>";
		--"- Players who attempt to execute a hidden command with insufficient permissions no longer sees insufficient permission error. Instead, they see 'Unable to execute' error.";
		--"- Decreased the char limit for updating/editing Shortcuts/Action Aliases/Keybinds' command execution input to 700 instead of 1000.";
		--"  - Existing saved command execution inputs are not affected by this change until the user manages to update them in client settings";
		--"";
		--"<u>Administration</u>";
		--"- List of game servers command {$actionprefix}gameservers now highlights the current server you are in";
		--"- Fixed softshutdown command moderator reason";
		--"- Roles list can now display offline usernames (role property 'hideofflineplayers' will hide offline usernames)";
		--"  - Only supports binded users/players in the role, not for integrated assignments (e.g. group ranks)";
		--"";
		--"<u>Parser</u>";
		--"- Added a new target selector called 'genuines', targeting players who are verified (non-voip numbers or ID verified)";
		--"";
		--"<u>Datastore</u>";
		--"- Reduced datastore write queue cooldown to 10 seconds instead of 12 seconds";
		--"- Reduced datastore overwrite & read queue cooldown to 8 seconds instead of 10 seconds";
		--"";
		--"<u>⭐ End-to-end Encryption [BETA]</u>";
		--"- ETEE communication has finally arrived to Essential main network and sub networks. With end to end encryption enabled, it is almost impossible for third party scripts to fully";
		--"  access your transmitted data and log them. Essential uses AES-128 encryption and Level-1 decompression to encrypt the communication line betweeen the";
		--"  server and client. In the event of a third party penetrating through Essential's main network, they have no chance to read the original transmitted data.";
		--"  Even if you were to verify through the main network while it's being penetrated by third party scripts, the Essential client will detect that the returned";
		--"  verified data is not authentic by checking the integrity of the hashed data. If you were to utilize a third party client executor, for instance, Synapse X,";
		--"  it is quite possible to retrieve the encryption keys to unlock the transmitted data. Third-party script remote loggers can retrieve the access key of the client,";
		--"  but rest assure that the access key is revoked after verification.";
		--"";
		--"<u>⭐ Keybinds</u>";
		--"After a few years of developing Essential, Essential has finally released command keybinds. The keybinds UI allows you to create up to three hotkeys for one keybind register.";
		--"Unlike Essential, Adonis and few other competitors support two or less hotkeys for one keybind register. Keybinds also support your custom command aliases and action aliases";
		--"to trigger commands. You can create up to 20 keybinds, less than a 1/4 of the maximum shortcuts creations. By default, everyone's keybinds setting is disabled. Newer players";
		--"have keybinds enabled under client settings.";
		--"<i>Final Note: Keybinds are now supported on console and also supports gamepad functionality. Hold duration is finally supported thanks to a new feature in client Utility.</i>";
		--"";
		--"<u>⭐ Core commands for keybinds/shortcuts</u>";
		--"In addition to the keybinds functionality, Essential has added three core commands that utilizes Mute on AFK system:";
		--"• {$selfprefix}togglemuteonafk -> Toggles mute state via Mute on AFK";
		--"• {$selfprefix}startmuteonafk -> Enables mute state via Mute on AFK";
		--"• {$selfprefix}endmuteonafk  -> Disables mute state via Mute on AFK";
		--"Keep in mind that these commands are only functionable/executable on shortcuts and keybinds.";
		--"<i>Prerequisite: The client has enabled Mute on AFK via client settings</i>";
		--"";
		"<u>⭐ Credits & Attributions</u>",
		"Attributions has arrived to Essential. View the contributors of Essential by opening {$selfprefix}credits",
		"",
		'<font size="15"><b> To open client settings, hover over the E button, colored in dark blue, on the top right corner of your screen, and press Client Settings. Alternatively, you can '
			.. "press P on your keyboard to toggle the visiblity of E. Quick actions.</b></font>",
		-- 2022 update
		--"<u>Datastore</u>";
		--"- Added datastore compression to Essential. Compression has enhanced the availability to store more data thanks to ZLib.";
		--"- Datastore encryption now uses a faster base 64 encoder/decoder thanks to github@Reselim";
		--"- Datastore write queues restarts after a few attempts of not saving data. This new change empowers Essential to continue data-saving";
		--"  without clearing the ques.";
		--"";
		--"<u>Character commands</u>";
		--"- Added a new argument 'saveItems' for respawn command";
		--"";
		--"<u>Target selectors</u>";
		--"- Fixed a problem with target selector `limit-limit_count` removing the last player in the selected players after removing the extras";
		--"- Fixed a string pattern issue when targeting players with partial user name `!partial_user_name`. This bug led to problems targeting players with";
		--"  partial usernames.";
		--"";
		--"<u>Filtering</u>";
		--"- Fixed the issue with Filter module returning the exact value of filtered boolean sentences, instead of the opposite value, if they are equal to the entire string";
		--"    - This led to problems with arguments requiring safe string returning as nil";
		--"- Fixed the issue where the Filter module couldn't replace the string with the cached sentences with a character for string patterns like `%`";
		--"";
		--"<u>Processing</u>";
		--"- Fixed the issue where debounce is not registered before/while running commands if the property is enabled. Several commands has debounce enabled; however,";
		--"  the Core command registry couldn't register and remove the debounce cache.";
		--"";
		--"<u>Player Utility</u>";
		--"- Increased the max creation limits for aliases, action aliases, & custom command aliases";
		--"  - Action Aliases: 20 → 30";
		--"  - Custom Command Aliases: 30 → 40";
		--"  - Shortcuts: 12 → 20";
		--"- Increased the command line char limit for these personal utilities like action aliases to 1,000 from 500";
		--"";
		--"<u>Direct Messages</u>";
		--"- Direct messages is now available to Essential. DMing players is an advantage to send messages to them anywhere and can be read upon opening the notification.";
		--"- Players with permission 'Private_Messaging' could use the command {$actionprefix}dm or {$actionprefix}directmessage. It utilizes the same arguments as ${actionprefix}pm.";
		--"  However, this command has to update the targets' player data which includes a server cooldown for 4 seconds to reduce spamming it.";
		--"- Direct message is not deleted from notifications until the recipient has read the message";
		--"- Receiving direct messages can take up to a minute depending on the time the recipient's player data was last updated";
		--"- Opening the dm marks it on read which stops from notifying again";
		--"- 10 minutes is the duration of the direct message before its gone after opening it";
		--"";
		"",
		"",
		"<i>Thank you for utilizing Essential. To see this changelog again, do {$selfprefix}changelog.</i>. View the attributions and credits of Essential by doing {$selfprefix}credits",
		"",
		"<b>Background Information</b>",
		"Essential is <u>NOT</u> open-source nor sold for robux/third-party payments. It's a private administration system, cooperated by trzistan, enhancing",
		"-the utility and administration for players with the use of minimal performance. Unlike Adonis and other admin systems, Essential runs in a hidden background",
		"-and safely hides script errors to prevent compromising its script location. It's designed to run each core and dependency using their cloned version.",
		"Therefore, none of the plugins and important modules become compromised to other scripts (scripts that aren't affiliated with Essential).",
		"",
		"We also value the security of our players and networks to ensure scripts are not disruptly interfering with players' connection to the main network. Players",
		"have a wider chance of utilizing Essential freely. Each player is assigned to a random network (40 main networks). In addition, scripts have a hard time finding",
		"a main network shared by all players and start firing malicious calls.",
	},
}
