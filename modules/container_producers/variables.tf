variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "container_image" {
  type = string
}

variable "connection_string" {
  type = string
}

variable "containers_group_name" {
  type    = string
  default = "aeh-producers"
}

variable "container_name" {
  type    = string
  default = "event-producers"
}

variable "cpu" {
  type    = number
  default = 0.5
}

variable "memory" {
  type    = number
  default = 1.0
}

variable "dockerhub_username" {
  type = string
}

variable "dockerhub_token" {
  type = string
}
