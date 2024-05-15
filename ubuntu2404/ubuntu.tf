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

variable "vm_dns_suffix" {
  description = "dns fqdn suffix for hostname"
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
  description = "vm_pass for vm"
}

variable "vm_ipaddress" {
  description = "name for vm"
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

variable "vm_dns_search" {
  type        = list(string)
  description = "dns search domains for vm"
}

variable "joindomain_username" {
  description = "username with rights to join to domain"
}

variable "joindomain_password" {
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

    # Prefer to run the VM on the primary pool instance
    affinity_host = data.xenorchestra_pool.pool.master
    network {
      network_id = data.xenorchestra_network.net.id
    }

    disk {
	  sr_id = data.xenorchestra_sr.sr.id
      name_label = "VM root volume"
      size = var.vm_disk_size
    }
	
	cloud_config = templatefile("cloud_config.tftpl", {
      hostname = var.vm_name
      domain = var.vm_dns_suffix
    })

	cloud_network_config  = templatefile("cloud_network_config.tftpl", {
    ip = "${var.vm_ipaddress}/24"
	  gw = var.vm_ipgateway
	  dns = format("[%s]", join(",", var.vm_dns_servers))
	  searchdomain = format("[%s]", join(",", var.vm_dns_search))
    })
	
    tags = var.vm_tags

    // Override the default create timeout from 5 mins to 20.
    timeouts {
      create = "20m"
    }

#set connection details for provisioners  
 connection {
    type = "ssh"
	host = var.vm_ipaddress
    user = var.vm_user
	password = var.vm_pass
  }


#wait for cloud-init
provisioner "remote-exec" {
  inline = [
    "sudo cloud-init status --wait",
	]
	on_failure = continue #a cloud-init reboot will trigger a terraform failure so we add this for it to reconnect
	connection { host = var.vm_ipaddress }
}

#once again wait for cloud-init to finish after the reboot
provisioner "remote-exec" {
  inline = [
    "sudo cloud-init status --wait",
	]
	on_failure = continue #a cloud-init reboot will trigger a terraform failure so we add this for it to reconnect
	connection { host = var.vm_ipaddress }
}


#copy scripts/required files	
#consider replacing with user_data - https://stackoverflow.com/questions/50835636/accessing-terraform-variables-within-user-data-provider-template-file
provisioner "file" {
        source = "${path.module}/join_ad_domain.sh"
        destination = "/tmp/join_ad_domain.sh"
    }

#run post build commands	
provisioner "remote-exec" {
      inline = [
	    "sudo cloud-init status --wait",
		"sudo chmod +x /tmp/join_ad_domain.sh",
		"sudo /tmp/join_ad_domain.sh ${var.joindomain_username} ${var.joindomain_password} ${var.ad_domain} ${var.ad_ou} ${var.administrators}",
		#"echo RUNNING APT UPDATES", 
		#"echo var.vm_ssh_password | sudo apt-get update",
		#"echo var.vm_ssh_password | sudo apt -y -qq upgrade",
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