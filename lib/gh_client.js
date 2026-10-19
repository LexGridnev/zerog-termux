import * as std from "qjs:std";

const HOME = std.getenv("HOME") || "/data/data/com.termux/files/home";
const CONFIG_DIR = std.getenv("ZEROG_CONFIG_DIR") || `${HOME}/.config/zerog`;
const TOKEN_FILE = `${CONFIG_DIR}/github_token`;
const USER_FILE = `${CONFIG_DIR}/github_user`;
const OFFLINE_TEST = std.getenv("ZEROG_GH_OFFLINE_TEST") === "1";

function shQuote(s) {
  return "'" + String(s || "").replace(/'/g, "'\\''") + "'";
}

function runShell(cmd) {
  const pipe = std.popen(cmd + " 2>&1", "r");
  if (!pipe) return "";
  const out = pipe.readAsString();
  pipe.close();
  return out ? out.trim() : "";
}

function getToken() {
  const envTok = std.getenv("GITHUB_TOKEN") || std.getenv("GH_TOKEN");
  if (envTok) return envTok.trim();
  const saved = std.loadFile(TOKEN_FILE);
  return saved ? saved.trim() : "";
}

function githubApi(method, endpoint, bodyObj) {
  const token = getToken();
  if (!token) {
    throw new Error("GitHub token not configured. Run: 0g gh token <YOUR_PAT>");
  }
  const url = endpoint.startsWith("http") ? endpoint : `https://api.github.com${endpoint}`;

  // Write Authorization header into a 0600 curl config file so token never appears in ps args
  const stamp = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  const tmpCurlCfg = `/data/data/com.termux/files/usr/tmp/gh_curl_${stamp}.cfg`;
  const safeTok = token.replace(/["\\]/g, "");
  const cf = std.open(tmpCurlCfg, "w");
  cf.puts(`header = "Accept: application/vnd.github+json"\n`);
  cf.puts(`header = "Authorization: Bearer ${safeTok}"\n`);
  cf.puts(`header = "X-GitHub-Api-Version: 2022-11-28"\n`);
  cf.close();
  runShell(`chmod 600 ${shQuote(tmpCurlCfg)}`);

  let cmd = `curl -sS -X ${method} -K ${shQuote(tmpCurlCfg)}`;

  let tmpPayload = "";
  if (bodyObj !== undefined) {
    tmpPayload = `/data/data/com.termux/files/usr/tmp/gh_payload_${stamp}.json`;
    const f = std.open(tmpPayload, "w");
    f.puts(JSON.stringify(bodyObj));
    f.close();
    runShell(`chmod 600 ${shQuote(tmpPayload)}`);
    cmd += ` -H "Content-Type: application/json" --data-binary @${shQuote(tmpPayload)}`;
  }
  cmd += ` ${shQuote(url)}`;
  const raw = runShell(cmd);
  runShell(`rm -f ${shQuote(tmpCurlCfg)} ${tmpPayload ? shQuote(tmpPayload) : ""}`);

  try {
    return JSON.parse(raw);
  } catch (_) {
    throw new Error(`Invalid JSON response from GitHub API: ${raw.substring(0, 200)}`);
  }
}

function pushSingleFile(repoTarget, localFile, remotePath, commitMsg) {
  const b64 = runShell(`base64 -w 0 ${shQuote(localFile)}`);
  if (!b64) {
    throw new Error(`Local file '${localFile}' is empty or unreadable.`);
  }
  if (OFFLINE_TEST) {
    return {
      repo: repoTarget,
      path: remotePath,
      message: commitMsg,
      content_base64: b64
    };
  }
  const existing = githubApi("GET", `/repos/${repoTarget}/contents/${remotePath}`);
  const body = {
    message: commitMsg,
    content: b64
  };
  if (existing && existing.sha) {
    body.sha = existing.sha;
  }
  return githubApi("PUT", `/repos/${repoTarget}/contents/${remotePath}`, body);
}

function showHelp() {
  std.out.puts(`Usage: 0g gh <command> [args...]

Zero-Git Native GitHub Client for Termux (powered by QuickJS + curl REST API).

Commands:
  0g gh token <PAT>                              Save Personal Access Token (chmod 600) & verify
  0g gh whoami                                   Show authenticated GitHub account info
  0g gh status                                   Alias for 0g gh whoami
  0g gh repos                                    List your GitHub repositories
  0g gh create <name> [--public|--private]       Create a new repository on GitHub
                      [--desc "Description"]
  0g gh push <repo> <local_path> [remote_path]   Upload/commit file or directory via GitHub API
                    [commit_message]
`);
}

const args = scriptArgs.slice(1);
const sub = args[0] || "help";

if (sub === "-h" || sub === "--help" || sub === "help") {
  showHelp();
  std.exit(0);
}

try {
  if (sub === "token" || sub === "login") {
    const pat = args[1] || "";
    if (!pat) {
      std.err.puts("Usage: 0g gh token <PERSONAL_ACCESS_TOKEN>\n");
      std.exit(1);
    }
    runShell(`mkdir -p ${shQuote(CONFIG_DIR)} && chmod 700 ${shQuote(CONFIG_DIR)}`);
    const f = std.open(TOKEN_FILE, "w");
    f.puts(pat.trim() + "\n");
    f.close();
    runShell(`chmod 600 ${shQuote(TOKEN_FILE)}`);

    if (OFFLINE_TEST) {
      std.out.puts(`✓ Token saved securely to ${TOKEN_FILE} (mode 600)\n`);
      std.exit(0);
    }

    const user = githubApi("GET", "/user");
    if (user && user.login) {
      const uf = std.open(USER_FILE, "w");
      uf.puts(user.login + "\n");
      uf.close();
      std.out.puts(`✓ Token saved & verified! Connected to GitHub as @${user.login} (${user.name || "user"})\n`);
    } else {
      std.err.puts(`⚠ Token saved, but verification returned: ${user?.message || "unknown error"}\n`);
      std.exit(1);
    }
  } else if (sub === "status" || sub === "whoami") {
    const token = getToken();
    if (!token) {
      std.out.puts("GitHub Status: Not connected. Run: 0g gh token <YOUR_PAT>\n");
      std.exit(1);
    }
    if (OFFLINE_TEST) {
      std.out.puts(`✓ Token configured (${TOKEN_FILE})\n`);
      std.exit(0);
    }
    const user = githubApi("GET", "/user");
    if (user && user.login) {
      const uf = std.open(USER_FILE, "w");
      uf.puts(user.login + "\n");
      uf.close();
      std.out.puts(`=== [ZeroG GitHub Connection] ===\n`);
      std.out.puts(`• Account:      @${user.login}${user.name ? " (" + user.name + ")" : ""}\n`);
      std.out.puts(`• Profile URL:  ${user.html_url}\n`);
      std.out.puts(`• Public Repos: ${user.public_repos ?? 0} | Private Repos: ${user.total_private_repos ?? 0}\n`);
    } else {
      std.err.puts(`GitHub API Error: ${user?.message || "Unauthorized"}\n`);
      std.exit(1);
    }
  } else if (sub === "repos" || sub === "list") {
    const repos = githubApi("GET", "/user/repos?sort=updated&per_page=20");
    if (!Array.isArray(repos)) {
      std.err.puts(`GitHub API Error: ${repos?.message || "Failed to list repos"}\n`);
      std.exit(1);
    }
    std.out.puts(`=== [Recent GitHub Repositories (${repos.length})] ===\n`);
    for (const r of repos) {
      const vis = r.private ? "🔒 private" : "🌐 public ";
      std.out.puts(`${vis}  ${r.full_name} — ${r.html_url}\n`);
    }
  } else if (sub === "create") {
    const name = args[1];
    if (!name) {
      std.err.puts("Usage: 0g gh create <repo-name> [--public|--private] [--desc \"...\"]\n");
      std.exit(1);
    }
    let isPrivate = false;
    let desc = "ZeroG (0g) — Adaptive Termux + Google Antigravity Mobile AI Station";
    for (let i = 2; i < args.length; i++) {
      if (args[i] === "--private") isPrivate = true;
      else if (args[i] === "--public") isPrivate = false;
      else if (args[i] === "--desc" && args[i + 1]) {
        desc = args[++i];
      }
    }
    const payload = {
      name,
      description: desc,
      private: isPrivate,
      auto_init: true
    };
    if (OFFLINE_TEST) {
      std.out.puts(JSON.stringify(payload) + "\n");
      std.exit(0);
    }
    const created = githubApi("POST", "/user/repos", payload);
    if (created && created.html_url) {
      std.out.puts(`✓ Repository created: ${created.full_name}\n  URL: ${created.html_url}\n`);
    } else {
      std.err.puts(`GitHub Create Error: ${created?.message || JSON.stringify(created)}\n`);
      std.exit(1);
    }
  } else if (sub === "push") {
    let repoTarget = args[1];
    const localPath = args[2];
    if (!repoTarget || !localPath) {
      std.err.puts("Usage: 0g gh push <owner/repo | repo> <local_path> [remote_path] [commit_msg]\n");
      std.exit(1);
    }
    if (!repoTarget.includes("/")) {
      const savedUser = (std.loadFile(USER_FILE) || "").trim();
      if (savedUser) {
        repoTarget = `${savedUser}/${repoTarget}`;
      } else if (!OFFLINE_TEST) {
        const u = githubApi("GET", "/user");
        if (u && u.login) repoTarget = `${u.login}/${repoTarget}`;
      }
    }

    const isDir = runShell(`[ -d ${shQuote(localPath)} ] && echo 1 || echo 0`) === "1";
    if (isDir) {
      const prefix = (args[3] || "").replace(/^\/+|\/+$/g, "");
      const commitMsg = args[4] || `Sync directory via ZeroG (0g gh)`;
      const rawFiles = runShell(
        `find ${shQuote(localPath)} -type f ! -name '*.old' ! -name '*.pid' ! -name '*.log' ! -path '*/.git/*' 2>/dev/null`
      );
      const fileList = rawFiles ? rawFiles.split("\n").filter(Boolean) : [];
      const relList = fileList.map((f) => {
        const rel = f.substring(localPath.replace(/\/+$/, "").length + 1);
        return prefix ? `${prefix}/${rel}` : rel;
      });

      if (OFFLINE_TEST) {
        std.out.puts(JSON.stringify({ repo: repoTarget, mode: "directory", files: relList }) + "\n");
        std.exit(0);
      }

      for (let i = 0; i < fileList.length; i++) {
        const res = pushSingleFile(repoTarget, fileList[i], relList[i], commitMsg);
        if (res && res.content && res.content.html_url) {
          std.out.puts(`✓ [${i + 1}/${fileList.length}] Pushed ${relList[i]}\n`);
        } else {
          std.err.puts(`✗ Failed ${relList[i]}: ${res?.message || "error"}\n`);
        }
      }
      std.exit(0);
    }

    const remotePath = (args[3] || localPath.split("/").pop()).replace(/^\/+/, "");
    const commitMsg = args[4] || `Update ${remotePath} via ZeroG (0g gh)`;
    const res = pushSingleFile(repoTarget, localPath, remotePath, commitMsg);

    if (OFFLINE_TEST) {
      std.out.puts(JSON.stringify(res) + "\n");
      std.exit(0);
    }
    if (res && res.content && res.content.html_url) {
      std.out.puts(`✓ Pushed ${remotePath} -> ${res.content.html_url}\n`);
    } else {
      std.err.puts(`GitHub Push Error: ${res?.message || JSON.stringify(res)}\n`);
      std.exit(1);
    }
  } else {
    showHelp();
    std.exit(1);
  }
} catch (err) {
  std.err.puts(`Error: ${err.message || err}\n`);
  std.exit(1);
}
