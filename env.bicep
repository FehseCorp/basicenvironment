targetScope = 'subscription'

param adminusername string='azureadmin'
@secure()
param adminpassword string
param dcIPaddress string = '10.0.3.4'

var location = 'eastus'
var hubrgname = 'hub-rg'
var spokergname = 'spoke-rg'
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

module spokerg '../bicep-registry-modules/avm/res/resources/resource-group/main.bicep' = {
  name: spokergname
  params: {
    location: location
    name: spokergname
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
  scope: resourceGroup(spokergname)
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
  scope: resourceGroup(spokergname)
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
// DCNew
module dcnew './modules/DC/dcnew.bicep' = {
  scope: resourceGroup(hubrgname)
  name: 'dcnew'
  dependsOn: [
    hubvnet
  ]
  params: {
    adminpassword: adminpassword
    adminusername: adminusername
    dcIPaddress: dcIPaddress
    dcrgname: hubrgname
    location: location
    subnetresourceid: hubvnet.outputs.subnetResourceIds[2]
    domainName: 'contoso.com'

  }
}

// DC
// module DC './modules/DC/dc.bicep' = {
//   scope: resourceGroup(hubrgname)
//   name: 'dc'
//   dependsOn: [
//     hubvnet
//   ]
//   params: {
//     adminPassword: adminpassword
//     adminUsername: adminusername
//     domainName: 'contoso.com'
//     adNicIPAddress: dcIPaddress
//     adSubnetAddressPrefix: adSubnetAddressPrefix
//     adSubnetName: adSubnetName
//     virtualNetworkAddressRange: hubVnetAddressPrefix
//     virtualNetworkName: hubvnetname
//   }
// }

module hubvnetupdate '../bicep-registry-modules/avm/res/network/virtual-network/main.bicep' = {
  name: '${hubvnetname}-update'
  dependsOn: [
    dcnew
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
    dcnew
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
module WinServer '../bicep-registry-modules/avm/res/compute/virtual-machine/main.bicep' = {
  scope: resourceGroup(spokergname)
  name: 'WinServer01'
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
      name: 'osdisk-WinServer01'
      caching: 'ReadWrite'
      createOption: 'FromImage'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: spokevnet.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: 'win-nic-01'
      }
    ]
  }
}

module LxServer '../bicep-registry-modules/avm/res/compute/virtual-machine/main.bicep' = {
  scope: resourceGroup(spokergname)
  name: 'LxServer01'
  params: {
    osType: 'Linux'
    zone: 1
    adminPassword: adminpassword
    adminUsername: adminusername
    location: location
    imageReference: {
      publisher: 'canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
    vmSize: 'Standard_D2s_v3'
    name: 'LxServer01'
    osDisk: {
      name: 'osdisk-LxServer01'
      caching: 'ReadWrite'
      createOption: 'FromImage'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: spokevnet.outputs.subnetResourceIds[0]
          }
        ]
        nicSuffix: 'lx-nic-01'
      }
    ]
  }
}
