param privateDnsZoneName string = 'privatelink.dfs.core.windows.net'

module storageAccount 'br/public:avm/res/storage/storage-account:0.6.0' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-storageaccount-deploy'
  params: {
    name: '${uniqueString(resourceGroup().id)}lakestore'
    allowBlobPublicAccess: false
    blobServices: {
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 10
      containerDeleteRetentionPolicyEnabled: true
      containers: [
        {
          name: 'dbricksdefault'
          publicAccess: 'None'
        }
        {
          enableNfsV3AllSquash: true
          enableNfsV3RootSquash: true
          name: 'avdscripts'
          publicAccess: 'None'
        }
        {
          allowProtectedAppendWrites: false
          enableWORM: true
          metadata: {
            testKey: 'testValue'
          }
          name: 'archivecontainer'
          publicAccess: 'None'
          WORMRetention: 666
        }
      ]
      deleteRetentionPolicyDays: 9
      deleteRetentionPolicyEnabled: true
      lastAccessTimeTrackingPolicyEnabled: true
    }
    enableHierarchicalNamespace: true
    enableNfsV3: true
    enableSftp: true
    fileServices: {
      shares: [
        {
          accessTier: 'Hot'
          name: 'avdprofiles'
          shareQuota: 5120
        }
        {
          name: 'avdprofiles2'
          shareQuota: 102400
        }
      ]
    }
    largeFileSharesState: 'Enabled'
    localUsers: [
      {
        hasSharedKey: false
        hasSshKey: true
        hasSshPassword: false
        homeDirectory: 'avdscripts'
        name: 'testuser'
        permissionScopes: [
          {
            permissions: 'r'
            resourceName: 'avdscripts'
            service: 'blob'
          }
        ]
        storageAccountName: '${uniqueString(resourceGroup().id)}lakestore'
      }
    ]
    location: 'uksouth'
    managedIdentities: {
      systemAssigned: true
    }
    managementPolicyRules: [
      {
        definition: {
          actions: {
            baseBlob: {
              delete: {
                daysAfterModificationGreaterThan: 30
              }
              tierToCool: {
                daysAfterLastAccessTimeGreaterThan: 5
              }
            }
          }
          filters: {
            blobIndexMatch: [
              {
                name: 'BlobIndex'
                op: '=='
                value: '1'
              }
            ]
            blobTypes: [
              'blockBlob'
            ]
            prefixMatch: [
              'sample-container/log'
            ]
          }
        }
        enabled: true
        name: 'FirstRule'
        type: 'Lifecycle'
      }
    ]
    privateEndpoints: [
      {
        name: 'stg-dfs-private-endpoint'
        privateDnsZoneResourceIds: [
          resourceId('Microsoft.Network/privateDnsZones', privateDnsZoneName)
        ]
        service: 'dfs'
        subnetResourceId:  resourceId('Microsoft.Network/virtualNetworks/subnets', 'dwwaf-vnet', 'defaultSubnet')
        tags: {
          Environment: 'Non-Prod'
          Role: 'DeploymentValidation'
        }
      }
    ]
    sasExpirationPeriod: '180.00:00:00'
    skuName: 'Standard_LRS'
    tags: {
      Environment: 'Non-Prod'
      Role: 'DeploymentValidation'
    }
  }
}

module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.3' = {
  name: '${uniqueString(deployment().name, 'uksouth')}-dfs-pvdnszone'
  params: {
    name: privateDnsZoneName
    location: 'global'
  }
}
