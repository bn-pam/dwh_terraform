# modules/tenant_seller/main.tf

variable "seller_name" {}
variable "storage_account_name" {}

# 1. Création du conteneur privé pour le vendeur
resource "azurerm_storage_container" "container" {
  name                  = "raw-data-${lower(var.seller_name)}"
  storage_account_name  = var.storage_account_name
  container_access_type = "private"
}