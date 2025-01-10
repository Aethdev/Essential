
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
	
	local Parser = server.Parser
	local Signal = server.Signal
	
	local musicLoop = false
	local musicPlayerEnabled = settings.musicPlayer_Enabled
	local musicPlayerQueue = server.Queue.new()
	--musicPlayerQueue.debug = true
	musicPlayerQueue.active = (musicPlayerEnabled and true)
	musicPlayerQueue.clearFinishedQuesAfterProcess = false
	musicPlayerQueue.maxQueue = math.floor(math.clamp(settings.musicPlayer_MaxSongs or 0, 1, math.huge))
	musicPlayerQueue.repeatProcess = false
	musicPlayerQueue.ignoreProcessedQues = false
	musicPlayerQueue.processFunc = function(ind, que, musicId, creatorId)
		if que.active then
			local musicInfo = service.getProductInfo(musicId)
			
			local creatorP = service.getPlayer(creatorId)
			local parsedCreator = creatorP and Parser:apifyPlayer(creatorP)
			local songAnnouncement = settings.musicPlayer_SongAnnouncement
			local songMessage = "Now playing <b>"..Parser:filterForRichText(musicInfo.Name).."</b> ("..tostring(musicId)..")"

			if songAnnouncement then
				for i,parsedPlr in pairs(service.getPlayers(true)) do
					parsedPlr:sendData("SendMessage", songMessage, nil, 8, "Context")
					--parsedPlr:sendData("SendMessage", "Music player", songMessage, 8, "Hint")
				end
			else
				if parsedCreator then
					parsedCreator:sendData("SendMessage", songMessage, nil, 8, "Context")
					--parsedCreator:sendData("SendMessage", "Music player", songMessage, 8, "Hint")
				end
			end

			local mainSound,soundData = server.Utility:getMainSound(true)
			local confirmSignal = Signal.new()
			local movedOn = false

			variables.music_nowPlaying_name = musicInfo.Name
			variables.music_nowPlaying_id = musicId

			mainSound.SoundId = "rbxassetid://"..musicId
			mainSound.TimePosition = 0
			mainSound.Looped = musicLoop
			mainSound:Play()

			que.removed:connectOnce(function()
				if not movedOn then
					mainSound:Stop()
					confirmSignal:fire()
				end
			end)

			que.ignored:connectOnce(function()
				if not movedOn then
					mainSound:Stop()
					confirmSignal:fire()
				end
			end)

			soundData.ended:connectOnce(function()
				if not movedOn then
					confirmSignal:fire()
				end
			end)
			
			soundData.destroyed:connectOnce(function()
				if not movedOn then
					mainSound:Stop()
					confirmSignal:fire()
				end
			end)

			confirmSignal:wait()
			movedOn = true
			wait(.2)
		end
	end

	musicPlayerQueue.processIdle:connect(function()
		local mainSound = server.Utility:getMainSound()

		if mainSound then
			mainSound.SoundId = ""
			mainSound.TimePosition = 0
			mainSound:Stop()
		end

		variables.music_nowPlaying_name = nil
		variables.music_nowPlaying_id = 0
	end)
	
	local cmdsList = {
		playMusic = {
			Disabled = not musicPlayerEnabled;
			Prefix = settings.actionPrefix;
			Aliases = {"music", "playsound", "playmusic"};
			Arguments = {
				{
					argument = "soundId/songName";
					required = true;
				},
				{
					argument = "loop (true/false)";
					type = "trueOrFalse";
				},
				{
					argument = "pitch";
					type = "number";
				},
				{
					argument = "volume";
					type = "number";
				},
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Plays music with modified arguments";

			Function = function(plr, args)
				local songId = variables.musicSongs[args[1]:lower()]
				local musicId = songId or tonumber(args[1]) or 0
				local bannedSong = table.find(settings.musicPlayer_BannedSongs, musicId)

				if bannedSong then
					if plr then
						plr:sendData("SendMessage", "Music Player", "Music id <b>"..tostring(args[1]).."</b> is banned and cannot be played.", 6, "Hint")
					end

					return
				end

				local assetInfo = service.getProductInfo(musicId) or {}

				if not assetInfo or assetInfo.AssetTypeId ~= 3 then
					plr:sendData("SendMessage", "Asset collection error", "<b>"..args[1].."</b> isn't an audio", 6, "Hint")

					return
				end

				-- Check banned song creator
				local userCreator = assetInfo.Creator.CreatorType == "User"
				if not userCreator then
					local groupInfo = service.getGroupInfo(assetInfo.Creator.Id)

					if groupInfo and groupInfo.Id then
						if Identity.checkTable(groupInfo.Owner.Id, settings.musicPlayer_BannedCreators) then
							plr:sendData("SendMessage", "Music Player", "Songs from creator <b>"..groupInfo.Owner.Name.."</b> are banned from being played.", 6, "Hint")
							return
						end
					end
				else
					if Identity.checkTable(assetInfo.Creator.Id, settings.musicPlayer_BannedCreators) then
						plr:sendData("SendMessage", "Music Player", "Songs from creator <b>"..assetInfo.Creator.Name.."</b> are banned from being played.", 6, "Hint")
						return
					end
				end

				local queueEnabled = settings.musicPlayer_Queue
				local noDuplication = settings.musicPlayer_NoDuplication
				local maxPlayerCreation = math.floor(math.clamp(settings.musicPlayer_MaxPlayerCreations, 1, math.huge))

				if queueEnabled then
					if noDuplication then
						for i,que in pairs(musicPlayerQueue._queue) do
							if que.arguments[1] == musicId then
								plr:sendData("SendMessage", "Music player", "This song was already added in the queue. Pick another song.", 5, "Hint")
								return
							end
						end
					end

					local creationCount = 0
					if plr then
						for i,que in pairs(musicPlayerQueue._queue)	do
							if que.arguments[2] == plr.UserId then
								creationCount += 1
							end
						end
					end

					if creationCount+1 > maxPlayerCreation then
						plr:sendData("SendMessage", "Music player", "You can't add more songs to the queue. Try removing some of your added songs from the queue via command "..settings.actionPrefix.."removemusic", 5, "Hint")
						return
					end

					local queData = musicPlayerQueue:add(songId or tonumber(args[1]), plr.UserId)

					if queData then
						plr:sendData("SendMessage", "Music player", "Added "..(songId or args[1]).." to queue. Your song will play soon once it's chosen in the queue.", 5, "Hint")
					else
						plr:sendData("SendMessage", "Music player", "Oops! The queue is currently full. Try again later.", 5, "Hint")
					end
				else
					local announceSongs = settings.musicPlayer_SongAnnouncement
					local songMessage = "Now playing "..assetInfo.Name.." ("..(songId or args[1])..")"
					
					if announceSongs then
						for i,parsedPlr in pairs(service.getPlayers(true)) do
							parsedPlr:sendData("SendMessage", "Music player", songMessage, 4, "Hint")
						end
					else
						plr:sendData("SendMessage", "Music player", songMessage, 4, "Hint")
					end
					
					local mainSound = server.Utility:getMainSound(true)

					mainSound.TimePosition = 0
					mainSound.SoundId = "rbxassetid://"..(songId or args[1])

					if args[2] then
						mainSound.Looped = args[2]
					end

					if args[3] then
						mainSound.PlaybackSpeed = args[3]
					end

					if args[4] then
						mainSound.Volume = math.clamp(args[4], 0, 4)
					end

					variables.music_nowPlaying_name = assetInfo.Name
					variables.music_nowPlaying_id = assetInfo.AssetId

					mainSound:Play()
				end
			end;
		};

		pauseMusic = {
			Disabled = not musicPlayerEnabled;
			Prefix = settings.actionPrefix;
			Aliases = {"pauseMusic"};
			Arguments = {};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Pauses music";

			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()

				if mainSound then
					mainSound:Pause()

					plr:sendData("SendMessage", "Music player", "Paused music", 4, "Hint")
				end
			end;
		};

		resumeMusic = {
			Disabled = not musicPlayerEnabled;
			Prefix = settings.actionPrefix;
			Aliases = {"resumeMusic"};
			Arguments = {};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Pauses music";

			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()

				if mainSound then
					mainSound:Resume()

					plr:sendData("SendMessage", "Music player", "Resumed music", 4, "Hint")
				end
			end;
		};

		stopMusic = {
			Disabled = not musicPlayerEnabled;
			Prefix = settings.actionPrefix;
			Aliases = {"stopMusic"};
			Arguments = {};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Stops the current music";

			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()
				if not mainSound then
					plr:sendData("SendMessage", "Music player", "Can't perform action if there's no music in game.", 4, "Hint")
					return
				end

				mainSound:Stop()
				plr:sendData("SendMessage", "Music player", "Stopped music", 4, "Hint")
			end;
		};

		repeatMusic = {
			Disabled = not musicPlayerEnabled;
			Prefix = settings.actionPrefix;
			Aliases = {"repeatmusic", "loopmusic"};
			Arguments = {"type (track/queue)"};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Repeats the current track or queue.";

			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()

				-- If no argument 1, show repeat statuses only
				if not args[1] then
					plr:sendData("SendMessage", "Music player | Repeat statuses", "Queue: "..tostring(musicPlayerQueue.repeatProcess).." | Track: "..tostring(musicLoop), 8, "Hint")
					return
				end

				local repeatType = (args[1] and args[1]:lower()=="track" and "track") or
					(args[1] and args[1]:lower()=="queue" and "queue") or "track"

				if repeatType == "track" then
					if not mainSound then
						plr:sendData("SendMessage", "Music player", "Can't change the track's repeat status if there's no music in game.", 4, "Hint")
						return
					end

					local newLoop = not mainSound.Looped
					mainSound.Looped = newLoop
					musicLoop = newLoop

					plr:sendData("SendMessage", "Music player", "Changed repeat status for tracks to "..tostring(newLoop), 4, "Hint")
				elseif repeatType == "queue" then
					local newLoop = not musicPlayerQueue.repeatProcess
					musicPlayerQueue.repeatProcess = newLoop
					
					plr:sendData("SendMessage", "Music player", "Changed repeat status for queue to "..tostring(newLoop), 4, "Hint")
				end
			end,
		};

		restartMusic = {
			Disabled = not musicPlayerEnabled;
			Prefix = settings.actionPrefix;
			Aliases = {"restartmusic"};
			Arguments = {};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Restarts the current music.";

			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()

				if mainSound then
					if variables.music_nowPlaying_id and variables.music_nowPlaying_id > 0 then
						mainSound.SoundId = "rbxassetid://"..variables.music_nowPlaying_id
						mainSound.TimePosition = 0
						mainSound:Play()
						plr:sendData("SendMessage", "Music player", "Restarted music", 4, "Hint")
					end
				end
			end;
		};

		restartMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"restartmusicqueue"};
			Arguments = {};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Restarts the music queue";

			Function = function(plr, args)
				if #musicPlayerQueue._queue == 0 then
					plr:sendData("SendMessage", "Music player", "The queue is empty. There's nothing to restart.", 4, "Hint")
				else
					coroutine.wrap(musicPlayerQueue.process)(musicPlayerQueue, 1, true)
					plr:sendData("SendMessage", "Music player", "Restarted the queue.", 4, "Hint")
				end
			end,
		};

		clearMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"clearmusic"};
			Arguments = {};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Clears the music queue";

			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()

				if mainSound then
					mainSound:Stop()
					mainSound.SoundId = ""
					mainSound.TimePosition = 0
				end

				if #musicPlayerQueue._queue > 0 then
					musicPlayerQueue:clear()
					plr:sendData("SendMessage", "Music player", "Cleared the queue", 5, "Hint")
				else
					plr:sendData("SendMessage", "Music player", "There's nothing to clear. Are you sure there was music added to the queue?", 5, "Hint")
				end
			end;
		};

		skipMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"skipmusic"};
			Arguments = {};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Skips the ongoing music via queue";

			Function = function(plr, args)
				local queue = musicPlayerQueue._queue

				if #queue > 0 then
					local queTab = musicPlayerQueue.focusingQueTab

					if not queTab then
						plr:sendData("SendMessage", "Music player", "The queue isn't playing and there's nothing to skip. Restart the queue by "..settings.actionPrefix.."restartmusic", 3, "Hint")
					else
						if queTab.active then
							local mainSound = server.Utility:getMainSound()

							if mainSound then
								mainSound:Stop()
								mainSound.SoundId = ""
								mainSound.TimePosition = 0
							end
							
							local newQueInd = musicPlayerQueue.focusingQueInd+1
							if musicPlayerQueue._queue[newQueInd] then
								musicPlayerQueue:process(musicPlayerQueue.focusingQueInd+1, true)
								plr:sendData("SendMessage", "Music player", "Skipped current music selection", 3, "Hint")
							else
								if musicPlayerQueue.repeatProcess and #musicPlayerQueue._queue > 0 then
									musicPlayerQueue:process(1, true)
									plr:sendData("SendMessage", "Music player", "Skipped current music selection", 3, "Hint")
								else
									queTab.ignored:fire()
									plr:sendData("SendMessage", "Music player", "There's nothing playing right now.", 3, "Hint")
								end
							end
							
							
						end

						
					end
				else
					plr:sendData("SendMessage", "Music player", "There's nothing in the queue. Are you sure there was music added to the queue?", 5, "Hint")
				end
			end;
		};

		jumpMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"jumpmusic"};
			Arguments = {
				{
					argument = "queuePosition";
					type = "integer";
					required = true;
				}	
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Jumps to an existing que from the music queue";
			PlayerCooldown = 2;

			Function = function(plr, args)
				local queue = musicPlayerQueue._queue

				if #queue > 0 then
					local jumpingQue = queue[args[1]]

					if jumpingQue then
						coroutine.wrap(function()
							musicPlayerQueue:process(args[1], true)
						end)()

						plr:sendData("SendMessage", "Music player", "Jumped to que position "..args[1], 4, "Hint")
					else
						plr:sendData("SendMessage", "Music player", "Que "..args[1].." doesn't exist. Unable to jump.", 4, "Hint")
					end
				else
					plr:sendData("SendMessage", "Music player", "There's nothing to jump. Are you sure there was music added to the queue?", 5, "Hint")
				end
			end;
		};

		removeMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"removemusic"};
			Arguments = {
				{
					argument = "queuePosition";
					type = "integer";
					required = true;
				}	
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Removes an existing que from the music queue";
			PlayerCooldown = 2;

			Function = function(plr, args)
				local queue = musicPlayerQueue._queue

				if #queue > 0 then
					local existingQue = queue[args[1]]

					if existingQue then
						musicPlayerQueue:remove(existingQue.id)
						plr:sendData("SendMessage", "Music player", "Removed que position "..args[1], 4, "Hint")
					else
						plr:sendData("SendMessage", "Music player", "Que "..args[1].." doesn't exist. Unable to remove.", 4, "Hint")
					end
				else
					plr:sendData("SendMessage", "Music player", "There's nothing to remove. Are you sure there was music added to the queue?", 5, "Hint")
				end
			end,
		};

		viewMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"musicqueue"};
			Arguments = {};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Views the music queue";
			PlayerCooldown = 2;

			Function = function(plr, args)
				local queue = musicPlayerQueue._queue

				if #queue > 0 then
					local queList = {}

					local function addEntryToList(text, desc, color)
						table.insert(queList, {
							Text = text;
							Desc = text or desc;
							Color = color;
						})
					end

					local mainSound = server.Utility:getMainSound()

					addEntryToList("-- Music Info --")
					local soundStat = 'paused/stopped'

					if mainSound and mainSound.IsPlaying then
						soundStat = 'playing'
					end

					if mainSound then
						local timeLapData = server.Parser:getTime(mainSound.TimePosition)
						local timelapse = server.Parser:formatTime(timeLapData.hours, timeLapData.mins, timeLapData.secs)

						local timeLenData = server.Parser:getTime(mainSound.TimeLength)
						local timelength = server.Parser:formatTime(timeLenData.hours, timeLenData.mins, timeLenData.secs)

						addEntryToList(timelapse.." / "..timelength.." - "..soundStat)
					else
						addEntryToList("Music wasn't created", nil, Color3.fromRGB(255, 67, 67))
					end


					addEntryToList("-- Now playing --")
					local nowPlayingFound = nil
					for ind,que in pairs(queue) do
						local queStatus = ''
						if musicPlayerQueue.focusingQueTab == que then
							local musicId,creatorId = unpack(que.arguments)
							local musicInfo = service.getProductInfo(musicId)
							local creatorName = service.playerNameFromId(creatorId) or "[unknown]"

							addEntryToList(tostring(ind)..". "..tostring(musicInfo.Name).." ("..musicId..")")
							addEntryToList(" - Added by "..creatorName)
							addEntryToList("")

							nowPlayingFound = true
							break
						end
					end

					if not nowPlayingFound then
						addEntryToList("Nothing playing right now.")
					end

					addEntryToList("-- Waiting queues --")
					for ind,que in pairs(queue) do
						if musicPlayerQueue.focusingQueTab ~= que then
							local musicId,creatorId = unpack(que.arguments)
							local musicInfo = service.getProductInfo(musicId)
							local creatorName = service.playerNameFromId(creatorId) or "[unknown]"

							addEntryToList(tostring(ind)..". "..tostring(musicInfo.Name).." ("..musicId..")")
							addEntryToList(" - Added by "..creatorName)
							addEntryToList("")
						end
					end

					plr:makeUI("ADONIS_LIST", {
						Title = "E. Music Queue";
						Table = queList;
						Size = {500, 400};
					})
				else
					plr:sendData("SendMessage", "Music player", "There's nothing playing nor added in the queue. Add more songs to see what's playing and added ones.", 4, "Hint")
				end
			end;
		};

		addPlaylistToMusicQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"addplaylist"};
			Arguments = {
				{
					argument = "playlistName";
					required = true;
					filter = true;
					requireSafeString = true;
				}	
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Adds songs from the specified playlist to the music queue";
			PlayerCooldown = 2;

			Function = function(plr, args)
				local songsQueue = musicPlayerQueue._queue
				local musicQueue = musicPlayerQueue

				local musicPlaylist = variables.musicPlaylists[args[1]:lower()]

				if not musicPlaylist then
					plr:sendData("SendMessage", "Music player", "Playlist <b>"..args[1].."</b> doesn't exist and cannot be added to the queue.", 6, "Hint")
					return	
				end

				if #musicPlaylist == 0 then
					plr:sendData("SendMessage", "Music player", "Playlist <b>"..args[1].."</b> doesn't have any songs added. Nothing has been added to the queue.", 6, "Hint")
					return	
				end

				local playerCreated = (function()
					local count = 0

					for i,que in pairs(songsQueue) do
						local musicId,creatorId = unpack(que.arguments)

						if creatorId == plr.UserId then
							count += 1
						end
					end

					return count
				end)()
				local songsCountInPlaylist = #musicPlaylist
				local maxCreations = settings.musicPlayer_MaxPlayerCreations-playerCreated
				local maxSongs = math.clamp(maxCreations, 0, math.clamp(songsCountInPlaylist, 0, settings.musicPlayer_MaxSongs-#songsQueue))
				local noSongDuplication = settings.musicPlayer_NoDuplication

				if maxSongs > 0 then
					local addedSongs = 0

					for i = 1,maxSongs,1 do
						local songIdFromPlaylist = tonumber(musicPlaylist[i])

						if songIdFromPlaylist then
							local musicInfo = service.getProductInfo(songIdFromPlaylist) or {}

							if musicInfo.AssetTypeId == 3 then
								if noSongDuplication then
									local skipAddition = false

									for d,songQue in pairs(songsQueue) do
										local musicId,creatorId = unpack(songQue.arguments)

										if musicId == songIdFromPlaylist then
											skipAddition = true
											break
										end
									end

									if skipAddition then
										continue
									end
								end

								musicQueue:add(songIdFromPlaylist, plr.UserId)
								addedSongs += 1
							end
						end
					end

					if addedSongs > 0 then
						plr:sendData("SendMessage", "Music player", "Added "..addedSongs.." songs from playlist <b>"..args[1].."</b>", 6, "Hint")
					else
						plr:sendData("SendMessage", "Music player", "There were no available songs from playlist <b>"..args[1].."</b> to add.", 4, "Hint")
					end
				else
					plr:sendData("SendMessage", "Music player", "There are no songs available to add. This is the amount of your added songs have exceeded the max player creations or queue is full.", 6, "Hint")
				end
			end;
		};

		viewMusicPlaylist = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"viewplaylist"};
			Arguments = {
				{
					argument = "playlistName";
					required = true;
					filter = true;
					requireSafeString = true;
				}	
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Views list of songs from specified music playlist";
			PlayerCooldown = 2;

			Function = function(plr, args)
				local songsQueue = musicPlayerQueue._queue
				local musicQueue = musicPlayerQueue

				local musicPlaylist = variables.musicPlaylists[args[1]:lower()]

				if not musicPlaylist then
					plr:sendData("SendMessage", "Music player", "Playlist <b>"..args[1].."</b> doesn't exist and cannot be viewed.", 6, "Hint")
					return	
				end

				if #musicPlaylist == 0 then
					plr:sendData("SendMessage", "Music player", "Playlist <b>"..args[1].."</b> doesn't have any songs added. There's no songs available to list.", 6, "Hint")
					return	
				end

				local songsList = {}

				for i,songId in pairs(musicPlaylist) do
					songId = tonumber(songId)

					if songId then
						local canUseSong = false
						local musicInfo = service.getProductInfo(songId) or {}

						if musicInfo.AssetTypeId == 3 then
							canUseSong = true
						end

						table.insert(songsList, {
							Text = (canUseSong and "✅" or "❌").." | ["..songId.."] - "..tostring(musicInfo.Name or "UNKNOWN SONG");
							Desc = (not canUseSong and "Song not available and cannot be played in the queue") or "Id: "..songId.." | "..tostring(musicInfo.Name);
							Color = (not canUseSong and Color3.fromRGB(255, 73, 73)) or nil;
						})
					end
				end

				plr:makeUI("ADONIS_LIST", {
					Title = "E. Music Playlist - "..args[1]:lower();
					Table = songsList;
					Size = {500, 400};
				})
			end;
		};

		musicPitch = {
			Disabled = not musicPlayerEnabled;
			Prefix = settings.actionPrefix;
			Aliases = {"musicPitch"};
			Arguments = {
				{
					argument = "number";
					type = "number";
					required = true;
				};
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Modifies music pitch to a specified pitch";

			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()

				if mainSound then
					local pitch = math.clamp(args[1], 0, math.huge)
					mainSound.PlaybackSpeed = pitch

					plr:sendData("SendMessage", "Music player", "Changed pitch to "..pitch, 4, "Hint")
				end
			end;
		};

		musicVolume = {
			Disabled = not musicPlayerEnabled;
			Prefix = settings.actionPrefix;
			Aliases = {"musicVolume"};
			Arguments = {
				{
					argument = "number";
					type = "number";
					required = true;
				};
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Modifies music volume to a specified volume";

			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()

				if mainSound then
					local pitch = math.clamp(args[1], 0, 4)
					mainSound.Volume = pitch

					plr:sendData("SendMessage", "Changed music volume to "..pitch, nil, 6, "Context")
				end
			end;
		};

		musicTimelapse = {
			Disabled = not musicPlayerEnabled;
			Prefix = settings.actionPrefix;
			Aliases = {"musicTimelapse", "musictlapse"};
			Arguments = {
				{
					argument = "timelapse";
					type = "time";
					required = true;
				};
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Modifies music timelapse to a specified timelapse";

			Function = function(plr, args)
				local mainSound = server.Utility:getMainSound()

				if mainSound then
					mainSound.TimePosition = args[1].total
					plr:sendData("SendMessage", "Changed music timelapse to "..tostring(args[1].hour..":"..args[1].min..":"..args[1].sec), nil, 6, "Context")
					--plr:sendData("SendMessage", "Music player", "Changed timelapse to "..tostring(args[1].hour..":"..args[1].min..":"..args[1].sec), 4, "Hint")
				end
			end;
		};

		musicList = {
			Prefix = settings.actionPrefix;
			Aliases = {"musiclist", "songs"};
			Arguments = {};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Lists songs from the developer settings";

			Function = function(plr, args)
				local songs = {}

				for songName,songId in pairs(settings.musicPlayer_Songs or {}) do
					local songInfo = service.getProductInfo(songId) or {}

					if songInfo.AssetTypeId ~= 3 then
						songInfo.Name = "Can't provide song name. It's either song doesn't exist or isn't a valid song."
					end

					table.insert(songs, {
						Text = "<b>"..songName.."</b> | "..songInfo.Name;
						Desc = songId;
					})
				end

				if #songs == 0 then
					plr:sendData("SendMessage", "Music list", "There are no songs to provide. Check with the developer if they had listed available songs.", 6, "Hint")
				else
					plr:makeUI("ADONIS_LIST", {
						Title = "E. Music List";
						Table = songs;
						RichText = true;
					})
				end
			end;
		};
		
		createSavedPlaylist = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"createSavedPlaylist"};
			Arguments = {
				{
					argument = "playlistName";
					required = true;
					filter = true;
					requireSafeString = true;
				}	
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Creates a saved playlist";
			PlayerDebounce = true;
			ServerCooldown = 20;
			
			Function = function(plr, args)
				if args[1]:find(settings.delimiter) then
					plr:sendData("SendMessage", "Music player management", "Playlist name must not have a delimiter", 10, "Hint")
					return -1,"ResetCooldown"
				elseif #args[1] > 30 then
					plr:sendData("SendMessage", "Music player management", "Playlist name must have up to 30 characters", 10, "Hint")
					return -1,"ResetCooldown"
				end
				
				local savedPlaylists = Datastore.read("Music", "SavedPlaylists") or {}
				
				if type(savedPlaylists) ~= "table" then
					savedPlaylists = {}
					Datastore.overWrite("Music", "SavedPlaylists", {})
				end
				
				if not savedPlaylists[args[1]] then
					plr:sendData("SendMessage", "Music player management", "Creating saved playlist "..args[1]..". Please wait.", 20, "Hint")
					Datastore.tableUpdate("Music", "SavedPlaylists", "Index", args[1], {}, nil, function()
						plr:sendData("SendMessage", "Music player management", "Successfully created saved playlist "..args[1], 8, "Hint")
					end)
				else
					plr:sendData("SendMessage", "Music player management", "Saved playlist "..args[1].." already exists.", 8, "Hint")
				end
			end;
		};
		
		viewSavedPlaylist = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"viewSavedPlaylist"};
			Arguments = {
				{
					argument = "playlistName";
					required = true;
					filter = true;
					requireSafeString = true;
				};
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Views a saved playlist";
			PlayerDebounce = true;
			ServerCooldown = 20;

			Function = function(plr, args)
				if args[1]:find(settings.delimiter) then
					plr:sendData("SendMessage", "Music player management", "Playlist name must not have a delimiter", 10, "Hint")
					return -1,"ResetCooldown"
				elseif #args[1] > 30 then
					plr:sendData("SendMessage", "Music player management", "Playlist name must have up to 30 characters", 10, "Hint")
					return -1,"ResetCooldown"
				end
				
				local savedPlaylists = Datastore.read("Music", "SavedPlaylists") or {}

				if type(savedPlaylists) ~= "table" then
					savedPlaylists = {}
				end

				if not savedPlaylists[args[1]] then
					plr:sendData("SendMessage", "Music player management", "Saved playlist "..args[1].." doesn't exist.", 6, "Hint")
				else
					local songsList = {}
					
					for i,songId in pairs(savedPlaylists[args[1]]) do
						songId = tonumber(songId)

						if songId and songId > 0 then
							local canUseSong = false
							local musicInfo = service.getProductInfo(songId) or {}

							if musicInfo.AssetTypeId == 3 then
								canUseSong = true
							end

							table.insert(songsList, {
								Text = (canUseSong and "✅" or "❌").." | ["..songId.."] - "..tostring(musicInfo.Name or "UNKNOWN SONG");
								Desc = (not canUseSong and "Song not available and cannot be played in the queue") or "Id: "..songId.." | "..tostring(musicInfo.Name);
								Color = (not canUseSong and Color3.fromRGB(255, 73, 73)) or nil;
							})
						end
					end
					
					plr:makeUI("ADONIS_LIST", {
						Title = "E. Saved Playlist "..args[1].." ("..service.tableCount(savedPlaylists[args[1]]).."/20)";
						Table = songsList;
						RichText = true;
					})
				end
			end;
		};
		
		clearSavedPlaylist = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"clearSavedPlaylist"};
			Arguments = {
				{
					argument = "playlistName";
					required = true;
					filter = true;
					requireSafeString = true;
				};
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Clears a saved playlist";
			PlayerDebounce = true;
			ServerCooldown = 20;

			Function = function(plr, args)
				if args[1]:find(settings.delimiter) then
					plr:sendData("SendMessage", "Music player management", "Playlist name must not have a delimiter", 10, "Hint")
					return -1,"ResetCooldown"
				elseif #args[1] > 30 then
					plr:sendData("SendMessage", "Music player management", "Playlist name must have up to 30 characters", 10, "Hint")
					return -1,"ResetCooldown"
				end
				
				local savedPlaylists = Datastore.read("Music", "SavedPlaylists") or {}

				if type(savedPlaylists) ~= "table" then
					savedPlaylists = {}
					Datastore.overWrite("Music", "SavedPlaylists", {})
				end

				if not savedPlaylists[args[1]] then
					plr:sendData("SendMessage", "Music player management", "Saved playlist "..args[1].." doesn't exist.", 6, "Hint")
				else
					plr:sendData("SendMessage", "Music player management", "Clearing saved playlist "..args[1]..". Please wait.", 20, "Hint")
					Datastore.tableUpdate("Music", "SavedPlaylists", "Index", args[1], {}, nil, function()
						plr:sendData("SendMessage", "Music player management", "Cleared saved playlist "..args[1], 8, "Hint")
					end)
				end
			end;
		};
		
		addSongToSavedPlaylist = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"addSongToSavedPlaylist"};
			Arguments = {
				{
					argument = "songId";
					type = "integer";
					required = true;
				};
				{
					argument = "playlistName";
					required = true;
					filter = true;
					requireSafeString = true;
				};
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Adds song to a saved playlist";
			PlayerDebounce = true;
			ServerCooldown = 20;

			Function = function(plr, args)
				if args[2]:find(settings.delimiter) then
					plr:sendData("SendMessage", "Music player management", "Playlist name must not have a delimiter", 10, "Hint")
					return -1,"ResetCooldown"
				elseif #args[2] > 30 then
					plr:sendData("SendMessage", "Music player management", "Playlist name must have up to 30 characters", 10, "Hint")
					return -1,"ResetCooldown"
				end
				
				local savedPlaylists = Datastore.read("Music", "SavedPlaylists") or {}
				
				if type(savedPlaylists) ~= "table" then
					savedPlaylists = {}
					Datastore.overWrite("Music", "SavedPlaylists", {})
				end

				if not savedPlaylists[args[2]] then
					plr:sendData("SendMessage", "Music player management", "Saved playlist "..args[2].." doesn't exist.", 6, "Hint")
				else
					local playlistData = savedPlaylists[args[2]]
					local entryCount = service.tableCount(playlistData)
					
					if entryCount+1 > 20 then
						plr:sendData("SendMessage", "Music player management", "Unable to add more songs for the saved playlist "..args[2], 6, "Hint")
						return
					end
					
					local assetInfo = service.getProductInfo(args[1]) or {}

					if not assetInfo or assetInfo.AssetTypeId ~= 3 then
						plr:sendData("SendMessage", "Asset collection error", "<b>"..args[1].."</b> isn't an audio", 6, "Hint")
						return
					end

					-- Check banned song creator
					local userCreator = assetInfo.Creator.CreatorType == "User"
					if not userCreator then
						local groupInfo = service.getGroupInfo(assetInfo.Creator.Id)

						if groupInfo and groupInfo.Id then
							if Identity.checkTable(groupInfo.Owner.Id, settings.musicPlayer_BannedCreators) then
								plr:sendData("SendMessage", "Music player management", "Songs from creator <b>"..groupInfo.Owner.Name.."</b> are banned from being played.", 6, "Hint")
								return
							end
						end
					else
						if Identity.checkTable(assetInfo.Creator.Id, settings.musicPlayer_BannedCreators) then
							plr:sendData("SendMessage", "Music player management", "Songs from creator <b>"..assetInfo.Creator.Name.."</b> are banned from being played.", 6, "Hint")
							return
						end
					end
					
					plr:sendData("SendMessage", "Music player management", "Adding song "..tostring(assetInfo.Name).." to the saved playlist "..args[2], 20, "Hint")
					
					Datastore.tableUpdate("Music", "SavedPlaylists", "tableAdd", args[2], args[1], nil, function()
						plr:sendData("SendMessage", "Music player management", "Successfully added song "..tostring(assetInfo.Name).." to the saved playlist "..args[2], 8, "Hint")
					end)
				end
			end;
		};
		
		removeSongFromSavedPlaylist = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"remSongFromSavedPlaylist"};
			Arguments = {
				{
					argument = "songId";
					type = "integer";
					required = true;
				};
				{
					argument = "playlistName";
					required = true;
					filter = true;
					requireSafeString = true;
				};
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Removes song from a saved playlist";
			PlayerDebounce = true;
			ServerCooldown = 20;

			Function = function(plr, args)
				if args[2]:find(settings.delimiter) then
					plr:sendData("SendMessage", "Music player management", "Playlist name must not have a delimiter", 10, "Hint")
					return -1,"ResetCooldown"
				elseif #args[2] > 30 then
					plr:sendData("SendMessage", "Music player management", "Playlist name must have up to 30 characters", 10, "Hint")
					return -1,"ResetCooldown"
				end

				local savedPlaylists = Datastore.read("Music", "SavedPlaylists") or {}

				if type(savedPlaylists) ~= "table" then
					savedPlaylists = {}
				end

				if not savedPlaylists[args[2]] then
					plr:sendData("SendMessage", "Music player management", "Saved playlist "..args[2].." doesn't exist.", 6, "Hint")
				else
					local playlistData = savedPlaylists[args[2]]
					
					if not table.find(playlistData, args[1]) then
						plr:sendData("SendMessage", "Music player management", "Song id "..tostring(args[1]).." doesn't exist in the saved playlist "..args[2], 10, "Hint")
					else
						local assetInfo = service.getProductInfo(args[1]) or {}
						plr:sendData("SendMessage", "Music player management", "Removing song "..tostring(assetInfo.Name).." from the saved playlist "..args[2], 20, "Hint")
						
						Datastore.tableRemove("Music", "SavedPlaylists", "valueFromIndex", args[2], args[1], function()
							plr:sendData("SendMessage", "Music player management", "Song "..tostring(assetInfo.Name).." was removed from the saved playlist "..args[2], 8, "Hint")
						end)
					end
				end
			end;
		};
		
		addSavedPlaylistToQueue = {
			Disabled = not (musicPlayerEnabled and settings.musicPlayer_Queue);
			Prefix = settings.actionPrefix;
			Aliases = {"addSavedPlaylistToMusic"};
			Arguments = {
				{
					argument = "playlistName";
					required = true;
					filter = true;
					requireSafeString = true;
				};
			};
			Permissions = {"Manage_MusicPlayer";};
			Roles = {};

			Description = "Adds saved playlist to the queue";
			PlayerDebounce = true;
			ServerCooldown = 20;

			Function = function(plr, args)
				if args[1]:find(settings.delimiter) then
					plr:sendData("SendMessage", "Music player management", "Playlist name must not have a delimiter", 10, "Hint")
					return -1,"ResetCooldown"
				elseif #args[1] > 30 then
					plr:sendData("SendMessage", "Music player management", "Playlist name must have up to 30 characters", 10, "Hint")
					return -1,"ResetCooldown"
				end

				local savedPlaylists = Datastore.read("Music", "SavedPlaylists") or {}

				if type(savedPlaylists) ~= "table" then
					savedPlaylists = {}
				end

				if not savedPlaylists[args[1]] then
					plr:sendData("SendMessage", "Music player management", "Saved playlist "..args[1].." doesn't exist.", 6, "Hint")
				else
					local songsQueue = musicPlayerQueue._queue
					local musicQueue = musicPlayerQueue
					
					local musicPlaylist = savedPlaylists[args[1]]

					if #musicPlaylist == 0 then
						plr:sendData("SendMessage", "Music player", "Saved playlist <b>"..args[1].."</b> doesn't have any songs added. Nothing has been added to the queue.", 6, "Hint")
						return	
					end

					local playerCreated = (function()
						local count = 0

						for i,que in pairs(songsQueue) do
							local musicId,creatorId = unpack(que.arguments)

							if creatorId == plr.UserId then
								count += 1
							end
						end

						return count
					end)()
					local songsCountInPlaylist = #musicPlaylist
					local maxCreations = settings.musicPlayer_MaxPlayerCreations-playerCreated
					local maxSongs = math.clamp(maxCreations, 0, math.clamp(songsCountInPlaylist, 0, settings.musicPlayer_MaxSongs-#songsQueue))
					local noSongDuplication = settings.musicPlayer_NoDuplication

					if maxSongs > 0 then
						local addedSongs = 0

						for i = 1,maxSongs,1 do
							local songIdFromPlaylist = tonumber(musicPlaylist[i])

							if songIdFromPlaylist then
								local musicInfo = service.getProductInfo(songIdFromPlaylist) or {}

								if musicInfo.AssetTypeId == 3 then
									if noSongDuplication then
										local skipAddition = false

										for d,songQue in pairs(songsQueue) do
											local musicId,creatorId = unpack(songQue.arguments)

											if musicId == songIdFromPlaylist then
												skipAddition = true
												break
											end
										end

										if skipAddition then
											continue
										end
									end

									musicQueue:add(songIdFromPlaylist, plr.UserId)
									addedSongs += 1
								end
							end
						end

						if addedSongs > 0 then
							plr:sendData("SendMessage", "Music player", "Added "..addedSongs.." songs from playlist <b>"..args[1].."</b>", 6, "Hint")
						else
							plr:sendData("SendMessage", "Music player", "There were no available songs from playlist <b>"..args[1].."</b> to add.", 4, "Hint")
						end
					else
						plr:sendData("SendMessage", "Music player", "There are no songs available to add. This is the amount of your added songs have exceeded the max player creations or queue is full.", 6, "Hint")
					end
				end
			end;
		};
	}
	
	for cmdName,cmdTab in pairs(cmdsList) do
		cmdTab.Category = script.Name
		Cmds.create(cmdName, cmdTab)
	end
end