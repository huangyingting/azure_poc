resource "azurerm_public_ip" "jumpbox" {
  name                = "jumpbox"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.poc.name
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "jumpbox${random_string.poc.result}"
  tags                = var.tags
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "jumpbox-nic"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.poc.name
  ip_configuration {
    name                          = "ip-config"
    subnet_id                     = azurerm_subnet.jumpbox-primary.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
  tags = var.tags
}

resource "azurerm_network_security_group" "jumpbox" {
  name                = "jumpbox-nsg"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.poc.name
  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "jumpbox" {
  subnet_id                 = azurerm_subnet.jumpbox-primary.id
  network_security_group_id = azurerm_network_security_group.jumpbox.id
  depends_on = [
    azurerm_network_interface.jumpbox
  ]
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                  = "jumpbox"
  location              = var.primary_location
  resource_group_name   = azurerm_resource_group.poc.name
  network_interface_ids = [azurerm_network_interface.jumpbox.id]
  size                  = var.vm_size
  admin_username        = var.admin_username
  priority              = "Spot"
  eviction_policy       = "Deallocate"
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  tags = var.tags
}

