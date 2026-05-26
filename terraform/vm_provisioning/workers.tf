# ==============================================================================
# 1. THE USER DATA SNIPPETS (Now generates 2 unique files!)
# ==============================================================================
resource "proxmox_virtual_environment_file" "k3s_worker_cloud_config" {
  count        = 2
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "mothership"

  source_raw {
    # Dynamically name the snippet file so they don't overwrite each other
    file_name = "k3s-worker-0${count.index + 1}-cloud-config.yaml"

    data = <<-EOF
    #cloud-config
    hostname: "k3s-worker-0${count.index + 1}"
    users:
      - name: gman
        groups: sudo
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${file("/home/gman/.ssh/id_ed25519.pub")}
    
    runcmd:
      - until ping -c 1 ${var.default_gateway}; do sleep 1; done
      # 1. Hardcode the environment variable directly so the service never gets confused
      - echo 'K3S_NODE_NAME="k3s-worker-0${count.index + 1}"' > /etc/systemd/system/k3s-agent.service.env
      # 2. Hardcode the installer flag directly
      - curl -sfL https://get.k3s.io | K3S_URL="https://192.168.50.219:6443" K3S_TOKEN="${var.k3s_share_token}" INSTALL_K3S_EXEC="agent --node-name=k3s-worker-0${count.index + 1}" sh -
      - systemctl daemon-reload
      - # Wait for network to settle
      - sleep 10 
      - # Then start k3s
      - systemctl restart k3s-agent
    EOF
  }
}

# ==============================================================================
# 2. THE VM DEPLOYMENT
# ==============================================================================
resource "proxmox_virtual_environment_vm" "k3s_worker" {
  count       = 2
  name        = "k3s-worker-0${count.index + 1}"
  description = "Managed by Terraform - K3s Worker Node via Golden Template"
  tags        = ["Kubernetes", "K3s", "worker"]
  node_name   = "mothership"
  vm_id       = 210 + count.index

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  # There is a VM that asks as a template to spin up future workers. 
  clone {
    vm_id        = 999
    full         = true 
    datastore_id = "local-lvm"
  }

  initialization {
    datastore_id = "local-lvm"

    # Match each VM to its specific hardcoded Cloud-Init file!
    user_data_file_id = proxmox_virtual_environment_file.k3s_worker_cloud_config[count.index].id

    ip_config {
      ipv4 {
        address = "192.168.50.${210 + count.index}/24"
        gateway = var.default_gateway
      }
    }

    dns {
      servers = ["${var.default_gateway}", "1.1.1.1"]
    }
  }
}