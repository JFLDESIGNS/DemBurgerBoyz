const assert = require("node:assert/strict");
const WebSocket = require("../mp_server/node_modules/ws");
const url = process.argv[2] || "ws://127.0.0.1:18769";
const sockets=[];
async function wait(peer,predicate){
 const end=Date.now()+15000;
 while(Date.now()<end){const i=peer.messages.findIndex(predicate);if(i>=0)return peer.messages.splice(i,1)[0];await new Promise(r=>setTimeout(r,10));}
 throw Error("Relay response timed out");
}
async function connect(binary){
 const socket=new WebSocket(url);sockets.push(socket);const peer={socket,messages:[]};
 socket.on("message",(data,isBinary)=>peer.messages.push(isBinary?Buffer.from(data):JSON.parse(data)));
 socket.on("error",err=>{peer.error=err});
 const hello=await wait(peer,m=>m.op==="hello");assert.equal(hello.binary_v,1,"Deployed relay has not upgraded yet");peer.binary=binary;return peer;
}
function send(peer,data){peer.socket.send(JSON.stringify(data));}
(async()=>{
 const host=await connect(1);send(host,{op:"host",name:"Protocol regression",binary_v:1});
 const hosted=await wait(host,m=>m.op==="hosted");const guests=[];
 for(const binary of [1,1,0]){const guest=await connect(binary);send(guest,{op:"join",code:hosted.code,binary_v:binary});guest.id=(await wait(guest,m=>m.op==="joined")).peer_id;guests.push(guest);}
 for(const mode of [0,1,2]){
  const body=Buffer.from([mode,0,127,255]);const data=Buffer.alloc(24);data[0]=0x46;data[1]=0x54;data[2]=1;data.writeUInt32LE(999,4);data[12]=mode;data[13]=2;data.writeUInt16LE(body.length,18);body.copy(data,20);host.socket.send(data);
  for(const guest of guests){const reply=await wait(guest,m=>Buffer.isBuffer(m)||m.op==="game_bin");if(guest.binary){assert.equal(reply.readUInt32LE(4),1);assert.equal(reply[12],mode);assert.deepEqual(reply.subarray(20),body);}else{assert.equal(reply.from,1);assert.equal(reply.mode,mode);assert.deepEqual(Buffer.from(reply.b64,"base64"),body);}}
 }
 console.log("RELAY_LIVE_PROTOCOL_OK four peers, binary/text compatibility, all transfer modes and authoritative sender");
})().catch(error=>{console.error(error);process.exitCode=1}).finally(()=>{for(const socket of sockets)socket.close();setTimeout(()=>{for(const socket of sockets)socket.terminate()},500).unref()});
