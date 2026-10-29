# ADR 0003 · Faire communiquer les modules de l'API centrale par événements de domaine publiés via une outbox transactionnelle

- Statut : proposé · Date : 2026-10-30 · Auteurs : AIT ELHADI Wissam · Spécialité : Dev
- Élément du C4 : composant « Bus d'événements + outbox » de l'API centrale (N3) ; flèche « API centrale → Orchestrateur de notifications » (N2)

## Contexte
- L'Event Storming du TP 5 montre des réactions entre contextes : `InspectionEnregistrée` (Terrain) résout l'alerte (Santé) ; `AlerteEscaladée` (Santé) crée une visite à planifier (Coordination) et doit notifier le coordinateur.
- CDC UC-A01 et UC-A03 : le coordinateur doit être notifié quand une inspection signale une anomalie ou qu'une récolte est déclarée ; CDC 5.2 : synchronisation et intégrations « event-driven » (files de messages, workflows n8n).
- ADR 0001 : les modules partagent un déployable mais pas leurs données (un schéma par module).
- Une notification ne doit jamais partir pour une alerte dont la transaction a échoué, et ne doit jamais être perdue si l'API redémarre juste après l'enregistrement.
- Point chaud du mur : « Terrain doit-il connaître Santé pour clôturer l'alerte ? »

## Options
1. **Appels directs entre modules** (Terrain appelle `SanteService.resoudre()`) — option la plus simple : + lisible, transaction unique / − couplage fort : Terrain dépend de Santé, et toute nouvelle réaction modifie le module émetteur.
2. **Événements en mémoire** (`EventEmitter` comme dans le kit TP 5) : + découplage / − un événement émis après le `COMMIT` est perdu si le processus s'arrête entre les deux ; émis avant, il peut annoncer une donnée jamais enregistrée.
3. **Événements + outbox transactionnelle** : l'événement est écrit dans la table `outbox` dans la même transaction que l'agrégat, puis un relais le distribue aux abonnés et à l'Orchestrateur de notifications : + aucun événement perdu ni fantôme / − livraison « au moins une fois », donc abonnés idempotents ; une table et un relais à maintenir.

## Décision
Option 3. C'est la seule qui garantit à la fois le découplage entre modules et la cohérence entre la donnée enregistrée et la notification. C'est aussi ce qui permet à l'ADR 0002 d'envoyer l'escalade une seule fois.

## Conséquences
+ Ajouter une réaction (ex. projection Impact) ne touche pas le module émetteur.
+ Un redémarrage n'entraîne ni perte ni événement fantôme ; le relais reprend au dernier événement non publié.
− Chaque abonné doit être idempotent (clé `eventId` mémorisée).
− Délai de quelques secondes entre l'action et la réaction.
À surveiller : nombre d'événements en attente dans l'outbox (alerte au-delà de 500) ; âge du plus ancien (cible < 1 min).

## Révision
Rouvrir si un module est extrait en service séparé (passer alors à un broker de messages externe), ou si l'outbox dépasse régulièrement 10 000 événements en attente.
