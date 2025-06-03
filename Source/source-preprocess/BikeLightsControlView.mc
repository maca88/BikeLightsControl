using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Position;
using Toybox.Time.Gregorian;
using Toybox.Application.Properties as Properties;

(/* #include TARGET */)
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

    (:settings)
    function onTap(clickEvent) {
        return _eventHandler.stillAlive()
            ? _eventHandler.get().openMenu()
            : false;
    }
}

(/* #include TARGET */)
class BikeLightsControlView extends BikeLightsView {

    private var _updateUiCounter = 0;
    private var _timer;
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
        _separatorColor = -1; // No separator
    }

    function onPosition(info) {
        var position = info.position.toDegrees();
        var time = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        _sunriseTime = getSunriseSet(true, time, position);
        _sunsetTime = getSunriseSet(false, time, position);
        WatchUi.requestUpdate();
    }

    (:settings)
    function openMenu() {
        var menu = null;
        if (_insideMenu) {
            return false;
        }

        if (_errorCode != null ||
            _initializedLights == 0 ||
            !validateSettingsLightModes(headlightData[0], headlightData[17]) ||
            !validateSettingsLightModes(taillightData[0], taillightData[17])) {
            if (WatchUi has :Menu2) {
                menu = new AppSettings.Menu(self);
                _insideMenu = true;
                WatchUi.pushView(menu, new MenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
                return true;
            }

            return false;
        }

        var menuContext = [
            headlightSettings,
            taillightSettings,
            getLightSettings(0 /* LIGHT_TYPE_HEADLIGHT */),
            getLightSettings(2 /* LIGHT_TYPE_TAILLIGHT */)
        ];
        menu = _initializedLights > 1
            ? WatchUi has :Menu2
                ? new LightsSettings.LightsMenu(self, menuContext, true)
                : new LegacySettings.LightsMenu(self, menuContext)
            : WatchUi has :Menu2
                ? new LightsSettings.LightMenu(getLightData(null)[0].type, self, menuContext, true)
                : new LegacySettings.LightMenu(getLightData(null)[0].type, self, menuContext);
        var delegate = WatchUi has :Menu2
            ? new MenuDelegate(menu)
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
        // Needed for TestLightNetwork and IndividualLightNetwork
        if (_errorCode == null && _lightNetwork != null && _lightNetwork has :update) {
            _errorCode = _lightNetwork.update();
        }

        var size = _initializedLights;
        for (var i = 0; i < size; i++) {
            var lightData = getLightData(size == 1 ? null : i * 2);
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

        if (_menuOpening) {
            _menuOpening = self has :openMenu ? !openMenu() : false; // If self has :openMenu is added to the if statement an exception is thrown on runtime for FR245
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
        }

        resetLights();
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:updateUi), 1000, true);
        }
    }

    function resetLights() {
        if (_lightNetwork instanceof AntLightNetwork.IndividualLightNetwork) {
            // We don't need to recreate IndividualLightNetwork as the network mode does not change
            return;
        }

        recreateLightNetwork();
        WatchUi.requestUpdate();
    }

    function onNetworkStateUpdate(networkState) {
        if (_lightNetwork == null) {
            return; // The view is hidden
        }

        var isInitialized = _initializedLights > 0;
        BikeLightsView.onNetworkStateUpdate(networkState);
        if (!isInitialized && _initializedLights > 0) {
            _menuOpening = self has :openMenu ? !openMenu() : false; // If self has :openMenu is added to the if statement an exception is thrown on runtime for FR245
        }

        WatchUi.requestUpdate();
    }

    function onSettingsChanged(setupSensors) {
        BikeLightsView.onSettingsChanged(setupSensors);
        _backgroundColor = Properties.getValue("BC");
        WatchUi.requestUpdate();

        // Do not reset lights before the widget is shown
        if (_timer != null) {
            resetLights();
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

        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }

        release(true);
    }

    protected function getBackgroundColor() {
        if (_backgroundColor != 1 /* Auto */) {
            return _backgroundColor;
        }

        var isDay;
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings has :isNightModeEnabled) {
            isDay = !deviceSettings.isNightModeEnabled;
        } else {
            var sunset = _sunsetTime != null ? _sunsetTime : _defaultSunset;
            var sunrise = _sunriseTime != null ? _sunriseTime : _defaultSunrise;
            var now = (Time.now().value() - _todayMoment) % 86400;
            isDay = sunrise > sunset /* Whether timespan goes into the next day */
                ? now > sunrise || now < sunset
                : now > sunrise && now < sunset;
        }

        return isDay
            ? 0xFFFFFF /* COLOR_WHITE */
            : 0x000000; /* COLOR_BLACK */
    }

    protected function getPropertyValue(key) {
        return key.equals("RL") ? false : Properties.getValue(key);
    }

    protected function preCalculate(dc, width, height) {
        BikeLightsView.preCalculate(dc, width, height);
        var fonts = Rez.Fonts;
        _lightsFont = WatchUi.loadResource(fonts[:lightsFont]);
        _batteryFont = WatchUi.loadResource(fonts[:batteryFont]);
        _controlModeFont = WatchUi.loadResource(fonts[:controlModeFont]);
        var padding = 3;
        var settings = WatchUi.loadResource(Rez.JsonData.Settings);
        _separatorWidth = settings[0];
        _titleFont = settings[1];
        _offsetX = 0;
        var batteryHeight = /* #if highResolution */26/* #else */18/* #endif */;
        var lightHeight = /* #if highResolution */49/* #else */32/* #endif */;
        _batteryY = (height / 2) + batteryHeight - padding;
        _lightY = _batteryY - padding - lightHeight;
        _titleY = _lightY - dc.getFontHeight(_titleFont) - settings[2];
    }

    protected function drawLight(lightData, position, dc, width, fgColor, bgColor) {
        var justification = lightData[0].type;
        if (_invertLights) {
            justification = justification == 0 ? 2 : 0;
            position = position == 1 ? 3
              : position == 3 ? 1
              : position;
        }

        var direction = justification == 0 ? 1 : -1;
        var lightX = Math.round(width * 0.25f * position);
        var batteryStatus = getLightBatteryStatus(lightData);
        var title = lightData[5];
        var lightXOffset = justification == 0 ? -4 : 2;
        dc.setColor(fgColor, bgColor);

        if (title != null && _titleY != null) {
            dc.drawText(lightX, _titleY, _titleFont, title, 1 /* TEXT_JUSTIFY_CENTER */);
        }

        var iconColor = lightData[16];
        if (iconColor != null && iconColor != 1 /* Black/White */) {
            dc.setColor(iconColor, -1 /* COLOR_TRANSPARENT */);
        }

// #if highResolution
        dc.drawText(lightX + (direction * (68 /* _batteryWidth */ / 2)) + lightXOffset, _lightY, _lightsFont, lightData[1], justification);
        dc.drawText(lightX + (direction * 10), _lightY + 16, _controlModeFont, $.controlModes[lightData[4]], 1 /* TEXT_JUSTIFY_CENTER */);
// #else
        dc.drawText(lightX + (direction * (49 /* _batteryWidth */ / 2)) + lightXOffset, _lightY, _lightsFont, lightData[1], justification);
        dc.drawText(lightX + (direction * 8), _lightY + 11, _controlModeFont, $.controlModes[lightData[4]], 1 /* TEXT_JUSTIFY_CENTER */);
// #endif
        drawBattery(dc, fgColor, lightX, _batteryY, batteryStatus);
    }

    protected function getLightProperty(id, lightType, defaultValue) {
        return defaultValue;
    }

    protected function setLightProperty(id, lightType, value) {
        // Do not store any data
    }
}
