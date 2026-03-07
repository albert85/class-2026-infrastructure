## Project Overview

This repository contains the infrastructure and deployment pipeline for a **FastAPI** application hosted on **AWS**. It utilizes a **Security-First** approach, implementing **CIS Level 1 Hardening** on Amazon Linux 2023 instances.

The architecture is designed for a private network setup where the application is shielded from the internet, accessible only through an **Application Load Balancer (ALB)**.

---

## 🏗 Architecture Diagram

* **Public Layer:** Application Load Balancer (ALB) and Bastion (Jump) Host.
* **Private Layer:** FastAPI Application (Nginx + Uvicorn) and PostgreSQL RDS.
* **Security Layer:** OS Hardening (DevSec), SSH Hardening, and RHEL9-CIS compliance roles.

---

## 🛠 Tech Stack

| Component | Technology |
| --- | --- |
| **Cloud Provider** | AWS (eu-north-1) |
| **IaC** | Terraform (S3 Backend) |
| **Configuration** | Ansible (CIS Hardening Roles) |
| **Web Server** | Nginx (Reverse Proxy) |
| **App Framework** | FastAPI (Uvicorn) |
| **CI/CD** | GitHub Actions |
| **Security** | Firewalld, Fail2Ban, SELinux, CodeQL, Gitleaks |

---

## 🚀 Getting Started

### 1. Prerequisites

* AWS CLI configured with appropriate permissions.
* A **DuckDNS** token for SSL certificate generation.
* GitHub Repository Secrets configured.

### 2. GitHub Secrets Configuration

To run the deployment pipeline, you must add the following secrets to your GitHub repository:

| Secret Name | Description |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | AWS credentials. |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials. |
| `DESTROY` | Set to `true` to destroy the infrastructure. |
| `DUCKDNS_DOMAIN` | Domain name for the SSL certificate.
| `DUCKDNS_TOKEN` | Token for ACME SSL challenge. |
| `SSH_PRIVATE_KEY` | The .pem key content to access EC2 instances.

---

## 📂 Project Structure

```text
├── .github/workflows/   # CI/CD Pipeline (Linting, Scanning, Deploy)
├── terraform/           # IaC for VPC, EC2, RDS, ALB, and SG


```

## 🔧 Troubleshooting

### 502 Bad Gateway

If the ALB returns a 502, check the following on the App Server:

* **SELinux:** `sudo ausearch -m avc -ts recent` to check for denials.
* **Firewall:** `sudo firewall-cmd --zone=trusted --list-sources` to ensure the VPC is whitelisted.
* **App Status:** `sudo systemctl status uvicorn` (or your app service name).

---

## 📜 License

This project is licensed under the MIT License.

Would you like me to help you generate the **`requirements.yml`** file for the Ansible roles used in this README?