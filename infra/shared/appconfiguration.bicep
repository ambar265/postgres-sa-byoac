param name string
param location string = resourceGroup().location
param tags object = {}
param keyVaultName string = ''

@description('The principal ID of the user to assign the App Configuration Data Owner role to')
param principalId string = ''

param principalType string = 'User'

@allowed([
  'Enabled', 'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@allowed([
  'Standard', 'Free'
])
param SkuName string = 'Standard'


resource appConfig 'Microsoft.AppConfiguration/configurationStores@2024-05-01' = {
  name: name
  location: location
  sku: {
    name: SkuName
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    dataPlaneProxy: {
      authenticationMode: 'Pass-through'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }

  tags: tags
}

resource keyvault 'Microsoft.KeyVault/vaults@2023-02-01' existing = if (!empty(keyVaultName)) {
  name: keyVaultName
}

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = if (!empty(keyVaultName)) {
  parent: keyvault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        objectId: appConfig.identity.principalId
        permissions: {
          secrets: ['get', 'list']
        }
        tenantId: subscription().tenantId
      }
    ]
  }
}

// Assign the App Configuration Data Owner role to principalId passed in for the user running the deployment
resource appConfigRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (!empty(principalId)) {
  name: guid(subscription().id, resourceGroup().id, principalId, 'AppConfigDataOwner')
  scope: appConfig
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b') // App Configuration Data Owner role
    principalId: principalId
    principalType: principalType
  }
}

output name string = appConfig.name
output endpoint string = appConfig.properties.endpoint
