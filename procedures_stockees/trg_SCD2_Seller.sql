-- trigger pour gérer les changements de données dans la table dim_seller en utilisant la logique SCD Type 2 (Slowly Changing Dimension Type 2)
-- 1. On supprime l'ancien s'il existe
DROP TRIGGER IF EXISTS trg_SCD2_Seller_Evolution;
GO -- Le GO est important pour séparer les instructions

CREATE TRIGGER trg_SCD2_Seller_Evolution
ON dim_seller
INSTEAD OF INSERT -- on intercepte les insertions pour gérer la logique SCD Type 2 (l'historisation des changements)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. On ne traite que les vendeurs qui ont RÉELLEMENT changé de data
    -- ou qui n'existent pas encore.
    IF EXISTS (
        SELECT 1 FROM inserted i
        LEFT JOIN dim_seller d ON i.seller_id = d.seller_id AND d.is_current = 1
        WHERE d.seller_id IS NULL -- Nouveau vendeur
           OR i.tier <> d.tier    -- Ou changement de Tier
           OR i.name <> d.name    -- Ou changement de Nom
           OR i.commission_rate <> d.commission_rate -- Ou changement de Commission
    )
    BEGIN
        -- 2. On ferme l'ancienne version uniquement pour ceux qui changent de data en gardant la même seller_id, et en fixant à 0 le flag is_current et en mettant une date de fin
        UPDATE d
        SET d.is_current = 0,
            d.end_date = GETDATE()
        FROM dim_seller d
        INNER JOIN inserted i ON d.seller_id = i.seller_id
        WHERE d.is_current = 1
          AND (i.tier <> d.tier OR i.name <> d.name OR i.commission_rate <> d.commission_rate);

        -- 3. On insère la nouvelle version
        INSERT INTO dim_seller (seller_id, name, tier, commission_rate, start_date, is_current)
        SELECT i.seller_id, i.name, i.tier, i.commission_rate, GETDATE(), 1
        FROM inserted i
        LEFT JOIN dim_seller d ON i.seller_id = d.seller_id AND d.is_current = 1
        -- On n'insère que si c'est un nouveau vendeur OU si le tier ou le nom a changé
        WHERE d.seller_id IS NULL
           OR (i.tier <> d.tier OR i.name <> d.name OR i.commission_rate <> d.commission_rate);
    END
END
GO