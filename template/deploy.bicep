//
// parameters
//
@description('SwitchBot Token')
@secure()
param switchbotToken string

@description('SwitchBot Secret')
@secure()
param switchbotSecret string

@description('azure resource postfix string')
param resourcePostfix string = 'ktkr'

@description('target azure region')
param location string = resourceGroup().location

@description('The workspace data retention in days')
param omsRetentionInDays int = 730

//
// variables
//
var omsName = 'log-${resourcePostfix}'
var customTableName = 'switchbot_CL'
var dceName = 'dce-${resourcePostfix}'
var dcrName = 'dcr-${resourcePostfix}'
var appinsName = 'appins-${resourcePostfix}'
var planName = 'plan-${resourcePostfix}'
var funcName = 'func-${resourcePostfix}-${uniqueString(resourceGroup().id)}'
var funcStName = 'st${take(resourcePostfix, 9)}${uniqueString(resourceGroup().id)}'

var funcAppSettings = [
  // Azure Functions basic settings
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: 'python'
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsights.properties.InstrumentationKey
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsights.properties.ConnectionString
  }
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: '~4'
  }
  {
    name: 'AzureWebJobsStorage'
    value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(funcStorage.id, funcStorage.apiVersion).keys[0].value}'
  }
  {
    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
    value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(funcStorage.id, funcStorage.apiVersion).keys[0].value}'
  }
  {
    name: 'WEBSITE_CONTENTSHARE'
    value: '${funcStName}000'
  }
  // SitchBot function settings
  {
    name: 'AZURE_MONITOR_ENDPOINT'
    value: dataCollectionEndpoint.properties.logsIngestion.endpoint
  }
  {
    name: 'AZURE_MONITOR_IMMUTABLEID'
    value: dataCollectionRule.properties.immutableId
  }
  {
    name: 'AZURE_MONITOR_STREAMNAME'
    value: 'Custom-${customTableName}'
  }
  {
    name: 'SWITCHBOT_TOKEN'
    value: switchbotToken
  }
  {
    name: 'SWITCHBOT_SECRET'
    value: switchbotSecret
  }
]

//
// resources
//
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: omsName
  location: location
  properties: {
    retentionInDays: omsRetentionInDays
    sku: {
      name: 'PerGB2018'
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource customTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  name: customTableName
  parent: logAnalyticsWorkspace
  properties: {
    plan: 'Analytics'
    schema: {
      name: customTableName
      columns: [
        {
          name: 'TimeGenerated'
          type: 'dateTime'
        }
        {
          name: 'deviceName'
          type: 'string'
        }
        {
          name: 'deviceId'
          type: 'string'
        }
        {
          name: 'body'
          type: 'dynamic'
        }
      ]
    }
  }
}

resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2021-09-01-preview' = {
  name: dceName
  location: location
  properties: {
    logsIngestion: {}
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2021-09-01-preview' = {
  name: dcrName
  location: location
  properties: {
    dataCollectionEndpointId: dataCollectionEndpoint.id
    streamDeclarations: {
      'Custom-${customTableName}': {
        columns: [
          {
            name: 'body'
            type: 'dynamic'
          }
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'deviceName'
            type: 'string'
          }
          {
            name: 'deviceId'
            type: 'string'
          }
        ]
      }

    }
    dataSources: {
    }
    destinations: {
      logAnalytics: [
        {
          name: logAnalyticsWorkspace.name
          workspaceResourceId: logAnalyticsWorkspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-${customTableName}'
        ]
        destinations: [
          logAnalyticsWorkspace.name
        ]
        transformKql: 'source'
        outputStream: 'Custom-${customTableName}'
      }

    ]
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appinsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: planName
  location: location
  kind: 'functionapp'
  properties: {
    elasticScaleEnabled: false
    reserved: true
    zoneRedundant: false
  }
  sku: {
    family: 'Y'
    tier: 'Dynamic'
    name: 'Y1'
    size: 'Y1'
    capacity: 0
  }
}

resource funcStorage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: funcStName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource functions 'Microsoft.Web/sites@2022-03-01' = {
  name: funcName
  kind: 'functionapp,linux'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    siteConfig: {
      appSettings: funcAppSettings
      linuxFxVersion: 'PYTHON|3.9'
      functionAppScaleLimit: 200
      numberOfWorkers: 1
      minimumElasticInstanceCount: 0
    }
    serverFarmId: appServicePlan.id
  }
}

resource monitoringMetricsPublisherRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '3913510d-42f4-4e42-8a64-420c390055eb'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: dataCollectionRule
  name: guid(subscription().id, dataCollectionRule.id, monitoringMetricsPublisherRoleDefinition.id)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRoleDefinition.id
    principalId: functions.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
