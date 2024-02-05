module workspace 'br/public:avm/res/databricks/workspace:0.1.0' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-test-dwwaf'
  params: {
    name: 'dwwaf002'
    customPrivateSubnetName: 'clintdbr-subnet-private'
    customPublicSubnetName: 'clintdbr-subnet-public'
    disablePublicIp: true
    location: 'uksouth'
    natGatewayName: 'nat-gateway'
    prepareEncryption: true
    publicIpName: 'nat-gw-public-ip'
    publicNetworkAccess: 'Disabled'
    requiredNsgRules: 'NoAzureDatabricksRules'
    requireInfrastructureEncryption: true
    skuName: 'premium'
    storageAccountName: 'sadwwaf001'
    storageAccountSkuName: 'Standard_ZRS'
    vnetAddressPrefix: '10.100' 
  }
}
