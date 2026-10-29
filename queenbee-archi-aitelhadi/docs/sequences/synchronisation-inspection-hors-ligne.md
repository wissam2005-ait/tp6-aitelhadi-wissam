# Séquence · Synchroniser une inspection saisie hors ligne (UC-A01) · parcours Dev

Participants : personnes et conteneurs du N2 (mêmes noms). Traits pleins = appels synchrones, pointillés = réponses ou événements.

```mermaid
sequenceDiagram
  actor A as Apicultrice / apiculteur
  participant P as App terrain
  participant K as Service d'identité
  participant C as API centrale
  participant D as Base opérationnelle
  participant N as Orchestrateur de notifications

  A->>P: Saisit l'inspection de la ruche SN-CASA-014 (hors réseau)
  P->>P: Enregistre l'opération dans la file IndexedDB (opId, version lue = 7)
  Note over A,P: Retour du réseau : le Service Worker déclenche la synchronisation
  P->>K: Renouvelle le jeton (refresh token lié à l'appareil)
  K-->>P: Jeton d'accès (15 min)
  P->>C: POST /sync [opId, inspection, If-Match: 7]
  C->>D: SELECT version, opId déjà appliqué ?
  D-->>C: version = 7, opId inconnu
  alt version identique (7 = 7)
    C->>D: INSERT inspection + UPDATE version = 8 + INSERT outbox (une transaction)
    D-->>C: OK
    C-->>P: 200 OK [version 8]
    C-->>N: InspectionEnregistrée (via outbox, webhook signé)
    P-->>A: Inspection synchronisée
  else conflit : la fiche a changé côté central (version 9)
    C-->>P: 409 Conflict [version serveur 9 + champs en conflit]
    P-->>A: Affiche les deux versions champ par champ
    A->>P: Choisit les valeurs à garder
    P->>C: POST /sync [nouvel opId, fusion, If-Match: 9]
    C-->>P: 200 OK [version 10]
  else opération déjà appliquée (rejeu après coupure)
    C-->>P: 200 OK [résultat mémorisé, aucun double enregistrement]
  end
```
