# Vue d'ensemble des contributions des membres — revisitée SQL

Une requête SQL réelle que j'ai écrite pour un cas d'usage d'analyse de
donateurs et de membres, accompagnée de la version améliorée que j'écrirais
aujourd'hui. J'ai conservé les deux volontairement : l'écart entre elles est un
instantané de l'évolution de ma pratique SQL.

**Contexte d'affaires.** La requête construit une vue d'ensemble par membre à
partir d'un schéma en étoile (tables de faits pour les transactions et les
souscriptions, dimensions pour les clients et les détails de transaction) : une
ligne par courriel de membre, combinant les métriques globales, récurrentes et
uniques des contributions, ainsi que le statut de souscription. Le résultat
alimentait la segmentation et les rapports sur les relations avec les donateurs.

- [`original/creation_overview_membres.sql`](original/creation overview membres.sql) — telle qu'écrite en production (MySQL)
- [`revisite/improved_version.sql`](revisite/improved_version.sql) — la réécriture de 2026 (MySQL 8.0+)

## Ce qui a changé, et pourquoi c'est important

### 1. Sous-requêtes imbriquées → CTE nommées
La requête originale répétait la même jointure de trois tables (`FACT_CHARGE` →
`DIM_CUSTOMER` → `DIM_CHARGE_DETAIL`) et les mêmes filtres
(`status = 'succeeded'`, `is_refunded = 0`, courriel valide) dans trois tables
dérivées distinctes. La version améliorée les centralise dans une seule CTE
`charges` dont chaque agrégation dépend.

**Pourquoi c'est important :** une seule définition d'une « transaction
valide » au lieu de trois. Si la règle d'affaires change, elle change à un seul
endroit — aucun risque que les segments récurrents et uniques divergent
silencieusement.

### 2. Correction d'un vrai bogue : `ORDER BY 'creation_date'`
La sous-requête des souscriptions triait selon la *chaîne littérale*
`'creation_date'` (remarquez les guillemets), et non selon la colonne — une
opération sans effet qui semblait pourtant intentionnelle. La mise à jour la
supprime et donne plutôt à `GROUP_CONCAT` un ordre interne déterminé, là où
le tri comptait réellement.

**Pourquoi c'est important :** le bogue était inoffensif ici, mais la même
erreur dans un `GROUP_CONCAT` ou une fonction de fenêtrage produirait des
résultats silencieusement erronés. La détecter exige de connaître la différence
entre `'col'` et `` `col` `` en MySQL.

### 3. Suppression du `DISTINCT` redondant et du `GROUP BY 1..18`
La version originale combinait `SELECT DISTINCT` avec un `GROUP BY` portant sur
les dix-huit colonnes de sortie. Le regroupement déduplique déjà; ce motif
trahit un débogage par essais et erreurs. La version améliorée ne regroupe que là
où l'agrégation a lieu (dans chaque CTE), sur les colonnes qui définissent le
grain.

**Pourquoi c'est important :** au-delà du calcul gaspillé, `GROUP BY 1..18`
obscurcit le grain de la requête. La refactorisation le rend explicite : une
ligne par courriel.

### 4. Filtres qualifiés et uniformes
Le `WHERE status = 'succeeded'` externe de l'original n'était pas qualifié
parmi trois tables jointes — il fonctionnait, mais seulement grâce au hasard de
l'unicité des noms de colonnes. Le filtrage des courriels alternait aussi entre
`!= " "` et `!= ''`. La mise à jour qualifie chaque référence et utilise
uniformément `TRIM(email) <> ''`, ce qui capte à la fois les valeurs vides et
celles composées uniquement d'espaces.

### 5. Code mort et petits problèmes d'exactitude
Suppression des clauses `ORDER BY` à l'intérieur des sous-requêtes (la requête
externe contrôle le tri; les tris internes ne font que coûter du temps) et
correction de l'identifiant de fuseau horaire (`'Us/Eastern'` →
`'US/Eastern'`).

### 6. La documentation comme partie intégrante du livrable
La mise à jour s'ouvre sur un en-tête énonçant l'objectif de la requête, son
grain, son dialecte et — surtout — ses contournements liés à la qualité des
données : le type de transaction est déduit d'un champ de description parce
qu'aucun indicateur dédié n'existe, et les courriels vides sont exclus en tant
que problème connu en amont. L'original s'appuyait sur la connaissance tacite de
l'équipe pour ces deux points.

**Pourquoi c'est important :** le prochain analyste (ou mon futur moi) ne
devrait pas avoir à rétroconcevoir pourquoi
`description != 'Contribution unique'` signifie « récurrent ».

## Équivalence de comportement

La mise à jour est conçue pour produire une sortie équivalente à
l'originale, avec une nuance délibérée documentée dans le code : l'originale
regroupait sur toutes les colonnes de sortie, de sorte qu'un courriel associé à
des valeurs incohérentes de nom ou de genre dans `DIM_CUSTOMER` produirait
plusieurs lignes; la mise à jour préserve ce comportement en regroupant
`global_stats` sur courriel + nom + genre. Sans accès aux données de
production, l'équivalence a été vérifiée par raisonnement sur le grain plutôt
que par comparaison des sorties — mentionné ici en toute transparence comme une
limite.

## À retenir

La requête originale fonctionnait, a été livrée et répondait à la question
d'affaires — cela compte toujours. Ce que la mise à jour ajoute, c'est ce
que je considère désormais comme non négociable en SQL analytique : une source
unique de vérité pour les filtres, un grain explicite, une structure qui se
documente elle-même et des commentaires qui capturent le contexte de qualité des
données dont un futur analyste aura besoin.
