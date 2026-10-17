#!/usr/bin/python3 -I
"""CUPS backend: submit the job to a Windows print queue through the Print
Spooler RPC interface (MS-RPRN), as Windows clients do.

SIUE's print server refuses jobs written to the printer share over SMB, the
route Samba's smbspool takes, but accepts OpenPrinterEx / StartDocPrinter /
WritePrinter from an authenticated client. The job is sent as RAW: CUPS has
already rendered it, job-accounting code included, with the copier's driver.

Device URI: spoolss://<server>/<queue>

Installed root-owned with mode 0700 so CUPS runs it as root. It switches to
the user in AUTH_UID (set by cupsd for queues with auth-info-required
negotiate, or by a wrapper backend) and authenticates with that user's
Kerberos ticket.
"""
import os
import pwd
import sys
from urllib.parse import unquote, urlsplit

CUPS_BACKEND_OK = 0
CUPS_BACKEND_AUTH_REQUIRED = 2
CUPS_BACKEND_RETRY = 6

CHUNK = 64 * 1024


def log(level, message):
    print(f"{level}: {message}", file=sys.stderr, flush=True)


def become(uid):
    """Drop to uid, keeping lp as a supplementary group so the spool file
    stays readable."""
    user = pwd.getpwuid(uid)
    os.setgroups([7, user.pw_gid])
    os.setgid(user.pw_gid)
    os.setuid(uid)
    os.environ["HOME"] = user.pw_dir
    os.environ["USER"] = os.environ["LOGNAME"] = user.pw_name
    os.environ.setdefault("KRB5CCNAME", f"KCM:{uid}")


def submit(server, queue, title, stream, copies):
    from samba import credentials, param
    from samba.dcerpc import spoolss

    lp = param.LoadParm()
    lp.load_default()
    creds = credentials.Credentials()
    creds.guess(lp)
    creds.set_kerberos_state(credentials.MUST_USE_KERBEROS)
    creds.set_named_ccache(os.environ["KRB5CCNAME"], credentials.SPECIFIED, lp)

    log("DEBUG", f"Connecting to {server} as {creds.get_username()} (uid {os.getuid()})")
    conn = spoolss.spoolss(f"ncacn_np:{server}[sign,seal]", lp, creds)
    log("DEBUG", "Connected; opening the printer")

    # The server answers WERR_ACCESS_DENIED to OpenPrinterEx when the client
    # reports a pre-Vista version, so report what rpcclient does.
    user_level = spoolss.UserLevel1()
    user_level.size = 28
    user_level.client = "\\\\" + lp.get("netbios name")
    user_level.user = creds.get_username()
    user_level.build = 7007
    user_level.major = 6
    user_level.minor = 1
    user_level.processor = 0
    user_ctr = spoolss.UserLevelCtr()
    user_ctr.level = 1
    user_ctr.user_info = user_level

    handle = conn.OpenPrinterEx(f"\\\\{server}\\{queue}", None,
                                spoolss.DevmodeContainer(),
                                spoolss.PRINTER_ACCESS_USE, user_ctr)
    log("DEBUG", f"Opened {queue}")
    try:
        doc = spoolss.DocumentInfo1()
        doc.document_name = title
        doc.output_file = None
        doc.datatype = "RAW"
        doc_ctr = spoolss.DocumentInfoCtr()
        doc_ctr.level = 1
        doc_ctr.info = doc
        job = conn.StartDocPrinter(handle, doc_ctr)
        log("INFO", f"Sending to {queue} as job {job}")
        try:
            sent = 0
            for _ in range(copies):
                stream.seek(0)
                conn.StartPagePrinter(handle)
                while chunk := stream.read(CHUNK):
                    while chunk:
                        written = conn.WritePrinter(handle, chunk, len(chunk))
                        chunk = chunk[written:]
                        sent += written
                conn.EndPagePrinter(handle)
            conn.EndDocPrinter(handle)
        except BaseException:
            conn.AbortPrinter(handle)
            raise
        log("INFO", f"Sent {sent} bytes to {queue} as job {job}")
    finally:
        conn.ClosePrinter(handle)


def main(argv):
    if len(argv) == 1:
        print('network spoolss "Unknown" "Windows print queue (Print Spooler RPC)"')
        return CUPS_BACKEND_OK
    if len(argv) not in (6, 7):
        print(f"Usage: {argv[0]} job-id user title copies options [file]", file=sys.stderr)
        return 1

    uri = urlsplit(os.environ.get("DEVICE_URI", argv[0]))
    server, queue = uri.hostname, unquote(uri.path.lstrip("/"))
    if not server or not queue:
        log("ERROR", f"Bad device URI {uri.geturl()!r}: expected spoolss://server/queue")
        return 1

    uid = os.environ.get("AUTH_UID")
    if os.getuid() == 0:
        if not uid:
            log("ERROR", "AUTH_UID is not set: set the queue's auth-info-required to negotiate")
            return CUPS_BACKEND_AUTH_REQUIRED
        become(int(uid))
    else:
        os.environ.setdefault("KRB5CCNAME", f"KCM:{os.getuid()}")

    # With a file argument CUPS has not made the copies; from stdin it has.
    copies = int(argv[4]) if len(argv) == 7 else 1
    title = argv[3] or "Untitled"
    try:
        if len(argv) == 7:
            with open(argv[6], "rb") as stream:
                submit(server, queue, title, stream, copies)
        else:
            import tempfile
            with tempfile.TemporaryFile() as stream:
                while chunk := sys.stdin.buffer.read(CHUNK):
                    stream.write(chunk)
                submit(server, queue, title, stream, copies)
    except Exception as exc:
        text = str(exc)
        if any(s in text for s in ("NO_CRED", "No credentials", "krb5", "LOGON_FAILURE",
                                   "Ticket expired", "KDC", "ccache")):
            log("ERROR", f"No usable Kerberos ticket for uid {os.getuid()}: {text}")
            return CUPS_BACKEND_AUTH_REQUIRED
        log("ERROR", f"Could not print to \\\\{server}\\{queue}: {text}")
        return CUPS_BACKEND_RETRY
    return CUPS_BACKEND_OK


if __name__ == "__main__":
    sys.exit(main(sys.argv))
