@description('Specify whether to provision new vnet or deploy to existing vnet')
@allowed([
  'new'
  'existing'
])
param vnetNewOrExisting string = 'existing'
param vnetName string = 'dwwaf-vnet'
param vnetAddressPrefixParam string = '10.101' 
var addressPrefix = '${vnetAddressPrefixParam}.0.0/16'
var privateDnsZoneName = 'privatelink.azuredatabricks.net'
// @description('Resource group name where the existing VNet is located')
// param existingVnetResourceGroupName string
@description('Resource ID of the existing NSG')
param existingNsgResourceId string = ''
@description('Resource ID of the existing VNet')
param existingVnetResourceId string = ''
@description('Resource ID of the existing private DNS zone')
param existingPrivateDnsZoneId string = ''
param existingsubName0 string = ''
param existingsubName1 string = ''
param existingsubName2 string = ''
param existingSubNetID0 string = ''
param existingSubNetID1 string = ''
param existingSubNetID2 string = ''
param existingNsgName string = ''

module nsg 'br/public:avm/res/network/network-security-group:0.1.2'  = if(vnetNewOrExisting == 'new') {
  name: '${uniqueString(deployment().name, 'uksouth')}-dwwaf-nsg'
  params: {
    name: 'dwwaf-nsg'
    location: 'uksouth'
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

module vnetwork 'br/public:avm/res/network/virtual-network:0.1.1' = if(vnetNewOrExisting == 'new') {
  name: '${uniqueString(deployment().name, 'uksouth')}-dwwaf-vnet'
  params: {
    name: vnetName
    location: 'uksouth'
    addressPrefixes: [addressPrefix]
    subnets: [
      {
        name: 'private-subnet'
        addressPrefix: cidrSubnet(addressPrefix, 20, 2) //privateSubnetCidr
        networkSecurityGroupResourceId: nsg.outputs.resourceId
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
        networkSecurityGroupResourceId: nsg.outputs.resourceId
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

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.3' = if(vnetNewOrExisting == 'new') {
  name: '${uniqueString(deployment().name, 'uksouth')}-pvdnszone'
   params: {
     name: privateDnsZoneName
     location: 'global'
     virtualNetworkLinks: [
       {
         registrationEnabled: false
         virtualNetworkResourceId: vnetwork.outputs.resourceId 
       }
     ]
   }
 }

output vnetId string = vnetNewOrExisting == 'new' ? vnetwork.outputs.resourceId : existingVnetResourceId
output nsgId string = vnetNewOrExisting == 'new' ? nsg.outputs.resourceId : existingNsgResourceId
output privateDnsZoneId string = vnetNewOrExisting == 'new' ? privateDnsZone.outputs.resourceId : existingPrivateDnsZoneId
output vnetsubName0 string = vnetNewOrExisting == 'new' ? vnetwork.outputs.subnetNames[0] : existingsubName0
output vnetsubName1 string = vnetNewOrExisting == 'new' ? vnetwork.outputs.subnetNames[1] : existingsubName1
output vnetsubName2 string = vnetNewOrExisting == 'new' ? vnetwork.outputs.subnetNames[2] : existingsubName2
output vnetSub0 string = vnetNewOrExisting == 'new' ? vnetwork.outputs.subnetResourceIds[0] : existingSubNetID0
output vnetSub1 string = vnetNewOrExisting == 'new' ? vnetwork.outputs.subnetResourceIds[1] : existingSubNetID1
output defaultSubnetId string = vnetNewOrExisting == 'new' ? vnetwork.outputs.subnetResourceIds[2] : existingSubNetID2
output ngsname string = vnetNewOrExisting == 'new' ? nsg.outputs.name : existingNsgName
