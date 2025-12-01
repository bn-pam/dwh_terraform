/* ================================================= */
/* ETAPE 1 : NETTOYAGE BRUTAL                       */
/* On supprime la contrainte d'abord pour débloquer */
/* ================================================= */
ALTER TABLE fact_order DROP CONSTRAINT IF EXISTS fk_order_seller;

DROP TABLE IF EXISTS fact_order;
DROP TABLE IF EXISTS fact_clickstream;
DROP TABLE IF EXISTS dim_seller;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_customer;

/* ================================================= */
/* ETAPE 2 : CREATION DES TABLES (SANS LIENS)        */
/* ================================================= */

/* Table 1 : Customer */
CREATE TABLE dim_customer (
    customer_id VARCHAR(50) PRIMARY KEY,
    name        NVARCHAR(255),
    email       NVARCHAR(255),
    address     NVARCHAR(500),
    city        NVARCHAR(100),
    country     NVARCHAR(100)
);

/* Table 2 : Product */
CREATE TABLE dim_product (
    product_id VARCHAR(50) PRIMARY KEY,
    name       NVARCHAR(255),
    category   NVARCHAR(100)
);

/* Table 3 : Seller (SCD Type 2) */
/* Note : On garde IDENTITY(1,1), c'est correct pour Azure */
CREATE TABLE dim_seller (
    seller_key      INT IDENTITY(1,1) PRIMARY KEY,
    seller_id       VARCHAR(50),
    name            NVARCHAR(255),
    tier            NVARCHAR(50),
    commission_rate DECIMAL(5, 2),
    row_start_date  DATETIME,
    row_end_date    DATETIME,
    is_current      BIT
);

/* Table 4 : Clickstream */
CREATE TABLE fact_clickstream (
    event_id        VARCHAR(50) PRIMARY KEY,
    session_id      VARCHAR(50),
    user_id         VARCHAR(50),
    url             NVARCHAR(MAX),
    event_type      NVARCHAR(50),
    event_timestamp DATETIME
);

/* Table 5 : Order */
/* ATTENTION : Je retire la contrainte FOREIGN KEY ici pour éviter le bug */
CREATE TABLE fact_order (
    order_id        VARCHAR(50),
    product_id      VARCHAR(50),
    customer_id     VARCHAR(50),
    seller_key      INT, /* La colonne est là, mais elle est libre pour l'instant */
    quantity        INT,
    unit_price      DECIMAL(18, 2),
    status          NVARCHAR(50),
    order_timestamp DATETIME
);

/* ================================================= */
/* ETAPE 3 : CREATION DU LIEN (APRES COUP)           */
/* Maintenant que tout existe, on active la menotte  */
/* ================================================= */

ALTER TABLE fact_order 
ADD CONSTRAINT fk_order_seller FOREIGN KEY (seller_key) REFERENCES dim_seller(seller_key);