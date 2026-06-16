/**
 * JomFest Firestore seeder.
 *
 * Bulk-inserts ~25 demo events under the "events" collection. All events are
 * attributed to a single fake organiser (`jomfest-official`) and marked
 * `status: "published"` so they appear immediately in the app.
 *
 * Each event defines a `tiers` array of `{ name, price }` ticket categories
 * (e.g. VIP / Cat 1 / Cat 2). The seeder writes that array as `ticketTiers`
 * and also stores `ticketPrice` = the lowest tier price for backward
 * compatibility with listings, the admin dashboard and the recommendation
 * feature vector. Free events use a single `{ name: 'Free Entry', price: 0 }`.
 *
 * Usage:
 *   1. Download your Firebase Admin service account key and save it as
 *      `serviceAccountKey.json` in this folder (see README for steps).
 *   2. `npm install`
 *   3. `npm run seed`     -> inserts all demo events
 *      `npm run clear`    -> deletes every event created by the seeder
 */

const admin = require('firebase-admin');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'serviceAccountKey.json');

try {
  // eslint-disable-next-line global-require, import/no-dynamic-require
  const serviceAccount = require(SERVICE_ACCOUNT_PATH);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
} catch (err) {
  console.error(
    '\n❌ Could not load serviceAccountKey.json.\n' +
      '   Download it from Firebase Console -> Project settings ->\n' +
      '   Service accounts -> "Generate new private key", then save\n' +
      `   the file as:\n   ${SERVICE_ACCOUNT_PATH}\n`,
  );
  process.exit(1);
}

const db = admin.firestore();

const ORGANIZER_UID = 'jomfest-official';
const ORGANIZER_NAME = 'JomFest Official';

// Must match the Flutter client (organizer_dashboard.dart).
const CATEGORIES = [
  'Music',
  'Food & Drink',
  'Arts & Culture',
  'Sports',
  'Technology',
  'Family',
  'Health & Wellness',
  'Business',
  'Comedy',
  'Education',
];
const TYPES = ['In Person', 'Virtual', 'Hybrid'];

function buildFeatureVector(category, type, price) {
  const vec = new Array(17).fill(0);

  const catIdx = CATEGORIES.indexOf(category);
  if (catIdx >= 0) vec[catIdx] = 1;

  const typeIdx = TYPES.indexOf(type);
  if (typeIdx >= 0) vec[10 + typeIdx] = 1;

  if (price === 0) vec[13] = 1;
  else if (price <= 50) vec[14] = 1;
  else if (price <= 100) vec[15] = 1;
  else vec[16] = 1;

  return vec;
}

// Lowest price across an event's ticket tiers — stored as `ticketPrice`.
function minTierPrice(tiers) {
  return tiers.reduce((m, t) => (t.price < m ? t.price : m), tiers[0].price);
}

// Shorthand for a single free-entry tier.
const FREE = [{ name: 'Free Entry', price: 0 }];

function addDays(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d;
}

function formatDate(d) {
  return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`;
}

function posterUrl(slug) {
  // picsum.photos returns the same image for a given seed — deterministic
  // and free. 800x450 is a 16:9 aspect ratio that matches the poster UI.
  return `https://picsum.photos/seed/${slug}/800/450`;
}

// ────────────────────────────────────────────────────────────────────────────
// Demo events
// ────────────────────────────────────────────────────────────────────────────

