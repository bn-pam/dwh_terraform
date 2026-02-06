CREATE OR ALTER PROCEDURE [dbo].[sp_clean_data_quarantine]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @nb_quarantined INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Insertion en quarantaine
        INSERT INTO table_quarantaine (order_id, product_id, seller_key, unit_price, quantity, error_reason)
        SELECT
            order_id, product_id, seller_key, unit_price, quantity,
            CASE
                WHEN unit_price < 0 THEN 'ERREUR : Prix négatif'
                WHEN quantity IS NULL OR quantity <= 0 THEN 'ERREUR : Quantité invalide'
                ELSE 'ERREUR : Donnée corrompue'
            END
        FROM fact_order
        WHERE unit_price < 0 OR quantity IS NULL OR quantity <= 0;

        SET @nb_quarantined = @@ROWCOUNT; -- On compte combien de lignes "sales" on a trouvé

        -- 2. Nettoyage de la table de faits
        DELETE FROM fact_order
        WHERE unit_price < 0 OR quantity IS NULL OR quantity <= 0;

        COMMIT TRANSACTION;

        -- 3. Journalisation du SUCCÈS
        INSERT INTO sys_log_execution (proc_name, execution_date, rows_affected, status, message)
        VALUES (
            'sp_clean_data_quarantine',
            GETDATE(),
            @nb_quarantined,
            'SUCCESS',
            CONCAT(@nb_quarantined, ' lignes corrompues déplacées en quarantaine.')
        );

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        -- Journalisation de l'ÉCHEC
        INSERT INTO sys_log_execution (proc_name, execution_date, rows_affected, status, message)
        VALUES ('sp_clean_data_quarantine', GETDATE(), 0, 'ERROR', ERROR_MESSAGE());

        THROW;
    END CATCH
END;