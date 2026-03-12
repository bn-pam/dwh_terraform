-- Description: Création du schéma DWH avec gestion SCD Type 2 pour dim_seller et contrainte FK sur fact_order.

/* 1. NETTOYAGE PRÉALABLE (Au cas où) */
--ALTER TABLE fact_order DROP CONSTRAINT IF EXISTS fk_order_seller;
DROP TABLE IF EXISTS fact_order;
DROP TABLE IF EXISTS fact_clickstream;
DROP TABLE IF EXISTS dim_seller;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS sys_log_execution;
DROP TABLE IF EXISTS table_quarantaine;

/* 2. CRÉATION DES TABLES (SANS LIENS POUR L'INSTANT) */

-- Dimension Customer
CREATE TABLE dim_customer (
    customer_id VARCHAR(50) PRIMARY KEY,
    name        NVARCHAR(255),
    email       NVARCHAR(255),
    address     NVARCHAR(500),
    city        NVARCHAR(100),
    country     NVARCHAR(100),
    last_updated_at DATETIME DEFAULT GETDATE()
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
    start_date  DATETIME,
    end_date    DATETIME,
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
    seller_key      INT, -- Clé technique vers dim_seller
    seller_id       VARCHAR(50), -- Clé métier (pour faciliter les requêtes sans faire de JOIN systématique)
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

ALTER TABLE dim_customer
ADD CONSTRAINT UQ_CustomerID UNIQUE (customer_id);
GO

ALTER TABLE dim_product
ADD CONSTRAINT UQ_ProductID UNIQUE (product_id);
GO

-- On met la date du jour (ou une date fixe) aux clients pré-évolution qui ont un NULL afin de pouvoir gérer leur RGPD
UPDATE dim_customer
SET last_updated_at = GETDATE()
WHERE last_updated_at IS NULL;
GO

-- On initialise les colonnes SCD2 pour les données vendeur qui n'ont pas encore de statut
UPDATE dim_seller
SET
    start_date = ISNULL(start_date, GETDATE()),
    is_current = ISNULL(is_current, 1)
WHERE is_current IS NULL;
GO

--options à activer pour les index filtrés
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Permet d'avoir une seule version active par seller_id
-- On ne peut pas faire de contrainte avec un WHERE, on crée donc un index unique filtré
CREATE UNIQUE INDEX UQ_SellerID_Current
ON dim_seller(seller_id)
WHERE is_current = 1;
GO



------SECURITE ET POLITIQUE D'ACCÈS (Row-Level Security)
-- 5.1 Création du schéma de sécurité (On utilise une vérification simple)
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Security')
BEGIN
    EXEC('CREATE SCHEMA Security');
END
GO

-- 5.2 Création de la fonction de filtrage multi-tenant
CREATE OR ALTER FUNCTION Security.fn_securitypredicate(@seller_id AS varchar(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS fn_securitypredicate_result
    WHERE (DATABASE_PRINCIPAL_ID() = DATABASE_PRINCIPAL_ID(@seller_id))
       OR (IS_MEMBER('db_owner') = 1)
GO

-- 5.3 Application de la politique de sécurité globale
-- On supprime si elle existe déjà pour éviter les doublons lors du déploiement
IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'SellerFilter')
BEGIN
    DROP SECURITY POLICY SellerFilter;
END
GO

CREATE SECURITY POLICY SellerFilter
ADD FILTER PREDICATE Security.fn_securitypredicate(seller_id) ON dbo.fact_order,
ADD FILTER PREDICATE Security.fn_securitypredicate(seller_id) ON dbo.dim_seller
WITH (STATE = ON);
GO