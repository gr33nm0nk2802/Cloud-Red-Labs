variable "subscription_id" {
  description = "Subscription ID in string"
  type        = string
  default     = "" # Your Subscription ID
}

variable "resource_group_name" {
  description = "Lab Resource Group name."
  type        = string
  default     = "cloud-red-lab"
}

variable "location" {
  description = "Resource Group location"
  type        = string
  default     = "UAE North"
}

variable "zip_path" {
  description = "Local path to the zip package to deploy (on the machine running terraform)."
  type        = string
  default     = "../artifacts/dist/app.zip"
}

variable "flag2" {
  description = "Contents of Flag 2 (stored in KeyVault)."
  type        = string
  sensitive   = true
  default     = "FLAG{flag2hash}"
}

variable "flag3" {
  description = "Contents of Flag 3 (stored in Blob)."
  type        = string
  sensitive   = true
  default     = "FLAG{flag3hash}"
}

variable "flag4" {
  description = "Flag 4 contents for the VM."
  type        = string
  sensitive   = true
  default     = "FLAG{flag4hash}"
}