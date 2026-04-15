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
  groups.forEach(function (group) {
    var panes = Array.from(
      group.querySelectorAll(":scope > .tab-pane[data-tab]"),
    );
    if (!panes.length) return;

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

    panes.forEach(function (pane, i) {
      var name = pane.getAttribute("data-tab");
      var active = name === preferred;

      var btn = document.createElement("li");
      btn.className = "tab-nav-item" + (active ? " active" : "");
      btn.setAttribute("role", "tab");
      btn.setAttribute("aria-selected", active ? "true" : "false");
      btn.setAttribute("tabindex", active ? "0" : "-1");
      btn.textContent = name;
      pane.hidden = !active;

      btn.addEventListener("click", function () {
        nav.querySelectorAll(".tab-nav-item").forEach(function (b) {
          b.classList.remove("active");
          b.setAttribute("aria-selected", "false");
          b.setAttribute("tabindex", "-1");
        });
        panes.forEach(function (p) {
          p.hidden = true;
        });
        btn.classList.add("active");
        btn.setAttribute("aria-selected", "true");
        btn.setAttribute("tabindex", "0");
        pane.hidden = false;
        localStorage.setItem(storageKey, name);
      });

      nav.appendChild(btn);
    });

    group.insertBefore(nav, group.firstChild);
  });
})();
