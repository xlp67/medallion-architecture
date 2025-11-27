module "google_project" {
  source = "./modules/gcp/project"
  project_id = "medallion-finance"
}

module "medallion_dataset" {
  source = "./modules/gcp/bigquery/dataset"
  dataset_id = "medallion_dataset"
  project_id = module.google_project.project_id
  depends_on = [module.google_project]
}

module "bronze_layer" {
  source = "./modules/gcp/bigquery/table"
  table_id = "bronze_layer"
  project_id = module.google_project.project_id
  dataset_id = module.medallion_dataset.dataset_id
  depends_on = [module.medallion_dataset]
}

module "local" {
  source = "./modules/local"
  region = var.region
  project_id = module.google_project.project_id
  dataset_id = module.medallion_dataset.dataset_id
  table_id = module.bronze_layer.table_id
  depends_on = [module.bronze_layer]
}


