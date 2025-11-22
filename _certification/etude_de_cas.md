# ÉTUDE DE CAS E6 – ShopNow Marketplace

## Contexte

ShopNow est une plateforme e-commerce en forte croissance.
L’entreprise a historiquement fonctionné comme un vendeur unique centralisé : tous les produits vendus sur le site provenaient de son catalogue interne.

Pour augmenter son offre et ses revenus, ShopNow décide de se transformer en Marketplace.
Ce pivot stratégique permet désormais à des vendeurs tiers de proposer leurs propres produits sur la plateforme.

Le Data Warehouse actuel a été conçu avant cette transition et repose sur un modèle en étoile simple incluant :
- dim_customer
- dim_product
- fact_order
- fact_clickstream

Il est alimenté par des données internes et par un flux temps réel provenant d’Azure Event Hubs.

## Nouveaux enjeux liés au modèle Marketplace

L’arrivée des vendeurs tiers introduit plusieurs contraintes auxquelles l’entrepôt de données doit s’adapter.
Les responsables métiers mettent en avant les besoins suivants :

1. Suivi des vendeurs dans le temps

Les vendeurs disposent désormais d’informations propres à leur activité (profil, statut, catégorie, etc.).
Ces informations peuvent évoluer dans le temps et doivent être exploitables pour l’analyse et le pilotage.

2. Qualité des données envoyées par les vendeurs tiers

Les vendeurs transmettent leurs données produits et opérationnelles via des flux variés.
Certaines de ces données peuvent être incorrectes, incomplètes ou incohérentes.

Les équipes souhaitent pouvoir :
- identifier les anomalies
- isoler les données problématiques
- assurer la fiabilité analytique malgré la diversité des sources

3. Intégration de nouvelles sources externes

ShopNow souhaite recevoir des informations complémentaires depuis les systèmes des vendeurs, notamment :
- les niveaux de stock
- les mises à jour de produits
- les disponibilités

Certaines de ces informations proviendront d’API externes ou de systèmes hétérogènes

4. Sécurité et cloisonnement des données

Chaque vendeur doit pouvoir accéder uniquement aux données le concernant.
Les équipes internes doivent conserver une vision globale, tandis que les vendeurs ne doivent voir que leurs propres informations opérationnelles et analytiques.

## Objectif de la mission

L’équipe Data doit proposer les évolutions nécessaires pour maintenir l’entrepôt en conditions opérationnelles dans ce nouveau contexte.

Le travail demandé consiste à :
- analyser l’impact de la transition Marketplace sur le Data Warehouse existant
- évaluer les limites et risques de l’architecture actuelle
- proposer les adaptations structurelles, organisationnelles et techniques nécessaires
- garantir la qualité, la disponibilité et la sécurité des données dans un environnement multi-vendeurs
- assurer la cohérence analytique malgré l’introduction de nouvelles sources et de données hétérogènes