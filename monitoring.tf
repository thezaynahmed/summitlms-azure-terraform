/*
SUMMARY:      Monitoring and Observability for SummitLMS
DESCRIPTION:  Log Analytics Workspace and Application Insights for telemetry and diagnostics
AUTHOR:       Cloud Solutions Architect
VERSION:      1.0.0
*/

# ====================== #
# Log Analytics          #
# ====================== #

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku               = "PerGB2018"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ====================== #
# Application Insights   #
# ====================== #

resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project_name}-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  workspace_id = azurerm_log_analytics_workspace.main.id

  application_type = "web"

  tags = var.tags
}
