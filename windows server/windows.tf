# provider.tf
terraform {
  required_providers {
    xenorchestra = {
      source = "vatesfr/xenorchestra"
    }
  }
}

# Configure the XenServer Provider
provider "xenorchestra" {
  # Must be ws or wss
  url      = var.xoa
  username = var.xoa_user  
  password = var.xoa_pass             
  insecure = true              
}

#variables
variable "xoa" {
  description = "The hostname/ip of xoa"
}

variable "xoa_user" {
  description = "xoa user"
}

variable "xoa_pass" {
  sensitive   = true
  description = "xoa password"
}

variable "xoa_pool" {
  description = "xoa pool for vm"
}

variable "xoa_template" {
  description = "xoa template for vm"
}

variable "xoa_storage" {
  description = "xoa storage location for vm"
}

variable "xoa_net" {
  description = "xoa network for vm"
}

variable "vm_name" {
  description = "name for vm"
}

variable "vm_description" {
  description = "description for vm"
}

variable "vm_tags" {
  type        = list(string)
  description = "tags for vm"
}

variable "vm_user" {
  description = "vm_user for vm"
}

variable "vm_pass" {
  sensitive   = true
  description = "vm_pass for vm"
}

variable "vm_ipaddress" {
  description = "name for vm"
}

variable "vm_netmask" {
  description = "subnet mask for vm"
}

variable "vm_cpu_count" {
  description = "cpu count for vm in vCenter"
}

variable "vm_ram" {
  description = "memory in MB for vm in vCenter"
}

variable "vm_disk_size" {
  description = "disk size in GB for vm in vCenter"
}

variable "vm_ipgateway" {
  description = "ip gateway for vm"
}

variable "vm_dns_servers" {
  type        = list(string)
  description = "dns servers for vm"
}

variable "vm_dns_suffix" {
  description = "dns suffix for vm"
}

variable "joindomain_username" {
  description = "username with rights to join to domain"
}

variable "joindomain_password" {
  sensitive   = true
  description = "password for username with rights to join to domain"
}

variable "ad_domain" {
  description = "active directory domain"
}

variable "ad_ou" {
  description = "active directory ou to create computer object in"
}

variable "administrators" {
  description = "Domain users who will require administrative privilege on the VM"
}

# Content of the terraform files
data "xenorchestra_pool" "pool" {
    name_label = var.xoa_pool
}

data "xenorchestra_template" "template" {
    name_label = var.xoa_template
}

data "xenorchestra_sr" "sr" {
  name_label = var.xoa_storage
  pool_id = data.xenorchestra_pool.pool.id
}

data "xenorchestra_network" "net" {
  name_label = var.xoa_net
}

resource "xenorchestra_vm" "bar" {
    memory_max = var.vm_ram
    cpus  = var.vm_cpu_count
    name_label = var.vm_name
    name_description = var.vm_description
    template = data.xenorchestra_template.template.id

    # get network id from label
    network {
      network_id = data.xenorchestra_network.net.id
    }
    #first disk, size must be equal or greater than template
    disk {
	  sr_id = data.xenorchestra_sr.sr.id
      name_label = "Windows System volume"
      size = "42949672960" #40GB x 1073741824 = 42949672960
    }
	#second disk
    disk {
	  sr_id = data.xenorchestra_sr.sr.id
      name_label = "secondary disk"
      size = var.vm_disk_size
    }	
	
	cloud_config = templatefile("cloud_config.tftpl", {
      hostname = var.vm_name
      ip = var.vm_ipaddress
      netmask = var.vm_netmask	  
      gw = var.vm_ipgateway
	  dns = "${join(", ", formatlist("\"%s\"", var.vm_dns_servers))}"
	  localadminpass = var.vm_pass
      joindomain_user = var.joindomain_username
      joindomain_pass = var.joindomain_password	  
      domain = var.ad_domain
	  domain_ou = var.ad_ou
	  administrators = var.administrators
    })
	
    tags = var.vm_tags

    // Override the default create timeout from 5 mins to 20.
    timeouts {
      create = "20m"
    }

#set connection details for provisioners
 connection {
    type = "winrm"
	host = var.vm_ipaddress
	#https = true
    user = var.vm_user
	password = var.vm_pass
	timeout = "20m"
  }
  

#confirm we can connect over winrm
  provisioner "remote-exec" {
      inline = [
	  "dir c:\\",
	  "echo ####WINRM CONNECTION CONFIRMED! ONE FINAL REBOOT SCHEDULED######",
    "shutdown -r -t 5",
	  ]
  }
}

output "A_VMname" {
  value       = var.vm_name
  description = "The computer name of the instance."
}
  
output "B_IP_Address" {
  value       = var.vm_ipaddress
  description = "The private IP address of the instance."
}