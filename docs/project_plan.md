# CSI ORIGIN 2026: Autonomous Financial Management for Variable-Income Users
## Implementation Plan & Documentation

### 1. Goal Description
To build an agentic AI financial management system that continuously transforms fragmented financial information into an evolving model of a user's financial state and uses that model to proactively identify risks, opportunities, and appropriate financial actions for variable-income users.

### 2. Context & Background (Notes)
- **Target Audience:** Gig workers, freelancers, informal-sector workers, young earners (users with highly variable income and irregular expenses).
- **Current Situation:** Financial data is fragmented (bank accounts, SMS, bills, receipts, investments). Users struggle to maintain a consistent understanding of their overall financial position.
- **Limitations of Current Solutions:** 
  - They are static dashboards for tracking *historical* transactions.
  - They require high manual effort (categorization, budgeting, monitoring).
  - They are reactive; the user must interpret data and decide on actions.
- **The Core Need:** A system that can continuously construct and maintain a coherent model of a user's evolving financial state from fragmented sources, accounting for:
  - Income variability
  - Recurring obligations
  - Discretionary spending
  - Upcoming expenses & savings goals
  - Investment activity
- **Why it matters now:** Variable income patterns are rising. Managing complex, fragmented finances requires continuous interpretation of changing circumstances, not just looking at the past.

### 3. The Problem Statement Analysis (Notes)
- **What is missing:** The transition from *financial tracking* to *autonomous financial decision support*. There is no autonomous layer that proactively determines when to intervene without being explicitly told by the user.
- **The Difficulty:** 
  - **Complexity:** Income fluctuates, expenses are irregular, obligations hit at different times, and user priorities conflict.
  - **Data Quality:** The system must operate reliably even if the data is incomplete or noisy.
  - **User Experience (UX):** Bad assumptions lead to inappropriate recommendations. Too many alerts will cause notification fatigue.
- **The Consequences of Inaction:** Users will fail to anticipate cash-flow shortfalls, overlook abnormal spending, delay decisions, and misallocate funds.

### 4. The Challenge & Requirements (Notes)
- **Core Task:** Design an **agentic AI** system that doesn't just passively track, but actively reasons and advises.
- **Key Capabilities Required:**
  - **Perception:** Ingesting and interpreting heterogeneous data (SMS, APIs, receipts, bills).
  - **Reasoning:** Evaluating current and projected conditions under uncertainty and incomplete info.
  - **Prioritization:** Balancing competing financial objectives.
  - **Decision Support:** Providing proactive, contextual, and explainable advice.
- **Strict Constraints / Requirements:**
  1. **Heterogeneous Data:** Must integrate transaction data, SMS, bills, receipts, and investments.
  2. **Comprehensive State Evaluation:** Must account for variable income, obligations, discretionary spending, upcoming expenses, savings, and investments.
  3. **Proactivity:** Must act without explicit user prompting.
  4. **Personalization & Explainability:** Advice must not be generic. It must align with user risk tolerance/preferences and explain *why* it's being suggested.
  5. **Resilience:** Must remain useful despite incomplete/noisy data, uncertain future income, changing behaviors, or competing goals.

### 5. Detailed Rules & Final Constraints (Notes)
These are the strict engineering guidelines we must follow:
- **Rule 1 (Data Interpretation):** The system must handle duplicated, delayed, or noisy data. *Crucially*, it must not treat inferred or uncertain information as confirmed facts without warning the user.
- **Rule 2 (Income Variability):** The forecasting models must assume income is unpredictable, not fixed. All projections must account for earnings uncertainty.
- **Rule 3 (Obligations vs. Discretionary):** The model must distinctly separate fixed/recurring obligations (rent, subscriptions) from discretionary spending (eating out) when calculating "safe to spend" amounts.
- **Rule 4 (Competing Objectives):** The AI must evaluate decisions holistically, not in isolation. E.g., if a user has a savings goal but an impending cash shortfall, the AI must prioritize these based on logic and user preferences.
- **Rule 5 (Explainability):** The AI must respect the user's risk tolerance and always provide the *why* behind a suggestion.

### 6. Team Distribution (4 Members) & Parallel Workflow
To ensure all 4 members can work in parallel without blocking each other, the architecture is divided into 4 independent microservices/modules. **Crucial:** Define JSON API contracts between these modules on Day 1 so each member can use mock data while waiting for others.

