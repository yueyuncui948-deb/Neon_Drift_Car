"""Install only verified Godot 4.6.3 single-threaded Web templates.
No credentials needed. Download from the official HTTPS release, check the pinned
SHA-512 published in that release's SHA512-SUMS.txt, then extract two known files.
"""
from pathlib import Path
import hashlib
import os
import tempfile
import urllib.request
import zipfile

VERSION = '4.6.3.stable'
URL = 'https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz'
ARCHIVE_SHA512 = 'da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68'
FILES = {
 'web_nothreads_release.zip': '1446f79dc12f60ce5d244c39fb6628ec298337ca5c4f91a16491feea72aa1bc9',
 'web_nothreads_debug.zip': '4a8a8ef7519637f7898fad25f09d3e466965e99c04e441682e1bc2d97a548922',
}

def digest(path, algorithm='sha256'):
 h=hashlib.new(algorithm)
 with path.open('rb') as f:
  for data in iter(lambda:f.read(8*1024*1024),b''): h.update(data)
 return h.hexdigest()

def main():
 data_home=Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))
 destination=data_home/'godot/export_templates'/VERSION
 destination.mkdir(parents=True,exist_ok=True)
 if all((destination/name).is_file() and digest(destination/name)==sha for name,sha in FILES.items()):
  print('Godot Web templates already installed; checksums verified.')
  return
 print('Downloading official template archive (~1.2 GB); only Web templates will be retained.',flush=True)
 with tempfile.TemporaryDirectory(prefix='neon-godot-') as directory:
  archive=Path(directory)/'templates.tpz'
  urllib.request.urlretrieve(URL,archive)
  if digest(archive,'sha512')!=ARCHIVE_SHA512:
   raise RuntimeError('Official archive checksum mismatch; refusing installation')
  with zipfile.ZipFile(archive) as z:
   for name,sha in FILES.items():
    data=z.read('templates/'+name)
    if hashlib.sha256(data).hexdigest()!=sha:
     raise RuntimeError('Template checksum mismatch: '+name)
    (destination/name).write_bytes(data)
 print('Verified Web templates installed at',destination)

if __name__=='__main__': main()
