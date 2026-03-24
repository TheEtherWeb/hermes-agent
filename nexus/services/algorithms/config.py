from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    redis_url: str = "redis://localhost:6379"
    timescale_url: str = "postgresql://nexus:nexus_dev@localhost:5432/nexus"
    mongodb_url: str = "mongodb://nexus:nexus_dev@localhost:27017/nexus?authSource=admin"

    finbert_model: str = "ProsusAI/finbert"
    finbert_device: str = "cpu"

    arima_max_order: int = 5
    monte_carlo_paths: int = 1000

    cross_validate_every_n: int = 10
    regime_classify_every_n: int = 50
    meta_learning_window: int = 500
    max_allocation: float = 0.15

    watched_symbols: str = "AAPL,MSFT,GOOGL,TSLA,NVDA"

    @property
    def symbols(self) -> List[str]:
        return [s.strip().upper() for s in self.watched_symbols.split(",")]

    class Config:
        env_file = ".env"


settings = Settings()
