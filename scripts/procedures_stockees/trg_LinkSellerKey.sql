-- Ce trigger gère l'ingestion dans la table fact_order en s'assurant que les vendeurs référencés existent dans dim_seller.
-- Si un vendeur n'existe pas, il est créé avec des valeurs par défaut. Ensuite, la clé technique seller_key est mise à jour pour faire le lien entre fact_order et dim_seller.

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER TRIGGER trg_LinkSellerKey
ON fact_order
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

        -- 1. Si le vendeur n'existe pas, on le crée proprement
    -- On n'insère en "Auto" que si le seller_id est TOTALEMENT inconnu (aucune ligne du tout)
    INSERT INTO dim_seller (seller_id, name, tier, commission_rate, is_current, start_date)
    SELECT DISTINCT i.seller_id, 'Nouveau Vendeur (Auto)', 'Standard', 0.10, 1, GETDATE()
    FROM inserted i
    WHERE NOT EXISTS (SELECT 1 FROM dim_seller s WHERE s.seller_id = i.seller_id);

-- 2. On fait la liaison des clés techniques
    -- Liaison sur la version actuelle
    UPDATE f
    SET f.seller_key = s.seller_key
    FROM fact_order f
    INNER JOIN inserted i ON f.order_id = i.order_id AND f.product_id = i.product_id
    INNER JOIN dim_seller s ON i.seller_id = s.seller_id
    WHERE s.is_current = 1;
END;
GO