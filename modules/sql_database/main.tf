resource "azurerm_mssql_server" "sql_server" {
  name                         = "sql-server-${lower(replace(var.resource_group_name, "_", "-"))}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "dwh" {
  name           = "dwh-shopnow"
  server_id      = azurerm_mssql_server.sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  sku_name       = "S0"
  zone_redundant = false
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "allow_local_ip" {
  name             = "AllowLocalIP"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

// ============================================================================
// Azure Container Instance pour l'initialisation du schéma de la base de données
// ============================================================================
// 
// Azure SQL Database ne permet PAS d'injecter un schéma SQL directement lors
// de sa création via Terraform. Cette ressource crée un conteneur temporaire
// dans Azure qui exécute le script SQL d'initialisation.
//
// FONCTIONNEMENT :
// ----------------
// 1. Terraform crée le SQL Server et la base de données
// 2. Terraform crée cette Container Instance dans Azure
// 3. Le conteneur démarre et exécute les commandes suivantes :
//    a) Charge le contenu de dwh_schema.sql dans /tmp/schema.sql
//    b) Utilise sqlcmd pour se connecter à la base de données
//    c) Exécute le script SQL pour créer les tables
// 4. Le conteneur se termine automatiquement (restart_policy = "Never")
// 5. Azure garde le conteneur en état "Terminated" pour consultation des logs
//
// ============================================================================

resource "azurerm_container_group" "db_setup" {
  # Attend que la base de données et la règle firewall soient créées
  depends_on = [azurerm_mssql_database.dwh, azurerm_mssql_firewall_rule.allow_azure_services]

  name                = "db-setup-${lower(replace(var.resource_group_name, "_", "-"))}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  restart_policy      = "Never" # Le conteneur s'exécute une seule fois puis s'arrête

  container {
    name   = "sqlcmd"
    image  = "mcr.microsoft.com/mssql-tools" # Image officielle Microsoft avec sqlcmd
    cpu    = "0.5"                           # 0.5 CPU core (suffisant pour un script SQL)
    memory = "1.0"                           # 1 GB de RAM

    # Azure Container Instance nécessite au moins un port exposé (même si non utilisé)
    ports {
      port     = 80
      protocol = "TCP"
    }

    # Commandes exécutées dans le conteneur
    commands = [
      "/bin/bash",
      "-c",
      <<-EOT
        # Écrit le contenu du fichier SQL dans le conteneur
        echo '${file(var.schema_file_path)}' > /tmp/schema.sql
        
        # Exécute le script SQL sur la base de données Azure SQL
        /opt/mssql-tools/bin/sqlcmd \
          -S ${azurerm_mssql_server.sql_server.fully_qualified_domain_name} \
          -U ${var.sql_admin_login} \
          -P '${var.sql_admin_password}' \
          -d ${azurerm_mssql_database.dwh.name} \
          -i /tmp/schema.sql
      EOT
    ]
  }
}

