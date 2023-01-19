-- PeerJS object to handle WebRTC connections
PeerJS = {}

local pool = {}
local peerInstanceId = 0

-- creates a new PeerJS instance, assigns it a unique ID and stores it in a pool. 
PeerJS.CreatePeer = function(onOpen, onConnection, onClose, onDisconnected, OnError)
    peerInstanceId = peerInstanceId + 1
    local instance = {
        peerInstanceId = peerInstanceId,
        onOpen = onOpen,
        onConnection = onConnection,
        onClose = onClose,
        onDisconnected = onDisconnected,
        OnError = OnError,
        connections = {}
    }
    -- connects to a peer and creates a new connection, assigns it a unique ID, adds callbacks to it, and stores it in the connection pool. 
    -- sends a message to the NUI to create a new connection with the peer.
    instance.Connect = function(peer, connOpen, connClose, connError, connData)
        local connection = {
            peerInstanceId = instance.peerInstanceId,
            connId = peer,
            onOpen = connOpen,
            onClose = connClose,
            OnError = connError,
            onData = connData
        }
        AppendConnFunctions(connection)
        instance.connections[peer] = connection
        pool[peer] = connection

        SendNUIMessage({
            action = "CreatePeerConn",
            peerInstanceId = connection.peerInstanceId,
            connId = connection.connId
        })

        return connection
    end

    -- closes the connection to the server
    instance.Close = function()
        SendNUIMessage({
            action = "PeerClose",
            peerInstanceId = peerInstanceId
        })
    end

    -- closes the connection to the server and terminates all existing connections
    instance.Destroy = function()
        SendNUIMessage({
            action = "PeerDestroy",
            peerInstanceId = peerInstanceId
        })
    end

    pool[peerInstanceId] = instance
    SendNUIMessage({
        action = "CreatePeer",
        peerInstanceId = peerInstanceId
    })
    return instance
end

-- appends extra functions to each remote connection object
-- ability to send messages or disconnect
function AppendConnFunctions(o)
    o.Send = function(data)
        SendNUIMessage({
            action = "ConnSend",
            peerInstanceId = o.peerInstanceId,
            connId = o.connId,
            data = data
        })
    end
    o.Close = function()
        SendNUIMessage({
            action = "ConnClose",
            peerInstanceId = o.peerInstanceId,
            connId = o.connId
        })
    end
end

local function handleCallbackEvents(data, cb)
    cb(true)
    -- local peer open
    if data.action == "pOpen" then
        pool[data.peerInstanceId].id = data.id
        if pool[data.peerInstanceId].onOpen then
            pool[data.peerInstanceId].onOpen(data.id)
        end
        -- local peer close
    elseif data.action == "pClose" then
        if pool[data.peerInstanceId].onClose then
            pool[data.peerInstanceId].onClose()
        end
        -- local peer disconnected from PeerJS service
    elseif data.action == "pDisconnected" then
        if pool[data.peerInstanceId].onDisconnected then
            pool[data.peerInstanceId].onDisconnected()
        end
        -- local peer error
    elseif data.action == "pError" then
        if pool[data.peerInstanceId].OnError then
            pool[data.peerInstanceId].OnError(data.err)
        end
        -- local peer on connection
    elseif data.action == "pConnection" then
        local connId = data.connId
        local o = {
            peerInstanceId = data.peerInstanceId,
            connId = data.connId
        }
        AppendConnFunctions(o)
        pool[connId] = o
        if pool[data.peerInstanceId].onConnection then
            pool[data.peerInstanceId].onConnection(o)
        end
        -- remote connection open
    elseif data.action == "cOpen" then
        if pool[data.connId].onOpen then
            pool[data.connId].onOpen()
        end
        -- remote connection close
    elseif data.action == "cClose" then
        if pool[data.connId].onClose then
            pool[data.connId].onClose()
        end
        -- remote connection error
    elseif data.action == "cError" then
        if pool[data.connId].OnError then
            pool[data.connId].OnError(data.err)
        end
        -- remote connection data
    elseif data.action == "cData" then
        if pool[data.connId].onData then
            pool[data.connId].onData(data.data)
        end
    end
end

RegisterNUICallback('peerevent', handleCallbackEvents)
exports('GetObject', function()
    return PeerJS
end)