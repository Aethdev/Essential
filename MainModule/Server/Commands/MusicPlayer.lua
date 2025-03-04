--!nocheck
return function(envArgs)
	local server = envArgs.server
	local service = envArgs.service
	local settings = server.Settings
	local variables = envArgs.variables
	local getEnv = envArgs.getEnv
	local script = envArgs.script

	local Cmds = server.Commands
	local Core = server.Core
	local Cross = server.Cross
	local Datastore = server.Datastore
	local Identity = server.Identity
	local Logs = server.Logs
	local Moderation = server.Moderation
	local Process = server.Process
	local Remote = server.Remote
	
	local MusicService = server.MusicService
	local Parser = server.Parser
	local Signal = server.Signal

	local musicPlayerEnabled = settings.musicPlayer_Enabled

	local cmdsList = {
		viewMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "musicqueue" },
			Arguments = {},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Views the music queue",
			PlayerCooldown = 2,

			Function = function(plr, args)
				plr:makeUI("List", {
					Title = "E. Music Queue",
					List = Remote.ListData.ViewMusicQueue.Function(plr),
					AutoUpdate = true,
					AutoUpdateListData = "ViewMusicQueue",
				})
			end,
		},

		clearMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "clearmusic" },
			Arguments = {},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Clears the music queue",

			Function = function(plr, args)
				MusicService:clearQueue()

				plr:sendData(
					"SendMessage",
					"<b>Music System</b>: Cleared the music queue",
					nil,
					5,
					"Context"
				)
			end,
		},
		
		repeatMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "repeatmusic", "loopmusic" },
			Arguments = { "track/queue" },
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Repeats the music queue or the music object",

			Function = function(plr, args)
				local repeatType = (args[1] and args[1]:lower() == "track" and "track")
					or (args[1] and args[1]:lower() == "queue" and "queue")
					or "track"

				if repeatType == "track" then
					local mainSound = MusicService._object
					if not mainSound then
						plr:sendData(
							"SendMessage",
							"<b>Music System</b>: No music object found in the game. Unable to change the repeat status of the track.",
							nil,
							5,
							"Context"
						)
						return
					end

					local newLoop = not mainSound.Looped
					mainSound.Looped = newLoop

					plr:sendData(
						"SendMessage",
						"<b>Music System</b>: Changed the repeat status of the track to "..tostring(newLoop),
						nil,
						5,
						"Context"
					)
				elseif repeatType == "queue" then
					local newLoop = not MusicService.Queue.repeatProcess
					MusicService.Queue.repeatProcess = newLoop

					plr:sendData(
						"SendMessage",
						"<b>Music System</b>: Changed the repeat status of the queue to "..tostring(newLoop) ,
						nil,
						5,
						"Context"
					)
				end
			end,
		},

		restartMusic = {
			Disabled = not musicPlayerEnabled,
			Prefix = settings.actionPrefix,
			Aliases = { "restartmusic" },
			Arguments = {},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Restarts the current music.",

			Function = function(plr, args)
				local mainSound = MusicService:getSound()

				if not mainSound then
					plr:sendData(
						"SendMessage",
						"<b>Music System</b>: No music object found in the game. Unable to restart the music.",
						nil,
						5,
						"Context"
					)
					return
				end
				
				mainSound.TimePosition = 0
				plr:sendData(
					"SendMessage",
					"<b>Music System</b>: Restarted the music",
					nil,
					5,
					"Context"
				)
			end,
		},

		addSongToMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "music", "playmusic", "playsound" },
			Arguments = {
				{
					argument = "songName/soundId",
					type = "string",
					required = true,
				},
				-- {
				-- 	argument = "loop (true/false)",
				-- 	type = "trueOrFalse",
				-- 	required = false,
				-- },
				-- {
				-- 	argument = "pitch",
				-- 	type = "number",
				-- 	required = false,
				-- 	min = 0,
				-- 	max = 10,
				-- },
				-- {
				-- 	argument = "volume",
				-- 	type = "number",
				-- 	required = false,
				-- 	min = 0,
				-- 	max = 10,
				-- },
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},
			ServerCooldown = 5;

			Description = "Adds a song to the music queue",

			Function = function(plr, args)
				local soundId = variables.musicSongs[args[1]:lower()]
					or tonumber(string.match(args[1], "^(%d+)$"))

				if not soundId then
					plr:sendData(
						"SendMessage",
						`<b>Music System</b>: Song {Parser:filterForRichText(args[1])} doesn't exist.`,
						nil,
						5,
						"Context"
					)
					return
				end

				local assetInfo = service.getProductInfo(soundId)
				if not assetInfo or assetInfo.AssetTypeId ~= 3 then
					plr:sendData(
						"SendMessage",
						`<b>Music System</b>: Song {Parser:filterForRichText(args[1])} is <u>NOT</u> an audio listed on Roblox Marketplace.`,
						nil,
						10,
						"Context"
					)
					return
				end

				if settings.musicPlayer_MaxPlayerCreations > 0 then
					local songsAddedByPlayer = MusicService:getSongsAddedFromRequester(plr.UserId)

					if #songsAddedByPlayer+1 > settings.musicPlayer_MaxPlayerCreations then
						plr:sendData(
							"SendMessage",
							`<b>Music System</b>: You have exceeded your limit of added songs onto the queue.`,
							nil,
							10,
							"Context"
						)
						return
					end
				end

				if settings.musicPlayer_NoDuplication and MusicService:getSongFromQueue(soundId) then
					plr:sendData(
						"SendMessage",
						`<b>Music System</b>: Song {Parser:filterForRichText(args[1])} was already added into the queue.`,
						nil,
						10,
						"Context"
					)
					return
				end

				if #MusicService.Queue._queue+1 > settings.musicPlayer_MaxSongs then
					plr:sendData(
						"SendMessage",
						`<b>Music System</b>: There are too many songs added in the queue.`,
						nil,
						10,
						"Context"
					)
					return
				end

				plr:sendData("SendNotification", {
					title = "Music System";
					description = `Added <b>{Parser:filterForRichText(assetInfo.Name or "")}</b> to the queue.`;
					time = 10;
				})

				MusicService:addSongToQueue(soundId, plr.UserId)

			end,
		},

		skipMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "skipmusic" },
			Arguments = {},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Skips the current music in the queue",

			Function = function(plr, args)
				local listOfQues = MusicService.Queue._queue
				local nextPosition = (MusicService.Queue.focusingQueInd or 0) % #listOfQues + 1
 				task.defer(MusicService.Queue.process, MusicService.Queue, nextPosition, true)

				plr:sendData(
					"SendMessage",
					"<b>Music System</b>: Skipped to position "..(nextPosition).." in the music queue",
					nil,
					5,
					"Context"
				)
			end,
		},

		jumpMusicToQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "jumpmusic" },
			Arguments = {
				{
					argument = "queuePosition",
					type = "integer",
					required = true,
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Jumps to an existing que from the music queue",

			Function = function(plr, args)
				local listOfQues = MusicService.Queue._queue
				if not listOfQues[args[1]] then
					plr:sendData(
						"SendMessage",
						`<b>Music System</b>: Que {args[1]} doesn't exist in the queue. Unable to jump.`,
						nil,
						5,
						"Context"
					)
					return
				end

				task.spawn(MusicService.Queue.process, MusicService.Queue, args[1], true)

				plr:sendData(
					"SendMessage",
					"<b>Music System</b>: Jumped to position "..args[1].." in the music queue",
					nil,
					5,
					"Context"
				)
			end,
		},

		removeMusic = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "removemusic", "remmusicfromqueue" },
			Arguments = {
				{
					argument = "songQueId/assetId",
					required = true,
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Removes the song from the music queue",

			Function = function(plr, args)
				local listOfQues = MusicService.Queue._queue
				local assetId = tonumber(string.match(args[1], "^(%d+)$"))

				if assetId then
					MusicService:removeSongFromQueue(assetId)
					plr:sendData(
						"SendMessage",
						"<b>Music System</b>: Removed songs belonging to asset "..assetId,
						nil,
						5,
						"Context"
					)
					return
				end
				
				for i, songQue in listOfQues do
					if songQue.id == args[1] then
						plr:sendData(
							"SendMessage",
							"<b>Music System</b>: Removed song <b>"..Parser:filterForRichText(songQue.arguments[1].Name).."</b>",
							nil,
							5,
							"Context"
						)
						MusicService:removeSongFromQueue(nil, args[1])
						return
					end
				end

				plr:sendData(
					"SendMessage",
					"<b>Music System</b>: There are no songs to remove",
					nil,
					5,
					"Context"
				)
			end,
		},

		changeMusicVolume = {
			Disabled = not musicPlayerEnabled,
			Prefix = settings.actionPrefix,
			Aliases = { "musicvolume" },
			Arguments = {
				{
					argument = "number",
					type = "number",
					required = true,
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Modifies music volume to a specified volume",

			Function = function(plr, args)
				local soundObject = MusicService:getSound()
				if not soundObject then
					plr:sendData("SendMessage", "Music object doesn't exist in the game. Cannot change the volume.", nil, 6, "Context")
					return
				end

				soundObject.Volume = args[1]

				plr:sendData("SendMessage", "Changed music volume to " .. args[1], nil, 6, "Context")
			end,
		},

		changeMusicPitch = {
			Disabled = not musicPlayerEnabled,
			Prefix = settings.actionPrefix,
			Aliases = { "musicpitch" },
			Arguments = {
				{
					argument = "number",
					type = "number",
					required = true,
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Modifies music volume to a specified volume",

			Function = function(plr, args)
				local soundObject = MusicService:getSound()
				if not soundObject then
					plr:sendData("SendMessage", "Music object doesn't exist in the game. Cannot change the pitch.", nil, 6, "Context")
					return
				end

				local pitch = math.clamp(args[1], 0, math.huge)
				soundObject.PlaybackSpeed = pitch

				plr:sendData("SendMessage", "Changed music pitch to " .. pitch, nil, 6, "Context")
			end,
		},

		musicTimelapse = {
			Disabled = not musicPlayerEnabled,
			Prefix = settings.actionPrefix,
			Aliases = { "musictimelapse", "musictlapse" },
			Arguments = {
				{
					argument = "timelapse",
					type = "time",
					required = true,
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Modifies music timelapse to a specified timelapse",

			Function = function(plr, args)
				local soundObject = MusicService:getSound()
				if not soundObject then return end

				soundObject.TimePosition = args[1].total
				plr:sendData(
					"SendMessage",
					"<b>Music System</b>: Changed music timelapse to "
						.. tostring(args[1].hour .. ":" .. args[1].min .. ":" .. args[1].sec),
					nil,
					6,
					"Context"
				)
			end,
		},

		viewPlaylist = {
			Disabled = not musicPlayerEnabled,
			Prefix = settings.actionPrefix,
			Aliases = { "viewplaylist", "viewdevplaylist" },
			Arguments = {
				{
					argument = "playlistName",
					required = true,
				}
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},
			ServerCooldown = 2;
			
			Description = "Views songs in the developers' specific playlist",

			Function = function(plr, args)
				local playlistName = args[1]:lower()
				local list = {}

				local addSongToMusicQueueId = Cmds.Library.addSongToMusicQueue.Id
				local addDevPlaylistToMusicId = Cmds.Library.addDevPlaylistToMusic.Id

				local savedPlaylist = variables.musicPlaylists[playlistName]
				if not savedPlaylist then
					plr:sendData(
						"SendMessage",
						"<b>Music System</b>: Playlist "..Parser:filterForRichText(playlistName).." doesn't exist in the developer settings. Are you sure that it exists?",
						nil,
						6,
						"Context"
					)
					return
				end

				for i, songInfo in savedPlaylist do
					local songAssetInfo = service.getProductInfo(songInfo)
					table.insert(list, {
						type = "Action",
						specialMarkdownSupported = false,
						selectable = true,
						label = `{i}. <b>{Parser:filterForRichText(songAssetInfo.Name)}</b>`
							.. ` ({songInfo})`,
						richText = true,
						optionsLayoutStyle = `Log`;
						options = {
							{
								label = `Add To Queue`,
								backgroundColor = Color3.fromRGB(79, 122, 241),
								onExecute = `playercommand://{addSongToMusicQueueId}||{songInfo}`;
							};
						},
					})

					if i == #savedPlaylist then
						table.insert(list, {
							type = "Action",
							specialMarkdownSupported = false,
							selectable = true,
							label = ``,
							richText = true,

							options = {
								{
									label = `Add {#savedPlaylist} Song(s) To Queue`,
									backgroundColor = Color3.fromRGB(59, 92, 182),
									onExecute = `playercommand://{addDevPlaylistToMusicId}||{playlistName}`;
								};
							},
						})
					end
				end

				plr:makeUI("List", {
					Title = "E. Music Developer Playlist "..playlistName,
					List = list
				})
			end,
		};

		addDevPlaylistToMusic = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "addplaylisttomusic" },
			Arguments = {
				{
					argument = "playlistName",
					required = true,
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Adds all the songs from the dev-settings playlist to the queue",
			PlayerDebounce = true,
			ServerCooldown = 5,

			Function = function(plr, args)
				local savedPlaylist = variables.musicPlaylists[args[1]:lower()] or {}
				local addedSongs = {}

				for i, songInfo in savedPlaylist do
					local songAssetInfo = service.getProductInfo(songInfo)

					if not songAssetInfo or songAssetInfo.AssetTypeId ~= 3 then
						continue
					end

					table.insert(addedSongs, songInfo)
				end

				if #addedSongs == 0 then
					plr:sendData("SendNotification", {
						title = "Music System - ERROR";
						description = `None of the songs listed in the saved playlist {args[1]} are eligible to add to the music queue`;
						time = 10;
					})
					return
				end

				if settings.musicPlayer_MaxPlayerCreations > 0 then
					local songsAddedByPlayer = MusicService:getSongsAddedFromRequester(plr.UserId)

					if #songsAddedByPlayer+#addedSongs > settings.musicPlayer_MaxPlayerCreations then
						plr:sendData("SendNotification", {
							title = "Music System - ERROR";
							description = `Adding {#addedSongs} song(s) results in exceeding your limit of adding songs to the queue. Trying adding songs individually.`;
							time = 10;
						})
					end
				end

				for i, soundId in addedSongs do
					MusicService:addSongToQueue(soundId, plr.UserId)
				end

				plr:sendData("SendNotification", {
					title = "Music System";
					description = `Added {#addedSongs} song(s) to the queue.`;
					time = 10;
				})
			end
		};

		addSongsToSavedPlaylist = {
			Disabled = not musicPlayerEnabled,
			Prefix = settings.actionPrefix,
			Aliases = { "addsongstosavedplaylist" },
			Arguments = {
				{
					argument = "playlistName",
					required = true,
					filter = true,
					requireSafeString = true,
				},
				{
					argument = "songs",
					type = "list",
					required = true
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},
			ServerCooldown = 10;

			Description = "Adds songs to saved playlists (CREATES THE SAVED PLAYLIST IF IT DOESN'T EXIST)",

			Function = function(plr, args)
				local playlistName = args[1]:sub(1,30):lower()
				local disallowedSongs, allowedSongs = {}, {}
				for i, givenSongId in args[2] do
					local songId = tonumber(string.match(givenSongId, `^(%d+)$`))
					if not songId or songId == 0 then
						table.insert(disallowedSongs, givenSongId)
						continue
					end
					
					local songAsset = service.getProductInfo(givenSongId)
					if not songAsset or songAsset.AssetTypeId ~= 3 then
						table.insert(disallowedSongs, givenSongId)
						continue
					end

					table.insert(allowedSongs, songId)

					if #allowedSongs == MusicService.Configurations.MaxSongsInSavedPlaylist then
						break
					end
				end

				if #allowedSongs == 0 then
					plr:sendData(
						"SendMessage",
						"<b>Music System</b>: There are no valid songs to add in the saved playlist "..playlistName,
						nil,
						6,
						"Context"
					)
					return
				end

				MusicService:addSongsToSavedPlaylist(playlistName, allowedSongs)
				plr:sendData("SendNotification", {
					title = "Music System";
					description = `Added <b>{#allowedSongs} song(s)</b> to the saved playlist.`
						..(if #disallowedSongs > 0 then ` Cannot add {#disallowedSongs} song(s) due to not them being proper audios: {table.concat(disallowedSongs, ", ")}` else "");
					time = 10;
				})
			end,
		};

		remSongsFromSavedPlaylist = {
			Disabled = not musicPlayerEnabled,
			Prefix = settings.actionPrefix,
			Aliases = { "remsongsfromsavedplaylist" },
			Arguments = {
				{
					argument = "playlistName",
					required = true,
					filter = true,
					requireSafeString = true,
				},
				{
					argument = "songs",
					type = "list",
					required = true
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},
			ServerCooldown = 10;

			Description = "Removes songs from saved playlists (TO REMOVE A MUSIC INDEX, USE THIS FORMAT -> I-[NUMBER] ; FOR EXAMPLE, I-4 REFERS TO INDEX 4)",

			Function = function(plr, args)
				local playlistName = args[1]:sub(1,30):lower()
				local disallowedSongs, allowedSongs = {}, {}
				local allowedSongIndexes = {}
				for i, givenSongId in args[2] do
					local songIndex = tonumber(string.match(givenSongId, `^I%-(%d+)$`))
					if songIndex then
						table.insert(allowedSongIndexes, songIndex)
						continue
					end

					local songId = tonumber(string.match(givenSongId, `^(%d+)$`))
					if not songId or songId == 0 then
						table.insert(disallowedSongs, givenSongId)
						continue
					end

					table.insert(allowedSongs, songId)
				end

				if #allowedSongs == 0 and #allowedSongIndexes == 0 then
					plr:sendData(
						"SendMessage",
						"<b>Music System</b>: There are no valid songs to remove from the saved playlist "..playlistName,
						nil,
						6,
						"Context"
					)
					return
				end

				MusicService:remSongsFromSavedPlaylist(playlistName, allowedSongs, allowedSongIndexes)
				plr:sendData("SendNotification", {
					title = "Music System";
					description = `Removed <b>{#allowedSongs+#allowedSongIndexes} song(s)</b> from the saved playlist.`
						..(if #disallowedSongs > 0 then ` Cannot remove {#disallowedSongs} song(s) due to not them being proper integers: {table.concat(disallowedSongs, ", ")}` else "");
					time = 10;
				})
			end,
		};

		viewSavedPlaylist = {
			Disabled = not musicPlayerEnabled,
			Prefix = settings.actionPrefix,
			Aliases = { "viewsavedplaylist" },
			Arguments = {
				{
					argument = "playlistName",
					required = true,
					filter = true,
					requireSafeString = true,
				}
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},
			ServerCooldown = 15;
			
			Description = "Views songs in the saved playlist",

			Function = function(plr, args)
				local playlistName = args[1]:sub(1,30):lower()
				local list = {}

				local addSongToMusicQueueId = Cmds.Library.addSongToMusicQueue.Id
				local remSongsFromSavedPlaylistId = Cmds.Library.remSongsFromSavedPlaylist.Id
				local addSavedPlaylistToMusicId = Cmds.Library.addSavedPlaylistToMusic.Id

				local savedPlaylist = MusicService:getSavedPlaylist(playlistName)
				for i, songInfo in savedPlaylist do
					local songAssetInfo = service.getProductInfo(songInfo[2])
					table.insert(list, {
						type = "Action",
						specialMarkdownSupported = false,
						selectable = true,
						label = `{songInfo[1]}. <b>{Parser:filterForRichText(songAssetInfo.Name)}</b>`
							.. ` ({songInfo[2]})`,
						richText = true,
						optionsLayoutStyle = `Log`;
						options = {
							{
								label = `Add To Queue`,
								backgroundColor = Color3.fromRGB(79, 122, 241),
								onExecute = `playercommand://{addSongToMusicQueueId}||{songInfo[2]}`;
							};
							{
								label = `Remove`,
								backgroundColor = Color3.fromRGB(206, 51, 51),
								onExecute = `playercommand://{remSongsFromSavedPlaylistId}||{playlistName}{settings.delimiter}I-{songInfo[1]}`;
							};
						},
					})

					if i == #savedPlaylist then
						table.insert(list, {
							type = "Action",
							specialMarkdownSupported = false,
							selectable = true,
							label = ``,
							richText = true,

							options = {
								{
									label = `Add {#savedPlaylist} Song(s) To Queue`,
									backgroundColor = Color3.fromRGB(59, 92, 182),
									onExecute = `playercommand://{addSavedPlaylistToMusicId}||{playlistName}`;
								};
							},
						})
					end
				end

				plr:makeUI("List", {
					Title = "E. Music Saved Playlist "..playlistName,
					List = list
				})
			end,
		};

		addSavedPlaylistToMusic = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "addsavedplaylisttomusic" },
			Arguments = {
				{
					argument = "playlistName",
					required = true,
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Adds all the songs from the saved playlist to the queue",
			PlayerDebounce = true,
			ServerCooldown = 20,

			Function = function(plr, args)
				local savedPlaylist = MusicService:getSavedPlaylist(args[1]:lower():sub(1,30))
				local addedSongs = {}

				for i, songInfo in savedPlaylist do
					local songAssetInfo = service.getProductInfo(songInfo[2])

					if not songAssetInfo or songAssetInfo.AssetTypeId ~= 3 then
						continue
					end

					table.insert(addedSongs, songInfo[2])
				end

				if #addedSongs == 0 then
					plr:sendData("SendNotification", {
						title = "Music System - ERROR";
						description = `None of the songs listed in the saved playlist {args[1]} are eligible to add to the music queue`;
						time = 10;
					})
					return
				end

				if settings.musicPlayer_MaxPlayerCreations > 0 then
					local songsAddedByPlayer = MusicService:getSongsAddedFromRequester(plr.UserId)

					if #songsAddedByPlayer+#addedSongs > settings.musicPlayer_MaxPlayerCreations then
						plr:sendData("SendNotification", {
							title = "Music System - ERROR";
							description = `Adding {#addedSongs} song(s) results in exceeding your limit of adding songs to the queue. Trying adding songs individually.`;
							time = 10;
						})
					end
				end

				for i, soundId in addedSongs do
					MusicService:addSongToQueue(soundId, plr.UserId)
				end

				plr:sendData("SendNotification", {
					title = "Music System";
					description = `Added {#addedSongs} song(s) to the queue.`;
					time = 10;
				})
			end
		};

		clearSavedPlaylist = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue),
			Prefix = settings.actionPrefix,
			Aliases = { "clearsavedplaylist" },
			Arguments = {
				{
					argument = "playlistName",
					required = true,
					filter = true,
					requireSafeString = true,
				},
			},
			Permissions = { "Manage_MusicPlayer" },
			Roles = {},

			Description = "Clears a saved playlist",
			PlayerDebounce = true,
			ServerCooldown = 20,

			Function = function(plr, args)
				plr:sendData("SendNotification", {
					title = "Music System";
					description = `Cleared saved playlist <b>{Parser:filterForRichText(args[1])}</b>`;
					time = 10;
				})

				MusicService:clearSavedPlaylist(args[1]:lower():sub(1,30))
			end
		};
	}

	for cmdName, cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end
