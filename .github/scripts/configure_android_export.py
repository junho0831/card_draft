#!/usr/bin/env python3
"""Inject ephemeral Android release metadata and signing credentials in CI."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


REQUIRED_ENV = (
    "ANDROID_KEYSTORE_PATH",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "RELEASE_VERSION_CODE",
    "RELEASE_VERSION_NAME",
)


def replace_once(text: str, pattern: str, replacement: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(f"Expected one match for {pattern!r}, found {count}")
    return updated


def main() -> int:
    missing = [name for name in REQUIRED_ENV if not os.environ.get(name)]
    if missing:
        raise RuntimeError("Missing environment variables: " + ", ".join(missing))

    preset_path = Path(sys.argv[1] if len(sys.argv) > 1 else "export_presets.cfg")
    text = preset_path.read_text(encoding="utf-8")
    android_start = text.index('[preset.1.options]')
    android_end = text.find('\n[preset.', android_start + 1)
    if android_end == -1:
        android_end = len(text)
    before, android, after = text[:android_start], text[android_start:android_end], text[android_end:]

    values = {
        r'^architectures/armeabi-v7a=.*$': 'architectures/armeabi-v7a=true',
        r'^architectures/arm64-v8a=.*$': 'architectures/arm64-v8a=true',
        r'^architectures/x86=.*$': 'architectures/x86=false',
        r'^architectures/x86_64=.*$': 'architectures/x86_64=false',
        r'^keystore/release=.*$': f'keystore/release="{os.environ["ANDROID_KEYSTORE_PATH"]}"',
        r'^keystore/release_user=.*$': f'keystore/release_user="{os.environ["ANDROID_KEY_ALIAS"]}"',
        r'^keystore/release_password=.*$': f'keystore/release_password="{os.environ["ANDROID_KEYSTORE_PASSWORD"]}"',
        r'^version/code=.*$': f'version/code={os.environ["RELEASE_VERSION_CODE"]}',
        r'^version/name=.*$': f'version/name="{os.environ["RELEASE_VERSION_NAME"]}"',
    }
    for pattern, replacement in values.items():
        android = replace_once(android, pattern, replacement)

    preset_path.write_text(before + android + after, encoding="utf-8")
    print(
        "Configured Android export for "
        f'{os.environ["RELEASE_VERSION_NAME"]} ({os.environ["RELEASE_VERSION_CODE"]})'
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
