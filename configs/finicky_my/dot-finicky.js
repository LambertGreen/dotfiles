// ~/.finicky.js — PERSONAL lane default
//
// Variant package, same shape as git_my/git_work: finicky_my and finicky_work
// both provide ~/.finicky.js, and each machine class stows exactly one (see
// machine-classes/*/stow/stow.txt). Mirrors git_osx/git_linux/git_win, which
// likewise provide one target from mutually exclusive packages.
//
// ⚠️  The `handlers` below are DUPLICATED in configs/finicky_work/dot-finicky.js.
//     Finicky's config is a single sandboxed script with no import/require, so
//     unlike gitconfig there is no [include] to factor the shared part into.
//     Change a handler here → change it there too.
//
// Browser lanes (both Macs):
//   Google Chrome       → work lane. On personal machines this is a
//                         deliberately thin proxy; corp rules mean no real
//                         work access from here.
//   Google Chrome Beta  → personal lane.
export default {
  defaultBrowser: "Google Chrome Beta",
  handlers: [
    {
      // Google Search → Chrome Beta
      match: "www.google.com/search*",
      browser: "Google Chrome Beta",
    },
    {
      // YouTube → Chrome Beta
      match: [
        "youtube.com/*",
        "*.youtube.com/*",
      ],
      browser: "Google Chrome Beta",
    },
  ],
};
