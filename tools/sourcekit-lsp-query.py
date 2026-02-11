#!/usr/bin/env python3

import argparse
import json
import os
import queue
import select
import shlex
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Set, Tuple
from urllib.parse import quote


@dataclass
class QueryTarget:
  file_path: Path
  line: Optional[int] = None
  column: Optional[int] = None


class LSPClient:
  def __init__(
    self,
    workspace: Path,
    scratch_path: Path,
    generated_files_path: Path,
    timeout_seconds: float = 20.0,
  ):
    self.timeout_seconds = timeout_seconds
    self.buffer = bytearray()
    self.request_id = 2

    env = dict(os.environ)
    home_dir = Path.cwd() / ".home"
    (home_dir / "Library" / "Caches" / "org.swift.swiftpm").mkdir(parents=True, exist_ok=True)
    (home_dir / "Library" / "org.swift.swiftpm" / "configuration").mkdir(parents=True, exist_ok=True)
    (home_dir / "Library" / "org.swift.swiftpm" / "security").mkdir(parents=True, exist_ok=True)
    env["HOME"] = str(home_dir)

    scratch_path.mkdir(parents=True, exist_ok=True)
    generated_files_path.mkdir(parents=True, exist_ok=True)

    self.proc = subprocess.Popen(
      [
        "xcrun",
        "sourcekit-lsp",
        "--scratch-path",
        str(scratch_path),
        "--generated-files-path",
        str(generated_files_path),
      ],
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE,
      stderr=subprocess.DEVNULL,
      env=env,
    )
    if self.proc.stdin is None or self.proc.stdout is None:
      raise RuntimeError("Failed to open stdio for sourcekit-lsp")

    self.root_uri = path_to_uri(workspace)

  def initialize(self) -> None:
    self.send(
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {"processId": None, "rootUri": self.root_uri, "capabilities": {}},
      }
    )
    self.wait_for_id(1)
    self.send({"jsonrpc": "2.0", "method": "initialized", "params": {}})

  def next_id(self) -> int:
    current = self.request_id
    self.request_id += 1
    return current

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

  def query(self, action: str, target: QueryTarget):
    file_uri = path_to_uri(target.file_path)
    self.send(
      {
        "jsonrpc": "2.0",
        "method": "textDocument/didOpen",
        "params": {
          "textDocument": {
            "uri": file_uri,
            "languageId": "swift",
            "version": 1,
            "text": target.file_path.read_text(encoding="utf-8"),
          }
        },
      }
    )

    request_id = self.next_id()
    if action == "symbols":
      self.send(
        {
          "jsonrpc": "2.0",
          "id": request_id,
          "method": "textDocument/documentSymbol",
          "params": {"textDocument": {"uri": file_uri}},
        }
      )
    elif action == "hover":
      assert target.line is not None and target.column is not None
      self.send(
        {
          "jsonrpc": "2.0",
          "id": request_id,
          "method": "textDocument/hover",
          "params": {
            "textDocument": {"uri": file_uri},
            "position": {"line": target.line - 1, "character": target.column - 1},
          },
        }
      )
    elif action == "definition":
      assert target.line is not None and target.column is not None
      self.send(
        {
          "jsonrpc": "2.0",
          "id": request_id,
          "method": "textDocument/definition",
          "params": {
            "textDocument": {"uri": file_uri},
            "position": {"line": target.line - 1, "character": target.column - 1},
          },
        }
      )
    else:
      raise ValueError(f"Unsupported action: {action}")

    response = self.wait_for_id(request_id)
    return response.get("result")

  def close(self):
    try:
      request_id = self.next_id()
      self.send({"jsonrpc": "2.0", "id": request_id, "method": "shutdown", "params": {}})
      self.wait_for_id(request_id)
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


def git_output(args: list[str], cwd: Path, optional: bool = False) -> list[str]:
  process = subprocess.run(
    args,
    cwd=cwd,
    capture_output=True,
    text=True,
  )
  if process.returncode != 0:
    if optional:
      return []
    stderr = process.stderr.strip()
    raise RuntimeError(stderr or "git command failed")
  return [line for line in process.stdout.splitlines() if line]


