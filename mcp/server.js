import * as std from "qjs:std";

const HOME = std.getenv("HOME") || "/data/data/com.termux/files/home";
const PREFIX = std.getenv("PREFIX") || "/data/data/com.termux/files/usr";

function runCommand(cmd) {
  const pipe = std.popen(cmd + " 2>&1", "r");
  if (!pipe) return "";
  const out = pipe.readAsString();
  pipe.close();
  return out ? out.trim() : "";
}

function shellEscape(arg) {
  return "'" + String(arg || "").replace(/'/g, "'\\''") + "'";
}

const TOOLS = [
  {
    name: "poco_system_vitals",
    description:
      "Get live POCO X4 Pro (Termux) system vitals: RAM usage, storage ($HOME), uptime, Android Phantom Process Killer slots (N/32), AGY CLI health, and active background tasks.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false
    }
  },
  {
    name: "poco_doctor",
    description:
      "Run AGY Doctor diagnostics, cleanup stale agy.*.old binaries (~180MB) and old logs, or repair Termux shims and HyperOS wake-lock.",
    inputSchema: {
      type: "object",
      properties: {
        action: {
          type: "string",
          enum: ["status", "clean", "fix", "json"],
          description: "Action to execute: status (default), clean, fix, or json"
        }
      },
      additionalProperties: false
    }
  },
  {
    name: "poco_tasks",
    description:
      "Manage supervised background tasks in Termux via Task Manager (tm): list jobs, run a background job, stop, restart, or read job logs.",
    inputSchema: {
      type: "object",
      properties: {
        action: {
          type: "string",
          enum: ["list", "run", "stop", "restart", "logs", "rm"],
          description: "Supervisor action to perform"
        },
        name: {
          type: "string",
          description: "Task name (required for run, stop, restart, logs, rm)"
        },
        command: {
          type: "string",
          description: "Shell command to execute in background (required when action is 'run')"
        }
      },
      required: ["action"],
      additionalProperties: false
    }
  },
  {
    name: "poco_processes",
    description:
      "List or search active Termux processes sorted by CPU, memory, or PID, or safely inspect a specific PID.",
    inputSchema: {
      type: "object",
      properties: {
        sort: {
          type: "string",
          enum: ["cpu", "mem", "pid"],
          description: "Sort order (default: cpu)"
        },
        filter: {
          type: "string",
          description: "Optional substring filter by process name or command"
        },
        limit: {
          type: "integer",
          description: "Maximum number of processes to return (default: 15)"
        }
      },
      additionalProperties: false
    }
  },
  {
    name: "poco_brain_search",
    description:
      "Search across Antigravity brain artifacts (*.md) and conversation transcripts (transcript.jsonl) for a keyword or phrase.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Keyword or regex pattern to search in brain artifacts and transcripts"
        },
        limit: {
          type: "integer",
          description: "Maximum matches to return (default: 10)"
        }
      },
      required: ["query"],
      additionalProperties: false
    }
  },
  {
    name: "poco_viewer_sync",
    description:
      "Synchronize Agent Viewer PWA metadata (reports.json, logs.json, agents.json, taskmgr.json) and ensure darkhttpd web server is running on port 8080.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false
    }
  }
];

const RESOURCES = [
  {
    uri: "poco://vitals",
    name: "POCO System Vitals & AGY Health",
    description: "Live JSON snapshot of RAM, Storage, Phantom Processes (N/32), AGY Health, and processes",
    mimeType: "application/json"
  },
  {
    uri: "poco://reports",
    name: "Agent Viewer Reports Index",
    description: "List of all Markdown reports and artifacts in brain",
    mimeType: "application/json"
  },
  {
    uri: "poco://agents",
    name: "Agent Workspace Registry",
    description: "Instructions, Skills, and Plans registered in Agent Viewer",
    mimeType: "application/json"
  }
];

