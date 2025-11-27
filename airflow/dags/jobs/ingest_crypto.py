import yfinance as yf
import pandas as pd
import os, base64, json
from google.cloud import bigquery
from google.oauth2 import service_account
from pyspark.sql import DataFrame, SparkSession
from dotenv import load_dotenv

load_dotenv('/home/thiago/Documentos/Code/medallion-architecture/airflow/config/.env.gcp')
PROJECT_ID = os.getenv('PROJECT_ID')
BIGQUERY_API_KEY = os.getenv('BIGQUERY_API_KEY')
BIGQUERY_TABLE_BRONZE_LAYER = os.getenv('BIGQUERY_TABLE_BRONZE_LAYER')



# def preco_atual_btc(symbol: str = 'BTC-USD'):
#     return yf.Ticker(symbol).info


credentials = service_account.Credentials.from_service_account_info(json.loads(base64.b64decode(BIGQUERY_API_KEY)))
client = bigquery.Client(credentials=credentials)

datasets = [dataset.dataset_id for dataset in client.list_datasets()]
print(datasets)