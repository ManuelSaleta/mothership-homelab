# ==============================================================================
# Purpose of this file is to provision the baseline infrastructure for the cluster:
# - "Carve out exactly 2 CPU cores and 3GB of RAM."
# - "Provision a 30GB virtual hard drive on local-lvm."
# - "Plug the virtual network card into the vmbr0 SDN bridge."
# - "Shove the Ubuntu 26.04 installation media into the virtual CDROM drive and turn on the power."
#
# Post-Deployment: This VM will be initialized with K3s to act as the "brains" 
# (Control Plane), orchestrating and managing the rest of the worker nodes.
# Docs: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
# ==============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = true
  api_token = var.proxmox_api_token
}

resource "proxmox_virtual_environment_vm" "k3s_control" {
  name        = "k3s-control-01"
  description = "Lightweight K3s Kubernetes Control Node - the 'brains'"
  node_name   = "mothership"
  vm_id       = 100

  # Modern CDROM definition requiring an explicit interface target
  cdrom {
    file_id   = "local:iso/ubuntu-26.04-live-server-amd64.iso"
    interface = "ide3"
  }

  # Hardware Layout Blocks
  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 3072 # 3 GB RAM
  }

  # Block storage definition
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 30 # 30 GB storage
    discard      = "on"
  }

  # Network interface definition targeting the local SDN zone
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Array format matching the 0.106 schema mapping rules
  boot_order = ["scsi0", "ide3"]
  on_boot    = true
}