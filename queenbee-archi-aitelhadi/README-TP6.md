# TP 6 · Documenter, sécuriser et évaluer l'architecture de QueenBee

- Auteur : AIT ELHADI Wissam · Spécialité : Dev
- Classe : Master 1 · Tronc commun · INGETIS · Architecture logicielle, séance 6


## Livrables

| Fichier | Partie | Contenu |
|---|---|---|
| `docs/c4/workspace.dsl` | A, B | Modèle Structurizr : 4 rôles du CDC, 5 systèmes externes, 14 conteneurs, 12 composants de l'API centrale ; vues N1, N2, N3 |
| `docs/c4/n1-contexte.png` | A | Vue N1 · Contexte |
| `docs/c4/n2-conteneurs.png` | A | Vue N2 · Conteneurs |
| `docs/c4/n3-api-centrale.png` | B | Vue N3 · Composants de l'API centrale |
| `docs/c4/conteneurs.md` | A | Raison de chaque séparation, placement des bounded contexts |
| `docs/sequences/synchronisation-inspection-hors-ligne.md` | B | UC-A01 en Mermaid ; `alt` version identique / conflit 409 / rejeu |
| `adr/0001-organiser-api-centrale-en-monolithe-modulaire.md` | dossier | Style de l'API centrale |
| `adr/0002-escalade-48h-tache-planifiee-api-centrale.md` | C | **ADR de spécialité Dev** : où exécuter la politique d'escalade à 48 h |
| `adr/0003-communiquer-entre-modules-par-evenements-et-outbox.md` | dossier | Communication entre modules |
| `docs/securite/stride.md` | D | Zones, 5 flux, 14 menaces sur les 6 lettres, risques résiduels |
| `docs/evaluation/matrice.md` | E | Scénarios de qualité, poids, matrice notée, sensibilité |

## Acteurs (CDC 3.2)
Apicultrice / apiculteur (~300), Coordinateur régional (8), Gestionnaire association (6), Administrateur (3).

## Le N3 de l'API centrale
Un module par bounded context (Terrain, Santé des colonies, Coordination, Référentiel, Impact), un adaptateur HTTP en entrée, des adaptateurs SQL en sortie. Chaque module ne passe que par son port Repository, limité à son schéma PostgreSQL : aucun module n'accède à la base d'un autre. Les réactions entre modules passent par le bus d'événements et l'outbox (ADR 0003).

## Afficher les diagrammes
- Structurizr : coller `docs/c4/workspace.dsl` sur structurizr.com/dsl, ou dans PowerShell :
  `docker run -it --rm -p 8080:8080 -v "${PWD}/docs/c4:/usr/local/structurizr" structurizr/lite` puis http://localhost:8080
- Mermaid : aperçu GitHub ou GitLab, ou mermaid.live ; le PNG est fourni à côté du `.md`.

## Restitution
1. **Boîte non séparée** : Coordination et Impact restent des modules de l'API centrale ; même charge, même public, mêmes données, donc un service de plus n'apporterait que du coût de déploiement, de supervision et de sécurité.
2. **Option écartée** : le workflow n8n pour l'escalade. Il aurait permis de changer le délai sans livrer, mais la règle métier serait sortie de l'agrégat `Alerte` et ne serait plus testée unitairement.
3. **Menace la plus grave** : F1-E, une apicultrice qui modifie les ruches d'un autre site en changeant l'identifiant dans l'URL ; mesure : RBAC par site vérifié sur chaque ressource (CDC 8.2), avec tests d'accès croisés en CI.
