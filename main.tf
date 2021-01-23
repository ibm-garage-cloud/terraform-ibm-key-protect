provider "ibm" {
  version = ">= 1.17.0"
  ibmcloud_api_key = var.ibmcloud_api_key
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

locals {
  name_prefix = var.name_prefix != "" ? var.name_prefix : var.resource_group_name
  name        = var.name != "" ? var.name : "${replace(local.name_prefix, "/[^a-zA-Z0-9_\\-\\.]/", "")}-keyprotect"
  bind        = (var.provision || (!var.provision && var.name != "")) && var.cluster_name != ""
  module_path = substr(path.module, 0, 1) == "/" ? path.module : "./${path.module}"
  service     = "kms"
}

resource "ibm_resource_instance" "keyprotect_instance" {
  count = var.provision ? 1 : 0

  name              = local.name
  service           = local.service
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
  service           = local.service
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

data "ibm_iam_access_group" "admin" {
  count = var.admin-access-group != "" ? 1 : 0

  access_group_name = var.admin-access-group
}

resource "ibm_iam_access_group_policy" "admin_policy" {
  count = var.admin-access-group != "" ? 1 : 0

  access_group_id = data.ibm_iam_access_group.admin[0].id
  roles           = ["Administrator", "Manager", "ReaderPlus"]
  resources {
    service           = local.service
    resource_group_id = data.ibm_resource_group.resource_group.id
  }
}

data "ibm_iam_access_group" "user" {
  count = var.user-access-group != "" ? 1 : 0

  access_group_name = var.user-access-group
}

resource "ibm_iam_access_group_policy" "user_policy" {
  count = var.user-access-group != "" ? 1 : 0

  access_group_id = data.ibm_iam_access_group.user[0].id
  roles           = ["Operator", "Reader", "ReaderPlus"]
  resources {
    service           = local.service
    resource_group_id = data.ibm_resource_group.resource_group.id
  }
}
