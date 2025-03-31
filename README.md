## Overview

This repository serves as a playground for building and deploying a cloud-native application on Azure with deliberately introduced security issues. These include outdated and vulnerable Linux versions, publicly accessible storage accounts, exposed virtual machines, and databases without proper access controls. It provides the foundation for security scanning and analysis across infrastructure, containers, Kubernetes, and CI/CD pipelines, allowing you to discover and remediate issues using modern cloud security tools.

## Purpose

The primary goals of this project are to:

1. **Demonstrate cloud-native architecture** with typical real-world components
2. **Implement infrastructure-as-code** using Terraform and Azure
3. **Showcase containerization** with Docker and Azure Container Registry
4. **Deploy to Kubernetes** using Azure Kubernetes Service
5. **Automate with CI/CD** using GitHub Actions workflows
6. **Demonstrate security misconfigurations** and their detection

## Repository Structure

```
CloudNative-Security/
├── 01_terraform/          # Terraform configuration files
├── 02_kubernetes/         # Kubernetes manifests for deployment
├── 03_application/        # Application source code
│   ├── backend/           # Node.js backend API
│   └── web-app/           # React frontend application
├── .github/workflows/     # GitHub Actions CI/CD workflows
└── README.md              # This file
```

## Getting Started

### Prerequisites

- Azure Subscription
- GitHub Account
- Terraform CLI (v1.0+)
- Azure CLI
- kubectl
- Docker
- Node.js and npm

### Setup Instructions

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/CloudNative-Security.git
   cd CloudNative-Security
   ```

2. **Set up Azure authentication**

   ```bash
   az login
   az account set --subscription <your-subscription-id>
   ```

3. **Configure GitHub Repository Secrets and Variables**

   Set up the following secrets in your GitHub repository:
   - `AZURE_CLIENT_ID`
   - `AZURE_CLIENT_SECRET`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`

   Set up the following variable as repository variable in your GitHub repository:
   - `RESOURCE_GROUP`

4. **Deploy with the CI/CD pipeline**

   Push changes to the `main` branch or manually trigger the ```End-to-End Deployment``` workflow from the GitHub Actions tab.

---

### Manual Deployment

#### Infrastructure

```bash
cd 01_terraform
terraform init
terraform plan -var "subscription_id=<your-subscription-id>" -var "environment=wizdemo"
terraform apply
```

#### Build and Push Docker Images

```bash
# Build backend
cd 03_application/backend
az acr build --registry <your-acr-name> --image backend-app:v1 .

# Build frontend
cd ../web-app
az acr build --registry <your-acr-name> --image web-app:v1 .
```

#### Deploy to Kubernetes

```bash
cd 02_kubernetes
az aks get-credentials --resource-group <your-resource-group> --name <your-aks-cluster>
kubectl apply -f deployment.yaml
kubectl apply -f service.yml
```

## CI/CD Pipeline

This repository includes GitHub Actions workflows that handle:

1. Building and pushing Docker images to ACR
2. Deploying infrastructure with Terraform
3. Deploying applications to Kubernetes

### Workflow Structure

- **build-images.yml**: Handles building and pushing Docker images to ACR
- **terraform-deploy.yml**: Manages infrastructure deployment using Terraform
- **kubernetes-deploy.yml**: Deploys applications to the Kubernetes cluster
- **end-to-end.yml**: Orchestrates the entire deployment pipeline

## Web Application Access

After successful deployment, access your web application at the external IP provided by the LoadBalancer service:

```bash
kubectl get service web-service -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
```

## Project Requirements & Implementation Details

### Database Setup
- **MongoDB VM**: Deployed with an outdated Linux version using Terraform
- **Security Issue**: VM configured with a public IP address and allows SSH connections from the internet
- **Database Authentication**: Local authentication enabled for MongoDB
- **Connection String**: Defined in Terraform outputs and passed to Kubernetes via secrets

### Highly Privileged VM
- **Security Issue**: MongoDB VM assigned an overly permissive "Contributor" role on the resource group
- **Potential Risk**: The VM's managed identity can modify any resource in the resource group

### Object Storage
- **Backup Storage**: Azure Storage Account created for database backups
- **Security Issue**: Storage account configured with `allow_nested_items_to_be_public = true`
- **Backup Access**: Publicly accessible backups can be accessed via external URL

### Database Backups
- **Automated Backups**: Scheduled backup script running on the MongoDB VM
- **Implementation**: Uses Azure Storage SAS tokens for authentication
- **Storage**: Backups stored in public-readable storage container

### Kubernetes Cluster
- **AKS Deployment**: Containerized web application running on AKS
- **Public Access**: Services exposed via LoadBalancer with public IP
- **Security Issue**: Web application container runs with cluster-admin privileges through service account binding

### Security Monitoring
- **Microsoft Defender for Cloud**: Enabled to detect infrastructure misconfigurations
- **Alerts**: Configured to identify security risks and compliance issues

## Security Controls

The following security controls have been implemented:

### Preventative Controls
- **Microsoft Defender for Cloud**: Protection for Container Registries, Kubernetes Services, and Virtual Machines
- **Network Security Group Rules**: Restricts inbound traffic to MongoDB VM (though intentionally misconfigured for demo)

### Detective Controls
- **Azure Security Center**: Monitors for security vulnerabilities and threats
- **Control Plane Audit Logging**: Records all API server activity for AKS cluster
- **Log Analytics**: Centralized logging for audit events and security alerts

### Monitoring and Response
- **Security Alerts**: Configured to send notifications via email for security incidents
- **Diagnostic Settings**: Captures detailed AKS control plane logs for investigation

To demonstrate these controls in action, you can run the included `simulate-attack.sh` script after deployment.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*Note: This project is intended for educational and demonstration purposes only.*