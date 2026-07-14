# JomFest — Content-Based Filtering Recommendation Engine

**File:** `lib/recommendation_service.dart`  
**Last updated:** 2026-07-01

---

## Overview

JomFest uses a **content-based filtering** approach to recommend upcoming events to each user. There is no collaboration between users — the system builds a personal taste profile from the logged-in user's explicit interests and implicit behaviour (views, bookmarks, purchases), then ranks every available event by how closely it matches that profile using **cosine similarity**.

---

## Feature Vector (17 dimensions)

Every event and every user is represented as a 17-dimensional numerical vector.

| Index | Dimension | Values |
|-------|-----------|--------|
| 0–9   | Category (one-hot) | Music, Food & Drink, Arts & Culture, Sports, Technology, Family, Health & Wellness, Business, Comedy, Education |
| 10–12 | Event type (one-hot) | In Person, Virtual, Hybrid |
| 13    | Free ticket | 1.0 if price == 0 |
| 14    | Budget tier | 1.0 if 0 < price ≤ RM50 |
| 15    | Mid tier | 1.0 if RM50 < price ≤ RM100 |
| 16    | Premium tier | 1.0 if price > RM100 |

Each event either uses a pre-computed `featureVector` stored in Firestore, or synthesises one on the fly from its `category`, `type`, and `ticketPrice` fields.

---

## Building the User Taste Vector

```
userVector = Σ(explicit interests × 1.0) + Σ(interaction featureVector × weight)
```

### Step 1 — Explicit interests
The user's profile interests (set during registration) each add **1.0** to the corresponding category dimension.

```
interests = ["Music", "Arts & Culture"]
→ vector[0] += 1.0   (Music)
→ vector[2] += 1.0   (Arts & Culture)
```

### Step 2 — Implicit signals (behavioural weights)

| Interaction type | Weight |
|-----------------|--------|
| `view`          | 0.3    |
| `search_click`  | 0.5    |
| `bookmark`      | 0.8    |
| `purchase`      | **3.0** |

Each interaction fetches the feature vector of the event the user engaged with, then adds `featureVector × weight` to the accumulating user vector. This means **buying a ticket to an Arts & Culture event** adds 3.0 to `vector[2]` — far outweighing passive views (0.3 each).

If an interaction has no stored `featureVector` (e.g. seed/legacy data), the engine synthesises one from the interaction's `category` and `eventType` fields so no signal is silently lost.

### Step 3 — Normalise to unit length
The accumulated vector is L2-normalised (divided by its magnitude), producing a unit vector that represents direction of taste rather than volume of activity. This makes cosine similarity meaningful regardless of how active a user is.

```dart
magnitude = sqrt(Σ vᵢ²)
normalised[i] = vector[i] / magnitude
```

---

## Scoring Events (Cosine Similarity)

For each candidate event, its feature vector is compared to the user vector:

```
score = (userVector · eventVector) / (|userVector| × |eventVector|)
```

Range: **0.0** (no overlap) → **1.0** (perfect match).

Because the user vector is already unit-length, the formula simplifies to:

```
score = userVector · eventVector / |eventVector|
```

Only events with `score > 0.05` are kept (noise threshold).

---

## Filtering Rules (applied before scoring)

1. **Status filter** — only `status == 'published'` events are fetched from Firestore.
2. **Already purchased** — events the user has a `purchase` interaction for are excluded entirely (no point recommending something they already bought).
3. **Past events** — events whose `startDate` is before today are skipped. Date format is `d/M/yyyy` (e.g. `26/6/2026`). Events with `startDate == null` or `'TBA'` are treated as upcoming.

---

## Output

After scoring, all remaining events are sorted descending by score. The **top 10** are returned to the UI.

The UI (`_ForYouPageState`) applies a second past-event filter as a safety net for any cached data, then shows the final list.

---

## Data Flow

```
Firestore: interactions (uid == currentUser)
         ↓
buildUserVector(interests, interactions)
         ↓ 17-dim unit vector
         
Firestore: events (status == 'published')
         ↓ filter past + already purchased
         ↓ _eventVector() → 17-dim vector
         
cosineSimilarity(userVector, eventVector)
         ↓ score > 0.05
         
sort desc → top 10 → ForYouPage
```

---

## Firestore Collections Used

| Collection     | Fields read |
|---------------|-------------|
| `interactions` | `uid`, `type`, `eventId`, `featureVector`, `category`, `eventType` |
| `events`       | `status`, `startDate`, `featureVector`, `category`, `type`, `ticketPrice` |

Interaction documents are written by `PaymentScreen` (on purchase) and by event view/bookmark handlers.

---

## Limitations & Possible Improvements

- **Cold start** — new users with no interactions and no profile interests get no recommendations (`hasSignal == false`). Could fall back to showing top-rated or trending events.
- **No recency decay** — an interaction from 6 months ago carries the same weight as yesterday's. Could multiply weight by `exp(-days_since / 30)`.
- **Single purchase signal per category** — buying two Music events doubles the Music score vs. one; this is intentional (repeat behaviour = strong preference).
- **Price dimension sparsity** — only one price bucket fires per event, so price matching contributes at most 1/17 of the dot product.
