# Analyse de menaces STRIDE sur le C4 de QueenBee · parcours Dev

Base : vue N2 (`docs/c4/n2-conteneurs.png`) et zones de la section 6.3 du cahier des charges.
Exigence Dev : au moins 2 flux dont celui de notre conteneur (API centrale), au moins 6 menaces sur au moins 4 lettres, au moins une menace traitée par un ADR. Nous analysons 5 flux et 14 menaces, sur les 6 lettres.

## 1. Zones de confiance

| Conteneur | Zone | Confiance |
|---|---|---|
| App terrain | Internet mobile (téléphone personnel) | faible : terminal non maîtrisé, perdable |
| Dashboard web | Internet (navigateur) | faible |
| Passerelle de site | Site · DMZ locale (VLAN 10), radio en IoT (VLAN 40) | faible |
| Broker MQTT central, Service d'identité | Central · DMZ (derrière le reverse proxy) | moyenne |
| **API centrale**, Ingestion, Service de prédiction, Orchestrateur de notifications | Central · applicatif | élevée |
| Base opérationnelle, Base de séries temporelles, Plateforme de données | Central · données | élevée |
| Supervision, SIEM et journal d'audit | Central · Management (VPN + MFA) | très élevée |
| Systèmes externes (FCM, SendGrid, OpenWeatherMap, OpenStreetMap) | Internet · tiers | non maîtrisée |

## 2. Flux analysés

| Flux | De → vers | Protocole | Zones traversées |
|---|---|---|---|
| F1 | App terrain → API centrale | HTTPS/JSON, JWT | Internet mobile → DMZ centrale → applicatif |
| F2 | Dashboard web → API centrale | HTTPS/JSON, JWT | Internet → DMZ centrale → applicatif |
| F3 | App terrain → Service d'identité | OIDC (PKCE) | Internet mobile → DMZ centrale |
| F4 | API centrale → Orchestrateur de notifications → FCM, Service d'e-mail | HTTPS (webhook signé), puis HTTPS / SMTP | applicatif → Internet tiers |
| F5 | Service de prédiction → API centrale | HTTPS/JSON, mTLS interne | applicatif → applicatif (frontière entre zone data et zone métier) |

## 3. Menaces et mesures

| Flux | STRIDE | Menace | Mesure | Réf. (UC, CDC, ADR) |
|---|---|---|---|---|
| F1 | S | Jeton volé sur un téléphone perdu, réutilisé par un tiers | Jeton d'accès de 15 min ; refresh token lié à l'appareil (DPoP), 7 jours hors ligne (usage hors ligne prolongé), révocable | UC-T01, CDC 8.2 |
| F1 | T | Lot d'opérations hors ligne rejoué ou modifié (inspection en double) | `opId` unique et idempotent, `If-Match` sur la version, validation du schéma JSON dans l'adaptateur HTTP | UC-A01, séquence Dev |
| F1 | R | Une apicultrice conteste avoir clôturé une alerte | Journal d'audit (utilisateur, appareil, opId, date de saisie hors ligne et date de synchronisation) expédié au SIEM en stockage WORM | CDC 7.2 (traçabilité), 8.2 |
| F1 | I | Fuite des positions des ruchers (risque de vol de ruches) | TLS 1.3 ; données locales chiffrées avant synchronisation (UC-T01) ; synchronisation limitée aux ruchers de l'utilisatrice ; coordonnées exactes réservées au rôle coordinateur | CDC 8.2 |
| F1 | D | Des centaines d'opérations envoyées d'un coup à la reconnexion saturent l'API | Lots de 100 opérations au maximum, limitation de débit par appareil (429 + `Retry-After`), file côté app avec backoff ; cible : 1 jour de données synchronisé en moins de 2 min | UC-A01, CDC 8.1 |
| F1 | E | Une apicultrice modifie une ruche d'un autre site en changeant l'identifiant dans l'URL | RBAC par site vérifié sur chaque ressource dans l'adaptateur HTTP ; tests d'accès croisés en CI | CDC 3.2, 8.2 |
| F2 | E | Un coordinateur s'attribue des droits d'administrateur via une route d'API | Rôles portés uniquement par le jeton Keycloak ; aucune route métier ne modifie un rôle ; changements de rôle réservés à l'administrateur et tracés | UC-AD01, CDC 3.2 |
| F2 | I | Export de rapports contenant des données personnelles des apicultrices | Indicateurs agrégés par site ; export nominatif réservé au gestionnaire et journalisé | CDC 8.2 |
| F2 | T | Injection SQL par un filtre du dashboard | Requêtes paramétrées uniquement (Kysely), rôle PostgreSQL par module limité à son schéma | ADR 0001 |
| F3 | S | Faux écran de connexion qui capte les identifiants | OIDC avec PKCE, MFA obligatoire pour coordinateurs, gestionnaires et administrateurs ; blocage après 5 tentatives | UC-T01, CDC 8.2 |
| F4 | S | Faux webhook vers l'Orchestrateur qui déclenche des notifications en masse (fausses alertes) | Webhook signé HMAC avec horodatage (rejet au-delà de 5 min), quota de notifications par jour et par site | ADR 0003 |
| F4 | T | Escalade envoyée deux fois au coordinateur ou envoyée pour une alerte jamais enregistrée | Outbox transactionnelle + `eventId` idempotent côté Orchestrateur ; tâche d'escalade protégée par un verrou | ADR 0002, ADR 0003 |
| F4 | D | Panne de FCM : les alertes n'arrivent plus | L'événement reste dans l'outbox ; bascule vers l'e-mail après 3 échecs ; l'alerte reste affichée au prochain accès à l'app | UC-A02 |
| F5 | S | Un processus interne se fait passer pour le Service de prédiction et lève de fausses alertes | mTLS interne : l'API n'accepte `POST /risques` que du certificat du Service de prédiction | UC-A02 |

Bilan : 14 menaces sur 5 flux ; lettres S (4), T (3), R (1), I (2), D (2), E (2). Menaces traitées par un ADR : F2-T (ADR 0001), F4-S (ADR 0003), F4-T (ADR 0002 et 0003).

## 4. Risques résiduels

- **Téléphone perdu pendant une longue période hors ligne** : le jeton reste utilisable jusqu'à 7 jours sans réseau. Surveillé par le coordinateur régional : indicateur « appareils déclarés perdus non révoqués » (cible 0).
- **Conflits de synchronisation mal résolus par l'utilisatrice** : une valeur correcte peut être écrasée. Surveillé par l'équipe Dev : nombre de 409 par semaine et versions conservées 90 jours pour restauration.
- **Retard de notification si l'outbox s'accumule** : surveillé en Supervision, alerte si plus de 500 événements en attente ou si le plus ancien a plus de 1 min.
- **Erreur humaine sur un seuil d'alerte** : chaque changement est journalisé ; revue mensuelle par le gestionnaire.
