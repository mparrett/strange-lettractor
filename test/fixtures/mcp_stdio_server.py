#!/usr/bin/env python3
"""Fixture MCP stdio server for tests: newline-delimited JSON-RPC on
stdin/stdout, stderr for logs only. Never used in production."""
import sys
import json


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def log(msg):
    sys.stderr.write(str(msg) + "\n")
    sys.stderr.flush()


def handle(req):
    rid = req.get("id")
    method = req.get("method")
    params = req.get("params") or {}
    if method == "initialize":
        return {"jsonrpc": "2.0", "id": rid,
                "result": {"protocolVersion": "2026-07-28",
                           "serverInfo": {"name": "fixture"}}}
    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": rid,
                "result": {"tools": [{"name": "quote",
                                      "description": "Get a quote"}]}}
    if method == "tools/call":
        args = params.get("arguments") or {}
        symbol = args.get("symbol", "?")
        return {"jsonrpc": "2.0", "id": rid,
                "result": {"content": [{"type": "text",
                                        "text": "price 42 for " + str(symbol)}]}}
    if method == "resources/read":
        return {"jsonrpc": "2.0", "id": rid,
                "result": {"contents": [{"uri": params.get("uri", ""),
                                         "text": "fixture resource"}]}}
    if rid is None:
        return None
    return {"jsonrpc": "2.0", "id": rid,
            "error": {"code": -32601, "message": "unknown method " + str(method)}}


def main():
    emit_request = "--emit-request" in sys.argv[1:]
    if emit_request:
        emit({"jsonrpc": "2.0", "id": 99, "method": "roots/list", "params": {}})
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception as exc:
            log("bad line: " + str(exc))
            continue
        try:
            resp = handle(req)
        except Exception as exc:
            log("handler failed: " + str(exc))
            continue
        if resp is not None:
            emit(resp)


if __name__ == "__main__":
    main()
