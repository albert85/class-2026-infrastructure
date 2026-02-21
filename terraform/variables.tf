variable "project_vpc" {
    type = string
}

variable "project_ami" {
    type = string
}

variable "project_instance_type" {
    type = string
}
variable "project_subnet" {
    type = string
}

variable "project_keyname" {
    type = string
}


variable "db_username" {
    type = string
}
variable "db_engine" {
    type = string
}

variable "db_instance_class" {
    type = string
}
variable "db_allocated_storage" {
    type = string
}
variable "db_storage_type" {
    type = string
}

variable "db_subnet_name" {
    type = string
}
variable "db_identifier" {
    type = string
}
variable "project_aurora_subnet" {
    type = string
}

variable "allowed_cidrs" {
  default = ["10.0.0.0/16"]
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "environment" {
  default = "dev"
}

variable "rds_subnet_name" {
  type = string
}

variable "rds_name" {
  type = string
}