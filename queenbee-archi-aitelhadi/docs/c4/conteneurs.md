# Conteneurs de QueenBee (C4 niveau 2)

Vue : `N2-Conteneurs` dans `workspace.dsl` · export : `n2-conteneurs.png`.
Règle suivie : un conteneur n'est séparé que pour une raison d'exécution, de charge, de technologie, de données ou de public. « C'est un bounded context » ne suffit pas.

## Pourquoi chaque conteneur est séparé

| Conteneur | Technologie | Pourquoi séparé | Contextes hébergés | Données stockées |
|---|---|---|---|---|
| App terrain | PWA React, IndexedDB, Service Worker | Autre lieu d'exécution (téléphone de l'apicultrice) et doit fonctionner hors ligne plusieurs jours | Terrain (saisie), Santé (consultation des alertes) | File d'opérations et copie locale des ruches de l'utilisatrice (IndexedDB) |
| Dashboard web | SPA React (TypeScript) | Autre public (8 coordinateurs, 6 gestionnaires, 3 administrateurs, CDC 1.4) et autre cycle de livraison que l'app terrain | Coordination, Impact, Référentiel (écrans) | Aucune (sans état) |
| Passerelle de site | K3s, ChirpStack, Mosquitto, Node.js 22 | Autre lieu d’exécution : une par site (8 sites, environ 50 ruches chacune, CDC 1.4 et 6.4), doit continuer à collecter et alerter quand le site est coupé | Télémétrie (collecte, cache), Santé (alertes locales simplifiées) | Cache local chiffré : 14 jours de mesures non transmises |
| Broker MQTT central | EMQX 5 | Autre rythme de charge : absorbe les rafales de resynchronisation des sites sans faire tomber l'ingestion | Télémétrie (transport) | Messages en transit (sessions persistantes) |
| Ingestion | Node.js 22 (worker) | Autre rythme de charge (flux continu, pics à la reconnexion) ; doit pouvoir monter en charge indépendamment de l'API | Télémétrie | Aucune (sans état) ; écrit dans la base de séries temporelles |
| API centrale | Node.js 22, Fastify, hexagonale | Point d'entrée unique des cas d'utilisation ; monolithe modulaire (ADR 0001) | Terrain, Santé des colonies, Coordination, Référentiel, Impact (un module par contexte) | Aucune (sans état) |
| Base opérationnelle | PostgreSQL 16 + PostGIS | Stockage de données transactionnelles et géographiques ; sauvegarde et restauration propres | Un schéma par module : terrain, sante, coordination, referentiel | Sites, ruches, inspections, alertes, visites, outbox |
| Base de séries temporelles | TimescaleDB | Stockage de données au profil différent : très nombreuses écritures horodatées, agrégats continus, rétention par partition | Télémétrie | Mesures brutes (≈ 10 Mo/jour, CDC 6.4), agrégats 15 min / heure / jour |
| Service de prédiction | Python 3.12, FastAPI, LightGBM | Autre langage (écosystème ML Python) et autre cycle de vie (déploiement d'un nouveau modèle sans livrer l'API) | Prédiction (analyse de santé) | Aucune (modèle chargé depuis le registre) |
| Plateforme de données | Python, Dagster, dbt, MLflow | Autre rythme de charge (traitements lourds par lots) et autre public (équipe data) ; ne doit pas ralentir l'opérationnel | Prédiction (entraînement), Impact (indicateurs) | Staging Parquet, entrepôt en étoile, registre de modèles |
| Service d'identité | Keycloak 25 | Produit standard à cycle de vie propre ; données sensibles (comptes) isolées ; partagé par l'app, le dashboard et l'API | Identité et accès | Comptes, rôles par site, sessions, clés de signature |
| Orchestrateur de notifications | n8n | Autre public (l’administrateur modifie un canal ou un modèle de message sans redéployer l'API) ; isole les secrets des fournisseurs externes | Notification (générique) | Historique d'exécution des workflows, secrets des fournisseurs |
| Supervision | Prometheus, Grafana, Loki (CDC 9.1) | Autre public (exploitation, dashboard d’exploitation DevOps) et doit rester disponible quand l'application est en panne | Aucun contexte métier | Métriques et journaux techniques (30 jours) |
| SIEM et journal d'audit | Wazuh, stockage WORM | Autre zone de confiance (management) : les journaux doivent échapper à un attaquant qui compromettrait l'API | Aucun contexte métier | Événements de sécurité et journal d'audit signé (conservation 1 an) |

## Où vivent les bounded contexts du TP 5

| Bounded context | Hébergement |
|---|---|
| Terrain (inspections, visites) | Module de l'API centrale ; saisie dans l'App terrain |
| Santé des colonies (alertes, seuils, escalade 48 h) | Module de l'API centrale ; version simplifiée des seuils sur la Passerelle de site |
| Coordination (planification des visites) | Module de l'API centrale |
| Référentiel (sites, ruchers, ruches, apicultrices) | Module de l'API centrale |
| Impact et reporting | Module de l'API centrale (lecture) + tables analytiques de la Plateforme de données |
| Télémétrie (mesures) | Passerelle de site → Broker MQTT central → Ingestion → Base de séries temporelles |
| Prédiction | Service de prédiction (inférence) + Plateforme de données (entraînement) |
| Identité et accès | Service d'identité |

Cinq contextes partagent donc un seul déployable (monolithe modulaire). L'isolation est garantie dans le code (ports, un schéma et un rôle PostgreSQL par module, aucune jointure entre schémas) et non par le réseau. Voir le N3 de l'API centrale.

## Ce que nous avons choisi de ne pas séparer

- **Coordination et Impact** restent des modules de l'API centrale : même charge, même public métier, mêmes données. Un service séparé coûterait un déploiement, une supervision et une surface d'attaque de plus pour aucun gain mesurable.
- **La politique d'escalade à 48 h** n'est pas un service : c'est une tâche planifiée du module Santé (ADR 0002).
- **Un seul PostgreSQL opérationnel**, avec un schéma par module, plutôt qu'une base par contexte.
