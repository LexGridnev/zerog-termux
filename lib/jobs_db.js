import * as std from "qjs:std";
import * as os from "qjs:os";

const args = scriptArgs.slice(1);
const action = args[0];
const stateDir = args[1] || "/data/data/com.termux/files/home/taskmgr/state";
const dbPath = stateDir + "/jobs.json";

function loadJobs() {
  try {
    const raw = std.loadFile(dbPath);
    if (raw) return JSON.parse(raw);
  } catch (e) {}
  return [];
}

function saveJobs(jobs) {
  try {
    const f = std.open(dbPath, "w");
    f.puts(JSON.stringify(jobs, null, 2));
    f.close();
  } catch (e) {
    console.log("Error saving jobs:", e);
  }
}

if (action === "add") {
  const name = args[2];
  const pid = parseInt(args[3], 10);
  const cmd = args[4] || "";
  const startedAt = args[5] || new Date().toISOString();

  let jobs = loadJobs();
  jobs = jobs.filter(j => j.name !== name && j.id !== name);
  jobs.push({
    id: name,
    name: name,
    pid: pid,
    command: cmd,
    started_at: startedAt,
    status: "RUNNING"
  });
  saveJobs(jobs);
} else if (action === "status") {
  const id = args[2];
  let jobs = loadJobs();
  const job = jobs.find(j => j.id === id || j.name === id);
  if (!job) {
    console.log("UNKNOWN");
  } else if (job.status === "STOPPED") {
    console.log("STOPPED");
  } else {
    const isAlive = (os.kill(job.pid, 0) === 0);
    if (isAlive) {
      console.log("RUNNING");
    } else {
      job.status = "DONE";
      saveJobs(jobs);
      console.log("DONE");
    }
  }
} else if (action === "pid") {
  const id = args[2];
  const jobs = loadJobs();
  const job = jobs.find(j => j.id === id || j.name === id);
  if (job) console.log(job.pid);
} else if (action === "get_cmd") {
  const id = args[2];
  const jobs = loadJobs();
  const job = jobs.find(j => j.id === id || j.name === id);
  if (job) console.log(job.command);
} else if (action === "stop") {
  const id = args[2];
  let jobs = loadJobs();
  const job = jobs.find(j => j.id === id || j.name === id);
  if (job) {
    job.status = "STOPPED";
    saveJobs(jobs);
  }
} else if (action === "delete") {
  const id = args[2];
  let jobs = loadJobs();
  jobs = jobs.filter(j => j.id !== id && j.name !== id);
  saveJobs(jobs);
} else if (action === "list") {
  let jobs = loadJobs();
  for (const job of jobs) {
    let status = job.status;
    if (status !== "STOPPED") {
      const isAlive = (os.kill(job.pid, 0) === 0);
      status = isAlive ? "RUNNING" : "DONE";
      job.status = status;
    }
    const timeShort = (job.started_at || "").substring(11, 19) || "--:--:--";
    const cmdShort = (job.command || "").length > 40 ? job.command.substring(0, 37) + "..." : job.command;
    const pad = (str, len) => (String(str || "")).padEnd(len, " ");
    console.log(`${pad(job.name, 18)} ${pad(job.pid, 8)} ${pad(status, 10)} ${pad(timeShort, 20)} ${cmdShort}`);
  }
  saveJobs(jobs);
} else if (action === "json") {
  let jobs = loadJobs();
  for (const job of jobs) {
    if (job.status !== "STOPPED") {
      const isAlive = (os.kill(job.pid, 0) === 0);
      job.status = isAlive ? "RUNNING" : "DONE";
    }
  }
  console.log(JSON.stringify(jobs));
}
