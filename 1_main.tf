resource "azurerm_resource_group" "rg" {
  name     = "rg-e6-${var.username}"
  location = var.location
}

// Event Hubs
module "module_event_hubs" {
  source                  = "./modules/event_hubs"
  depends_on              = [azurerm_resource_group.rg]
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  eventhub_namespace_name = "eh-${var.username}"
  eventhubs               = var.eventhubs
}

// DB
module "sql_database" {
  source              = "./modules/sql_database"
  depends_on          = [module.module_event_hubs]
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sql_admin_login     = var.sql_admin_login
  sql_admin_password  = var.sql_admin_password
  schema_file_path    = "${path.root}/dwh_schema_init.sql"
}

// Stream
module "stream_analytics" {
  source                  = "./modules/stream_analytics"
  depends_on              = [module.module_event_hubs, module.sql_database]
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  eventhub_namespace_name = "eh-${var.username}"
  eventhub_listen_key     = module.module_event_hubs.listen_connection_string
  sql_server_fqdn         = module.sql_database.server_fqdn
  sql_database_name       = module.sql_database.database_name
  sql_admin_login         = var.sql_admin_login
  sql_admin_password      = var.sql_admin_password
}

// Event producers
module "container_producers" {
  source     = "./modules/container_producers"
  depends_on = [module.module_event_hubs, module.stream_analytics]

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  container_image   = var.container_producers_image
  connection_string = module.module_event_hubs.send_connection_string

  dockerhub_username = var.dockerhub_username
  dockerhub_token    = var.dockerhub_token
}

// Data Lake (stockage global)
resource "azurerm_storage_account" "datalake" {
  name                     = "sadatalake${var.username}" # Doit être unique mondialement
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true # Important pour Data Lake Gen2 (Hierarchical Namespace)
}

#################################################
# ajout de code pour les tenants
// Création du Tenant Vendeur 1 (TechWorld)
resource "azurerm_storage_container" "tenant_techworld" {
  name                  = "raw-data-techworld" # Le dossier racine du vendeur
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private" # Sécurité : Seul ShopNow (et TechWorld via SAS key) peut lire
}

// Création du Tenant Vendeur 2 (Pour l'exemple)
resource "azurerm_storage_container" "tenant_librairie" {
  name                  = "raw-data-librairie"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

// Création du Tenant ShopNow
resource "azurerm_storage_container" "tenant_shopnow_admin" {
  name                  = "shopnow-core-data"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}
#################################################

# ajout de code pour la procédure de purge RGPD

# ordonnanceur de la purge RGPD quotidienne via Logic App
# Création de la Logic App
resource "azurerm_logic_app_workflow" "maintenance_rgpd" {
  name                = "la-shopnow-compliance-pbo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    Category = "Compliance_RGPD"
    Task     = "Quarantine_Daily"
  }
}

# Déclencheur/trigger : 1ère seconde de chaque mois à 02h00 il déclenche la Logic App
resource "azurerm_logic_app_trigger_recurrence" "daily_trigger_rgpd" {
  logic_app_id = azurerm_logic_app_workflow.maintenance_rgpd.id
  name         = "recurrence-daily-purge"
  frequency    = "Day"
  interval     = 1

  schedule {
    at_these_hours   = [17]
    at_these_minutes = [0]
  }
}

# Action : Appel à la Procédure Stockée SQL (sp_PurgeRGPD_Mensuelle)
#"type": "ApiConnection", indique qu'on utilise une connexion API existante, sinon erreur 400
resource "azurerm_logic_app_action_custom" "call_sql_purge" {
  logic_app_id = azurerm_logic_app_workflow.maintenance_quarantine.id
  name         = "Execute_sp_PurgeRGPD_Daily"
  body = <<BODY
{
    "type": "ApiConnection",
    "inputs": {
        "host": {
            "connection": {
                "name": "sql-connection-shopnow"
            }
        },
        "method": "post",
        "path": "/datasets/default/procedures/sp_PurgeRGPD_Daily"
    }
}
BODY
}

#################################################

# ajout de code pour la procédure de quarantaine

# ordonnanceur de la mise en quarantaine via Logic App
# Création de la Logic App
resource "azurerm_logic_app_workflow" "maintenance_quarantine" {
  name                = "la-shopnow-quarantine-pbo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    Category = "Quarantine"
    Task     = "Quarantine_Daily"
  }
}

# Déclencheur/trigger : 1ère seconde de chaque mois à 02h00 il déclenche la Logic App
resource "azurerm_logic_app_trigger_recurrence" "daily_trigger_quarantine" {
  logic_app_id = azurerm_logic_app_workflow.maintenance_quarantine.id
  name         = "recurrence-daily-quarantine"
  frequency    = "Day"
  interval     = 1

  schedule {
    at_these_hours   = [16]
    at_these_minutes = [0]
  }
}

# Action : Appel à la Procédure Stockée SQL (sp_clean_data_quarantine)
#"type": "ApiConnection", indique qu'on utilise une connexion API existante, sinon erreur 400
resource "azurerm_logic_app_action_custom" "call_sql_purge_quarantine" {
  logic_app_id = azurerm_logic_app_workflow.maintenance_quarantine.id
  name         = "sp_clean_data_quarantine"
  body = <<BODY
{
    "type": "ApiConnection",
    "inputs": {
        "host": {
            "connection": {
                "name": "sql-connection-shopnow"
            }
        },
        "method": "post",
        "path": "/datasets/default/procedures/sp_clean_data_quarantine"
    }
}
BODY
}