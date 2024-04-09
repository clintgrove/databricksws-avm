targetScope='subscription'

param RGroupName string
param location string

resource newRG 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: RGroupName
  location: location
}
