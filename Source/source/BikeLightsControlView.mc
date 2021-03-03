using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Position;
using Toybox.Time.Gregorian;
using Toybox.Application.Properties as Properties;

class BikeLightsControlInputDelegate extends WatchUi.InputDelegate {

    private var _eventHandler;

    function initialize(eventHandler) {
        InputDelegate.initialize();
        _eventHandler = eventHandler.weak();
    }

    (:settings)
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (_eventHandler.stillAlive() && (key == 7 /* KEY_MENU */ || key == 4 /* KEY_ENTER */)) {
            return _eventHandler.get().openMenu();
        }

        return false;
    }

    (:touchScreen)
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (_eventHandler.stillAlive() && key == 7 /* KEY_MENU */) {
            return _eventHandler.get().openConfigurationMenu();
        }

        return false;
    }

    (:touchScreen)
    function onTap(clickEvent) {
        var result = _eventHandler.stillAlive()
            ? _eventHandler.get().onTap(clickEvent.getCoordinates())
            : false;
        WatchUi.requestUpdate();

        return result;
    }
}

class BikeLightsControlView extends BikeLightsView {

    private var _updateUiCounter = 0;
    private var _timer;
    private var _menu;
    private var _menuDelegate;
    private var _insideMenu = false;
    private var _menuOpening = false;
    private var _backgroundColor = null;
    private var _defaultSunset;
    private var _defaultSunrise;

    function initialize() {
        BikeLightsView.initialize();
        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
        var zone = System.getClockTime().timeZoneOffset;
        _defaultSunset = getSecondsOfDay(65700 /* 18:15 */ - zone);
        _defaultSunrise = getSecondsOfDay(22500 /* 6:15 */ - zone);
    }

    function onPosition(info) {
        var position = info.position.toDegrees();
        var time = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var jd = getJD(time.year, time.month, time.day);
        _sunriseTime = getSunriseSet(true, jd, position);
        _sunsetTime = getSunriseSet(false, jd, position);
        WatchUi.requestUpdate();
    }

