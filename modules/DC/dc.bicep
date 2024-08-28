@description('The name of the administrator account of the new VM and domain')
param adminUsername string

@description('The password for the administrator account of the new VM and domain')
@secure()
param adminPassword string

@description('The FQDN of the Active Directory Domain to be created')
param domainName string

@description('The version of Windows Server to use')
@allowed([
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2016-Datacenter'
  '2019-Datacenter'
  '2022-Datacenter'
])
param windowsserver string = '2022-Datacenter'
param adVMName string = 'DC01'
param adNicIPAddress string
param adSubnetAddressPrefix string
param virtualNetworkAddressRange string

@description('The location of resources, such as templates and DSC modules, that the template depends on')
param _artifactsLocation string = 'https://raw.githubusercontent.com/fehsecorp/scommi/master/'

@description('Auto-generated token to access _artifactsLocation')
@secure()
param _artifactsLocationSasToken string = ''
param  virtualNetworkName string
param adSubnetName string

//var storageAccountName = '${uniqueString(resourceGroup().id)}adsa'
var adNicName = 'adNic'

// resource storageAccount 'Microsoft.Storage/storageAccounts@2016-01-01' = {
//   name: storageAccountName
//   location: resourceGroup().location
//   sku: {
//     name: 'Standard_LRS'
//   }
//   kind: 'Storage'
//   properties: {}
// }

resource adNic 'Microsoft.Network/networkInterfaces@2016-03-30' = {
  name: adNicName
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: adNicIPAddress
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, adSubnetName)
          }
        }
      }
    ]
  }
}

resource adVM 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: adVMName
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: adVMName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsserver
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      dataDisks:[
        {
          name: 'dataDisk1'
          diskSizeGB: 128
          lun: 0
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: adNic.id
        }
      ]
    }
  }
}

resource adVMName_CreateADForest 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: adVM
  name: 'CreateADForest'
  location: resourceGroup().location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.19'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: '${_artifactsLocation}/DSC/CreateADPDC.zip${_artifactsLocationSasToken}'
      ConfigurationFunction: 'CreateADPDC.ps1\\CreateADPDC'
      Properties: {
        DomainName: domainName
        AdminCreds: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:AdminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminPassword
      }
    }
  }
}

module UpdateVNetDNS 'updatevnet.bicep' /*TODO: replace with correct path to [concat(parameters('_artifactsLocation'), '/nestedtemplates/vnet-with-dns-server.json', parameters('_artifactsLocationSasToken'))]*/ = {
  name: 'UpdateVNetDNS'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: adSubnetName
    subnetRange: adSubnetAddressPrefix
    DNSServerAddress: [
      adNicIPAddress
    ]
  }
  dependsOn: [
    adVMName_CreateADForest
  ]
}
