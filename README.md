# Datavisualisation_M1_EPSI

```
tp-dataviz/
│
├── docker-compose.yml
│
├── prometheus/
│   └── prometheus.yml
│
├── grafana/
│   └── provisioning/
│       └── datasources/
│           └── datasources.yml
│
├── loki/                       # (Optionnel si tu fais aussi les logs)
│   ├── loki-config.yml
│   └── promtail-config.yml
│
├── logs/                       # (Optionnel) dossier local pour logs custom
│
└── README.md                   # (facultatif, pour décrire ton TP)
```

___

📁 Détails de chaque dossier

| Dossier / Fichier                                    | Rôle                                                                                                      |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **docker-compose.yml**                               | Le fichier principal : définit tous les services Docker, leurs ports, volumes, dépendances, réseaux, etc. |
| **prometheus/prometheus.yml**                        | Configuration de Prometheus : quels exporters scraper, intervalle, etc.                                   |
| **grafana/provisioning/datasources/datasources.yml** | Auto-provisioning des connexions Grafana (Prometheus et Loki).                                            |
| **loki/loki-config.yml** *(optionnel)*               | Configuration du moteur de logs Loki.                                                                     |
| **loki/promtail-config.yml** *(optionnel)*           | Configuration de Promtail pour collecter les logs Docker.                                                 |
| **logs/** *(optionnel)*                              | Si tu veux y rediriger des logs de services ou de tests manuels.                                          |
| **README.md**                                        | Notes de ton TP, commandes utiles, etc.                                                                   |

___

💾 Volumes persistants créés par Docker

| Volume         | Contenu persisté                         | Monté où ?         |
| -------------- | ---------------------------------------- | ------------------ |
| `prom_data`    | Base de données interne de Prometheus    | `/prometheus`      |
| `grafana_data` | Dashboards, datasources, comptes Grafana | `/var/lib/grafana` |
| `mysql_data`   | Données MySQL (tables, users, etc.)      | `/var/lib/mysql`   |
| `loki_data`    | Logs stockés par Loki (si activé)        | `/loki`            |

___

