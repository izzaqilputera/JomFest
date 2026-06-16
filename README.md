How Match % is Calculated
Step 1 — Build a "taste profile" for the user (17 numbers)
Every user gets a 17-dimension vector representing their preferences:

Dimensions	What they represent
0–9	10 categories (Music, Food & Drink, Technology, Sports, etc.)
10–12	Event type preference (In Person, Virtual, Hybrid)
13–16	Price preference (Free, ≤RM50, ≤RM100, >RM100)
This vector is built from two signals combined:

Explicit interests — what the user selected during registration (weight: 1.0)
Behaviour — how they've interacted with events, with different weights:
Viewed an event → 0.3
Clicked from search → 0.5
Bookmarked → 0.7
Purchased → 1.5 (strongest signal)
Step 2 — Build a vector for each event (same 17 numbers)
Each published event also gets a 17-dim vector, either from a stored featureVector field in Firestore, or synthesized from its category, type, and ticketPrice fields.

Step 3 — Cosine similarity → percentage
The app measures the angle between the user vector and each event vector. The closer they point in the same direction, the higher the match:


match % = cosineSimilarity(userVector, eventVector) × 100
Events below 5% are hidden. Top 10 results are shown.

Why Everything Shows 60%
All those events showing exactly 60% match means your users have a sparse profile — either:

They registered with few interests and haven't interacted much yet, OR
The events in Firestore don't have a featureVector field stored, so they're being synthesized from just one field (category), making many events score the same
The system gets smarter the more a user bookmarks, clicks, and purchases events.
