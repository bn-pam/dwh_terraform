# TEACHING_DWH_terraform

## Introduction
Ce projet déploie une infrastructure de Data Warehouse sur Azure avec Terraform, en intégrant des bonnes pratiques telles que le SCD type 2 pour la gestion de l'historique des vendeurs et une procédure de purge RGPD.
Il inclut également des scripts SQL pour initialiser le schéma de la base de données, gérer les acès vendeurs et assurer la conformité des données (data quality) grâce à une quarantaine.

## Prérequis
Avant de déployer la nouvelle infrastructure :
- ajuster la politique de rétention pour le PITR à 7 jours dans le module sql_database du main.tf pour éviter les coûts élevés liés au stockage des backups

## Déploiement
- pour déployer la nouvelle infrastructure, exécuter les commandes suivantes dans le terminal à la racine du projet :
```terraform
terraform init
terraform plan
terraform apply
```

- pour déployer le schéma de la nouvelle base de données,
exécuter le script de déploiement de la BDD :
```bash
./scripts/script_deploy.sh
```

cela permet d'exécuter le SQL de création de la bdd et toutes les procédures de base, notamment :
- le script de création du schéma de la base de données `schema.sql` qui définit les tables de faits et de dimensions, les tables de monitoring (logs, quarantaine) les clés primaires et étrangères, la police de sécurité pour le RLS, et les indexes des clés primaires pour l'ingrité des données.
- la procédure de création d'utilisateur avec login `user_creation` qui automatise la création d'un login SQL au niveau du serveur et d'un utilisateur au niveau de la base de données, en attribuant les droits de lecture nécessaires pour garantir un accès sécurisé et conforme aux politiques de sécurité de l'entrepôt de données.
- le trigger `sp_clean_data_quarantine` qui surveille les insertions dans la table `fact_order` et met automatiquement en quarantaine les ventes avec un prix unitaire négatif en les marquant comme "Quarantined" et en les excluant des analyses, assurant ainsi la qualité des données et la fiabilité des rapports de vente.
- la procédure de purge RGPD `sp_PurgeCustomerDataRGPD` qui permet d'anonymiser les données personnelles d'un client et de mettre à jour les enregistrements liés dans les tables de faits pour garantir la conformité RGPD tout en préservant l'intégrité analytique.
- la procédure de purge quotidienne `spPurgeRGPD_daily` qui automatise la suppression des données personnelles des clients inactifs depuis plus de 3 ans et leur navigation web tous les 13 mois, assurant ainsi une conformité continue avec le RGPD et une gestion efficace de l'espace de stockage.
- la procédure de check de quarantaine `sp_quarantine_status` qui permet de vérifier régulièrement les ventes mises en quarantaine pour alerter et décider de leur suppression définitive ou de leur réintégration après correction, assurant ainsi une gestion proactive de la qualité des données.
- le trigger `trg_LinkSellerKey` qui associe une `seller_key` à un vendeur dans la table `fact_order`.
- la procédure de gestion du SCD type 2 `trg_SCD2_Seller` qui gère les changements dans les données des vendeurs en créant de nouvelles versions des enregistrements avec des dates de validité, assurant ainsi une traçabilité complète de l'historique des vendeurs et une analyse précise des performances dans le temps.
- la procédure de génération du dashboard de KPI `dashboard_sql_kpi_mco` qui calcule et met à jour quotidiennement les indicateurs clés de performance de maintenance du DWH, en les stockant dans une table dédiée pour un accès rapide et une visualisation efficace.
- la procédure de génération de vues vendeurs `sp_GenerateAllSellerViews` qui scanne la table `dim_seller` et génère une vue SQL par vendeur (ex: `v_sales_TechWorld`) pour fournir à chaque vendeur une vue simplifiée et isolée de ses performances sans qu'il ait à manipuler la table de faits globale.

