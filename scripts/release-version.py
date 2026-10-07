#!/usr/bin/env python3
"""Choose a release version without creating a remote tag before validation."""
import os
import plistlib
import re
import subprocess
from pathlib import Path


def next_version(base, tags):
    current = tuple(map(int, base.split(".")))
    versions = [tuple(map(int, tag[1:].split("."))) for tag in tags
                if re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag)]
    if versions and max(versions) >= current:
        major, minor, patch = max(versions)
        current = (major, minor, patch + 1)
    return ".".join(map(str, current))


if __name__ == "__main__":
    base = plistlib.loads(Path("Resources/Info.plist").read_bytes())["CFBundleShortVersionString"]
    tags = subprocess.check_output(["git", "tag", "--list", "v*"], text=True).splitlines()
    version = next_version(base, tags)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    with open(os.environ["GITHUB_ENV"], "a") as output:
        output.write(f"APP_VERSION={version}\n")
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"tag=v{version}\ncommit={commit}\n")
    print(f"EFBY Git Desk v{version}, commit {commit}")
