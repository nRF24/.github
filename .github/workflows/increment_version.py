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
COMPONENTS = ["major", "minor", "patch"]


def get_version() -> VERSION_TUPLE:
    """get current latest tag and parse into a 3-tuple"""
    result = subprocess.run(
        ["gh", "release", "list", "--limit=1", "--json=tagName"],
        capture_output=True,
        check=True,
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


def increment_version(version: VERSION_TUPLE, bump: str = "patch") -> VERSION_TUPLE:
    """Increment given version based on specified ``bump`` component."""
    new_ver = list(version)  # make tuple mutable
    component = COMPONENTS.index(bump)
    new_ver[component] += 1
    return tuple(new_ver)


def update_metadata_files(version: str) -> bool:
    """update the library metadata files with the new specified ``version``."""
    made_changes = False
    meta: List[Tuple[Path, str, str]] = [
        (
            Path("library.json"),
            r'"version":\s+"(\d+\.\d+\.\d+)",',
            f'"version": "{version}",',
        ),
        (
            Path("library.properties"),
            r"version=(\d+\.\d+\.\d+)",
            f"version={version}",
        ),
    ]

    for meta_file, pattern, update in meta:
        if meta_file.exists():
            ver_pattern = re.compile(pattern)
            data = meta_file.read_text(encoding="utf-8")
            ver_match = ver_pattern.search(data)
            assert ver_match is not None, "could not find version in " + str(meta_file)
            if ver_match.group(1) != version:
                data = ver_pattern.sub(update, data)
                meta_file.write_text(data, encoding="utf-8", newline="\n")
                made_changes = True

    return made_changes


class Args(argparse.Namespace):
    bump: str = "patch"
    update_metadata: bool = False


def main(argv: List[str] = sys.argv) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-b",
        "--bump",
        default="patch",
        choices=COMPONENTS,
        help="The version component to increment",
    )
    parser.add_argument(
        "-U",
        "--update-metadata",
        action="store_true",
        help="Update library metadata files with new version number",
    )
    args = parser.parse_args(namespace=Args())

    version = increment_version(version=get_version(), bump=args.bump)
    ver_str = ".".join([str(x) for x in version])
    print("New version:", ver_str)

    made_changes = False
    if args.update_metadata:
        made_changes = update_metadata_files(ver_str)
        print("Metadata file(s) updated:", made_changes)

    if "GITHUB_OUTPUT" in environ:  # create an output variables for use in CI workflow
        with open(environ["GITHUB_OUTPUT"], mode="a") as gh_out:
            gh_out.write(f"new-version={ver_str}\n")
            gh_out.write(f"made-changes={str(made_changes).lower()}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
