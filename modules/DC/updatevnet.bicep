@description('The name of the Virtual Network to Create')
param virtualNetworkName string

@description('The address range of the new VNET in CIDR format')
param virtualNetworkAddressRange string

@description('The name of the subnet created in the new VNET')
param subnetName string

@description('The address range of the subnet created in the new VNET')
param subnetRange string

@description('The DNS address(es) of the DNS Server(s) used by the VNET')
param DNSServerAddress array

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2016-03-30' = {
  name: virtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressRange
      ]
    }
    dhcpOptions: {
      dnsServers: DNSServerAddress
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetRange
        }
      }
    ]
  }
}