def discover_changed_swift_files(base_ref: str, workspace: Path) -> list[Path]:
  git_root_lines = git_output(["git", "rev-parse", "--show-toplevel"], cwd=workspace)
  if not git_root_lines:
    return []
  git_root = Path(git_root_lines[0]).resolve()

  git_output(["git", "rev-parse", "--verify", base_ref], cwd=git_root)

  compared = git_output(
    ["git", "diff", "--name-only", "--diff-filter=ACMRTUXB", f"{base_ref}...HEAD", "--", "*.swift"],
    cwd=git_root,
  )
  staged = git_output(
    ["git", "diff", "--name-only", "--cached", "--diff-filter=ACMRTUXB", "--", "*.swift"],
    cwd=git_root,
  )
  unstaged = git_output(
    ["git", "diff", "--name-only", "--diff-filter=ACMRTUXB", "--", "*.swift"],
    cwd=git_root,
  )
  untracked = git_output(
    ["git", "ls-files", "--others", "--exclude-standard", "*.swift"],
    cwd=git_root,
  )

  unique_paths = list(dict.fromkeys(compared + staged + unstaged + untracked))
  files: list[Path] = []
  for relative in unique_paths:
    absolute = (git_root / relative).resolve()
    if absolute.exists():
      files.append(absolute)
  return files


def parse_batch_file(batch_file: Path, action: str, cwd: Path) -> list[QueryTarget]:
  targets: list[QueryTarget] = []
  for raw_line in batch_file.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
      continue

    pieces = shlex.split(line)
    if action == "symbols":
      if len(pieces) != 1:
        raise ValueError(f"Invalid symbols batch line: {raw_line}")
      targets.append(QueryTarget(file_path=(cwd / pieces[0]).resolve()))
    else:
      if len(pieces) != 3:
        raise ValueError(f"Invalid {action} batch line: {raw_line}")
      targets.append(
        QueryTarget(
          file_path=(cwd / pieces[0]).resolve(),
          line=int(pieces[1]),
          column=int(pieces[2]),
        )
      )
  return targets


def infer_module_key(file_path: Path, workspace: Path) -> str:
  try:
    relative = file_path.resolve().relative_to(workspace)
  except ValueError:
    return "external"

  parts = relative.parts
  if not parts:
    return "."
  if parts[0] == "Modules" and len(parts) > 1:
    return f"Modules/{parts[1]}"
  return parts[0]


def group_targets_by_module(targets: list[QueryTarget], workspace: Path) -> list[list[QueryTarget]]:
  by_module: dict[str, list[QueryTarget]] = {}
  for target in targets:
    key = infer_module_key(target.file_path, workspace)
    by_module.setdefault(key, []).append(target)

  return [by_module[key] for key in sorted(by_module.keys())]


def distribute_module_groups(
  module_groups: list[list[QueryTarget]], workers: int
) -> list[list[QueryTarget]]:
  assignments: list[list[QueryTarget]] = [[] for _ in range(workers)]
  load: list[int] = [0 for _ in range(workers)]

  for group in sorted(module_groups, key=len, reverse=True):
    index = load.index(min(load))
    assignments[index].extend(group)
    load[index] += len(group)

  return [items for items in assignments if items]


def make_record(
  action: str,
  target: QueryTarget,
  result,
  error: Optional[str],
  worker_id: int,
) -> dict:
  record = {
    "action": action,
    "file": str(target.file_path),
    "result": result,
    "worker": worker_id,
  }
  if target.line is not None and target.column is not None:
    record["line"] = target.line
    record["column"] = target.column
  if error is not None:
    record["error"] = error
  return record


def is_retryable_lsp_error(error: Exception) -> bool:
  message = str(error)
  return (
    "sourcekit-lsp closed stdout" in message
    or "Broken pipe" in message
    or "Timed out waiting" in message
  )


def process_targets_serial(
  action: str,
  targets: list[QueryTarget],
  workspace: Path,
  scratch_path: Path,
  generated_files_path: Path,
  timeout_seconds: float,
) -> list[dict]:
  client: Optional[LSPClient] = None
  records: list[dict] = []

  def open_client() -> LSPClient:
    new_client = LSPClient(
      workspace=workspace,
      scratch_path=scratch_path,
      generated_files_path=generated_files_path,
      timeout_seconds=timeout_seconds,
    )
    new_client.initialize()
    return new_client

  try:
    client = open_client()
    for target in targets:
      attempts = 0
      while True:
        try:
          result = client.query(action, target)
          records.append(make_record(action, target, result, None, worker_id=0))
          break
        except Exception as error:
          if attempts == 0 and is_retryable_lsp_error(error):
            attempts += 1
            client.close()
            client = open_client()
            continue
          records.append(make_record(action, target, None, str(error), worker_id=0))
          break
  finally:
    if client is not None:
      client.close()
  return records


