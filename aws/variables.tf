variable "zip_path" {
  description = "Local path to the zip package to deploy (on the machine running terraform)."
  type        = string
  default     = "../artifacts/dist/app-aws.zip"
}

variable "region" {
  description = "aws region"
  type        = string
  default     = "ap-south-1"
}

variable "name_prefix" {
  description = "Lab Prefix name."
  type        = string
  default     = "cloud-red-lab"
}

variable "flag2" {
  description = "Contents of Flag 2 (stored in Blob)."
  type        = string
  sensitive   = true
  default     = "flag{flag2_hash}"
}

variable "flag3" {
  description = "Flag 3 contents for the SSM."
  type        = string
  sensitive   = true
  default = "flag{flag3_hash}"
}

variable "flag4" {
  description = "Final CTF flag to store in the DB"
  type        = string
  default     = "flag{flag4_hash}"
}
