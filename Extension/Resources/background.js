// Startpage for Safari -- background service worker.
//
// Two redirect mechanisms live here:
//
//   1. declarativeNetRequest dynamic rules (default). Fast, no per-request
//      callback into extension code, redirect happens before the request is
//      dispatched. This is the good path.
//
//   2. webNavigation.onBeforeNavigate + tabs.update() (fallback, opt-in).
//      Slower, produces a visible flash of the origin engine, but it works
//      when dNR redirect is broken -- which it has been in some Safari 26
//      builds ("This webpage was reloaded because a problem occurred").
//
// rules.json ships the same rules statically so that a search issued before
// this worker has ever started still redirects. Once the worker runs it takes
// over with dynamic rules and disables the static set.

const api = globalThis.browser ?? globalThis.chrome;

const STATIC_RULESET_ID = "default";
const DYNAMIC_RULE_BASE = 1000;
const STARTPAGE_ENDPOINT = "https://www.startpage.com/sp/search";

// Engine table. `regex` is used for declarativeNetRequest (RE2 flavour -- no
// lookahead, no backreferences in the pattern itself). `host`/`path`/`param`
// are used by the fallback path, which parses the URL properly instead.
const ENGINES = {
  google: {
    label: "Google",
    regex: "^https?://(?:www\\.)?google\\.[a-z.]+/search\\?(?:.*&)?q=([^&]*)",
    host: /(?:^|\.)google\.[a-z.]+$/,
    path: /^\/search$/,
    param: "q",
  },
  duckduckgo: {
    label: "DuckDuckGo",
    regex: "^https?://(?:www\\.)?duckduckgo\\.com/(?:html/)?\\?(?:.*&)?q=([^&]*)",
    host: /(?:^|\.)duckduckgo\.com$/,
    path: /^\/(?:html\/)?$/,
    param: "q",
  },
  ecosia: {
    label: "Ecosia",
    regex: "^https?://(?:www\\.)?ecosia\\.org/search\\?(?:.*&)?q=([^&]*)",
    host: /(?:^|\.)ecosia\.org$/,
    path: /^\/search$/,
    param: "q",
  },
  bing: {
    label: "Bing",
    regex: "^https?://(?:www\\.)?bing\\.com/search\\?(?:.*&)?q=([^&]*)",
    host: /(?:^|\.)bing\.com$/,
    path: /^\/search$/,
    param: "q",
  },
  yahoo: {
    label: "Yahoo",
    regex: "^https?://[a-z]+\\.search\\.yahoo\\.com/search\\?(?:.*&)?p=([^&]*)",
    host: /\.search\.yahoo\.com$/,
    path: /^\/search$/,
    param: "p",
  },
};

// Google image/news/video searches carry tbm=; leave those alone rather than
// flattening them into a plain web search on Startpage.
const GOOGLE_VERTICAL_EXCEPTION = {
  regex: "^https?://(?:www\\.)?google\\.[a-z.]+/search\\?(?:.*&)?tbm=",
};

const DEFAULT_SETTINGS = {
  // Which engines to intercept. Redirecting only the one engine you actually
  // set as Safari's default keeps the pre-redirect leak confined to it.
  engines: {
    google: true,
    duckduckgo: true,
    ecosia: true,
    bing: true,
    yahoo: true,
  },
  // Startpage encodes user preferences in an opaque `prfe` token, obtainable
  // from startpage.com/do/settings. Carrying it on the query string makes
  // settings survive Private Browsing, where the settings cookie does not.
  prfe: "",
  // Set true to use the webNavigation fallback instead of dNR.
  useFallback: false,
};

async function loadSettings() {
  const stored = await api.storage.local.get(DEFAULT_SETTINGS);
  return {
    ...DEFAULT_SETTINGS,
    ...stored,
    engines: { ...DEFAULT_SETTINGS.engines, ...(stored.engines ?? {}) },
  };
}

function targetTemplate(settings) {
  const suffix = settings.prfe
    ? `&prfe=${encodeURIComponent(settings.prfe)}`
    : "";
  // \\1 is the dNR substitution backreference for the captured query, which is
  // still percent-encoded in the source URL -- so it drops straight in.
  return `${STARTPAGE_ENDPOINT}?query=\\1${suffix}`;
}

function buildDynamicRules(settings) {
  const substitution = targetTemplate(settings);
  const rules = [];
  let id = DYNAMIC_RULE_BASE;

  if (settings.engines.google) {
    rules.push({
      id: id++,
      priority: 2,
      action: { type: "allow" },
      condition: {
        regexFilter: GOOGLE_VERTICAL_EXCEPTION.regex,
        resourceTypes: ["main_frame"],
      },
    });
  }

  for (const [key, engine] of Object.entries(ENGINES)) {
    if (!settings.engines[key]) continue;
    rules.push({
      id: id++,
      priority: 1,
      action: {
        type: "redirect",
        redirect: { regexSubstitution: substitution },
      },
      condition: {
        regexFilter: engine.regex,
        resourceTypes: ["main_frame"],
      },
    });
  }

  return rules;
}

async function applySettings() {
  const settings = await loadSettings();

  const existing = await api.declarativeNetRequest.getDynamicRules();
  await api.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: existing.map((rule) => rule.id),
    addRules: settings.useFallback ? [] : buildDynamicRules(settings),
  });

  // The static ruleset exists only to cover the window before this worker has
  // ever run. Once we are live, dynamic rules are authoritative.
  await api.declarativeNetRequest.updateEnabledRulesets({
    disableRulesetIds: [STATIC_RULESET_ID],
  });
}

// --- Fallback path ----------------------------------------------------------

function extractQuery(settings, rawURL) {
  let url;
  try {
    url = new URL(rawURL);
  } catch {
    return null;
  }

  if (url.protocol !== "http:" && url.protocol !== "https:") return null;
  // Never act on Startpage itself -- cheap insurance against a redirect loop.
  if (url.hostname.endsWith("startpage.com")) return null;

  for (const [key, engine] of Object.entries(ENGINES)) {
    if (!settings.engines[key]) continue;
    if (!engine.host.test(url.hostname)) continue;
    if (!engine.path.test(url.pathname)) continue;
    if (key === "google" && url.searchParams.has("tbm")) return null;

    const query = url.searchParams.get(engine.param);
    if (query) return query;
  }

  return null;
}

api.webNavigation.onBeforeNavigate.addListener(async (details) => {
  if (details.frameId !== 0) return;

  const settings = await loadSettings();
  if (!settings.useFallback) return;

  const query = extractQuery(settings, details.url);
  if (!query) return;

  const suffix = settings.prfe
    ? `&prfe=${encodeURIComponent(settings.prfe)}`
    : "";
  await api.tabs.update(details.tabId, {
    url: `${STARTPAGE_ENDPOINT}?query=${encodeURIComponent(query)}${suffix}`,
  });
});

// --- Lifecycle --------------------------------------------------------------

api.runtime.onInstalled.addListener(() => {
  applySettings();
});

api.runtime.onStartup.addListener(() => {
  applySettings();
});

api.storage.onChanged.addListener((_changes, areaName) => {
  if (areaName === "local") applySettings();
});

applySettings();
