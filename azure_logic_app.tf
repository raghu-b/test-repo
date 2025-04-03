# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

# Define variables
variable "resource_group_name" {
  type    = string
  default = "logic-app-rg"
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "logic_app_name" {
  type    = string
  default = "excel-to-sql-logic-app"
}

variable "storage_account_name" {
  type    = string
  default = "yourstorageaccountname" # Replace with your actual storage account name
}

variable "storage_container_name" {
  type    = string
  default = "excel-container" # Replace with your actual container name
}

variable "sql_server_name" {
  type    = string
  default = "your-sql-server-name" # Replace with your SQL Server name
}

variable "sql_database_name" {
  type    = string
  default = "your-sql-database-name" # Replace with your SQL Database name
}

variable "sql_username" {
  type    = string
  default = "your-sql-username" # Replace with your SQL username
}

variable "sql_password" {
  type    = string
  default = "your-sql-password" # Replace with your SQL password
  sensitive = true
}

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Create Logic App Workflow
resource "azurerm_logic_app_workflow" "logic_app" {
  name                = var.logic_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }
}

# Logic App Definition (replace with your actual Logic App definition)
resource "azurerm_logic_app_workflow" "logic_app" {
  name                = var.logic_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }

  definition = jsonencode({
    "$schema" = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
    contentVersion = "1.0.0.0"
    parameters = {
      "$connections" = {
        defaultValue = {}
        type = "Object"
      }
    }
    triggers = {
      "When_a_blob_is_added_or_modified_(properties_only)" = {
        recurrence = {
          frequency = "Minute"
          interval = 5
        }
        splitOn = "@triggerBody()"
        type = "ApiConnection"
        inputs = {
          host = {
            connection = {
              name = "@parameters('$connections')['azureblob']['connectionId']"
            }
          }
          method = "get"
          path = "/datasets/default/triggers/batch/onupdatedfile"
          queries = {
            folderPath = "/"
            maxFileCount = 1
            notificationUrl = "https://logic-apis.azure.com/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.Logic/workflows/<logic_app_name>/triggers/When_a_blob_is_added_or_modified_(properties_only)/callback"
            pollForEmptyFile = false
          }
        }
      }
    }
    actions = {
      "Get_blob_content" = {
        runAfter = {}
        type = "ApiConnection"
        inputs = {
          host = {
            connection = {
              name = "@parameters('$connections')['azureblob']['connectionId']"
            }
          }
          method = "get"
          path = "/datasets/default/files/@{encodeURIComponent(triggerBody()?['name'])}/content"
        }
      }
      "Insert_row" = {
        runAfter = {
          "Get_blob_content" = [
            "Succeeded"
          ]
        }
        type = "ApiConnection"
        inputs = {
          host = {
            connection = {
              name = "@parameters('$connections')['sql']['connectionId']"
            }
          }
          method = "post"
          body = {
            // Map Excel columns to SQL table columns here
            Column1 = "value1"
            Column2 = "value2"
          }
          path = "/datasets/default/tables/TableName/items" // Replace TableName
        }
      }
    }
  })

  parameters = jsonencode({
    "$connections" = {
      value = {
        azureblob = {
          id = "/subscriptions/<subscription_id>/providers/Microsoft.Web/locations/${var.location}/managedApis/azureblob"
          connectionId = "/subscriptions/<subscription_id>/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/connections/azureblob"
          connectionName = "azureblob-connection"
        }
        sql = {
          id = "/subscriptions/<subscription_id>/providers/Microsoft.Web/locations/${var.location}/managedApis/sql"
          connectionId = "/subscriptions/<subscription_id>/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/connections/sql"
          connectionName = "sql-connection"
        }
      }
    }
  })
}
