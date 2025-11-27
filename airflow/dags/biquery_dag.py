import os
from datetime import timedelta, datetime
from airflow import DAG
from airflow.decorators import task
from dotenv import load_dotenv
import subprocess


ls = subprocess.run(['ls', '-a' , '/opt/airflow/config']).stdout
print(ls)
load_dotenv('/opt/airflow/config/.env.gcp')
PROJECT_ID = os.getenv("PROJECT_ID")
BIGQUERY_DATASET = os.getenv("BIGQUERY_DATASET") 
BIGQUERY_TABLE_BRONZE_LAYER = os.getenv("BIGQUERY_TABLE_BRONZE_LAYER")

default_args = {
    "owner": "airflow",
    "retries": 1,
    "retry_delay": timedelta(minutes=1),
}

with DAG(
    dag_id="medallion_pipeline_v1",
    schedule="* * * * *", 
    max_active_runs=1,
    start_date=datetime(2025, 11, 26),
    catchup=False,
    default_args=default_args,
    tags=["medallion", "crypto", "bigquery", "debug"],
) as dag:
    
    @task
    def extract():
        from google.cloud import bigquery
        from google.oauth2 import service_account
        from jobs.data_from_api import get_current_data, normalize_df

        key_path = "/opt/airflow/config/sa-key.json"
        if not os.path.exists(key_path):
            import glob
            files = glob.glob("/opt/airflow/config/*")
            raise FileNotFoundError("Arquivo não existe!")

        print("Arquivo de chave encontrado!")

        try:
            credentials = service_account.Credentials.from_service_account_file(key_path)
            client = bigquery.Client(credentials=credentials)
            print(f"Cliente BigQuery criado. Projeto: {client.project}")
        except Exception as e:
            print(f"Erro ao criar cliente: {e}")
            raise e
        
        symbol = "BTC-USD"
        df = get_current_data(symbol)
        df = normalize_df(df)

        if df.empty:
            print("DataFrame vazio.")
            return

        # --- 3. Carga ---
        dataset_clean = BIGQUERY_DATASET.split('.')[-1]
        full_table_id = f"{PROJECT_ID}.{dataset_clean}.{BIGQUERY_TABLE_BRONZE_LAYER}"
        
        print(f"Enviando para: {full_table_id}")

        job_config = bigquery.LoadJobConfig(
            create_disposition="CREATE_IF_NEEDED",
            write_disposition="WRITE_APPEND",
            autodetect=True,
            schema_update_options=[bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION]
        )

        job = client.load_table_from_dataframe(
            df, 
            full_table_id, 
            job_config=job_config
        )
        job.result()
        print(f"{job.output_rows} linhas inseridas.")

    extract_data = extract()