const EVENTS = [
  // ── Music ────────────────────────────────────────────────────────────────
  {
    title: 'Rainforest World Music Festival',
    description:
      'A 3-day outdoor music festival celebrating indigenous and world music in the heart of the Borneo rainforest.',
    category: 'Music',
    type: 'In Person',
    location: 'Kuching, Sarawak',
    venue: 'Sarawak Cultural Village',
    startOffset: 14,
    endOffset: 16,
    tiers: [
      { name: 'VIP', price: 600 },
      { name: 'Cat 1', price: 400 },
      { name: 'Cat 2', price: 250 },
    ],
    keywords: ['world music', 'outdoor', 'festival', 'borneo', 'culture'],
    slug: 'rainforest-music',
  },
  {
    title: 'Penang Island Jazz Festival',
    description:
      'International jazz artists performing live across two stages at Straits Quay.',
    category: 'Music',
    type: 'In Person',
    location: 'George Town, Penang',
    venue: 'Straits Quay Marina',
    startOffset: 30,
    endOffset: 31,
    tiers: [
      { name: 'VIP Lounge', price: 450 },
      { name: 'Cat 1', price: 280 },
      { name: 'Cat 2', price: 180 },
    ],
    keywords: ['jazz', 'live music', 'penang'],
    slug: 'penang-jazz',
  },
  {
    title: 'Urbanscapes 2026',
    description:
      "Malaysia's original creative arts festival — indie music, art and design in the middle of KL.",
    category: 'Music',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'MAEPS Serdang',
    startOffset: 45,
    endOffset: 46,
    tiers: [
      { name: 'VIP', price: 500 },
      { name: 'Standard', price: 220 },
    ],
    keywords: ['indie', 'urban', 'art', 'music', 'festival'],
    slug: 'urbanscapes',
  },
  {
    title: 'KL Acoustic Sessions',
    description:
      'Intimate acoustic performances from homegrown Malaysian singer-songwriters.',
    category: 'Music',
    type: 'Hybrid',
    location: 'Kuala Lumpur',
    venue: 'Publika Black Box',
    startOffset: 7,
    endOffset: 7,
    tiers: [
      { name: 'Premium Seat', price: 90 },
      { name: 'Standard', price: 45 },
    ],
    keywords: ['acoustic', 'indie', 'local'],
    slug: 'kl-acoustic',
  },

  // ── Food & Drink ─────────────────────────────────────────────────────────
  {
    title: 'KL International Food Festival',
    description:
      'Street food, chef demos and cooking competitions from across Southeast Asia.',
    category: 'Food & Drink',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'Dataran Merdeka',
    startOffset: 10,
    endOffset: 12,
    tiers: FREE,
    keywords: ['food', 'street food', 'chef', 'southeast asia'],
    slug: 'kl-food-fest',
  },
  {
    title: 'Penang Durian Festival',
    description:
      'All-you-can-eat durian tasting featuring Musang King, Red Prawn and rare local varietals.',
    category: 'Food & Drink',
    type: 'In Person',
    location: 'Balik Pulau, Penang',
    venue: 'Balik Pulau Durian Farm',
    startOffset: 20,
    endOffset: 21,
    tiers: [
      { name: 'Premium Tasting', price: 220 },
      { name: 'All-You-Can-Eat', price: 120 },
    ],
    keywords: ['durian', 'musang king', 'fruit', 'penang'],
    slug: 'durian-fest',
  },
  {
    title: 'Johor Coffee & Dessert Expo',
    description:
      'Local roasters, specialty coffee brewing workshops and dessert pop-ups.',
    category: 'Food & Drink',
    type: 'In Person',
    location: 'Johor Bahru',
    venue: 'Mid Valley Southkey',
    startOffset: 25,
    endOffset: 26,
    tiers: [
      { name: 'Connoisseur Pass', price: 75 },
      { name: 'Standard', price: 35 },
    ],
    keywords: ['coffee', 'dessert', 'specialty', 'barista'],
    slug: 'jb-coffee',
  },

  // ── Arts & Culture ───────────────────────────────────────────────────────
  {
    title: 'George Town Festival',
    description:
      'Month-long arts and culture festival celebrating the UNESCO heritage city of Penang.',
    category: 'Arts & Culture',
    type: 'In Person',
    location: 'George Town, Penang',
    venue: 'Various Heritage Venues',
    startOffset: 60,
    endOffset: 89,
    tiers: [
      { name: 'Festival Pass', price: 180 },
      { name: 'Standard', price: 80 },
    ],
    keywords: ['heritage', 'art', 'culture', 'unesco'],
    slug: 'gtf',
  },
  {
    title: 'KL Biennale: Emerging Voices',
    description:
      'Contemporary Southeast Asian visual art exhibition featuring 40+ artists.',
    category: 'Arts & Culture',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'National Art Gallery',
    startOffset: 5,
    endOffset: 90,
    tiers: [
      { name: 'Guided Tour', price: 40 },
      { name: 'Standard', price: 15 },
    ],
    keywords: ['contemporary art', 'exhibition', 'biennale'],
    slug: 'kl-biennale',
  },
  {
    title: 'Thaipusam at Batu Caves',
    description:
      'Experience the largest Thaipusam procession outside India at the iconic Batu Caves temple complex.',
    category: 'Arts & Culture',
    type: 'In Person',
    location: 'Selangor',
    venue: 'Batu Caves',
    startOffset: 40,
    endOffset: 40,
    tiers: FREE,
    keywords: ['thaipusam', 'hindu', 'festival', 'batu caves', 'culture'],
    slug: 'thaipusam',
  },
  {
    title: 'Malaysian Batik Fashion Week',
    description:
      'Runway shows, designer talks and workshops celebrating traditional Malaysian batik textiles.',
    category: 'Arts & Culture',
    type: 'Hybrid',
    location: 'Putrajaya',
    venue: 'Putrajaya International Convention Centre',
    startOffset: 35,
    endOffset: 37,
    tiers: [
      { name: 'Front Row', price: 350 },
      { name: 'Standard', price: 150 },
    ],
    keywords: ['batik', 'fashion', 'textile', 'runway'],
    slug: 'batik-fashion',
  },

  // ── Sports ───────────────────────────────────────────────────────────────
  {
    title: 'Malaysia Open Badminton 2026',
    description:
      'BWF World Tour Super 1000 event — watch the world’s best shuttlers live.',
    category: 'Sports',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'Axiata Arena, Bukit Jalil',
    startOffset: 28,
    endOffset: 33,
    tiers: [
      { name: 'VIP Courtside', price: 300 },
      { name: 'Cat 1', price: 180 },
      { name: 'Cat 2', price: 80 },
    ],
    keywords: ['badminton', 'bwf', 'tournament', 'sports'],
    slug: 'my-badminton',
  },
  {
    title: 'KL Standard Chartered Marathon',
    description:
      'Full marathon, half marathon, 10K and 5K through the iconic streets of Kuala Lumpur.',
    category: 'Sports',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'Dataran Merdeka (Start Line)',
    startOffset: 55,
    endOffset: 55,
    tiers: [
      { name: 'Full Marathon', price: 110 },
      { name: 'Half Marathon', price: 80 },
      { name: '10K', price: 50 },
      { name: '5K Fun Run', price: 35 },
    ],
    keywords: ['marathon', 'running', 'fitness', 'race'],
    slug: 'kl-marathon',
  },
  {
    title: 'Selangor Futsal Cup',
    description:
      'Amateur futsal tournament for teams across the Klang Valley.',
    category: 'Sports',
    type: 'In Person',
    location: 'Shah Alam, Selangor',
    venue: 'MBSA Futsal Complex',
    startOffset: 12,
    endOffset: 13,
    tiers: FREE,
    keywords: ['futsal', 'football', 'amateur', 'tournament'],
    slug: 'selangor-futsal',
  },

  // ── Technology ───────────────────────────────────────────────────────────
  {
    title: 'PIKOM PC Fair',
    description:
      'Malaysia’s largest IT fair — laptops, peripherals and gaming gear at unbeatable prices.',
    category: 'Technology',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'Kuala Lumpur Convention Centre',
    startOffset: 22,
    endOffset: 24,
    tiers: FREE,
    keywords: ['tech', 'laptop', 'gadgets', 'pc fair'],
    slug: 'pc-fair',
  },
  {
    title: 'Malaysia Tech Week 2026',
    description:
      'Summit bringing together Southeast Asia’s founders, investors and tech talent.',
    category: 'Technology',
    type: 'Hybrid',
    location: 'Cyberjaya',
    venue: 'MRANTI Technology Park',
    startOffset: 50,
    endOffset: 52,
    tiers: [
      { name: 'VIP Investor Pass', price: 500 },
      { name: 'Conference Pass', price: 200 },
    ],
    keywords: ['startup', 'tech', 'conference', 'cyberjaya'],
    slug: 'my-tech-week',
  },
  {
    title: 'DevFest KL 2026',
    description:
      'Community-run developer conference covering web, mobile, AI and cloud.',
    category: 'Technology',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'Menara Ken TTDI',
    startOffset: 33,
    endOffset: 33,
    tiers: [
      { name: 'Pro Pass', price: 120 },
      { name: 'Standard', price: 50 },
    ],
    keywords: ['developer', 'conference', 'flutter', 'google', 'cloud'],
    slug: 'devfest-kl',
  },

  // ── Family ───────────────────────────────────────────────────────────────
  {
    title: 'KLCC Family Fun Day',
    description:
      'Outdoor games, bouncy castles, face painting and live performances for the whole family.',
    category: 'Family',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'KLCC Park',
    startOffset: 8,
    endOffset: 8,
    tiers: FREE,
    keywords: ['family', 'kids', 'outdoor', 'games'],
    slug: 'klcc-family',
  },
  {
    title: 'Legoland Malaysia Family Weekend',
    description:
      'Special family pass weekend at Legoland including parade, fireworks and exclusive photo ops.',
    category: 'Family',
    type: 'In Person',
    location: 'Iskandar Puteri, Johor',
    venue: 'Legoland Malaysia Resort',
    startOffset: 42,
    endOffset: 43,
    tiers: [
      { name: 'Family Bundle (4 pax)', price: 650 },
      { name: '2-Day Pass', price: 280 },
      { name: '1-Day Pass', price: 180 },
    ],
    keywords: ['legoland', 'theme park', 'family', 'kids'],
    slug: 'legoland-fam',
  },

  // ── Health & Wellness ────────────────────────────────────────────────────
  {
    title: 'KL Wellness & Yoga Expo',
    description:
      'Yoga masterclasses, wellness brands and mental health talks over one weekend.',
    category: 'Health & Wellness',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'MITEC',
    startOffset: 18,
    endOffset: 19,
    tiers: [
      { name: 'All-Access', price: 130 },
      { name: 'Standard', price: 60 },
    ],
    keywords: ['wellness', 'yoga', 'mental health', 'fitness'],
    slug: 'wellness-expo',
  },
  {
    title: 'Sunrise Yoga at Langkawi',
    description:
      'Beachside sunrise yoga retreat followed by a healthy breakfast buffet.',
    category: 'Health & Wellness',
    type: 'In Person',
    location: 'Langkawi, Kedah',
    venue: 'Pantai Cenang',
    startOffset: 27,
    endOffset: 27,
    tiers: [
      { name: 'Private Session', price: 180 },
      { name: 'Standard', price: 90 },
    ],
    keywords: ['yoga', 'beach', 'sunrise', 'retreat'],
    slug: 'langkawi-yoga',
  },

  // ── Business ─────────────────────────────────────────────────────────────
  {
    title: 'Malaysia Startup Summit 2026',
    description:
      'Pitch competitions, investor panels and networking for Malaysian startup founders.',
    category: 'Business',
    type: 'Hybrid',
    location: 'Kuala Lumpur',
    venue: 'Sunway Resort Hotel',
    startOffset: 65,
    endOffset: 66,
    tiers: [
      { name: 'Investor Pass', price: 600 },
      { name: 'Founder Pass', price: 350 },
      { name: 'Standard', price: 150 },
    ],
    keywords: ['startup', 'business', 'pitch', 'investor'],
    slug: 'my-startup-summit',
  },
  {
    title: 'SME Digital Growth Forum',
    description:
      'Practical workshops to help Malaysian SMEs adopt e-commerce and digital marketing.',
    category: 'Business',
    type: 'Virtual',
    location: 'Online',
    venue: 'Zoom',
    startOffset: 9,
    endOffset: 9,
    tiers: FREE,
    keywords: ['sme', 'ecommerce', 'digital marketing', 'webinar'],
    slug: 'sme-digital',
  },

  // ── Comedy ───────────────────────────────────────────────────────────────
  {
    title: 'Malaysia Stand-Up Comedy Night',
    description:
      'Harith Iskander, Papi Zak, Kavin Jay and more on one stage for a night of belly laughs.',
    category: 'Comedy',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'HGH Convention Centre',
    startOffset: 15,
    endOffset: 15,
    tiers: [
      { name: 'VIP Front Row', price: 200 },
      { name: 'Standard', price: 95 },
    ],
    keywords: ['comedy', 'stand-up', 'malaysia'],
    slug: 'comedy-night',
  },
  {
    title: 'PJ Comedy Open Mic',
    description:
      'Weekly open mic night — amateurs and pros welcome, free entry with a drink purchase.',
    category: 'Comedy',
    type: 'In Person',
    location: 'Petaling Jaya, Selangor',
    venue: 'The Crackhouse Comedy Club',
    startOffset: 4,
    endOffset: 4,
    tiers: [{ name: 'Entry', price: 20 }],
    keywords: ['comedy', 'open mic', 'stand-up'],
    slug: 'pj-comedy',
  },

  // ── Education ────────────────────────────────────────────────────────────
  {
    title: 'International Education Fair 2026',
    description:
      'Meet representatives from 150+ universities across UK, US, Australia and Asia.',
    category: 'Education',
    type: 'In Person',
    location: 'Kuala Lumpur',
    venue: 'Mid Valley Exhibition Centre',
    startOffset: 16,
    endOffset: 17,
    tiers: FREE,
    keywords: ['education', 'university', 'study abroad'],
    slug: 'edu-fair',
  },
  {
    title: 'Malaysia Science & Robotics Fair',
    description:
      'Hands-on science experiments, robotics competitions and STEM workshops for students.',
    category: 'Education',
    type: 'In Person',
    location: 'Putrajaya',
    venue: 'National Science Centre',
    startOffset: 38,
    endOffset: 39,
    tiers: [
      { name: 'Workshop Pass', price: 45 },
      { name: 'Standard', price: 15 },
    ],
    keywords: ['science', 'stem', 'robotics', 'education', 'students'],
    slug: 'science-fair',
  },
];

