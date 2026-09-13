// Test-only transparent TCP link: ~100ms RTT, deterministic jitter, 128KiB/s each way.
const net=require("node:net");
net.createServer(client=>{
 const server=net.connect(18769,"127.0.0.1");client.setNoDelay(true);server.setNoDelay(true);
 function pipe(source,dest){let tail=Date.now(),queued=0,sequence=0,timer=null;const pending=[];
  function pump(){timer=null;if(!pending.length||dest.destroyed)return;const item=pending[0];
   if(item.due>Date.now()){timer=setTimeout(pump,Math.max(1,Math.ceil(item.due-Date.now())));return;}
   pending.shift();queued-=item.data.length;dest.write(item.data);if(queued<512*1024)source.resume();pump();
  }
  source.on("data",data=>{queued+=data.length;if(queued>1024*1024)source.pause();
   tail=Math.max(tail,Date.now()+50+(sequence++%5)*5)+data.length/131.072;pending.push({data,due:tail});if(!timer)pump();
  });
  source.on("close",()=>{if(timer)clearTimeout(timer);dest.destroy()});source.on("error",()=>dest.destroy());
 }
 pipe(client,server);pipe(server,client);
}).listen(18770,"127.0.0.1",()=>console.log("IMPAIRED_RELAY_PROXY_READY"));
