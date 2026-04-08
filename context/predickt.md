# Project Context: Predickt

Prediction market trading system. Live trading on Polymarket + fast-resolution crypto contracts on Kalshi.

## Architecture
- 5-layer: Data Ingestion → Signal Generators → Blended Model → Risk/Sizing → Execution
- Fast engine: Kalshi 15-min + Polymarket 5-min crypto contracts
- Calibration: empirical, 30/90/180d rolling windows per symbol
- Hot path: ring buffers → signal generators → ML model → Kelly sizing → execution
- Current symbols: BTC, ETH, SOL

## Key Files
- `monte-carlo/fast/` — fast-resolution engine code
- `monte-carlo/ml/` — ML models (XGBoost, LR, RF), feature extraction, prediction
- `monte-carlo/ml/features.py` — 16-feature extractor (OFI, VWAP momentum, Gini, etc.)
- `monte-carlo/ml/train.py` — training pipeline with expanding-window CV
- `monte-carlo/ml/predict.py` — inference with model caching, asymmetric thresholds, quarter-Kelly
- `dashboard/` — Next.js 16 + React 19 + Tailwind v4, FastAPI backend on :8000

## Constraints
- Paper-first: new algorithms must always start paper-only before going live
- $5 flat bets, limit orders only
- DuckDB + Parquet for fast system (not SQLite — write contention)
- NEVER kill the live engine process

## Key Formats
- Kalshi 15-min: `KXBTC15M`, `KXETH15M`, `KXSOL15M`
- Polymarket 5-min: slug `{coin}-updown-5m-{unix_ts}`
