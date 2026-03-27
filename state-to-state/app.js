// =============================================
// State to State — Application Logic
// =============================================

// ---- State ----
let activeTab = "state-laws";
let selectedState = "IL";
let activeCategoryFilter = "All";
let selectedStateA = "IL";
let selectedStateB = "TX";
let activeStates = new Set(Object.keys(STATES));

// ---- DOM ----
const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

// =============================================
// TABS
// =============================================
function switchTab(tabId) {
  activeTab = tabId;
  $$(".nav-tab").forEach(t => t.classList.toggle("active", t.dataset.tab === tabId));
  $$(".tab-panel").forEach(p => p.classList.toggle("active", p.id === `tab-${tabId}`));
}

// =============================================
// STATE LAWS TAB
// =============================================
function renderStateLaws() {
  const state = STATES[selectedState];
  if (!state) return;

  // Hero
  $("#hero-abbr").textContent = selectedState;
  $("#hero-name").textContent = state.name;
  $("#hero-region").textContent = state.region;
  $("#hero-count").textContent = LAWS.length;

  // Category filter
  renderCategoryFilter();

  // Laws grid
  renderLawsGrid();
}

function renderCategoryFilter() {
  const container = $("#category-filter");
  const cats = ["All", ...CATEGORIES];
  container.innerHTML = cats.map(cat => `
    <button class="cat-btn ${activeCategoryFilter === cat ? 'active' : ''}"
            onclick="setCategoryFilter('${cat}')">
      ${cat}
    </button>
  `).join("");
}

function setCategoryFilter(cat) {
  activeCategoryFilter = cat;
  renderCategoryFilter();
  renderLawsGrid();
}

function renderLawsGrid() {
  const grid = $("#laws-grid");
  const filtered = activeCategoryFilter === "All"
    ? LAWS
    : LAWS.filter(l => l.category === activeCategoryFilter);

  if (!filtered.length) {
    grid.innerHTML = `<div class="empty-state"><div class="empty-icon">🔍</div><h3>No laws found</h3></div>`;
    return;
  }

  grid.innerHTML = filtered.map(law => {
    const val = law.stateValues[selectedState] || "Unknown";
    const style = getValueStyle(val);
    return `
      <div class="law-card" style="--val-color: ${style.color}">
        <div class="law-card-header">
          <span class="law-icon">${law.icon}</span>
          <div>
            <div class="law-card-title">${law.name}</div>
            <div class="law-category-label">${law.category}</div>
          </div>
        </div>
        <div class="law-value-badge"
             style="color: ${style.color}; background: ${style.bg};">
          ${val}
        </div>
        <div class="law-description">${law.description}</div>
        <div class="law-source">Source: ${law.source}</div>
      </div>
    `;
  }).join("");
}

// =============================================
// SHARED LAWS TAB
// =============================================
const REGIONS_ORDER = ["Northeast", "South", "Midwest", "Mountain", "Southwest", "West"];

function renderSharedLaws() {
  renderStateToggles();
  renderSharedResults();
}

function renderStateToggles() {
  const container = $("#state-toggles");

  // Group by region
  const byRegion = {};
  Object.entries(STATES).forEach(([abbr, info]) => {
    if (!byRegion[info.region]) byRegion[info.region] = [];
    byRegion[info.region].push({ abbr, ...info });
  });

  const html = REGIONS_ORDER.map(region => {
    if (!byRegion[region]) return "";
    const chips = byRegion[region].map(s => `
      <button class="state-chip ${activeStates.has(s.abbr) ? 'active' : 'inactive'}"
              data-abbr="${s.abbr}"
              title="${s.name}"
              onclick="toggleState('${s.abbr}')">
        ${s.abbr}
      </button>
    `).join("");
    return `
      <div class="region-group">
        <div class="region-label">${region}</div>
        <div class="state-chips">${chips}</div>
      </div>
    `;
  }).join("");

  container.innerHTML = html;
  updateActiveCount();
}

function toggleState(abbr) {
  if (activeStates.has(abbr)) {
    if (activeStates.size === 1) return; // keep at least 1
    activeStates.delete(abbr);
  } else {
    activeStates.add(abbr);
  }
  // Update just the clicked chip without full re-render
  const chip = document.querySelector(`.state-chip[data-abbr="${abbr}"]`);
  if (chip) {
    chip.classList.toggle("active", activeStates.has(abbr));
    chip.classList.toggle("inactive", !activeStates.has(abbr));
  }
  updateActiveCount();
  renderSharedResults();
}

function updateActiveCount() {
  const el = $("#active-count");
  if (el) {
    const n = activeStates.size;
    const total = Object.keys(STATES).length;
    el.innerHTML = `<strong>${n}</strong> of ${total} states/territories selected`;
  }
}

function selectAllStates() {
  Object.keys(STATES).forEach(a => activeStates.add(a));
  renderStateToggles();
  renderSharedResults();
}

function clearAllStates() {
  // Keep at least DC
  activeStates.clear();
  activeStates.add("DC");
  renderStateToggles();
  renderSharedResults();
}

function getSharedLaws() {
  const stateList = [...activeStates];
  const shared = [];
  LAWS.forEach(law => {
    const values = stateList.map(s => law.stateValues[s]).filter(Boolean);
    if (values.length === 0) return;
    const first = values[0];
    if (values.every(v => v === first)) {
      shared.push({ law, sharedValue: first });
    }
  });
  return shared;
}

