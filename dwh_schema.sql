-- Create Tables for ShopNow DWH

-- 1. dim_customer
DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer (
    customer_id VARCHAR(50) PRIMARY KEY,
    name        NVARCHAR(255),
    email       NVARCHAR(255),
    address     NVARCHAR(500),
    city        NVARCHAR(100),
    country     NVARCHAR(100)
);

-- 2. dim_product
DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product (
    product_id VARCHAR(50) PRIMARY KEY,
    name       NVARCHAR(255),
    category   NVARCHAR(100)
);

-- 3. fact_order
DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order (
    order_id        VARCHAR(50),
    product_id      VARCHAR(50),
    customer_id     VARCHAR(50),
    quantity        INT,
    unit_price      DECIMAL(18, 2),
    status          NVARCHAR(50),
    order_timestamp DATETIME
);

-- 4. fact_clickstream
DROP TABLE IF EXISTS fact_clickstream;
CREATE TABLE fact_clickstream (
    event_id        VARCHAR(50) PRIMARY KEY,
    session_id      VARCHAR(50),
    user_id         VARCHAR(50),
    url             NVARCHAR(MAX),
    event_type      NVARCHAR(50),
    event_timestamp DATETIME
);
