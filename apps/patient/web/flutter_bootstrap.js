{{flutter_js}}
{{flutter_build_config}}

// Flutter's deprecated cleanup worker would race with pruevia-sw.js.
// The install helper registers only our public-shell worker after page load.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
  },
});
