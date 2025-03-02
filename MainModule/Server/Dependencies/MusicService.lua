--!nocheck
local MusicService = {
    Configurations = {
        MaxSongsInSavedPlaylist = 30;
    };

    SavedPlaylists = {};
}
local server, settings, service;
local Datastore, Parser, Process, Remote, Network, Logs, Signal;

function MusicService:getSongFromQueue(assetId: number): {
    Name: string,
    AssetId: number,
    RequesterId: number?
}?
    for i, que in MusicService.Queue._queue do
        if que.arguments[1].AssetId == assetId then
            return que.arguments[1]
        end
    end

    return nil
end

function MusicService:getSongsAddedFromRequester(requesterId: number): {[number]: {
    Name: string,
    AssetId: number,
    RequesterId: number?
}}
    local list = {}
    for i, que in MusicService.Queue._queue do
        if que.arguments[1].RequesterId == requesterId then
            table.insert(list, que.arguments[1])
        end
    end

    return list
end

function MusicService:addSongToQueue(assetId: number, RequesterId: number?)
    if settings.musicPlayer_NoDuplication and MusicService:getSongFromQueue(assetId) then
        return self
    end

    local assetInfo = service.getProductInfo(assetId)
    if not assetInfo or assetInfo.AssetTypeId ~= 3 then return self end

    MusicService.Queue:add({
        Name = assetInfo and assetInfo.Name or "";
        AssetId = assetId;
        RequesterId = RequesterId;
    })
    
    return self
end

function MusicService:removeSongFromQueue(assetId: number?, queId: string)
    local listOfQueIds = {}
    for i, que in MusicService.Queue._queue do
        if que.arguments[1].AssetId == assetId or que.id == queId then
           table.insert(listOfQueIds, que.id)
        end
    end

    for i, queId in listOfQueIds do
        MusicService.Queue:remove(queId)
    end

    return self
end

function MusicService:clearQueue()
    MusicService.Queue:clear()

    return self
end

function MusicService.internalUpdateSavedPlaylistCache(playlistName: string, playlistData: any)
    local cacheData = MusicService.SavedPlaylists[playlistName]
    
    if not cacheData then
        cacheData = {
            _updated = os.time();
            playlistData = playlistData;
        }
        MusicService.SavedPlaylists[playlistName] = cacheData
    else
        cacheData._updated = os.time()
        cacheData.playlistData = playlistData
    end

    return
end

function MusicService:getSavedPlaylist(playlistName: string)
    local currentCache = MusicService.SavedPlaylists[playlistName]
    if currentCache and os.time()-currentCache._updated > 600 then
        return currentCache.playlistData
    end

    MusicService.internalUpdateSavedPlaylistCache(playlistName, currentCache and currentCache.playlistData or {})
    
    local savedPlaylist = Datastore.read(`Music`, `SavedPlaylist-{playlistName}`)
    if type(savedPlaylist) ~= "table" then
        savedPlaylist = {}
    end

    MusicService.internalUpdateSavedPlaylistCache(playlistName, savedPlaylist)

    return savedPlaylist
end

