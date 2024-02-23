// @description('The name of the public subnet to create.')
// param publicSubnetName string = 'public-subnet'
// @description('CIDR range for the public subnet.')
// param publicSubnetCidr string = '10.101.64.0/18'
// @description('The name of the private subnet to create.')
// param privateSubnetName string = 'private-subnet'
// @description('CIDR range for the private subnet.')
// param privateSubnetCidr string = '10.101.0.0/18'
//@description('CIDR range for the private endpoint subnet..')
//param privateEndpointSubnetCidr string = '10.101.128.0/24'
//@description('The name of the subnet to create the private endpoint in.')
//param PrivateEndpointSubnetName string = 'defaultSub'
@description('CIDR range for the vnet.')
param vnetCidr array = ['10.101.0.0/16']
@description('The name of the workspace to create.')
param workspaceName string = 'dwwaf002'
@description('vnet prefix address')
param vnetAddressPrefixParam string = '10.101' 
var addressPrefix = '10.101.0.0/16'

@description('Specify whether to provision new vnet or deploy to existing vnet')
@allowed([
  'new'
  'existing'
])
param vnetNewOrExisting string = 'existing'

param vnetName string = 'dwwaf-vnet'
var privateDnsZoneName = 'privatelink.azuredatabricks.net'
// var privateEndpointName = '${workspaceName}-pvtEndpoint'
// var privateEndpointNameBrowserAuth = '${workspaceName}-pvtEndpoint-browserAuth'


module nsg 'br/public:avm/res/network/network-security-group:0.1.2' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-dwwaf-nsg'
  params: {
    name: 'dwwaf-nsg'
    location: 'uksouth'
    securityRules: [
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
          priority: 100
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
          priority: 100
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
          priority: 101
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
          priority: 102
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
          priority: 103
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
          priority: 104
          direction: 'Outbound'
        }
      }
    ]
  }
}

module vnetwork 'br/public:avm/res/network/virtual-network:0.1.1' = if(vnetNewOrExisting == 'new') {
  dependsOn: [
    nsg
  ]
  name: '${uniqueString(deployment().name, 'uksouth')}-dwwaf-vnet'
  params: {
    name: vnetName
    location: 'uksouth'
    addressPrefixes: vnetCidr
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
        //privateEndpointSubnetCidr
        //privateEndpointNetworkPolicies: 'Disabled'

      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.101.129.0/26'
      }
    ]
  }
}

module workspace 'br/public:avm/res/databricks/workspace:0.1.0' = {
  dependsOn: [
    vnetwork
    nsg
  ]
  name: '${uniqueString(deployment().name, 'uksouth')}-databricksworkspace'
  params: {
    name: workspaceName
    customPrivateSubnetName: vnetwork.outputs.subnetNames[0]
    customPublicSubnetName: vnetwork.outputs.subnetNames[1]
    customVirtualNetworkResourceId: vnetwork.outputs.resourceId
    disablePublicIp: true
    location: 'uksouth'
    publicIpName: 'nat-gw-public-ip'
    natGatewayName: 'nat-gateway' //nsg.outputs.name
    prepareEncryption: true
    publicNetworkAccess: 'Disabled'
    requiredNsgRules: 'NoAzureDatabricksRules'
    requireInfrastructureEncryption: true
    skuName: 'premium'
    storageAccountName: 'dev2${uniqueString(resourceGroup().id)}stg'
    storageAccountSkuName: 'Standard_ZRS'
    vnetAddressPrefix: vnetAddressPrefixParam
    privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          privateDnsZone.outputs.resourceId
        ]
        subnetResourceId: vnetwork.outputs.subnetResourceIds[2]
        tags: {
          Environment: 'Non-Prod'
          Role: 'DeploymentValidation'
        }
      }
    ]
  }
}

// module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.3.3' = {
//   dependsOn: [
//     workspace
//     vnetwork
//     nsg
//   ]
//   name: '${uniqueString(deployment().name, 'uksouth')}-dbr-privateendpoint'
//   params: {
//     name: privateEndpointName
//     location: 'uksouth'
//     subnetResourceId: vnetwork.outputs.subnetResourceIds[2]
//     privateDnsZoneGroupName: 'config1'
//     privateDnsZoneResourceIds: [
//       privateDnsZone.outputs.resourceId
//     ]
//     privateLinkServiceConnections: [
//       {
//         name: privateEndpointName
//         properties: {
//           groupIds: [
//             'databricks_ui_api'
//           ]
//           privateLinkServiceId: workspace.outputs.resourceId
//         }
//       }
//     ]
//   }
// }

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.3' = {
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

// module privateEndpoint_browserAuth 'br/public:avm/res/network/private-endpoint:0.3.3' = {
//   dependsOn: [
//     privateEndpoint
//     privateDnsZone
//   ]
//   name: '${uniqueString(deployment().name, 'uksouth')}-browserauth-pe'
//   params: {
//     name: privateEndpointNameBrowserAuth
//     location: 'uksouth'
//     subnetResourceId: vnetwork.outputs.subnetResourceIds[2]
//     privateDnsZoneGroupName: 'config2'
//     privateDnsZoneResourceIds: [
//       privateDnsZone.outputs.resourceId
//     ]
//     privateLinkServiceConnections: [
//       {
//         name: privateEndpointNameBrowserAuth
//         properties: {
//           groupIds: [
//             'browser_authentication'
//           ]
//           privateLinkServiceId: workspace.outputs.resourceId
//         }
//       }
//     ]
//   }
// }

output vnetId string = vnetwork.outputs.resourceId
