#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12,<3.14"
# dependencies = [
#     "kev[mlx]",
#     "torch>=2.6,<2.9",
#     "mcp>=2,<3",
# ]
#
# [[tool.uv.index]]
# name = "pytorch-cpu"
# url = "https://download.pytorch.org/whl/cpu"
# explicit = true
#
# [tool.uv.sources]
# kev = { git = "https://github.com/jaredpalmer/kev", rev = "fe64b1274ea7f80d4095866df90666abb03e9cf6" }
# torch = [{ index = "pytorch-cpu", marker = "sys_platform == 'linux'" }]
# ///

import gc
import io
import os
import sys
import threading
import time
from dataclasses import replace
from pathlib import Path
from typing import Any

import anyio
from mcp.server.mcpserver import MCPServer
from mcp.server.stdio import stdio_server
from mcp.types import ToolAnnotations

MODEL_ID = os.environ.get("KEV_MODEL", "jaredpalmer/kev-4b")
READ_ONLY = ToolAnnotations(readOnlyHint=True, idempotentHint=True, openWorldHint=False)

mcp = MCPServer(
    "kev-decide",
    instructions=(
        "Local Kev-4B decision model. Use it to answer multiple typed questions "
        "over the same text or JSON: choices (intent, sentiment, routing), "
        "yes/no probabilities and ordinal scores. Runs only on AC power."
    ),
)

POWER_SUPPLY = Path("/sys/class/power_supply")
POLL_SECONDS = 15

_lock = threading.Lock()
_model = None
_tokenizer = None


def _read(path: Path) -> str:
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def on_ac() -> bool:
    mains = [p for p in POWER_SUPPLY.glob("*") if _read(p / "type") == "Mains"]
    return not mains or any(_read(p / "online") == "1" for p in mains)


def _load():
    global _model, _tokenizer
    if _model is None:
        import torch
        from kev.checkpoint import Checkpoint, LoadOptions

        # Linux uses CPU wheels; Apple Silicon uses Kev's MLX backend.
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        opts = LoadOptions.from_env()
        if opts.backend is None:
            opts = replace(opts, backend="auto")
        if device == "mps":
            if opts.dtype is None:
                opts = replace(opts, dtype=torch.bfloat16)
            if opts.attn is None:
                opts = replace(opts, attn="sdpa")
        print(f"loading {MODEL_ID} on {device}", file=sys.stderr)
        _tokenizer, _model = Checkpoint(MODEL_ID).load(device, opts)


def _unload():
    global _model, _tokenizer
    if _model is not None:
        backend = _model.backend
        print(f"on battery, unloading {MODEL_ID}", file=sys.stderr)
        _model = _tokenizer = None
        gc.collect()
        if backend == "mlx":
            import mlx.core as mx

            mx.clear_cache()
        else:
            import torch

            if torch.backends.mps.is_available():
                torch.mps.empty_cache()


def _require_ac():
    if not on_ac():
        _unload()
        raise RuntimeError(
            "kev-decide only runs on AC power; the laptop is on battery. "
            "Answer the questions yourself instead."
        )


def watch_power():
    while True:
        try:
            with _lock:
                _load() if on_ac() else _unload()
        except Exception as exc:
            # A failed download must not kill battery monitoring or the MCP server.
            print(f"kev-decide: {exc}", file=sys.stderr)
        time.sleep(POLL_SECONDS)


@mcp.tool(annotations=READ_ONLY)
def decide(state: Any, questions: dict[str, Any]) -> dict[str, Any]:
    """Answer named questions over a text or JSON state using local Kev-4B.

    Each question has a `type`, `instructions` and (where needed) `criteria`:
      - choice: pick one label; criteria maps labels to descriptions or null.
        {"type": "choice", "instructions": "Route this ticket",
         "criteria": {"billing": "Charges and refunds", "technical": "Bugs"}}
      - noul: probability that a yes/no question is true (0..1).
        {"type": "noul", "instructions": "Is the customer requesting a refund?"}
      - score: expected zero-based level; criteria lists levels in order.
        {"type": "score", "instructions": "How urgent is this?",
         "criteria": ["can wait", "this week", "today"]}

    For multiple matching labels, ask a separate noul question for each label.
    Returns model, named answers (including probabilities/confidence where
    applicable), input token count and inference latency. Oversized inputs
    are rejected rather than silently truncated.
    """
    # Hold the lock throughout inference so the power watcher cannot unload
    # a model still in use. Recheck after loading in case AC was disconnected.
    with _lock:
        _require_ac()
        from kev.api import SystemOneRequest, to_answers, to_record
        from kev.model import admit

        request = SystemOneRequest(state=state, questions=questions)
        record, meta = to_record(request)
        _load()
        _require_ac()
        enc = admit(_model, _tokenizer, record, truncate=False)
        started = time.perf_counter()
        probabilities = [p.tolist() for p in _model.probs(enc)]
        return {
            "model": MODEL_ID,
            "answers": to_answers(probabilities, meta),
            "usage": {"input_tokens": len(enc["ids"])},
            "latency_ms": round((time.perf_counter() - started) * 1000, 1),
        }


@mcp.tool(annotations=READ_ONLY)
def decide_batch(states: list[Any], questions: dict[str, Any]) -> list[dict[str, Any]]:
    """Apply the same questions (see decide) to each state, in input order.

    States run sequentially to limit memory use and check AC before each one.
    """
    return [decide(state, questions) for state in states]


async def serve(rpc_out):
    stdout = anyio.wrap_file(io.TextIOWrapper(rpc_out, encoding="utf-8"))
    async with stdio_server(stdout=stdout) as (read_stream, write_stream):
        server = mcp._lowlevel_server
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    # Model downloads and native libraries may print to stdout. Keep those
    # messages on stderr and reserve the original stdout for the MCP protocol.
    rpc_out = os.fdopen(os.dup(1), "wb")
    os.dup2(2, 1)
    sys.stdout = sys.stderr
    threading.Thread(target=watch_power, daemon=True).start()
    anyio.run(serve, rpc_out)
