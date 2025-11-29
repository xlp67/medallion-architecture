resource "local_file" "env_file" {
  # Ajuste o caminho conforme sua estrutura de pastas
  filename = "${path.module}/../../../airflow/config/.env.gcp"

  content  = <<-EOT
    # --- Configurações Geradas pelo Terraform ---
    PROJECT_ID="${var.project_id}"
    BIGQUERY_REGION="${var.region}"
    BIGQUERY_DATASET="${var.dataset_id}"

    # --- Tabelas Dinâmicas ---
    %{ for layer, table_name in var.tables ~}
BIGQUERY_TABLE_${upper(layer)}="${table_name}"
    %{ endfor ~}

    # --- Auth ---
    GOOGLE_APPLICATION_CREDENTIALS="/opt/airflow/config/sa-key.json"
  EOT
}

# resource "null_resource" "docker_compose" {
#   provisioner "local-exec" {
#     when        = create
#     command     = "docker compose -f ../../../airflow/docker-compose.yaml up -d"
#     working_dir = path.module
#     }
#   provisioner "local-exec" {
#     when        = destroy
#     command     = "docker compose -f ../../../airflow/docker-compose.yaml down -v"
#     working_dir = path.module
#   }
#   depends_on = [local_file.env_file]
# }