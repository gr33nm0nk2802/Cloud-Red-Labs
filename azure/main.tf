terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.10.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}

provider "azuread" {
  tenant_id = data.azurerm_client_config.current.tenant_id
}

# --- Creating the Resource group for lab ---
resource "azurerm_resource_group" "lab-rg" {
  name     = var.resource_group_name
  location = var.location
}

# ---- Attack Vector: Initial Access (SSTI)
resource "azurerm_service_plan" "asp" {
  name                = "${var.resource_group_name}-app-asp"
  resource_group_name = azurerm_resource_group.lab-rg.name
  location            = azurerm_resource_group.lab-rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "app-service" {
  name                = "${var.resource_group_name}-app-${random_string.st_sfx.result}"    # Change name using variable
  resource_group_name = azurerm_resource_group.lab-rg.name
  location            = azurerm_service_plan.asp.location
  service_plan_id     = azurerm_service_plan.asp.id
  site_config {
    application_stack {
      python_version = "3.12"
    }
    minimum_tls_version = "1.2"
  }
  zip_deploy_file = var.zip_path
  app_settings = {
     SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }
  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_service_plan.asp,
    azurerm_resource_group.lab-rg
  ]
  timeouts { create = "60m" }
}

resource "azurerm_role_assignment" "mi_reader_rg" {
  scope                = azurerm_resource_group.lab-rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_web_app.app-service.identity[0].principal_id
}

resource "azurerm_role_definition" "webapp_read_only" {
  name        = "WebApp-ReadOnly-${random_string.st_sfx.result}"
  scope       = azurerm_resource_group.lab-rg.id
  description = "Can read Microsoft.Web/sites resources only."

  permissions {
    actions     = ["Microsoft.Web/sites/read"]
    not_actions = []
  }

  # Must be at or above the assignment scope (use RG or subscription)
  assignable_scopes = [
    azurerm_resource_group.lab-rg.id
  ]
}

resource "azurerm_role_assignment" "mi_read_site" {
  scope              = azurerm_linux_web_app.app-service.id
  role_definition_id = azurerm_role_definition.webapp_read_only.role_definition_resource_id
  principal_id       = azurerm_linux_web_app.app-service.identity[0].principal_id
}

# --- Storage Account ---

resource "random_string" "st_sfx" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# Storage account (internal blob)
resource "azurerm_storage_account" "internal_blob" {
  name                     = lower(replace("internalblob${random_string.st_sfx.result}", "-", ""))
  resource_group_name      = azurerm_resource_group.lab-rg.name
  location                 = azurerm_resource_group.lab-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

# Private container for flags
resource "azurerm_storage_container" "flag" {
  name                   = "flag"
  storage_account_id   = azurerm_storage_account.internal_blob.id
  container_access_type  = "private"
}

# Put flag3 blob inside the 'flag' container
resource "azurerm_storage_blob" "flag3" {
  name                   = "flag3.txt"
  storage_account_name   = azurerm_storage_account.internal_blob.name
  storage_container_name = azurerm_storage_container.flag.name
  type                   = "Block"
  content_type           = "text/plain"
  source_content         = var.flag3
}

# Generate a container-level SAS (1 year) — gives read + list on container and read on objects
# Generate a container-level SAS (1 year) — read + list on container, read on objects
data "azurerm_storage_account_sas" "flag_sas" {
  # REQUIRED by this data source:
  connection_string = azurerm_storage_account.internal_blob.primary_connection_string
  https_only        = true

  start  = timeadd(timestamp(), "-5m")
  expiry = timeadd(timestamp(), "8760h") # ~1 year

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  resource_types {
    service   = false
    container = true
    object    = true
  }

  permissions {
    read    = true
    list    = true   # list container contents
    write   = false
    delete  = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }

  depends_on = [
    azurerm_storage_blob.flag3,        # ensure blob exists before generating SAS (optional but useful)
    azurerm_storage_container.flag,
    azurerm_storage_account.internal_blob
  ]
}  

# full container SAS URL (container path + SAS token returned by data source)
locals {
  flags_container_sas_url = "https://${azurerm_storage_account.internal_blob.name}.blob.core.windows.net/${azurerm_storage_container.flag.name}/${azurerm_storage_blob.flag3.name}${data.azurerm_storage_account_sas.flag_sas.sas}"
}

# --- Create KeyVault ---
resource "azurerm_key_vault" "lab_kv" {
  name                       = "corpVault-${random_string.st_sfx.result}"
  location                   = azurerm_resource_group.lab-rg.location
  resource_group_name        = azurerm_resource_group.lab-rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"

  soft_delete_retention_days = 7
  purge_protection_enabled   = false
}

resource "azurerm_key_vault_access_policy" "me" {
  key_vault_id = azurerm_key_vault.lab_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge"
  ]
}