## Procédures de test
lignes de test pour tester la RGPD:
```sql
-- A. On s'assure qu'au moins un vendeur existe pour la seller_key 1
SET IDENTITY_INSERT dim_seller ON; -- Si ta clé est IDENTITY
IF NOT EXISTS (SELECT 1 FROM dim_seller WHERE seller_key = 1)
    INSERT INTO dim_seller (seller_key, seller_id, name, tier, is_current)
    VALUES (1, 'SELL-999', 'Vendeur Test', 'Gold', 1);
SET IDENTITY_INSERT dim_seller OFF;

-- B. On s'assure que le produit PROD-01 existe
IF NOT EXISTS (SELECT 1 FROM dim_product WHERE product_id = 'PROD-01')
    INSERT INTO dim_product (product_id, name, category)
    VALUES ('PROD-01', 'Smartphone Phoenix', 'Tech');

-- C. Création de Martine
INSERT INTO dim_customer (customer_id, name, email, address, city, country)
VALUES ('MARTINE-RGPD-TEST', 'Martine Dupont', 'm.dupont@test.com', '1 rue de Lille', 'Lille', 'France');

-- D. VIEILLISSEMENT (Crucial pour que la procédure la voit !)
UPDATE dim_customer 
SET last_updated_at = '2020-01-01', 
    registration_date = '2020-01-01'
WHERE customer_id = 'MARTINE-RGPD-TEST';

-- E. Sa commande de 2020
INSERT INTO fact_order (order_id, product_id, customer_id, seller_key, quantity, unit_price, status, order_timestamp)
VALUES ('ORD-MARTINE-001', 'PROD-01', 'MARTINE-RGPD-TEST', 1, 1, 500.00, 'Completed', '2020-01-01');

-- F. Ses clics de 2020
INSERT INTO fact_clickstream (event_id, session_id, user_id, url, event_type, event_timestamp)
VALUES 
('EVT-M1', 'SESS-M1', 'MARTINE-RGPD-TEST', 'https://shopnow.com/promo', 'page_view', '2020-01-01 10:00:00'),
('EVT-M2', 'SESS-M1', 'MARTINE-RGPD-TEST', 'https://shopnow.com/checkout', 'click', '2020-01-01 10:05:00');
```

lignes de test pour tester la mise en quarantaine des ventes avec prix négatif:
```sql
-- VENTE B : Sera mise en QUARANTAINE (car prix négatif)
INSERT INTO fact_order (order_id, product_id, customer_id, seller_key, quantity, unit_price, order_timestamp)
VALUES ('ORD-KO', 'PROD-02', 'TEST-DELETE-RGPD', 1, 1, -50.00, GETDATE());
```

lignes de test pour tester la mise à jour d'un vendeur et le SCD type 2:
```sql
INSERT INTO dim_seller (seller_id, name, tier, commission_rate)
VALUES ('SELL-001', 'TechWorld', 'Platinum', 0.25);
```

## Erreurs fréquentes

 "The Stream Analytics job is in a 'Processing' state..."
### Arrêter le job ASA avant de déployer les modifications
az stream-analytics job stop --resource-group rg-e6-pbo1 --name asa-shopnow

### si aucune donnée n'est présente dans la BDD SQL
checker les logs du conteneur docker du producer pour vérifier que les événements sont bien émis
```bash
docker logs nom_du_conteneur_producer
``` 
### et si les logs du conteneur docker renvoient 'None'
recréer l'image docker du producer pour qu'il soit construit en AMD64 et pas ARM (si vous êtes sur un mac M1/M2)
```bash
cd _event_producers
docker buildx build --platform linux/amd64 -t nomdocker/nom-image-producer:latest .
docker push nomdocker/nom-image-producer:latest
```

### obtenir mon ip v4 pour l'autoriser dans Azure SQL
```bash
curl -4 ifconfig.me
```


## 📘 Guide d'Exploitation de l'Entrepôt ShopNow

### Cas d'Usage 1 : Intégration d'une nouvelle source (Vendeur)

**Objectif :** Ajouter un nouveau flux de données marketplace au système.

* **Procédure Terraform :** Ajouter un nouveau dossier/conteneur dans le module Storage.
* **Procédure SQL :** Créer l'utilisateur SQL correspondant pour le cloisonnement.
* **Mise en œuvre :** 1.  Déclarer le `seller_id` dans les variables Terraform.
2.  Lancer `terraform apply`.
3.  Le trigger `trg_LinkSellerKey` gérera automatiquement la création dans `dim_seller` dès le premier message reçu.

### Cas d'Usage 2 : Création de nouveaux accès (Avec login)

**Objectif :** Donner un accès sécurisé à un analyste ou un nouveau vendeur.

* **Procédure :** Utiliser le script de création d'utilisateur avec login
* **Mise en œuvre :**
```sql

-- 1. Création du Login au niveau du serveur (Se connecter à la base 'master')
-- Cette étape gère l'authentification (Connexion au serveur)
CREATE LOGIN [Vendeur_TechWorld] WITH PASSWORD = 'MotDePasseSecurise123!';
GO

-- 2. Création de l'User au niveau de la base DWH (Se connecter à 'shopnow_db')
-- Cette étape gère l'autorisation (Accès aux données)
CREATE USER [SELL-001] FOR LOGIN [Vendeur_TechWorld];
GO

-- 3. Attribution des droits de lecture
GRANT SELECT ON dbo.fact_order TO [SELL-001];
GRANT SELECT ON dbo.dim_seller TO [SELL-001];

-- 4. Test de sécurité : Le RLS s'applique dynamiquement au Login connecté

```

