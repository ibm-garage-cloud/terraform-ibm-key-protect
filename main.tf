provider "ibm" {
  version = ">= 1.9.0"
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

locals {
  name_prefix = var.name_prefix != "" ? var.name_prefix : var.resource_group_name
  name        = var.name != "" ? var.name : "${replace(local.name_prefix, "/[^a-zA-Z0-9_\\-\\.]/", "")}-keyprotect"
  bind        = (var.provision || (!var.provision && var.name != "")) && var.cluster_name != ""
  module_path = substr(path.module, 0, 1) == "/" ? path.module : "./${path.module}"
}

resource "ibm_resource_instance" "keyprotect_instance" {
  count = var.provision ? 1 : 0

  name              = local.name
  service           = "kms"
  plan              = var.plan
  location          = var.resource_location
  resource_group_id = data.ibm_resource_group.resource_group.id
  tags              = var.tags

  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}

data "ibm_resource_instance" "keyprotect_instance" {
  count             = local.bind ? 1 : 0
  depends_on        = [ibm_resource_instance.keyprotect_instance]

  name              = local.name
  resource_group_id = data.ibm_resource_group.resource_group.id
  location          = var.resource_location
  service           = "kms"
}

resource "null_resource" "keyprotect_secret" {
  count = local.bind ? 1 : 0

  triggers = {
    kubeconfig  = var.cluster_config_file_path
    namespace   = var.tools_namespace
    script_dir  = "${local.module_path}/scripts"
    instance_id = data.ibm_resource_instance.keyprotect_instance[0].guid
  }

  provisioner "local-exec" {
    command = "${self.triggers.script_dir}/create-keyprotect-secret.sh ${self.triggers.namespace} ${var.resource_location} ${self.triggers.instance_id}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      API_KEY    = var.ibmcloud_api_key
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${self.triggers.script_dir}/destroy-keyprotect-secret.sh ${self.triggers.namespace}"

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
    }
  }
}
