"""Say whether a CUPS queue already has the settings the role manages.

Usage: queue-matches.py QUEUE PPD KEY=VALUE...

Compares the queue's entry in /etc/cups/printers.conf against each KEY=VALUE
(IPP attribute names) and against the model name (*NickName) in PPD, and
prints "match" or "differs". A queue that does not exist differs.

printers.conf is read rather than `lpoptions`, which prints values in single
quotes without escaping quotes inside them. It is root-only, so run this as
root. CUPS may take up to DirtyCleanInterval (30 s) to write a change there;
a stale read only makes the caller reapply settings that already match.
"""
import re
import sys

# IPP attribute -> printers.conf key, and how to turn the IPP value into the
# file's spelling.
FIELDS = {
    "device-uri": ("DeviceURI", str),
    "printer-info": ("Info", str),
    "printer-location": ("Location", str),
    "auth-info-required": ("AuthInfoRequired", str),
    "printer-is-shared": ("Shared", lambda v: "Yes" if v == "true" else "No"),
    "printer-make-and-model": ("MakeModel", str),
}

queue, ppd, *pairs = sys.argv[1:]
want = dict(pair.split("=", 1) for pair in pairs)
with open(ppd, encoding="latin-1") as f:
    nick = re.search(r'^\*NickName:\s*"([^"]*)"', f.read(), re.M)
want["printer-make-and-model"] = nick.group(1) if nick else ""

have, inside = None, False
with open("/etc/cups/printers.conf", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if re.fullmatch(rf"<(Default)?Printer {re.escape(queue)}>", line):
            have, inside = {}, True
        elif inside and line.startswith("</"):
            break
        elif inside and " " in line:
            key, value = line.split(" ", 1)
            have[key] = value

if have is not None:
    # printers.conf omits AuthInfoRequired when it is "none".
    have.setdefault("AuthInfoRequired", "none")

print("match" if have is not None and all(
    have.get(FIELDS[k][0]) == FIELDS[k][1](v) for k, v in want.items()
) else "differs")
