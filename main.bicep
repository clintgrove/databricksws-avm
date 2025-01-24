@description('The name of the workspace to create.')
param workspaceName string
@description('vnet prefix address')
param vnetAddressPrefixParam string = '10.101'

var addressPrefix = '${vnetAddressPrefixParam}.0.0/16'

@description('Specify whether to provision new vnet or deploy to existing vnet')
@allowed([
  'new'
  'existing'
])
param vnetNewOrExisting string = 'existing'

param vnetName string = 'bricks-vnet'
@description('Resource group name where the existing VNet is located')
param existingVnetResourceGroupName string
@description('Resource ID of the existing NSG')
param existingNsgResourceId string = ''

resource existingVnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = if (vnetNewOrExisting == 'existing') {
  name: vnetName
  scope: resourceGroup(existingVnetResourceGroupName)
}

@description('Resource ID of the existing VNet')
var existingVnetResourceId = vnetNewOrExisting == 'existing' ? existingVnet.id : ''
@description('Name of the existing private subnet')
param existingPrivateSubnetName string = 'private-subnet'
@description('Name of the existing public subnet')
param existingPublicSubnetName string = 'public-subnet'

@description('Resource ID of the existing default subnet')
var existingDefaultSubnetResourceId = vnetNewOrExisting == 'existing' ? existingVnet.properties.subnets[0].id : ''

var privateDnsZoneName = 'privatelink.azuredatabricks.net'
var privateEndpointNameBrowserAuth = '${workspaceName}-pvtEndpoint-browserAuth'

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = if (vnetNewOrExisting == 'new') {
  name: '${uniqueString(deployment().name, 'uksouth')}-bricks-nsg'
  location: 'uksouth'
  properties: {
    securityRules: [
      {
        name: 'AllowBastionToVM'
        properties: {
          description: 'Allow Azure Bastion to connect to the VM on RDP port 3389.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAzureBastionTraffic'
        properties: {
          description: 'Allow Azure Bastion service traffic to AzureBastionSubnet.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.101.129.0/26' //AzureBastionSubnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-worker-inbound'
        properties: {
          description: 'Required for worker nodes communication within a cluster.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 102
          direction: 'Inbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-databricks-webapp'
        properties: {
          description: 'Required for workers communication with Databricks Webapp.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureDatabricks'
          access: 'Allow'
          priority: 103
          direction: 'Outbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-sql'
        properties: {
          description: 'Required for workers communication with Azure SQL services.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3306'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Sql'
          access: 'Allow'
          priority: 104
          direction: 'Outbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-storage'
        properties: {
          description: 'Required for workers communication with Azure Storage services.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 105
          direction: 'Outbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-worker-outbound'
        properties: {
          description: 'Required for worker nodes communication within a cluster.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 106
          direction: 'Outbound'
        }
      }
      {
        name: 'Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-eventhub'
        properties: {
          description: 'Required for worker communication with Azure Eventhub services.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '9093'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          priority: 107
          direction: 'Outbound'
        }
      }
    ]
  }
}

var nsgResourceId = vnetNewOrExisting == 'new' ? nsg.id : existingNsgResourceId

module vnetwork 'br/public:avm/res/network/virtual-network:0.1.1' = if(vnetNewOrExisting == 'new') {
  name: '${uniqueString(deployment().name, 'uksouth')}-bricks-vnet'
  params: {
    name: vnetName
    location: 'uksouth'
    addressPrefixes: [addressPrefix]
    subnets: [
      {
        name: 'private-subnet'
        addressPrefix: cidrSubnet(addressPrefix, 20, 2) //privateSubnetCidr
        networkSecurityGroupResourceId: nsgResourceId
        delegations: [
            {
              name: 'databricks-del-private'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
      }
      {
        name: 'public-subnet'
        addressPrefix: cidrSubnet(addressPrefix, 20, 1) //publicSubnetCidr
        networkSecurityGroupResourceId: nsgResourceId
        delegations: [
            {
              name: 'databricks-del-public'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
      }
      {
        name: 'defaultSubnet'
        addressPrefix: cidrSubnet(addressPrefix, 20, 0)
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.101.129.0/26'
      }
    ]
  }
}

var vnetResourceId = vnetNewOrExisting == 'new' ? vnetwork.outputs.resourceId : existingVnetResourceId
var privateSubnetName = vnetNewOrExisting == 'new' ? vnetwork.outputs.subnetNames[0] : existingPrivateSubnetName
var publicSubnetName = vnetNewOrExisting == 'new' ? vnetwork.outputs.subnetNames[1] : existingPublicSubnetName
var vnetSubnetId2 = vnetNewOrExisting == 'new' ? vnetwork.outputs.subnetResourceIds[2] : existingDefaultSubnetResourceId

module workspace 'br/public:avm/res/databricks/workspace:0.8.5' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-databricksworkspace'
  params: {
    name: workspaceName
    customPrivateSubnetName: privateSubnetName
    customPublicSubnetName: publicSubnetName
    customVirtualNetworkResourceId: vnetResourceId
    disablePublicIp: true
    location: 'uksouth'
    publicIpName: 'nat-gw-public-ip'
    natGatewayName: 'nat-gateway' //nsg.outputs.name
    prepareEncryption: true
    publicNetworkAccess: 'Disabled'
    requiredNsgRules: 'NoAzureDatabricksRules'
    requireInfrastructureEncryption: true
    skuName: 'premium'
    storageAccountName: take('${workspaceName}${uniqueString(resourceGroup().id)}', 24)
    storageAccountSkuName: 'Standard_ZRS'
    vnetAddressPrefix: vnetAddressPrefixParam
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privateDnsZone.outputs.resourceId
            }
          ]
        }
        service: 'databricks_ui_api'
        subnetResourceId: vnetSubnetId2 //vnetwork.outputs.subnetResourceIds[2]
        tags: {
          Environment: 'Non-Prod'
          Role: 'DeploymentValidation'
        }
      }
    ]
  }
}

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.3' = {
 name: '${uniqueString(deployment().name, 'uksouth')}-pvdnszone'
  params: {
    name: privateDnsZoneName
    location: 'global'
    virtualNetworkLinks: [
      {
        registrationEnabled: false
        virtualNetworkResourceId: vnetResourceId
      }
    ]
  }
}

module privateEndpoint_browserAuth 'br/public:avm/res/network/private-endpoint:0.3.3' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-browserauth-pe'
  params: {
    name: privateEndpointNameBrowserAuth
    location: 'uksouth'
    subnetResourceId: vnetSubnetId2
    privateDnsZoneGroupName: 'config2'
    privateDnsZoneResourceIds: [
      privateDnsZone.outputs.resourceId
    ]
    privateLinkServiceConnections: [
      {
        name: privateEndpointNameBrowserAuth
        properties: {
          groupIds: [
            'browser_authentication'
          ]
          privateLinkServiceId: workspace.outputs.resourceId
        }
      }
    ]
  }
}

output vnetId string = vnetwork.outputs.resourceId
output vnetSub0 string = vnetwork.outputs.subnetResourceIds[0]
output vnetSub1 string = vnetwork.outputs.subnetResourceIds[1]
output vnetSub2 string = vnetwork.outputs.subnetResourceIds[2]
