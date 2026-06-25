/* Bind Cmd+K (macOS) / Ctrl+K (Windows/Linux) to open Material's search,
   matching the "⌘K" hint chip shown in the search field. Material's built-in
   shortcuts (f / s / /) keep working; this just adds the modern Cmd+K. */
document.addEventListener("keydown", function (e) {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
    e.preventDefault();
    var toggle = document.querySelector('[data-md-toggle="search"]');
    var input = document.querySelector(".md-search__input");
    if (toggle && input) {
      toggle.checked = true;
      // Focus on the next frame so the field is visible before we focus it.
      requestAnimationFrame(function () {
        input.focus();
        input.select();
      });
    }
  }
});
