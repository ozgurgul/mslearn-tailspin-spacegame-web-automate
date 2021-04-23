#########
# NOTE
# You can also put the content of variables.tf at the top of the main.tf file.
#########

variable "arm_endpoint" { }

variable "subscription_id" { }

variable "client_id" { }

variable "client_secret" { }

variable "tenant_id" { }

variable "admin_username" {
  default = "testadmin"
}

variable "admin_password" {
  default = "Password123!"
}

variable "location" {
  description = "The location of the resource group"
}

variable "rg_tag" {
  default = "production"
}

variable "rg_name" {
  default     = "vocalink-rg"
  description = "The name of the resource group"
}

variable "vm_count" {
  default = 2
}

variable "vm_image_string" {
  default = "cognosys/python-3-with-redhat-7-9/python-3-with-redhat-7-9/latest"
}

variable "vm_size" {
  default = "Standard_A1_v2"
}

variable "prefix" {
  default = "vocalink"
}

