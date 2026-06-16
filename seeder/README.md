# JomFest Event Seeder

Bulk-insert ~25 realistic demo events into your Firestore database so the app
has content to show without manually creating each one.

## How it works

`seed.js` uses the **Firebase Admin SDK** to write events directly to
Firestore. Because admin SDK bypasses Firebase security rules, you don't need a
real `organizer` account — every seeded event is attributed to a fake
organizer called **JomFest Official** (`organizerUid: "jomfest-official"`).

All events are marked `status: "published"` so they appear immediately on the
Discover / Featured / For You tabs. Images use deterministic
[picsum.photos](https://picsum.photos) URLs (free, no auth required).

Each seeded document also carries a `seeded: true` flag so you can safely
delete them later with `npm run clear`.

## One-time setup

### 1. Get your Firebase service account key

1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Pick your JomFest project.
3. Click the ⚙ gear icon → **Project settings** → **Service accounts** tab.
4. Press **Generate new private key** → **Generate key**.
5. Save the downloaded JSON as **`serviceAccountKey.json`** inside this
   `seeder/` folder.

> ⚠️ **Never commit** `serviceAccountKey.json` to git. It contains admin
> credentials to your whole Firebase project. The folder's `.gitignore` already
> ignores it.

### 2. Install dependencies

```bash
cd seeder
npm install
```

You'll need Node.js 18+ installed. Check with `node --version`.

## Usage

### Insert all demo events

```bash
npm run seed
```

You should see:

```
Seeding 25 events…
Done — inserted 25 events into "events".
```

Open the app — the events should appear on Discover / Featured immediately.

### Remove all demo events

```bash
npm run clear
```

Only deletes documents that have `seeded: true` on them (real events created
by organizers through the app are untouched).

## Customising

All event data lives in the `EVENTS` array inside `seed.js`. You can:

- Add, remove or edit entries
- Edit the `tiers` array (each is `{ name, price }`, e.g. VIP / Cat 1 / Cat 2).
  Use the `FREE` shorthand for free events. The seeder writes this as
  `ticketTiers` and stores `ticketPrice` = the lowest tier price.
- Change `category`, `type`, etc.
- Tweak `startOffset` / `endOffset` (days relative to today)
- Replace `slug` to change which picsum image is used (or swap the
  `posterUrl()` helper to point at another image source entirely, e.g.
  Unsplash)

The feature vector required by the recommendation engine is generated
automatically from `category`, `type` and the lowest tier price.
