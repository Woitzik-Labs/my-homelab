# My Homelab

Welcome to **My Homelab** repository!

This repo contains all the code, configurations, and scripts I use to manage my personal homelab.  
Everything here is aimed at learning, experimenting, and building practical IT skills in areas like Terraform, Ansible, Docker, Kubernetes, and more.

---

## Table of Contents

- [About](#about)  
- [Infrastructure](#infrastructure)  
- [Projects](#projects)  
- [Setup Instructions](#setup-instructions)  
- [Contributing](#contributing)  
- [License](#license)

---

## About

This repository is my personal collection of:

- **Terraform configurations** for network devices, servers, and VMs  
- **Ansible playbooks & roles** for automation across my Raspberry Pi, mini PC, and other nodes  
- **Docker Compose setups** for services like media servers, proxies, and home automation  
- **Kubernetes manifests & Helm charts** for my clusters  
- Useful scripts, notes, and experiments  

> This is **not production code** — everything is tailored to my homelab environment.

---

## Infrastructure

Here’s an overview of my current homelab:

- **Raspberry Pi 4B (8GB RAM)**  
  - Minecraft server (Crafty, Mysterium Network)  
  - Nginx Proxy Manager  

- **Mini PC (Ryzen 7 5825U, 64GB RAM)**  
  - Proxmox host for VMs  
  - AdGuard Home  
  - Jellyfin media server  
  - Vaultwarden  
  - Arr Suite (Sonarr, Radarr, etc.)  

- **Networking**  
  - Mikrotik RB5009 (Terraform-managed)  
  - VLANs configured  
  - FritzBox 6591 Cable  

- **Other**  
  - Rackmount setup (Digitus 10U 6HE)  
  - Plans for future Cloud-Init, Ingress, and Load Balancer experiments  

---

## Projects

This repo contains multiple projects. Some of the main folders include:

- `terraform/` — Terraform configurations for networking and VM provisioning  
- `ansible/` — Playbooks and roles for system setup and service automation  
- `docker/` — Docker Compose files for various services  
- `kubernetes/` — Cluster manifests, Helm charts, and configuration examples  
- `scripts/` — Useful bash/python scripts for automation  

> Each project is documented inside its folder with README files explaining purpose, requirements, and usage.

---

## Setup Instructions

> These instructions assume you are familiar with basic IT concepts.  
> Use at your own risk — tailored for my homelab environment.

1. Clone the repository:

```bash
git clone https://github.com/woitzik-labs/my-homelab.git
```

2. Check each project folder for specific instructions:

- `terraform/README.md`  
- `ansible/README.md`  
- `docker/README.md`  
- `kubernetes/README.md`  

3. Follow the individual setup instructions carefully.  
Contributions are welcome but make sure to test in your own environment before applying any configs.

---

## Contributing

If you want to contribute:

1. Fork the repo  
2. Create a branch: `git checkout -b feature-name`  
3. Commit your changes: `git commit -m "Add feature"`  
4. Push to the branch: `git push origin feature-name`  
5. Open a pull request  

Only share tested and safe configurations.

---

## License

This repository is licensed under the MIT License. See [LICENSE](LICENSE) for details.

