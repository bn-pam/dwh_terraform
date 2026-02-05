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

via le portail azure, entrer dans la base de données et exécuter les scripts suivants :
- Exécuter ensuite le script sp_Purge_RGPD_Daily pour stocker la procédure de purge RGPD
- Exécuter ensuite le script trg_SCD2_Seller.sql pour stocker la procédure d'ingestion quotidienne avec gestion des vendeurs et SCD type 2
- Exécuter ensuite le script sp_clean_data_quarantine pour stocker la procédure de mise en quarantaine des lignes abérrantes (ex: prix négatif)
- Exécuter ensuite le script sp_quarantine_status pour stocker la procédure de monitoring de la quarantaine

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

# erreurs fréquentes

 "The Stream Analytics job is in a 'Processing' state..."
# Arrêter le job ASA avant de déployer les modifications
az stream-analytics job stop --resource-group rg-e6-pbo1 --name asa-shopnow

# si aucune donnée n'est présente dans la BDD SQL
checker les logs du conteneur docker du producer pour vérifier que les événements sont bien émis
```bash
docker logs nom_du_conteneur_producer
``` 
## et si les logs du conteneur docker renvoient 'None'
recréer l'image docker du producer pour qu'il soit construit en AMD64 et pas ARM (si vous êtes sur un mac M1/M2)
```bash
cd _event_producers
docker buildx build --platform linux/amd64 -t nomdocker/nom-image-producer:latest .
docker push nomdocker/nom-image-producer:latest
```

