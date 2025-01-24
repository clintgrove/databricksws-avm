@description('The name of the workspace to create.')
param workspaceName string = 'db'
@description('vnet prefix address')
param vnetAddressPrefixParam string = '10.101' 
@description('The name of the resource group to deploy the workspace to.')
param vNetId string
param subnetName0 string
param subnetName1 string
param subnetId2 string
param privateDnsZoneIdoutput string

var privateEndpointNameBrowserAuth = '${workspaceName}-pvtEndpoint-browserAuth'

module networking 'networking.bicep' = {
  name: 'vnetwork'
}

module workspace 'br/public:avm/res/databricks/workspace:0.8.5' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-databricksworkspace'
  params: {
    name: workspaceName
    customPrivateSubnetName: subnetName0
    customPublicSubnetName: subnetName1
    customVirtualNetworkResourceId: vNetId
    disablePublicIp: true
    location: 'uksouth'
    publicIpName: 'nat-gw-public-ip'
    natGatewayName: 'nat-gateway' //nsg.outputs.name
    prepareEncryption: true
    publicNetworkAccess: 'Disabled'
    requiredNsgRules: 'NoAzureDatabricksRules'
    requireInfrastructureEncryption: true
    skuName: 'premium'
    storageAccountName: '${workspaceName}${uniqueString(resourceGroup().id)}stg'
    storageAccountSkuName: 'Standard_ZRS'
    vnetAddressPrefix: vnetAddressPrefixParam
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privateDnsZoneIdoutput
            }
          ]
        }
        service: 'databricks_ui_api'
        subnetResourceId: subnetId2
        tags: {
          Environment: 'Non-Prod'
          Role: 'DeploymentValidation'
        }
      }
    ]
  }
}

module privateEndpoint_browserAuth 'br/public:avm/res/network/private-endpoint:0.3.3' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-browserauth-pe'
  params: {
    name: privateEndpointNameBrowserAuth
    location: 'uksouth'
    subnetResourceId: subnetId2
    privateDnsZoneGroupName: 'config2'
    privateDnsZoneResourceIds: [
      networking.outputs.privateDnsZoneId
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

