param name string
param location string = resourceGroup().location

var acrPullRole = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

// Existing resources ---------------------------------------------------------
resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' existing = {
  name: 'acr${name}'
}

resource aca_env 'Microsoft.App/managedEnvironments@2022-10-01' existing = {
  name: 'acaenv${name}'
}

resource sb_ns 'Microsoft.ServiceBus/namespaces@2021-11-01' existing = {
  name: 'sbns-${name}'
}

resource sbSharedKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-11-01' existing = {
  name: 'subscriber'
  parent: sb_ns
}

// Subscriber ------------------------------------------------------------------
resource subscriber_uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-subscriber'
  location: location
}

resource subscriber_uaiRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, subscriber_uai.id, acrPullRole)
  properties: {
    roleDefinitionId: acrPullRole
    principalId: subscriber_uai.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource subscriber 'Microsoft.App/containerApps@2022-10-01' = {
  name: 'subscriber'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${subscriber_uai.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: aca_env.id
    configuration: {
      activeRevisionsMode: 'single'
      dapr: {
        enabled: true
        appId: 'subscriber'
        appPort: 5000
      }
      registries: [
        {
          identity: subscriber_uai.id
          server: acr.properties.loginServer
        }
      ]
      secrets: [
        {
          name: 'sb-connection-string'
          value: sbSharedKey.listKeys().primaryConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${acr.name}.azurecr.io/subscribers/subscriber:0.1'
          name: 'subscriber'
          resources:{
            cpu: json('.25')
            memory: '.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 10
        rules: [
          {
            name: 'sb-scale-rule'
            custom: {
              type: 'azure-servicebus'
              auth: [
                {
                  secretRef: 'sb-connection-string'
                  triggerParameter: 'connection'
                }
              ]
              metadata: {
                topicName: 'updates'
                subscriptionName: 'subscriber'
                queueLength: '10'
              }
            }
          }
        ]
      }
    }
  }
}
