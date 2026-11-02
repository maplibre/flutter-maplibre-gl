/* Bind Cmd+K (macOS) / Ctrl+K (Windows/Linux) to open Material's search,
   matching the "⌘K" hint chip shown in the search field. Material's built-in
   shortcuts (f / s / /) keep working; this just adds the modern Cmd+K.
   Zensical binds Cmd+K itself and has no .md-search__input until the search
   opens, so the key is left alone there. */
document.addEventListener("keydown", function (e) {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
    var toggle = document.querySelector('[data-md-toggle="search"]');
    var input = document.querySelector(".md-search__input");
    if (toggle && input) {
      e.preventDefault();
      toggle.checked = true;
      // Focus on the next frame so the field is visible before we focus it.
      requestAnimationFrame(function () {
        input.focus();
        input.select();
      });
    }
  }
});
