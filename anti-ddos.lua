-- anti-ddos.lua
local MAX_CONNECTIONS_PER_MINUTE = 20 -- Limite de connexions par minute par IP
local CONNECTION_RESET_TIME = 60000   -- Temps (en ms) avant de réinitialiser le compteur
local BAN_THRESHOLD = 100             -- Nombre de connexions bloquées avant de bannir une IP
local BAN_DURATION = 3600             -- Durée du bannissement en secondes (1 heure)

local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN" -- Remplacez par votre webhook Discord
local ADMIN_GROUP = "admin" -- Nom du groupe ayant accès au panneau d'administration

local connectionTracker = {}
local bannedIPs = {}
local whitelistedIPs = {
    "127.0.0.1", -- Exemple : localhost
    "192.168.1.1" -- Exemple : IP interne
}

-- Fonction pour envoyer une notification Discord
local function sendDiscordNotification(message, color)
    PerformHttpRequest(DISCORD_WEBHOOK_URL, function(err, text, headers) end, "POST", json.encode({
        embeds = {{
            title = "🚨 Anti-DDoS Notification",
            description = message,
            color = color or 16711680, -- Par défaut : rouge
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }), { ["Content-Type"] = "application/json" })
end

-- Fonction pour loguer les connexions bloquées
local function logBlockedConnection(ip, reason)
    local logMessage = string.format("[Anti-DDoS] Connexion bloquée pour IP %s : %s", ip, reason)
    print(logMessage)
    sendDiscordNotification(logMessage, 16711680) -- Notification Discord en rouge
end

-- Vérifie si une IP est bannie
local function isBanned(ip)
    if bannedIPs[ip] then
        local banInfo = bannedIPs[ip]
        if os.time() - banInfo.startTime > BAN_DURATION then
            bannedIPs[ip] = nil -- Supprime le bannissement après la durée
            return false
        end
        return true
    end
    return false
end

-- Gère les connexions des joueurs
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local playerIP = GetPlayerEndpoint(source) -- Récupère l'IP du joueur
    deferrals.defer()

    if not playerIP then
        deferrals.done("Impossible de vérifier votre connexion. Réessayez plus tard.")
        return
    end

    -- Vérifie si l'IP est en liste blanche
    for _, whitelistedIP in ipairs(whitelistedIPs) do
        if playerIP == whitelistedIP then
            deferrals.done() -- Autorise la connexion
            return
        end
    end

    -- Vérifie si l'IP est bannie
    if isBanned(playerIP) then
        deferrals.done("Votre IP est bannie temporairement pour abus. Réessayez plus tard.")
        logBlockedConnection(playerIP, "IP bannie temporairement.")
        return
    end

    local currentTime = os.time()

    -- Initialise ou met à jour le tracker pour l'IP
    if not connectionTracker[playerIP] then
        connectionTracker[playerIP] = { count = 1, lastConnection = currentTime, blockCount = 0 }
    else
        local tracker = connectionTracker[playerIP]

        -- Réinitialise le compteur si le délai est écoulé
        if currentTime - tracker.lastConnection > CONNECTION_RESET_TIME / 1000 then
            tracker.count = 1
        else
            tracker.count = tracker.count + 1
        end

        tracker.lastConnection = currentTime

        -- Bloque la connexion si la limite est atteinte
        if tracker.count > MAX_CONNECTIONS_PER_MINUTE then
            tracker.blockCount = tracker.blockCount + 1

            if tracker.blockCount >= BAN_THRESHOLD then
                bannedIPs[playerIP] = { startTime = os.time() }
                logBlockedConnection(playerIP, "IP bannie pour abus.")
                deferrals.done("Votre IP est temporairement bannie pour abus.")
            else
                logBlockedConnection(playerIP, "Limite de connexions dépassée.")
                deferrals.done("Vous avez dépassé la limite de connexions. Réessayez plus tard.")
            end
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
            -- Supprime les entrées inactives
            if currentTime - tracker.lastConnection > CONNECTION_RESET_TIME / 1000 then
                connectionTracker[ip] = nil
            end
        end
    end
end)

-- Commandes administratives
RegisterCommand("antiddos", function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and xPlayer.getGroup() == ADMIN_GROUP then
        local action = args[1]

        if action == "list" then
            TriggerClientEvent('chat:addMessage', source, { args = { "Anti-DDoS", "Liste des IP bannies :" } })
            for ip, _ in pairs(bannedIPs) do
                TriggerClientEvent('chat:addMessage', source, { args = { "-> ", ip } })
            end
        elseif action == "unban" and args[2] then
            local ipToUnban = args[2]
            if bannedIPs[ipToUnban] then
                bannedIPs[ipToUnban] = nil
                TriggerClientEvent('chat:addMessage', source, { args = { "Anti-DDoS", "IP " .. ipToUnban .. " débannie." } })
                sendDiscordNotification("IP " .. ipToUnban .. " débannie par un administrateur.", 65280) -- Vert
            else
                TriggerClientEvent('chat:addMessage', source, { args = { "Anti-DDoS", "IP " .. ipToUnban .. " non trouvée." } })
            end
        else
            TriggerClientEvent('chat:addMessage', source, {
                args = {
                    "Anti-DDoS",
                    "Commandes disponibles : /antiddos list, /antiddos unban [IP]"
                }
            })
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { "Anti-DDoS", "Vous n'avez pas la permission d'exécuter cette commande." } })
    end
end, false)
