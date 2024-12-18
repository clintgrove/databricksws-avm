@secure()
param vmpassword string

param uniqueStringSuffix string = uniqueString(resourceGroup().id)

// Define the OS disk name
var osDiskName = 'cvmwinmin-disk-os-01'

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

// Reference the existing OS disk if it exists
resource existingOsDisk 'Microsoft.Compute/disks@2021-04-01' existing = {
  name: osDiskName
}

// Create a new OS disk if it does not exist
resource newOsDisk 'Microsoft.Compute/disks@2021-04-01' = if (empty(existingOsDisk.id)) {
  name: osDiskName
  location: 'uksouth'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 128
    encryption: {
      diskEncryptionSetId: diskEncryptionSet.id
    }
  }
}

// Determine the disk ID to use
var osDiskReference = empty(existingOsDisk.id) ? {
  caching: 'ReadWrite'
  diskSizeGB: 128
  managedDisk: {
    storageAccountType: 'Premium_LRS'
    diskEncryptionSet: {
      id: diskEncryptionSet.id
    }
  }
  createOption: 'Attach'
} : {
  id: existingOsDisk.id
  caching: 'ReadWrite'
  diskSizeGB: 128
  managedDisk: {
    storageAccountType: 'Standard_LRS'
    diskEncryptionSet: {
      id: diskEncryptionSet.id
    }
  }
}
module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.2.1' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-test-cvmwinmin'
  params: {
    osDisk: osDiskReference
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
    dataDisks: [
      {
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'Premium_LRS'
          diskEncryptionSet: {
            id: diskEncryptionSet.id
          }
        }
      }
    ]
  }
}
