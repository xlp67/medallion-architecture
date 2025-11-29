/* CAMADA SILVER: ENRICHED MARKET DATA
   Objetivo: Sanitização, Deduplicação e Tipagem Forte com Unidades Explícitas.
   Fonte: Tabela Bronze (Raw JSON/CSV)
*/

-- 1. Limpeza de Segurança
DROP TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_silver }}.{{ params.table_silver }}`;

-- 2. Criação da Tabela Otimizada
CREATE OR REPLACE TABLE `{{ params.project_id }}.{{ params.dataset_silver }}.{{ params.table_silver }}`
PARTITION BY DATE(data_evento)
CLUSTER BY ativo_ticker, data_evento
OPTIONS(
  description="Dados de mercado limpos. Sufixos: _usd (Valor Monetário), _unid (Quantidade), _pct (Percentual)."
)
AS
SELECT
    * EXCEPT(rn)
FROM (
    SELECT
        -- === IDENTIFICAÇÃO ===
        SAFE_CAST(symbol AS STRING) AS ativo_ticker,

        -- === PREÇO E VOLATILIDADE INTRADAY (USD) ===
        -- Proteção GREATEST para evitar preços negativos (glitch de API)
        GREATEST(SAFE_CAST(regularMarketPrice AS FLOAT64), 0) AS preco_fechamento_usd,
        SAFE_CAST(regularMarketOpen AS FLOAT64) AS preco_abertura_usd,
        SAFE_CAST(regularMarketDayHigh AS FLOAT64) AS maxima_dia_usd,
        SAFE_CAST(regularMarketDayLow AS FLOAT64) AS minima_dia_usd,
        
        -- Variação percentual do dia (Ex: 1.5 para 1.5%)
        SAFE_CAST(regularMarketChangePercent AS FLOAT64) AS variacao_dia_pct,

        -- === DADOS ESTRUTURAIS DE LONGO PRAZO (52 Semanas) ===
        -- Essencial para saber se estamos no topo ou fundo histórico recente
        SAFE_CAST(fiftyTwoWeekHigh AS FLOAT64) AS maxima_52sem_usd,
        SAFE_CAST(fiftyTwoWeekLow AS FLOAT64) AS minima_52sem_usd,
        
        -- === INDICADORES TÉCNICOS DE TENDÊNCIA (Médias Móveis) ===
        -- Usados para identificar Golden Cross / Death Cross na camada Gold
        SAFE_CAST(fiftyDayAverage AS FLOAT64) AS media_movel_50d_usd,
        SAFE_CAST(twoHundredDayAverage AS FLOAT64) AS media_movel_200d_usd,

        -- === FUNDAMENTOS DE MERCADO (Liquidez e Tamanho) ===
        -- Volume financeiro transacionado (em USD)
        SAFE_CAST(regularMarketVolume AS INT64) AS volume_dia_usd,
        -- Média de volume para identificar spikes de interesse
        SAFE_CAST(averageDailyVolume10Day AS INT64) AS volume_medio_10d_usd,
        -- Capitalização de Mercado (Tamanho da moeda)
        SAFE_CAST(marketCap AS INT64) AS market_cap_usd,
        -- Supply: Quantas moedas existem em circulação
        SAFE_CAST(circulatingSupply AS FLOAT64) AS supply_circulante_unid,

        -- === CONVERSÃO TEMPORAL ===
        TIMESTAMP_SECONDS(SAFE_CAST(regularMarketTime AS INT64)) AS data_evento,

        -- === DEDUPLICAÇÃO (Mantida a lógica original robusta) ===
        ROW_NUMBER() OVER(
            PARTITION BY symbol, regularMarketTime 
            ORDER BY SAFE_CAST(regularMarketVolume AS INT64) DESC
        ) as rn

    FROM `{{ params.project_id }}.{{ params.dataset_bronze }}.{{ params.table_bronze }}`
    WHERE 
        symbol IS NOT NULL 
        AND regularMarketTime IS NOT NULL
        AND SAFE_CAST(regularMarketPrice AS FLOAT64) > 0
)
WHERE rn = 1;