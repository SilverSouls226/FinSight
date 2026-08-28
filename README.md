# FinSentinel — AI-Powered Real-Time Financial Scam Interceptor

> **Track:** FinSec & Cyber Finance | Hackathon Project

---

## Team

| Member | Domain |
|--------|--------|
| Sanjani | Twilio + Call Infrastructure (Sub-team A) |
| Skandan | Speech-to-Text + AI Scam Detection (Sub-team A) |
| Sameer | Backend + Integration |
| Kalyan | Flutter / Mobile Security Platform |

---

## Repository Structure

```
CSI/
├── docs/                   # Shared contracts and design docs
│   └── backend-contract.md # FROZEN API contract — source of truth
├── backend/                # FastAPI backend (Sameer)
├── mobile/                 # Flutter app (Kalyan)
└── web/                    # React web console + call subsystem (Sanjani/Skandan)
```

## Subteam Boundaries

- **Sub-team A** (Sanjani + Skandan): `web/` call infrastructure + AI pipeline
- **Sub-team B** (Sameer + Kalyan): `backend/` + `mobile/`
- Integration boundary: `docs/backend-contract.md`

## Quick Start

See [`backend/README.md`](backend/README.md) for backend setup.

## Frozen Contract

See [`docs/backend-contract.md`](docs/backend-contract.md) — **do not modify without team agreement**.
