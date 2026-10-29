# Décision évaluée : ADR 0002 · Exécuter la politique d'escalade à 48 h par une tâche planifiée idempotente dans l'API centrale

Options : **A** cron système sur une VM · **B** tâche planifiée dans l'API centrale (pg-boss + verrou) · **C** workflow n8n planifié.

## Scénarios de qualité (poids fixés avant de noter)
- **S1 Fiabilité** : une alerte reste LEVÉE 48 h pendant qu'une instance de l'API redémarre → elle est escaladée au coordinateur en moins de 48 h 15, dans 100 % des cas. **Poids : 45 %**
- **S2 Modifiabilité / testabilité** : le délai passe de 48 h à 24 h pour le risque « mortalité » → changement livré en moins d'une journée, couvert par des tests unitaires qui tournent en moins de 5 s sans base réelle. **Poids : 30 %**
- **S3 Exploitabilité** : l'API tourne en 2 instances pendant un mois → 0 escalade en double et aucun composant supplémentaire à superviser. **Poids : 25 %**

## Matrice (notes de 1 à 5)
| Scénario (poids) | A · Cron système | B · Tâche dans l'API | C · Workflow n8n |
|---|---|---|---|
| S1 (45 %) | 3 | 5 | 3 |
| S2 (30 %) | 2 | 5 | 2 |
| S3 (25 %) | 4 | 4 | 3 |
| **Score pondéré /5** | **2,95** | **4,75** | **2,70** |

Calcul : A = 0,45×3 + 0,30×2 + 0,25×4 = 2,95 · B = 0,45×5 + 0,30×5 + 0,25×4 = 4,75 · C = 0,45×3 + 0,30×2 + 0,25×3 = 2,70.

## Justification des notes
- S1 · A = 3 : le cron rattrape au passage suivant, mais si sa VM tombe plus de 15 min, aucune escalade n'a lieu.
- S1 · B = 5 : la tâche est dans chaque instance, le verrou garantit qu'une seule l'exécute, et l'état est relu dans PostgreSQL à chaque passage.
- S1 · C = 3 : dépend à la fois de n8n et de l'API ; une panne de n8n suspend les escalades.
- S2 · A = 2 : la règle « 48 h » est réécrite en SQL hors de l'agrégat, donc dupliquée et testée seulement contre une vraie base.
- S2 · B = 5 : la règle reste dans `Alerte.estEnRetard()` ; les 12 tests du TP 5 la couvrent avec une horloge simulée.
- S2 · C = 2 : la condition vit dans un nœud n8n, sans test unitaire.
- S3 · A = 4 : une seule VM donc pas de doublon, mais un élément à surveiller hors du déploiement.
- S3 · B = 4 : pas de doublon grâce au verrou ; pg-boss ajoute des tables techniques à sauvegarder.
- S3 · C = 3 : risque de doublon si le workflow est relancé à la main après une erreur, et un appel réseau de plus à surveiller.

## Sensibilité
L'option B a une note supérieure ou égale aux deux autres sur **chacun** des trois scénarios : aucune répartition des poids ne la fait perdre. La décision est robuste.
Seul un nouveau critère pourrait l'inverser : avec **S4 Délai de mise en place** (A = 5, B = 3, C = 4), l'option A ne gagne que si S4 pèse plus de 47 % du total. Ce n'est pas plausible pour BeeAfrica : une escalade oubliée laisse une colonie malade sans visite, alors qu'un jour de développement en plus est un coût unique.

## Conclusion → ADR 0002
Option B retenue (4,75 / 5), décision robuste à toute variation de poids. Reportée dans la section « Décision » de l'ADR 0002.
