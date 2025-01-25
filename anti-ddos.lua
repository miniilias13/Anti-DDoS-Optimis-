-- anti-ddos.lua
local MAX_CONNECTIONS_PER_MINUTE = 20 -- Limite de connexions par minute par IP
local CONNECTION_RESET_TIME = 60000   -- Temps (en ms) avant de réinitialiser le compteur

local connectionTracker = {}

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local playerIP = GetPlayerEndpoint(source) -- Récupère l'IP du joueur
    deferrals.defer()

    if not playerIP then
        deferrals.done("Impossible de vérifier votre connexion. Réessayez plus tard.")
        return
    end

    local currentTime = os.time()

    -- Initialiser ou mettre à jour le tracker pour l'IP
    if not connectionTracker[playerIP] then
        connectionTracker[playerIP] = { count = 1, lastConnection = currentTime }
    else
        local tracker = connectionTracker[playerIP]

        -- Réinitialiser le compteur si le délai est écoulé
        if currentTime - tracker.lastConnection > CONNECTION_RESET_TIME / 1000 then
            tracker.count = 1
        else
            tracker.count = tracker.count + 1
        end

        tracker.lastConnection = currentTime

        -- Refuser la connexion si la limite est atteinte
        if tracker.count > MAX_CONNECTIONS_PER_MINUTE then
            deferrals.done("Vous avez dépassé la limite de connexions. Réessayez dans une minute.")
            return
        end
    end

    deferrals.done() -- Autorise la connexion
end)

-- Nettoyage périodique pour libérer la mémoire
CreateThread(function()
    while true do
        Wait(600000) -- Nettoyage toutes les 10 minutes
        local currentTime = os.time()

        for ip, tracker in pairs(connectionTracker) do
            -- Supprime les entrées anciennes qui ne sont plus actives
            if currentTime - tracker.lastConnection > CONNECTION_RESET_TIME / 1000 then
                connectionTracker[ip] = nil
            end
        end
    end
end)
