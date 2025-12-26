variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_tokenid" {
  type = string
}

variable "proxmox_api_token" {
  type = string
}

variable "node" {
  type    = string
  default = "pve"
}

variable "iso_file" {
  type    = string
  default = "local:iso/Ubuntu-24.04.3.iso"
}