function executeTool(name, args) {
  const a = args || {};
  switch (name) {
    case "poco_system_vitals": {
      runCommand(`"${HOME}/taskmgr/bin/tm" export "${HOME}/agent-viewer/taskmgr.json"`);
      const data = std.loadFile(`${HOME}/agent-viewer/taskmgr.json`) || "{}";
      return { content: [{ type: "text", text: data }], isError: false };
    }
    case "poco_doctor": {
      const act = ["status", "clean", "fix", "json"].includes(a.action) ? a.action : "status";
      const out = runCommand(`"${HOME}/taskmgr/bin/agy-doctor" ${act}`);
      return { content: [{ type: "text", text: out }], isError: false };
    }
    case "poco_tasks": {
      const act = a.action || "list";
      const tname = a.name ? shellEscape(a.name) : "";
      let cmd = `"${HOME}/taskmgr/bin/tm" tasks`;
      if (act === "run" && a.name && a.command) {
        cmd = `"${HOME}/taskmgr/bin/tm" run ${tname} -- ${shellEscape(a.command)}`;
      } else if (["stop", "restart", "logs", "rm"].includes(act) && a.name) {
        cmd = `"${HOME}/taskmgr/bin/tm" ${act} ${tname}`;
      }
      const out = runCommand(cmd);
      return { content: [{ type: "text", text: out || "(no output)" }], isError: false };
    }
    case "poco_processes": {
      const sort = ["cpu", "mem", "pid"].includes(a.sort) ? a.sort : "cpu";
      const limit = Number.isInteger(a.limit) && a.limit > 0 ? a.limit : 15;
      let cmd = `"${HOME}/taskmgr/bin/tm" ps --sort ${sort}`;
      if (a.filter) {
        cmd = `"${HOME}/taskmgr/bin/tm" ps ${shellEscape(a.filter)}`;
      }
      const out = runCommand(`${cmd} | head -n ${limit + 1}`);
      return { content: [{ type: "text", text: out }], isError: false };
    }
    case "poco_brain_search": {
      const q = String(a.query || "").trim();
      const limit = Number.isInteger(a.limit) && a.limit > 0 ? a.limit : 10;
      if (!q) {
        return { content: [{ type: "text", text: "[]" }], isError: false };
      }
      const brainDir = `${HOME}/.gemini/antigravity-cli/brain`;
      const cmd = `grep -rnI -i -m 2 ${shellEscape(q)} "${brainDir}" 2>/dev/null | head -n ${limit}`;
      const raw = runCommand(cmd);
      const matches = raw
        ? raw.split("\n").map((line) => {
            const idx1 = line.indexOf(":");
            const idx2 = idx1 !== -1 ? line.indexOf(":", idx1 + 1) : -1;
            if (idx1 !== -1 && idx2 !== -1) {
              return {
                file: line.substring(0, idx1).replace(brainDir + "/", ""),
                line: parseInt(line.substring(idx1 + 1, idx2), 10) || 1,
                snippet: line.substring(idx2 + 1).trim().substring(0, 240)
              };
            }
            return { raw: line.substring(0, 240) };
          })
        : [];
      return {
        content: [{ type: "text", text: JSON.stringify({ query: q, count: matches.length, matches }, null, 2) }],
        isError: false
      };
    }
    case "poco_viewer_sync": {
      runCommand(`"${HOME}/agent-viewer/update_meta.sh"`);
      const check = runCommand(`curl -sf -o /dev/null -w "%{http_code}" -m 1 http://127.0.0.1:8080/`);
      if (check !== "200") {
        runCommand(
          `rm -f "${HOME}/agent-viewer/darkhttpd.pid" && darkhttpd "${HOME}/agent-viewer" --port 8080 --daemon --pidfile "${HOME}/agent-viewer/darkhttpd.pid" --log "${HOME}/agent-viewer/darkhttpd.log"`
        );
      }
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                status: "synced",
                url: "http://127.0.0.1:8080/",
                pwa_manifest: "http://127.0.0.1:8080/manifest.json"
              },
              null,
              2
            )
          }
        ],
        isError: false
      };
    }
    default:
      return {
        content: [{ type: "text", text: `Unknown tool: ${name}` }],
        isError: true
      };
  }
}

