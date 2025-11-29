# module "google_project" {
#   source = "./modules/gcp/project"
#   project_id = "medallion-finance"
# }

module "medallion_dataset" {
  source = "./modules/gcp/bigquery/dataset"
  project_id = var.project_id
  dataset_id = "medallion_architecture"
  region = var.region
}

module "medallion_tables" {
  source   = "./modules/gcp/bigquery/table"
  for_each = var.medallion_tables
  project_id = var.project_id
  dataset_id = module.medallion_dataset.dataset_id
  table_id   = each.value
  depends_on = [module.medallion_dataset]
}

module "local" {
  source = "./modules/local"
  region     = var.region
  project_id = var.project_id
  dataset_id = module.medallion_dataset.dataset_id
  tables     = var.medallion_tables
  depends_on = [module.medallion_tables]
}