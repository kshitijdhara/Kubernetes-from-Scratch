# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "kubernetes-resource-group"
  location = "East US"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "kubernetes-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet
resource "azurerm_subnet" "subnet" {
  name                 = "kubernetes-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}