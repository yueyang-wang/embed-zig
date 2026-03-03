(() => {
  const logsEl = document.getElementById("logs");
  const ledEl = document.getElementById("led0");
  const ledStateEl = document.getElementById("led-state");
  const ledRgbEl = document.getElementById("led-rgb");
  const ledTEl = document.getElementById("led-t");
  const bootBtn = document.getElementById("btn-boot");
  const resetBtn = document.getElementById("btn-reset");

  const wsProto = location.protocol === "https:" ? "wss" : "ws";
  const ws = new WebSocket(`${wsProto}://${location.host}/ws`);

  const clockStart = Date.now();
  const nowT = () => Date.now() - clockStart;

  let holding = false;
  let holdTimer = null;

  function log(line) {
    logsEl.textContent += `${line}\n`;
    logsEl.scrollTop = logsEl.scrollHeight;
  }

  function sendInline(message) {
    if (ws.readyState !== WebSocket.OPEN) {
      log(`[drop] ${message}`);
      return;
    }
    ws.send(message);
    log(`[send] ${message}`);
  }

  function sendReset() {
    sendInline(`{ op: "cmd", t: ${nowT()}, dev: "sys", v: { cmd: "reset" } }`);
  }

  function sendPressDown() {
    sendInline(`{ op: "input", t: ${nowT()}, dev: "btn_boot", v: { action: "press_down" } }`);
  }

  function sendRelease() {
    sendInline(`{ op: "input", t: ${nowT()}, dev: "btn_boot", v: { action: "release" } }`);
  }

  function parseSetMessage(raw) {
    const opMatch = raw.match(/op:\s*"([^"]+)"/);
    const devMatch = raw.match(/dev:\s*"([^"]+)"/);
    if (!opMatch || !devMatch) return null;
    if (opMatch[1] !== "set" || devMatch[1] !== "led0") return null;

    const tMatch = raw.match(/t:\s*(-?\d+)/);
    const onMatch = raw.match(/on:\s*(true|false)/);
    const rMatch = raw.match(/r:\s*(-?\d+)/);
    const gMatch = raw.match(/g:\s*(-?\d+)/);
    const bMatch = raw.match(/b:\s*(-?\d+)/);
    if (!tMatch || !onMatch || !rMatch || !gMatch || !bMatch) return null;

    return {
      t: Number(tMatch[1]),
      on: onMatch[1] === "true",
      r: Number(rMatch[1]),
      g: Number(gMatch[1]),
      b: Number(bMatch[1]),
    };
  }

  function renderLed(state) {
    ledTEl.textContent = String(state.t);
    ledStateEl.textContent = state.on ? "on" : "off";
    ledRgbEl.textContent = `${state.r},${state.g},${state.b}`;

    if (!state.on) {
      ledEl.classList.remove("on");
      ledEl.style.background = "#0a0c16";
      return;
    }

    ledEl.classList.add("on");
    ledEl.style.background = `rgb(${state.r}, ${state.g}, ${state.b})`;
  }

  ws.addEventListener("open", () => {
    log("[ws] connected");
    sendReset();
  });

  ws.addEventListener("close", () => {
    log("[ws] closed");
  });

  ws.addEventListener("message", (event) => {
    const raw = String(event.data);
    log(`[recv] ${raw}`);

    const setMsg = parseSetMessage(raw);
    if (setMsg) {
      renderLed(setMsg);
    }
  });

  function startHold() {
    if (holding) return;
    holding = true;
    sendPressDown();
    holdTimer = setInterval(sendPressDown, 120);
  }

  function stopHold() {
    if (!holding) return;
    holding = false;
    if (holdTimer) {
      clearInterval(holdTimer);
      holdTimer = null;
    }
    sendRelease();
  }

  bootBtn.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    startHold();
  });
  bootBtn.addEventListener("pointerup", stopHold);
  bootBtn.addEventListener("pointercancel", stopHold);
  bootBtn.addEventListener("pointerleave", stopHold);

  resetBtn.addEventListener("click", () => {
    sendReset();
  });
})();
