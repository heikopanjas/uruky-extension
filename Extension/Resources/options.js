const api = globalThis.browser ?? globalThis.chrome;

// Kept in sync with ENGINES in background.js. Only the display labels live
// here; the matching patterns are not needed on this page.
const ENGINE_LABELS = {
  google: "Google",
  duckduckgo: "DuckDuckGo",
  ecosia: "Ecosia",
  bing: "Bing",
  yahoo: "Yahoo",
};

const DEFAULT_SETTINGS = {
  engines: {
    google: true,
    duckduckgo: true,
    ecosia: true,
    bing: true,
    yahoo: true,
  },
  prfe: "",
  useFallback: false,
};

const fieldset = document.getElementById("engines");
const prfeField = document.getElementById("prfe");
const fallbackField = document.getElementById("useFallback");
const status = document.getElementById("status");

function renderEngines(enabled) {
  fieldset.replaceChildren();

  for (const [key, label] of Object.entries(ENGINE_LABELS)) {
    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.dataset.engine = key;
    checkbox.checked = Boolean(enabled[key]);

    const wrapper = document.createElement("label");
    wrapper.append(checkbox, ` ${label}`);
    fieldset.append(wrapper);
  }
}

async function restore() {
  const stored = await api.storage.local.get(DEFAULT_SETTINGS);
  renderEngines({ ...DEFAULT_SETTINGS.engines, ...(stored.engines ?? {}) });
  prfeField.value = stored.prfe ?? "";
  fallbackField.checked = Boolean(stored.useFallback);
}

async function save() {
  const engines = {};
  for (const box of fieldset.querySelectorAll("input[type=checkbox]")) {
    engines[box.dataset.engine] = box.checked;
  }

  // Accept a pasted "prfe=abc123" or a bare token, and strip an accidental
  // leading "?" or "&".
  const prfe = prfeField.value.trim().replace(/^[?&]?(?:prfe=)?/, "");

  await api.storage.local.set({
    engines,
    prfe,
    useFallback: fallbackField.checked,
  });

  prfeField.value = prfe;
  status.classList.add("visible");
  setTimeout(() => status.classList.remove("visible"), 1500);
}

document.getElementById("save").addEventListener("click", save);
restore();
