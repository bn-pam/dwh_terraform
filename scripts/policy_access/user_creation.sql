--création d'utilisateurs tests
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'SELL-001')
    CREATE USER [SELL-001] WITHOUT LOGIN;

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'SELL-002')
    CREATE USER [SELL-002] WITHOUT LOGIN;

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'SELL-003')
CREATE USER [SELL-003] WITHOUT LOGIN;
GO

--activation des droits de lecture sur les tables concernées par la politique de sécurité préalablement créée
GRANT SELECT ON dbo.fact_order TO [SELL-001], [SELL-002], [SELL-003];
GRANT SELECT ON dbo.dim_seller TO [SELL-001], [SELL-002], [SELL-003];
GO