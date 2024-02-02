module workspace 'br/public:avm/res/databricks/workspace:v1' = {
  name: '${uniqueString(deployment().name, resourceLocation)}-test-dwmin'
  params: {
    // Required parameters
    name: 'dwmin001'
    // Non-required parameters
    location: 'northeurope'
  }
}
