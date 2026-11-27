"""Check that the Gen8 catalog exposes the full dataset module input type."""

from difflib import unified_diff
from pathlib import Path


def type_body(path: Path, variable: str, wrapper: str) -> list[str]:
    # Compare formatted HCL declarations, not evaluated instance values.
    _, _, block = path.read_text(encoding="utf-8").partition(f'variable "{variable}" {{\n')
    block, _, _ = block.partition("\n}")
    _, opening, body = block.partition(f"= {wrapper}{{\n")
    body, closing, _ = body.partition("\n  }")
    if not opening or not closing:
        raise SystemExit(f"Cannot find the type of {variable!r} in {path}")
    return [" ".join(line.split()) for line in body.splitlines() if line.strip()]


def main() -> None:
    module = Path(__file__).resolve().parents[1]
    root = module.parents[1] / "gen8" / "variables.datasets.tf"
    datasets = type_body(root, "datasets", "map(object(")
    dataset = type_body(module / "variables.tf", "dataset", "object(")
    if datasets != dataset:
        diff = "\n".join(unified_diff(dataset, datasets, "module/dataset", "gen8/datasets", lineterm=""))
        raise SystemExit(f"Gen8 datasets must expose the same object type as the dataset module\n{diff}")


if __name__ == "__main__":
    main()
