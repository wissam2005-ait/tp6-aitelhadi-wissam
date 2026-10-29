# ADR 0001 · Organiser l'API centrale en monolithe modulaire, un module et un schéma par bounded context

- Statut : accepté · Date : 2026-10-23 · Auteurs : AIT ELHADI Wissam · Spécialité : Dev
- Élément du C4 : conteneur « API centrale » (N2) et sa vue N3

## Contexte
- L'Event Storming du TP 5 fait apparaître cinq contextes côté central : Terrain, Santé des colonies, Coordination, Référentiel, Impact.
- CDC 1.4 : BeeAfrica est une association ; 8 sites, 400 ruches, environ 317 utilisateurs (300 apiculteurs, 8 coordinateurs, 6 gestionnaires, 3 administrateurs). Charge modeste, équipe technique réduite.
- CDC 5.2 et 9.1 : la spécialité Dev doit conteneuriser, déployer par CI/CD et superviser chaque service ; chaque déployable supplémentaire multiplie ce travail.
- CDC 8.1 : API centrale < 500 ms (p95).
- Point chaud du mur : « qui est propriétaire de la ruche ? » (Référentiel lu par tous les autres contextes).

## Options
1. **Monolithe en couches, une seule base partagée sans frontière** : + le plus simple à livrer / − les contextes se couplent par des jointures, impossible à découper plus tard.
2. **Monolithe modulaire** (un module hexagonal par contexte, un schéma et un rôle PostgreSQL par module, communication par événements internes + outbox) : + un seul déploiement, frontières vérifiables / − discipline à tenir, un module lent peut ralentir les autres.
3. **Un microservice et une base par contexte** : + déploiement et charge indépendants / − 5 déployables, 5 bases, un bus, de la supervision et de la sécurité en plus pour une équipe de 2 ou 3 développeurs.

## Décision
Option 2. Elle donne les frontières de l'option 3 au coût d'exploitation de l'option 1.

## Conséquences
+ Une seule image à déployer et à superviser ; transactions locales simples.
+ Un module pourra être extrait en service si un besoin réel apparaît (les ports existent déjà).
− Il faut outiller la règle de dépendance (lint d'architecture en CI, comme `npm run lint:archi`).
− Une montée en charge concerne tout le monolithe.
À surveiller : nombre d'imports interdits détectés en CI (cible 0) ; temps de réponse p95 par module.

## Révision
Rouvrir si un module doit être livré plus d'une fois par semaine indépendamment des autres, ou si un module consomme plus de 60 % du CPU de l'API pendant plus d'un mois.
