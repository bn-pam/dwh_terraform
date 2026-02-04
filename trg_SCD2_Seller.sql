--- script de trigger pour transformer les datas destinées à la table Seller dès leur arrivée
CREATE TRIGGER trg_SCD2_Seller_Evolution
ON dim_seller
INSTEAD OF INSERT -- On intercepte l'insertion pour gérer l'historisation
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. On "ferme" l'ancienne version du vendeur si elle existe
    -- On met is_current à 0 et on définit la date de fin
    UPDATE d
    SET d.is_current = 0,
        d.row_end_date = GETDATE()
    FROM dim_seller d
    INNER JOIN inserted i ON d.seller_id = i.seller_id
    WHERE d.is_current = 1;

    -- 2. On insère la nouvelle version (celle qui arrive de l'ETL)
    INSERT INTO dim_seller (seller_id, name, tier, row_start_date, is_current)
    SELECT seller_id, name, tier, GETDATE(), 1
    FROM inserted;
END
GO