// ────────────────────────────────────────────────────────────────────────────
// Seeder
// ────────────────────────────────────────────────────────────────────────────

async function seed() {
  console.log(`Seeding ${EVENTS.length} events…`);

  const batch = db.batch();

  for (const ev of EVENTS) {
    const ref = db.collection('events').doc();
    const startDate = addDays(ev.startOffset);
    const endDate = addDays(ev.endOffset);
    const minPrice = minTierPrice(ev.tiers);

    batch.set(ref, {
      organizerUid: ORGANIZER_UID,
      organizerName: ORGANIZER_NAME,
      title: ev.title,
      description: ev.description,
      category: ev.category,
      type: ev.type,
      location: ev.location,
      venue: ev.venue,
      startDate: formatDate(startDate),
      endDate: formatDate(endDate),
      ticketTiers: ev.tiers,
      ticketPrice: minPrice,
      keywords: ev.keywords,
      featureVector: buildFeatureVector(ev.category, ev.type, minPrice),
      imageUrl: posterUrl(ev.slug),
      status: 'published',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      seeded: true,
    });
  }

  await batch.commit();
  console.log(`Done — inserted ${EVENTS.length} events into "events".`);
}

async function clear() {
  console.log('Deleting all seeded events (seeded == true)…');
  const snap = await db
    .collection('events')
    .where('seeded', '==', true)
    .get();

  if (snap.empty) {
    console.log('No seeded events found.');
    return;
  }

  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  console.log(`Deleted ${snap.size} seeded events.`);
}

(async () => {
  try {
    const shouldClear = process.argv.includes('--clear');
    if (shouldClear) {
      await clear();
    } else {
      await seed();
    }
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
