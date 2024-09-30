# Create a Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "k8s-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "k8s"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Kubelet"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "NodePort"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "WeaveNet"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6783"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Development"
    project     = "Kubernetes Cluster"
  }
}

# Create 3 VMs
resource "azurerm_linux_virtual_machine" "vm" {
  count               = 3
  name                = "kubernetes-node-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub") # Path to your local public key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  custom_data = filebase64("startup_script.sh")

  tags = {
    environment = "Development"
    project     = "Kubernetes Cluster"
  }
}

# Create public IPs
resource "azurerm_public_ip" "public_ip" {
  count               = 3
  name                = "public-ip-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Development"
    project     = "Kubernetes Cluster"
  }
}

# Create network interfaces for VMs
resource "azurerm_network_interface" "nic" {
  count               = 3
  name                = "my-nic-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }

  tags = {
    environment = "Development"
    project     = "Kubernetes Cluster"
  }
}

# Associate NSG with network interfaces
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  count                     = 3
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create managed disks for container storage
resource "azurerm_managed_disk" "data_disk" {
  count                = 3
  name                 = "data-disk-${count.index + 1}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 100

  tags = {
    environment = "Development"
    project     = "Kubernetes Cluster"
  }
}

# Attach managed disks to VMs
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachment" {
  count              = 3
  managed_disk_id    = azurerm_managed_disk.data_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}

# Output public IP addresses
output "vm_public_ips" {
  value = azurerm_public_ip.public_ip[*].ip_address
}

# Output private IP addresses
output "vm_private_ips" {
  value = azurerm_network_interface.nic[*].private_ip_address
}