#### Member 1: Data & Ingestion Engineer (Perception Layer)
*   **Role:** Turn messy, heterogeneous inputs into clean, structured JSON.
*   **Tasks:**
    *   Build the SMS parsing logic (regex/NLP to extract amounts, dates, vendors).
    *   Integrate OCR for scanned receipts and bills.
    *   Build a deduplication & noise-filtering script.
*   **Output:** A standard JSON stream of events (`Transaction`, `Bill_Received`, `Income_Received`).
*   **Handoff:** Sends this clean data to Member 2.

#### Member 2: Backend & State Engineer (State & Forecasting Layer)
*   **Role:** Maintain the dynamic "State of the User" and predict the future.
*   **Tasks:**
    *   Set up the database (PostgreSQL/MongoDB) to store user states, goals, and history.
    *   Build the categorization engine (Discretionary vs. Recurring).
    *   Develop the probabilistic forecasting model to predict variable income for the next 30 days.
*   **Output:** A "State API" that Member 3 and Member 4 can query to get the user's *current* balance, *projected* cash flow, and *upcoming* bills.
*   **Handoff:** Provides the API to Members 3 & 4. (M2 uses mock inputs until M1 is ready).

#### Member 3: AI / Agentic Engineer (The "Brain")
*   **Role:** Proactive reasoning, conflict resolution, and explainable interventions.
*   **Tasks:**
    *   Build the Agent pipeline (using LangChain/LlamaIndex or custom LLM logic).
    *   Write the system prompts and reasoning loops that ingest the "State API" (from M2) to detect risks (e.g., shortfall next week) and prioritize objectives.
    *   Ensure the AI respects user risk tolerance and formats explanations clearly.
*   **Output:** An "Intervention Stream" (alerts, advice, and the *why*).
*   **Handoff:** Provides the advice stream API to Member 4. (M3 uses mock "State API" data until M2 is ready).

#### Member 4: Frontend & UI/UX Developer (Presentation Layer)
*   **Role:** Build the user-facing application (Web or Mobile).
*   **Tasks:**
    *   Build a feed/chat interface for the AI's proactive alerts (consuming M3's API).
    *   Build dynamic visualizers for the evolving financial state (consuming M2's API).
    *   Build a profile setup page (to capture risk tolerance and goals).
- [ ] **Phase 5: User Interface (UI)**
  - Build a chat-based or feed-based interface where the agent proactively pushes insights, alongside a basic view of the evolving financial model.
- [ ] **Phase 6: Voice & Empathy Integration (ElevenLabs - Bonus/Extra Points)**
  *Note: To be executed once the core MVP (Phases 1-5) is functional.*
  **What we are doing with ElevenLabs:**
  1.  **Proactive Audio Alerts:** When Member 3 (The Agent) generates a "High Severity" alert (e.g., an upcoming cash shortfall), the system will use the ElevenLabs TTS API to generate a highly empathetic, natural-sounding audio file of the explanation. The frontend will display a "Listen" button (or autoplay if configured) to read the warning aloud.
  2.  **Conversational Query (Stretch Goal):** Allow the user to press a microphone button and ask, "Can I afford to go to a concert this weekend?" The Agent processes the request, and ElevenLabs speaks the contextual answer back.

### 7. Technical Architecture & Tech Stack (Proposed)
To move fast during the hackathon, we will standardize on the following tech stack:

*   **Frontend (Member 4):** 
    *   **Framework:** Next.js (React) + Tailwind CSS.
    *   **Voice Integration:** HTML5 Web Audio API to play ElevenLabs audio streams.
*   **Backend & State API (Member 2):**
    *   **Framework:** Python (FastAPI) - Chosen for fast development and seamless integration with AI libraries.
    *   **Database:** Supabase (PostgreSQL) - Fast setup, handles relational financial state perfectly.
*   **Agentic Brain (Member 3):**
    *   **Framework:** Python + LangChain (or LlamaIndex).
    *   **LLM:** OpenAI (GPT-4o) or Anthropic (Claude 3.5 Sonnet) for the reasoning loop.
    *   **Voice:** ElevenLabs Python SDK for generating TTS audio files.
*   **Data Ingestion (Member 1):**
    *   **Framework:** Python (FastAPI/Serverless).
    *   **Tools:** Tesseract (for receipt OCR), Twilio API (for mocking SMS interception).

---
*Note: This concludes the full analysis of Problem Statement 1 and the team delegation plan.*
