"""
Kalshi API Client
Handles authentication and all REST API calls to the Kalshi trading platform.
Supports both demo (https://demo-api.kalshi.co) and live (https://trading-api.kalshi.com) environments.
"""

import os
import time
import json
import hashlib
import hmac
import base64
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
import httpx


KALSHI_LIVE_BASE = "https://trading-api.kalshi.com/trade-api/v2"
KALSHI_DEMO_BASE = "https://demo-api.kalshi.co/trade-api/v2"


class KalshiAPIError(Exception):
    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        self.message = message
        super().__init__(f"Kalshi API Error [{status_code}]: {message}")


class KalshiClient:
    """
    Full-featured Kalshi REST API client.

    Authentication supports two methods:
      1. API Key + RSA signing (production recommended)
      2. Email + password login (simpler, demo-friendly)

    Set env vars:
      KALSHI_API_KEY_ID    - Your API key ID
      KALSHI_PRIVATE_KEY   - PEM-encoded RSA private key (base64 or file path)
      KALSHI_EMAIL         - Account email (fallback auth)
      KALSHI_PASSWORD      - Account password (fallback auth)
      KALSHI_DEMO=true     - Use demo environment
    """

    def __init__(
        self,
        api_key_id: Optional[str] = None,
        private_key: Optional[str] = None,
        email: Optional[str] = None,
        password: Optional[str] = None,
        demo: bool = False,
    ):
        self.demo = demo or os.getenv("KALSHI_DEMO", "false").lower() == "true"
        self.base_url = KALSHI_DEMO_BASE if self.demo else KALSHI_LIVE_BASE

        self.api_key_id = api_key_id or os.getenv("KALSHI_API_KEY_ID")
        self.private_key_raw = private_key or os.getenv("KALSHI_PRIVATE_KEY")
        self.email = email or os.getenv("KALSHI_EMAIL")
        self.password = password or os.getenv("KALSHI_PASSWORD")

        self._token: Optional[str] = None
        self._token_expiry: float = 0.0
        self._client = httpx.Client(timeout=30.0)

        # Load RSA private key if available
        self._private_key = None
        if self.private_key_raw:
            self._load_private_key()

    def _load_private_key(self):
        """Load RSA private key from PEM string or file path."""
        try:
            from cryptography.hazmat.primitives.serialization import load_pem_private_key
            key_data = self.private_key_raw

            # If it's a file path
            if not key_data.startswith("-----") and os.path.exists(key_data):
                with open(key_data, "rb") as f:
                    key_data = f.read().decode()

            # If base64 encoded
            if not key_data.startswith("-----"):
                key_data = base64.b64decode(key_data).decode()

            self._private_key = load_pem_private_key(key_data.encode(), password=None)
        except ImportError:
            print("[KalshiClient] Warning: 'cryptography' package not installed. RSA auth disabled.")
        except Exception as e:
            print(f"[KalshiClient] Warning: Could not load private key: {e}")

    def _sign_request(self, method: str, path: str, timestamp_ms: int) -> str:
        """Generate HMAC-SHA256 signature for API key auth."""
        if self._private_key is None:
            return ""

        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.asymmetric import padding

        msg = f"{timestamp_ms}{method.upper()}{path}"
        signature = self._private_key.sign(
            msg.encode("utf-8"),
            padding.PKCS1v15(),
            hashes.SHA256(),
        )
        return base64.b64encode(signature).decode()

    def _get_headers(self, method: str = "GET", path: str = "") -> Dict[str, str]:
        """Build request headers with appropriate authentication."""
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

        if self.api_key_id and self._private_key:
            ts_ms = int(time.time() * 1000)
            sig = self._sign_request(method, path, ts_ms)
            headers["KALSHI-ACCESS-KEY"] = self.api_key_id
            headers["KALSHI-ACCESS-TIMESTAMP"] = str(ts_ms)
            headers["KALSHI-ACCESS-SIGNATURE"] = sig
        elif self._token:
            headers["Authorization"] = f"Bearer {self._token}"

        return headers

    def _ensure_authenticated(self):
        """Ensure we have a valid session token (email/password auth)."""
        if self._token and time.time() < self._token_expiry:
            return
        if self.email and self.password:
            self._login()

    def _login(self):
        """Login with email/password and cache the token."""
        resp = self._client.post(
            f"{self.base_url}/login",
            json={"email": self.email, "password": self.password},
        )
        if resp.status_code != 200:
            raise KalshiAPIError(resp.status_code, f"Login failed: {resp.text}")
        data = resp.json()
        self._token = data.get("token")
        # Tokens typically valid for 1 hour; we refresh 5 minutes early
        self._token_expiry = time.time() + 3300

    def _request(self, method: str, path: str, **kwargs) -> Dict[str, Any]:
        """Make an authenticated HTTP request."""
        if not (self.api_key_id and self._private_key):
            self._ensure_authenticated()

        url = f"{self.base_url}{path}"
        headers = self._get_headers(method=method, path=f"/trade-api/v2{path}")

        for attempt in range(3):
            try:
                resp = self._client.request(method, url, headers=headers, **kwargs)
                if resp.status_code == 401 and attempt == 0 and self._token:
                    # Re-auth on 401
                    self._token = None
                    self._ensure_authenticated()
                    headers = self._get_headers(method=method, path=f"/trade-api/v2{path}")
                    continue
                if resp.status_code >= 400:
                    raise KalshiAPIError(resp.status_code, resp.text)
                return resp.json()
            except httpx.TimeoutException:
                if attempt == 2:
                    raise
                time.sleep(2 ** attempt)

        return {}

    # ─── Market Data ─────────────────────────────────────────────────────────

    def get_markets(
        self,
        limit: int = 100,
        cursor: Optional[str] = None,
        event_ticker: Optional[str] = None,
        series_ticker: Optional[str] = None,
        status: str = "open",
        tickers: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """List markets with optional filters."""
        params: Dict[str, Any] = {"limit": limit, "status": status}
        if cursor:
            params["cursor"] = cursor
        if event_ticker:
            params["event_ticker"] = event_ticker
        if series_ticker:
            params["series_ticker"] = series_ticker
        if tickers:
            params["tickers"] = ",".join(tickers)
        return self._request("GET", "/markets", params=params)

    def get_market(self, ticker: str) -> Dict[str, Any]:
        """Get detailed data for a single market."""
        return self._request("GET", f"/markets/{ticker}")

    def get_market_orderbook(self, ticker: str, depth: int = 10) -> Dict[str, Any]:
        """Get the current orderbook for a market."""
        return self._request("GET", f"/markets/{ticker}/orderbook", params={"depth": depth})

    def get_market_history(
        self,
        ticker: str,
        start_ts: Optional[int] = None,
        end_ts: Optional[int] = None,
        limit: int = 1000,
    ) -> Dict[str, Any]:
        """Get candlestick price history for a market."""
        params: Dict[str, Any] = {"limit": limit}
        if start_ts:
            params["min_ts"] = start_ts
        if end_ts:
            params["max_ts"] = end_ts
        return self._request("GET", f"/markets/{ticker}/history", params=params)

    def get_market_trades(
        self,
        ticker: str,
        limit: int = 100,
        cursor: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Get recent trades for a market."""
        params: Dict[str, Any] = {"limit": limit}
        if cursor:
            params["cursor"] = cursor
        return self._request("GET", f"/markets/{ticker}/trades", params=params)

    def get_series(self, series_ticker: str) -> Dict[str, Any]:
        """Get data for a market series."""
        return self._request("GET", f"/series/{series_ticker}")

    def get_events(
        self,
        limit: int = 100,
        cursor: Optional[str] = None,
        series_ticker: Optional[str] = None,
        status: str = "open",
    ) -> Dict[str, Any]:
        """List events."""
        params: Dict[str, Any] = {"limit": limit, "status": status}
        if cursor:
            params["cursor"] = cursor
        if series_ticker:
            params["series_ticker"] = series_ticker
        return self._request("GET", "/events", params=params)

    # ─── Portfolio / Account ─────────────────────────────────────────────────

    def get_balance(self) -> Dict[str, Any]:
        """Get account balance in cents."""
        return self._request("GET", "/portfolio/balance")

    def get_positions(
        self,
        limit: int = 100,
        cursor: Optional[str] = None,
        ticker: Optional[str] = None,
        event_ticker: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Get all open positions."""
        params: Dict[str, Any] = {"limit": limit}
        if cursor:
            params["cursor"] = cursor
        if ticker:
            params["ticker"] = ticker
        if event_ticker:
            params["event_ticker"] = event_ticker
        return self._request("GET", "/portfolio/positions", params=params)

    def get_fills(self, limit: int = 100, cursor: Optional[str] = None) -> Dict[str, Any]:
        """Get trade fill history."""
        params: Dict[str, Any] = {"limit": limit}
        if cursor:
            params["cursor"] = cursor
        return self._request("GET", "/portfolio/fills", params=params)

    def get_orders(
        self,
        limit: int = 100,
        cursor: Optional[str] = None,
        ticker: Optional[str] = None,
        status: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Get order history."""
        params: Dict[str, Any] = {"limit": limit}
        if cursor:
            params["cursor"] = cursor
        if ticker:
            params["ticker"] = ticker
        if status:
            params["status"] = status
        return self._request("GET", "/portfolio/orders", params=params)

    # ─── Order Management ─────────────────────────────────────────────────────

    def place_order(
        self,
        ticker: str,
        action: str,           # "buy" or "sell"
        side: str,             # "yes" or "no"
        count: int,            # number of contracts
        order_type: str = "limit",
        yes_price: Optional[int] = None,   # cents (1-99)
        no_price: Optional[int] = None,    # cents (1-99)
        expiration_ts: Optional[int] = None,
        buy_max_cost: Optional[int] = None,
        sell_position_floor: Optional[int] = None,
        client_order_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Place a new order.

        Prices are in cents (1-99 representing 1¢ to 99¢ per contract).
        count is the number of contracts (each contract = $1 max payout).
        """
        body: Dict[str, Any] = {
            "ticker": ticker,
            "action": action,
            "side": side,
            "count": count,
            "type": order_type,
        }
        if yes_price is not None:
            body["yes_price"] = yes_price
        if no_price is not None:
            body["no_price"] = no_price
        if expiration_ts is not None:
            body["expiration_ts"] = expiration_ts
        if buy_max_cost is not None:
            body["buy_max_cost"] = buy_max_cost
        if sell_position_floor is not None:
            body["sell_position_floor"] = sell_position_floor
        if client_order_id is not None:
            body["client_order_id"] = client_order_id

        return self._request("POST", "/portfolio/orders", json=body)

    def cancel_order(self, order_id: str) -> Dict[str, Any]:
        """Cancel an open order."""
        return self._request("DELETE", f"/portfolio/orders/{order_id}")

    def get_order(self, order_id: str) -> Dict[str, Any]:
        """Get a specific order by ID."""
        return self._request("GET", f"/portfolio/orders/{order_id}")

    def amend_order(
        self,
        order_id: str,
        count: Optional[int] = None,
        yes_price: Optional[int] = None,
        no_price: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Amend an existing open order."""
        body: Dict[str, Any] = {}
        if count is not None:
            body["count"] = count
        if yes_price is not None:
            body["yes_price"] = yes_price
        if no_price is not None:
            body["no_price"] = no_price
        return self._request("PATCH", f"/portfolio/orders/{order_id}", json=body)

    # ─── Utility ──────────────────────────────────────────────────────────────

    def get_exchange_status(self) -> Dict[str, Any]:
        """Get current exchange status and trading hours."""
        return self._request("GET", "/exchange/status")

    def search_markets(self, query: str, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Search for open markets by keyword. Returns a flat list of market dicts.
        Paginates automatically up to `limit` results.
        """
        results = []
        cursor = None
        page_size = min(limit, 100)

        while len(results) < limit:
            data = self.get_markets(limit=page_size, cursor=cursor, status="open")
            markets = data.get("markets", [])
            for m in markets:
                title = (m.get("title") or m.get("event_title") or "").lower()
                if query.lower() in title:
                    results.append(m)
            cursor = data.get("cursor")
            if not cursor or not markets:
                break

        return results[:limit]

    def close(self):
        self._client.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
