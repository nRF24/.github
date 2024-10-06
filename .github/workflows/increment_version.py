"""A simple script to get current latest version from repo in working directory and
increment it accordingly. This can also be used to alter the version in metadata
files."""

import argparse
import json
from os import environ
from pathlib import Path
import re
import subprocess
from typing import cast, Tuple, List, Sequence, Dict
import sys
from difflib import unified_diff

VERSION_TUPLE = Tuple[int, int, int]
COMPONENTS = ["major", "minor", "patch"]
GIT_CLIFF_CONFIG = (Path(__file__).parent / "cliff.toml").resolve()
RELEASE_NOTES = GIT_CLIFF_CONFIG.with_name("ReleaseNotes.md")


def get_version() -> Tuple[VERSION_TUPLE, str]:
    """get current latest tag and parse into a 3-tuple"""
    # get list of all tags
    result = subprocess.run(
        ["git", "log", "--no-walk", "--tags", '--pretty="%D"'],
        capture_output=True,
        check=True,
    )
    tags: Sequence[VERSION_TUPLE] = set()  # using a set to avoid duplicates
    tag_pattern = re.compile(r"tag:\s+(?:RF24)?v?(\d+\.\d+\.?[A-Za-z0-9-_]*)")
    for line in result.stdout.decode(encoding="utf-8").splitlines():
        ver_tags = cast(List[str], tag_pattern.findall(line))
        for ver_tag in ver_tags:
            try:
                ver_tuple = tuple([int(x) for x in ver_tag.split(".", maxsplit=3)])
            except ValueError:
                print(ver_tag, "is not a stable version spec; skipping")
                continue
            if len(ver_tuple) < 3:
                print(ver_tag, "is an incomplete version spec; appending zero(s)")
                ver_tuple += (0,) * (3 - len(ver_tuple))
            tags.add(cast(VERSION_TUPLE, ver_tuple))
    tags = sorted(tags)  # sort by version & converts to a list
    tags.reverse()  # to iterate from newest to oldest versions
    print("found version tags:")
    for tag in tags:
        print("    v" + ".".join([str(t) for t in tag]), flush=True)

    # get current branch
    result = subprocess.run(["git", "branch"], capture_output=True, check=True)
    branch = "master"
    for line in result.stdout.decode(encoding="utf-8").splitlines():
        if line.startswith("*"):
            branch = line.lstrip("*").strip()
            break
    else:
        print(
            "Could not determine the currently checked out branch name;",
            "assuming default branch",
            repr(branch),
        )

    # filter tags and find the appropriate latest tag according to current branch
    if branch.endswith("1.x"):
        print("filtering tags for branch", branch)
        for tag in tags:
            if tag[0] == 1:
                ver_tag = tag
                break
        else:
            raise RuntimeError(f"Found no v1.x tags for branch {branch}")
    else:
        print("treating branch", repr(branch), "as latest stable branch", flush=True)
        ver_tag = tags[0]
    print("Current version:", ".".join([str(x) for x in ver_tag]), flush=True)
    return ver_tag, branch


def increment_version(version: VERSION_TUPLE, bump: str = "patch") -> VERSION_TUPLE:
    """Increment given version based on specified ``bump`` component."""
    new_ver = list(version)  # make tuple mutable
    component = COMPONENTS.index(bump)
    new_ver[component] += 1
    # zero out minor and patch components if needed
    for i in range(component + 1, len(COMPONENTS)):
        new_ver[i] = 0
    return tuple(new_ver)


def get_changelog(
    tag: str, first_commit: str, full: bool = False, branch: str = "main"
):
    """Gets the changelog for this release.
    If ``full`` is true, then this returns a flag to describe if
    anything was changed in the CHANGELOG.md"""
    old = ""
    changelog = Path("CHANGELOG.md")
    if not changelog.exists():
        changelog.write_bytes(b"")
    if full:
        old = changelog.read_text(encoding="utf-8")
    output = changelog
    exe_name = "git-cliff"
    if environ.get("CI", "false") == "true":
        exe_name = (
            (GIT_CLIFF_CONFIG.parent.parent.parent / exe_name).resolve().as_posix()
        )
    args = [exe_name, "--use-branch-tags", "--github-repo", f"nRF24/{Path.cwd().name}"]
    if not full:
        args.append("--unreleased")
        output = str(RELEASE_NOTES)
    env = {
        "FIRST_COMMIT": first_commit,
        "GIT_CLIFF_CONFIG": str(GIT_CLIFF_CONFIG),
        "GIT_CLIFF_OUTPUT": str(output),
        "GIT_CLIFF_TAG": f"v{tag}",
    }
    if not full:
        env["GIT_CLIFF__CHANGELOG__HEADER"] = ""
    subprocess.run(args, env=env, check=True)
    if full:
        new = changelog.read_text(encoding="utf-8")
        changes = list(unified_diff(old, new))
        return len(changes) != 0
    return False


def get_first_commit() -> str:
    result = subprocess.run(
        ["git", "rev-list", "--max-parents=0", "HEAD"], check=True, capture_output=True
    )
    return result.stdout.decode("utf-8").strip()


def update_metadata_files(version: str) -> bool:
    """update the library metadata files with the new specified ``version``."""
    made_changes = False
    # NOTE: Path.write_text(..., newline="\n") requires python v3.10+

    pio_meta_file = Path("library.json")
    if pio_meta_file.exists():
        # treat PIO metadata as a dict to prevent us from alter a dep's `version`
        data = cast(
            Dict[str, str], json.loads(pio_meta_file.read_text(encoding="utf-8"))
        )
        assert "version" in data
        if data["version"] != version:
            data["version"] = version
            pio_meta_file.write_text(
                json.dumps(data, indent=4), encoding="utf-8", newline="\n"
            )
            made_changes = True

    arduino_meta_file = Path("library.properties")
    if arduino_meta_file.exists():
        # simple search and replace
        ver_pattern = re.compile(r"version=(\d+\.\d+\.?\d*)")
        data = arduino_meta_file.read_text(encoding="utf-8")
        ver_match = ver_pattern.search(data)
        assert ver_match is not None, "could not find version in " + str(
            arduino_meta_file
        )
        if ver_match.group(1) != version:
            data = ver_pattern.sub(f"version={version}", data)
            arduino_meta_file.write_text(data, encoding="utf-8", newline="\n")
            made_changes = True

    return made_changes


class Args(argparse.Namespace):
    bump: str = "patch"
    update_metadata: bool = False


def main() -> int:
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

    version, branch = get_version()
    version = increment_version(version=version, bump=args.bump)
    ver_str = ".".join([str(x) for x in version])
    first_commit = get_first_commit()
    # generate release notes and save them to a file
    get_changelog(ver_str, first_commit, full=False, branch=branch)
    # generate complete changelog
    made_changes = get_changelog(ver_str, first_commit, full=True, branch=branch)
    print("Updated CHANGELOG.md:", made_changes)
    print("New version:", ver_str)

    if args.update_metadata:
        made_changes = update_metadata_files(ver_str) or made_changes
        print("Metadata file(s) updated:", made_changes)

    if "GITHUB_OUTPUT" in environ:  # create an output variables for use in CI workflow
        with open(environ["GITHUB_OUTPUT"], mode="a") as gh_out:
            gh_out.write(f"release-notes={RELEASE_NOTES}\n")
            gh_out.write(f"new-version={ver_str}\n")
            gh_out.write(f"made-changes={str(made_changes).lower()}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
