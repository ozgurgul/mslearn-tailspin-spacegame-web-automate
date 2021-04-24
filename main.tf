# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {

   backend "azurerm" {
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

#########
# NOTE
# You can also put the content of variables.tf at the top of the main.tf file.
#########

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

#########
# END
#########

# resource "random_integer" "app_service_name_suffix" {
#   min = 1000
#   max = 9999
# }

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location

  tags = {
    environment = var.rg_tag
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${azurerm_resource_group.rg.name}-SecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                        = "ssh"
    priority                    = "100"
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "tcp"
    source_port_range           = "*"
    destination_port_range      = "22"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }

  tags = azurerm_resource_group.rg.tags
}

resource "azurerm_virtual_network" "virtual-network" {
  name                = "${azurerm_resource_group.rg.name}-VirtualNetwork"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet1" {
  name                            = format("%s-Subnet1", azurerm_resource_group.rg.name)
  resource_group_name             = azurerm_resource_group.rg.name
  virtual_network_name            = azurerm_virtual_network.virtual-network.name
  address_prefixes                = ["10.0.2.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "public-ip" {
  count                         = var.vm_count
  name                          = format("public-ip-%02d", count.index + 1)
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  allocation_method             = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                                  = format("%s-NIC%02d", azurerm_resource_group.rg.name, count.index + 1)
  count                                 = var.vm_count
  location                              = azurerm_resource_group.rg.location
  resource_group_name                   = azurerm_resource_group.rg.name

  ip_configuration {
    name                            = "nic-ip-config1"
    subnet_id                       = azurerm_subnet.subnet1.id
    private_ip_address_allocation   = "Dynamic"
    public_ip_address_id            = element(azurerm_public_ip.public-ip.*.id, count.index)
  }

  tags = azurerm_resource_group.rg.tags
}

###########################################################

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  
  count                 = var.vm_count
  name                  = format("vm-%02d", count.index + 1)
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [element(azurerm_network_interface.nic.*.id, count.index)]
  size               = var.vm_size

  os_disk {
    name                = format("vm-%02d-OS-Disk", count.index + 1)
    caching             = "ReadWrite"
    storage_account_type   = "Standard_LRS"
  }

  source_image_reference  {
    publisher = element(split("/", var.vm_image_string), 0)
    offer     = element(split("/", var.vm_image_string), 1)
    sku       = element(split("/", var.vm_image_string), 2)
    version   = element(split("/", var.vm_image_string), 3)
  }

  plan {
    publisher = element(split("/", var.vm_image_string), 0)
    name      = element(split("/", var.vm_image_string), 1)
    product   = element(split("/", var.vm_image_string), 2)
  }

  computer_name  = format("host-%02d", count.index + 1)
  admin_username = var.admin_username
  admin_password = var.admin_password
  disable_password_authentication = false

  admin_ssh_key {
      username       = var.admin_username
      public_key     = tls_private_key.example_ssh.public_key_openssh
  }

  # boot_diagnostics {
  #     storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  # }

  tags = {
      environment = azurerm_resource_group.rg.tags
  }
}

# Optional data disks
resource "azurerm_managed_disk" "data_disk" {
  count                = var.vm_count
  name                 = format("vm-%02d-OS-Disk", count.index + 1)
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "example" {
  managed_disk_id    = azurerm_managed_disk.data_disk.*.id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.*.id
  lun                = "10"
  caching            = "ReadWrite"
}

output "public_ip_address" {
  value = azurerm_public_ip.public-ip.*.ip_address
}

output "hostname" {
  value = azurerm_virtual_machine.vm.*.name
}


