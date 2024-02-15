module storageAccount 'br/public:avm/res/storage/storage-account:0.6.0' = {
  dependsOn: [
    privateDnsZone
  ]
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
          '/subscriptions/3ab181cd-675b-4b59-a974-db22e4177daf/resourceGroups/dbr-private-rg-1/providers/Microsoft.Network/privateDnsZones/newdnszone-stg-dfs'
        ]
        service: 'dfs'
        subnetResourceId:  resourceId('Microsoft.Network/virtualNetworks/subnets', 'dwwaf-vnet', 'default')
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

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'newdnszone-stg-dfs'
  location: 'global'
}

resource pe_dns_vnetwrk_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'newdnszone-stg-dfs-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'dwwaf-vnet', 'default')
    }
  }
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  name: 'stg-dfs-private-endpoint/mydnsgroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1dfs'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.3.3' = {
//   dependsOn: [
//     storageAccount
//   ]
//   name: '${uniqueString(deployment().name, 'uksouth')}-dbr-privateendpoint-dfs'
//   params: {
//     name: 'stg-dfs-private-endpoint'
//     location: 'uksouth'
//     subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', 'dwwaf-vnet', 'default')
//     privateDnsZoneGroupName: 'config-dfs'
//     privateLinkServiceConnections: [
//       {
//         name: 'stg-dfs-private-endpoint'
//         properties: {
//           groupIds: [
//             'dfs'
//           ]
//           privateLinkServiceId: storageAccount.outputs.resourceId
//         }
//       }
//     ]
//   }
// }

// module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.3' = {

//   name: '${uniqueString(deployment().name, 'uksouth')}-dfs-pvdnszone'
//   params: {
//     name: 'privatelink.dfs.core.net'
//     location: 'global'
//     virtualNetworkLinks: [
//       {
//         registrationEnabled: true
//         virtualNetworkResourceId: resourceId('Microsoft.Network/virtualNetworks/', 'dwwaf-vnet')
//       }
//     ]
//   }
// }
