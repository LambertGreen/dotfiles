// ~/.finicky.js — WORK lane default
//
// Variant package, same shape as git_my/git_work: finicky_my and finicky_work
// both provide ~/.finicky.js, and each machine class stows exactly one (see
// machine-classes/*/stow/stow.txt). Mirrors git_osx/git_linux/git_win, which
// likewise provide one target from mutually exclusive packages.
//
// ⚠️  The `handlers` below are DUPLICATED in configs/finicky_my/dot-finicky.js.
//     Finicky's config is a single sandboxed script with no import/require, so
//     unlike gitconfig there is no [include] to factor the shared part into.
//     Change a handler here → change it there too.
//
// Browser lanes (both Macs):
//   Google Chrome       → work lane, and the default on a work machine.
//   Google Chrome Beta  → personal lane. Search and YouTube are routed here
//                         so incidental personal browsing stays out of the
//                         work profile.
export default {
  defaultBrowser: "Google Chrome",
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
