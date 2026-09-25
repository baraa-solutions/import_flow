"""
Deterministic pytest sharding for CI (.github/workflows/ci.yml), no extra dependency.

Collects tests/unit/test_*.py and tests/integration/test_*.py, sorts them by path and packs them greedily
(largest file first, by byte size as a cheap proxy for run time) into N shards. The same checkout always gives the
same split, every file lands in exactly one shard, and the shards are balanced to within one large file.

Usage:
  python scripts/ci/shard_tests.py --shards 4 --index 1          # prints the files of shard 1 (1-based), one per line
  python -m pytest $(python scripts/ci/shard_tests.py --shards 4 --index 1)

Exit code: 0 = printed (a shard may be empty only when there are fewer files than shards), 2 = bad arguments.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import List, Optional, Sequence

PROJECT_DIR = Path(__file__).resolve().parents[2]
TEST_DIRS = ("tests/unit", "tests/integration")


def collect_test_files(root: Path = PROJECT_DIR) -> List[str]:
    files: List[str] = []
    for rel in TEST_DIRS:
        base = root / rel
        if base.is_dir():
            files.extend(p.relative_to(root).as_posix() for p in base.rglob("test_*.py") if p.is_file())
    return sorted(set(files))


def split(files: Sequence[str], shards: int, root: Path = PROJECT_DIR) -> List[List[str]]:
    """Greedy longest-processing-time packing; ties broken by path so the result is deterministic."""
    weighted = sorted(((max((root / f).stat().st_size, 1), f) for f in files), key=lambda item: (-item[0], item[1]))
    buckets: List[List[str]] = [[] for _ in range(shards)]
    loads = [0] * shards
    for weight, name in weighted:
        target = min(range(shards), key=lambda i: (loads[i], i))
        buckets[target].append(name)
        loads[target] += weight
    return [sorted(b) for b in buckets]


def main(argv: Optional[Sequence[str]] = None, root: Path = PROJECT_DIR) -> int:
    parser = argparse.ArgumentParser(description="Print the test files of one CI shard.")
    parser.add_argument("--shards", type=int, required=True)
    parser.add_argument("--index", type=int, required=True, help="1-based shard index")
    args = parser.parse_args(argv)
    if args.shards < 1 or not 1 <= args.index <= args.shards:
        print("error: need --shards >= 1 and 1 <= --index <= --shards", file=sys.stderr)
        return 2
    files = collect_test_files(root)
    if not files:
        print("error: no test files found", file=sys.stderr)
        return 2
    for name in split(files, args.shards, root)[args.index - 1]:
        print(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
