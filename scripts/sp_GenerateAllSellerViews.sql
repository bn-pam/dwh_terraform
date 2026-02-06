CREATE OR ALTER PROCEDURE sp_GenerateAllSellerViews
AS
BEGIN
    DECLARE @SellerName NVARCHAR(100);
    DECLARE @ID_Vendeur NVARCHAR(50);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @ViewName NVARCHAR(150);
    DECLARE @GrantSQL NVARCHAR(MAX);

    -- On boucle sur chaque vendeur (on prend seller_id pour le filtrage et name pour le titre)
    DECLARE seller_cursor CURSOR FOR
    SELECT DISTINCT seller_id, name FROM dim_seller;

    OPEN seller_cursor;
    FETCH NEXT FROM seller_cursor INTO @ID_Vendeur, @SellerName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 1. Construction du nom de la vue (remplacement des espaces par des underscores)
        SET @ViewName = 'v_sales_' + REPLACE(@SellerName, ' ', '_');

        -- 2. Création de la vue historique
        -- Utilisation des crochets [] pour gérer les tirets dans les noms de vues
        -- Filtrage sur seller_id (stable) et jointure sur seller_key (historique SCD2)
        SET @SQL = 'CREATE OR ALTER VIEW [' + @ViewName + '] AS
                    SELECT f.* FROM fact_order f
                    INNER JOIN dim_seller s ON f.seller_key = s.seller_key
                    WHERE s.seller_id = ''' + @ID_Vendeur + '''';

        EXEC sp_executesql @SQL;

        -- 3. Attribution automatique des droits SELECT au vendeur
        -- On suppose que le nom de l'utilisateur SQL est le seller_id (ex: SELL-001)
        SET @GrantSQL = 'GRANT SELECT ON [' + @ViewName + '] TO [' + @ID_Vendeur + ']';

        EXEC sp_executesql @GrantSQL;

        PRINT '✅ Vue historique et droits générés pour : ' + @SellerName + ' (ID: ' + @ID_Vendeur + ')';

        FETCH NEXT FROM seller_cursor INTO @ID_Vendeur, @SellerName;
    END

    CLOSE seller_cursor;
    DEALLOCATE seller_cursor;
END
GO