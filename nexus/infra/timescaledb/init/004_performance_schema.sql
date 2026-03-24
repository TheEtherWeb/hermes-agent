-- Algorithm performance tracking (used by Phase 5 recursive engine)
CREATE TABLE IF NOT EXISTS algo_performance (
    time            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    symbol          TEXT            NOT NULL,
    algorithm       TEXT            NOT NULL,
    window_size     INTEGER         NOT NULL,      -- number of predictions evaluated
    accuracy        NUMERIC(5,4),                  -- directional accuracy 0.0–1.0
    precision_score NUMERIC(5,4),
    recall_score    NUMERIC(5,4),
    avg_confidence  NUMERIC(5,4),
    feature_weights JSONB,                         -- current weight vector
    regime          TEXT,                          -- market regime at evaluation time
    consensus_weight NUMERIC(5,4)                  -- this algo's share in consensus
);

SELECT create_hypertable('algo_performance', 'time',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_algo_performance_algo_time
    ON algo_performance (symbol, algorithm, time DESC);

-- Consensus predictions (output of cross-validator + regime weighting)
CREATE TABLE IF NOT EXISTS consensus_predictions (
    id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    time             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    symbol           TEXT            NOT NULL,
    direction        SMALLINT        NOT NULL,      -- 1=BUY, 0=HOLD, -1=SELL
    direction_label  TEXT            NOT NULL,      -- 'LONG' | 'SHORT' | 'NEUTRAL'
    price_target     NUMERIC(18,6),
    confidence       NUMERIC(5,4)    NOT NULL,
    timeframe        TEXT            NOT NULL,      -- '1D' | '3D' | '1W' | '2W' | '1M'
    algo_agreement   NUMERIC(5,4),                  -- fraction agreeing on direction
    algo_weights     JSONB,                         -- {SENTINEL, ORACLE, PHANTOM} weights used
    regime           TEXT,
    -- Risk fields (populated by risk engine)
    risk_score       INTEGER,                       -- 0–100
    risk_level       TEXT,                          -- 'LOW'|'MODERATE'|'ELEVATED'|'HIGH'|'EXTREME'
    position_size    NUMERIC(6,4),                  -- 0.00–0.15
    stop_loss        NUMERIC(18,6),
    take_profit      NUMERIC(18,6),
    var_95           NUMERIC(8,4),
    var_99           NUMERIC(8,4),
    scenarios        JSONB                          -- bull/base/bear/black_swan
);

SELECT create_hypertable('consensus_predictions', 'time',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_consensus_symbol_time
    ON consensus_predictions (symbol, time DESC);
