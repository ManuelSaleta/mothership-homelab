terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://192.168.50.200:8006/api2/json"
  pm_api_token_id     = "terraform-user-agent@pve!terraform-token" # the terraform created on the proxmox server
  pm_api_token_secret = "ffd815cc-a181-40be-9844-c485778b233b" # WARNING REPLACE BEFORE PUTTING IN GIT
  pm_tls_insecure     = true 
}

resource "proxmox_vm_qemu" "k3s_control" {
  name        = "k3s-control-01"
  target_node = "mothership" 
  vmid        = 100
  desc        = "Lightweight K3s Kubernetes Control Node"

  # Core Hardware Settings
  cores   = 2
  sockets = 1
  cpu_type     = "host" # pipi Fixed argument name for Telmate v3
  memory  = 3072 

  # Storage Layout
  scsihw = "virtio-scsi-pci"
  
  disks {
    scsi {
      scsi0 {
        disk {
          size    = "30G"
          storage = "local-lvm"
          discard = true 
        }
      }
    }
    ide {
      ide2 {
        cdrom {
          iso = "local:iso/ubuntu-26.04-live-server-amd64.iso"
        }
      }
    }
  }

  # Network Topology
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  boot   = "order=scsi0;ide2"
  onboot = true
}