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
  list      = "Internal_Networks"
  address   = "192.168.178.0/24"
}

resource "routeros_ip_firewall_addr_list" "internal_net_10" {
  list      = routeros_ip_firewall_addr_list.internal_networks_wlan.list
  address   = "10.10.0.0/24"
}

resource "routeros_ip_firewall_addr_list" "internal_net_20" {
  list      = routeros_ip_firewall_addr_list.internal_networks_wlan.list
  address   = "10.20.0.0/24"
}

resource "routeros_ip_firewall_addr_list" "dmz_network" {
  list      = "DMZ_Network"
  address   = "10.30.0.0/24"
}

# ===============================================
# Firewall Filter - INPUT Chain
# ===============================================

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
  place_before = routeros_ip_firewall_filter.accept_management_from_pc.id
}

resource "routeros_ip_firewall_filter" "accept_management_from_pc" {
  action      = "accept"
  chain       = "input"
  src_address = "10.10.0.0/24"
  place_before = routeros_ip_firewall_filter.drop_all_input.id
}

resource "routeros_ip_firewall_filter" "drop_all_input" {
  action = "drop"
  chain  = "input"
}

# ===============================================
# Firewall Filter - FORWARD Chain
# ===============================================

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
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_adguard_http.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_adguard_http" {
  action           = "accept"
  chain            = "forward"
  comment          = "DMZ to Prod: AdGuard HTTP Backend (Reverse Proxy)"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address      = "10.20.0.3"
  protocol         = "tcp"
  dst_port         = "80"
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_vaultwarden_http.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_vaultwarden_http" {
  action           = "accept"
  chain            = "forward"
  comment          = "DMZ to Prod: Vaultwarden Backend (Reverse Proxy)"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address      = "10.20.0.102"
  protocol         = "tcp"
  dst_port         = "8000"
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_proxmox_http.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_proxmox_http" {
  action           = "accept"
  chain            = "forward"
  comment          = "DMZ to Prod: Proxmox Backend (Reverse Proxy)"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address      = "10.20.0.10"
  protocol         = "tcp"
  dst_port         = "8006"
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_qbt_http.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_jf_http" {
  action           = "accept"
  chain            = "forward"
  comment          = "DMZ to Prod: Jellyfin Backend (Reverse Proxy)"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address      = "10.20.0.101"
  protocol         = "tcp"
  dst_port         = "8096"
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_qbt_http.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_qbt_http" {
  action           = "accept"
  chain            = "forward"
  comment          = "DMZ to Prod: qBittorrent Backend (Reverse Proxy)"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address      = "10.20.0.101"
  protocol         = "tcp"
  dst_port         = "8080"
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_ra_http.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_ra_http" {
  action           = "accept"
  chain            = "forward"
  comment          = "DMZ to Prod: Radarr Backend (Reverse Proxy)"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address      = "10.20.0.101"
  protocol         = "tcp"
  dst_port         = "7878"
  place_before     = routeros_ip_firewall_filter.allow_dmz_to_sa_http.id
}

resource "routeros_ip_firewall_filter" "allow_dmz_to_sa_http" {
  action           = "accept"
  chain            = "forward"
  comment          = "DMZ to Prod: Sonarr Backend (Reverse Proxy)"
  src_address_list = routeros_ip_firewall_addr_list.dmz_network.list
  dst_address      = "10.20.0.101"
  protocol         = "tcp"
  dst_port         = "8989"
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
  action      = "accept"
  chain       = "forward"
  comment     = "PC -> PROD (Client-Zugriff)"
  src_address = "10.10.0.0/24"
  dst_address = "10.20.0.0/24"
  place_before = routeros_ip_firewall_filter.allow_pc_to_dmz.id
}

resource "routeros_ip_firewall_filter" "allow_pc_to_dmz" {
  action      = "accept"
  chain       = "forward"
  comment     = "PC -> DMZ (Client-Zugriff)"
  src_address = "10.10.0.0/24"
  dst_address = "10.30.0.0/24"
  place_before = routeros_ip_firewall_filter.allow_wlan_to_prod.id
}

resource "routeros_ip_firewall_filter" "allow_wlan_to_prod" {
  action      = "accept"
  chain       = "forward"
  comment     = "WLAN -> PROD (Client-Zugriff)"
  src_address = "192.168.178.0/24"
  dst_address = "10.20.0.0/24"
  place_before = routeros_ip_firewall_filter.allow_lan_to_dmz.id
}

resource "routeros_ip_firewall_filter" "allow_lan_to_dmz" {
  action      = "accept"
  chain       = "forward"
  comment     = "WLAN -> DMZ (Client-Zugriff)"
  src_address = "192.168.178.0/24"
  dst_address = "10.30.0.0/24"
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
  place_before      = routeros_ip_firewall_filter.drop_all_wan_not_dstnat.id
}

resource "routeros_ip_firewall_filter" "drop_all_wan_not_dstnat" {
  action             = "drop"
  chain              = "forward"
  comment            = "Drop incoming WAN traffic not destined for a port-forward"
  connection_nat_state = "!dstnat"
  connection_state   = "new"
  in_interface_list  = "WAN"
  place_before       = routeros_ip_firewall_filter.z_drop_all_forward.id
}

resource "routeros_ip_firewall_filter" "z_drop_all_forward" {
  action = "drop"
  chain  = "forward"
  comment = "DROP EVERYTHING ELSE - FINAL ZERO TRUST POLICY"
}

# ===============================================
# Firewall NAT (DST-NAT/SRC-NAT)
# ===============================================

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

# ===============================================
# IPv6 Settings
# ===============================================

resource "routeros_ipv6_settings" "disable" {
  disable_ipv6 = "true"
}