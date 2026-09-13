const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const {EventEmitter} = require("node:events");
let relay;
const timers=[];
class Server extends EventEmitter { constructor(){super(); this.clients=new Set();relay=this;} }
vm.runInNewContext(fs.readFileSync(path.join(__dirname,"../mp_server/server.js"),"utf8"),{
 require(n){if(n==="http")return{createServer:()=>({listen(){}})};if(n==="ws")return{WebSocketServer:Server};throw Error(n)},
 Buffer,Uint8Array,process:{env:{}},console,setInterval(fn){timers.push(fn);return{unref(){}}}
});
function socket(binary=1){
 const s=new EventEmitter();s.sent=[];s.readyState=1;s.bufferedAmount=0;
 s.send=(data,options,cb)=>{s.sent.push(options?.binary?Buffer.from(data):JSON.parse(data));if(cb)cb();};
 s.close=()=>{s.readyState=3;s.emit("close")};s.terminate=s.close;s.ping=()=>{};
 relay.clients.add(s);relay.emit("connection",s);s.requestedBinary=binary;return s;
}
const message=(s,m)=>s.emit("message",Buffer.from(JSON.stringify(m)),false);
const host=socket();message(host,{op:"host",code:"1234",binary_v:1});
const guest=socket();message(guest,{op:"join",code:host.roomCode,binary_v:1});
const legacy=socket(0);message(legacy,{op:"join",code:host.roomCode});
function packet(mode,channel,target=0,body=Buffer.from([0,127,255])){
 const b=Buffer.alloc(20+body.length);b[0]=0x46;b[1]=0x54;b[2]=1;b.writeUInt32LE(999,4);b.writeInt32LE(target,8);b[12]=mode;b[13]=channel;b.writeUInt16LE(body.length,18);body.copy(b,20);return b;
}
for(const mode of [0,1,2]){
 guest.sent=[];legacy.sent=[];host.emit("message",packet(mode,0),true);
 assert.equal(guest.sent[0][12],mode);assert.equal(guest.sent[0].readUInt32LE(4),host.peerId);
 assert.deepEqual([...guest.sent[0].subarray(20)],[0,127,255]);
 assert.equal(legacy.sent[0].mode,mode);assert.equal(legacy.sent[0].from,host.peerId);
}
guest.sent=[];host.emit("message",packet(0,0,-guest.peerId),true);assert.equal(guest.sent.length,0);
const bad=packet(2,0);bad.writeUInt16LE(12,18);host.emit("message",bad,true);assert.equal(guest.sent.length,0);
guest.bufferedAmount=16*1024*1024;guest.sent=[];legacy.sent=[];
for(let i=0;i<100;i++)host.emit("message",packet(0,1,0,Buffer.from([i])),true);
assert.equal(guest.sent.length,0);assert.equal(guest.motion.size,1);assert.equal(legacy.sent.length,100);
guest.bufferedAmount=0;timers[0]();assert.equal(guest.sent.length,1);assert.equal(guest.sent[0][20],99);
guest.bufferedAmount=16*1024*1024;
for(let i=0;i<40 && guest.readyState===1;i++)host.emit("message",packet(2,2,guest.peerId,Buffer.alloc(65535)),true);
assert.equal(guest.readyState,3,"Slow reliable recipient must disconnect at the bounded limit");
const kickHost=socket();message(kickHost,{op:"host",binary_v:1});
const kickGuest=socket();message(kickGuest,{op:"join",code:kickHost.roomCode,binary_v:1});
message(kickGuest,{op:"kick",peer_id:1});assert.equal(kickHost.readyState,1);
message(kickHost,{op:"kick",peer_id:kickGuest.peerId});assert.equal(kickGuest.readyState,3);assert.equal(kickHost.readyState,1);
console.log("RELAY_PROTOCOL_OK modes, sender authority, binary/text fallback, negative targets, malformed packets, motion coalescing, slow-peer isolation and bounded reliable queue");
