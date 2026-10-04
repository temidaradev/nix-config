#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "gliner2[local]>=2,<3",
#     "torch>=2.1",
#     "mcp>=2,<3",
# ]
#
# [tool.uv]
# index-strategy = "unsafe-best-match"
#
# [[tool.uv.index]]
# name = "pytorch-cpu"
# url = "https://download.pytorch.org/whl/cpu"
# explicit = true
#
# [tool.uv.sources]
# torch = { index = "pytorch-cpu" }
# ///

import gc
import io
import os
import sys
import threading
import time
from pathlib import Path
from typing import Any

import anyio
from mcp.server.mcpserver import MCPServer
from mcp.server.stdio import stdio_server
from mcp.types import ToolAnnotations

MODEL_ID = os.environ.get("GLINER_DECIDE_MODEL", "fastino/GLiNER2.5-Decide")
READ_ONLY = ToolAnnotations(readOnlyHint=True, idempotentHint=True, openWorldHint=False)

mcp = MCPServer(
    "gliner-decide",
    instructions=(
        "Fast local classifier (GLiNER2.5-Decide, DeBERTa-v3-large). Use it for "
        "intent, sentiment, priority, routing, yes/no questions over a passage, "
        "ordinal ratings and other label-picking decisions over short texts."
    ),
)


POWER_SUPPLY = Path("/sys/class/power_supply")
POLL_SECONDS = 15

_lock = threading.Lock()
_model = None


def on_ac() -> bool:
    mains = [p for p in POWER_SUPPLY.glob("*") if _read(p / "type") == "Mains"]
    return not mains or any(_read(p / "online") == "1" for p in mains)


def _read(path: Path) -> str:
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def _load():
    global _model
    if _model is None:
        from gliner2 import AutoExtractor

        print(f"loading {MODEL_ID}", file=sys.stderr)
        _model = AutoExtractor.from_pretrained(MODEL_ID)
    return _model


def _unload():
    global _model
    if _model is not None:
        print(f"on battery, unloading {MODEL_ID}", file=sys.stderr)
        _model = None
        gc.collect()


def model():
    with _lock:
        if not on_ac():
            _unload()
            raise RuntimeError(
                "gliner-decide only runs on AC power; the laptop is on battery. "
                "Classify the text yourself instead."
            )
        return _load()


def watch_power():
    while True:
        with _lock:
            _load() if on_ac() else _unload()
        time.sleep(POLL_SECONDS)


@mcp.tool(annotations=READ_ONLY)
def classify(text: str, tasks: dict[str, Any]) -> dict[str, Any]:
    """Classify a text with one or more label sets (heads) in a single pass.

    `tasks` maps a head name to either:
      - a list of labels: {"intent": ["refund", "bug_report", "other"]}
      - a config object with:
          "labels": list of labels, or {label: description} for clearer meaning
          "multi_label": true to return every matching label (default false)
          "cls_threshold": score cutoff for multi_label (e.g. 0.4)
          "prompt": a question asked over the text, e.g. with labels ["yes", "no"]

    Returns {head: label} for single-label heads and {head: [labels]} for
    multi-label heads.
    """
    return model().classify_text(text, tasks)


@mcp.tool(annotations=READ_ONLY)
def classify_batch(texts: list[str], tasks: dict[str, Any]) -> list[dict[str, Any]]:
    """Run the same `tasks` (see `classify`) over many texts, one result per text."""
    m = model()
    return [m.classify_text(t, tasks) for t in texts]


async def serve(rpc_out):
    stdout = anyio.wrap_file(io.TextIOWrapper(rpc_out, encoding="utf-8"))
    async with stdio_server(stdout=stdout) as (read_stream, write_stream):
        server = mcp._lowlevel_server
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    rpc_out = os.fdopen(os.dup(1), "wb")
    os.dup2(2, 1)
    sys.stdout = sys.stderr
    threading.Thread(target=watch_power, daemon=True).start()
    anyio.run(serve, rpc_out)
