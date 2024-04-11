packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "1.4.5"
    }
  }
}

locals {
  managed_image_name = var.managed_image_name != "" ? var.managed_image_name : "packer-${var.image_os}-${var.image_version}"
}

variable "allowed_inbound_ip_addresses" {
  type    = list(string)
  default = []
}

variable "azure_tags" {
  type    = map(string)
  default = {}
}

variable "build_resource_group_name" {
  type    = string
  default = "${env("BUILD_RESOURCE_GROUP_NAME")}"
}

variable "client_cert_path" {
  type    = string
  default = "${env("ARM_CLIENT_CERT_PATH")}"
}

variable "client_id" {
  type    = string
  default = "${env("ARM_CLIENT_ID")}"
}

variable "client_secret" {
  type      = string
  default   = "${env("ARM_CLIENT_SECRET")}"
  sensitive = true
}

variable "dockerhub_login" {
  type    = string
  default = "${env("DOCKERHUB_LOGIN")}"
}

variable "dockerhub_password" {
  type    = string
  default = "${env("DOCKERHUB_PASSWORD")}"
}

variable "helper_script_folder" {
  type    = string
  default = "/imagegeneration/helpers"
}

variable "image_folder" {
  type    = string
  default = "/imagegeneration"
}

variable "image_os" {
  type    = string
  default = "ubuntu22"
}

variable "image_version" {
  type    = string
  default = "dev"
}

variable "imagedata_file" {
  type    = string
  default = "/imagegeneration/imagedata.json"
}

variable "installer_script_folder" {
  type    = string
  default = "/imagegeneration/installers"
}

variable "install_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "location" {
  type    = string
  default = "${env("ARM_RESOURCE_LOCATION")}"
}

variable "managed_image_name" {
  type    = string
  default = ""
}

variable "managed_image_resource_group_name" {
  type    = string
  default = "${env("ARM_RESOURCE_GROUP")}"
}

variable "private_virtual_network_with_public_ip" {
  type    = bool
  default = false
}

variable "subscription_id" {
  type    = string
  default = "${env("ARM_SUBSCRIPTION_ID")}"
}

variable "temp_resource_group_name" {
  type    = string
  default = "${env("TEMP_RESOURCE_GROUP_NAME")}"
}

variable "tenant_id" {
  type    = string
  default = "${env("ARM_TENANT_ID")}"
}

variable "virtual_network_name" {
  type    = string
  default = "${env("VNET_NAME")}"
}

variable "virtual_network_resource_group_name" {
  type    = string
  default = "${env("VNET_RESOURCE_GROUP")}"
}

variable "virtual_network_subnet_name" {
  type    = string
  default = "${env("VNET_SUBNET")}"
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v4"
}

source "azure-arm" "build_image" {
  allowed_inbound_ip_addresses           = "${var.allowed_inbound_ip_addresses}"
  build_resource_group_name              = "${var.build_resource_group_name}"
  client_cert_path                       = "${var.client_cert_path}"
  client_id                              = "${var.client_id}"
  client_secret                          = "${var.client_secret}"
  image_offer                            = "0001-com-ubuntu-server-jammy"
  image_publisher                        = "canonical"
  image_sku                              = "22_04-lts"
  location                               = "${var.location}"
  managed_image_name                     = "${local.managed_image_name}"
  managed_image_resource_group_name      = "${var.managed_image_resource_group_name}"
  os_disk_size_gb                        = "75"
  os_type                                = "Linux"
  private_virtual_network_with_public_ip = "${var.private_virtual_network_with_public_ip}"
  subscription_id                        = "${var.subscription_id}"
  temp_resource_group_name               = "${var.temp_resource_group_name}"
  tenant_id                              = "${var.tenant_id}"
  virtual_network_name                   = "${var.virtual_network_name}"
  virtual_network_resource_group_name    = "${var.virtual_network_resource_group_name}"
  virtual_network_subnet_name            = "${var.virtual_network_subnet_name}"
  vm_size                                = "${var.vm_size}"

  dynamic "azure_tag" {
    for_each = var.azure_tags
    content {
      name = azure_tag.key
      value = azure_tag.value
    }
  }
}

build {
  sources = ["source.azure-arm.build_image"]

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["mkdir ${var.image_folder}", "chmod 777 ${var.image_folder}"]
  }

  provisioner "file" {
    destination = "${var.helper_script_folder}"
    source      = "${path.root}/../scripts/helpers"
  }

  provisioner "file" {
    destination = "${var.installer_script_folder}"
    source      = "${path.root}/../scripts/build"
  }

  provisioner "file" {
    destination = "${var.image_folder}"
    sources     = [
      "${path.root}/../assets/post-gen",
      "${path.root}/../scripts/tests",
      "${path.root}/../scripts/docs-gen"
    ]
  }

  provisioner "file" {
    destination = "${var.image_folder}/docs-gen/"
    source      = "${path.root}/../../../helpers/software-report-base"
  }

  provisioner "file" {
    destination = "${var.installer_script_folder}/toolset.json"
    source      = "${path.root}/../toolsets/toolset-2204.json"
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "mv ${var.image_folder}/docs-gen ${var.image_folder}/SoftwareReport",
      "mv ${var.image_folder}/post-gen ${var.image_folder}/post-generation"
    ]
  }

  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPT_FOLDER=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "IMAGE_FOLDER=${var.image_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/../scripts/build/configure-system.sh"]
  }

  provisioner "file" {
    destination = "/tmp/"
    source      = "${path.root}/../assets/ubuntu2204.conf"
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["mkdir -p /etc/vsts", "cp /tmp/ubuntu2204.conf /etc/vsts/machine_instance.conf"]
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["sleep 30", "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"]
  }

}
