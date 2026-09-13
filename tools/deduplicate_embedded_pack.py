"""Lossless PCK v3 deduplication. Keep every resource path and verify every payload."""
from pathlib import Path
import struct,hashlib,os,json

def compact(path):
 path=Path(path);rows=[]
 with path.open('rb') as src:
  def u32():return struct.unpack('<I',src.read(4))[0]
  def u64():return struct.unpack('<Q',src.read(8))[0]
  src.seek(-12,2);old_pack=u64();assert src.read(4)==b'GDPC'
  start=path.stat().st_size-old_pack-12;src.seek(start)
  assert src.read(4)==b'GDPC';assert u32()==3
  src.seek(start);header=bytearray(src.read(104));flags=struct.unpack_from('<I',header,20)[0]
  assert flags==2,('Unsupported encrypted or bundled pack',flags)
  base=start+struct.unpack_from('<Q',header,24)[0];directory=start+struct.unpack_from('<Q',header,32)[0]
  src.seek(directory);count=u32()
  for _ in range(count):
   n=u32();name=src.read(n);offset=u64()+base;size=u64();md5=src.read(16);entry_flags=u32();assert entry_flags==0
   rows.append((name,offset,size,md5,entry_flags))
  tmp=path.with_suffix('.dedup.tmp');canonical={};entries=[];digests={};saved=0
  with tmp.open('wb') as dst:
   src.seek(0);dst.write(src.read(start));new_base=104
   struct.pack_into('<Q',header,24,new_base);dst.write(header)
   for name,offset,size,md5,entry_flags in rows:
    src.seek(offset);data=src.read(size);assert len(data)==size
    assert hashlib.md5(data).digest()==md5
    key=(size,hashlib.sha256(data).digest());digests[name]=key[1]
    if key in canonical: new_offset=canonical[key];saved+=size
    else:
     dst.write(bytes((-dst.tell())%16));new_offset=dst.tell()-start-new_base;canonical[key]=new_offset;dst.write(data)
    entries.append((name,new_offset,size,md5,entry_flags))
   dst.write(bytes((-dst.tell())%16));new_directory=dst.tell()-start
   dst.write(struct.pack('<I',count))
   for name,offset,size,md5,entry_flags in entries:
    dst.write(struct.pack('<I',len(name))+name+struct.pack('<QQ',offset,size)+md5+struct.pack('<I',entry_flags))
   new_pack=dst.tell()-start;dst.write(struct.pack('<Q4s',new_pack,b'GDPC'))
   dst.seek(start+32);dst.write(struct.pack('<Q',new_directory))
   # Windows locates the embedded pack through this PE section.
   src.seek(0x3c);pe=u32();src.seek(pe+6);sections=struct.unpack('<H',src.read(2))[0]
   src.seek(pe+20);optional=struct.unpack('<H',src.read(2))[0]
   for i in range(sections):
    at=pe+24+optional+i*40;src.seek(at);section=src.read(40)
    if section[:8].rstrip(bytes([0])) in (b'pck',b'.pck'):
     # Godot intentionally maps only the original tiny virtual section;
     # the pack is read from disk, not mapped into SizeOfImage.
     dst.seek(at+16);dst.write(struct.pack('<I',new_pack+12))
  with tmp.open('rb') as check:
   for name,offset,size,md5,entry_flags in entries:
    check.seek(start+new_base+offset);assert hashlib.sha256(check.read(size)).digest()==digests[name],name
  before=path.stat().st_size;after=tmp.stat().st_size;assert after<=before
 os.replace(tmp,path)
 result={'before_bytes':before,'after_bytes':after,'saved_bytes':before-after,'resource_paths_verified':count,'unique_payloads':len(canonical)}
 print(json.dumps(result),flush=True);return result
if __name__=='__main__':
 import sys
 compact(sys.argv[1])
