# SummitLMS Deployment Guide

## 📖 Table of Contents
- [How It Works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)
- [Terraform Commands Explained](#terraform-commands-explained)
- [Post-Deployment](#post-deployment)
- [Cleanup](#cleanup)

---

## 🔍 How It Works

### Architecture Overview

SummitLMS deploys a complete Learning Management System on Azure with enterprise-grade security. Here's what happens when you deploy:

```
┌─────────────────────────────────────────────────────────────┐
│  1. TERRAFORM INITIALIZATION                                 │
│  • Downloads Azure provider                                  │
│  • Prepares backend for state management                     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  2. INFRASTRUCTURE PLANNING                                  │
│  • Calculates resource dependencies                          │
│  • Validates configuration                                   │
│  • Shows what will be created                                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  3. RESOURCE CREATION (in order)                            │
│                                                              │
│  A. Networking Layer                                         │
│     • Virtual Network (10.0.0.0/16)                         │
│     • App Subnet (10.0.1.0/24)                              │
│     • Database Subnet (10.0.2.0/24)                         │
│     • Private DNS Zone                                       │
│                                                              │
│  B. Security Layer                                           │
│     • Azure Key Vault                                        │
│     • Store MySQL password as secret                         │
│     • Create access policies                                 │
│                                                              │
│  C. Data Layer                                               │
│     • MySQL Flexible Server                                  │
│     • Connect to Database Subnet                             │
│     • Link to Private DNS                                    │
│     • Create WordPress database                              │
│                                                              │
│  D. Compute Layer                                            │
│     • App Service Plan (B1)                                  │
│     • Linux Web App with Docker                              │
│     • Enable Managed Identity                                │
│     • Connect to App Subnet (VNet Integration)              │
│     • Configure Key Vault reference for password            │
│                                                              │
│  E. Observability Layer                                      │
│     • Log Analytics Workspace                                │
│     • Application Insights                                   │
│     • Connect to App Service                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  4. APPLICATION STARTUP                                      │
│  • Docker pulls wordpress:latest image                       │
│  • App Service fetches DB password from Key Vault           │
│  • WordPress connects to MySQL (via VNet)                    │
│  • Site becomes accessible at: app-summitlms-prod.azure...  │
└─────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

```
User Browser
    ↓ (HTTPS)
Azure App Service (WordPress Docker Container)
    ↓
    ├─→ Azure Key Vault (Get DB Password) [via Managed Identity]
    │
    ├─→ MySQL Server (Database Queries) [via Private VNet - No Internet]
    │
    └─→ Application Insights (Send Logs & Metrics)
```

### Key Security Features Explained

1. **Zero-Trust Networking**: The MySQL database has NO public IP address. It's invisible from the internet.
2. **Managed Identity**: The App Service doesn't use passwords to access Key Vault—it uses its Azure identity.
3. **Key Vault References**: The database password is never stored in the App Service configuration; only a reference URI is stored.

---

## ✅ Prerequisites

Before you begin, ensure you have:

1. **Azure CLI** (v2.40+)
   ```bash
   az --version
   ```

2. **Terraform** (v1.0+)
   ```bash
   terraform version
   ```

3. **Azure Subscription** with:
   - Contributor or Owner role
   - Sufficient quota for:
     - 1 App Service Plan (B1)
     - 1 MySQL Flexible Server (B_Standard_B1ms)
     - 1 Key Vault
     - 1 Virtual Network

4. **Authenticated Azure CLI**
   ```bash
   az login
   az account show
   ```

---

## 🚀 Deployment Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/thezaynahmed/summitlms-azure-terraform.git
cd summitlms-azure-terraform
```

### Step 2: Configure Secrets

Create a `terraform.tfvars` file in the project root:

```bash
cat > terraform.tfvars << EOF
mysql_admin_password = "YourSecurePassword123!@#"
EOF
```

> **Security Note**: This file is listed in `.gitignore` and will NOT be committed to Git.

**Password Requirements:**
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 number
- At least 1 special character

### Step 3: Initialize Terraform

```bash
terraform init
```

**What This Does:**
- Downloads the Azure provider plugin (~100MB)
- Initializes the backend (local state file by default)
- Prepares the working directory

**Expected Output:**
```
Terraform has been successfully initialized!
```

### Step 4: Review the Deployment Plan

```bash
terraform plan -out=tfplan
```

**What This Does:**
- Connects to Azure
- Calculates what resources need to be created
- Shows a detailed execution plan
- Saves the plan to a file (`tfplan`)

**Expected Output:**
```
Plan: 13 to add, 0 to change, 0 to destroy.
```

**Resources That Will Be Created:**
- 1 Resource Group
- 1 Virtual Network
- 2 Subnets (App + Database)
- 1 Private DNS Zone
- 1 DNS Zone VNet Link
- 1 Key Vault
- 1 Key Vault Secret
- 2 Key Vault Access Policies
- 1 MySQL Flexible Server
- 1 MySQL Database
- 1 App Service Plan
- 1 Linux Web App
- 1 Log Analytics Workspace
- 1 Application Insights

### Step 5: Apply the Configuration

```bash
terraform apply tfplan
```

**What This Does:**
- Executes the saved plan
- Creates all Azure resources (takes ~10-15 minutes)
- Stores the final state in `terraform.tfstate`

**Deployment Timeline:**
```
0:00 - 1:00   → Networking (VNet, Subnets, DNS)
1:00 - 2:00   → Key Vault creation
2:00 - 8:00   → MySQL Server provisioning (slowest step)
8:00 - 12:00  → App Service Plan + Web App
12:00 - 15:00 → Docker image pull and startup
```

**Expected Output:**
```
Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

Outputs:

app_service_url = "https://app-summitlms-prod.azurewebsites.net"
mysql_fqdn = "mysql-summitlms-prod.mysql.database.azure.com"
```

---

## 🛠️ Terraform Commands Explained

### `terraform init`
**Purpose**: Prepares your working directory for Terraform operations.

**When to Use**:
- First time setting up the project
- After adding new provider dependencies
- After changing backend configuration

**Flags**:
```bash
terraform init -upgrade    # Upgrade provider plugins to latest
terraform init -reconfigure # Reconfigure backend
```

---

### `terraform plan`
**Purpose**: Creates an execution plan showing what Terraform will do.

**When to Use**:
- Before every `apply` to review changes
- To verify your configuration is valid
- To estimate cost impact

**Flags**:
```bash
terraform plan -out=tfplan           # Save plan to file
terraform plan -destroy              # Plan for destruction
terraform plan -var="environment=dev" # Override variables
```

**Reading the Output**:
- `+` = Resource will be created
- `~` = Resource will be modified
- `-` = Resource will be destroyed
- `+/-` = Resource will be replaced (destroyed then created)

---

### `terraform apply`
**Purpose**: Executes the plan and creates/updates resources.

**When to Use**:
- After reviewing the plan
- Ready to deploy changes

**Flags**:
```bash
terraform apply                    # Interactive approval required
terraform apply tfplan             # Apply saved plan (no approval)
terraform apply -auto-approve      # Skip approval (DANGEROUS)
```

**What Happens**:
1. Terraform reads the plan
2. Makes API calls to Azure
3. Waits for resources to be ready
4. Updates the state file
5. Shows outputs

---

### `terraform destroy`
**Purpose**: Deletes all resources managed by Terraform.

**When to Use**:
- Tearing down development/test environments
- Cleaning up to avoid Azure charges
- Starting fresh

**Command**:
```bash
terraform destroy
```

**What Gets Deleted**:
- All 13 Azure resources
- Associated data (databases, logs)

> **Warning**: This is irreversible. All data will be lost.

---

### `terraform output`
**Purpose**: Display output values from your deployment.

**When to Use**:
- To get the App Service URL
- To retrieve connection strings
- To extract values for documentation

**Command**:
```bash
terraform output                  # Show all outputs
terraform output app_service_url  # Show specific output
terraform output -json            # JSON format
```

---

### `terraform state`
**Purpose**: Advanced state file management.

**Common Commands**:
```bash
terraform state list               # List all resources
terraform state show <resource>    # Show resource details
terraform state rm <resource>      # Remove from state (doesn't delete)
```

---

## 🎉 Post-Deployment

### Step 1: Access WordPress

1. Get your App Service URL:
   ```bash
   terraform output app_service_url
   ```

2. Open the URL in your browser:
   ```
   https://app-summitlms-prod.azurewebsites.net
   ```

3. Complete the WordPress installation wizard:
   - **Site Title**: "SummitLMS"
   - **Username**: `admin` (or your choice)
   - **Password**: Generate a strong password
   - **Email**: Your email address
   - Click "Install WordPress"

### Step 2: Verify Key Vault Integration

Check that the App Service is reading the password from Key Vault:

```bash
az webapp config appsettings list \
  --name app-summitlms-prod \
  --resource-group rg-summitlms-prod \
  --query "[?name=='WORDPRESS_DB_PASSWORD'].value" \
  --output tsv
```

**Expected Output** (a Key Vault reference, NOT the actual password):
```
@Microsoft.KeyVault(SecretUri=https://kv-summitlms-prod.vault.azure.com/secrets/mysql-admin-password/)
```

### Step 3: Check Monitoring

View Application Insights:
```bash
az monitor app-insights component show \
  --app appi-summitlms-prod \
  --resource-group rg-summitlms-prod
```

---

## 🧹 Cleanup

To avoid ongoing Azure charges, destroy the infrastructure when done:

```bash
# Review what will be deleted
terraform plan -destroy

# Destroy all resources
terraform destroy
```

**Confirm by typing**: `yes`

**Estimated Time**: 8-10 minutes

---

## 🐛 Troubleshooting

### Issue: "Error establishing a database connection"

**Cause**: Key Vault reference not resolved or VNet propagation delay.

**Solution**:
```bash
# Restart the App Service
az webapp restart \
  --name app-summitlms-prod \
  --resource-group rg-summitlms-prod

# Wait 2-3 minutes, then test
curl -I https://app-summitlms-prod.azurewebsites.net
```

---

### Issue: "Error: Key Vault name already exists"

**Cause**: Key Vault names are globally unique in Azure.

**Solution**:
Update `variables.tf`:
```hcl
variable "project_name" {
  default = "summitlms-yourname"  # Make it unique
}
```

---

### Issue: Terraform state is locked

**Cause**: Another Terraform operation is running or crashed.

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

---

## 📚 Additional Resources

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Azure Key Vault Best Practices](https://docs.microsoft.com/azure/key-vault/general/best-practices)

---

*Built by [Zain Ahmed](https://zainahmed.net/)*
