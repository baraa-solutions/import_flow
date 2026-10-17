"""
Check the `path:line` citations in a module reference doc (docs/modules/<module>.md).

A citation is a backtick span such as `modules/import_documentation/service.py:450` or
`modules/import_documentation/service.py:450-460`. A short form `:529` after a full citation on the
same doc line refers to that file. Each citation must name a file by its path from the repo root, the
file must exist, and every cited line must be inside the file. A line hint outside backticks, such as
(:529), is an error: the checker cannot verify it.

Usage: python scripts/check_doc_citations.py docs/modules/<module>.md [more docs...]
Exit code 0 when every citation is valid, 1 otherwise (one error per line on stdout).
"""
import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[1]
CODE_SPAN = re.compile(r"`([^`\n]+)`")
FULL_CITATION = re.compile(r"^(?P<path>[\w./-]+\.\w+):(?P<start>\d+)(?:-(?P<end>\d+))?$")
SHORT_CITATION = re.compile(r"^:(?P<start>\d+)(?:-(?P<end>\d+))?$")
PLAIN_LINE_HINT = re.compile(r"(?<![\w/.]):\d+(?:-\d+)?(?!\w)")


def count_lines(path: Path) -> int:
    with path.open("rb") as handle:
        return sum(1 for _ in handle)


def check_line_range(path_text: str, start: int, end: int, line_counts: dict[str, int]) -> str | None:
    total = line_counts[path_text]
    if start < 1 or end < start:
        return f"bad line range {start}-{end}"
    if end > total:
        return f"line {end} is past the end of the file ({total} lines)"
    return None


def resolve_path(path_text: str, root: Path, line_counts: dict[str, int]) -> str | None:
    """Return an error message, or None after caching the file's line count."""
    if path_text in line_counts:
        return None
    target = root / path_text
    if not target.is_file():
        if "/" not in path_text:
            return "bare file name; write the full path from the repo root"
        return "file does not exist"
    line_counts[path_text] = count_lines(target)
    return None


def find_citation_errors(doc_text: str, root: Path = PROJECT_DIR) -> list[str]:
    errors: list[str] = []
    line_counts: dict[str, int] = {}
    for doc_line_number, doc_line in enumerate(doc_text.splitlines(), start=1):
        previous_path: str | None = None
        for hint in PLAIN_LINE_HINT.findall(CODE_SPAN.sub(" ", doc_line)):
            errors.append(f"line {doc_line_number}: {hint}: line hint outside backticks; write `{hint}`")
        for span in CODE_SPAN.findall(doc_line):
            span = span.strip()
            full = FULL_CITATION.match(span)
            short = SHORT_CITATION.match(span)
            if full:
                path_text = full["path"]
                start = int(full["start"])
                end = int(full["end"] or start)
                error = resolve_path(path_text, root, line_counts)
                if error:
                    errors.append(f"line {doc_line_number}: `{span}`: {error}")
                    previous_path = None
                    continue
                previous_path = path_text
            elif short:
                if previous_path is None:
                    errors.append(f"line {doc_line_number}: `{span}`: short citation with no full citation before it")
                    continue
                path_text = previous_path
                start = int(short["start"])
                end = int(short["end"] or start)
            else:
                continue
            error = check_line_range(path_text, start, end, line_counts)
            if error:
                errors.append(f"line {doc_line_number}: `{span}`: {error}")
    return errors


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__.strip())
        return 1
    failed = False
    for doc_argument in argv:
        doc_path = Path(doc_argument)
        errors = find_citation_errors(doc_path.read_text(encoding="utf-8"))
        for error in errors:
            print(f"{doc_argument}: {error}")
        failed = failed or bool(errors)
        if not errors:
            print(f"{doc_argument}: all citations OK")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