### Cas d'Usage 3 : Extension de la capacité de calcul (Scalability)

**Objectif :** Faire face à un pic d'activité (ex: Black Friday).

* **Procédure :** Scale-up vertical du SKU SQL.
* **Mise en œuvre :** Modifier la variable `sku_name` dans le `main.tf` de "Basic" vers "S1" ou "S2" et relancer le déploiement. Pour Stream Analytics, augmenter les **Streaming Units (SU)** de 1/3 à 3.

### Cas d'Usage 4 : Purge RGPD pour un client (Droit à l'effacement)
**Objectif :** Supprimer les données personnelles d'un client conformément à une demande de droit à l'effacement.
* **Procédure :** Exécution de la procédure `sp_PurgeCustomerDataRGPD`.
* **Mise en œuvre :** 
```sql
EXEC sp_PurgeCustomerDataRGPD @customer_id = 'MARTINE-RGPD-TEST';
```
* **Résultat :** La procédure anonymise les données personnelles de Martine dans `dim_customer`, met à jour les enregistrements liés dans `fact_order` et `fact_clickstream` pour garantir la conformité RGPD tout en préservant l'intégrité analytique.
* **Test de validation :** Après l'exécution, une requête sur `dim_customer` pour `MARTINE-RGPD-TEST` doit montrer des données anonymisées, et les commandes associées dans `fact_order` doivent être marquées comme "Anonymized" ou supprimées selon la logique métier définie.
* **Note :** Cette procédure doit être exécutée avec précaution, idéalement dans un environnement de test avant d'être appliquée en production, pour éviter toute suppression accidentelle de données.
* **Fréquence d'exécution :** Cette procédure est à exécuter à la demande, en réponse à une requête de droit à l'effacement d'un client, et doit être suivie d'une vérification pour s'assurer que les données ont été correctement anonymisées ou supprimées.
* **Conformité RGPD :** En plus de la purge des données, il est recommandé de mettre à jour le registre des traitements de données personnelles pour refléter les actions prises et de documenter les procédures de conformité mises en place pour garantir que l'entrepôt de données reste conforme au RGPD.
* **Impact sur les analyses :** Il est important de noter que la suppression ou l'anonymisation des données peut affecter les analyses historiques. Par conséquent, il est conseillé de mettre en place des mécanismes pour gérer ces cas, comme l'utilisation de flags d'anonymisation ou la création de vues spécifiques pour les données anonymisées.
* **Communication :** Informer les équipes d'analyse et les parties prenantes de la purge des données pour qu'elles puissent ajuster leurs analyses en conséquence et éviter toute confusion lors de l'interprétation des résultats.
* **Suivi :** Mettre en place un suivi des demandes de purge et des actions prises pour assurer une traçabilité complète et faciliter les audits de conformité RGPD.
* **Formation :** Assurer que les membres de l'équipe sont formés sur les procédures de purge RGPD et comprennent les implications de ces actions sur l'entrepôt de données et les analyses.
* **Amélioration continue :** Après chaque purge, recueillir les retours d'expérience pour améliorer la procédure et garantir une meilleure efficacité et conformité à l'avenir.
* **Exemple de résultat attendu :** Après l'exécution de la procédure pour `MARTINE-RGPD-TEST`, une requête sur `dim_customer` pourrait retourner :

```sql
SELECT * FROM dim_customer WHERE customer_id = 'MARTINE-RGPD-TEST';
```

La vente associée à Martine dans `fact_order` est marquée comme avec un id customer "DELETED-RGPD", 
et les données personnelles de Martine dans `dim_customer` sont effacées : 

| order_id       | product_id | customer_id     | seller_key | quantity | unit_price | status      | order_timestamp       |
|----------------|------------|-----------------|------------|----------|------------|-------------|-----------------------|
| ORD-RGPD-001 | PROD-01    | DELETED-RGPD    | 1          | 1        | 500.00     | Anonymized   | 2020-01-01 00:00:00   |

### Cas d'Usage 5 : Création de Datamarts Vendeurs

**Objectif :** Fournir à chaque vendeur une vue simplifiée et isolée de ses performances sans qu'il ait à manipuler la table de faits globale.

* **Procédure :** Exécution de la procédure `sp_GenerateAllSellerViews`.
* **Mise en œuvre :** 
```sql
EXEC sp_GenerateAllSellerViews;
```

* **Résultat :** Le système scanne la table `dim_seller` et génère instantanément une vue SQL par vendeur (ex: `v_sales_TechWorld`).