def process_targets_parallel(
  action: str,
  targets: list[QueryTarget],
  workspace: Path,
  scratch_path: Path,
  generated_files_path: Path,
  timeout_seconds: float,
  workers: int,
) -> list[dict]:
  module_groups = group_targets_by_module(targets, workspace)
  assignments = distribute_module_groups(module_groups, workers)

  results_queue: queue.Queue[dict] = queue.Queue()

  def worker_run(worker_index: int, jobs: list[QueryTarget]) -> None:
    client: Optional[LSPClient] = None

    def open_client() -> LSPClient:
      new_client = LSPClient(
        workspace=workspace,
        scratch_path=scratch_path / f"worker-{worker_index}",
        generated_files_path=generated_files_path / f"worker-{worker_index}",
        timeout_seconds=timeout_seconds,
      )
      new_client.initialize()
      return new_client

    try:
      client = open_client()
      for target in jobs:
        attempts = 0
        while True:
          try:
            result = client.query(action, target)
            results_queue.put(make_record(action, target, result, None, worker_index))
            break
          except Exception as error:
            if attempts == 0 and is_retryable_lsp_error(error):
              attempts += 1
              if client is not None:
                client.close()
              client = open_client()
              continue
            results_queue.put(make_record(action, target, None, str(error), worker_index))
            break
    except Exception as error:
      for target in jobs:
        results_queue.put(make_record(action, target, None, str(error), worker_index))
    finally:
      if client is not None:
        client.close()

  threads: list[threading.Thread] = []
  for index, jobs in enumerate(assignments):
    thread = threading.Thread(target=worker_run, args=(index, jobs), daemon=True)
    thread.start()
    threads.append(thread)

  for thread in threads:
    thread.join()

  records: list[dict] = []
  while not results_queue.empty():
    records.append(results_queue.get())

  order = {str(target.file_path): idx for idx, target in enumerate(targets)}
  records.sort(key=lambda item: order.get(item["file"], sys.maxsize))
  return records


def build_parser() -> argparse.ArgumentParser:
  parser = argparse.ArgumentParser(
    description="Run SourceKit-LSP queries (symbols, hover, definition) for one or many Swift files."
  )
  parser.add_argument(
    "--workspace",
    type=Path,
    help="Workspace root. Defaults to ./Modules when present, otherwise current directory.",
  )
  parser.add_argument(
    "--scratch-path",
    type=Path,
    help="Persistent SourceKit-LSP scratch directory (default: <workspace>/.lsp/scratch).",
  )
  parser.add_argument(
    "--generated-files-path",
    type=Path,
    help="Persistent SourceKit-LSP generated-files directory (default: <workspace>/.lsp/generated).",
  )
  parser.add_argument(
    "--batch-file",
    type=Path,
    help="Read additional query targets from file. For symbols: one file path per line.",
  )
  parser.add_argument(
    "--changed-only",
    action="store_true",
    help="For symbols: query only Swift files changed vs --base-ref (plus staged/unstaged/untracked).",
  )
  parser.add_argument(
    "--base-ref",
    default="origin/main",
    help="Base git ref used with --changed-only (default: origin/main).",
  )
  parser.add_argument(
    "--workers",
    type=int,
    default=1,
    choices=[1, 2, 3, 4],
    help="Number of long-lived LSP workers (2-4 enables module-parallel symbols scanning).",
  )
  parser.add_argument(
    "--jsonl",
    action="store_true",
    help="Emit newline-delimited JSON records instead of pretty JSON.",
  )
  parser.add_argument(
    "--jsonl-path",
    type=Path,
    help="Write JSONL records to this file (overwrites existing file).",
  )
  parser.add_argument(
    "--timeout-seconds",
    type=float,
    default=20.0,
    help="Per-request timeout when waiting for SourceKit-LSP responses.",
  )

  subparsers = parser.add_subparsers(dest="action", required=True)

  symbols = subparsers.add_parser("symbols")
  symbols.add_argument("files", nargs="*", type=Path)

  hover = subparsers.add_parser("hover")
  hover.add_argument("file", type=Path)
  hover.add_argument("line", type=int, help="1-based line")
  hover.add_argument("column", type=int, help="1-based column")

  definition = subparsers.add_parser("definition")
  definition.add_argument("file", type=Path)
  definition.add_argument("line", type=int, help="1-based line")
  definition.add_argument("column", type=int, help="1-based column")

  return parser


