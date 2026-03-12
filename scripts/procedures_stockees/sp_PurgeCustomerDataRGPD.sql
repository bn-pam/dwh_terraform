CREATE OR ALTER PROCEDURE dbo.sp_PurgeCustomerDataRGPD
    @customer_id VARCHAR(50) -- C'est le paramètre que tu passeras (ex: 'MARTINE...')
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Suppression dans la table de faits (on enlève les ventes)
        DELETE FROM dbo.fact_order
        WHERE customer_id = @customer_id;

        -- 2. Suppression dans la dimension (on enlève l'identité)
        DELETE FROM dbo.dim_customer
        WHERE customer_id = @customer_id;

        COMMIT TRANSACTION;
        PRINT 'Purge effectuée avec succès pour le client : ' + @customer_id;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Erreur lors de la purge : ' + ERROR_MESSAGE();
    END CATCH
END;
GO