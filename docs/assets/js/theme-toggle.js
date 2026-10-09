(function () {
  "use strict";

  var storageKey = "ostep-color-scheme";

  function remember(input) {
    var color = {
      media: input.getAttribute("data-md-color-media") || "",
      scheme: input.getAttribute("data-md-color-scheme") || "default",
      primary: input.getAttribute("data-md-color-primary") || "indigo",
      accent: input.getAttribute("data-md-color-accent") || "indigo"
    };

    try {
      localStorage.setItem(storageKey, color.scheme);
    } catch (_) {
      // file:// 或隐私模式可能禁用 localStorage；当前页面仍可正常切换。
    }

    try {
      if (typeof window.__md_set === "function") {
        window.__md_set("__palette", { color: color });
      }
    } catch (_) {
      // Material 的状态存储不可用时，使用上面的独立存储。
    }
  }

  function initializeThemeToggle() {
    var form = document.querySelector('[data-md-component="palette"]');
    if (!form) return;

    var inputs = Array.prototype.slice.call(
      form.querySelectorAll("input.md-option[data-md-color-scheme]")
    );
    var labels = Array.prototype.slice.call(
      form.querySelectorAll("label[for^='__palette_']")
    );
    if (inputs.length < 2) return;

    function apply(input, persist) {
      inputs.forEach(function (candidate) {
        candidate.checked = candidate === input;
      });

      ["media", "scheme", "primary", "accent"].forEach(function (name) {
        var value = input.getAttribute("data-md-color-" + name);
        if (value !== null) {
          document.body.setAttribute("data-md-color-" + name, value);
        }
      });

      var activeIndex = inputs.indexOf(input);
      labels.forEach(function (label, index) {
        label.hidden = index !== activeIndex;
      });

      if (persist) remember(input);
    }

    var savedScheme = null;
    try {
      savedScheme = localStorage.getItem(storageKey);
    } catch (_) {
      // 使用页面当前配色。
    }

    var initial = inputs.find(function (input) {
      return input.getAttribute("data-md-color-scheme") === savedScheme;
    });
    if (!initial) {
      var currentScheme = document.body.getAttribute("data-md-color-scheme");
      initial = inputs.find(function (input) {
        return input.getAttribute("data-md-color-scheme") === currentScheme;
      });
    }
    apply(initial || inputs[0], false);

    form.addEventListener(
      "click",
      function (event) {
        var label = event.target.closest("label[for^='__palette_']");
        if (!label || !form.contains(label)) return;

        var target = document.getElementById(label.htmlFor);
        if (!target || !inputs.includes(target)) return;

        event.preventDefault();
        event.stopImmediatePropagation();
        apply(target, true);
      },
      true
    );
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializeThemeToggle);
  } else {
    initializeThemeToggle();
  }
})();
