"""Run the Moonlight Gu POC through a local ComfyUI server.

The custom node pack lives at:
    integrations/comfyui/wenzhen_asset_pipeline

Copy or symlink that directory into ComfyUI's custom_nodes directory, start
ComfyUI, then run:
    python tools/comfyui/run_moonlight_gu_poc.py
"""
from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path


WEB_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WORKFLOW = Path(__file__).resolve().parent / "moonlight_gu_poc_api.json"
DEFAULT_SOURCE = (
    WEB_ROOT.parents[1]
    / "docs"
    / "art"
    / "references"
    / "moonlight"
    / "canonical_form.png"
)
DEFAULT_ASSET_ROOT = WEB_ROOT / "assets" / "gu" / "moonlight_gu"


def request_json(url: str, payload: dict | None = None) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="GET" if payload is None else "POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def build_prompt(workflow_path: Path, source: Path, asset_root: Path) -> dict:
    text = workflow_path.read_text(encoding="utf-8")
    text = text.replace("{{SOURCE_PATH}}", str(source.resolve()).replace("\\", "/"))
    text = text.replace("{{ASSET_ROOT}}", str(asset_root.resolve()).replace("\\", "/"))
    return json.loads(text)


def wait_for_result(server: str, prompt_id: str, timeout_seconds: int) -> dict:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        history = request_json(f"{server}/history/{prompt_id}")
        if prompt_id in history:
            return history[prompt_id]
        time.sleep(1.0)
    raise TimeoutError(f"ComfyUI did not finish prompt {prompt_id} in {timeout_seconds}s")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", default="http://127.0.0.1:8188")
    parser.add_argument("--workflow", type=Path, default=DEFAULT_WORKFLOW)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--asset-root", type=Path, default=DEFAULT_ASSET_ROOT)
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    prompt = build_prompt(args.workflow, args.source, args.asset_root)
    if args.dry_run:
        print(json.dumps(prompt, ensure_ascii=False, indent=2))
        return

    try:
        queued = request_json(
            f"{args.server}/prompt",
            {"prompt": prompt, "client_id": str(uuid.uuid4())},
        )
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"ComfyUI rejected the workflow: HTTP {error.code}\n{details}") from error
    except urllib.error.URLError as error:
        raise SystemExit(
            f"ComfyUI is not reachable at {args.server}. "
            "Install/copy the custom node pack and start ComfyUI first.\n"
            f"{error}"
        ) from error

    prompt_id = queued["prompt_id"]
    print(f"queued {prompt_id}")
    result = wait_for_result(args.server, prompt_id, args.timeout)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print(f"manifest: {args.asset_root.resolve() / 'manifest.json'}")


if __name__ == "__main__":
    main()