    (:settings)
    function openMenu() {
        if (_insideMenu || _errorCode != null || _initializedLights == 0 || !initializeSettings()) {
            return false;
        }

        var menu = _initializedLights > 1
            ? WatchUi has :Menu2
                ? new Settings.LightsMenu(self)
                : new LegacySettings.LightsMenu(self)
            : WatchUi has :Menu2
                ? new Settings.LightMenu(headlightData[0].type, self)
                : new LegacySettings.LightMenu(headlightData[0].type, self);
        var delegate = WatchUi has :Menu2
            ? new Settings.MenuDelegate(menu)
            : new LegacySettings.MenuDelegate(menu);
        _insideMenu = true;
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    (:touchScreen)
    function openConfigurationMenu() {
        if (_activityColor == null || _backgroundColor == null) {
            return false;
        }

        var menu = WatchUi has :Menu2
            ? new Configuration.ConfigurationMenu(self, _activityColor, _backgroundColor)
            : new LegacyConfiguration.ConfigurationMenu(self, _activityColor, _backgroundColor);
        var delegate = WatchUi has :Menu2
            ? new Configuration.MenuDelegate(menu)
            : new LegacyConfiguration.MenuDelegate(menu);
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    (:touchScreen)
    function updateActivityColor(value) {
        _activityColor = value;
        WatchUi.requestUpdate();
    }

    (:touchScreen)
    function updateBackgroundColor(value) {
        _backgroundColor = value;
        WatchUi.requestUpdate();
    }

    function updateUi() {
        // NOTE: Use only for testing purposes when using TestLightNetwork
        //if (_lightNetwork != null && _lightNetwork has :update) {
        //    _lightNetwork.update();
        //}

        var size = _initializedLights;
        for (var i = 0; i < size; i++) {
            var lightData = getLightData(i, null);
            if (lightData[7] != null) {
                if (lightData[9] <= 0) {
                    lightData[7] = null;
                    WatchUi.requestUpdate();
                } else {
                    lightData[9]--; /* Timeout */
                    continue;
                }
            }
        }

        _updateUiCounter = (_updateUiCounter + 1) % 60;
        if (_updateUiCounter == 0) {
            WatchUi.requestUpdate();
        }
    }

    function onShow() {
        if (_insideMenu) {
            _insideMenu = false;
            WatchUi.requestUpdate();
            return;
        } else if (self has :openMenu) {
            _menuOpening = !openMenu();
        }

        resetLights();
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:updateUi), 1000, true);
        }
    }

    function resetLights() {
        BikeLightsView.onShow();
        WatchUi.requestUpdate();
    }

    function onNetworkStateUpdate(networkState) {
        if (_lightNetwork == null) {
            return; // The view is hidden
        }

        BikeLightsView.onNetworkStateUpdate(networkState);
        WatchUi.requestUpdate();
        if (_menuOpening) {
            _menuOpening = !openMenu();
        }
    }

    function onSettingsChanged() {
        BikeLightsView.onSettingsChanged();
        _backgroundColor = Properties.getValue("BC");
        WatchUi.requestUpdate();
        if (_menuOpening) {
            _menuOpening = !openMenu();
        }
    }

    function updateLight(light, mode) {
        if (_lightNetwork == null) {
            return; // The view is hidden
        }

        BikeLightsView.updateLight(light, mode);
        WatchUi.requestUpdate();
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
        if (_insideMenu) {
            return;
        }

        _timer.stop();
        _timer = null;
        releaseLights();
        _lightNetwork = null; // Release light network
    }

    protected function getBackgroundColor() {
        if (_backgroundColor == 1) {
            var sunset = _sunsetTime != null ? _sunsetTime : _defaultSunset;
            var sunrise = _sunriseTime != null ? _sunriseTime : _defaultSunrise;
            var now = (Time.now().value() - _todayMoment) % 86400;
            var isDay = sunrise > sunset /* Whether timespan goes into the next day */
                ? now > sunrise || now < sunset
                : now > sunrise && now < sunset;

            return isDay
                ? 0xFFFFFF /* COLOR_WHITE */
                : 0x000000; /* COLOR_BLACK */
        }

        return _backgroundColor;
    }

    protected function getPropertyValue(key) {
        return key.equals("RL") || key.equals("CMO") ? false : Properties.getValue(key);
    }

    protected function preCalculate(dc, width, height) {
        var padding = 3;
        var settings = WatchUi.loadResource(Rez.JsonData.Settings);
        _monochrome = !settings[0];
        _titleFont = settings[1];
        _titleTopPadding = settings[2];
        _offsetX = 0;
        if (self has :_fieldWidth) {
            _fieldWidth = width;
            _isFullScreen = true;
        }

        _batteryY = (height / 2) + 19 - padding;
        _lightY = _batteryY - padding - 32 /* Lights font size */;
        _titleY = _lightY - dc.getFontHeight(_titleFont) - _titleTopPadding;
    }

    protected function drawLight(lightData, position, dc, width, fgColor, bgColor) {
        var justification = lightData[0].type;
        var direction = justification == 0 ? 1 : -1;
        var lightX = Math.round(width * 0.25f * position);
        var batteryStatus = getLightBatteryStatus(lightData);
        var title = lightData[5];
        var lightXOffset = justification == 0 ? -4 : 2;
        dc.setColor(fgColor, bgColor);

        if (title != null && _titleY != null) {
            dc.drawText(lightX, _titleY, _titleFont, title, 1 /* TEXT_JUSTIFY_CENTER */);
        }

        dc.drawText(lightX + (direction * (_batteryWidth / 2)) + lightXOffset, _lightY, _lightsFont, lightData[1], justification);
        dc.drawText(lightX + (direction * 8), _lightY + 11, _controlModeFont, $.controlModes[lightData[4]], 1 /* TEXT_JUSTIFY_CENTER */);
        drawBattery(dc, fgColor, lightX, _batteryY, batteryStatus);
    }

    // Do not set any mode
    protected function setInitialLightMode(lightData, lightMode, controlMode) {
        if (controlMode == 1 /* NETWORK */) {
            lightData[5] = _networkMode != null && _networkMode < $.networkModes.size()
                ? $.networkModes[_networkMode]
                : null;
        }
    }

    protected function getInitialLightMode(light, controlMode) {
        return light.mode;
    }

    (:touchScreen)
    protected function onLightPanelModeChange(lightData, lightType, lightMode, controlMode) {
        var newControlMode = lightMode < 0 ? 1 /* NETWORK */
            : controlMode != 2 ? 2 /* MANUAL */
            : null;
        setLightAndControlMode(lightData, lightType, lightMode, newControlMode);
    }

    protected function getLightProperty(id, lightType, defaultValue) {
        return defaultValue;
    }

    protected function setLightProperty(id, lightType, value) {
        // Do not store any data
    }
}
