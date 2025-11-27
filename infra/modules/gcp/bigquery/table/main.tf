resource "google_bigquery_table" "table" {
  project = var.project_id
  dataset_id = var.dataset_id
  table_id   = var.table_id
  deletion_protection=false
  time_partitioning {
    type = "DAY"
  }
}