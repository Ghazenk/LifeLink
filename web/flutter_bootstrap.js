{{flutter_js}}
{{flutter_build_config}}

// Ship CanvasKit with the app; never load the renderer from Google's CDN.
_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});