function readResource(uri) {
  if (uri === "poco://vitals") {
    runCommand(`"${HOME}/taskmgr/bin/tm" export "${HOME}/agent-viewer/taskmgr.json"`);
    const text = std.loadFile(`${HOME}/agent-viewer/taskmgr.json`) || "{}";
    return [{ uri, mimeType: "application/json", text }];
  }
  if (uri === "poco://reports") {
    const text = std.loadFile(`${HOME}/agent-viewer/reports.json`) || "[]";
    return [{ uri, mimeType: "application/json", text }];
  }
  if (uri === "poco://agents") {
    const text = std.loadFile(`${HOME}/agent-viewer/agents.json`) || "{}";
    return [{ uri, mimeType: "application/json", text }];
  }
  throw new Error(`Resource not found: ${uri}`);
}

let useContentLengthFraming = false;

function sendResponse(obj) {
  const body = JSON.stringify(obj);
  if (useContentLengthFraming) {
    std.out.puts(`Content-Length: ${body.length}\r\n\r\n${body}`);
  } else {
    std.out.puts(body + "\n");
  }
  std.out.flush();
}

function handleRpcMessage(msg) {
  if (!msg || typeof msg !== "object") return;
  const { id, method, params } = msg;

  // Notifications have no id
  if (id === undefined || id === null) {
    return;
  }

  try {
    if (method === "initialize") {
      const clientProto = params?.protocolVersion || "2024-11-05";
      sendResponse({
        jsonrpc: "2.0",
        id,
        result: {
          protocolVersion: clientProto,
          capabilities: {
            tools: { listChanged: false },
            resources: { subscribe: false, listChanged: false }
          },
          serverInfo: {
            name: "poco-mcp",
            version: "1.0.0"
          }
        }
      });
    } else if (method === "ping") {
      sendResponse({ jsonrpc: "2.0", id, result: {} });
    } else if (method === "tools/list") {
      sendResponse({ jsonrpc: "2.0", id, result: { tools: TOOLS } });
    } else if (method === "tools/call") {
      const res = executeTool(params?.name, params?.arguments);
      sendResponse({ jsonrpc: "2.0", id, result: res });
    } else if (method === "resources/list") {
      sendResponse({ jsonrpc: "2.0", id, result: { resources: RESOURCES } });
    } else if (method === "resources/read") {
      const contents = readResource(params?.uri);
      sendResponse({ jsonrpc: "2.0", id, result: { contents } });
    } else if (method === "prompts/list") {
      sendResponse({ jsonrpc: "2.0", id, result: { prompts: [] } });
    } else {
      sendResponse({
        jsonrpc: "2.0",
        id,
        error: { code: -32601, message: `Method not found: ${method}` }
      });
    }
  } catch (err) {
    sendResponse({
      jsonrpc: "2.0",
      id,
      error: { code: -32603, message: String(err?.message || err) }
    });
  }
}

// Main stdio loop supporting both JSONL and Content-Length headers
while (!std.in.eof()) {
  const line = std.in.getline();
  if (line === null) break;
  const trimmed = line.trim();
  if (!trimmed) continue;

  if (trimmed.toLowerCase().startsWith("content-length:")) {
    useContentLengthFraming = true;
    const len = parseInt(trimmed.split(":")[1].trim(), 10);
    // Read until empty header line
    while (!std.in.eof()) {
      const hline = std.in.getline();
      if (hline === null || hline.trim() === "") break;
    }
    if (len > 0) {
      const buf = new Uint8Array(len);
      const readBytes = std.in.read(buf.buffer, 0, len);
      if (readBytes > 0) {
        let jsonStr = "";
        for (let i = 0; i < readBytes; i++) {
          jsonStr += String.fromCharCode(buf[i]);
        }
        try {
          handleRpcMessage(JSON.parse(jsonStr));
        } catch (_) {}
      }
    }
    continue;
  }

  if (trimmed.startsWith("{")) {
    try {
      handleRpcMessage(JSON.parse(trimmed));
    } catch (_) {}
  }
}
