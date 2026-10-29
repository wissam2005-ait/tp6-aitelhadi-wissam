workspace "QueenBee" "Plateforme apicole de BeeAfrica" {

  !identifiers flat

  model {
    # --- Personnes (rôles du CDC)
    apicultrice = person "Apicultrice / apiculteur" "Inspecte ses ruches, saisit les inspections hors ligne et prend en charge les alertes de son rucher"
    coord = person "Coordinateur régional" "Priorise et assigne les visites des sites de sa région, reçoit les alertes escaladées"
    gest = person "Gestionnaire association" "Supervise tous les sites et coopératives, consulte les analytics et génère les rapports d'impact pour les bailleurs"
    admin = person "Administrateur" "Gère utilisateurs et rôles, supervise déploiements, infrastructure et sécurité, configure les seuils d'alerte"

    # --- Systèmes externes
    ruches = softwareSystem "Ruches connectées" "400 ruches : capteurs de poids, température, humidité, acoustique et GPS (LoRaWAN)" "Externe"
    meteo = softwareSystem "OpenWeatherMap" "Météo observée et prévue par site" "Externe"
    fcm = softwareSystem "Firebase Cloud Messaging" "Notifications push différées vers les téléphones" "Externe"
    mail = softwareSystem "Service d'e-mail (SendGrid)" "Envoi des notifications, escalades et rapports aux bailleurs" "Externe"
    osm = softwareSystem "OpenStreetMap" "Tuiles cartographiques des ruchers (Leaflet)" "Externe"

    queenbee = softwareSystem "QueenBee" "Plateforme de suivi des ruchers de BeeAfrica : télémétrie, santé des colonies, inspections, coordination" {
      app = container "App terrain" "Inspections hors ligne, alertes, carte des ruches" "PWA React, IndexedDB, Service Worker"
      web = container "Dashboard web" "Coordination des visites, impact, administration" "SPA React (TypeScript)"
      edge = container "Passerelle de site" "Collecte radio, cache local, alertes locales, relais vers le central" "K3s, ChirpStack, Mosquitto, Node.js 22"
      broker = container "Broker MQTT central" "Reçoit et tamponne les lots des passerelles" "EMQX 5 (MQTT 5, TLS)"
      ing = container "Ingestion" "Vérifie, déduplique, horodate et stocke les mesures" "Node.js 22 (worker)"
      core = container "API centrale" "Monolithe modulaire : Terrain, Santé des colonies, Coordination, Référentiel, Impact" "Node.js 22, Fastify, architecture hexagonale" {
        http = component "Adaptateur HTTP" "Routes REST, validation des schémas, contrôle JWT et RBAC par site" "Fastify"
        sync = component "Moteur de synchronisation" "Rejoue les opérations hors ligne, idempotence et contrôle de version" "TypeScript"
        mTerrain = component "Module Terrain" "Agrégat Inspection, visites réalisées" "TypeScript (domaine)"
        mSante = component "Module Santé des colonies" "Agrégat Alerte, seuils, politique d'escalade 48 h" "TypeScript (domaine)"
        mCoord = component "Module Coordination" "Planification et assignation des visites" "TypeScript (domaine)"
        mRef = component "Module Référentiel" "Sites, ruchers, ruches, apicultrices" "TypeScript (domaine)"
        mImpact = component "Module Impact" "Indicateurs et rapports (lecture seule)" "TypeScript"
        bus = component "Bus d'événements + outbox" "Événements de domaine, table outbox transactionnelle" "EventEmitter + table outbox"
        planif = component "Planificateur" "Lance les tâches périodiques (escalade toutes les 15 min)" "pg-boss"
        repo = component "Adaptateurs SQL" "Un dépôt par module, chacun limité à son schéma (rôle PostgreSQL dédié)" "pg + Kysely"
        notifA = component "Adaptateur de notification" "Webhook signé vers l'orchestrateur" "HTTP client"
        audit = component "Journal d'audit" "Trace chaque commande (qui, quoi, quand, site)" "pino + syslog"
      }
      db = container "Base opérationnelle" "Sites, ruches, inspections, alertes, visites (un schéma par module)" "PostgreSQL 16 + PostGIS" "Database"
      tsdb = container "Base de séries temporelles" "Mesures brutes et agrégats (15 min, heure, jour)" "TimescaleDB (PostgreSQL 16)" "Database"
      pred = container "Service de prédiction" "Calcule les scores de santé et de risque par ruche" "Python 3.12, FastAPI, LightGBM"
      dataplat = container "Plateforme de données" "ETL, entrepôt, jeux d'entraînement, registre de modèles" "Python, Dagster, dbt, MLflow"
      idp = container "Service d'identité" "Comptes, rôles par site, jetons OIDC" "Keycloak 25"
      notif = container "Orchestrateur de notifications" "Push, e-mails d’escalade, rapports bailleurs planifiés (UC-G02)" "n8n"
      supervision = container "Supervision" "Métriques, journaux techniques, disponibilité des sites" "Prometheus, Grafana, Loki"
      siem = container "SIEM et journal d'audit" "Événements de sécurité, audit signé et conservé" "Wazuh (SIEM central), stockage WORM" "Database"
    }

    # --- Niveau 1 (déclarées en premier : évite les relations implicites mal libellées)
    apicultrice -> queenbee "Saisit les inspections et prend en charge les alertes" "HTTPS, hors ligne"
    coord -> queenbee "Priorise et assigne les visites" "HTTPS"
    gest -> queenbee "Suit l'impact et exporte les rapports" "HTTPS"
    admin -> queenbee "Administre sites, passerelles, seuils et comptes" "HTTPS, VPN WireGuard"
    ruches -> queenbee "Émettent les mesures toutes les 15 min (5 min en surveillance)" "LoRaWAN"
    queenbee -> meteo "Récupère la météo de chaque site" "HTTPS/JSON"
    queenbee -> fcm "Demande l'envoi des notifications push" "HTTPS (FCM v1)"
    queenbee -> mail "Envoie escalades et rapports" "SMTP/TLS"
    queenbee -> osm "Affiche la carte des ruchers" "HTTPS"
    fcm -> apicultrice "Notifie les alertes" "Push"
    mail -> coord "Transmet escalades et anomalies" "E-mail"

    # --- Niveau 2
    apicultrice -> app "Saisit les inspections, consulte les alertes" "HTTPS, hors ligne"
    coord -> web "Priorise et assigne les visites" "HTTPS"
    gest -> web "Consulte l'impact, exporte les rapports" "HTTPS"
    admin -> web "Administre seuils, comptes et sites" "HTTPS"
    admin -> supervision "Surveille sites et services" "HTTPS, VPN WireGuard"
    admin -> edge "Administre la passerelle" "SSH, VPN WireGuard"
    ruches -> edge "Émettent les mesures" "LoRaWAN (AES-128)"
    app -> core "Synchronise les opérations hors ligne" "HTTPS/JSON, JWT"
    app -> idp "S'authentifie et renouvelle son jeton" "OIDC (PKCE)"
    app -> edge "Lit les alertes locales quand le site est coupé" "HTTPS (Wi-Fi du site)"
    web -> core "Appelle les cas d'utilisation" "HTTPS/JSON, JWT"
    web -> idp "Authentifie les utilisateurs" "OIDC"
    edge -> broker "Publie les lots de mesures signés" "MQTT 5, mTLS"
    edge -> supervision "Envoie métriques et journaux" "HTTPS, tunnel WireGuard"
    edge -> siem "Envoie les événements de sécurité" "Syslog/TLS, tunnel WireGuard"
    broker -> ing "Délivre les lots (abonnement partagé)" "MQTT 5"
    ing -> tsdb "Écrit les mesures validées" "SQL"
    ing -> meteo "Récupère la météo du site" "HTTPS/JSON"
    ing -> siem "Signale les lots rejetés" "Syslog/TLS"
    pred -> tsdb "Lit les fenêtres de mesures" "SQL"
    pred -> core "Soumet les scores de risque" "HTTPS/JSON, mTLS interne"
    pred -> dataplat "Charge le modèle promu" "HTTPS (API MLflow)"
    dataplat -> tsdb "Extrait les mesures" "SQL (lecture seule)"
    dataplat -> db "Extrait inspections et alertes" "SQL (réplica en lecture)"
    core -> db "Lit et écrit" "SQL"
    core -> dataplat "Lit les indicateurs d'impact" "SQL (lecture seule)"
    core -> idp "Valide les jetons" "HTTPS (JWKS)"
    core -> notif "Transmet les événements à notifier" "HTTPS, webhook signé"
    core -> siem "Envoie le journal d'audit" "Syslog/TLS"
    idp -> siem "Envoie les événements de connexion" "Syslog/TLS"
    notif -> fcm "Envoie les notifications push" "HTTPS (FCM v1)"
    notif -> mail "Envoie escalades et rapports" "SMTP/TLS"
    web -> osm "Charge les tuiles de la carte" "HTTPS"
    notif -> core "Lit les données des rapports" "HTTPS/JSON, jeton de service"

    # --- Niveau 3 · API centrale
    app -> http "Envoie les lots d'opérations" "HTTPS/JSON, JWT"
    web -> http "Appelle les cas d'utilisation" "HTTPS/JSON, JWT"
    pred -> http "Soumet les scores de risque" "HTTPS/JSON, mTLS"
    http -> idp "Récupère les clés de signature" "HTTPS (JWKS)"
    http -> audit "Trace chaque commande" "appel interne"
    http -> sync "Transmet les lots hors ligne" "appel interne"
    sync -> mTerrain "Applique les opérations d'inspection" "port EnregistrerInspection"
    http -> mSante "Transmet scores et prises en charge" "port LeverAlerte / Assigner"
    http -> mCoord "Transmet les assignations" "port AssignerVisite"
    http -> mRef "Transmet les modifications du référentiel" "port GérerRéférentiel"
    http -> mImpact "Demande les indicateurs" "port ConsulterImpact"
    mTerrain -> bus "Publie InspectionEnregistrée" "événement"
    mSante -> bus "Publie AlerteLevée, AlerteEscaladée" "événement"
    bus -> mSante "Délivre InspectionEnregistrée" "abonnement"
    bus -> mCoord "Délivre AlerteEscaladée" "abonnement"
    bus -> notifA "Délivre les événements à notifier" "abonnement"
    planif -> mSante "Déclenche l'escalade des alertes en retard" "toutes les 15 min"
    mTerrain -> repo "Persiste (schéma terrain)" "port InspectionRepository"
    mSante -> repo "Persiste (schéma sante)" "port AlerteRepository"
    mCoord -> repo "Persiste (schéma coordination)" "port VisiteRepository"
    mRef -> repo "Persiste (schéma referentiel)" "port RucheRepository"
    bus -> repo "Écrit l'outbox dans la même transaction" "SQL"
    repo -> db "Lit et écrit" "SQL"
    planif -> db "Prend un verrou de tâche" "SQL (advisory lock)"
    mImpact -> dataplat "Lit les tables analytiques" "SQL (lecture seule)"
    notifA -> notif "Envoie le webhook signé" "HTTPS, HMAC"
    audit -> siem "Expédie le journal d'audit" "Syslog/TLS"
  }

  views {
    systemContext queenbee "N1-Contexte" {
      title "N1 · Contexte de QueenBee"
      include *
      autolayout tb
    }
    container queenbee "N2-Conteneurs" {
      title "N2 · Conteneurs de QueenBee"
      include *
      autolayout tb
    }
    component core "N3-API-centrale" {
      title "N3 · Composants · API centrale"
      include *
      autolayout lr
    }
    styles {
      element "Person" { shape Person background #08427b color #ffffff }
      element "Software System" { background #1168bd color #ffffff }
      element "Container" { background #438dd5 color #ffffff }
      element "Component" { background #85bbf0 color #000000 }
      element "Database" { shape Cylinder }
      element "Externe" { background #999999 color #ffffff }
      relationship "Relationship" { dashed false }
    }
  }
}