def resolve_workspace(args: argparse.Namespace) -> Path:
  cwd = Path.cwd().resolve()
  if args.workspace is not None:
    return args.workspace.resolve()
  modules = cwd / "Modules"
  return modules if modules.exists() else cwd


def resolve_targets(
  args: argparse.Namespace, parser: argparse.ArgumentParser, workspace: Path
) -> list[QueryTarget]:
  cwd = Path.cwd().resolve()
  targets: list[QueryTarget] = []

  if args.action in ("hover", "definition"):
    if args.batch_file is not None or args.changed_only:
      parser.error("--batch-file and --changed-only are only supported with the symbols action")
    if args.line < 1 or args.column < 1:
      parser.error("line and column must be >= 1")
    targets.append(
      QueryTarget(file_path=args.file.resolve(), line=args.line, column=args.column)
    )
  else:
    for file in args.files:
      targets.append(QueryTarget(file_path=file.resolve()))

    if args.batch_file is not None:
      batch_file = args.batch_file.resolve()
      if not batch_file.exists():
        parser.error(f"batch file not found: {batch_file}")
      try:
        targets.extend(parse_batch_file(batch_file, action=args.action, cwd=cwd))
      except Exception as error:
        parser.error(str(error))

    if args.changed_only:
      try:
        changed_files = discover_changed_swift_files(args.base_ref, workspace)
      except Exception as error:
        parser.error(f"failed to compute changed files: {error}")
      targets.extend(QueryTarget(file_path=file_path) for file_path in changed_files)

  deduped: list[QueryTarget] = []
  seen: Set[Tuple[str, Optional[int], Optional[int]]] = set()
  for target in targets:
    key = (str(target.file_path), target.line, target.column)
    if key not in seen:
      seen.add(key)
      deduped.append(target)

  if not deduped:
    if args.action == "symbols" and args.changed_only:
      return []
    if args.action == "symbols":
      parser.error("no Swift files selected; pass files, --batch-file, or --changed-only")
    parser.error("no query targets provided")

  missing = [target.file_path for target in deduped if not target.file_path.exists()]
  if missing:
    parser.error(f"file not found: {missing[0]}")

  if args.action != "symbols" and len(deduped) > 1:
    parser.error("hover/definition currently support one query target per invocation")

  return deduped


def emit_output(records: list[dict], use_jsonl: bool, jsonl_path: Optional[Path]) -> None:
  jsonl_lines = [json.dumps(record, separators=(",", ":")) for record in records]

  if jsonl_path is not None:
    output_path = jsonl_path.resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(jsonl_lines) + ("\n" if jsonl_lines else ""), encoding="utf-8")

  if use_jsonl:
    for line in jsonl_lines:
      print(line)
    return

  if len(records) == 1 and "error" not in records[0]:
    print(json.dumps(records[0]["result"], indent=2))
    return

  print(json.dumps(records, indent=2))


def main() -> int:
  parser = build_parser()
  args = parser.parse_args()

  workspace = resolve_workspace(args)
  lsp_root = workspace / ".lsp"
  scratch_path = args.scratch_path.resolve() if args.scratch_path else (lsp_root / "scratch")
  generated_files_path = (
    args.generated_files_path.resolve() if args.generated_files_path else (lsp_root / "generated")
  )

  targets = resolve_targets(args, parser, workspace)
  if not targets:
    print("warning: no changed Swift files found", file=sys.stderr)
    return 0

  if args.workers > 1 and args.action != "symbols":
    parser.error("--workers > 1 is only supported with the symbols action")

  records: list[dict]
  if args.action == "symbols" and args.workers > 1 and len(targets) > 1:
    records = process_targets_parallel(
      action=args.action,
      targets=targets,
      workspace=workspace,
      scratch_path=scratch_path,
      generated_files_path=generated_files_path,
      timeout_seconds=args.timeout_seconds,
      workers=args.workers,
    )
  else:
    records = process_targets_serial(
      action=args.action,
      targets=targets,
      workspace=workspace,
      scratch_path=scratch_path,
      generated_files_path=generated_files_path,
      timeout_seconds=args.timeout_seconds,
    )

  emit_output(records, use_jsonl=args.jsonl, jsonl_path=args.jsonl_path)
  return 1 if any("error" in record for record in records) else 0


if __name__ == "__main__":
  sys.exit(main())
