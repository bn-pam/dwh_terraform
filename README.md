# TEACHING_DWH_terraform

- terraform init
- terraform plan
- terraform apply

--> obtention du schéma de l'infrastructure déployée de base

ajout de ce code terraform dans le main.tf pour créer un conteneur par vendeur dans le but de simuler le cloisonnement des données

```// Création du Tenant Vendeur 1 (TechWorld)
resource "azurerm_storage_container" "tenant_techworld" {
  name                  = "raw-data-techworld" # Le dossier racine du vendeur
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private" # Sécurité : Seul ShopNow (et TechWorld via SAS key) peut lire
}

// Création du Tenant Vendeur 2 (Pour l'exemple)
resource "azurerm_storage_container" "tenant_librairie" {
  name                  = "raw-data-librairie"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

// Création du Tenant ShopNow
resource "azurerm_storage_container" "tenant_shopnow_admin" {
  name                  = "shopnow-core-data"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}
```

Ensuite prendre le dwh_schema_init_v2.sql et l'exécuter via le portail azure
--> obtention du schéma de l'infrastructure déployée avec le SCD type 2 et la table des vendeurs selon l'architecture préconisée

Détruire l'infrastructure initiale terraform via la commande
- terraform destroy
--> suppression de l'infrastructure initiale

Changer _producers/dockerfile pour utiliser le nouveau producer.py qui émet de la donnée vendeur et schema_init_v2.sql en schema_init.sql (renommer le fichier en conséquence et vérifier que son nom est correct dans 1_main.tf)

Exécuter le code terraform modifié (s'assurer que le nouveau producer.py est bien renommé et que son nom est correct dans /_event_producers/dockerfile) via les commandes
- terraform init
- terraform plan
- terraform apply

La nouvelle infrastructure est déployée avec de la donnée vendeur émise,

Exécuter le script dwh_schema_init.sql dans le portail azure synapse pour initialiser le schéma intégrant la table vendeur
(il a tendance à bloquer avec terraform car il y a beaucoup de requêtes, donc le faire manuellement dans le portail azure synapse)

Le nouveau schéma DWH avec SCD type 2 et table vendeur est en place

via le portailazure, entrer dans la base de données et exécuter les scripts suivants :
- Exécuter ensuite le script sp_Purge_RGPD_Daily pour stocker la procédure de purge RGPD
- Exécuter ensuite le script trg_SCD2_Seller.sql pour stocker la procédure d'ingestion quotidienne avec gestion des vendeurs et SCD type 2


lignes de test pour tester la RGPD:
```sql
-- 1. On crée le client test
INSERT INTO dim_customer (customer_id, name, email, address, city, country)
VALUES ('TEST-DELETE-RGPD2', 'Martine Dupont', 'm.dupont@test.com', '1 rue de Lille', 'Lille', 'France');

-- 2. On lui associe une commande (important pour tester la cascade/mise à jour)
INSERT INTO fact_order (order_id, product_id, customer_id, seller_key, quantity, unit_price, status, order_timestamp)
VALUES ('ORD-TEST-99', 'PROD-01', 'TEST-DELETE-RGPD2', 1, 2, 150.00, 'Completed', '2020-01-01'); 
-- Note : La date est en 2020 pour être sûr qu'elle soit > 3 ans !

-- On simule deux événements de navigation pour Martine en 2020
INSERT INTO fact_clickstream (event_id, session_id, user_id, url, event_type, event_timestamp)
VALUES 
('EVT-001', 'SESS-101', 'TEST-DELETE-RGPD2', 'https://shopnow.com/home', 'page_view', '2020-01-01 09:00:00'),
('EVT-002', 'SESS-101', 'TEST-DELETE-RGPD2', 'https://shopnow.com/product/PROD-01', 'click', '2020-01-01 09:05:00');
```

lignes de test pour tester la mise en quarantaine des ventes avec prix négatif:
```sql
-- VENTE B : Sera mise en QUARANTAINE (car prix négatif)
INSERT INTO fact_order (order_id, product_id, customer_id, seller_key, quantity, unit_price, order_timestamp)
VALUES ('ORD-KO', 'PROD-02', 'TEST-DELETE-RGPD', 1, 1, -50.00, GETDATE());
```


# erreurs fréquentes

 "The Stream Analytics job is in a 'Processing' state..."
# Arrêter le job ASA avant de déployer les modifications
az stream-analytics job stop --resource-group rg-e6-pbo1 --name asa-shopnow

