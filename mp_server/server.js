#!/usr/bin/env node
/**
 * Burger Pals online room relay for Railway.
 *
 * Hosts create a 4-digit code and can Start Co-op alone.
 * Friends join anytime with that code (lobby or mid-shift) up to MAX_PLAYERS.
 * All game packets are relayed over WebSocket (works across the internet / NAT).
 */
const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = Number(process.env.PORT || 8080);
const MAX_PLAYERS = 4;
// Keep empty rooms briefly; active rooms refresh lastActive on traffic.
const ROOM_IDLE_MS = 90 * 60 * 1000;
const HEADER_SIZE = 20;
const MAX_PENDING_BYTES = 2 * 1024 * 1024;
const MAX_SOCKET_BYTES = 256 * 1024;
const MAX_QUEUE_AGE_MS = 5000;
const MAX_PACKET_BYTES = 65535;
const stats = { forwarded: 0, bytes: 0, coalesced: 0, overloads: 0 };

function queuePacket(ws, data, binary = false, key = "") {
  if (!ws || ws.readyState !== 1) return;
  const bytes = typeof data === "string" ? Buffer.byteLength(data) : data.length;
  if (!ws.pending) { ws.pending = []; ws.motion = new Map(); ws.pendingBytes = 0; }
  if (key && ws.motion.has(key)) {
    ws.pendingBytes -= ws.motion.get(key).bytes;
    stats.coalesced++;
  }
  const item = { data, binary, bytes, time: Date.now() };
  if (key) ws.motion.set(key, item); else ws.pending.push(item);
  ws.pendingBytes += bytes;
  if (ws.pendingBytes > MAX_PENDING_BYTES) {
    stats.overloads++;
    ws.close(1013, "Receiver cannot keep up");
    ws.pending = []; ws.motion.clear(); ws.pendingBytes = 0;
    return;
  }
  flushSocket(ws);
}

function flushSocket(ws) {
  if (!ws || ws.readyState !== 1 || !ws.pending) return;
  let sent = 0, bytes = 0;
  while ((ws.pending.length || ws.motion.size) && sent < 32 && bytes < 128 * 1024) {
    if (ws.bufferedAmount >= MAX_SOCKET_BYTES) break;
    // Reliable events keep their ordering; a motion turn prevents starvation.
    const motionTurn = ws.motion.size && (!ws.pending.length || sent % 8 === 7);
    let item;
    if (motionTurn) {
      const key = ws.motion.keys().next().value;
      item = ws.motion.get(key); ws.motion.delete(key);
    } else item = ws.pending.shift();
    ws.pendingBytes -= item.bytes;
    if (Date.now() - item.time > MAX_QUEUE_AGE_MS) {
      stats.overloads++; ws.close(1013, "Receiver backlog expired"); return;
    }
    ws.send(item.data, { binary: item.binary }, (err) => { if (err) ws.close(1011, "Send failed"); });
    bytes += item.bytes; sent++; stats.forwarded++; stats.bytes += item.bytes;
  }
  const oldest = ws.pending[0];
  if (oldest && Date.now() - oldest.time > MAX_QUEUE_AGE_MS) {
    stats.overloads++; ws.close(1013, "Receiver backlog expired");
  }
}

function destinations(room, sender, target) {
  return [...room.peers].filter(([id, other]) => other?.readyState === 1 && id !== sender &&
    (target === 0 || (target > 0 ? id === target : id !== -target)));
}

function forwardGame(ws, target, channel, mode, raw) {
  const room = rooms.get(ws.roomCode);
  if (!room || !ws.peerId || !Number.isInteger(target) || !Number.isInteger(channel) || channel < 0 || channel > 255 || ![0,1,2].includes(mode) || !raw.length || raw.length > MAX_PACKET_BYTES) return;
  touchRoom(room);
  const header = Buffer.alloc(HEADER_SIZE);
  header[0] = 0x46; header[1] = 0x54; header[2] = 1;
  header[3] = channel === 1 && mode === 0 ? 1 : 0;
  header.writeUInt32LE(ws.peerId, 4); // Never trust a client-supplied sender ID.
  header.writeInt32LE(target, 8);
  header[12] = mode; header[13] = channel;
  header.writeUInt16LE(raw.length, 18);
  const packet = Buffer.concat([header, raw]);
  let text;
  for (const [, dest] of destinations(room, ws.peerId, target)) {
    const key = header[3] ? `${ws.peerId}:motion` : "";
    if (dest.binaryV === 1) queuePacket(dest, packet, true, key);
    else {
      text ??= JSON.stringify({ op: "game_bin", from: ws.peerId, ch: channel, mode, b64: raw.toString("base64") });
      queuePacket(dest, text, false, key);
    }
  }
}

/**
 * @typedef {{
 *   code: string,
 *   peers: Map<number, import('ws').WebSocket>,
 *   created: number,
 *   lastActive: number,
 *   sessionActive?: boolean,
 *   sessionSeed?: number,
 * }} Room
 * @type {Map<string, Room>}
 */
const rooms = new Map();

function broadcastRoomJson(room, fromPeerId, obj) {
  if (!room) return;
  for (const [id, other] of room.peers) {
    if (id === fromPeerId) continue;
    if (other && other.readyState === 1) {
      sendJson(other, obj);
    }
  }
}

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
    queuePacket(ws, JSON.stringify(obj));
  }
}

function touchRoom(room) {
  if (room) room.lastActive = Date.now();
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
  touchRoom(room);
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
    const idleFrom = room.lastActive || room.created;
    if (room.peers.size === 0 && now - idleFrom > ROOM_IDLE_MS) {
      rooms.delete(code);
    }
  }
}

