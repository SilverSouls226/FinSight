# Member 2: Financial State & Forecasting Engine

This module is responsible for the **Financial Digital Twin**. It ingests normalized financial events, updates a SQLite database, runs probabilistic forecasting (Monte Carlo simulation), and exposes the `Financial State Snapshot` to the AI Brain and Mobile App.

## How to run
1. Install dependencies: `pip install -r requirements.txt`
2. Run the server: `uvicorn app.main:app --reload`
