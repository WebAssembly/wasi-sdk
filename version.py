#!/usr/bin/env python3

# This script finds and prints the various versions in this project: wasi-sdk
# itself, LLVM, and the Git revisions of dependencies.
#
# Usage: version [wasi-sdk|llvm|llvm-major|dump] [--llvm-dir=<non-project dir>]

import argparse
import os
import subprocess
import sys

# The number of characters to use for the abbreviated Git revision.
GIT_REF_LEN = 12


def exec(command, cwd=None):
    result = subprocess.run(command, stdout=subprocess.PIPE,
                            universal_newlines=True, check=True, cwd=cwd)
    return result.stdout.strip()


def git_commit(dir='.'):
    return exec(['git', 'rev-parse', f'--short={GIT_REF_LEN}', 'HEAD'], dir)


def parse_git_version(version):
    # Parse, e.g.: wasi-sdk-21-0-g317548590b40+m
    parts = version.replace('+', '-').split('-')
    assert parts.pop(0) == 'wasi'
    assert parts.pop(0) == 'sdk'

    major, minor = parts.pop(0), parts.pop(0)
    git = None
    dirty = False

    if parts:
        # Check: git|dirty.
        next = parts.pop(0)
        if next == 'm':
            dirty = True
        else:
            git = next[1:]

        # Check: dirty.
        if parts:
            assert parts.pop(0) == 'm', f'expected dirty flag: +m'
            dirty = True

    assert not parts, f'unexpected suffixes: {parts}'
    return major, minor, git, dirty


# Some inline tests to check Git version parsing:
assert parse_git_version(
    'wasi-sdk-21-0-g317548590b40+m') == ('21', '0', '317548590b40', True)
assert parse_git_version('wasi-sdk-21-2+m') == ('21', '2', None, True)
assert parse_git_version(
    'wasi-sdk-23-0-g317548590b40') == ('23', '0', '317548590b40', False)


def git_version():
    version = exec(['git', 'describe', '--long', '--candidates=999',
                    '--match=wasi-sdk-*', '--dirty=+m', f'--abbrev={GIT_REF_LEN}'])
    major, minor, git, dirty = parse_git_version(version)
    version = f'{major}.{minor}'
    if git:
        version += f'g{git}'
    if dirty:
        version += '+m'
    return version


def parse_cmake_set(line):
    return line.split(' ')[1].split(')')[0]


def llvm_cmake_version(llvm_dir):
    path = f'{llvm_dir}/cmake/Modules/LLVMVersion.cmake'
    if not os.path.exists(path):
        # Handle older LLVM versions; see #399.
        path = f'{llvm_dir}/llvm/CMakeLists.txt'
    with open(path) as file:
        for line in file:
            line = line.strip()
            if line.startswith('set(LLVM_VERSION_MAJOR'):
                llvm_version_major = parse_cmake_set(line)
            elif line.startswith('set(LLVM_VERSION_MINOR'):
                llvm_version_minor = parse_cmake_set(line)
            elif line.startswith('set(LLVM_VERSION_PATCH'):
                llvm_version_patch = parse_cmake_set(line)
    return llvm_version_major, llvm_version_minor, llvm_version_patch


def main(action, llvm_dir):
    if action == 'wasi-sdk':
        print(git_version())
    elif action == 'llvm':
        major, minor, path = llvm_cmake_version(llvm_dir)
        print(f'{major}.{minor}.{path}')
    elif action == 'llvm-major':
        major, _, _ = llvm_cmake_version(llvm_dir)
        print(major)
    elif action == 'dump':
        print(git_version())
        print(f'wasi-libc: {git_commit("src/wasi-libc")}')
        print(f'llvm: {git_commit(llvm_dir)}')
        major, minor, path = llvm_cmake_version(llvm_dir)
        print(f'llvm-version: {major}.{minor}.{path}')
        print(f'config: {git_commit("src/config")}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Print the various kinds of versions in wasi-sdk')
    parser.add_argument('action',
                        choices=['wasi-sdk', 'llvm', 'llvm-major', 'dump'],
                        nargs='?',
                        default='wasi-sdk',
                        help='Which kind of version to print (default: wasi-sdk).')
    parser.add_argument('--llvm-dir',
                        nargs='?',
                        default='src/llvm-project',
                        help='Override the location of the LLVM source directory (default: src/llvm-project).')
    args = parser.parse_args()
    main(args.action, args.llvm_dir)
    sys.exit(0)
