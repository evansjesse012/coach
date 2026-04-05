# Deployment Guide

Step-by-step: from code to a working app on your iPhone home screen.

## Option A: Deploy via v0.dev (Fastest)

### Step 1: Set up on v0.dev

1. Go to [v0.dev](https://v0.dev) and sign in
2. Create a new project
3. Paste the contents of `CoachFinal.jsx` into `app/page.jsx`
4. Create the file `app/api/chat/route.js` and paste the contents of `api-route.js`
5. The app should render in the preview immediately (AI features won't work yet — that's expected)

### Step 2: Deploy to Vercel

1. Click "Deploy" in v0.dev — it creates a Vercel project automatically
2. Go to your Vercel dashboard → select the project
3. Navigate to **Settings → Environment Variables**
4. Add: `ANTHROPIC_API_KEY` = your Anthropic API key (starts with `sk-ant-`)
5. Click **Redeploy** (the first deploy won't have the key, so redeploy is required)

### Step 3: Verify deployment

Open your deployed URL (e.g., `https://coach-xyz.vercel.app`) and test:

- [ ] App loads with the home tab
- [ ] Light/dark mode toggle works in Settings
- [ ] Can add a goal (e.g., 70.3 Triathlon, Sep 20 2026)
- [ ] Training plan appears on Plan tab after adding a goal
- [ ] Can log a workout manually on the Log tab
- [ ] Quick capture (⚡ button) parses "45 min easy run" correctly
- [ ] Coach tab: send a message, get a response
- [ ] Coach tab: say "I just did a 45 min easy run" — workout gets logged
- [ ] Push message generates on Home tab (tap ↻ if it doesn't auto-generate)
- [ ] Settings: personality switch changes push message style
- [ ] Learn tab: research a topic, article saves to library

### Step 4: Add to iPhone home screen

1. Open the deployed URL in Safari on your iPhone
2. Tap the Share button (box with arrow)
3. Scroll down and tap **Add to Home Screen**
4. Name it "Coach" and tap Add
5. The app now opens full-screen without the Safari toolbar

## Option B: Deploy via Git + Vercel CLI

If you prefer version control:

```bash
# Create the project
npx create-next-app@latest coach --js --no-tailwind --no-eslint --app --src-dir=false
cd coach

# Replace the default page
cp /path/to/CoachFinal.jsx app/page.jsx

# Create the API route
mkdir -p app/api/chat
cp /path/to/api-route.js app/api/chat/route.js

# Add environment variable
echo "ANTHROPIC_API_KEY=sk-ant-your-key-here" > .env.local

# Test locally
npm run dev
# Open http://localhost:3000

# Deploy
npx vercel
# Follow prompts, then set env var in Vercel dashboard
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_API_KEY` | Yes | Your Anthropic API key. Get one at [console.anthropic.com](https://console.anthropic.com) |

The API key is only used server-side in the API route. It never reaches the browser.

## PWA Behavior on iPhone

When added to the home screen, the app behaves like a native app:

- Opens full-screen (no Safari toolbar)
- Has its own app switcher entry
- Splashscreen uses the page background color

### Limitations

- **No push notifications** — iOS PWAs support push notifications as of iOS 16.4, but it requires a service worker and VAPID key setup. Not implemented yet.
- **No background refresh** — The push message only refreshes when you open the app.
- **localStorage risk** — Safari may clear localStorage after 7 days of inactivity. Don't rely on the PWA as your only data store until Supabase is wired up.

## Custom Domain (Optional)

1. In Vercel → Settings → Domains
2. Add your domain (e.g., `coach.yourdomain.com`)
3. Update DNS as instructed (CNAME record)
4. Vercel handles SSL automatically

## Monitoring

### API costs

Each coach interaction makes 1-5 API calls to Claude claude-sonnet-4-20250514. Rough costs for personal use:

- Chat message with tool use: ~2000-4000 input tokens, ~500-1000 output tokens per round
- Push message generation: ~3000-5000 input tokens across 4 tool rounds
- Memory extraction: ~1500 input tokens, ~300 output tokens (runs ~55% of conversations)
- Knowledge article: ~500 input tokens, ~1500 output tokens

At personal use levels (5-10 interactions/day), expect roughly $3-8/month.

### Vercel

The free Vercel tier handles personal use easily. The API route is a serverless function that runs for <5 seconds per call. No persistent server.

## Troubleshooting

**"API error 401"** — Your `ANTHROPIC_API_KEY` is missing or wrong. Check Vercel → Settings → Environment Variables and redeploy.

**"API error 429"** — Rate limited by Anthropic. Wait a minute and try again. If persistent, check your Anthropic usage dashboard.

**App is blank / white screen** — Check the browser console for errors. Most common cause: a syntax error introduced during editing.

**Push message not generating** — Requires at least one logged workout. Log a workout, then tap the ↻ button on the home screen coaching card.

**Dark mode colors look wrong after switching** — Known issue with the mutable theme system. Navigate away from the current tab and back, or reload the app.
