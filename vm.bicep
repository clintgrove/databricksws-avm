@secure()
param vmpassword string

param uniqueStringSuffix string = uniqueString(resourceGroup().id)

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv56-${uniqueStringSuffix}'
  location: 'uksouth'
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enablePurgeProtection: true
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

resource keyPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault::key.id, 'Key Vault Crypto User', diskEncryptionSet.id)
  scope: keyVault
  properties: {
    principalId: diskEncryptionSet.identity.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'e147488a-f6f5-4113-8e2d-b22465e65bf6'
    ) // Key Vault Crypto Service Encryption User
    principalType: 'ServicePrincipal'
  }
}

module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.2.1' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-test-cvmwinmin'
  params: {
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
    osType: 'Windows'
    vmSize: 'Standard_DS2_v2'
    adminPassword: vmpassword
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
        diskEncryptionSet: {
          id: diskEncryptionSet.id
        }
      }
    }
    dataDisks: [
      {
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'Standard_LRS'
          diskEncryptionSet: {
            id: diskEncryptionSet.id
          }
        }
      }
    ]
  }
}