function renderSharedResults() {
  const container = $("#shared-results");
  const count = $("#shared-count");

  if (activeStates.size < 2) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">🗺️</div>
        <h3>Select at least 2 states</h3>
        <p>Toggle states on the left to find the laws they have in common.</p>
      </div>`;
    count.textContent = "0 shared";
    return;
  }

  const shared = getSharedLaws();
  count.textContent = `${shared.length} shared law${shared.length !== 1 ? "s" : ""}`;

  if (shared.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">🔍</div>
        <h3>No shared laws found</h3>
        <p>The ${activeStates.size} selected states don't share identical policies on any tracked law. Try deselecting some states.</p>
      </div>`;
    return;
  }

  container.innerHTML = shared.map(({ law, sharedValue }) => {
    const style = getValueStyle(sharedValue);
    return `
      <div class="shared-law-card" style="--val-color: ${style.color}">
        <div class="shared-law-icon">${law.icon}</div>
        <div class="shared-law-info">
          <div class="shared-law-cat">${law.category}</div>
          <div class="shared-law-name">${law.name}</div>
          <div class="shared-law-value"
               style="color: ${style.color}; background: ${style.bg};">
            ${sharedValue}
          </div>
          <div class="shared-law-states-count">
            Shared by all ${activeStates.size} selected states/territories
          </div>
        </div>
      </div>
    `;
  }).join("");
}

// =============================================
// COMPARE TAB
// =============================================
function renderCompare() {
  renderCompareSelectors();
  renderCompareTable();
}

function renderCompareSelectors() {
  const makeOptions = (selected) =>
    Object.entries(STATES)
      .map(([abbr, info]) =>
        `<option value="${abbr}" ${abbr === selected ? "selected" : ""}>${info.name} (${abbr})</option>`)
      .join("");

  const wrapA = $("#compare-select-a");
  const wrapB = $("#compare-select-b");
  if (!wrapA || !wrapB) return;

  // Update abbr display
  const abbrA = $("#compare-abbr-a");
  const abbrB = $("#compare-abbr-b");
  const nameA = $("#compare-name-a");
  const nameB = $("#compare-name-b");

  if (abbrA) abbrA.textContent = selectedStateA;
  if (abbrB) abbrB.textContent = selectedStateB;
  if (nameA) nameA.textContent = STATES[selectedStateA]?.name || "";
  if (nameB) nameB.textContent = STATES[selectedStateB]?.name || "";
}

function renderCompareTable() {
  const tbody = $("#compare-tbody");
  if (!tbody) return;

  let matchCount = 0;

  const rows = LAWS.map(law => {
    const valA = law.stateValues[selectedStateA] || "Unknown";
    const valB = law.stateValues[selectedStateB] || "Unknown";
    const isMatch = valA === valB;
    if (isMatch) matchCount++;
    const styleA = getValueStyle(valA);
    const styleB = getValueStyle(valB);

    return `
      <div class="compare-row ${isMatch ? "match" : ""}">
        <div class="compare-law-label">
          <span class="cmp-icon">${law.icon}</span>
          ${law.name}
        </div>
        <div class="compare-cell">
          <span class="compare-badge" style="color:${styleA.color}; background:${styleA.bg};">${valA}</span>
          ${isMatch ? `<span class="match-indicator" title="Match"></span>` : `<span class="diff-indicator" title="Different"></span>`}
        </div>
        <div class="compare-cell">
          <span class="compare-badge" style="color:${styleB.color}; background:${styleB.bg};">${valB}</span>
        </div>
      </div>
    `;
  }).join("");

  tbody.innerHTML = rows;

  // Update summary
  const diffCount = LAWS.length - matchCount;
  const summary = $("#compare-summary");
  if (summary) {
    summary.innerHTML = `
      <div class="summary-stat">
        <span class="summary-dot" style="background:#22c55e"></span>
        <span><strong>${matchCount}</strong> matching law${matchCount !== 1 ? "s" : ""}</span>
      </div>
      <div class="summary-stat">
        <span class="summary-dot" style="background:#ef4444"></span>
        <span><strong>${diffCount}</strong> differing law${diffCount !== 1 ? "s" : ""}</span>
      </div>
    `;
  }
}

function onCompareAChange(val) {
  selectedStateA = val;
  renderCompareSelectors();
  renderCompareTable();
}

function onCompareBChange(val) {
  selectedStateB = val;
  renderCompareSelectors();
  renderCompareTable();
}

// =============================================
// BOOTSTRAP
// =============================================
function buildStateOptions(selected) {
  return Object.entries(STATES)
    .map(([abbr, info]) =>
      `<option value="${abbr}" ${abbr === selected ? "selected" : ""}>${info.name} (${abbr})</option>`)
    .join("");
}

function init() {
  // Populate state selectors
  $("#state-select").innerHTML = buildStateOptions(selectedState);
  $("#state-select").addEventListener("change", e => {
    selectedState = e.target.value;
    activeCategoryFilter = "All";
    renderStateLaws();
  });

  // Compare selectors built inline in HTML
  $("#compare-select-a").innerHTML = buildStateOptions(selectedStateA);
  $("#compare-select-a").addEventListener("change", e => onCompareAChange(e.target.value));

  $("#compare-select-b").innerHTML = buildStateOptions(selectedStateB);
  $("#compare-select-b").addEventListener("change", e => onCompareBChange(e.target.value));

  // Nav tabs
  $$(".nav-tab").forEach(t => {
    t.addEventListener("click", () => {
      switchTab(t.dataset.tab);
      if (t.dataset.tab === "state-laws") renderStateLaws();
      if (t.dataset.tab === "shared-laws") renderSharedLaws();
      if (t.dataset.tab === "compare") renderCompare();
    });
  });

  // Initial renders
  renderStateLaws();
  renderSharedLaws();
  renderCompare();
}

document.addEventListener("DOMContentLoaded", init);
