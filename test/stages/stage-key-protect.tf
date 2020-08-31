module "dev_key_protect" {
  source = "./module"

  resource_group_name      = var.resource_group_name
  resource_location        = var.region
  name_prefix              = var.name_prefix
  provision                = true
  cluster_name             = module.dev_cluster.name
  cluster_config_file_path = module.dev_cluster.config_file_path
  tools_namespace          = module.dev_capture_state.namespace
}
