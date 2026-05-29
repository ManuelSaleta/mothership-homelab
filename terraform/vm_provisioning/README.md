# Homelab K3s Cluster Infrastructure

Automated Proxmox IaC repository to provision a lightweight K3s Kubernetes cluster (1 Manager, N Workers) cloned from a golden Packer made template (**ID 777**).

---

## 🏗️ Architecture Layout

- **Manager Node (`k3s-control-01`):** 2 Cores, 3GB RAM, DHCP IP allocation.
- **Worker Nodes (`k3s-worker-0[1-N]`):** 2 Cores, 2GB RAM, Static IPs, starting at .210 (`192.168.50.210` & `.211`, `.xxx`).
- **Base OS Template:** Ubuntu 24.04 LTS (Pre-baked via Packer).

---

## 📂 Repository Blueprint

```text
├── main.tf                  # Provider configuration & K3s Control Plane VM definition
├── workers.tf               # K3s Worker VMs & Cloud-Init User-Data snippet loops
├── variables.tf             # Core HCL input type definitions and schema rules
├── terraform.tfvars.example # Safe documentation template for variables
└── Makefile                 # Single-command infrastructure lifecycle orchestration

```

---

## 🛠️ Automation Matrix (Makefile)

Run commands from the root directory to manage the cluster lifecycle:

```bash
# Initialize and validate configuration
make init
make validate

# Standard Infrastructure Lifecycle
make plan
make apply              # Deploys entire cluster with auto-approval
make destroy-workers    # Targets and tears down only the worker pool
make destroy-manager    # Targets and tears down only the control plane

# The Nuke Options
make destroy-all        # Completely tears down all VMs (includes interactive safety check)
make redeploy-workers   # Pipeline: Nukes everything -> Validates formatting -> Re-applies fresh

```

---

## 🔒 Post-Deployment & Injection Mechanics

### 1. Security Isolation

Ensure you copy `terraform.tfvars.example` to `terraform.tfvars` locally and populate your real tokens and endpoints. The `.tfvars` format is ignored by Git to prevent leak risks on GitHub.

### 2. Cloud-Init Worker Hook

Workers leverage a dynamic Cloud-Init configuration block (`proxmox_virtual_environment_file.k3s_worker_cloud_config`) to auto-register with the control plane upon boot. They pull the cluster join hash directly using `${var.k3s_share_token}` and connect to the manager API at port `6443`.

Here is a streamlined, copy-paste friendly `README.md` section covering cluster token rotation, worker node initialization, and your standard pod validation workflow.

---

---

---

## 🚀 K3s Cluster Configuration & Validation Manual

### 1. Token Rotation & Manual Worker Registration

Every time the `k3s-control-01` manager VM is destroyed and recreated, it mints a **brand-new cluster token**. You must extract this token and provide it to your worker nodes.

#### Extract the New Token (Run on Manager)

```bash
sudo cat /var/lib/rancher/k3s/server/node-token

```

#### Manual Join Execution (Run on Worker Nodes)

SSH into your worker node and run the registration command wrapper. Ensure you substitute the correct token value and target node hostname matching your topography:

```bash
# Example for k3s-worker-01
curl -sfL https://get.k3s.io | \
  K3S_URL="https://192.168.50.72:6443" \
  K3S_TOKEN="YOUR_FRESHLY_EXTRACTED_SERVER_TOKEN" \
  INSTALL_K3S_SKIP_DOWNLOAD=true \
  INSTALL_K3S_EXEC="agent --node-name=k3s-worker-01" sh -

```

#### Force Service Sync & Restart

If the installation script skips execution because no core binary changes were detected, force `systemd` to parse the new environment variables manually:

```bash
sudo systemctl daemon-reload
sudo systemctl restart k3s-agent

```

---

### 2. Post-Deployment Verification & Debugging Loop

Once the cluster matrix reports a `Ready` state, execute this interactive loop from your local workstation terminal to verify network connectivity and pod scheduling runtime operations.

#### A. Monitor Lifecycle Status

Watch the engine scale the deployment layers and download container image steps in real time:

```bash
kubectl get pods -w

```

_Press `Ctrl + C` to exit the live stream view once the status flags hit `Running` and the readiness gate registers `1/1`._

#### B. Inspect Cluster Network Allocation

Retrieve extended metadata to check pod-to-node routing assignments and target overlay networks:

```bash
kubectl get pods -o wide

```

> 💡 **Networking Note:** Pod IP allocations (e.g., `10.42.0.X`) exist strictly within the cluster's internal overlay network fabric. Your local workstation cannot route traffic directly to these endpoints without an active proxy or Ingress gateway controller.

#### C. Establish a Secure Tunnel (Port-Forwarding)

Map a local network port on your workstation directly to an active container endpoint inside the target pod layer:

```bash
# Syntax: kubectl port-forward deployment/<NAME> <LOCAL_PORT>:<CONTAINER_PORT>
kubectl port-forward deployment/internal-test 8080:80

```

_This process locks the terminal pane to keep the proxy network bridge alive. Leave it running._

#### D. Interact with the Cluster API (New Terminal Window)

Open a new terminal tab or pane (`Ctrl + Shift + T`) on your workstation and interact with the application over the localhost bridge:

```bash
curl http://localhost:8080

```

_Alternatively, verify visual elements by routing your web browser to `http://localhost:8080`._

#### E. Clean Up Resources

Once your smoke tests or manual debugging sessions are complete, terminate the test resources to free up internal compute overhead on your Proxmox pool:

1. Go back to your first terminal window and press `Ctrl + C` to tear down the port-forwarding proxy.
2. Delete the test deployment components:

```bash
kubectl delete deployment internal-test

```
