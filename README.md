# Astro App Pages

Static Astro site with 5 pages: Home, About, Privacy Policy, Terms of Use, and Roadmap.

## Pages

| Route | Description |
|-------|-------------|
| `/` | Index with navigation cards |
| `/about` | About Us |
| `/privacy` | Privacy Policy |
| `/terms` | Terms of Use |
| `/roadmap` | Future Updates Roadmap |

## Deploy to Vercel (3 steps)

### Option A — Vercel CLI (fastest)
```bash
npm install -g vercel
cd astro-app
npm install
vercel
```
Follow the prompts → you'll get a live URL in ~60 seconds.

### Option B — GitHub + Vercel Dashboard
1. Push this folder to a GitHub repo.
2. Go to https://vercel.com → **Add New Project** → import your repo.
3. Vercel auto-detects Astro. Click **Deploy**.
4. Done — you get a `*.vercel.app` URL instantly.

## Local development
```bash
npm install
npm run dev
```
Open http://localhost:4321
