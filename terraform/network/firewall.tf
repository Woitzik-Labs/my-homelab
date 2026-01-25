# ===============================================
# Interface Lists
# ===============================================

resource "routeros_interface_list" "wan" {
  name = "WAN"
}

resource "routeros_interface_list" "lan" {
  name = "LAN"
}

resource "routeros_interface_list_member" "wan_ether1" {
  interface = "ether1"
  list      = routeros_interface_list.wan.name
}

resource "routeros_interface_list_member" "lan_bridge" {
  interface = routeros_interface_bridge.bridge.name
  list      = routeros_interface_list.lan.name
}

# ===============================================
# Firewall Address Lists
# ===============================================

resource "routeros_ip_firewall_addr_list" "internal_networks_wlan" {
  list    = "Internal_Networks"
  address = "192.168.178.0/24"
}

resource "routeros_ip_firewall_addr_list" "internal_net_10" {
  list    = routeros_ip_firewall_addr_list.internal_networks_wlan.list
  address = "10.10.0.0/24"
}

resource "routeros_ip_firewall_addr_list" "internal_net_20" {
  list    = routeros_ip_firewall_addr_list.internal_networks_wlan.list
  address = "10.20.0.0/24"
}

resource "routeros_ip_firewall_addr_list" "dmz_network" {
  list    = "DMZ_Network"
  address = "10.30.0.0/24"
}

resource "routeros_ip_firewall_addr_list" "mgmt_devices" {
  list    = "Mgmt_Devices"
  address = "10.10.0.0/24"
}

resource "routeros_ip_firewall_addr_list" "proxy_backends" {
  for_each = { for k, v in {
    "adguard"     = "10.20.0.3"
    "proxmox"     = "10.20.0.10"
    "jellyfin"    = "10.20.0.101"
    "vaultwarden" = "10.20.0.102"
    "kuma"        = "10.20.0.104"
    "homepage"    = "10.20.0.200"
  } : k => v }

  list    = "Reverse_Proxy_Targets"
  address = each.value
}

# ===============================================
# Firewall Filter - INPUT Chain
# ===============================================

resource "routeros_ip_firewall_filter" "drop_blacklisted" {
  action   = "drop"
  chain    = "input"
  src_address_list = "Blacklist"
  comment  = "Drop traffic from dynamically blacklisted IPs"
  place_before = routeros_ip_firewall_filter.accept_established_related_untracked.id
}

resource "routeros_ip_firewall_filter" "accept_established_related_untracked" {
  action           = "accept"
  chain            = "input"
  connection_state = "established,related,untracked"
  place_before     = routeros_ip_firewall_filter.drop_invalid.id
}

resource "routeros_ip_firewall_filter" "drop_invalid" {
  action           = "drop"
  chain            = "input"
  connection_state = "invalid"
  place_before     = routeros_ip_firewall_filter.accept_icmp.id
}

resource "routeros_ip_firewall_filter" "accept_icmp" {
  action   = "accept"
  chain    = "input"
  protocol = "icmp"
  limit    = "5,5"
  place_before = routeros_ip_firewall_filter.accept_management_from_pc.id
}

resource "routeros_ip_firewall_filter" "accept_management_from_pc" {
  action           = "accept"
  chain            = "input"
  src_address_list = routeros_ip_firewall_addr_list.mgmt_devices.list
  place_before     = routeros_ip_firewall_filter.drop_all_input.id
}

resource "routeros_ip_firewall_filter" "drop_all_input" {
  action = "drop"
  chain  = "input"
}

# ===============================================
# Firewall Filter - FORWARD Chain
# ===============================================

resource "routeros_ip_firewall_mangle" "mss_clamp" {
  action            = "change-mss"
  chain             = "forward"
  new_mss           = "clamp-to-pmtu"
  out_interface_list = "WAN"
  protocol          = "tcp"
  tcp_flags         = "syn"
}

resource "routeros_ip_firewall_filter" "drop_invalid_forward" {
  action           = "drop"
  chain            = "forward"
  connection_state = "invalid"
  place_before     = routeros_ip_firewall_filter.accept_established_related_untracked_forward.id
}

resource "routeros_ip_firewall_filter" "accept_established_related_untracked_forward" {
  action           = "accept"
  chain            = "forward"
  connection_state = "established,related,untracked"
  place_before     = routeros_ip_firewall_filter.fasttrack_connection.id
}

