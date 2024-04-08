provider "azurerm" {
  features {
  }
}

#variables
variable "A-location" {
    description = "Location of the resources"
    #default     = "eastus"
}

variable "B-resource_group_name" {
    description = "Name of the resource group to create"
}

variable "C-home_public_ip" {
    description = "Your home public ip address"
}

variable "D-username" {
    description = "Username for Virtual Machines"
    #default     = "azureuser"
}

variable "E-password" {
    description = "Password for Virtual Machines"
    sensitive = true
}

resource "azurerm_resource_group" "RG" {
  location = var.A-location
  name     = var.B-resource_group_name
  provisioner "local-exec" {
    command = "az vm image terms accept --urn cisco:cisco-asav:asav-azure-byol:latest"
  }
}

#logic app to self destruct resourcegroup after 24hrs
data "azurerm_subscription" "sub" {
}

resource "azurerm_logic_app_workflow" "workflow1" {
  location = azurerm_resource_group.RG.location
  name     = "labdelete"
  resource_group_name = azurerm_resource_group.RG.name
  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_resource_group.RG,
  ]
}
resource "azurerm_role_assignment" "contrib1" {
  scope = azurerm_resource_group.RG.id
  role_definition_name = "Contributor"
  principal_id  = azurerm_logic_app_workflow.workflow1.identity[0].principal_id
  depends_on = [azurerm_logic_app_workflow.workflow1]
}

resource "azurerm_resource_group_template_deployment" "apiconnections" {
  name                = "group-deploy"
  resource_group_name = azurerm_resource_group.RG.name
  deployment_mode     = "Incremental"
  template_content = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Web/connections",
            "apiVersion": "2016-06-01",
            "name": "arm-1",
            "location": "${azurerm_resource_group.RG.location}",
            "kind": "V1",
            "properties": {
                "displayName": "labdeleteconn1",
                "authenticatedUser": {},
                "statuses": [
                    {
                        "status": "Ready"
                    }
                ],
                "connectionState": "Enabled",
                "customParameterValues": {},
                "alternativeParameterValues": {},
                "parameterValueType": "Alternative",
                "createdTime": "2023-05-21T23:07:20.1346918Z",
                "changedTime": "2023-05-21T23:07:20.1346918Z",
                "api": {
                    "name": "arm",
                    "displayName": "Azure Resource Manager",
                    "description": "Azure Resource Manager exposes the APIs to manage all of your Azure resources.",
                    "iconUri": "https://connectoricons-prod.azureedge.net/laborbol/fixes/path-traversal/1.0.1552.2695/arm/icon.png",
                    "brandColor": "#003056",
                    "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm",
                    "type": "Microsoft.Web/locations/managedApis"
                },
                "testLinks": []
            }
        },
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "labdelete",
            "location": "${azurerm_resource_group.RG.location}",
            "dependsOn": [
                "[resourceId('Microsoft.Web/connections', 'arm-1')]"
            ],
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        }
                    },
                    "triggers": {
                        "Recurrence": {
                            "recurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "evaluatedRecurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "type": "Recurrence"
                        }
                    },
                    "actions": {
                        "Delete_a_resource_group": {
                            "runAfter": {},
                            "type": "ApiConnection",
                            "inputs": {
                                "host": {
                                    "connection": {
                                        "name": "@parameters('$connections')['arm']['connectionId']"
                                    }
                                },
                                "method": "delete",
                                "path": "/subscriptions/@{encodeURIComponent('${data.azurerm_subscription.sub.subscription_id}')}/resourcegroups/@{encodeURIComponent('${azurerm_resource_group.RG.name}')}",
                                "queries": {
                                    "x-ms-api-version": "2016-06-01"
                                }
                            }
                        }
                    },
                    "outputs": {}
                },
                "parameters": {
                    "$connections": {
                        "value": {
                            "arm": {
                                "connectionId": "[resourceId('Microsoft.Web/connections', 'arm-1')]",
                                "connectionName": "arm-1",
                                "connectionProperties": {
                                    "authentication": {
                                        "type": "ManagedServiceIdentity"
                                    }
                                },
                                "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm"
                            }
                        }
                    }
                }
            }
        }
    ]
}
TEMPLATE
}


