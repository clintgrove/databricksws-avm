module workspace 'br/public:avm/res/databricks/workspace:0.1.0' = {
  name: '${uniqueString(deployment().name, resourceGroup().location)}-test-dwwaf'
  params: {
    name: 'dwwaf002'
    customPrivateSubnetName: 'clintdbr-subnet-private'
    customPublicSubnetName: 'clintdbr-subnet-public'
    customVirtualNetworkResourceId: '<customVirtualNetworkResourceId>'
    disablePublicIp: true
    location: resourceGroup().location
    lock: {
      kind: 'CanNotDelete'
      name: 'myCustomLockName'
    }
    natGatewayName: 'nat-gateway'
    prepareEncryption: true
    publicIpName: 'nat-gw-public-ip'
    publicNetworkAccess: 'Disabled'
    requiredNsgRules: 'NoAzureDatabricksRules'
    requireInfrastructureEncryption: true
    skuName: 'premium'
    storageAccountName: 'sadwwaf001'
    storageAccountSkuName: 'Standard_ZRS'
    tags: {
      Environment: 'Non-Prod'
      'hidden-title': 'This is visible in the resource name'
      Role: 'DeploymentValidation'
    }
    vnetAddressPrefix: '10.100'
  }
}
