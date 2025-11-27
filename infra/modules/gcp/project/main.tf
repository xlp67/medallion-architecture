resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_project" "project" {
  project_id      = "${var.project_id}-${random_id.suffix.hex}" 
  name            = "Medallion Project"
  deletion_policy = "DELETE"
}

resource "google_project_service" "apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com", 
    "iam.googleapis.com",           
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com"
  ])

  project = google_project.project.project_id
  service = each.key

  disable_on_destroy = false
}