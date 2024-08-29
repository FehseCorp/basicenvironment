targetScope = 'subscription'

param adminusername string
@secure()
param adminpassword string
param dcIPaddress string

var location = 'eastus'
var hubrgname = 'hub-rg'
var hubvnetname = 'hub-vnet'
var spokevnetname = 'spoke-vnet'
var adSubnetName = 'identity'
var adSubnetAddressPrefix = '10.0.3.0/24'
var hubVnetAddressPrefix = '10.0.0.0/16'

module hubrg '../bicep-registry-modules/avm/res/resources/resource-group/main.bicep' = {
  name: hubrgname
  params: {
    location: location
    name: hubrgname
  }
}

module hubvnet '../bicep-registry-modules/avm/res/network/virtual-network/main.bicep' = {
  name: hubvnetname
  scope: resourceGroup('hub-rg')
  params: {
    location: location   
    addressPrefixes: [
      hubVnetAddressPrefix
    ]
    name: hubvnetname
    subnets: [
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.1.0/24'
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.0.2.0/24'
      }
      {
        name: adSubnetName
        addressPrefix: adSubnetAddressPrefix
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.4.0/24'
      }
    ]
  }
}
module spokevnet '../bicep-registry-modules/avm/res/network/virtual-network/main.bicep' = {
  scope: resourceGroup(hubrgname)
  name: spokevnetname
  params: {
    location: location   
    addressPrefixes: ['10.1.0.0/16']
    name: spokevnetname
    subnets: [
      {
        name: 'Servers'
        addressPrefix: '10.1.1.0/24'
      }
    ]
  }
}

module peerings1 '../bicep-registry-modules/avm/res/network/virtual-network/virtual-network-peering/main.bicep' = {
  scope: resourceGroup(hubrgname)
  name: 'hub-to-spoke'
  params: {
    localVnetName: hubvnetname
    remoteVirtualNetworkId: spokevnet.outputs.resourceId
    allowGatewayTransit: true
    doNotVerifyRemoteGateways: true
  }
}

module peerings2 '../bicep-registry-modules/avm/res/network/virtual-network/virtual-network-peering/main.bicep' = {
  scope: resourceGroup(hubrgname)
  name: 'spoke-to-hub'
  params: {
    localVnetName: spokevnetname
    remoteVirtualNetworkId: hubvnet.outputs.resourceId
    allowGatewayTransit: false
    doNotVerifyRemoteGateways: true
  }
}
// Bastion
module bastion '../bicep-registry-modules/avm/res/network/bastion-host/main.bicep' = {
  scope: resourceGroup(hubrgname)
  name: 'bastion'
  params: {
    name: 'bastion'
    location: location
    virtualNetworkResourceId: hubvnet.outputs.resourceId
  }
}
// DC
module DC './modules/DC/dc.bicep' = {
  scope: resourceGroup(hubrgname)
  name: 'dc'
  dependsOn: [
    hubvnet
  ]
  params: {
    adminPassword: adminpassword
    adminUsername: adminusername
    domainName: 'contoso.com'
    adNicIPAddress: dcIPaddress
    adSubnetAddressPrefix: adSubnetAddressPrefix
    adSubnetName: adSubnetName
    virtualNetworkAddressRange: hubVnetAddressPrefix
    virtualNetworkName: hubvnetname
  }
}

module hubvnetupdate '../bicep-registry-modules/avm/res/network/virtual-network/main.bicep' = {
  name: '${hubvnetname}-update'
  dependsOn: [
    DC
  ]
  scope: resourceGroup('hub-rg')
  params: {
    location: location   
    addressPrefixes: [
      hubVnetAddressPrefix
    ]
    name: hubvnetname
    dnsServers: [
      dcIPaddress
    ]
    subnets: [
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.0.1.0/24'
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.0.2.0/24'
      }
      {
        name: adSubnetName
        addressPrefix: adSubnetAddressPrefix
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.0.4.0/24'
      }
    ]
  }
}
module spokevnetupdate '../bicep-registry-modules/avm/res/network/virtual-network/main.bicep' = {
  scope: resourceGroup(hubrgname)
  dependsOn: [
    DC
  ]
  name: '${spokevnetname}-update'
  params: {
    location: location   
    addressPrefixes: ['10.1.0.0/16']
    dnsServers: [
      dcIPaddress
    ]
    name: spokevnetname
    subnets: [
      {
        name: 'Servers'
        addressPrefix: '10.1.1.0/24'
      }
    ]
  }
}
//Windows Server
module windowsServer '../bicep-registry-modules/avm/res/compute/virtual-machine/main.bicep' = {
  scope: resourceGroup(hubrgname)
  name: 'windowsServer01'
  params: {
    osType: 'Windows'
    zone: 1
    adminPassword: adminpassword
    adminUsername: adminusername
    location: location
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2019-Datacenter'
      version: 'latest'
    }
    vmSize: 'Standard_D2s_v3'
    name: 'WinServer01'
    osDisk: {
      name: 'osdisk'
      caching: 'ReadWrite'
      createOption: 'FromImage'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    dataDisks: [
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
        name: 'winsrvnic1'
        properties: {
          ipConfigurations: [
            {
              name: 'ipconfig1'
              properties: {
                privateIPAllocationMethod: 'Dynamic'
                subnet: {
                  id: spokevnet.outputs.resourceId
                }
              }
            }
          ]
        }
      }
    ]
  }
}
module LxServer '../bicep-registry-modules/avm/res/compute/virtual-machine/main.bicep' = {
  scope: resourceGroup(hubrgname)
  name: 'LxServer01'
  params: {
    osType: 'Linux'
    zone: 1
    adminPassword: adminpassword
    adminUsername: adminusername
    location: location
    imageReference: {
      publisher: 'Canonical'
      offer: 'UbuntuServer'
      sku: '22.04-LTS'
      version: 'latest'
    }
    vmSize: 'Standard_D2s_v3'
    name: 'WinServer01'
    osDisk: {
      name: 'osdisk'
      caching: 'ReadWrite'
      createOption: 'FromImage'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    dataDisks: [
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
        name: 'lxservernic1'
        properties: {
          ipConfigurations: [
            {
              name: 'ipconfig1'
              properties: {
                privateIPAllocationMethod: 'Dynamic'
                subnet: {
                  id: spokevnet.outputs.subnetResourceIds[0]
                }
              }
            }
          ]
        }
      }
    ]
  }
}
