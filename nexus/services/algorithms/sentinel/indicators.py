"""
Technical indicator calculations for SENTINEL algorithm.
All functions take numpy arrays of price data and return indicator values.
Uses TA-Lib for performance-critical computations.
"""
import numpy as np
import talib
from typing import Optional


def compute_ema(closes: np.ndarray, period: int) -> np.ndarray:
    return talib.EMA(closes, timeperiod=period)


def compute_rsi(closes: np.ndarray, period: int = 14) -> np.ndarray:
    return talib.RSI(closes, timeperiod=period)


def compute_macd(closes: np.ndarray):
    """Returns (macd_line, signal_line, histogram)."""
    return talib.MACD(closes, fastperiod=12, slowperiod=26, signalperiod=9)


def compute_bollinger(closes: np.ndarray, period: int = 20, nbdevup: float = 2.0, nbdevdn: float = 2.0):
    """Returns (upper_band, middle_band, lower_band)."""
    return talib.BBANDS(closes, timeperiod=period, nbdevup=nbdevup, nbdevdn=nbdevdn)


def compute_atr(highs: np.ndarray, lows: np.ndarray, closes: np.ndarray, period: int = 14) -> np.ndarray:
    return talib.ATR(highs, lows, closes, timeperiod=period)


def compute_adx(highs: np.ndarray, lows: np.ndarray, closes: np.ndarray, period: int = 14) -> np.ndarray:
    return talib.ADX(highs, lows, closes, timeperiod=period)


def compute_obv(closes: np.ndarray, volumes: np.ndarray) -> np.ndarray:
    return talib.OBV(closes, volumes.astype(float))


def compute_all(prices: list[dict]) -> dict:
    """
    Compute full indicator set from a list of OHLCV dicts.
    Returns a dict of indicator arrays, all NaN-padded to same length.
    """
    closes = np.array([p["close"] for p in prices], dtype=float)
    highs = np.array([p["high"] for p in prices], dtype=float)
    lows = np.array([p["low"] for p in prices], dtype=float)
    volumes = np.array([p["volume"] for p in prices], dtype=float)

    ema9 = compute_ema(closes, 9)
    ema21 = compute_ema(closes, 21)
    ema50 = compute_ema(closes, 50)
    ema200 = compute_ema(closes, 200)
    rsi = compute_rsi(closes, 14)
    macd, macd_signal, macd_hist = compute_macd(closes)
    bb_upper, bb_mid, bb_lower = compute_bollinger(closes)
    atr = compute_atr(highs, lows, closes, 14)
    adx = compute_adx(highs, lows, closes, 14)
    obv = compute_obv(closes, volumes)

    # Volume moving average (20-period)
    vol_ma20 = talib.SMA(volumes, timeperiod=20)

    return {
        "closes": closes,
        "highs": highs,
        "lows": lows,
        "volumes": volumes,
        "ema9": ema9,
        "ema21": ema21,
        "ema50": ema50,
        "ema200": ema200,
        "rsi": rsi,
        "macd": macd,
        "macd_signal": macd_signal,
        "macd_hist": macd_hist,
        "bb_upper": bb_upper,
        "bb_mid": bb_mid,
        "bb_lower": bb_lower,
        "atr": atr,
        "adx": adx,
        "obv": obv,
        "vol_ma20": vol_ma20,
    }


def is_valid(arr: np.ndarray, idx: int = -1) -> bool:
    """Check that the array value at index is not NaN."""
    return arr is not None and len(arr) > abs(idx) and not np.isnan(arr[idx])
