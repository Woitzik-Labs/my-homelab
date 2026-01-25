locals {
  vlans = {
    "10" = { 
      name        = "vlan10"
      address     = "10.10.0.1/24"
      network     = "10.10.0.0/24"
      pool_range  = "10.10.0.10-10.10.0.254"
      dns_servers = ["10.20.0.3", "1.1.1.1"]
      tagged      = ["bridge"]
      untagged    = ["ether2"]
    }
    "20" = { 
      name        = "vlan20"
      address     = "10.20.0.1/24"
      network     = "10.20.0.0/24"
      pool_range  = "10.20.0.10-10.20.0.254"
      dns_servers = ["10.20.0.3", "1.1.1.1"]
      tagged      = ["bridge", "ether7"]
      untagged    = ["ether5", "ether6"]
    }
    "30" = { 
      name        = "vlan30"
      address     = "10.30.0.1/24"
      network     = "10.30.0.0/24"
      pool_range  = "10.30.0.10-10.30.0.254"
      dns_servers = ["10.20.0.3", "1.1.1.1"]
      tagged      = ["bridge", "ether7"]
      untagged    = ["ether8"]
    }
  }
}

resource "routeros_ip_dhcp_client" "wan" {
  interface = "ether1"
}

# --- VLAN INTERFACES ---
resource "routeros_interface_vlan" "vlan" {
  for_each  = local.vlans
  name      = each.value.name
  vlan_id   = each.key
  interface = routeros_interface_bridge.bridge.name
}

# --- IP ADDRESSES ---
resource "routeros_ip_address" "vlan_ips" {
  for_each  = local.vlans
  address   = each.value.address
  interface = routeros_interface_vlan.vlan[each.key].name
}

# --- DHCP POOLS ---
resource "routeros_ip_pool" "vlan_pools" {
  for_each = local.vlans
  name     = "${each.value.name}_pool"
  ranges   = [each.value.pool_range]
}

# --- DHCP SERVER ---
resource "routeros_ip_dhcp_server" "vlan_dhcps" {
  for_each     = local.vlans
  interface    = routeros_interface_vlan.vlan[each.key].name
  name         = "${each.value.name}_dhcp"
  address_pool = routeros_ip_pool.vlan_pools[each.key].name
  disabled     = false
}

# --- DHCP NETWORKS ---
resource "routeros_ip_dhcp_server_network" "vlan_networks" {
  for_each   = local.vlans
  address    = each.value.network
  gateway    = split("/", each.value.address)[0]
  dns_server = each.value.dns_servers
}

# --- INTERFACE LIST MEMBERS ---
resource "routeros_interface_list_member" "lan_vlan_members" {
  for_each  = local.vlans
  interface = routeros_interface_vlan.vlan[each.key].name
  list      = routeros_interface_list.lan.name
}

# --- BRIDGE VLAN SETTINGS ---
resource "routeros_interface_bridge_vlan" "vlan_config" {
  for_each = local.vlans
  bridge   = routeros_interface_bridge.bridge.name
  vlan_ids = [each.key]
  tagged   = each.value.tagged
  untagged = each.value.untagged
}