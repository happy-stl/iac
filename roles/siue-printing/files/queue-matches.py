"""Say whether a CUPS queue already has the settings the role manages.

Usage: queue-matches.py QUEUE PPD KEY=VALUE...

Compares the queue's `lpoptions` against each KEY=VALUE and against the
model name (*NickName) in PPD, and prints "match" or "differs". A queue that
does not exist differs.
"""
import re
import shlex
import subprocess
import sys

queue, ppd, *pairs = sys.argv[1:]
want = dict(pair.split("=", 1) for pair in pairs)
with open(ppd, encoding="latin-1") as f:
    nick = re.search(r'^\*NickName:\s*"([^"]*)"', f.read(), re.M)
want["printer-make-and-model"] = nick.group(1) if nick else ""

result = subprocess.run(["lpoptions", "-p", queue], capture_output=True, text=True)
have = {}
if result.returncode == 0:
    have = dict(t.split("=", 1) for t in shlex.split(result.stdout) if "=" in t)
# lpoptions omits auth-info-required when it is "none".
have.setdefault("auth-info-required", "none")

print("match" if have and all(have.get(k) == v for k, v in want.items()) else "differs")