resource "azurerm_key_vault_secret" "flags_sas" {
  name         = "flags-container-sas"
  key_vault_id = azurerm_key_vault.lab_kv.id
  value        = local.flags_container_sas_url

  depends_on = [azurerm_key_vault.lab_kv,azurerm_key_vault_access_policy.me]
}

resource "azurerm_key_vault_secret" "flag2" {
  name         = "flag"
  key_vault_id = azurerm_key_vault.lab_kv.id
  value        = var.flag2

  depends_on = [azurerm_key_vault.lab_kv,azurerm_key_vault_access_policy.me]
}

# --- MI Read KeyVault ---
resource "azurerm_role_assignment" "webapp_kv_read" {
  scope                = azurerm_key_vault.lab_kv.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_linux_web_app.app-service.identity[0].principal_id
}


resource "azurerm_key_vault_access_policy" "webapp_kv_read" {
  key_vault_id = azurerm_key_vault.lab_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.app-service.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  depends_on = [
    azurerm_linux_web_app.app-service,
    azurerm_key_vault.lab_kv
  ]
}

# --- Create BkpUser User ---
# Get a verified domain from the tenant
# Get a verified domain from the tenant
data "azuread_domains" "verified" {
  # one (or more) of: only_initial, only_default, only_verified
  only_default = false
}

locals {
  bkp_upn = "bkpuser@${data.azuread_domains.verified.domains[0].domain_name}"
}

resource "random_password" "bkpuser" {
  length  = 20
  special          = true
  override_special = "!#$%&*()-_=+[]:?"
  keepers = {
    upn = local.bkp_upn
  }
}

resource "azuread_user" "limited_user" {
  user_principal_name    = local.bkp_upn
  display_name           = "Backup User"
  password               = random_password.bkpuser.result
  force_password_change  = false
  account_enabled        = true
}

# --- Store credentials on blob ---
resource "azurerm_storage_blob" "bkpuser_creds" {
  name                   = "bkpuser-creds.json"
  storage_account_name   = azurerm_storage_account.internal_blob.name
  storage_container_name = azurerm_storage_container.flag.name
  type                   = "Block"
  content_type           = "application/json"

  # Store both UPN and password (newline-safe)
  source_content = jsonencode({
    upn      = azuread_user.limited_user.user_principal_name
    password = random_password.bkpuser.result
  })

  depends_on = [
    azuread_user.limited_user,                 # make sure the user is created first
    azurerm_storage_container.flag
  ]
}


# --- Create VM ---
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_group_name}-vnet"
  location            = azurerm_resource_group.lab-rg.location
  resource_group_name = azurerm_resource_group.lab-rg.name
  address_space       = ["10.50.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.lab-rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.50.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.resource_group_name}-nsg"
  location            = azurerm_resource_group.lab-rg.location
  resource_group_name = azurerm_resource_group.lab-rg.name
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.resource_group_name}-vm-nic"
  location            = azurerm_resource_group.lab-rg.location
  resource_group_name = azurerm_resource_group.lab-rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "tls_private_key" "vm" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

locals {
  cloud_init = <<-EOF
  #cloud-config
  write_files:
    - path: /opt/flags/flag4.txt
      content: "${replace(var.flag4, "\"", "\\\"")}"
      owner: root:root
      permissions: '0600'
  runcmd:
    - mkdir -p /opt/flags
    - chown root:root /opt/flags
    - chmod 700 /opt/flags
  EOF
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "jump-vm" # rename
  resource_group_name = azurerm_resource_group.lab-rg.name
  location            = azurerm_resource_group.lab-rg.location
  size                = "Standard_B1s"
  admin_username      = "labadmin"
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "labadmin"
    public_key = tls_private_key.vm.public_key_openssh
  }

  os_disk {
    name                 = "${var.resource_group_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(local.cloud_init)
}

resource "azurerm_role_assignment" "bkp_vm_contrib" {
  scope                = azurerm_linux_virtual_machine.vm.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azuread_user.limited_user.object_id
}

output "webapp_url" {
  # default_site_hostname is like myapp.azurewebsites.net
  value = "https://${azurerm_linux_web_app.app-service.default_hostname}"
}
