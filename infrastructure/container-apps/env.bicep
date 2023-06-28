param name string
param location string = resourceGroup().location

resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: 'acr${name}'
  location: location
  sku: {
    name: 'Basic'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'stoacc${name}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource systemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: 'eg-sto-updates-${name}'
  location: location
  properties: {
    source: storageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource eventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = {
  parent: systemTopic
  name: 'sb-sub-aca'
  properties: {
    destination: {
      endpointType: 'ServiceBusTopic'
      properties: {
        resourceId: sb_topic.id
      }
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}

resource sb_ns 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: 'sbns-${name}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource sb_topic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = {
  name: 'updates'
  parent: sb_ns
  properties: {
    enablePartitioning: true
  }

  resource sb_subscription 'subscriptions' = {
    name: 'subscriber'
    properties: {
      deadLetteringOnFilterEvaluationExceptions: true
      deadLetteringOnMessageExpiration: true
      maxDeliveryCount: 10
    }
  }
}

resource sbSharedKey 'Microsoft.ServiceBus/namespaces/authorizationRules@2021-11-01' = {
  name: 'subscriber'
  parent: sb_ns
  properties: {
    rights: [ 'Manage', 'Listen', 'Send' ]
  }
}

resource loganalytics_workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'logs${name}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appinsights${name}'
  kind: 'web'
  location: location
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: loganalytics_workspace.id
    //SamplingPercentage: 4
  }
}

resource aca_env 'Microsoft.App/managedEnvironments@2023-04-01-preview' = {
  name: 'acaenv${name}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: loganalytics_workspace.properties.customerId
        sharedKey: loganalytics_workspace.listKeys().primarySharedKey
      }
    }
    daprAIInstrumentationKey: appinsights.properties.InstrumentationKey
    daprAIConnectionString: appinsights.properties.ConnectionString
  }
}


resource pubsub_component 'Microsoft.App/managedEnvironments/daprComponents@2023-04-01-preview' = {
  name: 'pubsub'
  parent: aca_env
  properties: {
    componentType: 'pubsub.azure.servicebus.topics'
    version: 'v1'
    initTimeout: '30s'
    metadata: [
      {
        name: 'connectionString'
        value: sbSharedKey.listKeys().primaryConnectionString
      }
      {
        name: 'maxActiveMessages'
        value: '10'
      }
    ]
    scopes: [
      'subscriber'
    ]
  }
}
