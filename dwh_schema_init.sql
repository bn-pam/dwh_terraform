-- Description: Création du schéma DWH avec gestion SCD Type 2 pour dim_seller et contrainte FK sur fact_order.

/* 1. NETTOYAGE PRÉALABLE (Au cas où) */
--ALTER TABLE fact_order DROP CONSTRAINT IF EXISTS fk_order_seller;
DROP TABLE IF EXISTS fact_order;
DROP TABLE IF EXISTS fact_clickstream;
DROP TABLE IF EXISTS dim_seller;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_customer;

/* 2. CRÉATION DES TABLES (SANS LIENS POUR L'INSTANT) */

-- Dimension Customer
CREATE TABLE dim_customer (
    customer_id VARCHAR(50) PRIMARY KEY,
    name        NVARCHAR(255),
    email       NVARCHAR(255),
    address     NVARCHAR(500),
    city        NVARCHAR(100),
    country     NVARCHAR(100)
);

-- Dimension Product
CREATE TABLE dim_product (
    product_id VARCHAR(50) PRIMARY KEY,
    name       NVARCHAR(255),
    category   NVARCHAR(100)
);

-- Dimension Seller (SCD Type 2)
CREATE TABLE dim_seller (
    seller_key      INT IDENTITY(1,1) PRIMARY KEY, -- Clé technique auto-incrémentée
    seller_id       VARCHAR(50),                   -- Clé métier
    name            NVARCHAR(255),
    tier            NVARCHAR(50),
    commission_rate DECIMAL(5, 2),
    row_start_date  DATETIME,
    row_end_date    DATETIME,
    is_current      BIT
);

-- Fact Clickstream
CREATE TABLE fact_clickstream (
    event_id        VARCHAR(50) PRIMARY KEY,
    session_id      VARCHAR(50),
    user_id         VARCHAR(50),
    url             NVARCHAR(MAX),
    event_type      NVARCHAR(50),
    event_timestamp DATETIME
);

-- Fact Order (Avec la colonne seller_key mais sans contrainte pour l'instant)
CREATE TABLE fact_order (
    order_id        VARCHAR(50),
    product_id      VARCHAR(50),
    customer_id     VARCHAR(50),
    seller_key      INT,
    quantity        INT,
    unit_price      DECIMAL(18, 2),
    status          NVARCHAR(50),
    order_timestamp DATETIME
);

/* 3. APPLICATION DE LA CONTRAINTE (Une fois que tout existe) */
ALTER TABLE fact_order
ADD CONSTRAINT fk_order_seller FOREIGN KEY (seller_key) REFERENCES dim_seller(seller_key);

/* 3.1 DONNEES INITIALES TABLE CUSTOMER */
-- À lancer une seule fois à l'initialisation du DWH
-- Insertion du client générique pour l'anonymisation RGPD,
-- permet d'éviter des ventes orphelines
INSERT INTO dim_customer (customer_id, name, email)
VALUES ('DELETED_RGPD', 'CLIENT SUPPRIME', 'rgpd@shopnow.com');

/* 4. TABLES DE MAINTENANCE ET QUALITE */
-- Table de log d'exécution des procédures
CREATE TABLE sys_log_execution (
    log_id         INT IDENTITY PRIMARY KEY,
    proc_name      NVARCHAR(100),
    execution_date DATETIME DEFAULT GETDATE(),
    rows_affected  INT,           -- Nombre de profils supprimés
    status         NVARCHAR(20),  -- 'SUCCESS' ou 'ERROR'
    message        NVARCHAR(MAX)  -- Détails (nb de ventes, erreur, etc.)
);

-- Création de la table de quarantaine pour isoler les données corrompues
CREATE TABLE table_quarantaine (
    quarantine_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id      VARCHAR(50),
    product_id    VARCHAR(50),
    seller_key    INT,
    unit_price    DECIMAL(18, 2),
    quantity      INT,
    error_reason  NVARCHAR(255),  -- Pour savoir POURQUOI la donnée est là
    detected_at   DATETIME DEFAULT GETDATE()
);