Webhook Discord : Remplacez DISCORD_WEBHOOK_URL par l'URL de votre webhook Discord.
Rôle admin : Ajustez ADMIN_GROUP selon le rôle administrateur défini dans votre système (ESX, QBCore, etc.).
Installation :
Ajoutez ce fichier dans resources.
Mettez ensure anti-ddos dans server.cfg 

Notifications Discord :

Lorsqu'une IP est bloquée ou bannie, une notification est envoyée au webhook Discord configuré.
Les notifications contiennent la raison et un horodatage.
Commandes administratives :

/antiddos list : Affiche les IP actuellement bannies.
/antiddos unban [IP] : Débannit une IP manuellement.
Accessible uniquement aux utilisateurs avec le rôle admin (ou autre rôle défini dans ADMIN_GROUP).
Gestion via console et en jeu :

Les logs sont visibles à la fois dans la console et sur Discord.
Les administrateurs peuvent interagir en jeu pour gérer les bannissements.