resource "routeros_ip_firewall_filter" "fasttrack_connection" {
  action           = "fasttrack-connection"
  chain            = "forward"
  connection_state = "established,related"
  hw_offload       = "true"
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_adguard_dns_tcp.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_adguard_dns_tcp" {
  action           = "accept"
  chain            = "forward"
  comment          = "DMZ to Prod: AdGuard DNS TCP"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address      = "10.20.0.3"
  protocol         = "tcp"
  dst_port         = "53"
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_adguard_dns_udp.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_adguard_dns_udp" {
  action           = "accept"
  chain            = "forward"
  comment          = "DMZ to Prod: AdGuard DNS UDP"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address      = "10.20.0.3"
  protocol         = "udp"
  dst_port         = "53"
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_backends.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_backends" {
  action           = "accept"
  chain            = "forward"
  protocol         = "tcp"
  comment          = "DMZ -> PROD: All defined Reverse Proxy Backends"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address_list = "Reverse_Proxy_Targets"
  dst_port = "80,443,3001,5900-5999,7878,8000,8006,8080,8096,8989,32000"
  place_before     = routeros_ip_firewall_filter.drop_dmz_to_internal.id
}

resource "routeros_ip_firewall_filter" "drop_dmz_to_internal" {
  action           = "drop"
  chain            = "forward"
  comment          = "Zero Trust: Block ALL other DMZ -> Internal Traffic"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address_list = routeros_ip_firewall_addr_list.internal_networks_wlan.list
  place_before     = routeros_ip_firewall_filter.allow_pc_to_internet.id
}

resource "routeros_ip_firewall_filter" "allow_pc_to_internet" {
  action             = "accept"
  chain              = "forward"
  comment            = "PC -> Internet"
  src_address        = "10.10.0.0/24"
  out_interface_list = "WAN"
  place_before       = routeros_ip_firewall_filter.allow_vlan20_to_internet.id
}

resource "routeros_ip_firewall_filter" "allow_vlan20_to_internet" {
  action             = "accept"
  chain              = "forward"
  comment            = "PROD -> Internet"
  in_interface_list  = "LAN"
  src_address        = "10.20.0.0/24"
  out_interface_list = "WAN"
  place_before       = routeros_ip_firewall_filter.allow_vlan30_to_internet.id
}

resource "routeros_ip_firewall_filter" "allow_vlan30_to_internet" {
  action             = "accept"
  chain              = "forward"
  comment            = "DMZ -> Internet"
  in_interface_list  = "LAN"
  src_address        = "10.30.0.0/24"
  out_interface_list = "WAN"
  place_before       = routeros_ip_firewall_filter.allow_pc_to_prod.id
}

resource "routeros_ip_firewall_filter" "allow_pc_to_prod" {
  action       = "accept"
  chain        = "forward"
  comment      = "PC -> PROD (Client-Zugriff)"
  src_address  = "10.10.0.0/24"
  dst_address  = "10.20.0.0/24"
  place_before = routeros_ip_firewall_filter.allow_pc_to_dmz.id
}

resource "routeros_ip_firewall_filter" "allow_pc_to_dmz" {
  action       = "accept"
  chain        = "forward"
  comment      = "PC -> DMZ (Client-Zugriff)"
  src_address  = "10.10.0.0/24"
  dst_address  = "10.30.0.0/24"
  place_before = routeros_ip_firewall_filter.allow_fritzbox_to_prd_dns_tcp.id
}

resource "routeros_ip_firewall_filter" "allow_fritzbox_to_prd_dns_tcp" {
  action            = "accept"
  chain             = "forward"
  comment           = "Hairpin: FritzBox -> PROD DNS TCP"
  in_interface_list = "WAN"
  src_address       = "192.168.178.0/24"
  dst_address       = "10.20.0.3"
  protocol          = "tcp"
  dst_port          = "53"
  place_before      = routeros_ip_firewall_filter.allow_fritzbox_to_prd_dns_udp.id
}

resource "routeros_ip_firewall_filter" "allow_fritzbox_to_prd_dns_udp" {
  action            = "accept"
  chain             = "forward"
  comment           = "Hairpin: FritzBox -> PROD DNS UDP"
  in_interface_list = "WAN"
  src_address       = "192.168.178.0/24"
  dst_address       = "10.20.0.3"
  protocol          = "udp"
  dst_port          = "53"
  place_before      = routeros_ip_firewall_filter.allow_fritzbox_to_dmz_http.id
}

