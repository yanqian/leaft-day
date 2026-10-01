import subprocess, sys, os, signal, json, time, tempfile
heartbeat = tempfile.NamedTemporaryFile(prefix='F031-heartbeat-', delete=False).name
child = 'import signal,time; from pathlib import Path;  signal.signal(signal.SIGTERM, signal.SIG_IGN); print("ready",flush=True); time.sleep(2); Path(HEARTBEAT).write_text("alive"); time.sleep(30)'
child = child.replace('HEARTBEAT',repr(heartbeat))
leader = f'import subprocess,sys,time; p=subprocess.Popen([sys.executable,"-c",{child!r}], stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True); p.stdout.readline(); print(p.pid,flush=True); time.sleep(30)'
p = subprocess.Popen([sys.executable,'scripts/run-bounded-evaluator.py','--timeout-seconds','1','--',sys.executable,'-c',leader],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
pid = None
try:
 line=p.stdout.readline().strip()
 pid=int(line)
 code=p.wait(timeout=15)
 try:
  os.kill(pid,0)
  alive=True
 except ProcessLookupError: alive=False
 time.sleep(1.3)
 heartbeat_written=open(heartbeat).read() == 'alive'
 print(json.dumps({'heartbeatWrittenAfterTimeout':heartbeat_written,'wrapperExit':code,'descendantAliveAfterWrapperExit':alive,'stderr':p.stderr.read()},indent=2))
finally:
 if pid:
  try: os.kill(pid,signal.SIGKILL)
  except ProcessLookupError: pass
 if p.poll() is None: p.kill(); p.wait()

os.unlink(heartbeat)
