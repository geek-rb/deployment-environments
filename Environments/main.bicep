@description('The location of all resources')
param location string = resourceGroup().location

@description('The ID of the Hub vNet')
param vNetHubId string = 'id....'

@description('The vnet spoke prefix')
@allowed([
  '10.10.200.0/29'
  '10.10.200.8/29'
  '10.10.200.16/29'
  '10.10.200.24/29'
  '10.10.200.32/29'
  '10.10.200.40/29'
])
param vNetSpokePrefix string = '10.10.200.0/29'

@description('The ip address of the next hop')
param nextHopIpAddress string

@description('The size of the Virtual Machine')
@allowed([
  'Standard_B1s'
  'Standard_D2s_v3'
])
param vmSize string = 'Standard_B1s'

@description('The username for the Virtual Machine')
param adminUsername string = 'admin'

@description('The password for the Virtual Machine')
@secure()
param adminPassword string

// Network variables
var vnetSpokeName = 'vnet-dev-01'
var subnetName = 'sub-dev-01'

// VM variables
var vmName = 'vm-dev-01'


resource def_udr 'Microsoft.Network/routeTables@2023-05-01' = {
  name: 'def-udr-${vnetSpokeName}'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [{
      name: 'def-route'
      properties: {
        addressPrefix: '0.0.0.0/0'
        hasBgpOverride: true
        nextHopIpAddress: nextHopIpAddress
        nextHopType: 'VirtualAppliance'
      }
    }]
  }
}

// vnet + peering + udr
resource vNetSpoke 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetSpokeName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetSpokePrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: vNetSpokePrefix
          routeTable: {
            id: def_udr.id
          }
        }
      }
    ]
    virtualNetworkPeerings: [
      {
        name: 'peering-${vnetSpokeName}-to-hub'
        properties: {
          allowVirtualNetworkAccess: true
          allowForwardedTraffic: false
          allowGatewayTransit: false
          useRemoteGateways: false
          remoteVirtualNetwork: {
            id: vNetHubId
          }
        }
      }
    ]
  }
}

//vnet peering
// resource vNetSpokeHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
//   parent: vNetSpoke
//   name: 'peering-${vnetSpokeName}-to-hub'
//   properties: {
//     allowVirtualNetworkAccess: true
//     allowForwardedTraffic: false
//     allowGatewayTransit: false
//     useRemoteGateways: false
//     remoteVirtualNetwork: {
//       id: vNetHubId
//     }
//   }
// }


// VM
resource vmNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmName}-nic-01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vNetSpoke.id}/subnets/${subnetName}'
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-os-01'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}