resource "routeros_ip_firewall_filter" "allow_fritzbox_to_dmz_http" {
  action            = "accept"
  chain             = "forward"
  comment           = "Hairpin: FritzBox -> DMZ HTTP"
  in_interface_list = "WAN"
  src_address       = "192.168.178.0/24"
  dst_address       = "10.30.0.2"
  protocol          = "tcp"
  dst_port          = "80"
  place_before      = routeros_ip_firewall_filter.allow_fritzbox_to_dmz_https.id
}

resource "routeros_ip_firewall_filter" "allow_fritzbox_to_dmz_https" {
  action            = "accept"
  chain             = "forward"
  comment           = "Hairpin: FritzBox -> DMZ HTTPS"
  in_interface_list = "WAN"
  src_address       = "192.168.178.0/24"
  dst_address       = "10.30.0.2"
  protocol          = "tcp"
  dst_port          = "443"
  place_before      = routeros_ip_firewall_filter.allow_fritzbox_to_dmz_minecraft_tcp.id
}

resource "routeros_ip_firewall_filter" "allow_fritzbox_to_dmz_minecraft_tcp" {
  action            = "accept"
  chain             = "forward"
  comment           = "Hairpin: FritzBox -> DMZ Minecraft TCP"
  in_interface_list = "WAN"
  src_address       = "192.168.178.0/24"
  dst_address       = "10.30.0.2"
  protocol          = "tcp"
  dst_port          = "25565"
  place_before      = routeros_ip_firewall_filter.allow_fritzbox_to_dmz_minecraft_udp.id
}

resource "routeros_ip_firewall_filter" "allow_fritzbox_to_dmz_minecraft_udp" {
  action            = "accept"
  chain             = "forward"
  comment           = "Hairpin: FritzBox -> DMZ Minecraft UDP"
  in_interface_list = "WAN"
  src_address       = "192.168.178.0/24"
  dst_address       = "10.30.0.2"
  protocol          = "udp"
  dst_port          = "25565"
  place_before      = routeros_ip_firewall_filter.allow_wan_to_dstnat_tcp.id
}

resource "routeros_ip_firewall_filter" "allow_wan_to_dstnat_tcp" {
  action               = "accept"
  chain                = "forward"
  comment              = "Allow incoming DST-NATed traffic (TCP)"
  connection_nat_state = "dstnat"
  connection_state     = "new"
  in_interface_list    = "WAN"
  protocol             = "tcp"
  place_before         = routeros_ip_firewall_filter.allow_wan_to_dstnat_udp.id
}

resource "routeros_ip_firewall_filter" "allow_wan_to_dstnat_udp" {
  action               = "accept"
  chain                = "forward"
  comment              = "Allow incoming DST-NATed traffic (UDP)"
  connection_nat_state = "dstnat"
  connection_state     = "new"
  in_interface_list    = "WAN"
  protocol             = "udp"
  place_before         = routeros_ip_firewall_filter.drop_all_wan_not_dstnat.id
}

resource "routeros_ip_firewall_filter" "drop_all_wan_not_dstnat" {
  action               = "drop"
  chain                = "forward"
  comment              = "Drop incoming WAN traffic not destined for a port-forward"
  connection_nat_state = "!dstnat"
  connection_state     = "new"
  in_interface_list    = "WAN"
  place_before         = routeros_ip_firewall_filter.z_drop_all_forward.id
}

resource "routeros_ip_firewall_filter" "z_drop_all_forward" {
  action = "drop"
  chain  = "forward"
  log    = "true"
  log_prefix = "FW_DROP: "
  comment = "DROP EVERYTHING ELSE - FINAL ZERO TRUST POLICY"
}

# ===============================================
# Firewall NAT (DST-NAT/SRC-NAT)
# ===============================================

resource "routeros_ip_firewall_nat" "hairpin_generic" {
  action      = "masquerade"
  chain       = "srcnat"
  comment     = "Hairpin NAT: Internal to DMZ via Public IP"
  src_address = "10.0.0.0/8"
  dst_address = "10.30.0.2"
  out_interface = routeros_interface_bridge.bridge.name
}

resource "routeros_ip_firewall_nat" "hairpin_srcnat_fritzbox_to_dmz" {
  action        = "masquerade"
  chain         = "srcnat"
  comment       = "Hairpin NAT: FritzBox (WAN) to DMZ"
  src_address   = "192.168.178.0/24"
  dst_address   = "10.30.0.0/24"
  out_interface = routeros_interface_bridge.bridge.name
  place_before  = routeros_ip_firewall_nat.hairpin_srcnat_fritzbox_to_prod.id
}

