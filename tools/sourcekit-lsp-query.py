#!/usr/bin/env python3

import argparse
import json
import os
import select
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import quote


class LSPClient:
  def __init__(self, workspace: Path, timeout_seconds: float = 20.0):
    self.timeout_seconds = timeout_seconds
    self.buffer = bytearray()

    env = dict(os.environ)
    home_dir = Path.cwd() / ".home"
    (home_dir / "Library" / "Caches" / "org.swift.swiftpm").mkdir(parents=True, exist_ok=True)
    (home_dir / "Library" / "org.swift.swiftpm" / "configuration").mkdir(parents=True, exist_ok=True)
    (home_dir / "Library" / "org.swift.swiftpm" / "security").mkdir(parents=True, exist_ok=True)
    env["HOME"] = str(home_dir)

    self.proc = subprocess.Popen(
      ["xcrun", "sourcekit-lsp"],
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE,
      stderr=subprocess.DEVNULL,
      env=env,
    )
    if self.proc.stdin is None or self.proc.stdout is None:
      raise RuntimeError("Failed to open stdio for sourcekit-lsp")

    self.root_uri = path_to_uri(workspace)

  def send(self, payload: dict) -> None:
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    assert self.proc.stdin is not None
    self.proc.stdin.write(header)
    self.proc.stdin.write(body)
    self.proc.stdin.flush()

  def _try_parse_message(self):
    separator = self.buffer.find(b"\r\n\r\n")
    if separator == -1:
      return None
    header_bytes = bytes(self.buffer[:separator])
    headers = header_bytes.decode("ascii", errors="replace").split("\r\n")
    content_length = None
    for header in headers:
      if header.lower().startswith("content-length:"):
        content_length = int(header.split(":", 1)[1].strip())
        break
    if content_length is None:
      raise RuntimeError("Invalid LSP message: missing Content-Length")

    full_length = separator + 4 + content_length
    if len(self.buffer) < full_length:
      return None

    body = bytes(self.buffer[separator + 4 : full_length])
    del self.buffer[:full_length]
    return json.loads(body.decode("utf-8"))

  def read_message(self, timeout_seconds: float):
    deadline = time.monotonic() + timeout_seconds
    while True:
      parsed = self._try_parse_message()
      if parsed is not None:
        return parsed

      remaining = deadline - time.monotonic()
      if remaining <= 0:
        raise TimeoutError("Timed out waiting for sourcekit-lsp response")

      assert self.proc.stdout is not None
      ready, _, _ = select.select([self.proc.stdout], [], [], remaining)
      if not ready:
        continue
      chunk = os.read(self.proc.stdout.fileno(), 4096)
      if not chunk:
        raise RuntimeError("sourcekit-lsp closed stdout")
      self.buffer.extend(chunk)

  def wait_for_id(self, request_id: int):
    deadline = time.monotonic() + self.timeout_seconds
    while True:
      remaining = deadline - time.monotonic()
      if remaining <= 0:
        raise TimeoutError(f"Timed out waiting for response id={request_id}")
      message = self.read_message(remaining)
      if message.get("id") == request_id:
        return message

  def close(self):
    try:
      self.send({"jsonrpc": "2.0", "id": 9999, "method": "shutdown", "params": {}})
      self.wait_for_id(9999)
      self.send({"jsonrpc": "2.0", "method": "exit", "params": {}})
    except Exception:
      pass

    if self.proc.poll() is None:
      self.proc.terminate()
      try:
        self.proc.wait(timeout=2)
      except subprocess.TimeoutExpired:
        self.proc.kill()
        self.proc.wait(timeout=2)


def path_to_uri(path: Path) -> str:
  return "file://" + quote(path.as_posix(), safe="/-._~")


def build_parser() -> argparse.ArgumentParser:
  parser = argparse.ArgumentParser(
    description="Run simple SourceKit-LSP queries (symbols, hover, definition)."
  )
  parser.add_argument(
    "--workspace",
    type=Path,
    help="Workspace root. Defaults to ./Modules when present, otherwise current directory.",
  )
  subparsers = parser.add_subparsers(dest="action", required=True)

  symbols = subparsers.add_parser("symbols")
  symbols.add_argument("file", type=Path)

  hover = subparsers.add_parser("hover")
  hover.add_argument("file", type=Path)
  hover.add_argument("line", type=int, help="1-based line")
  hover.add_argument("column", type=int, help="1-based column")

  definition = subparsers.add_parser("definition")
  definition.add_argument("file", type=Path)
  definition.add_argument("line", type=int, help="1-based line")
  definition.add_argument("column", type=int, help="1-based column")

  return parser


def main() -> int:
  parser = build_parser()
  args = parser.parse_args()

  file_path = args.file.resolve()
  if not file_path.exists():
    print(f"error: file not found: {file_path}", file=sys.stderr)
    return 1

  cwd = Path.cwd().resolve()
  if args.workspace is not None:
    workspace = args.workspace.resolve()
  else:
    modules = cwd / "Modules"
    workspace = modules if modules.exists() else cwd

  line = None
  column = None
  if args.action in ("hover", "definition"):
    line = args.line
    column = args.column
    if line < 1 or column < 1:
      print("error: line and column must be >= 1", file=sys.stderr)
      return 1

  client = LSPClient(workspace=workspace)
  try:
    client.send(
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {"processId": None, "rootUri": client.root_uri, "capabilities": {}},
      }
    )
    client.wait_for_id(1)
    client.send({"jsonrpc": "2.0", "method": "initialized", "params": {}})

    client.send(
      {
        "jsonrpc": "2.0",
        "method": "textDocument/didOpen",
        "params": {
          "textDocument": {
            "uri": path_to_uri(file_path),
            "languageId": "swift",
            "version": 1,
            "text": file_path.read_text(encoding="utf-8"),
          }
        },
      }
    )

    if args.action == "symbols":
      client.send(
        {
          "jsonrpc": "2.0",
          "id": 2,
          "method": "textDocument/documentSymbol",
          "params": {"textDocument": {"uri": path_to_uri(file_path)}},
        }
      )
    elif args.action == "hover":
      client.send(
        {
          "jsonrpc": "2.0",
          "id": 2,
          "method": "textDocument/hover",
          "params": {
            "textDocument": {"uri": path_to_uri(file_path)},
            "position": {"line": line - 1, "character": column - 1},
          },
        }
      )
    elif args.action == "definition":
      client.send(
        {
          "jsonrpc": "2.0",
          "id": 2,
          "method": "textDocument/definition",
          "params": {
            "textDocument": {"uri": path_to_uri(file_path)},
            "position": {"line": line - 1, "character": column - 1},
          },
        }
      )

    response = client.wait_for_id(2)
    print(json.dumps(response.get("result"), indent=2))
    return 0
  finally:
    client.close()


if __name__ == "__main__":
  sys.exit(main())
