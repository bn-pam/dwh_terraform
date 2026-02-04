/* VUE DE SUPERVISION MCO (DYNAMIQUE) */
/* Ce script interroge l'état réel de ton infrastructure Azure SQL */

SELECT
    '1. DISPONIBILITÉ' AS KPI,
    'Etat Base de Données' AS Mesure,
    state_desc AS Valeur, -- Va renvoyer 'ONLINE'
    CASE WHEN state_desc = 'ONLINE' THEN 'OK' ELSE 'CRITICAL' END AS Statut
FROM sys.databases
WHERE name = DB_NAME()

UNION ALL

SELECT
    '2. ACTIVITÉ',
    'Vendeurs Actifs (Gold/Standard)',
    CAST(COUNT(*) AS VARCHAR) + ' Vendeurs', -- Compte tes vraies lignes dans dim_seller
    CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING (Vide)' END
FROM dim_seller
WHERE is_current = 1

UNION ALL

SELECT
    '3. STOCKAGE',
    'Espace Utilisé',
    -- Calcul savant pour trouver la taille réelle utilisée
    CAST(SUM(reserved_page_count) * 8.0 / 1024 AS VARCHAR) + ' MB',
    'OK'
FROM sys.dm_db_partition_stats

UNION ALL

SELECT
    '4. QUALITÉ',
    'Doublons détectés (Vendeurs)',
    -- Vérifie s'il y a des doublons d'ID vendeur actifs (Test de qualité réel)
    CAST(COUNT(*) - COUNT(DISTINCT seller_id) AS VARCHAR),
    CASE WHEN COUNT(*) - COUNT(DISTINCT seller_id) = 0 THEN 'OK' ELSE 'ALERTE' END
FROM dim_seller
WHERE is_current = 1;