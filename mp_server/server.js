#!/usr/bin/env node
/**
 * Burger Pals online room relay for Railway.
 * Hosts create a 4-digit code; joiners enter that code.
 * All game packets are relayed over WebSocket (works across the internet / NAT).
 */
const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = Number(process.env.PORT || 8080);
const MAX_PLAYERS = 2;
const ROOM_IDLE_MS = 45 * 60 * 1000;

/** @type {Map<string, { code: string, host: import('ws').WebSocket|null, client: import('ws').WebSocket|null, created: number }>} */
const rooms = new Map();

function normalizeCode(raw) {
  const digits = String(raw || "").replace(/\D/g, "");
  if (!digits) return "";
  return digits.slice(-4).padStart(4, "0");
}

function randomCode() {
  for (let i = 0; i < 64; i++) {
    const code = String(Math.floor(Math.random() * 10000)).padStart(4, "0");
    const room = rooms.get(code);
    if (!room || (!room.host && !room.client)) return code;
  }
  return String(Date.now() % 10000).padStart(4, "0");
}

function sendJson(ws, obj) {
  if (ws && ws.readyState === 1) {
    ws.send(JSON.stringify(obj));
  }
}

function clearSocketRoom(ws) {
  if (!ws || !ws.roomCode) return;
  const code = ws.roomCode;
  const room = rooms.get(code);
  if (!room) {
    ws.roomCode = null;
    ws.peerId = 0;
    return;
  }
  const other = ws.peerId === 1 ? room.client : room.host;
  if (ws.peerId === 1) room.host = null;
  if (ws.peerId === 2) room.client = null;
  if (other) {
    sendJson(other, { op: "peer_left", peer_id: ws.peerId });
  }
  if (!room.host && !room.client) {
    rooms.delete(code);
  }
  ws.roomCode = null;
  ws.peerId = 0;
}

function pruneRooms() {
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (now - room.created > ROOM_IDLE_MS && !room.host && !room.client) {
      rooms.delete(code);
    }
  }
}

const server = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        ok: true,
        service: "burger-pals-mp-relay",
        rooms: rooms.size,
      })
    );
    return;
  }
  res.writeHead(404);
  res.end("not found");
});

const wss = new WebSocketServer({ server });

wss.on("connection", (ws) => {
  ws.roomCode = null;
  ws.peerId = 0;
  ws.isAlive = true;
  ws.on("pong", () => {
    ws.isAlive = true;
  });

  sendJson(ws, { op: "hello", max_players: MAX_PLAYERS });

  ws.on("message", (data, isBinary) => {
    if (isBinary) {
      // Binary game packet: forward to the other peer in the room.
      if (!ws.roomCode) return;
      const room = rooms.get(ws.roomCode);
      if (!room) return;
      const other = ws.peerId === 1 ? room.client : room.host;
      if (other && other.readyState === 1) {
        other.send(data, { binary: true });
      }
      return;
    }

    let msg;
    try {
      msg = JSON.parse(String(data));
    } catch {
      sendJson(ws, { op: "error", msg: "bad json" });
      return;
    }
    const op = String(msg.op || "");

    if (op === "host") {
      clearSocketRoom(ws);
      pruneRooms();
      let code = normalizeCode(msg.code || "");
      if (!code) code = randomCode();
      if (rooms.has(code) && rooms.get(code).host) {
        code = randomCode();
      }
      const room = { code, host: ws, client: null, created: Date.now() };
      rooms.set(code, room);
      ws.roomCode = code;
      ws.peerId = 1;
      sendJson(ws, {
        op: "hosted",
        code,
        peer_id: 1,
        name: String(msg.name || "Host").slice(0, 24),
      });
      return;
    }

    if (op === "join") {
      clearSocketRoom(ws);
      const code = normalizeCode(msg.code || "");
      if (!code) {
        sendJson(ws, { op: "error", msg: "need 4-digit code" });
        return;
      }
      const room = rooms.get(code);
      if (!room || !room.host || room.host.readyState !== 1) {
        sendJson(ws, { op: "error", msg: `no room ${code}` });
        return;
      }
      if (room.client && room.client.readyState === 1) {
        sendJson(ws, { op: "error", msg: "room full" });
        return;
      }
      room.client = ws;
      ws.roomCode = code;
      ws.peerId = 2;
      sendJson(ws, {
        op: "joined",
        code,
        peer_id: 2,
        name: String(msg.name || "Cook").slice(0, 24),
      });
      sendJson(room.host, {
        op: "peer_joined",
        peer_id: 2,
        name: String(msg.name || "Cook").slice(0, 24),
      });
      return;
    }

    if (op === "ping") {
      sendJson(ws, { op: "pong", t: msg.t || 0 });
      return;
    }

    sendJson(ws, { op: "error", msg: "unknown op" });
  });

  ws.on("close", () => {
    clearSocketRoom(ws);
  });

  ws.on("error", () => {
    clearSocketRoom(ws);
  });
});

setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) {
      ws.terminate();
      continue;
    }
    ws.isAlive = false;
    ws.ping();
  }
  pruneRooms();
}, 25000);

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Burger Pals MP relay on :${PORT}`);
});
