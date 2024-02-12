@description('The name of the public subnet to create.')
param publicSubnetName string = 'public-subnet'
@description('CIDR range for the public subnet.')
param publicSubnetCidr string = '10.101.64.0/18'
@description('CIDR range for the private subnet.')
param privateSubnetCidr string = '10.101.0.0/18'
@description('CIDR range for the private endpoint subnet..')
param privateEndpointSubnetCidr string = '10.101.128.0/24'
@description('The name of the private subnet to create.')
param privateSubnetName string = 'private-subnet'
@description('The name of the subnet to create the private endpoint in.')
param PrivateEndpointSubnetName string = 'default'
@description('CIDR range for the vnet.')
param vnetCidr array = ['10.101.0.0/16']
@description('The name of the workspace to create.')
param workspaceName string = 'dwwaf002'

var privateDnsZoneName = 'privatelink.azuredatabricks.net'
var privateEndpointName = '${workspaceName}-pvtEndpoint'
var privateEndpointNameBrowserAuth = '${workspaceName}-pvtEndpoint-browserAuth'
var pvtEndpointDnsGroupNameBrowserAuth = '${privateEndpointNameBrowserAuth}/mydnsgroupname'

module nsg 'br/public:avm/res/network/network-security-group:0.1.2' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-test-dwwaf-nsg'
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

module vnetwork 'br/public:avm/res/network/virtual-network:0.1.1' = {
  dependsOn: [
    nsg
  ]
  name: '${uniqueString(deployment().name, 'uksouth')}-test-dwwaf-vnet'
  params: {
    name: 'dwwaf-vnet'
    location: 'uksouth'
    addressPrefixes: vnetCidr
    subnets: [
      {
        name: publicSubnetName
        addressPrefix: publicSubnetCidr
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
        name: privateSubnetName
        addressPrefix: privateSubnetCidr
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
        name: PrivateEndpointSubnetName
        addressPrefix: privateEndpointSubnetCidr
        privateEndpointNetworkPolicies: 'Disabled'

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
    customPrivateSubnetName: vnetwork.outputs.subnetNames[1]
    customPublicSubnetName: vnetwork.outputs.subnetNames[0]
    customVirtualNetworkResourceId: vnetwork.outputs.resourceId
    disablePublicIp: true
    location: 'uksouth'
    natGatewayName: nsg.outputs.name
    prepareEncryption: true
    publicNetworkAccess: 'Disabled'
    requiredNsgRules: 'NoAzureDatabricksRules'
    requireInfrastructureEncryption: true
    skuName: 'premium'
    storageAccountName: ${uniqueString(deployment().name, 'storage')}
    storageAccountSkuName: 'Standard_ZRS'
    vnetAddressPrefix: '10.101' 
    roleAssignments: [
      {
        principalId: 'aa736789-9da5-4b91-a8ba-8e9d142e6153' //adornglobal
        principalType: 'User'
        roleDefinitionIdOrName: 'Owner'
      }
    ]
  }
}

module accessConnector 'br/public:avm/res/databricks/access-connector:0.1.0' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-dbraccessconnector'
  params: {
    name: 'dacmin001'
    location: 'uksouth'
    roleAssignments: [
      {
        principalId: '5d39eec6-6d61-4be7-bc0d-f411a9e67d6a' //adornglobal
        principalType: 'User'
        roleDefinitionIdOrName: 'Owner'
      }
    ]
    
  }
}

module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.3.3' = {
  dependsOn: [
    workspace
    vnetwork
    nsg
  ]
  name: '${uniqueString(deployment().name, 'uksouth')}-dbr-privateendpoint'
  params: {
    name: privateEndpointName
    location: 'uksouth'
    subnetResourceId: vnetwork.outputs.subnetResourceIds[2]
    privateDnsZoneGroupName: 'config1'
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          groupIds: [
            'databricks_ui_api'
          ]
          privateLinkServiceId: workspace.outputs.resourceId
        }
      }
    ]
  }
}

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.3' = {
  dependsOn: [
    privateEndpoint
  ]
  name: '${uniqueString(deployment().name, 'uksouth')}-pvdnszone'
  params: {
    name: privateDnsZoneName
    location: 'global'
    virtualNetworkLinks: [
      {
        registrationEnabled: true
        virtualNetworkResourceId: vnetwork.outputs.resourceId 
      }
    ]
  }
}

module privateEndpoint_browserAuth 'br/public:avm/res/network/private-endpoint:0.3.3' = {
  dependsOn: [
    privateEndpoint
    vnetwork
    workspace
    privateDnsZone
  ]
  name: '${uniqueString(deployment().name, 'uksouth')}-browserauth-pe'
  params: {
    name: privateEndpointNameBrowserAuth
    location: 'uksouth'
    subnetResourceId: vnetwork.outputs.subnetResourceIds[2]
    privateDnsZoneGroupName: pvtEndpointDnsGroupNameBrowserAuth
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
