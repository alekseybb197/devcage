#!/usr/bin/env python3
"""
qwen-acp — run qwen agent in ACP mode via docker exec.

Usage:
  qwen-acp --project myproject "do something"
  echo "do something" | qwen-acp --project myproject
  qwen-acp --workflow ci --node review --role reviewer --project myproject "check the code"
  qwen-acp --raw --project myproject "do something"  # output raw JSONL
"""

import argparse
import json
import subprocess
import sys


def make_initialize(msg_id: int) -> dict:
    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "method": "initialize",
        "params": {"protocolVersion": 1, "capabilities": {}},
    }


def make_load(msg_id: int, session_id: str, cwd: str) -> dict:
    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "method": "session/load",
        "params": {"sessionId": session_id, "cwd": cwd, "mcpServers": []},
    }


def make_set_mode(msg_id: int, session_id: str, mode: str = "yolo") -> dict:
    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "method": "session/set_config_option",
        "params": {"sessionId": session_id, "configId": "mode", "value": mode},
    }


def make_prompt(msg_id: int, session_id: str, text: str) -> dict:
    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "method": "session/prompt",
        "params": {
            "sessionId": session_id,
            "prompt": [{"type": "text", "text": text}],
        },
    }


def send(proc: subprocess.Popen, msg: dict, debug_mode: bool = False, pretty_mode: bool = False):
    if debug_mode:
        output = json.dumps(msg, indent=2, ensure_ascii=False) if pretty_mode else json.dumps(msg, ensure_ascii=False)
        print(f"<<: {output}", file=sys.stderr)
        line = json.dumps(msg, ensure_ascii=False)
    else:
        line = json.dumps(msg, ensure_ascii=False)
    proc.stdin.write(line + "\n")
    proc.stdin.flush()


def wait_for_id(proc: subprocess.Popen, msg_id: int) -> dict:
    """Reads stdout until a response with the required id is received. Returns the message."""
    for raw in proc.stdout:
        raw = raw.strip()
        if not raw:
            continue
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if msg.get("id") == msg_id:
            if "error" in msg:
                raise RuntimeError(
                    f"ACP error for id={msg_id}: {json.dumps(msg['error'], ensure_ascii=False)}"
                )
            return msg


def collect_response(proc: subprocess.Popen, prompt_id: int, raw_mode: bool = False, pretty_mode: bool = False) -> str:
    """Reads the stream and collects agent_message_chunk until stopReason is received.
    If raw_mode is True, outputs raw JSONL lines to stderr and returns empty string.
    If pretty_mode is True, outputs pretty-printed JSONL lines to stderr."""
    chunks = []
    for raw in proc.stdout:
        raw = raw.strip()
        if not raw:
            continue

        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            continue

        # final response to prompt — always check, even in raw mode
        if msg.get("id") == prompt_id:
            if "error" in msg:
                raise RuntimeError(
                    f"Prompt error: {json.dumps(msg['error'], ensure_ascii=False)}"
                )
            if raw_mode:
                output = json.dumps(msg, indent=2, ensure_ascii=False) if pretty_mode else raw
                print(f">>: {output}", file=sys.stderr)
            break

        if raw_mode:
            output = json.dumps(msg, indent=2, ensure_ascii=False) if pretty_mode else raw
            print(f">>: {output}", file=sys.stderr)
            continue

        update = msg.get("params", {}).get("update", {})
        if update.get("sessionUpdate") == "agent_message_chunk":
            text = update.get("content", {}).get("text", "")
            if text:
                chunks.append(text)

    return "".join(chunks)


def read_session_id(container: str, session_path: str) -> str:
    result = subprocess.run(
        ["docker", "exec", container, "cat", session_path],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to read session.id from {container}:{session_path}\n"
            f"stderr: {result.stderr.strip()}"
        )
    session_id = result.stdout.strip()
    if not session_id:
        raise RuntimeError(
            f"File {session_path} is empty in container {container}"
        )
    return session_id


def run(container: str, session_id: str, cwd: str, prompt_text: str, raw_mode: bool = False, debug_mode: bool = False, pretty_mode: bool = False) -> str:
    proc = subprocess.Popen(
        ["docker", "exec", "-i", container, "qwen", "--acp"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )

    try:
        send(proc, make_initialize(1), debug_mode=debug_mode, pretty_mode=pretty_mode)
        wait_for_id(proc, 1)

        send(proc, make_load(2, session_id, cwd), debug_mode=debug_mode, pretty_mode=pretty_mode)
        wait_for_id(proc, 2)

        send(proc, make_set_mode(3, session_id, "yolo"), debug_mode=debug_mode, pretty_mode=pretty_mode)
        wait_for_id(proc, 3)

        send(proc, make_prompt(4, session_id, prompt_text), debug_mode=debug_mode, pretty_mode=pretty_mode)
        response = collect_response(proc, prompt_id=4, raw_mode=raw_mode, pretty_mode=pretty_mode)
    finally:
        proc.stdin.close()
        proc.wait()

    return response


def main():
    parser = argparse.ArgumentParser(
        description="Run qwen agent in ACP mode via docker exec"
    )
    parser.add_argument("--workflow", default="default", help="Workflow name (default: default)")
    parser.add_argument("--node",     default="default", help="Node name (default: default)")
    parser.add_argument("--role",     default="default", help="Agent role (default: default)")
    parser.add_argument("--project",  required=True,     help="Project name (required)")
    parser.add_argument("--raw",      action="store_true", help="Output raw JSONL stream to stderr with '>>: ' prefix")
    parser.add_argument("--debug",    action="store_true", help="Output input JSONL lines to stderr with '<<: ' prefix")
    parser.add_argument("--pretty",   action="store_true", help="Pretty-print JSONL in debug/raw mode")
    parser.add_argument("prompt",     nargs="?",         help="Prompt (if not provided, read from stdin)")

    args = parser.parse_args()

    # prompt: argument or stdin
    if args.prompt:
        prompt_text = args.prompt
    else:
        prompt_text = sys.stdin.read().strip()
        if not prompt_text:
            print("Error: prompt not provided neither as argument nor via stdin", file=sys.stderr)
            sys.exit(1)

    container   = f"devcage-{args.role}-{args.node}"
    cwd         = f"/workspace/{args.project}"
    session_path = f"{cwd}/.devcage/{args.workflow}/{args.node}/session.id"

    try:
        session_id = read_session_id(container, session_path)
        response   = run(container, session_id, cwd, prompt_text, raw_mode=args.raw, debug_mode=args.debug, pretty_mode=args.pretty)
        if not args.raw:
            print(response, end="")
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()