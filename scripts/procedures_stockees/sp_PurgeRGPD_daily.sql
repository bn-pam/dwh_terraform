CREATE OR ALTER PROCEDURE [dbo].[sp_PurgeRGPD_Daily]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @nb_profiles_deleted INT = 0;
    DECLARE @nb_orders_anonymized INT = 0;
    DECLARE @nb_clicks_deleted INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Identification des clients inactifs (> 3 ans)
        IF OBJECT_ID('tempdb..#ClientsAPurger') IS NOT NULL DROP TABLE #ClientsAPurger;
        CREATE TABLE #ClientsAPurger (customer_id VARCHAR(50));

        INSERT INTO #ClientsAPurger
        SELECT c.customer_id
        FROM dim_customer c
        LEFT JOIN fact_order o ON c.customer_id = o.customer_id
        GROUP BY c.customer_id, c.last_updated_at
        HAVING
            -- CONDITION 1 : La dernière commande date de plus de 3 ans
            (MAX(o.order_timestamp) < DATEADD(month, -36, GETDATE()))
            OR
            -- CONDITION 2 : Jamais commandé ET profil non modifié/créé depuis 3 ans
            (MAX(o.order_timestamp) IS NULL AND c.last_updated_at < DATEADD(month, -36, GETDATE()));

        -- 2. Anonymisation des ventes
        UPDATE fact_order
        SET customer_id = 'DELETED_RGPD'
        WHERE customer_id IN (SELECT customer_id FROM #ClientsAPurger);
        SET @nb_orders_anonymized = @@ROWCOUNT;

        -- 3. Purge de la navigation
        DELETE FROM fact_clickstream
        WHERE event_timestamp < DATEADD(month, -13, GETDATE())
           OR user_id IN (SELECT customer_id FROM #ClientsAPurger);
        SET @nb_clicks_deleted = @@ROWCOUNT;

        -- 4. Suppression du profil client
        DELETE FROM dim_customer
        WHERE customer_id IN (SELECT customer_id FROM #ClientsAPurger);
        SET @nb_profiles_deleted = @@ROWCOUNT;

        COMMIT TRANSACTION;

        -- 5. Log de l'exécution (Critère C16)
        INSERT INTO sys_log_execution (proc_name, execution_date, rows_affected, status, message)
        VALUES (
            'sp_PurgeRGPD_Daily',
            GETDATE(),
            @nb_profiles_deleted,
            'SUCCESS',
            CONCAT('Profils: ', @nb_profiles_deleted, ' | Ventes Anonymisées: ', @nb_orders_anonymized, ' | Clics supprimés (>13m): ', @nb_clicks_deleted)
        );

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO sys_log_execution (proc_name, execution_date, rows_affected, status, message)
        VALUES ('sp_PurgeRGPD_Daily', GETDATE(), 0, 'ERROR', ERROR_MESSAGE());
        THROW;
    END CATCH
END;