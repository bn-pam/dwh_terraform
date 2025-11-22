variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sql_admin_login" {
  type = string
}

variable "sql_admin_password" {
  type = string
}

variable "schema_file_path" {
  type        = string
  description = "Path to the SQL schema file"
}
