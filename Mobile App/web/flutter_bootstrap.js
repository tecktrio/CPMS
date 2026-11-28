{{flutter_js}}
{{flutter_build_config}}

// Use CanvasKit CPU rendering by default to avoid Chrome WebGL2 / ANGLE
// shader compilation failures (e.g. BoxShadow blur shaders on macOS Chrome).
// Pass ?webgl=1 in the URL to opt back into WebGL2 hardware shaders.
const params = new URLSearchParams(window.location.search);
const forceWebgl = params.get('webgl') === '1';

_flutter.loader.load({
  config: forceWebgl
    ? {}
    : { renderer: 'canvaskit', canvasKitForceCpuOnly: true },
});
