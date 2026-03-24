"""Shared Pydantic models used across all algorithms."""
from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import datetime


class Tick(BaseModel):
    symbol: str
    open: float
    high: float
    low: float
    close: float
    volume: int
    vwap: Optional[float] = None
    source: str = "polygon"
    ts: int  # milliseconds since epoch


class Prediction(BaseModel):
    symbol: str
    algorithm: Literal["SENTINEL", "ORACLE", "PHANTOM"]
    direction: Literal[-1, 0, 1]      # -1=SELL, 0=HOLD, 1=BUY
    confidence: float = Field(ge=0.0, le=1.0)
    price_at_signal: float
    price_target: Optional[float] = None
    horizon_minutes: int = 60
    feature_weights: Optional[dict] = None
    iteration: Optional[int] = None


class SentimentScore(BaseModel):
    symbol: str
    positive: float
    negative: float
    neutral: float
    weighted_score: float       # WSS = P(pos)*conf - P(neg)*conf, range [-1, 1]
    velocity: float = 0.0       # rate of change over last window
    article_count: int = 0
    computed_at: datetime


class Regime(BaseModel):
    symbol: str
    regime: Literal[
        "STRONG_TREND",
        "EVENT_DRIVEN",
        "MEAN_REVERTING",
        "HIGH_VOLATILITY",
        "LOW_CONVICTION",
    ]
    adx: float
    hurst: float
    atr_ratio: float        # current ATR / 20-day avg ATR
    news_spike: bool
    weights: dict           # {"SENTINEL": 0.5, "ORACLE": 0.25, "PHANTOM": 0.25}
    classified_at: datetime


class ConsensusPrediction(BaseModel):
    symbol: str
    direction: Literal[-1, 0, 1]
    direction_label: Literal["LONG", "SHORT", "NEUTRAL"]
    price_target: Optional[float]
    confidence: float
    timeframe: Literal["1D", "3D", "1W", "2W", "1M"]
    algo_agreement: float       # 0.33–1.0
    algo_weights: dict
    regime: str
    # Risk fields (populated by risk engine)
    risk_score: Optional[int] = None
    risk_level: Optional[str] = None
    position_size: Optional[float] = None
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    var_95: Optional[float] = None
    var_99: Optional[float] = None
    scenarios: Optional[dict] = None
