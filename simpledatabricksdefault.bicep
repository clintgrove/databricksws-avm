

// module workspace 'br/public:avm/res/databricks/workspace:0.3.0' = {

//   name: 'deafultdbr'
//   params: {
//     location: 'uksouth'
//     name: 'deafultdbr'
//   }

// }

resource df2 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: 'defaultadf3424'
  location: 'uksouth'
}

resource ir2 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  parent: df2
  name: 'IR2mvn2'
  properties: {
    type: 'Managed'
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
      }
    }
  }
}


module datafactory 'br/public:avm/res/data-factory/factory:0.3.3' = {
  name: 'deploy_a_defaultadf'
  params: {
    location: 'uksouth'
    name: 'defaultadf2323'
  integrationRuntimes: [
    {
      managedVirtualNetworkName: 'default'
      name: 'IR2mvn2'
      type: 'Managed'
      typeProperties: {
        computeProperties: {
          location: 'AutoResolve'
       }
      }
     }
    ]
  }

}