function forwardBinary(ws, data) {
  const buf = Buffer.from(data);
  if (ws.binaryV !== 1 || buf.length < HEADER_SIZE || buf[0] !== 0x46 || buf[1] !== 0x54 || buf[2] !== 1) return;
  const size = buf.readUInt16LE(18);
  if (buf.length !== HEADER_SIZE + size) return;
  forwardGame(ws, buf.readInt32LE(8), buf[13], buf[12], buf.subarray(HEADER_SIZE));
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
        mid_round_join: true,
        solo_host_ok: true,
        binary_v: 1,
        transport: stats,
      })
    );
    return;
  }
  res.writeHead(404);
  res.end("not found");
});

const wss = new WebSocketServer({ server, maxPayload: 256 * 1024, perMessageDeflate: false });

wss.on("connection", (ws) => {
  ws.roomCode = null;
  ws.peerId = 0;
  ws.binaryV = 0;
  ws.isAlive = true;
  ws.on("pong", () => {
    ws.isAlive = true;
  });

  sendJson(ws, {
    op: "hello",
    binary_v: 1,
    max_players: MAX_PLAYERS,
    mid_round_join: true,
    solo_host_ok: true,
  });

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

    if (op === "kick") {
      const room = rooms.get(ws.roomCode);
      const target = Number(msg.peer_id);
      if (ws.peerId === 1 && room && Number.isInteger(target) && target > 1) {
        room.peers.get(target)?.close(1008, "Removed by host");
      }
      return;
    }

    if (op === "host") {
      ws.binaryV = Number(msg.binary_v) === 1 ? 1 : 0;
      clearSocketRoom(ws);
      pruneRooms();
      let code = normalizeCode(msg.code || "");
      if (!code) code = randomCode();
      const existing = rooms.get(code);
      if (existing && existing.peers.has(1) && existing.peers.get(1)?.readyState === 1) {
        code = randomCode();
      }
      const now = Date.now();
      /** @type {Room} */
      const room = { code, peers: new Map(), created: now, lastActive: now, sessionActive: false, sessionSeed: 0 };
      rooms.set(code, room);
      room.peers.set(1, ws);
      ws.roomCode = code;
      ws.peerId = 1;
      sendJson(ws, {
        op: "hosted",
        code,
        peer_id: 1,
        max_players: MAX_PLAYERS,
        mid_round_join: true,
        name: String(msg.name || "Host").slice(0, 24),
      });
      return;
    }

    if (op === "join") {
      ws.binaryV = Number(msg.binary_v) === 1 ? 1 : 0;
      clearSocketRoom(ws);
      const code = normalizeCode(msg.code || "");
      if (!code) {
        sendJson(ws, { op: "error", msg: "need 4-digit code" });
        return;
      }
      const room = rooms.get(code);
      // Host must still be connected — late joins OK while they play (solo or co-op).
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
      touchRoom(room);
      ws.roomCode = code;
      ws.peerId = peerId;
      const others = alivePeers(room).filter((id) => id !== peerId);
      sendJson(ws, {
        op: "joined",
        code,
        peer_id: peerId,
        max_players: MAX_PLAYERS,
        peers: others,
        mid_round_join: true,
        session_active: !!room.sessionActive,
        session_seed: Number(room.sessionSeed || 0),
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
      // Mid-shift joiner — immediately pull them into the live shift.
      if (room.sessionActive) {
        sendJson(ws, {
          op: "session_start",
          seed: Number(room.sessionSeed || 0),
          from_peer: 1,
        });
      }
      return;
    }

    // Host starts co-op — JSON handoff (does not rely on Godot binary RPCs).
    if (op === "session_start") {
      if (!ws.roomCode || ws.peerId !== 1) {
        sendJson(ws, { op: "error", msg: "only host can start" });
        return;
      }
      const room = rooms.get(ws.roomCode);
      if (!room) {
        sendJson(ws, { op: "error", msg: "no room" });
        return;
      }
      const seed = Number(msg.seed || 0) || (Date.now() & 0x7fffffff);
      room.sessionActive = true;
      room.sessionSeed = seed;
      touchRoom(room);
      broadcastRoomJson(room, ws.peerId, {
        op: "session_start",
        seed,
        from_peer: 1,
      });
      // Ack host so client can confirm relay accepted the start.
      sendJson(ws, { op: "session_started", seed, peers: alivePeers(room).length });
      return;
    }

    // Godot SceneMultiplayer packets tunneled as JSON (binary WS frames were dropping).
    if (op === "game_bin") {
      if (!ws.roomCode || !ws.peerId || typeof msg.b64 !== "string" || msg.b64.length > 87384) return;
      forwardGame(ws, Number(msg.to ?? 0), Number(msg.ch ?? 0), Number(msg.mode ?? 2), Buffer.from(msg.b64, "base64"));
      return;
    }

    if (op === "ping") {
      if (ws.roomCode) {
        const room = rooms.get(ws.roomCode);
        touchRoom(room);
      }
      sendJson(ws, { op: "pong", t: msg.t || 0 });
      return;
    }

    sendJson(ws, { op: "error", msg: "unknown op" });
  });

  ws.on("close", (code, reason) => {
    if (process.env.RELAY_TEST_LOG) console.log("CLOSE", ws.peerId, code, reason.toString());
    clearSocketRoom(ws);
  });

  ws.on("error", () => {
    clearSocketRoom(ws);
  });
});

setInterval(() => { for (const ws of wss.clients) flushSocket(ws); }, 10).unref();

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
  console.log(
    `Burger Pals MP relay on :${PORT} (max ${MAX_PLAYERS}, mid-round join OK, solo host OK)`
  );
});
