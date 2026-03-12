CREATE TABLE sys_log_execution (
    log_id         INT IDENTITY PRIMARY KEY,
    proc_name      NVARCHAR(100),
    execution_date DATETIME DEFAULT GETDATE(),
    rows_affected  INT,           -- Nombre de profils supprimés
    status         NVARCHAR(20),  -- 'SUCCESS' ou 'ERROR'
    message        NVARCHAR(MAX)  -- Détails (nb de ventes, erreur, etc.)
);