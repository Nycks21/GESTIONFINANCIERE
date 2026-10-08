(function () {
  try {
    document.documentElement.classList.toggle(
      "dark-mode",
      window.localStorage.getItem("darkMode") === "enabled",
    );
  } catch (error) {
    document.documentElement.classList.remove("dark-mode");
  }
})();
