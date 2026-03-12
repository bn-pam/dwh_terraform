/* CAS D'USAGE : Maintenance et Qualité de Données (C16)
   OBJECTIF : Rattrapage SCD2 + Gestion des commandes antérieures
*/

-- 1. Configuration Azure SQL
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- 2. Nettoyage
UPDATE fact_order SET seller_id = TRIM(seller_id) WHERE seller_key IS NULL;
UPDATE dim_seller SET seller_id = TRIM(seller_id);
GO

-- 3. Réconciliation temporelle standard (Strict)
UPDATE f
SET f.seller_key = s.seller_key
FROM fact_order f
INNER JOIN dim_seller s ON f.seller_id = s.seller_id
WHERE f.seller_key IS NULL
  AND f.order_timestamp >= s.start_date
  AND (f.order_timestamp <= s.end_date OR s.end_date IS NULL);
GO

-- 3bis. Rattrapage des "Ventes en avance" (Antérieures)
-- On prend la version la plus ancienne du vendeur pour les commandes qui précèdent sa création
UPDATE f
SET f.seller_key = first_version.seller_key
FROM fact_order f
CROSS APPLY (
    SELECT TOP 1 s.seller_key
    FROM dim_seller s
    WHERE s.seller_id = f.seller_id
    ORDER BY s.start_date ASC -- On force la version la plus vieille
) AS first_version
WHERE f.seller_key IS NULL; -- Uniquement pour ceux qui n'ont pas trouvé de match strict
GO

-- 4. Rapport final
PRINT '--- Rapport de réconciliation finale ---';
SELECT ISNULL(seller_id, 'Total') AS [Vendeur], COUNT(*) AS [Restants à NULL]
FROM fact_order WHERE seller_key IS NULL
GROUP BY ROLLUP(seller_id);