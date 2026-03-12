CREATE OR ALTER PROCEDURE [dbo].[sp_quarantine_status]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @nb_errors INT;
    DECLARE @should_alert BIT = 0;

    -- On compte les erreurs des dernières 24h
    SELECT @nb_errors = COUNT(*)
    FROM table_quarantaine
    WHERE detected_at > DATEADD(day, -1, GETDATE());

    -- Si on a des erreurs, on passe le flag à 1
    IF @nb_errors > 0
        SET @should_alert = 1;

    -- On retourne le résultat pour la Logic App
    SELECT
        @should_alert AS ShouldAlert,
        @nb_errors AS ErrorCount,
        'Des anomalies ont été détectées dans la table de quarantaine.' AS AlertMessage;
END;