"""A simple script to get current latest version from repo in working directory and
increment it accordingly. This can also be used to alter the version in metadata
files."""

import argparse
from os import environ
from pathlib import Path
import re
import subprocess
from typing import cast, Tuple, List, Sequence
import sys

VERSION_TUPLE = Tuple[int, int, int]
COMPONENTS = ["major", "minor", "patch"]


def get_version() -> VERSION_TUPLE:
    """get current latest tag and parse into a 3-tuple"""
    # get list of all tags
    result = subprocess.run(
        ["git", "log", "--no-walk", "--tags", '--pretty="%D"'],
        capture_output=True,
        check=True,
    )
    tags: Sequence[VERSION_TUPLE] = set()  # using a set to avoid duplicates
    tag_pattern = re.compile(r"tag: v?(\d+\.\d+\.[A-Za-z0-9-_]+)")
    for line in result.stdout.decode(encoding="utf-8").splitlines():
        ver_tags = cast(List[str], tag_pattern.findall(line))
        for ver_tag in ver_tags:
            try:
                ver_tuple = tuple([int(x) for x in ver_tag.split(".")])
            except ValueError:
                print(ver_tag, "is not a stable version spec; skipping")
                continue
            if len(ver_tuple) < 3:
                print(ver_tag, "is an incomplete version spec; skipping")
                continue
            tags.add(cast(VERSION_TUPLE, ver_tuple))
    tags = sorted(tags)  # sort by version & converts to a list
    tags.reverse()  # to iterate from newest to oldest versions
    print("found version tags:")
    for tag in tags:
        print("    v" + ".".join([str(t) for t in tag]))

    # get current branch
    result = subprocess.run(["git", "branch"], capture_output=True, check=True)
    branch = "master"
    for line in result.stdout.decode(encoding="utf-8").splitlines():
        if line.startswith("*"):
            branch = line.lstrip("*").strip()
            break
    else:
        raise RuntimeError("could not determine the currently checked out branch name")
    if branch.endswith("1.x"):
        print("filtering tags for branch", branch)
        for tag in tags:
            if tag[0] == 1:
                ver_tag = tag
                break
        else:
            raise RuntimeError(f"Found no v1.x tags for branch {branch}")
    else:
        print("treating branch", branch, "as latest stable branch")
        ver_tag = tags[0]
    print("Current version:", ".".join([str(x) for x in ver_tag]))
    return ver_tag


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
