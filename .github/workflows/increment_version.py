"""A simple script to get current latest version from repo in working directory and
increment it accordingly. This can also be used to alter the version in metadata
files."""

import argparse
import json
from os import environ
from pathlib import Path
import re
import subprocess
from typing import cast, Dict, Tuple, List
import sys

VERSION_TUPLE = Tuple[int, int, int]


def get_version() -> VERSION_TUPLE:
    """get current latest tag and parse into a 3-tuple"""
    result = subprocess.run(
        ["gh", "release", "list", "--limit=1", "--json=tagName"],
        capture_output=True,
        check=True,
        # shell=True,
    )
    ver_json = cast(
        List[Dict[str, str]], json.loads(result.stdout.decode(encoding="utf-8"))
    )[0]
    assert "tagName" in ver_json, f"got malformed output from gh-cli:\n{ver_json}"
    ver_tag = ver_json["tagName"].lstrip("v")
    print("Current version:", ver_tag)
    ver_tuple = ver_tag.split(".")
    assert len(ver_tuple) == 3, f"failed to parse version from tag {ver_tag}"
    return int(ver_tuple[0]), int(ver_tuple[1]), int(ver_tuple[2])


def increment_version(
    version: VERSION_TUPLE, major: bool = False, minor: bool = False, patch: bool = True
) -> VERSION_TUPLE:
    """Increment given version based on specified ``major``, ``minor``, and ``patch`` flags."""
    new_ver = list(version)  # make tuple mutable
    if major:
        new_ver[0] += 1
    if minor:
        new_ver[1] += 1
    if patch:
        new_ver[2] += 1
    return tuple(new_ver)


def update_metadata_files(version: str) -> bool:
    """update the library metadata files with the new specified ``version``."""
    made_changes = False

    pio_meta_file = Path("library.json")
    if pio_meta_file.exists():
        pio_ver_pattern = re.compile(r'"version":\s+"\d+\.\d+\.\d+",')
        data = pio_meta_file.read_text(encoding="utf-8")
        data = pio_ver_pattern.sub(f'"version": "{version}",', data)
        pio_meta_file.write_text(data, encoding="utf-8", newline="\n")
        made_changes = True

    arduino_meta_file = Path("library.properties")
    if arduino_meta_file.exists():
        arduino_ver_pattern = re.compile(r"version=\d+\.\d+\.\d+")
        data = arduino_meta_file.read_text(encoding="utf-8")
        data = arduino_ver_pattern.sub(f"version={version}", data)
        arduino_meta_file.write_text(data, encoding="utf-8", newline="\n")
        made_changes = True

    return made_changes


class Args(argparse.Namespace):
    major: bool = False
    minor: bool = False
    patch: bool = False
    update_metadata: bool = False


def main(argv: List[str] = sys.argv) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--major",
        default=False,
        type=lambda x: x.lower() == "true",
        help="Set to true to bump major version number",
    )
    parser.add_argument(
        "--minor",
        default=False,
        type=lambda x: x.lower() == "true",
        help="Set to true to bump minor version number",
    )
    parser.add_argument(
        "--patch",
        default=False,
        type=lambda x: x.lower() == "true",
        help="Set to true to bump patch version number",
    )
    parser.add_argument(
        "-U",
        "--update-metadata",
        action="store_true",
        help="Update library metadata files with new version number",
    )
    args = parser.parse_args(namespace=Args())

    version = increment_version(
        version=get_version(), major=args.major, minor=args.minor, patch=args.patch
    )
    ver_str = ".".join([str(x) for x in version])

    made_changes = False
    if args.update_metadata:
        made_changes = update_metadata_files(ver_str)

    if "GITHUB_OUTPUT" in environ:  # create an output variable for use in CI workflow
        with open(environ["GITHUB_OUTPUT"], mode="a") as gh_out:
            gh_out.write(f"new-version={ver_str}\n")
            gh_out.write(f"made-changes={str(made_changes).lower()}\n")
    else:  # use stdout for non-CI env (locally run)
        print("New version:", ver_str)

    return 0


if __name__ == "__main__":
    sys.exit(main())
