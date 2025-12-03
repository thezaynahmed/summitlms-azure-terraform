/*
SUMMARY:      Core Infrastructure for SummitLMS
DESCRIPTION:  Deploys WordPress on Azure App Service with Docker, MySQL backend, and VNet integration.
              Includes SSL transport disabled on MySQL for WordPress Docker image compatibility.
REFERENCE:    https://github.com/Azure/wordpress-linux-appservice/tree/main/Terraform_Script_Create_WP
AUTHOR:       Cloud Solutions Architect
VERSION:      1.0.1 (SSL configuration fix for WordPress compatibility)
*/

# ====================== #
# Data Sources           #
# ====================== #

data "azurerm_client_config" "current" {}

locals {
  # Resource naming convention: {project}-{resource}-{environment}
  # REMOVED: Random suffix for enterprise standard naming
  resource_suffix = var.environment

  # Computed names
  rg_name          = "rg-${var.project_name}-${local.resource_suffix}"
  vnet_name        = "vnet-${var.project_name}-${local.resource_suffix}"
  app_subnet_name  = "snet-app-${var.project_name}-${local.resource_suffix}"
  db_subnet_name   = "snet-db-${var.project_name}-${local.resource_suffix}"
  dns_zone_name    = "privatelink.mysql.database.azure.com"
  mysql_name       = "mysql-${var.project_name}-${local.resource_suffix}"
  app_plan_name    = "plan-${var.project_name}-${local.resource_suffix}"
  app_service_name = "app-${var.project_name}-${local.resource_suffix}"
  kv_name          = "kv-${var.project_name}-${local.resource_suffix}" # Key Vault Name
}

# ====================== #
# Resource Group         #
# ====================== #

resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

# ====================== #
# Azure Key Vault        #
# ====================== #

resource "azurerm_key_vault" "main" {
  name                        = local.kv_name
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false # Set to true for production

  sku_name = "standard"

  # Access policy for the user running Terraform
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Purge"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Purge"
    ]
  }

  tags = var.tags
}

# Store MySQL Password in Key Vault
resource "azurerm_key_vault_secret" "mysql_password" {
  name         = "mysql-admin-password"
  value        = var.mysql_admin_password
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags
}

# ====================== #
# Virtual Network        #
# ====================== #

resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# App Service Subnet (with delegation)
resource "azurerm_subnet" "app" {
  name                 = local.app_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.app_subnet_cidr]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Database Subnet (with delegation)
resource "azurerm_subnet" "database" {
  name                 = local.db_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.db_subnet_cidr]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ====================== #
# Private DNS Zone       #
# ====================== #

resource "azurerm_private_dns_zone" "mysql" {
  name                = local.dns_zone_name
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "mysql-vnet-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = true
  tags                  = var.tags

  depends_on = [
    azurerm_private_dns_zone.mysql,
    azurerm_virtual_network.main
  ]
}

# ====================== #
# MySQL Flexible Server  #
# ====================== #

resource "azurerm_mysql_flexible_server" "main" {
  name                = local.mysql_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password

  sku_name = var.mysql_sku
  version  = var.mysql_version

  # Network integration
  delegated_subnet_id = azurerm_subnet.database.id
  private_dns_zone_id = azurerm_private_dns_zone.mysql.id

  # Storage configuration
  storage {
    size_gb = var.mysql_storage_size_gb
    iops    = 360 # Minimum for B1ms
  }

  # Backup configuration
  backup_retention_days        = var.mysql_backup_retention_days
  geo_redundant_backup_enabled = false # Not available on burstable tier

  tags = var.tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.mysql
  ]

  # Lifecycle management: Azure auto-assigns availability zone on creation
  # Student subscriptions may not support explicit zone selection (zone = null causes errors)
  # Ignore changes to prevent Terraform from attempting to modify immutable zone attribute
  lifecycle {
    ignore_changes = [zone]
  }
}

# ======================== #
# MySQL Server Configuration #
# ======================== #

# Disable SSL requirement for WordPress Docker image compatibility
# The official wordpress:latest image uses plain MySQL connections by default (no SSL)
# Security mitigation: Database is VNet-integrated with no public access
# Production recommendation: Re-enable SSL and configure WordPress with SSL certificates
resource "azurerm_mysql_flexible_server_configuration" "require_secure_transport" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "OFF"

  depends_on = [
    azurerm_mysql_flexible_server.main
  ]
}

# WordPress Database
resource "azurerm_mysql_flexible_database" "wordpress" {
  name                = var.wordpress_db_name
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"

  depends_on = [
    azurerm_mysql_flexible_server_configuration.require_secure_transport
  ]
}

# ====================== #
# App Service Plan       #
# ====================== #

resource "azurerm_service_plan" "main" {
  name                = local.app_plan_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  os_type  = "Linux"
  sku_name = var.app_service_plan_sku

  tags = var.tags
}

# ====================== #
# Linux Web App (Docker) #
# ====================== #

resource "azurerm_linux_web_app" "main" {
  name                = local.app_service_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  # Enable Managed Identity
  identity {
    type = "SystemAssigned"
  }

  # VNet Integration
  virtual_network_subnet_id = azurerm_subnet.app.id

  site_config {
    # Production settings
    always_on              = true
    vnet_route_all_enabled = true

    # Docker container configuration
    application_stack {
      docker_image_name   = var.docker_image
      docker_registry_url = "https://index.docker.io"
    }
  }

  # WordPress configuration via environment variables
  app_settings = {
    # Database connection
    WORDPRESS_DB_HOST = azurerm_mysql_flexible_server.main.fqdn
    WORDPRESS_DB_USER = var.mysql_admin_username
    # Key Vault Reference for Password
    WORDPRESS_DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.mysql_password.id})"
    WORDPRESS_DB_NAME     = var.wordpress_db_name

    # WordPress settings
    WORDPRESS_CONFIG_EXTRA = <<-EOT
      define('WP_HOME', 'https://${local.app_service_name}.azurewebsites.net');
      define('WP_SITEURL', 'https://${local.app_service_name}.azurewebsites.net');
    EOT

    # Container settings
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "true"

    # Monitoring
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
  }

  tags = var.tags

  depends_on = [
    azurerm_mysql_flexible_database.wordpress,
    azurerm_application_insights.main
  ]
}

# Grant App Service Access to Key Vault
resource "azurerm_key_vault_access_policy" "app_service" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}