#vwan and hub
resource "azurerm_virtual_wan" "vwan1" {
  name                = "vwan1"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
    timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_virtual_hub" "vhub1" {
  name                = "vhub1"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  virtual_wan_id      = azurerm_virtual_wan.vwan1.id
  address_prefix      = "10.0.0.0/16"
    timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_vpn_gateway" "hubvpngw" {
  resource_group_name = azurerm_resource_group.RG.name
  name                = "hubvpngw"
  location            = azurerm_resource_group.RG.location
  virtual_hub_id      = azurerm_virtual_hub.vhub1.id
  
}

data "azurerm_vpn_gateway" "hubpip" {
  name                = azurerm_vpn_gateway.hubvpngw.name
  resource_group_name = azurerm_resource_group.RG.name
  
}

resource "azurerm_vpn_site" "onprem" {
  device_vendor       = "Azure"
  location            = azurerm_resource_group.RG.location
  name                = "onprem"
  resource_group_name = azurerm_resource_group.RG.name
  virtual_wan_id      = azurerm_virtual_wan.vwan1.id
  
  link {
    ip_address    = azurerm_public_ip.onpremasa-pip.ip_address
    name          = "onpremlink"
    provider_name = "Azure"
    speed_in_mbps = 10    
    bgp {
      asn             = 65002      
      peering_address = "172.16.1.1"
    }
  }
  depends_on = [ azurerm_route_map.routemap2, azurerm_vpn_gateway.hubvpngw ]
}


resource "azurerm_vpn_gateway_connection" "onpremconnection" {
  internet_security_enabled = true
  name                      = "Connection-onprem"
  remote_vpn_site_id        = azurerm_vpn_site.onprem.id
  vpn_gateway_id            = azurerm_vpn_gateway.hubvpngw.id
  vpn_link {
    bgp_enabled      = true
    name             = "onpremlink"
    shared_key       = "vpn123"
    vpn_site_link_id = azurerm_vpn_site.onprem.link[0].id
  }
  
  routing {
    associated_route_table = data.azurerm_virtual_hub_route_table.hubdefaultrt.id
    outbound_route_map_id = azurerm_route_map.routemap2.id
  }
 
}


resource "azurerm_route_map" "routemap1" {
  name           = "routemap-one"
  virtual_hub_id = azurerm_virtual_hub.vhub1.id

  rule {
    name                 = "rule1"
    next_step_if_matched = "Terminate"

    action {
      type = "Replace"

      parameter {
        route_prefix = ["192.168.0.0/16"]
      }
    }

    match_criterion {
      match_condition = "Equals"
      route_prefix    = ["192.168.0.0/24"]
    }
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  } 
  depends_on = [ azurerm_vpn_gateway.hubvpngw]   
}


