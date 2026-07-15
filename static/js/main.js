// Dark mode toggle - keeps body.dark (legacy) and data-bs-theme (Bootstrap 5)
// in sync so both the old class-based styles and the new CSS-var styles work.
function applyTheme(dark) {
  if (dark) {
    document.body.classList.add("dark");
    document.documentElement.setAttribute("data-bs-theme", "dark");
  } else {
    document.body.classList.remove("dark");
    document.documentElement.setAttribute("data-bs-theme", "light");
  }
}

const modeBtn = document.getElementById("mode");
if (modeBtn) {
  modeBtn.addEventListener("click", () => {
    const isDark = document.body.classList.contains("dark");
    applyTheme(!isDark);
    localStorage.setItem("theme", !isDark ? "dark" : "light");
  });
}

// Apply saved preference or fall back to system preference.
const saved = localStorage.getItem("theme");
if (
  saved === "dark" ||
  (!saved && window.matchMedia("(prefers-color-scheme: dark)").matches)
) {
  applyTheme(true);
} else {
  applyTheme(false);
}

// Also respond to live system-preference changes when no saved preference.
window
  .matchMedia("(prefers-color-scheme: dark)")
  .addEventListener("change", (e) => {
    if (!localStorage.getItem("theme")) {
      applyTheme(e.matches);
    }
  });

// Bootstrap collapse polyfill - handles data-bs-toggle="collapse" without
// requiring Bootstrap JS (sidebar group toggles + mobile nav toggle).
document.addEventListener("click", function (e) {
  var trigger = e.target.closest('[data-bs-toggle="collapse"]');
  if (!trigger) return;
  var sel = trigger.getAttribute("data-bs-target");
  if (!sel) return;
  var target = document.querySelector(sel);
  if (!target) return;
  var open = target.classList.contains("show");
  if (open) {
    target.classList.remove("show");
    trigger.setAttribute("aria-expanded", "false");
  } else {
    target.classList.add("show");
    trigger.setAttribute("aria-expanded", "true");
  }
});

// Sidebar desktop collapse toggle.
var sidebarCol = document.getElementById("sidebar-col");
var sidebarToggle = document.getElementById("sidebar-toggle");
var SIDEBAR_KEY = "sidebar-open";

function setSidebar(open) {
  if (!sidebarCol) return;
  if (open) {
    sidebarCol.classList.remove("sidebar-collapsed");
    if (sidebarToggle) sidebarToggle.setAttribute("aria-expanded", "true");
  } else {
    sidebarCol.classList.add("sidebar-collapsed");
    if (sidebarToggle) sidebarToggle.setAttribute("aria-expanded", "false");
  }
  localStorage.setItem(SIDEBAR_KEY, open ? "1" : "0");
}

if (sidebarToggle) {
  sidebarToggle.addEventListener("click", function () {
    var open = !sidebarCol.classList.contains("sidebar-collapsed");
    setSidebar(!open);
  });
}

// Restore saved sidebar state (default: open).
var savedSidebar = localStorage.getItem(SIDEBAR_KEY);
if (savedSidebar === "0") setSidebar(false);

// Tab groups — find .tab-group > .tab-pane[data-tab] containers in guide pages,
// build a nav bar from the tab names, show/hide panes on click.
// Selection is persisted in localStorage keyed by the set of tab names so the
// same platform choice carries over to every page that has matching tabs.
(function initTabGroups() {
  var groups = document.querySelectorAll(".tab-group");
  var groupSeq = 0;
  groups.forEach(function (group) {
    var panes = Array.from(
      group.querySelectorAll(":scope > .tab-pane[data-tab]"),
    );
    if (!panes.length) return;
    groupSeq++;

    // Stable key: sorted tab names joined, so GitHub/ADO tabs on every page share state.
    var tabNames = panes.map(function (p) {
      return p.getAttribute("data-tab");
    });
    var storageKey = "pp-tab:" + tabNames.slice().sort().join("|");

    var preferred =
      localStorage.getItem(storageKey) ||
      group.getAttribute("data-default") ||
      tabNames[0];
    // Fall back to first tab if saved value no longer exists in this group.
    if (!tabNames.includes(preferred)) preferred = tabNames[0];

    // Build nav.
    var nav = document.createElement("ul");
    nav.className = "tab-nav";
    nav.setAttribute("role", "tablist");

    var tabs = [];

    // Select tab `i`: update roving tabindex, aria-selected, and pane
    // visibility, persist the choice, and optionally move focus (keyboard nav).
    function activate(i, focus) {
      panes.forEach(function (p) {
        p.hidden = true;
      });
      tabs.forEach(function (t) {
        t.classList.remove("active");
        t.setAttribute("aria-selected", "false");
        t.setAttribute("tabindex", "-1");
      });
      var tab = tabs[i];
      tab.classList.add("active");
      tab.setAttribute("aria-selected", "true");
      tab.setAttribute("tabindex", "0");
      panes[i].hidden = false;
      localStorage.setItem(storageKey, tabNames[i]);
      if (focus) tab.focus();
    }

    panes.forEach(function (pane, i) {
      var name = pane.getAttribute("data-tab");
      var active = name === preferred;
      var tabId = "pp-tab-" + groupSeq + "-" + i;
      var paneId = "pp-tabpanel-" + groupSeq + "-" + i;

      var btn = document.createElement("li");
      btn.className = "tab-nav-item" + (active ? " active" : "");
      btn.id = tabId;
      btn.setAttribute("role", "tab");
      btn.setAttribute("aria-selected", active ? "true" : "false");
      btn.setAttribute("tabindex", active ? "0" : "-1");
      btn.setAttribute("aria-controls", paneId);
      btn.textContent = name;

      // Pane becomes a labelled, focusable tabpanel.
      pane.id = paneId;
      pane.setAttribute("role", "tabpanel");
      pane.setAttribute("aria-labelledby", tabId);
      pane.setAttribute("tabindex", "0");
      pane.hidden = !active;

      btn.addEventListener("click", function () {
        activate(i, false);
      });

      tabs.push(btn);
      nav.appendChild(btn);
    });

    // ARIA APG tabs pattern, automatic activation: arrows move focus and select
    // (wrapping), Home/End jump to the ends, Enter/Space (re)activate.
    nav.addEventListener("keydown", function (e) {
      var current = tabs.indexOf(document.activeElement);
      if (current === -1) return;
      var next = null;
      switch (e.key) {
        case "ArrowRight":
        case "ArrowDown":
          next = (current + 1) % tabs.length;
          break;
        case "ArrowLeft":
        case "ArrowUp":
          next = (current - 1 + tabs.length) % tabs.length;
          break;
        case "Home":
          next = 0;
          break;
        case "End":
          next = tabs.length - 1;
          break;
        case "Enter":
        case " ":
        case "Spacebar":
          activate(current, true);
          e.preventDefault();
          return;
        default:
          return;
      }
      activate(next, true);
      e.preventDefault();
    });

    group.insertBefore(nav, group.firstChild);
  });
})();
