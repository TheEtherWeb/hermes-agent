from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    polygon_api_key: str = ""
    finnhub_api_key: str = ""
    newsapi_key: str = ""
    redis_url: str = "redis://localhost:6379"
    timescale_url: str = "postgresql://nexus:nexus_dev@localhost:5432/nexus"
    mongodb_url: str = "mongodb://nexus:nexus_dev@localhost:27017/nexus?authSource=admin"
    watched_symbols: str = "AAPL,MSFT,GOOGL,TSLA,NVDA"
    enable_sec_feed: bool = False

    @property
    def symbols(self) -> List[str]:
        return [s.strip().upper() for s in self.watched_symbols.split(",")]

    class Config:
        env_file = ".env"


settings = Settings()
