resource "azurerm_eventhub_namespace" "EH_namespace" {
  name                = var.eventhub_namespace_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku      = "Basic"
  capacity = 1
}


resource "azurerm_eventhub" "EH" {
  for_each = toset(var.eventhubs)

  name              = each.value
  namespace_id      = azurerm_eventhub_namespace.EH_namespace.id
  partition_count   = 1
  message_retention = 1
}

resource "azurerm_eventhub_namespace_authorization_rule" "send_policy" {
  name                = "send-policy"
  namespace_name      = azurerm_eventhub_namespace.EH_namespace.name
  resource_group_name = var.resource_group_name

  send = true
}

resource "azurerm_eventhub_namespace_authorization_rule" "listen_policy" {
  name                = "listen-policy"
  namespace_name      = azurerm_eventhub_namespace.EH_namespace.name
  resource_group_name = var.resource_group_name

  listen = true
}
