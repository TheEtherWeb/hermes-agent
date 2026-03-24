export type Direction = 1 | 0 | -1;
export type DirectionLabel = "LONG" | "SHORT" | "NEUTRAL";
export type RiskLevel = "LOW" | "MODERATE" | "ELEVATED" | "HIGH" | "EXTREME";
export type Regime =
  | "STRONG_TREND"
  | "EVENT_DRIVEN"
  | "MEAN_REVERTING"
  | "HIGH_VOLATILITY"
  | "LOW_CONVICTION"
  | "UNKNOWN";

export interface AlgoPrediction {
  algorithm: "SENTINEL" | "ORACLE" | "PHANTOM";
  direction: Direction;
  confidence: number;
  price_at_signal: number;
  price_target: number | null;
  horizon_minutes: number;
  was_correct: boolean | null;
  time: string;
}

export interface ConsensusPrediction {
  direction: Direction;
  direction_label: DirectionLabel;
  price_target: number;
  confidence: number;
  timeframe: string;
  algo_agreement: number;
  algo_weights: string; // JSON
  regime: Regime;
  risk_score: number;
  risk_level: RiskLevel;
  position_size: number;
  stop_loss: number;
  take_profit: number;
  var_95: number;
  var_99: number;
  scenarios: {
    bull: ScenarioPoint;
    base: ScenarioPoint;
    bear: ScenarioPoint;
    black_swan: ScenarioPoint;
  } | null;
  time: string;
}

export interface ScenarioPoint {
  price: number;
  probability: number;
  label: string;
}

export interface SentimentData {
  wss: number;
  velocity: number;
  article_count: number;
  positive_ratio: number;
  negative_ratio: number;
  computed_at: string;
}

export interface NewsArticle {
  _id: string;
  title: string;
  source: string;
  url: string;
  published_at: string;
  sentiment?: {
    weighted_score: number;
    label: string;
    confidence: number;
  };
}
