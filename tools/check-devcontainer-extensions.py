#!/usr/bin/env python3
import json
import pathlib
import sys


def load_json(path: pathlib.Path):
  with path.open("r", encoding="utf-8") as handle:
    return json.load(handle)


def main() -> int:
  repo_root = pathlib.Path(__file__).resolve().parents[1]
  devcontainer_path = repo_root / ".devcontainer" / "devcontainer.json"
  recommendations_path = repo_root / ".vscode" / "extensions.json"

  devcontainer = load_json(devcontainer_path)
  recommendations = load_json(recommendations_path)

  container_extensions = devcontainer.get("customizations", {}).get("vscode", {}).get("extensions", [])
  recommended_extensions = recommendations.get("recommendations", [])

  container_set = set(container_extensions)
  recommended_set = set(recommended_extensions)

  missing_from_container = sorted(recommended_set - container_set)
  missing_from_recommendations = sorted(container_set - recommended_set)

  if missing_from_container or missing_from_recommendations:
    print("devcontainer extension list and .vscode recommendations differ.")
    if missing_from_container:
      print("Missing from .devcontainer/devcontainer.json:")
      for extension in missing_from_container:
        print(f"  - {extension}")
    if missing_from_recommendations:
      print("Missing from .vscode/extensions.json:")
      for extension in missing_from_recommendations:
        print(f"  - {extension}")
    return 1

  print("devcontainer and workspace extension recommendations are in sync.")
  return 0


if __name__ == "__main__":
  sys.exit(main())