# Burger Pals — online multiplayer relay (Railway)

This small WebSocket server lets friends join with a **4-digit room code over the internet**.

## Deploy on Railway

1. In Railway → **New Project** → **Deploy from GitHub** (or empty project + upload this `mp_server` folder).
2. Root directory / service should be this `mp_server` folder (`package.json` here).
3. Railway sets `PORT` automatically — no extra env vars required.
4. After deploy, open the service → **Settings → Networking → Generate Domain**.
5. Copy the public URL, e.g. `https://burger-pals-mp-production.up.railway.app`
6. In the game lobby, set **Online relay** to the **WebSocket** form:
   - `wss://burger-pals-mp-production.up.railway.app`
   - (use `ws://` only for local testing)

Health check: open `https://YOUR-DOMAIN/` — should show `{"ok":true,...}`.

## Local test

```bash
cd mp_server
npm install
npm start
```

Game relay URL: `ws://127.0.0.1:8080`
