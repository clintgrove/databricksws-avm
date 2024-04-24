@secure()
param vmpassword string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-groove-cvmwinmin'
  location: 'uksouth'
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enablePurgeProtection: true // Required for encryption to work
    softDeleteRetentionInDays: 7
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enabledForDeployment: true
    enableRbacAuthorization: true
    accessPolicies: []
  }

  resource key 'keys@2022-07-01' = {
    name: 'keyEncryptionKey'
    properties: {
      kty: 'RSA'
    }
  }
}

resource diskEncryptionSet 'Microsoft.Compute/diskEncryptionSets@2021-04-01' = {
  name: 'diskEncryptionvmgroove'
  location: 'uksouth'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    activeKey: {
      sourceVault: {
        id: keyVault.id
      }
      keyUrl: keyVault::key.properties.keyUriWithVersion
    }
    encryptionType: 'EncryptionAtRestWithPlatformAndCustomerKeys'
  }
}

module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.2.1' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-test-cvmwinmin'
  params: {
    // Required parameters
    adminUsername: 'localAdminUser'
    encryptionAtHost: false
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
            subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', 'dwwaf-vnet', 'defaultSubnet')
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
        diskEncryptionSet: {
          id: diskEncryptionSet.id
        }
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_DS2_v2'
    adminPassword: vmpassword
    dataDisks: [
      {
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'Premium_LRS'
          diskEncryptionSet: {
            id:  diskEncryptionSet.id
          }
        }
      }
    ]
  }
}

module publicIpAddress 'br/public:avm/res/network/public-ip-address:0.2.2' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-public-ip'
  params: {
    name: 'bastionhostdbr1-pip'
    location: 'uksouth'
  }
}

module bastionHost 'br/public:avm/res/network/bastion-host:0.1.1' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-bastion-host'
  params: {
    name: 'bastionhostdbr1'
    vNetId: resourceId('Microsoft.Network/virtualNetworks', 'dwwaf-vnet')
    location: 'uksouth'
    bastionSubnetPublicIpResourceId: publicIpAddress.outputs.resourceId
  }
}
