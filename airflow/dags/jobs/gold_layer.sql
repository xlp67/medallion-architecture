/* CAMADA GOLD: INSTITUTIONAL QUANT ANALYTICS V2 (ROBUST)
   Engine: Google BigQuery (Standard SQL)
   Orchestrator: Apache Airflow (Jinja Templating)
   
   Objetivo: Geração de Alpha, Gestão de Risco Dinâmica e Features para ML.
*/

DROP TABLE IF EXISTS `{{ params.project_id }}.{{ params.dataset_gold }}.{{ params.table_gold }}`;

CREATE OR REPLACE TABLE `{{ params.project_id }}.{{ params.dataset_gold }}.{{ params.table_gold }}`
PARTITION BY DATE(data_evento)
CLUSTER BY ativo, data_evento
OPTIONS(
  description="Gold Layer V2: Full Quant Stack (RSI, MACD, Bollinger, VWAP, Regressão, ML Features)."
)
AS
WITH base_data AS (
    SELECT 
        ativo_ticker as ativo,
        data_evento,
        DATE(data_evento) as data_referencia,
        preco_fechamento_usd as fechamento,
        maxima_dia_usd as maxima,
        minima_dia_usd as minima,
        CAST(volume_dia_usd AS FLOAT64) as volume,
        -- Lag para cálculos de retorno e diff
        LAG(preco_fechamento_usd) OVER (PARTITION BY ativo_ticker ORDER BY data_evento) as prev_close,
        ROW_NUMBER() OVER (PARTITION BY ativo_ticker ORDER BY data_evento) as x_axis
    FROM `{{ params.project_id }}.{{ params.dataset_silver }}.{{ params.table_silver }}`
    WHERE data_evento IS NOT NULL
),

calculations_step_1 AS (
    SELECT
        *,
        -- === DIFFS PARA RSI ===
        CASE WHEN (fechamento - prev_close) > 0 THEN (fechamento - prev_close) ELSE 0 END as gain,
        CASE WHEN (fechamento - prev_close) < 0 THEN ABS(fechamento - prev_close) ELSE 0 END as loss,

        -- === TENDÊNCIA (SMAs como proxy de EMAs para performance no BigQuery) ===
        AVG(fechamento) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as fast_ma_12,
        AVG(fechamento) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 25 PRECEDING AND CURRENT ROW) as slow_ma_26,
        AVG(fechamento) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 199 PRECEDING AND CURRENT ROW) as ma_200,

        -- === ESTATÍSTICA ===
        AVG(fechamento) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as media_20,
        STDDEV(fechamento) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as stddev_20,
        
        -- === TRUE RANGE ===
        GREATEST(
            (maxima - minima), 
            ABS(maxima - prev_close), 
            ABS(minima - prev_close)
        ) as true_range,

        -- === INSTITUCIONAL ===
        SAFE_DIVIDE(
            SUM(fechamento * volume) OVER (PARTITION BY ativo, data_referencia ORDER BY data_evento),
            SUM(volume) OVER (PARTITION BY ativo, data_referencia ORDER BY data_evento)
        ) as vwap

    FROM base_data
),

calculations_step_2 AS (
    SELECT
        *,
        -- === RSI 14 (Simples) ===
        -- RSI = 100 - (100 / (1 + RS))
        SAFE_DIVIDE(
            AVG(gain) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 13 PRECEDING AND CURRENT ROW),
            AVG(loss) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 13 PRECEDING AND CURRENT ROW)
        ) as rs_ratio,

        -- === MACD ===
        (fast_ma_12 - slow_ma_26) as macd_line,

        -- === BOLLINGER BANDS (Standard) ===
        (media_20 + (2 * stddev_20)) as bb_upper,
        (media_20 - (2 * stddev_20)) as bb_lower,
        
        -- === ATR 14 ===
        AVG(true_range) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as atr_14,

        -- === REGRESSÃO LINEAR (Slope & R2) ===
        SAFE_DIVIDE(
            COVAR_POP(x_axis, fechamento) OVER (PARTITION BY ativo ORDER BY x_axis ROWS BETWEEN 19 PRECEDING AND CURRENT ROW),
            VAR_POP(x_axis) OVER (PARTITION BY ativo ORDER BY x_axis ROWS BETWEEN 19 PRECEDING AND CURRENT ROW)
        ) as slope,
        POW(CORR(fechamento, x_axis) OVER (PARTITION BY ativo ORDER BY x_axis ROWS BETWEEN 19 PRECEDING AND CURRENT ROW), 2) as r_squared,
        
        -- === Z-SCORE ===
        SAFE_DIVIDE((fechamento - media_20), stddev_20) as z_score

    FROM calculations_step_1
),

