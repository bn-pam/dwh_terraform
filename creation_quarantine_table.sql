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

