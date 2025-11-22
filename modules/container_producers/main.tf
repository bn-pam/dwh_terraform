
resource "azurerm_container_group" "producers" {
  name                = var.containers_group_name
  location            = var.location
  resource_group_name = var.resource_group_name

  os_type         = "Linux"
  restart_policy  = "Always"
  ip_address_type = "None"

  container {
    name   = var.container_name
    image  = var.container_image
    cpu    = var.cpu
    memory = var.memory


    environment_variables = {
      EVENTHUB_CONNECTION_STR = var.connection_string
      ORDERS_INTERVAL         = 60
      PRODUCTS_INTERVAL       = 120
      CLICKSTREAM_INTERVAL    = 2
    }

  }

  image_registry_credential {
    server   = "index.docker.io"
    username = var.dockerhub_username
    password = var.dockerhub_token
  }
}
