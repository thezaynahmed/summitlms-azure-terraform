/*
SUMMARY:      Output Values for SummitLMS Deployment
DESCRIPTION:  Exports critical resource identifiers and connection information
AUTHOR:       Cloud Solutions Architect
VERSION:      1.0.0
*/

# ====================== #
# Resource Group Outputs #
# ====================== #

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.main.location
}

# ====================== #
# Application Outputs    #
# ====================== #

output "app_service_name" {
  description = "Name of the App Service"
  value       = azurerm_linux_web_app.main.name
}

output "app_service_url" {
  description = "URL to access the WordPress site"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "app_service_default_hostname" {
  description = "Default hostname of the App Service"
  value       = azurerm_linux_web_app.main.default_hostname
}

# ====================== #
# Database Outputs       #
# ====================== #

output "mysql_server_name" {
  description = "Name of the MySQL Flexible Server"
  value       = azurerm_mysql_flexible_server.main.name
}

output "mysql_fqdn" {
  description = "Fully qualified domain name of the MySQL server"
  value       = azurerm_mysql_flexible_server.main.fqdn
  sensitive   = true
}

output "mysql_database_name" {
  description = "Name of the WordPress database"
  value       = azurerm_mysql_flexible_database.wordpress.name
}

# ====================== #
# Monitoring Outputs     #
# ====================== #

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = azurerm_application_insights.main.name
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# ====================== #
# Network Outputs        #
# ====================== #

output "virtual_network_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "app_subnet_id" {
  description = "ID of the App Service subnet"
  value       = azurerm_subnet.app.id
}

output "database_subnet_id" {
  description = "ID of the Database subnet"
  value       = azurerm_subnet.database.id
}

# ====================== #
# Deployment Info        #
# ====================== #

output "deployment_instructions" {
  description = "Next steps after deployment"
  value       = <<-EOT
    
    ╔════════════════════════════════════════════════════════════╗
    ║          SummitLMS Deployment Successful! 🎉               ║
    ╚════════════════════════════════════════════════════════════╝
    
    WordPress URL: https://${azurerm_linux_web_app.main.default_hostname}
    
    Next Steps:
    1. Navigate to the URL above to complete WordPress installation
    2. Follow the 5-minute installation wizard
    3. Access Application Insights: ${azurerm_application_insights.main.name}
    4. View logs in Log Analytics: ${azurerm_log_analytics_workspace.main.name}
    
    Note: Initial container startup may take 3-5 minutes.
    
  EOT
}