function MusicService:addSongsToSavedPlaylist(playlistName: string, assetIds: {[number]: number}, allowDuplication: boolean?)
    playlistName = playlistName:sub(1,30)

    Datastore.readAndWrite(`Music`, `SavedPlaylist-{playlistName}`, function (playlistData, keyInfo: DataStoreKeyInfo)
        if type(playlistData) ~= "table" then
            playlistData = {}
        end

        local notAllowedIds = not allowDuplication and {} or nil
        if not allowDuplication then
            for i, songEntry in playlistData do
                table.insert(notAllowedIds, songEntry[2])
            end
        end

        if #playlistData+1 > MusicService.Configurations.MaxSongsInSavedPlaylist then
            repeat
                table.remove(playlistData, 1)
            until
                #playlistData+1 <= MusicService.Configurations.MaxSongsInSavedPlaylist or #playlistData == 0
        end

        local songEntryId = playlistData[#playlistData] and playlistData[#playlistData][1]+1 or 1
        
        for i, assetId in assetIds do
            if notAllowedIds and table.find(notAllowedIds, assetId) then continue end
            table.insert(playlistData, {songEntryId, assetId})
            songEntryId += 1
        end

        task.spawn(MusicService.internalUpdateSavedPlaylistCache, playlistName, playlistData)
        warn(`DID ADD SONGS TO SAVED PLAYLIST?`, playlistName, playlistData)

        return playlistData
    end)

    return self
end

function MusicService:remSongsFromSavedPlaylist(playlistName: string, assetIds: {[number]: number}?, indexNumbers: {[number]: number}?)
    playlistName = playlistName:sub(1,30)

    Datastore.readAndWrite(`Music`, `SavedPlaylist-{playlistName}`, function (playlistData, keyInfo: DataStoreKeyInfo)
        if type(playlistData) ~= "table" then
            playlistData = {}
        end

        if indexNumbers then
            local didFinish = false;
            repeat
                didFinish = true
                for i, songEntry in playlistData do
                    if table.find(indexNumbers, songEntry[1]) then
                        table.remove(playlistData, i)
                        didFinish = false;
                        break;
                    end
                end
            until didFinish
        end

        if assetIds then
            local didFinish = false;
            repeat
                didFinish = true
                for i, songEntry in playlistData do
                    if table.find(assetIds, songEntry[2]) then
                        table.remove(playlistData, i)
                        didFinish = false;
                        break;
                    end
                end
            until didFinish
        end

        task.spawn(MusicService.internalUpdateSavedPlaylistCache, playlistName, playlistData)
        warn(`new playlist`, playlistName, playlistData)
        
        return playlistData
    end)
    
    return self
end

function MusicService:clearSavedPlaylist(playlistName: string)
    playlistName = playlistName:sub(1,30)
    
    Datastore.readAndWrite(`Music`, `SavedPlaylist-{playlistName}`, function (playlistData, keyInfo: DataStoreKeyInfo)
        playlistData = {}
        
        task.spawn(MusicService.internalUpdateSavedPlaylistCache, playlistName, playlistData)

        return playlistData
    end)

    return self
end

function MusicService:getSound(): Sound
    if not self._object or self._object.Parent ~= workspace then
        if self._object then
            pcall(self._object.Stop, self._object)
            service.Delete(self._object)
        end

        self._object = service.New("Sound", {
            Name = `ESSMUSIC`;
            Parent = workspace;
        })
    end

    return self._object
end

function MusicService:setupSystem()
    local MusicQueue = server.Queue.new()
    MusicQueue.active = true
    MusicQueue.clearFinishedQuesAfterProcess = false
    MusicQueue.maxQueue = math.floor(math.clamp(settings.musicPlayer_MaxSongs or 0, 1, math.huge))
    MusicQueue.repeatProcess = false
    MusicQueue.ignoreProcessedQues = false

    MusicQueue.processFunc = MusicService.internalProcessQueue
    MusicQueue.processIdle:connect(function()
        local soundObject = MusicService._object
        soundObject.SoundId = ""
        soundObject.TimePosition = 0
        soundObject:Stop()
    end)

    MusicService.Queue = MusicQueue

    Remote.ListData.ViewMusicQueue = {
        Whitelist = {},
        Permissions = { "Manage_MusicPlayer" },
        Function = function(plr)
            --[[
            {
                --     type = "Log",
                --     title = `what`,
                --     desc = `what`,
                --     sentOs = os.clock(),
                --     sent = 1708223467,
                -- },
            ]]

            local list = {}
            local jumpMusicToQueueId = server.Commands.Library.jumpMusicToQueue.Id
            local skipMusicQueueId = server.Commands.Library.skipMusicQueue.Id
            local removeMusicId = server.Commands.Library.removeMusic.Id

            local soundObject = MusicService._object

            for i, que in MusicQueue._queue do
                local parsedCreator = que.arguments[1].RequesterId and Parser:getParsedPlayer(que.arguments[1].RequesterId, true) or nil
                local isNowPlaying = MusicQueue.focusingQueTab == que

                table.insert(list, {
                    type = "Action",
                    specialMarkdownSupported = false,
                    selectable = true,
                    labelColor = if isNowPlaying then Color3.fromRGB(39, 230, 80) else nil;
                    label = (if isNowPlaying and soundObject then
                        `[{Parser:formatTime(soundObject.TimePosition)} - {Parser:formatTime(soundObject.TimeLength)}]\n`
                        else "") ..
                        `{i}. <b>{Parser:filterForRichText(que.arguments[1].Name)}</b> ({que.arguments[1].AssetId})`
                        ..(if parsedCreator then `\nRequested by <i>{parsedCreator:toStringDisplayForPlayer(plr)}</i>` else "")
                        ..(if isNowPlaying then `\n----------` else ""),
                    richText = true,
                    isPlaying = isNowPlaying and 1 or 0;
                    index = i;
	                optionsLayoutStyle = `Log`;
                    options = {
                        {
                            label = if isNowPlaying then `Skip` else `Jump`,
                            backgroundColor = Color3.fromRGB(185, 118, 118),
                            onExecute = if isNowPlaying then `playercommand://{skipMusicQueueId}|| `
                                else `playercommand://{jumpMusicToQueueId}||{i}`;
                        };
                        {
                            label = `Remove`,
                            backgroundColor = Color3.fromRGB(224, 56, 56),
                            onExecute = `playercommand://{removeMusicId}||{que.id}`;
                        };
                    },
                })
            end

            table.sort(list, function(logA, logB)
                return logA.isPlaying > logB.isPlaying or if logA.isPlaying == logB.isPlaying then logA.index < logB.index else false
            end)

            if #list == 0 then
                table.insert(list, {
                    type = "Label",
                    label = `There are no songs added in the queue`;
                })
            end

            return list
        end,
    }

    MusicService.setupSystem = nil
end

function MusicService.internalProcessQueue(index: number, queInfo: any, songInfo: {
    Name: string,
    AssetId: number,
    RequesterId: number?
})
    if settings.musicPlayer_SongAnnouncement then
        local parsedCreator = songInfo.RequesterId and Parser:getParsedPlayer(songInfo.RequesterId, true) or nil
        local songMessage = `Now playing <b>{Parser:filterForRichText(songInfo.Name)}</b> ({songInfo.AssetId})`
            .. (if parsedCreator then `\n\n<i>Added by {parsedCreator:toStringPublicDisplay()}</i>` else "")
       
        for i, parsedPlr in pairs(service.getPlayers(true)) do
            parsedPlr:sendData("SendNotification", {
                title = "Music System";
                description = songMessage;
                time = 15;
            })
        end
    end

    local finishSignal = Signal.new()
    local mainSound = MusicService:getSound()

    task.defer(function()
        mainSound.TimePosition = 0
        mainSound.SoundId = `rbxassetid://{songInfo.AssetId}`
        mainSound:Play()
    end)
        
    -- task.spawn(function()
    --     service.ContentProvider:PreloadAsync({ `rbxassetid://{songInfo.AssetId}` }, function(result: Enum.AssetFetchStatus)
    --         if not finishSignal.active then return end
    --         warn(`result:`, result)
    --         if result == Enum.AssetFetchStatus.Failure or result == Enum.AssetFetchStatus.TimedOut then
    --             MusicService.Queue:remove(queInfo.id)

    --             for i, parsedPlr in pairs(service.getPlayers(true)) do
    --                 parsedPlr:sendData("SendNotification", {
    --                     title = "Music System";
    --                     description = `<b>Couldn't load {Parser:filterForRichText(songInfo.Name)}</b> due to one or more of the reasons:\n`
    --                         .. "- Game creator not owning property rights to the asset\n"
    --                         .. "- Roblox prohibited the asset to load\n\n"
    --                         .. "<i>The asset was removed from the music system</i>";
    --                     time = 10;
    --                 })
    --             end
    --         end
    -- end)
    -- end)

    Signal:waitOnSingleEvents({ mainSound.Ended, mainSound:GetPropertyChangedSignal("Parent"), queInfo.removed, queInfo.ignored }, 2)
    finishSignal:disconnect()
end

function MusicService.Init(env)
    server, settings, service = env.server, env.settings, env.service
    Datastore = server.Datastore
    Parser = server.Parser
    Process = server.Process
    Remote = server.Remote
    Network = server.Network
    Logs = server.Logs
    Signal = server.Signal
    
    MusicService:setupSystem()
end

return MusicService