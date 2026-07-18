# Burger Pals — online multiplayer relay (Railway)

This WebSocket relay lets friends join with a **4-digit room code** over the internet.

## How it works

- **Host** creates a room (gets a code) and can **Start Co-op alone**.
- Friends **Join with that code anytime** — lobby or mid-shift — up to **4 cooks**.
- Game packets are fully relayed (works across NAT / different networks).

## Deploy on Railway

1. In Railway → **New Project** → **Deploy from GitHub** (repo root directory = `mp_server`).
2. Railway sets `PORT` automatically — no extra env vars required.
3. After deploy: **Settings → Networking → Generate Domain**.
4. Game **Online relay** URL (WebSocket):
   - `wss://burger-pals-mp-production.up.railway.app`
   - (use `ws://` only for local testing)

Health check: open `https://YOUR-DOMAIN/` — should show  
`{"ok":true,"mid_round_join":true,"solo_host_ok":true,...}`.

**Redeploy after pulling `main`** so Railway picks up relay changes (mid-join / idle timeout).

## Local test

```bash
cd mp_server
npm install
npm start
```

Game relay URL: `ws://127.0.0.1:8080`
