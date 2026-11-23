// Tiny progressive enhancement. The page is fully readable without it.
document.addEventListener("DOMContentLoaded", () => {
  const year = document.getElementById("year");
  if (year) {
    year.textContent = String(new Date().getFullYear());
  }

  // The deploy job rewrites __COMMIT_SHA__ with the real short SHA.
  // Fall back to something honest if it was never stamped.
  const commit = document.getElementById("commit");
  if (commit && commit.textContent.includes("__COMMIT_SHA__")) {
    commit.textContent = "local";
  }
});