final_metrics AS (
    SELECT
        *,
        -- RSI Final Calculation
        100 - (100 / (1 + IFNULL(rs_ratio, 1))) as rsi_14,
        
        -- MACD Signal Line (9 periodos sobre a linha MACD)
        AVG(macd_line) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 8 PRECEDING AND CURRENT ROW) as macd_signal,

        -- Bollinger Bandwidth (Largura da banda - detecta compressão)
        SAFE_DIVIDE((bb_upper - bb_lower), media_20) as bb_bandwidth,

        -- Volume Relativo (RVOL)
        SAFE_DIVIDE(volume, AVG(volume) OVER (PARTITION BY ativo ORDER BY data_evento ROWS BETWEEN 19 PRECEDING AND CURRENT ROW)) as rvol,
        
        -- Intercept para projeção
        (media_20 - (slope * AVG(x_axis) OVER (PARTITION BY ativo ORDER BY x_axis ROWS BETWEEN 19 PRECEDING AND CURRENT ROW))) as intercept

    FROM calculations_step_2
)

SELECT
    data_evento,
    ativo,
    
    -- === 1. PRICE ACTION ===
    ROUND(fechamento, 2) as price_close,
    ROUND(vwap, 2) as price_vwap,
    -- Distância percentual da média de 200 (Tendência de Longo Prazo)
    ROUND(((fechamento - ma_200) / ma_200) * 100, 2) as dist_ma200_pct,
    
    -- === 2. ALPHA SIGNALS (Indicadores de Direção) ===
    ROUND(rsi_14, 1) as alpha_rsi,
    ROUND(macd_line, 4) as alpha_macd,
    ROUND(macd_signal, 4) as alpha_macd_signal,
    -- Histograma do MACD (Diferença entre linha e sinal)
    ROUND(macd_line - macd_signal, 4) as alpha_macd_hist,
    ROUND(slope, 4) as alpha_trend_slope,
    ROUND(r_squared, 4) as alpha_trend_strength,
    
    -- === 3. RISK METRICS (Gestão de Risco) ===
    ROUND(atr_14, 2) as risk_atr,
    ROUND(z_score, 2) as risk_z_score,
    ROUND(bb_bandwidth, 4) as risk_volatility_compression, -- Baixo = Squeeze, Alto = Volátil
    -- Sugestão dinâmica de Stop Loss (2x ATR abaixo do fechamento)
    ROUND(fechamento - (2 * atr_14), 2) as risk_stop_loss_long,
    ROUND(fechamento + (2 * atr_14), 2) as risk_stop_loss_short,
    
    -- === 4. ML FEATURES (Para Modelos Preditivos) ===
    -- Retorno Logarítmico (Melhor para ML que % simples)
    ROUND(LN(fechamento / NULLIF(prev_close, 0)), 5) as ml_log_return,
    ROUND(rvol, 2) as ml_relative_volume,
    -- Projeção Linear Next Tick
    ROUND(((slope * (x_axis + 1)) + intercept), 2) as ml_proj_linear_t1,

    -- === 5. DECISION SUPPORT (Classificação Humana) ===
    CASE
        WHEN bb_bandwidth < 0.05 THEN 'ALTA'
        WHEN rsi_14 > 70 AND z_score > 2 THEN 'SOBRECOMPRA EXTREMA'
        WHEN rsi_14 < 30 AND z_score < -2 THEN 'SOBREVENDA EXTREMA'
        WHEN (macd_line - macd_signal) > 0 AND slope > 0 THEN 'COMPRA (Tendência)'
        WHEN (macd_line - macd_signal) < 0 AND slope < 0 THEN 'VENDA (Tendência)'
        ELSE 'NEUTRO'
    END as decision_signal,

    -- === LLM PROMPT DATA ===
    FORMAT(
        'Ativo %s. $%.2f. RSI: %.0f. MACD Hist: %.2f. Volatilidade (ATR): %.2f. Z-Score: %.2f. Tendência (Slope): %.4f. O mercado está em %s.',
        ativo, fechamento, rsi_14, (macd_line - macd_signal), atr_14, z_score, slope,
        CASE 
            WHEN slope > 0 AND r_squared > 0.6 THEN 'Alta Forte'
            WHEN slope < 0 AND r_squared > 0.6 THEN 'Baixa Forte'
            ELSE 'Consolidação'
        END
    ) as llm_summary

FROM final_metrics;