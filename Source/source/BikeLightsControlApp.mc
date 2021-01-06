using Toybox.Application;

class BikeLightsControlApp extends Application.AppBase {

    private var _view;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        _view = null;
    }

    function onSettingsChanged() {
        if (_view == null) {
            return;
        }

        _view.onSettingsChanged();
        _view.resetLights();
    }

    // Return the initial view of your application here
    function getInitialView() {
        if (_view == null) {
            _view = new BikeLightsControlView();
        }

        return [ _view, new BikeLightsControlInputDelegate(_view) ];
    }

    (:glance)
    function getGlanceView() {
        return [ new BikeLightsGlanceView() ];
    }
}