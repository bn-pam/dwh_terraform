SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER TRIGGER trg_SCD2_Seller_Evolution
ON dim_seller
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Fermeture de l'ancien si changement détecté
    UPDATE d
    SET d.is_current = 0, d.end_date = GETDATE()
    FROM dim_seller d
    INNER JOIN inserted i ON d.seller_id = i.seller_id
    WHERE d.is_current = 1
      AND (i.tier <> d.tier OR i.name <> d.name OR i.commission_rate <> d.commission_rate);

    -- 2. Insertion de la nouvelle version (ou du premier record)
    INSERT INTO dim_seller (seller_id, name, tier, commission_rate, start_date, is_current)
    SELECT i.seller_id, i.name, i.tier, i.commission_rate, GETDATE(), 1
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM dim_seller d
        WHERE d.seller_id = i.seller_id AND d.is_current = 1
        AND d.tier = i.tier AND d.name = i.name AND d.commission_rate = i.commission_rate
    );
END;
GO