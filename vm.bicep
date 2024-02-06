module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.2.1' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-test-cvmwinmin'
  params: {
    // Required parameters
    adminUsername: 'localAdminUser'
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    name: 'cvmwinmin'
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', 'dwwaf-vnet', 'default')
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_DS2_v2'
  }
}
