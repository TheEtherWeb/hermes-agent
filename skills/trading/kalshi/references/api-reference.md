# Kalshi API Reference

Base URLs:
- **Live:** `https://trading-api.kalshi.com/trade-api/v2`
- **Demo:** `https://demo-api.kalshi.co/trade-api/v2`

## Authentication

### API Key (RSA Signing)
```
Headers:
  KALSHI-ACCESS-KEY: <key_id>
  KALSHI-ACCESS-TIMESTAMP: <unix_ms>
  KALSHI-ACCESS-SIGNATURE: <base64(RSA_PKCS1v15_SHA256(timestamp + METHOD + path))>
```

### Email/Password (Session Token)
```
POST /login
Body: {"email": "...", "password": "..."}
Response: {"token": "..."}

Then: Authorization: Bearer <token>
```

## Markets

| Method | Path | Description |
|--------|------|-------------|
| GET | `/markets` | List markets |
| GET | `/markets/{ticker}` | Single market |
| GET | `/markets/{ticker}/orderbook` | Order book |
| GET | `/markets/{ticker}/history` | Price history (candlesticks) |
| GET | `/markets/{ticker}/trades` | Recent trades |
| GET | `/events` | List events |
| GET | `/series/{series_ticker}` | Series info |

### Market Object Fields
```json
{
  "ticker": "INXD-24DEC31-B4800",
  "title": "Will S&P 500 close above 4800 on Dec 31?",
  "status": "open",
  "yes_ask": 62,
  "yes_bid": 60,
  "no_ask": 40,
  "no_bid": 38,
  "volume": 15234,
  "volume_24h": 1823,
  "open_interest": 8421,
  "close_time": "2024-12-31T21:00:00Z",
  "result": "",
  "category": "financials",
  "series_ticker": "INXD"
}
```

## Portfolio

| Method | Path | Description |
|--------|------|-------------|
| GET | `/portfolio/balance` | Account balance (cents) |
| GET | `/portfolio/positions` | Open positions |
| GET | `/portfolio/orders` | Order history |
| GET | `/portfolio/fills` | Trade fills |

## Orders

| Method | Path | Description |
|--------|------|-------------|
| POST | `/portfolio/orders` | Place order |
| GET | `/portfolio/orders/{id}` | Get order |
| DELETE | `/portfolio/orders/{id}` | Cancel order |
| PATCH | `/portfolio/orders/{id}` | Amend order |

### Place Order Body
```json
{
  "ticker": "MKTICKER",
  "action": "buy",
  "side": "yes",
  "count": 10,
  "type": "limit",
  "yes_price": 62,
  "expiration_ts": null
}
```

### Notes
- Prices are in **cents** (1-99 representing $0.01-$0.99)
- Each contract pays **$1.00** if it resolves in your favor
- `count` = number of contracts
- `action`: "buy" or "sell"
- `side`: "yes" or "no"
- `type`: "limit" or "market"
- Kalshi charges a fee on winnings (~7% of profit)

## Exchange Status

```
GET /exchange/status
Response: {"exchange_active": true, "trading_active": true}
```
