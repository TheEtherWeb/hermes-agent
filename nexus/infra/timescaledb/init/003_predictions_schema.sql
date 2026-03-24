-- Algorithm predictions table
CREATE TABLE IF NOT EXISTS predictions (
    id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    time             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    symbol           TEXT            NOT NULL,
    algorithm        TEXT            NOT NULL,      -- 'SENTINEL' | 'ORACLE' | 'PHANTOM'
    direction        SMALLINT        NOT NULL,      -- 1=BUY, 0=HOLD, -1=SELL
    confidence       NUMERIC(5,4)    NOT NULL,      -- 0.0000 to 1.0000
    price_at_signal  NUMERIC(18,6)   NOT NULL,
    price_target     NUMERIC(18,6),
    horizon_minutes  INTEGER         NOT NULL DEFAULT 60,
    -- Filled in by accuracy tracker after horizon elapses
    outcome          SMALLINT,                      -- 1=correct, 0=incorrect
    outcome_time     TIMESTAMPTZ,
    price_at_outcome NUMERIC(18,6),
    was_correct      BOOLEAN,
    -- Internal self-correction metadata
    feature_weights  JSONB,                         -- algo's weight vector at signal time
    iteration        INTEGER
);

SELECT create_hypertable('predictions', 'time',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_predictions_symbol_algo_time
    ON predictions (symbol, algorithm, time DESC);

CREATE INDEX IF NOT EXISTS idx_predictions_accuracy
    ON predictions (algorithm, was_correct, time DESC)
    WHERE was_correct IS NOT NULL;