resource "routeros_ip_firewall_nat" "hairpin_srcnat_fritzbox_to_prod" {
  action        = "masquerade"
  chain         = "srcnat"
  comment       = "Hairpin NAT: FritzBox (WAN) to PROD"
  src_address   = "192.168.178.0/24"
  dst_address   = "10.20.0.0/24"
  out_interface = routeros_interface_bridge.bridge.name
  place_before  = routeros_ip_firewall_nat.masquerade.id
}

resource "routeros_ip_firewall_nat" "masquerade" {
  chain              = "srcnat"
  action             = "masquerade"
  comment            = "Masquerade all traffic leaving WAN"
  ipsec_policy       = "out,none"
  out_interface_list = routeros_interface_list.wan.name
}

resource "routeros_ip_firewall_nat" "forward_http_to_npm" {
  action            = "dst-nat"
  chain             = "dstnat"
  comment           = "Forward HTTP to Reverse Proxy"
  in_interface_list = "WAN"
  protocol          = "tcp"
  dst_port          = "80"
  to_addresses      = "10.30.0.2"
  to_ports          = "80"
  place_before      = routeros_ip_firewall_nat.forward_https_to_npm.id
}

resource "routeros_ip_firewall_nat" "forward_https_to_npm" {
  action            = "dst-nat"
  chain             = "dstnat"
  comment           = "Forward HTTPS to Reverse Proxy"
  in_interface_list = "WAN"
  protocol          = "tcp"
  dst_port          = "443"
  to_addresses      = "10.30.0.2"
  to_ports          = "443"
  place_before      = routeros_ip_firewall_nat.forward_minecraft_to_pi.id
}

resource "routeros_ip_firewall_nat" "forward_minecraft_to_pi" {
  action            = "dst-nat"
  chain             = "dstnat"
  comment           = "Forward Minecraft to DMZ"
  in_interface_list = "WAN"
  protocol          = "tcp"
  dst_port          = "25565"
  to_addresses      = "10.30.0.2"
  to_ports          = "25565"
  place_before      = routeros_ip_firewall_nat.redirect_wan_dns_to_adguard_tcp.id
}

resource "routeros_ip_firewall_nat" "redirect_wan_dns_to_adguard_tcp" {
  action            = "dst-nat"
  chain             = "dstnat"
  comment           = "Redirect WAN DNS TCP to AdGuard (192.168.178.10 is FritzBox)"
  in_interface_list = "WAN"
  dst_address       = "192.168.178.10"
  protocol          = "tcp"
  dst_port          = "53"
  to_addresses      = "10.20.0.3"
  to_ports          = "53"
  place_before      = routeros_ip_firewall_nat.redirect_wan_dns_to_adguard_udp.id
}

resource "routeros_ip_firewall_nat" "redirect_wan_dns_to_adguard_udp" {
  action            = "dst-nat"
  chain             = "dstnat"
  comment           = "Redirect WAN DNS UDP to AdGuard (192.168.178.10 is FritzBox)"
  in_interface_list = "WAN"
  dst_address       = "192.168.178.10"
  protocol          = "udp"
  dst_port          = "53"
  to_addresses      = "10.20.0.3"
  to_ports          = "53"
}

resource "routeros_ip_firewall_nat" "force_dns_internal" {
  action             = "dst-nat"
  chain              = "dstnat"
  comment            = "Force Internal DNS to AdGuard"
  in_interface_list  = "LAN"
  dst_address        = "!10.20.0.3"
  protocol           = "udp"
  dst_port           = "53"
  to_addresses       = "10.20.0.3"
}

# ===============================================
# IPv6 Settings
# ===============================================

resource "routeros_ipv6_settings" "disable" {
  disable_ipv6 = "true"
}

# ===============================================
# System Logging (Firewall Drops)
# ===============================================

resource "routeros_system_logging_action" "fw_drop_action" {
  name                = "fwtodisk"
  target              = "disk"
  disk_file_name      = "fw_drops"
  disk_lines_per_file = 1000
  disk_file_count     = 2
}

resource "routeros_system_logging" "fw_drop_rule" {
  action = routeros_system_logging_action.fw_drop_action.name
  topics = ["firewall", "info"]
}