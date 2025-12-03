/*
SUMMARY:      Variable Definitions for SummitLMS Infrastructure
DESCRIPTION:  All configurable parameters for the WordPress deployment on Azure
AUTHOR:       Cloud Solutions Architect
VERSION:      1.0.0
*/

# ==================== #
# Project Metadata     #
# ==================== #

variable "project_name" {
  description = "Name of the project - used as prefix for resource naming"
  type        = string
  default     = "summitlms"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region for all resources (hardcoded to canadacentral for student subscription)"
  type        = string
  default     = "canadacentral"
}

# ==================== #
# Governance Tags      #
# ==================== #

variable "tags" {
  description = "Mandatory tags for all resources"
  type        = map(string)
  default = {
    CostCenter = "000"
    Project    = "SummitLMS"
    Owner      = "Zain"
  }
}

# ==================== #
# Networking           #
# ==================== #

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_subnet_cidr" {
  description = "CIDR block for App Service subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR block for Database subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# ==================== #
# Database (MySQL)     #
# ==================== #

variable "mysql_admin_username" {
  description = "Administrator username for MySQL Flexible Server"
  type        = string
  default     = "sqladmin"
}

variable "mysql_admin_password" {
  description = "Administrator password for MySQL Flexible Server"
  type        = string
  sensitive   = true
}

variable "mysql_sku" {
  description = "MySQL Flexible Server SKU (burstable tier for student subscription)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "mysql_version" {
  description = "MySQL server version"
  type        = string
  default     = "8.0.21"
}

variable "mysql_storage_size_gb" {
  description = "MySQL storage size in GB"
  type        = number
  default     = 20
}

variable "mysql_backup_retention_days" {
  description = "Number of days to retain MySQL backups"
  type        = number
  default     = 7
}

variable "wordpress_db_name" {
  description = "WordPress database name"
  type        = string
  default     = "wordpress"
}

# ==================== #
# App Service          #
# ==================== #

variable "app_service_plan_sku" {
  description = "App Service Plan SKU (B1 for student subscription)"
  type        = string
  default     = "B1"
}

variable "docker_image" {
  description = "Docker image for WordPress container"
  type        = string
  default     = "wordpress:latest"
}

variable "wordpress_container_start_time_limit" {
  description = "Seconds to wait for WordPress container to start"
  type        = number
  default     = 300
}

# ==================== #
# WordPress Settings   #
# ==================== #

variable "wordpress_admin_email" {
  description = "WordPress admin email address"
  type        = string
  default     = "admin@summitlms.local"
}

variable "wordpress_site_title" {
  description = "WordPress site title"
  type        = string
  default     = "SummitLMS - Learning Management System"
}

# ==================== #
# Monitoring           #
# ==================== #

variable "log_retention_days" {
  description = "Log Analytics workspace retention in days"
  type        = number
  default     = 30
}
