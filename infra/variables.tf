variable "region" {
  default = "us-east1"
}

variable "project_id" {
  default = "resolve-ai-407701"
}

variable "medallion_tables" {
    default     = {
        bronze = "bronze_layer"
        silver = "silver_layer"
        gold   = "gold_layer"
  }
}