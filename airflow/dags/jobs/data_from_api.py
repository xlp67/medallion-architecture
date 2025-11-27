import yfinance as yf
import pandas as pd
import json

def normalize_df(df: pd.DataFrame):
    df = df.copy()
    for col in df.columns:
        if df[col].dtype == "object":
            df[col] = df[col].apply(
                lambda x: json.dumps(x) if isinstance(x, (dict, list)) else x
            )
    return df

def get_bq_schema_from_df(df: pd.DataFrame):
    type_map = {
        "object": "STRING",
        "float64": "FLOAT",
        "int64": "INTEGER",
        "bool": "BOOLEAN",
        "datetime64[ns]": "TIMESTAMP",
        "datetime64[ns, tz]": "TIMESTAMP",
    }
    schema = []
    for col, dtype in df.dtypes.items():
        dtype_str = str(dtype)
        bq_type = type_map.get(dtype_str, "STRING")

        schema.append({
            "name": col,
            "type": bq_type,
            "mode": "NULLABLE"
        })
    return schema


def get_current_data(symbol: str):
    ticker = yf.Ticker(symbol)
    data = ticker.get_info()
    return pd.DataFrame([data])
