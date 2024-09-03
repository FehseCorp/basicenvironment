//Windows Server
param dcrgname string
param adminusername string='azureadmin'
@secure()
param adminpassword string
param dcIPaddress string
param location string
param subnetresourceid string

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

@description('The location of resources, such as templates and DSC modules, that the template depends on')
param _artifactsLocation string = 'https://github.com/FehseCorp/basicenvironment/raw/main/modules/DC'

@description('Auto-generated token to access _artifactsLocation')
@secure()
param _artifactsLocationSasToken string = ''

var dcname = 'DC01'

module dc '../../../bicep-registry-modules/avm/res/compute/virtual-machine/main.bicep' = {
  scope: resourceGroup(dcrgname)
  name: 'DC01'
  params: {
    osType: 'Windows'
    zone: 1
    adminPassword: adminpassword
    adminUsername: adminusername
    location: location
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: windowsserver
      version: 'latest'
    }
    vmSize: 'Standard_D2s_v3'
    name: dcname
    osDisk: {
      name: 'osdisk-${dcname}'
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
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: subnetresourceid
            privateIPAllocationMethod: 'Static'
            privateIPAddress: dcIPaddress
          }
        ]
        nicSuffix: '${dcname}-nic-01'
      }
    ]
    extensionDSCConfig: {
      enabled: true
      settings: {
        wmfVersion: 'latest'
        configuration: {
          url: '${_artifactsLocation}/DSC/CreateADPDC.zip${_artifactsLocationSasToken}'
          script: 'CreateADPDC.ps1'
          function: 'CreateADPDC'
        }
        configurationArguments: {
          DomainName: domainName
          AdminCreds: {
            UserName: adminusername
            Password: 'PrivateSettingsRef:AdminPassword'
          }
        }

      }
      protectedSettings: {
        Items: {
          AdminPassword: adminpassword
        }
      }
    }
  }
}



// resource adVMName_CreateADForest 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
//   parent: dc.outputs.resourceId
//   name: 'CreateADForest'
//   location: resourceGroup().location
//   properties: {
//     publisher: 'Microsoft.Powershell'
//     type: 'DSC'
//     typeHandlerVersion: '2.77'
//     autoUpgradeMinorVersion: true
//     settings: {
//       ModulesUrl: '${_artifactsLocation}/DSC/CreateADPDC.zip${_artifactsLocationSasToken}'
//       ConfigurationFunction: 'CreateADPDC.ps1\\CreateADPDC'
//       Properties: {
//         DomainName: domainName
//         AdminCreds: {
//           UserName: adminUsername
//           Password: 'PrivateSettingsRef:AdminPassword'
//         }
//       }
//     }
//     protectedSettings: {
//       Items: {
//         AdminPassword: adminPassword
//       }
//     }
//   }
// }

