"""
Grafana → Jira bridge.

Grafana 11.6's native Jira contact point still calls the removed
/rest/api/3/search endpoint (HTTP 410). This tiny webhook creates issues
via /rest/api/3/issue instead, which works on current Jira Cloud.
"""

from __future__ import annotations

import base64
import json
import logging
import os
from typing import Any

import requests
from flask import Flask, jsonify, request

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("jira-bridge")

app = Flask(__name__)

JIRA_BASE_URL = os.environ["JIRA_BASE_URL"].rstrip("/")
JIRA_EMAIL = os.environ["JIRA_EMAIL"]
JIRA_API_TOKEN = os.environ["JIRA_API_TOKEN"]
JIRA_PROJECT_KEY = os.environ.get("JIRA_PROJECT_KEY", "KAN")
# Prefer ID — stable across RU/EN UI. Name is fallback only.
JIRA_ISSUE_TYPE_ID = os.environ.get("JIRA_ISSUE_TYPE_ID", "").strip()
JIRA_ISSUE_TYPE = os.environ.get("JIRA_ISSUE_TYPE", "Task")


def jira_headers() -> dict[str, str]:
    token = base64.b64encode(f"{JIRA_EMAIL}:{JIRA_API_TOKEN}".encode()).decode()
    return {
        "Authorization": f"Basic {token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }


def adf_paragraph(text: str) -> dict[str, Any]:
    return {
        "type": "doc",
        "version": 1,
        "content": [
            {
                "type": "paragraph",
                "content": [{"type": "text", "text": text[:32000] or "(empty)"}],
            }
        ],
    }


def create_issue(summary: str, description: str) -> dict[str, Any]:
    if JIRA_ISSUE_TYPE_ID:
        issuetype: dict[str, str] = {"id": JIRA_ISSUE_TYPE_ID}
    else:
        issuetype = {"name": JIRA_ISSUE_TYPE}
    payload = {
        "fields": {
            "project": {"key": JIRA_PROJECT_KEY},
            "summary": summary[:255],
            "issuetype": issuetype,
            "description": adf_paragraph(description),
        }
    }
    url = f"{JIRA_BASE_URL}/rest/api/3/issue"
    r = requests.post(url, headers=jira_headers(), data=json.dumps(payload), timeout=30)
    if r.status_code >= 300:
        log.error("Jira create failed %s: %s", r.status_code, r.text)
        r.raise_for_status()
    return r.json()


def alert_lines(alert: dict[str, Any]) -> tuple[str, str]:
    labels = alert.get("labels") or {}
    ann = alert.get("annotations") or {}
    name = labels.get("alertname") or "Grafana alert"
    severity = labels.get("severity") or "unknown"
    summary = f"[ALERT] {name} ({severity})"
    parts = [
        ann.get("summary") or ann.get("description") or "",
        f"status={alert.get('status')}",
        f"labels={json.dumps(labels, ensure_ascii=False)}",
    ]
    if alert.get("generatorURL"):
        parts.append(f"source={alert['generatorURL']}")
    return summary, "\n".join(p for p in parts if p)


@app.get("/health")
def health():
    return jsonify(ok=True)


@app.post("/webhook")
def webhook():
    body = request.get_json(silent=True) or {}
    # Grafana Unified Alerting webhook payload
    status = (body.get("status") or "").lower()
    alerts = body.get("alerts") or []
    created: list[str] = []

    # Only open tickets on firing (not resolved).
    if status == "resolved":
        log.info("Ignoring resolved notification (%d alerts)", len(alerts))
        return jsonify(ok=True, created=created, skipped="resolved")

    targets = [a for a in alerts if (a.get("status") or "").lower() == "firing"]
    if not targets and status == "firing":
        # Test button sometimes sends a single synthetic alert without nested status.
        targets = alerts or [body]

    for alert in targets:
        if isinstance(alert, dict) and alert.get("labels") is None and "alerts" in body:
            continue
        summary, description = alert_lines(alert if isinstance(alert, dict) else {})
        issue = create_issue(summary, description)
        key = issue.get("key")
        created.append(key)
        log.info("Created Jira issue %s", key)

    return jsonify(ok=True, created=created)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
