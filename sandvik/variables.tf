variable "location" {
  description = "Azure region where resources will be created."
  type        = string
  default     = "East US"
}

variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
  default     = "pg18lab"
}

variable "resource_group_name" {
  description = "Resource Group name."
  type        = string
  default     = "rg-pg18-lab"
}

variable "vnet_cidr" {
  description = "CIDR block for the VNet."
  type        = string
  default     = "10.50.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1."
  type        = string
  default     = "10.50.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2."
  type        = string
  default     = "10.50.2.0/24"
}

variable "admin_username" {
  description = "Admin username for the Linux VM."
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key content for VM access."
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN4yu0MNApSqmpJTuOsNR4oJPkI0e1Lz6OM1O5qzU8zy wagnerbianchi@macbook-tigerdata.local"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the VM."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
  default     = 64
}

variable "tags" {
  description = "Common tags applied to supported Azure resources."
  type        = map(string)

  default = {
    environment = "lab"
    managed_by  = "terraform"
    workload    = "postgresql18"
    project     = "timescaledb-lab"
    owner       = "Bianchi"
  }
}