variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "eventhub_namespace_name" {
  type = string
}

variable "eventhubs" {
  type = list(string)
}

