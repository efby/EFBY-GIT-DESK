#!/usr/bin/env python3
"""Bound CI tests and sample only their processes if startup stalls."""
import os
import signal
import subprocess
import time

process = subprocess.Popen(["scripts/test.sh", "--verbose"], start_new_session=True)
started = time.monotonic()
sampled = False
try:
    while process.poll() is None:
        elapsed = time.monotonic() - started
        if elapsed >= 120 and not sampled:
            sampled = True
            print("::group::Test process diagnostic (no arguments or environment)", flush=True)
            rows = subprocess.check_output(
                ["/bin/ps", "-axo", "pid=,ppid=,comm="], text=True
            ).splitlines()
            entries = [row.strip().split(None, 2) for row in rows]
            owned = {process.pid}
            while True:
                children = {int(pid) for pid, parent, _ in entries if int(parent) in owned}
                expanded = owned | children
                if expanded == owned:
                    break
                owned = expanded
            for pid, parent, command in entries:
                if int(pid) not in owned:
                    continue
                print(f"pid={pid} parent={parent} executable={command}", flush=True)
                if "EfbyGitDeskPackageTests" in command or command.endswith("/swift-test"):
                    result = subprocess.run(
                        ["/usr/bin/sample", pid, "3", "-file", "/dev/stdout"],
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                        text=True, timeout=15,
                    )
                    print(result.stdout[:40000], flush=True)
            print("::endgroup::", flush=True)
        if elapsed >= 300:
            print("::error::Tests exceeded five minutes; terminating their process group.", flush=True)
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            raise SystemExit(124)
        time.sleep(1)
    raise SystemExit(process.returncode)
finally:
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
