# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}


####
# Check out variables.tf..! 
####

# resource "random_integer" "app_service_name_suffix" {
#   min = 1000
#   max = 9999
# }

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  # arm_endpoint    = var.arm_endpoint # for azurestack
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
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


resource "azurerm_virtual_machine" "vm" {
  count                 = var.vm_count
  name                  = format("vm-%02d", count.index + 1)
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [element(azurerm_network_interface.nic.*.id, count.index)]
  vm_size               = var.vm_size

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
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

  storage_os_disk {
    name                = format("vm-%02d-OS-Disk", count.index + 1)
    caching             = "ReadWrite"
    managed_disk_type   = "Standard_LRS"
    create_option       = "FromImage"
  }

  # Optional data disks
  storage_data_disk {
    name                = format("vm-%02d-Data-Disk", count.index + 1)
    disk_size_gb        = "20"
    managed_disk_type   = "Standard_LRS"
    create_option       = "Empty"
    lun                 = 0
  }

  os_profile {
    computer_name  = format("host-%02d", count.index + 1)
    admin_username = var.admin_username
    admin_password = var.admin_password
  }
   
  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = azurerm_resource_group.rg.tags
}

output "public_ip_address" {
  value = azurerm_public_ip.public-ip.*.ip_address
}

output "hostname" {
  value = azurerm_virtual_machine.vm.*.name
}


