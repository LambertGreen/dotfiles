// ~/.finicky.js
export default {
  defaultBrowser: "Google Chrome",
  // rewrite: [
  //   // Example rewrite (keep if you want)
  //   {
  //     match: "x.com/*",
  //     url: (url) => {
  //       url.host = "xcancel.com";
  //       return url;
  //     },
  //   },
  // ],
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

