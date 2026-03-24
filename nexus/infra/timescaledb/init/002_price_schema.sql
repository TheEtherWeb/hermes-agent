-- Price ticks hypertable (partitioned by time, 1 day chunks)
CREATE TABLE IF NOT EXISTS price_ticks (
    time        TIMESTAMPTZ     NOT NULL,
    symbol      TEXT            NOT NULL,
    open        NUMERIC(18,6)   NOT NULL,
    high        NUMERIC(18,6)   NOT NULL,
    low         NUMERIC(18,6)   NOT NULL,
    close       NUMERIC(18,6)   NOT NULL,
    volume      BIGINT          NOT NULL DEFAULT 0,
    vwap        NUMERIC(18,6),
    source      TEXT            NOT NULL DEFAULT 'polygon'
);

SELECT create_hypertable('price_ticks', 'time',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_price_ticks_symbol_time
    ON price_ticks (symbol, time DESC);

-- TimescaleDB compression: compress chunks older than 7 days
ALTER TABLE price_ticks SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'symbol',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('price_ticks', INTERVAL '7 days',
    if_not_exists => TRUE);

-- Continuous aggregate: 1-minute OHLCV candles (materialized view)
CREATE MATERIALIZED VIEW IF NOT EXISTS price_1m
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 minute', time) AS bucket,
    symbol,
    first(open, time)             AS open,
    max(high)                     AS high,
    min(low)                      AS low,
    last(close, time)             AS close,
    sum(volume)                   AS volume,
    avg(vwap)                     AS vwap
FROM price_ticks
GROUP BY bucket, symbol
WITH NO DATA;

SELECT add_continuous_aggregate_policy('price_1m',
    start_offset => INTERVAL '1 hour',
    end_offset   => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute',
    if_not_exists => TRUE
);
