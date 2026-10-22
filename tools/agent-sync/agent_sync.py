#!/usr/bin/env python3
"""Lightweight coordination daemon for Claude Code and Codex.

This daemon monitors repository changes and manages an explicit JSON
blackboard. It does NOT launch cloud agents or guarantee that an agent
reads a message. Dispatch is an adapter responsibility; see README.md.

Install: python -m pip install -r tools/agent-sync/requirements.txt
Run:     python tools/agent-sync/agent_sync.py watch
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import tempfile
import threading
import time
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import fcntl
except ImportError:  # Windows: cross-process locking falls back to in-process only
    fcntl = None

# watchdog is only needed for the watcher; the other commands work without it.
try:
    from watchdog.events import FileSystemEvent, FileSystemEventHandler
    from watchdog.observers import Observer
except ImportError:
    FileSystemEvent = Any
    FileSystemEventHandler = object
    Observer = None

AGENTS = {"Claude", "Astra"}
STATES = {
    "Astra_Design_Phase",
    "Claude_Integration_Phase",
    "Claude_Performance_Audit",
    "Astra_Design_Audit",
    "Testing_Phase",
}
IGNORE_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__",
    ".mypy_cache", ".pytest_cache", "dist", "build",
}
HUB_NAME = ".ai_sync_hub.json"
EVENT_LOG_NAME = ".ai_sync_events.jsonl"
LOCKS_NAME = ".ai_sync_locks.json"
HUB_LOCK_NAME = ".ai_sync_hub.lock"
# tools/agent-sync/agent_sync.py -> repository root
DEFAULT_REPO = Path(__file__).resolve().parents[2]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")  # noqa: UP017 (datetime.UTC needs 3.11)


def default_hub() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "project": {"name": "Hyprland Desktop Shell", "repository_root": "."},
        "system_state": "Astra_Design_Phase",
        "workflow": {
            "current_task_id": None, "current_owner": "Astra",
            "last_transition_at": None, "transition_reason": "Initialized",
            "max_review_cycles": 1, "require_explicit_completion_event": True,
        },
        "active_file_locks": {"locked_by": "None", "files": [], "locks": []},
        "design_tokens": {"theme_name": "To be determined by Astra",
                          "colors": {}, "effects": ["backdrop-blur", "shadows"]},
        "audit_logs": {"claude_performance_notes": [], "astra_design_notes": []},
        "communication_channel": {
            "astra_to_claude_requests": [], "claude_to_astra_responses": []},
        "events": [], "changed_files_since_last_completion": [],
        "last_agent_event": None,
    }


class HubError(RuntimeError):
    pass


class Blackboard:
    """Thread-safe, atomic JSON state updates for one daemon process."""

    def __init__(self, repo: Path):
        self.repo = repo
        self.path = repo / HUB_NAME
        self.event_log = repo / EVENT_LOG_NAME
        self.lock_file = repo / LOCKS_NAME
        self.hub_lock = repo / HUB_LOCK_NAME
        self.mutex = threading.RLock()
        with self._exclusive():
            if not self.path.exists():
                self._atomic_write(default_hub(), self.path)
                logging.warning("Created default %s", self.path.name)
        self.read()  # fail early if malformed

    @contextmanager
    def _exclusive(self):
        """Serialise writers within this process and across processes.

        Claude and Codex each run the CLI as a separate process, so a thread
        lock alone would let two simultaneous publishes overwrite each other.
        """
        with self.mutex:
            if fcntl is None:
                yield
                return
            with self.hub_lock.open("a") as fh:
                fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
                try:
                    yield
                finally:
                    fcntl.flock(fh.fileno(), fcntl.LOCK_UN)

    def read(self) -> dict[str, Any]:
        with self.mutex:
            try:
                data = json.loads(self.path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                raise HubError(f"Cannot read valid {HUB_NAME}: {exc}") from exc
            if data.get("system_state") not in STATES:
                raise HubError(f"Invalid system_state: {data.get('system_state')!r}")
            # Tolerate hand-edited hubs that dropped a section.
            defaults = default_hub()
            for key in ("workflow", "active_file_locks", "communication_channel", "audit_logs"):
                data.setdefault(key, defaults[key])
                for sub_key, value in defaults[key].items():
                    data[key].setdefault(sub_key, value)
            data.setdefault("events", [])
            data.setdefault("changed_files_since_last_completion", [])
            return data

    @staticmethod
    def _atomic_write(data: dict[str, Any], target: Path) -> None:
        target.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp_name = tempfile.mkstemp(prefix=f".{target.name}.", suffix=".tmp", dir=target.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp_name, target)
        finally:
            try:
                os.unlink(tmp_name)
            except FileNotFoundError:
                pass

    def update(self, mutator) -> dict[str, Any]:
        with self._exclusive():
            data = self.read()
            mutator(data)
            data["updated_at"] = utc_now()
            self._atomic_write(data, self.path)
            return data

    def log_event(self, event: dict[str, Any]) -> None:
        record = {"timestamp": utc_now(), **event}
        with self.mutex:
            with self.event_log.open("a", encoding="utf-8") as f:
                f.write(json.dumps(record, ensure_ascii=False) + "\n")

    def transition(self, state: str, reason: str, owner: str | None = None) -> None:
        if state not in STATES:
            raise HubError(f"Unknown state {state!r}")
        if owner is not None and owner not in AGENTS:
            raise HubError(f"Unknown owner {owner!r}")

        def mutate(d):
            d["system_state"] = state
            wf = d.setdefault("workflow", {})
            wf["last_transition_at"] = utc_now()
            wf["transition_reason"] = reason
            if owner:
                wf["current_owner"] = owner
            d.setdefault("events", []).append({
                "id": str(uuid.uuid4()), "type": "state_transition",
                "state": state, "reason": reason, "timestamp": utc_now()
            })
            d["events"] = d["events"][-200:]
        self.update(mutate)
        self.log_event({"type": "state_transition", "state": state, "reason": reason, "owner": owner})
        logging.info("STATE -> %s (%s)", state, reason)

    def publish(self, agent: str, event_type: str, files: list[str], summary: str,
                notes: str = "", task_id: str | None = None) -> None:
        if agent not in AGENTS:
            raise HubError(f"Agent must be one of {sorted(AGENTS)}")
        files = [self.normalize_relpath(p) for p in files]
        now = utc_now()

        def mutate(d):
            d["last_agent_event"] = {
                "agent": agent, "type": event_type, "files": files,
                "summary": summary, "notes": notes, "task_id": task_id,
                "timestamp": now,
            }
            d["changed_files_since_last_completion"] = sorted(
                set(d.get("changed_files_since_last_completion", [])) | set(files)
            )
            d.setdefault("events", []).append({
                "id": str(uuid.uuid4()), "type": "agent_event", **d["last_agent_event"]
            })
            d["events"] = d["events"][-200:]
            if event_type == "design_complete" and agent == "Astra":
                d["system_state"] = "Claude_Performance_Audit"
                d["workflow"]["current_owner"] = "Claude"
                d["workflow"]["last_transition_at"] = now
                d["workflow"]["transition_reason"] = "Astra explicitly published design_complete"
                d["communication_channel"]["astra_to_claude_requests"].append({
                    "timestamp": now, "task_id": task_id,
                    "files": files, "request": "Performance/stability audit of the completed design layer",
                    "summary": summary, "notes": notes, "status": "pending"
                })
            elif event_type == "integration_complete" and agent == "Claude":
                d["system_state"] = "Astra_Design_Audit"
                d["workflow"]["current_owner"] = "Astra"
                d["workflow"]["last_transition_at"] = now
                d["workflow"]["transition_reason"] = "Claude explicitly published integration_complete"
                d["communication_channel"]["claude_to_astra_responses"].append({
                    "timestamp": now, "task_id": task_id,
                    "files": files, "response": "Visual/spatial audit of the integration",
                    "summary": summary, "notes": notes, "status": "pending"
                })
            elif event_type == "performance_audit_complete" and agent == "Claude":
                d["system_state"] = "Astra_Design_Phase"
                d["workflow"]["current_owner"] = "Astra"
                d["workflow"]["last_transition_at"] = now
                d["workflow"]["transition_reason"] = "Claude completed performance audit"
            elif event_type == "design_audit_complete" and agent == "Astra":
                d["system_state"] = "Testing_Phase"
                d["workflow"]["current_owner"] = "Claude"
                d["workflow"]["last_transition_at"] = now
                d["workflow"]["transition_reason"] = "Astra completed design audit"
            elif event_type == "tests_passed" and agent == "Claude":
                d["system_state"] = "Astra_Design_Phase"
                d["workflow"]["current_owner"] = "Astra"
                d["workflow"]["last_transition_at"] = now
                d["workflow"]["transition_reason"] = "Tests passed; next design iteration may begin"
                d["changed_files_since_last_completion"] = []
            elif event_type == "blocked":
                d.setdefault("events", []).append({
                    "id": str(uuid.uuid4()), "type": "blocked", "agent": agent,
                    "summary": summary, "notes": notes, "timestamp": now
                })
            d["events"] = d["events"][-200:]

        self.update(mutate)
        self.log_event({"type": "agent_event", "agent": agent, "event_type": event_type,
                        "files": files, "summary": summary, "task_id": task_id})
        logging.info("Agent event: %s / %s / %s", agent, event_type, summary)

    @staticmethod
    def normalize_relpath(value: str) -> str:
        p = Path(value)
        if p.is_absolute() or ".." in p.parts:
            raise HubError(f"Path must be repository-relative and cannot contain '..': {value}")
        return p.as_posix()

    def acquire(self, agent: str, files: list[str], task_id: str | None, ttl: int = 1800) -> None:
        if agent not in AGENTS:
            raise HubError(f"Agent must be one of {sorted(AGENTS)}")
        paths = sorted(set(self.normalize_relpath(p) for p in files))
        if not paths:
            raise HubError("At least one file is required")
        now_epoch = time.time()
        expires = now_epoch + max(30, min(ttl, 86400))
        conflict = []

        def mutate(d):
            locks = d["active_file_locks"].setdefault("locks", [])
            locks[:] = [x for x in locks if x.get("expires_epoch", 0) > now_epoch]
            for lock in locks:
                overlap = sorted(set(paths) & set(lock.get("files", [])))
                if overlap and lock["agent"] != agent:
                    conflict.append((lock["agent"], overlap))
            if conflict:
                return
            locks.append({"lock_id": str(uuid.uuid4()), "agent": agent, "files": paths,
                          "task_id": task_id, "created_at": utc_now(),
                          "expires_epoch": expires, "ttl_seconds": ttl})
            d["active_file_locks"]["files"] = sorted(
                {f for lock in locks for f in lock["files"]})
            owners = {lock["agent"] for lock in locks}
            d["active_file_locks"]["locked_by"] = next(iter(owners)) if len(owners) == 1 else "Multiple"

        self.update(mutate)
        if conflict:
            who, overlap = conflict[0]
            msg = f"LOCK DENIED: {agent} cannot lock {overlap}; held by {who}"
            self.log_event({"type": "lock_denied", "agent": agent, "message": msg})
            raise HubError(msg)
        self.log_event({"type": "lock_acquired", "agent": agent, "files": paths, "task_id": task_id})
        logging.info("LOCK acquired by %s: %s", agent, ", ".join(paths))

    def release(self, agent: str, files: list[str] | None = None, task_id: str | None = None) -> None:
        if agent not in AGENTS:
            raise HubError(f"Agent must be one of {sorted(AGENTS)}")
        wanted = set(self.normalize_relpath(p) for p in files) if files else None

        def mutate(d):
            locks = d["active_file_locks"].setdefault("locks", [])
            kept = []
            for lock in locks:
                owned = lock.get("agent") == agent and (task_id is None or lock.get("task_id") == task_id)
                if not owned:
                    kept.append(lock)
                elif wanted is not None:
                    remaining = [p for p in lock.get("files", []) if p not in wanted]
                    if remaining:
                        lock["files"] = remaining
                        kept.append(lock)
            d["active_file_locks"]["locks"] = kept
            d["active_file_locks"]["files"] = sorted({f for x in kept for f in x["files"]})
            owners = {x["agent"] for x in kept}
            d["active_file_locks"]["locked_by"] = (
                next(iter(owners)) if len(owners) == 1 else "Multiple" if owners else "None"
            )
        self.update(mutate)
        self.log_event({"type": "lock_released", "agent": agent,
                        "files": sorted(wanted) if wanted else None, "task_id": task_id})
        logging.info("LOCK released by %s", agent)

    def check_lock(self, agent: str, file: str) -> tuple[bool, str]:
        path = self.normalize_relpath(file)
        now = time.time()
        d = self.read()
        locks = d["active_file_locks"].get("locks", [])
        for lock in locks:
            if lock.get("expires_epoch", 0) <= now:
                continue
            if path in lock.get("files", []) and lock.get("agent") != agent:
                return False, f"BLOCKED: {path} is locked by {lock['agent']} (task {lock.get('task_id')})"
        return True, "OK"


class RepoHandler(FileSystemEventHandler):
    def __init__(self, repo: Path, hub: Blackboard, debounce: float = 0.35):
        self.repo = repo
        self.hub = hub
        self.debounce = debounce
        self.last_seen: dict[str, float] = {}
        self.guard = threading.Lock()

    def on_any_event(self, event: FileSystemEvent) -> None:
        if event.is_directory:
            return
        for raw in (event.src_path, getattr(event, "dest_path", "")):
            if not raw:
                continue
            path = Path(raw)
            try:
                rel = path.resolve().relative_to(self.repo.resolve()).as_posix()
            except (ValueError, OSError):
                continue
            if any(part in IGNORE_DIRS for part in Path(rel).parts):
                continue
            if rel in {HUB_NAME, EVENT_LOG_NAME, LOCKS_NAME, HUB_LOCK_NAME} or rel.endswith(".tmp"):
                continue
            now = time.monotonic()
            with self.guard:
                if now - self.last_seen.get(rel, 0) < self.debounce:
                    continue
                self.last_seen[rel] = now
            logging.info("FS change observed: %s (event=%s)", rel, event.event_type)
            self.hub.log_event({"type": "filesystem_change_observed", "path": rel,
                                "event": event.event_type})
            try:
                data = self.hub.read()
                locks = data["active_file_locks"].get("locks", [])
                active = [lock for lock in locks if lock.get("expires_epoch", 0) > time.time()
                          and rel in lock.get("files", [])]
                if active:
                    owners = sorted({lock["agent"] for lock in active})
                    logging.warning(
                        "LOCKED FILE CHANGED: %s; active owner(s): %s. "
                        "Watcher cannot undo writes; use the controlled edit/commit gate.",
                        rel, ", ".join(owners)
                    )
            except HubError as exc:
                logging.error("Blackboard error while handling event: %s", exc)


def cli(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=str(DEFAULT_REPO),
                        help="Repository root (default: the repository this script lives in)")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("watch", help="Watch the repository for changes (default when no command is given)")

    p_transition = sub.add_parser("transition", help="Set workflow state")
    p_transition.add_argument("state", choices=sorted(STATES))
    p_transition.add_argument("--reason", required=True)
    p_transition.add_argument("--owner", choices=sorted(AGENTS))

    p_publish = sub.add_parser("publish", help="Publish explicit agent completion event")
    p_publish.add_argument("--agent", required=True, choices=sorted(AGENTS))
    p_publish.add_argument("--type", required=True, choices=[
        "design_complete", "integration_complete", "performance_audit_complete",
        "design_audit_complete", "tests_passed", "blocked", "note"
    ])
    p_publish.add_argument("--files", nargs="*", default=[])
    p_publish.add_argument("--summary", required=True)
    p_publish.add_argument("--notes", default="")
    p_publish.add_argument("--task-id")

    p_lock = sub.add_parser("lock", help="Acquire file locks")
    p_lock.add_argument("--agent", required=True, choices=sorted(AGENTS))
    p_lock.add_argument("--files", nargs="+", required=True)
    p_lock.add_argument("--task-id")
    p_lock.add_argument("--ttl", type=int, default=1800)

    p_unlock = sub.add_parser("unlock", help="Release file locks")
    p_unlock.add_argument("--agent", required=True, choices=sorted(AGENTS))
    p_unlock.add_argument("--files", nargs="*")
    p_unlock.add_argument("--task-id")

    p_check = sub.add_parser("check", help="Check whether an agent may edit a file")
    p_check.add_argument("--agent", required=True, choices=sorted(AGENTS))
    p_check.add_argument("--file", required=True)

    sub.add_parser("status", help="Print current state")
    args = parser.parse_args(argv)
    repo = Path(args.repo).resolve()

    try:
        hub = Blackboard(repo)
        if args.command == "transition":
            hub.transition(args.state, args.reason, args.owner)
        elif args.command == "publish":
            hub.publish(args.agent, args.type, args.files, args.summary, args.notes, args.task_id)
        elif args.command == "lock":
            hub.acquire(args.agent, args.files, args.task_id, args.ttl)
        elif args.command == "unlock":
            hub.release(args.agent, args.files or None, args.task_id)
        elif args.command == "check":
            ok, message = hub.check_lock(args.agent, args.file)
            print(message)
            return 0 if ok else 2
        elif args.command == "status":
            print(json.dumps(hub.read(), indent=2, ensure_ascii=False))
        else:
            if Observer is None:
                raise HubError("The watcher needs watchdog: python -m pip install -r tools/agent-sync/requirements.txt")
            observer = Observer()
            observer.schedule(RepoHandler(repo, hub), str(repo), recursive=True)
            observer.start()
            logging.info("Watching repository: %s", repo)
            logging.info("Press Ctrl-C to stop. State is stored in %s", HUB_NAME)
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                logging.info("Stopping watcher...")
            finally:
                observer.stop()
                observer.join()
        return 0
    except HubError as exc:
        logging.error("%s", exc)
        return 2


if __name__ == "__main__":
    logging.basicConfig(
        level=os.environ.get("AI_SYNC_LOG_LEVEL", "INFO").upper(),
        format="%(asctime)s %(levelname)s %(message)s",
    )
    sys.exit(cli())
