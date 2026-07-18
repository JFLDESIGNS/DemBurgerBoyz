#!/usr/bin/env node
/**
 * Burger Pals online room relay for Railway.
 * Hosts create a 4-digit code; up to 4 cooks can join (including mid-round).
 * All game packets are relayed over WebSocket (works across the internet / NAT).
 */
const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = Number(process.env.PORT || 8080);
const MAX_PLAYERS = 4;
const ROOM_IDLE_MS = 45 * 60 * 1000;
const HEADER_SIZE = 10;

/**
 * @typedef {{ code: string, peers: Map<number, import('ws').WebSocket>, created: number }} Room
 * @type {Map<string, Room>}
 */
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
    if (!room || room.peers.size === 0) return code;
  }
  return String(Date.now() % 10000).padStart(4, "0");
}

function sendJson(ws, obj) {
  if (ws && ws.readyState === 1) {
    ws.send(JSON.stringify(obj));
  }
}

function readU32(buf, offset) {
  return buf[offset] | (buf[offset + 1] << 8) | (buf[offset + 2] << 16) | (buf[offset + 3] << 24);
}

function alivePeers(room) {
  /** @type {number[]} */
  const ids = [];
  for (const [id, sock] of room.peers) {
    if (sock && sock.readyState === 1) ids.push(id);
  }
  return ids.sort((a, b) => a - b);
}

function nextPeerId(room) {
  for (let id = 1; id <= MAX_PLAYERS; id++) {
    const sock = room.peers.get(id);
    if (!sock || sock.readyState !== 1) return id;
  }
  return 0;
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
  const leftId = ws.peerId;
  room.peers.delete(leftId);
  for (const [, other] of room.peers) {
    if (other && other.readyState === 1) {
      sendJson(other, { op: "peer_left", peer_id: leftId });
    }
  }
  if (room.peers.size === 0) {
    rooms.delete(code);
  }
  ws.roomCode = null;
  ws.peerId = 0;
}

function pruneRooms() {
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (now - room.created > ROOM_IDLE_MS && room.peers.size === 0) {
      rooms.delete(code);
    }
  }
}

function forwardBinary(ws, data) {
  if (!ws.roomCode) return;
  const room = rooms.get(ws.roomCode);
  if (!room) return;
  if (!Buffer.isBuffer(data) && !(data instanceof Uint8Array)) return;
  const buf = Buffer.from(data);
  if (buf.length < HEADER_SIZE) return;
  const target = readU32(buf, 5);
  if (target === 0) {
    for (const [id, other] of room.peers) {
      if (id === ws.peerId) continue;
      if (other && other.readyState === 1) {
        other.send(buf, { binary: true });
      }
    }
    return;
  }
  const dest = room.peers.get(target);
  if (dest && dest.readyState === 1 && target !== ws.peerId) {
    dest.send(buf, { binary: true });
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
        max_players: MAX_PLAYERS,
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
      forwardBinary(ws, data);
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
      const existing = rooms.get(code);
      if (existing && existing.peers.has(1) && existing.peers.get(1)?.readyState === 1) {
        code = randomCode();
      }
      /** @type {Room} */
      const room = { code, peers: new Map(), created: Date.now() };
      rooms.set(code, room);
      room.peers.set(1, ws);
      ws.roomCode = code;
      ws.peerId = 1;
      sendJson(ws, {
        op: "hosted",
        code,
        peer_id: 1,
        max_players: MAX_PLAYERS,
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
      if (!room || !room.peers.has(1) || room.peers.get(1)?.readyState !== 1) {
        sendJson(ws, { op: "error", msg: `no room ${code}` });
        return;
      }
      const peerId = nextPeerId(room);
      if (!peerId) {
        sendJson(ws, { op: "error", msg: "room full" });
        return;
      }
      room.peers.set(peerId, ws);
      ws.roomCode = code;
      ws.peerId = peerId;
      const others = alivePeers(room).filter((id) => id !== peerId);
      sendJson(ws, {
        op: "joined",
        code,
        peer_id: peerId,
        max_players: MAX_PLAYERS,
        peers: others,
        name: String(msg.name || "Cook").slice(0, 24),
      });
      for (const id of others) {
        const other = room.peers.get(id);
        sendJson(other, {
          op: "peer_joined",
          peer_id: peerId,
          name: String(msg.name || "Cook").slice(0, 24),
        });
      }
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
  console.log(`Burger Pals MP relay on :${PORT} (max ${MAX_PLAYERS} players)`);
});
