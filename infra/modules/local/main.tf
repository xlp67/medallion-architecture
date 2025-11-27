resource "local_file" "env_file" {
  filename = "../airflow/config/.env.gcp"
  content  = <<-EOT
    PROJECT_ID="${var.project_id}"
    BIGQUERY_REGION="${var.region}"
    BIGQUERY_DATASET="${var.project_id}.${var.dataset_id}"
    BIGQUERY_TABLE_${upper(var.table_id)} = "${var.table_id}"
    GOOGLE_APPLICATION_CREDENTIALS="/opt/airflow/config/sa-key.json"
  EOT
}

# resource "null_resource" "docker_compose" {
#   provisioner "local-exec" {
#     when        = create
#     command     = "docker compose -f ../airflow/docker-compose.yaml up -d"
#     working_dir = path.module
#     }
#   provisioner "local-exec" {
#     when        = destroy
#     command     = "docker compose -f ../airflow/docker-compose.yaml down -v"
#     working_dir = path.module
#   }
# }