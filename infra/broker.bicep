targetScope = 'resourceGroup'

@description('Name of team responsible for broker')
param team string = 'platform'

@description('Location of the resources')
param location string = resourceGroup().location

@description('Event hub namespace: Name of the namespace')
param eventhubNamespaceName string = 'dv-events003-ehns-eun-dgrf'

@description('Event hub namespace: Sku name')
param eventSkuName string = 'Standard'

@description('Event hub namespace: Tier')
param eventSkuTier string = 'Standard'

@description('Event hub namespace: Number of throughput units')
param eventCapacity int = 1

@description('Event hub namespace: Maximum number of throughput units')
param eventMaxCapacity int = 20

@description('Storage Account: The SKU for the storage')
param storageSkuName string = 'Standard_LRS'

@description('Storage Account: Days until data is deleted')
param storageDaysToDeleteData int = 7

@description('Storage Account: Days until data is moved to archive tier')
param storageDaysToArchiveData int = 5

@description('Storage Account: Days until data is moved to cool tier')
param storageDaysToCoolData int = 3

var storageAccountName = replace(replace(eventhubNamespaceName,'-',''),'sa','')
var storageDaysToRestoreFiles = storageDaysToCoolData - 1
var storageDaysToRestoreContainer = storageDaysToCoolData

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: eventhubNamespaceName
  location: location
  sku: {
    name: eventSkuName
    tier: eventSkuTier
    capacity: eventCapacity
  }
  properties: {
    zoneRedundant: true
    isAutoInflateEnabled: true
    kafkaEnabled: true
    maximumThroughputUnits: eventMaxCapacity
  }
  tags:  {
    'team' : team
  }
}

resource eventstorage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageSkuName
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
  tags:  {
    'team' : team
  }
}

resource lifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2019-04-01' = {
  name: 'default'
  parent: eventstorage
  properties: {
    policy: {
      rules: [
        {
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: storageDaysToDeleteData
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: storageDaysToArchiveData
                }
                tierToCool: {
                  daysAfterModificationGreaterThan: storageDaysToCoolData
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
            }
          }
          enabled: true
          name: 'eventsLifecycle'
          type: 'Lifecycle'
        }
      ]
    }
  }
}

resource blobservice 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  name: 'default'
  parent: eventstorage
  properties: {
    automaticSnapshotPolicyEnabled: true
    changeFeed: {
      enabled: true
      retentionInDays: storageDaysToRestoreContainer
    }
    containerDeleteRetentionPolicy: {
      days: storageDaysToDeleteData
      enabled: true
    }
    deleteRetentionPolicy: {
      days: storageDaysToDeleteData
      enabled: true
    }
    isVersioningEnabled: true
    restorePolicy: {
      days: storageDaysToRestoreFiles
      enabled: true
    }
  }
}
