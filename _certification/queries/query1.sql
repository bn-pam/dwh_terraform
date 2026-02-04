-- SCÉNARIO DE DÉMO SCD TYPE 2 --

-- 1. État Initial : TechWorld arrive sur la marketplace (Janvier)
INSERT INTO dim_seller (seller_id, name, tier, commission_rate, row_start_date, row_end_date, is_current)
VALUES ('V_TECH_001', 'TechWorld', 'Standard', 0.15, '2024-01-01', NULL, 1);

-- 2. Évolution : TechWorld devient performant et passe GOLD (Juin)
-- A. On ferme l'ancienne ligne (UPDATE)
UPDATE dim_seller
SET row_end_date = '2024-05-31', is_current = 0
WHERE seller_id = 'V_TECH_001' AND is_current = 1;

-- B. On ouvre la nouvelle ligne (INSERT)
INSERT INTO dim_seller (seller_id, name, tier, commission_rate, row_start_date, row_end_date, is_current)
VALUES ('V_TECH_001', 'TechWorld', 'Gold', 0.12, '2024-06-01', NULL, 1);

-- 3. les états finaux de la table dim_seller sont bien historisés
SELECT
    seller_key AS [Clé Technique],
    seller_id AS [ID Vendeur],
    tier AS [Statut],
    commission_rate AS [Com (%)],
    row_start_date AS [Début],
    row_end_date AS [Fin],
    is_current AS [Actif ?]
FROM dim_seller
ORDER BY seller_key;