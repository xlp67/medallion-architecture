from google.cloud import bigquery
from google.oauth2 import service_account
import os
from dotenv import load_dotenv


load_dotenv('/opt/airflow/config/.env.gcp')
PROJECT_ID = os.getenv('PROJECT_ID')

def get_bq_client():
    try:
        credential = service_account.Credentials.from_service_account_file('/opt/airflow/config/sa-key.json')
        client = bigquery.Client(credentials=credential)
        print(f"✅ CONECTADO! Projeto: {client}")
        return client
    except:
        print('Erro ao se conectar!')
        return None
        