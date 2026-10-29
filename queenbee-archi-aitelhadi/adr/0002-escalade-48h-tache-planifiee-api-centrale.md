# ADR 0002 · Exécuter la politique d'escalade à 48 h par une tâche planifiée idempotente dans l'API centrale

- Statut : proposé · Date : 2026-10-30 · Auteurs : AIT ELHADI Wissam · Spécialité : Dev
- Élément du C4 : composants « Planificateur » et « Module Santé des colonies » de l'API centrale (N3) ; flèche « API centrale → Orchestrateur de notifications » (N2)

## Contexte
- UC-A02 et UC-C01 : une alerte levée et non prise en charge sous 48 h est escaladée au coordinateur régional, qui doit pouvoir réassigner la visite.
- CDC 3.2 et 1.4 : 8 coordinateurs régionaux priorisent les visites (UC-C01) et 6 gestionnaires gèrent les alertes critiques ; une alerte oubliée signifie une colonie perdue (objectif 1.3 : 80 % des essaimages détectés au moins 48 h avant).
- CDC 8.1 : temps de réponse de l'API centrale < 500 ms (p95) ; la tâche ne doit pas dégrader les requêtes des utilisateurs.
- La règle est déjà dans l'agrégat `Alerte` du TP 5 (`estEnRetard(now)`, `escalader(at)`), et le service `AlerteService.escaladerAlertesEnRetard()` existe. La question est **qui l'appelle, où et comment**.
- Contraintes : l'API centrale tourne en 2 instances (redémarrages fréquents lors des livraisons) ; aucune escalade ne doit être oubliée ni envoyée deux fois au coordinateur ; la règle doit rester testable sans base réelle.
- Point chaud du mur : « Escalade 48 h : qui déclenche ? et si le serveur redémarre ? »

## Options
1. **Cron système sur une VM** qui appelle un script SQL ou un point d'API (option la plus simple) : + aucun code applicatif / − point unique de défaillance hors du déploiement ; la règle « 48 h » est réécrite en SQL, donc dupliquée hors du domaine.
2. **Tâche planifiée dans l'API centrale** (pg-boss, toutes les 15 min, verrou PostgreSQL pour qu'une seule instance l'exécute) qui appelle `AlerteService.escaladerAlertesEnRetard()` : + la règle reste dans l'agrégat, rattrapage automatique après un redémarrage, idempotente / − une dépendance de plus (pg-boss) ; l'escalade a jusqu'à 15 min de retard.
3. **Workflow n8n planifié** qui interroge l'API et déclenche l'escalade : + modifiable sans livrer / − règle métier dans un outil visuel non testé unitairement ; si n8n est en panne, plus d'escalade.

Écartée d'emblée : exécuter l'escalade sur la passerelle de site (elle ne connaît pas les prises en charge faites au central).

## Décision
Option 2. Elle obtient le meilleur score pondéré (4,75 sur 5 contre 2,95 et 2,70) et reste en tête quelle que soit la pondération des trois scénarios (voir `docs/evaluation/matrice.md`). Le critère décisif est la fiabilité : aucune escalade oubliée après un redémarrage, aucune en double avec deux instances.

## Conséquences
+ Une seule source de vérité pour la règle (l'agrégat `Alerte`) ; testée en moins de 5 s avec une horloge simulée.
+ L'événement `AlerteEscaladée` passe par l'outbox : la notification n'est envoyée qu'une fois la transaction validée.
− Une escalade peut arriver jusqu'à 15 min après l'échéance de 48 h (accepté : écart inférieur à 1 %).
− pg-boss ajoute des tables techniques dans PostgreSQL à sauvegarder et migrer.
À surveiller : âge de l'alerte LEVÉE la plus ancienne (cible < 48 h 15) ; nombre d'exécutions ratées de la tâche (cible 0 par semaine).

## Révision
Rouvrir si plus de 1 % des escalades dépassent 48 h 30, ou si le délai doit devenir configurable par type de risque et par site plus d'une fois par mois (alors un moteur de règles ou n8n redevient intéressant).