resource "azurerm_route_map" "routemap2" {
  name           = "routemap-two"
  virtual_hub_id = azurerm_virtual_hub.vhub1.id

  rule {
    name                 = "rule2"
    next_step_if_matched = "Terminate"

    action {
      type = "Add"

      parameter {
        as_path = ["65010"]
      }
    }

    match_criterion {
      match_condition = "Equals"
      route_prefix    = ["10.250.0.0/16"]
    }
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  depends_on = [ azurerm_vpn_gateway.hubvpngw] 
}

#spoke vnets
resource "azurerm_virtual_network" "spoke1-vnet" {
  address_space       = ["10.150.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "spoke1-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "10.150.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefix     = "10.150.1.0/24"
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_network" "spoke2-vnet" {
  address_space       = ["10.250.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "spoke2-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "10.250.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefix     = "10.250.1.0/24"
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_virtual_network" "onprem-vnet" {
  address_space       = ["192.168.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "onprem-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefix     = "192.168.0.0/24"
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefix     = "192.168.1.0/24"
    name                 = "GatewaySubnet" 
  }
  subnet {
    address_prefix     = "192.168.2.0/24"
    name                 = "outside"
    security_group =  azurerm_network_security_group.asasshnsg.id
  }
  subnet {
    address_prefix     = "192.168.3.0/24"
    name                 = "inside" 
    security_group = azurerm_network_security_group.asansg.id
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#vnet connections to hub
resource "azurerm_virtual_hub_connection" "tospoke1" {
  name                      = "tospoke1"
  internet_security_enabled = true
  virtual_hub_id            = azurerm_virtual_hub.vhub1.id
  remote_virtual_network_id = azurerm_virtual_network.spoke1-vnet.id
}
resource "azurerm_virtual_hub_connection" "tospoke2" {
  name                      = "tospoke2"
  internet_security_enabled = true
  virtual_hub_id            = azurerm_virtual_hub.vhub1.id
  remote_virtual_network_id = azurerm_virtual_network.spoke2-vnet.id
  
  routing {
    associated_route_table_id = data.azurerm_virtual_hub_route_table.hubdefaultrt.id    
    outbound_route_map_id = azurerm_route_map.routemap1.id
  }
  
}

#NSG
resource "azurerm_network_security_group" "spokevnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "spoke-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "spokevnetnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockRDPInbound"
  network_security_group_name = "spoke-vnet-default-nsg"
  priority                    = 2711
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.spokevnetNSG.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_group" "asansg" {
  location            = azurerm_resource_group.RG.location
  name                = "onprem-asa-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "asansgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockInbound"
  network_security_group_name = "onprem-asa-default-nsg"
  priority                    = 2711
  protocol                    = "*"
  resource_group_name         = azurerm_network_security_group.asansg.resource_group_name
  source_address_prefix       = "192.168.0.0/24"
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "asansgrule2" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  direction                   = "Outbound"
  name                        = "AllowCidrBlockOutbound"
  network_security_group_name = "onprem-asa-default-nsg"
  priority                    = 2712
  protocol                    = "*"
  resource_group_name         = azurerm_network_security_group.asansg.resource_group_name
  source_address_prefix       = "10.0.0.0/8"
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_network_security_group" "asasshnsg" {
  location            = azurerm_resource_group.RG.location
  name                = "onprem-ssh-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_security_rule" "asasshnsgrule1" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  direction                   = "Inbound"
  name                        = "AllowCidrBlockSSHInbound"
  network_security_group_name = "onprem-ssh-default-nsg"
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_network_security_group.asasshnsg.resource_group_name
  source_address_prefix       = var.C-home_public_ip
  source_port_range           = "*"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#default table
data "azurerm_virtual_hub_route_table" "hubdefaultrt" {
  name                = "defaultRouteTable"
  resource_group_name = azurerm_resource_group.RG.name
  virtual_hub_name    = azurerm_virtual_hub.vhub1.name
}

#Public ip's
resource "azurerm_public_ip" "spoke1vm-pip" {
  name                = "spoke1vm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_public_ip" "spoke2vm-pip" {
  name                = "spoke2vm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_public_ip" "onpremvm-pip" {
  name                = "onpremvm-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Dynamic"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_public_ip" "onpremasa-pip" {
  name                = "onpremasa-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  sku = "Standard"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#route table for home access
resource "azurerm_route_table" "RT" {
  name                          = "to-home"
  location                      = azurerm_resource_group.RG.location
  resource_group_name           = azurerm_resource_group.RG.name
  disable_bgp_route_propagation = false

  route {
    name           = "tohome"
    address_prefix = "${var.C-home_public_ip}/32"
    next_hop_type  = "Internet"
    
  }
  
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}
resource "azurerm_subnet_route_table_association" "onspoke1defaultsubnet" {
  subnet_id      = azurerm_virtual_network.spoke1-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "2h"
    read = "2h"
    delete = "2h"
  }
}
resource "azurerm_subnet_route_table_association" "onspoke2defaultsubnet" {
  subnet_id      = azurerm_virtual_network.spoke2-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "2h"
    read = "2h"
    delete = "2h"
  }
}

resource "azurerm_route_table" "onpremRT" {
  name                          = "onpremRT"
  location                      = azurerm_resource_group.RG.location
  resource_group_name           = azurerm_resource_group.RG.name
  disable_bgp_route_propagation = false

  route {
    name           = "toasa"
    address_prefix = "10.0.0.0/8"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "192.168.3.4"
  }
  route {
    name           = "tohome"
    address_prefix = "${var.C-home_public_ip}/32"
    next_hop_type  = "Internet"
    
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}
resource "azurerm_subnet_route_table_association" "onpremdefaultsubnet" {
  subnet_id      = azurerm_virtual_network.onprem-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.onpremRT.id
  timeouts {
    create = "2h"
    read = "2h"
    #update = "2h"
    delete = "2h"
  }
}

#vnic's
resource "azurerm_network_interface" "spoke1vm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "spoke1vm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spoke1vm-pip.id
    subnet_id                     = azurerm_virtual_network.spoke1-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "spoke2vm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "spoke2vm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.spoke2vm-pip.id
    subnet_id                     = azurerm_virtual_network.spoke2-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "onpremvm-nic" {
  location            = azurerm_resource_group.RG.location
  name                = "onpremvm-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onpremvm-pip.id
    subnet_id                     = azurerm_virtual_network.onprem-vnet.subnet.*.id[0]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "asainside-nic" {
  enable_ip_forwarding = true
  location            = azurerm_resource_group.RG.location
  name                = "asainside-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_virtual_network.onprem-vnet.subnet.*.id[3]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_network_interface" "asaoutside-nic" {
  enable_ip_forwarding = true
  location            = azurerm_resource_group.RG.location
  name                = "asaoutside-nic"
  resource_group_name = azurerm_resource_group.RG.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onpremasa-pip.id
    subnet_id                     = azurerm_virtual_network.onprem-vnet.subnet.*.id[2]
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#VM's
resource "azurerm_windows_virtual_machine" "spoke1vm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "spoke1vm"
  network_interface_ids = [azurerm_network_interface.spoke1vm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killspoke1vmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killspoke1vmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.spoke1vm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_windows_virtual_machine" "spoke2vm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "spoke2vm"
  network_interface_ids = [azurerm_network_interface.spoke2vm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killspoke2vmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killspokevmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.spoke2vm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_windows_virtual_machine" "onpremvm" {
  admin_password        = var.E-password
  admin_username        = var.D-username
  location              = azurerm_resource_group.RG.location
  name                  = "onpremvm"
  network_interface_ids = [azurerm_network_interface.onpremvm-nic.id]
  resource_group_name   = azurerm_resource_group.RG.name
  size                  = "Standard_B2ms"
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
resource "azurerm_virtual_machine_extension" "killonpremvmfirewall" {
  auto_upgrade_minor_version = true
  name                       = "killonpremvmfirewall"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtual_machine_id         = azurerm_windows_virtual_machine.onpremvm.id
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"Set-NetFirewallProfile -Enabled False\""
    }
  SETTINGS
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_linux_virtual_machine" "asav" {
  admin_password                  = var.E-password
  admin_username                  = var.D-username
  disable_password_authentication = false
  location                        = azurerm_resource_group.RG.location
  name                            = "asa"
  network_interface_ids           = [azurerm_network_interface.asaoutside-nic.id,azurerm_network_interface.asainside-nic.id]
  resource_group_name             = azurerm_resource_group.RG.name
  size                            = "Standard_D2_v2"
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  plan {
    name      = "asav-azure-byol"
    product   = "cisco-asav"
    publisher = "cisco"
  }
  source_image_reference {
    offer     = "cisco-asav"
    publisher = "cisco"
    sku       = "asav-azure-byol"
    version   = "latest"
  }
  custom_data = base64encode(local.asa_custom_data)
  depends_on = [ azurerm_vpn_site.onprem ]
  provisioner "local-exec" { 
    command = "az network vpn-site update --resource-group ${azurerm_resource_group.RG.name} --name onprem --device-model az101"  
  }
}

# Locals Block for custom data
locals {
asa_custom_data = <<CUSTOM_DATA
int gi0/0
no shut
nameif inside
ip address dhcp

route inside 192.168.0.0 255.255.0.0 192.168.3.1

crypto ikev2 enable management

crypto ikev2 policy 50
 encryption aes-256
 integrity sha
 group 2
 prf sha
 lifetime seconds 86400

crypto ipsec ikev2 ipsec-proposal vpn
 protocol esp encryption aes-256
 protocol esp integrity sha-1
crypto ipsec profile vpn-profile
 set ikev2 ipsec-proposal vpn

interface Tunnel1
 nameif vpntunnel
 ip address 172.16.1.1 255.255.255.252
 tunnel source interface management
 tunnel destination ${data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips[0]}
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile vpn-profile

group-policy vpn-tunnel internal
group-policy vpn-tunnel attributes
 vpn-tunnel-protocol ikev2

tunnel-group ${data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips[0]} type ipsec-l2l
tunnel-group ${data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips[0]} general-attributes
 default-group-policy vpn-tunnel
tunnel-group ${data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips[0]} ipsec-attributes
 ikev2 remote-authentication pre-shared-key vpn123
 ikev2 local-authentication pre-shared-key vpn123

router bgp 65002
 bgp log-neighbor-changes
 address-family ipv4 unicast
 neighbor ${data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips[0]} remote-as 65515
 neighbor ${data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips[0]} ebgp-multihop 10
 neighbor ${data.azurerm_vpn_gateway.hubpip.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips[0]} activate 
 network 192.168.0.0 mask 255.255.0.0 
 exit-address-family

route vpntunnel 10.0.0.0 255.0.0.0 172.16.1.2
CUSTOM_DATA  
}
