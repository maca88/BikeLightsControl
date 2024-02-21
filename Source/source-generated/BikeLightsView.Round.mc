// <auto-generated>
//     This code was generated by a tool.
//     Changes to this file may cause incorrect behavior and will be lost if the code is regenerated.
// </auto-generated>
using Toybox.WatchUi;
using Toybox.AntPlus;
using Toybox.Math;
using Toybox.System;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application.Properties as Properties;
using Toybox.Attention;

(:round :nonTouchScreen :mediumResolution)
const lightModeCharacters = [
    "S", /* High steady beam */
    "M", /* Medium steady beam */
    "s", /* Low steady beam */
    "F", /* High flash */
    "m", /* Medium flash */
    "f"  /* Low flash */
];

(:round :nonTouchScreen :mediumResolution)
const controlModes = [
    "S", /* SMART */
    "N", /* NETWORK */
    "M"  /* MANUAL */
];

(:round :nonTouchScreen :mediumResolution)
const networkModes = [
    "INDV", /* LIGHT_NETWORK_MODE_INDIVIDUAL */
    "AUTO", /* LIGHT_NETWORK_MODE_AUTO */
    "HIVI", /* LIGHT_NETWORK_MODE_HIGH_VIS */
    "TRAIL"
];

(:round :nonTouchScreen :mediumResolution)
class BikeLightsView extends  WatchUi.View  {

    // Fonts
    protected var _lightsFont;
    protected var _batteryFont;
    protected var _controlModeFont;

    // Fields related to lights and their network
    protected var _lightNetwork;
    protected var _lightNetworkListener;
    protected var _networkMode;
    protected var _initializedLights = 0;

    // Light data:
    // 0. BikeLight instance
    // 1. Light text (S])
    // 2. Current light mode
    // 3. Force Smart mode (high memory devices only)
    // 4. Current light control mode: 0 SMART, 1 NETWORK, 2 MANUAL
    // 5. Title
    // 6. Fit field
    // 7. Next light mode
    // 8. Next title
    // 9. Compute setMode timeout
    // 10. Current filter group index
    // 11. Current filter group deactivation delay
    // 12. Next filter group index
    // 13. Next filter group activation delay
    // 14. Light modes
    // 15. Serial number
    // 16. Icon color
    // 17. Filters
    var headlightData = new [18];
    var taillightData = new [18];

    protected var _errorCode;

    // Settings
    protected var _separatorWidth;
    protected var _separatorColor;
    protected var _titleFont;
    protected var _invertLights;
    protected var _activityColor;
    protected var _batteryY;
    protected var _lightY;
    protected var _titleY;
    protected var _offsetX;
    // Parsed filters
    protected var _globalFilters;

    // Settings data
    (:settings) var headlightSettings;
    (:settings) var taillightSettings;
    private var _individualNetwork;
    private var _updateSettings = false;

    // Fields used to evaluate filters
    protected var _todayMoment;
    protected var _sunsetTime;
    protected var _sunriseTime;
    // Callbacks (value must be a weak reference)
    public var onLightModeChangeCallback;
    public var onLightControlModeChangeCallback;

    private var _lastUpdateTime = 0;
    private var _lastOnShowCallTime = 0;

    // Used as an out parameter for getting the group filter data
    // 0. Filter group title
    // 1. Filter group index
    // 2. Filter group activation time
    // 3. Filter group deactivation time
    private var _filterResult = new [4];

    function initialize() {
        View.initialize();
        _lightNetworkListener = new BikeLightNetworkListener(self);

        // In order to avoid calling Gregorian.utcInfo every second, calcualate Unix Timestamp of today
        var now = Time.now();
        var time = Gregorian.utcInfo(now, 0 /* FORMAT_SHORT */);
        _todayMoment = now.value() - ((time.hour * 3600) + (time.min * 60) + time.sec);

        onSettingsChanged();
    }

    // Called from SmartBikeLightsApp.onSettingsChanged()
    function onSettingsChanged() {
        //System.println("onSettingsChanged" + " timer=" + System.getTimer());
        _invertLights = getPropertyValue("IL");
        _activityColor = getPropertyValue("AC");
        _errorCode = null;
        try {
            var hlData = headlightData;
            var tlData = taillightData;
            // Free memory before parsing to avoid out of memory exception
            _globalFilters = null;
            hlData[17] = null; // Headlight filters
            tlData[17] = null; // Taillight filters
            var configuration = parseConfiguration();
            _globalFilters = configuration[0];
            // configuration[1];  // Headlight modes
            // configuration[2];  // Headlight serial number
            // configuration[3];  // Headlight color
            // configuration[4];  // Headlight filters
            // configuration[5];  // Taillight modes
            // configuration[6];  // Taillight serial number
            // configuration[7];  // Taillight color
            // configuration[8];  // Taillight filters
            for (var i = 0; i < 8; i++) {
                var lightData = i < 4 ? hlData : tlData;
                lightData[14 + (i % 4)] = configuration[i + 1];
            }

            setupLightButtons(configuration);
            initializeLights(null);
        } catch (e) {
            _errorCode = 4;
        }
    }

    // Overrides DataField.onLayout
    function onLayout(dc) {
        // Due to getObsurityFlags returning incorrect results here, we have to postpone the calculation to onUpdate method
        _lightY = null; // Force to pre-calculate again
    }

    function onShow() {
        //System.println("onShow=" + _lastUpdateTime  + " timer=" + System.getTimer());
        var timer = System.getTimer();
        _lastOnShowCallTime = timer;
        if (_lightNetwork instanceof AntLightNetwork.IndividualLightNetwork) {
            // We don't need to recreate IndividualLightNetwork as the network mode does not change
            return;
        }

        // When start button is pressed onShow is called, skip re-initialization in such case. This also prevents
        // a re-initialization when switching between two data screens that both contain this data field.
        if (timer - _lastUpdateTime < 1500) {
            initializeLights(null);
            return;
        }

        // In case the user modifies the network mode outside the data field by using the built-in Garmin lights menu,
        // the LightNetwork mode will not be updated (LightNetwork.getNetworkMode). The only way to update it is to
        // create a new LightNetwork.
        recreateLightNetwork();
    }

    function release(final) {
        releaseLights();
        if (_lightNetwork != null && _lightNetwork has :release) {
            _lightNetwork.release();
        }

        _lightNetwork = null; // Release light network
    }

    function onUpdate(dc) {
        var timer = System.getTimer();
        if (_updateSettings) {
            _updateSettings = false;
            onSettingsChanged();
        }

        _lastUpdateTime = timer;
        var width = dc.getWidth();
        var height = dc.getHeight();
        var bgColor = getBackgroundColor();
        var fgColor = 0x000000; /* COLOR_BLACK */
        if (bgColor == 0x000000 /* COLOR_BLACK */) {
            fgColor = 0xFFFFFF; /* COLOR_WHITE */
        }

        dc.setColor(fgColor, bgColor);
        dc.clear();
        if (_lightY == null) {
            preCalculate(dc, width, height);
        }

        var text = _errorCode != null ? "Error " + _errorCode
            : _initializedLights == 0 ? "No network"
            : null;
        if (text != null) {
            setTextColor(dc, fgColor);
            dc.drawText(width / 2, height / 2, 2, text, 1 /* TEXT_JUSTIFY_CENTER */ | 4 /* TEXT_JUSTIFY_VCENTER */);
            return;
        }

        if (_initializedLights == 1) {
            drawLight(getLightData(null), 2, dc, width, fgColor, bgColor);
            return;
        }

        // Draw separator
        var separatorColor = _separatorColor;
        if (separatorColor != -1 /* No separator */) {
            setTextColor(dc, separatorColor == 1 /* Black/White */ ? fgColor : separatorColor);
            dc.setPenWidth(_separatorWidth);
            dc.drawLine(width / 2 + _offsetX, 0, width / 2 + _offsetX, height);
        }

        drawLight(headlightData, 1, dc, width, fgColor, bgColor);
        drawLight(taillightData, 3, dc, width, fgColor, bgColor);
    }

    function onNetworkStateUpdate(networkState) {
        //System.println("onNetworkStateUpdate=" + networkState  + " timer=" + System.getTimer());
        if (_initializedLights > 0 && networkState != 2 /* LIGHT_NETWORK_STATE_FORMED */) {
            // Set the mode to disconnected in order to be recorded in case lights recording is enabled
            updateLightTextAndMode(headlightData, -1);
            updateLightTextAndMode(taillightData, -1);
            // We have to reinitialize in case the light network is dropped after its formation
            releaseLights();
            return;
        }

        if (_initializedLights > 0 || networkState != 2 /* LIGHT_NETWORK_STATE_FORMED */) {
            //System.println("Skip=" + _initializedLights + " networkState=" + networkState +" timer=" + System.getTimer());
            return;
        }

        var networkMode = _lightNetwork.getNetworkMode();
        if (networkMode == null) {
            networkMode = 3; // TRAIL
        }

        // In case the user changes the network mode outside the application, set the default to network control mode
        var newNetworkMode = _networkMode != null && networkMode != _networkMode ? networkMode : null;
        _networkMode = networkMode;

        // Initialize lights
        initializeLights(newNetworkMode);
    }

    function updateLight(light, mode) {
        var lightType = light.type;
        if (_initializedLights == 0 || (lightType != 0 /* LIGHT_TYPE_HEADLIGHT */ && lightType != 2 /* LIGHT_TYPE_TAILLIGHT */)) {
            //System.println("skip updateLight light=" + light.type + " mode=" + mode + " timer=" + System.getTimer());
            return;
        }

        var lightData = getLightData(lightType);
        light = tryUpdateMultiBikeLight(lightData, light);
        var oldLight = lightData[0];
        if (oldLight == null || oldLight.identifier != light.identifier) {
            return;
        }

        lightData[0] = light;
        var nextMode = lightData[7];
        if (mode == lightData[2] && nextMode == null) {
            //System.println("skip updateLight light=" + light.type + " mode=" + mode + " currMode=" + lightData[2] + " nextMode=" + lightData[7]  + " timer=" + System.getTimer());
            return;
        }

        //System.println("updateLight light=" + light.type + " mode=" + mode + " currMode=" + lightData[2] + " nextMode=" + nextMode + " timer=" + System.getTimer());
        var controlMode = lightData[4];
        if (nextMode == mode) {
            lightData[5] = lightData[8]; // Update title
            lightData[7] = null;
            lightData[8] = null;
        } else if (controlMode != 1 /* NETWORK */) {
            lightData[5] = null;
        }

        if (updateLightTextAndMode(lightData, mode) &&
            nextMode != mode && controlMode != 1 /* NETWORK */ &&
            // In the first few seconds during and after the network formation the lights may automatically switch to different
            // light modes, which can change their control mode to manual. In order to avoid changing the control mode, we
            // ignore initial light mode changes. This mostly helps when a device wakes up after only a few seconds of sleep.
            (System.getTimer() - _lastOnShowCallTime) > 5000) {
            // Change was done outside the data field.
            onExternalLightModeChange(lightData, mode);
        }
    }

    (:settings)
    function getLightSettings(lightType) {
        var lightData = getLightData(lightType);
        var light = lightData[0];
        if (light == null) {
            return null;
        }

        var lightSettings = light.type == 0 /* LIGHT_TYPE_HEADLIGHT */
            ? headlightSettings
            : taillightSettings;

        return lightSettings == null
            ? getDefaultLightSettings(light)
            : lightSettings;
    }

    function setLightAndControlMode(lightData, lightType, newMode, newControlMode) {
        if (lightData[0] == null || _errorCode != null) {
            return; // This can happen when in menu the network is dropped or an invalid configuration is set
        }

        var controlMode = lightData[4];
        // In case the previous mode is Network we have to call setMode to override it
        var forceSetMode = controlMode == 1 /* NETWORK */ && newControlMode != null;
        if (newControlMode == 1 /* NETWORK */) {
            setNetworkMode(lightData, _networkMode);
        } else if ((controlMode == 2 /* MANUAL */ && newControlMode == null) || newControlMode == 2 /* MANUAL */) {
            setLightProperty("MM", lightType, newMode);
            setLightMode(lightData, newMode, null, forceSetMode);
        } else if (newControlMode == 0 /* SMART */ && forceSetMode) {
            setLightMode(lightData, lightData[2], null, true);
        }

        if (newControlMode != null) {
            setLightProperty("CM", lightType, newControlMode);
            lightData[4] = newControlMode;
            var callback = onLightControlModeChangeCallback;
            if (callback != null && callback.stillAlive() && callback.get() has :onLightControlModeChange) {
                callback.get().onLightControlModeChange(lightType, newControlMode);
            }
        }
    }

    function getLightData(lightType) {
        return lightType == null
            ? headlightData[0] != null ? headlightData : taillightData
            : lightType == 0 ? headlightData : taillightData;
    }

    function tryUpdateMultiBikeLight(lightData, newLight) {
        var oldLight = lightData[0];
        if (oldLight == null || !(oldLight has :updateLight)) {
            return newLight;
        }

        return oldLight.updateLight(newLight, lightData[7]);
    }

    function combineLights(lightData, light) {
        var currentLight = lightData[0];
        if (currentLight has :addLight) {
            currentLight.addLight(light);
            return currentLight;
        }

        return new MultiBikeLight(currentLight, light);
    }

    protected function getPropertyValue(key) {
        return Properties.getValue(key);
    }

    protected function getBackgroundColor() {
    }

    protected function preCalculate(dc, width, height) {
    }
    protected function initializeLights(newNetworkMode) {
        //System.println("initializeLights=" + newNetworkMode + " timer=" + System.getTimer());
        var errorCode = _errorCode;
        var lightNetwork = _lightNetwork;
        if (lightNetwork == null || (errorCode != null && errorCode > 3)) {
            return;
        }

        errorCode = null;
        var firstTime = _initializedLights == 0;
        releaseLights();
        var lights = lightNetwork.getBikeLights();
        if (lights == null) {
            _errorCode = errorCode;
            return;
        }

        var recordLightModes = getPropertyValue("RL");
        var initializedLights = 0;
        var hasSerialNumber = headlightData[15] != null || taillightData[15] != null;
        for (var i = 0; i < lights.size(); i++) {
            var light = lights[i];
            var lightType = light != null ? light.type : 7;
            if (lightType != 0 && lightType != 2) {
                errorCode = 1;
                break;
            }

            var lightData = getLightData(lightType);
            var serial = lightData[15];
            if ((hasSerialNumber && lightData[14] == null) ||
                (hasSerialNumber && serial != null && serial != lightNetwork.getProductInfo(light.identifier).serial)) {
                continue;
            }

            if (lightData[0] != null) {
                light = combineLights(lightData, light);
                initializedLights--;
            }

            var filters = lightData[17];
            var capableModes = getLightModes(light);
            // Validate filters light modes
            if (filters != null) {
                var j = 0;
                while (j < filters.size()) {
                    var totalFilters = filters[j + 1];
                    if (capableModes.indexOf(filters[j + 2]) < 0) {
                        errorCode = 3;
                        break;
                    }

                    j = j + 5 + (totalFilters * 3);
                }
            }

            if (newNetworkMode != null) {
                setLightProperty("CM", lightType, 1 /* NETWORK */);
            }

            var controlMode = getLightProperty("CM", lightType, filters != null ? 0 /* SMART */ : 1 /* NETWORK */);
            var lightMode = light.mode;
            var lightModeIndex = capableModes.indexOf(lightMode);
            if (lightModeIndex < 0) {
                lightModeIndex = 0;
                lightMode = 0; /* LIGHT_MODE_OFF */
            }

            if (recordLightModes && lightData[6] == null) {
                lightData[6] = createField(
                    lightType == 0 /* LIGHT_TYPE_HEADLIGHT */ ? "headlight_mode" : "taillight_mode",
                    lightType, // Id
                    1 /*DATA_TYPE_SINT8 */,
                    {
                        :mesgType=> 20 /* Fit.MESG_TYPE_RECORD */
                    }
                );
            }

            lightData[0] = light;
            lightData[2] = null; // Force to update light text in case light modes were changed
            updateLightTextAndMode(lightData, lightMode);
            var oldControlMode = lightData[4];
            lightData[4] = controlMode;
            // In case of SMART or MANUAL control mode, we have to set the light mode in order to prevent the network mode
            // from changing it.
            if (firstTime || oldControlMode != controlMode) {
                // For the widget we don't want to set any mode
                if (controlMode == 1 /* NETWORK */) {
                    lightData[5] = _networkMode != null && _networkMode < $.networkModes.size()
                        ? $.networkModes[_networkMode]
                        : null;
                }
            }

            initializedLights++;
        }

        _errorCode = errorCode;
        _initializedLights = errorCode == null ? initializedLights : 0;
    }

    protected function setLightMode(lightData, mode, title, force) {
        if (lightData[2] == mode) {
            lightData[5] = title; // updateLight may not be called when setting the same mode
            if (!force) {
                return;
            }
        }

        //System.println("setLightMode=" + mode + " light=" + lightData[0].type + " force=" + force + " timer=" + System.getTimer());
        lightData[7] = mode; // Next mode
        lightData[8] = title; // Next title
        // Do not set a timeout in case we force setting the same mode, as we won't get a light update
        lightData[9] = lightData[2] == mode ? 0 : 5; // Timeout for compute method
        lightData[0].setMode(mode);
    }

    protected function getLightBatteryStatus(lightData) {
        var light = lightData[0];
        var status = light has :getBatteryStatus
            ? light.getBatteryStatus(_lightNetwork)
            : _lightNetwork.getBatteryStatus(light.identifier);
        if (status == null) { /* Disconnected */
            updateLightTextAndMode(lightData, -1);
            return 7; /* Disconnected */
        }

        return status.batteryStatus;
    }

    protected function getLightModes(light) {
        var modes = light.getCapableModes();
        if (modes == null) {
            return [0];
        }

        // LightNetwork supports up to five custom modes, any custom mode beyond the fifth one will be set to NULL.
        // Cycliq lights FLY6 CE and Fly12 CE have the following modes: [0, 1, 2, 3, 6, 7, 63, 62, 61, 60, 59, null]
        // In such case we need to remove the NULL values from the array.
        if (modes.indexOf(null) > -1) {
            modes = modes.slice(0, null);
            modes.removeAll(null);
        }

        return modes;
    }

    protected function setLightProperty(id, lightType, value) {
        Application.Storage.setValue(id + lightType, value);
    }

    (:lightButtons)
    protected function onExternalLightModeChange(lightData, mode) {
        //System.println("onExternalLightModeChange mode=" + mode + " lightType=" + lightData[0].type  + " timer=" + System.getTimer());
        var controlMode = lightData[4];
        if (controlMode == 0 /* SMART */ && lightData[3] == true /* Force smart mode */) {
            return;
        }

        var lightType = lightData[0].type;
        setLightProperty("PCM", lightType, controlMode);
        setLightAndControlMode(lightData, lightType, mode, controlMode != 2 ? 2 /* MANUAL */ : null);
    }

    (:noLightButtons)
    protected function onExternalLightModeChange(lightData, mode) {
        var controlMode = lightData[4];
        lightData[4] = 2; /* MANUAL */
        lightData[5] = null;
        // As onHide is never called, we use the last update time in order to determine whether the data field is currently
        // displayed. In case that the data field is currently not displayed, we assume that the user used either Garmin
        // lights menu or a CIQ application to change the light mode. In such case set the next control mode to manual so
        // that when the data field will be again displayed the manual control mode will be active. In case when the light
        // mode is changed while the data field is displayed (by pressing the button on the light), do not set the next mode
        // so that the user will be able to reset back to smart by moving to a different data screen and then back to the one
        // that contains this data field. In case when the network mode is changed when the data field is not displayed by
        // using Garmin lights menu, network control mode will be active when the data field will be again displayed. As the
        // network mode is not updated when changed until a new instance of the LightNetwork is created, the logic is done in
        // onNetworkStateUpdate method.
        if (System.getTimer() > _lastUpdateTime + 1500) {
            var lightType = lightData[0].type;
            setLightProperty("PCM", lightType, controlMode);
            // Assume that the change was done either by Garmin lights menu or a CIQ application
            setLightProperty("CM", lightType, 2 /* MANUAL */);
            setLightProperty("MM", lightType, mode);
        }
    }

    protected function releaseLights() {
        _initializedLights = 0;
        headlightData[0] = null;
        taillightData[0] = null;
    }

    protected function drawLight(lightData, position, dc, width, fgColor, bgColor) {
    }
    protected function drawBattery(dc, fgColor, x, y, batteryStatus) {
        // Draw the battery shell
        setTextColor(dc, fgColor);
        dc.drawText(x, y, _batteryFont, "B", 1 /* TEXT_JUSTIFY_CENTER */);

        // Do not draw the indicator in case the light is not connected anymore or an invalid status is given
        // The only way to detect whether the light is still connected is to check whether the its battery status is not null
        if (batteryStatus > 6) {
            return;
        }

        // Draw the battery indicator
        var color = batteryStatus == 6 /* BATT_STATUS_CHARGE */ ? fgColor
            : batteryStatus == 5 /* BATT_STATUS_CRITICAL */ ? 0xFF0000 /* COLOR_RED */
            : batteryStatus > 2 /* BATT_STATUS_GOOD */ ? 0xFF5500 /* COLOR_ORANGE */
            : 0x00AA00; /* COLOR_DK_GREEN */
        setTextColor(dc, color);
        dc.drawText(x, y, _batteryFont, batteryStatus.toString(), 1 /* TEXT_JUSTIFY_CENTER */);
    }

    protected function getSecondsOfDay(value) {
        value = value.toNumber();
        return value == null ? null : (value < 0 ? value + 86400 : value) % 86400;
    }

    (:settings)
    protected function validateSettingsLightModes(light) {
        if (light == null) {
            return true; // In case only one light is connected
        }

        var settings = light.type == 0 /* LIGHT_TYPE_HEADLIGHT */ ? headlightSettings : taillightSettings;
        if (settings == null) {
            return true;
        }

        var capableModes = getLightModes(light);
        for (var i = 2; i < settings.size(); i += 2) {
            if (capableModes.indexOf(settings[i]) < 0) {
                _errorCode = 3;
                return false;
            }
        }

        return true;
    }

    protected function recreateLightNetwork() {
        release(false);
        _lightNetwork = _individualNetwork != null
            ? new AntLightNetwork.IndividualLightNetwork(_individualNetwork[0], _individualNetwork[1], _lightNetworkListener)
            : new AntPlus.LightNetwork(_lightNetworkListener);
    }

    // The below source code was ported from: https://www.esrl.noaa.gov/gmd/grad/solcalc/main.js
    // which is used for the NOAA Solar Calculator: https://www.esrl.noaa.gov/gmd/grad/solcalc/
    protected function getSunriseSet(rise, time, position) {
        var month = time.month;
        var year = time.year;
        if (month <= 2) {
            year -= 1;
            month += 12;
        }

        var a = Math.floor(year / 100);
        var b = 2 - a + Math.floor(a / 4);
        var jd = Math.floor(365.25 * (year + 4716)) + Math.floor(30.6001 * (month + 1)) + time.day + b - 1524.5;
        var t = (jd - 2451545.0) / 36525.0;
        var omega = degToRad(125.04 - 1934.136 * t);
        var l1 = 280.46646 + t * (36000.76983 + t * 0.0003032);
        while (l1 > 360.0) {
            l1 -= 360.0;
        }

        while (l1 < 0.0) {
            l1 += 360.0;
        }

        var l0 = degToRad(l1);
        var e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t); // unitless
        var mrad = degToRad(357.52911 + t * (35999.05029 - 0.0001537 * t));
        var ec = degToRad((23.0 + (26.0 + ((21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))) / 60.0)) / 60.0) + 0.00256 * Math.cos(omega));
        var y = Math.tan(ec/2.0);
        y *= y;
        var sinm = Math.sin(mrad);
        var eqTime = (180.0 * (y * Math.sin(2.0 * l0) - 2.0 * e * sinm + 4.0 * e * y * sinm * Math.cos(2.0 * l0) - 0.5 * y * y * Math.sin(4.0 * l0) - 1.25 * e * e * Math.sin(2.0 * mrad)) / 3.141593) * 4.0; // in minutes of time
        var sunEq = sinm * (1.914602 - t * (0.004817 + 0.000014 * t)) + Math.sin(mrad + mrad) * (0.019993 - 0.000101 * t) + Math.sin(mrad + mrad + mrad) * 0.000289; // in degrees
        var latRad = degToRad(position[0].toFloat() /* latitude */);
        var sdRad  = degToRad(180.0 * (Math.asin(Math.sin(ec) * Math.sin(degToRad((l1 + sunEq) - 0.00569 - 0.00478 * Math.sin(omega))))) / 3.141593);
        var hourAngle = Math.acos((Math.cos(degToRad(90.833)) / (Math.cos(latRad) * Math.cos(sdRad)) - Math.tan(latRad) * Math.tan(sdRad))); // in radians (for sunset, use -HA)
        if (!rise) {
            hourAngle = -hourAngle;
        }

        return getSecondsOfDay((720 - (4.0 * (position[1].toFloat() /* longitude */ + (180.0 * hourAngle / 3.141593))) - eqTime) * 60); // timeUTC in seconds
    }

    private function updateLightTextAndMode(lightData, mode) {
        var light = lightData[0];
        if (light == null || lightData[2] == mode) {
            return false;
        }

        var lightType = light.type;
        var lightModes = lightData[14];
        var lightModeCharacter = "";
        if (mode < 0) {
            lightModeCharacter = "X"; // Disconnected
        } else if (mode > 0) {
            var index = lightModes == null
                ? -1
                : ((lightModes >> (4 * ((mode > 9 ? mode - 49 : mode) - 1))) & 0x0F).toNumber() - 1;
            lightModeCharacter = index < 0 || index >= $.lightModeCharacters.size()
                ? "?" /* Unknown */
                : $.lightModeCharacters[index];
        }

        lightData[1] = lightType == (_invertLights ? 2 /* LIGHT_TYPE_TAILLIGHT */ : 0 /* LIGHT_TYPE_HEADLIGHT */) ? lightModeCharacter + ")" : "(" + lightModeCharacter;
        lightData[2] = mode;
        var fitField = lightData[6];
        if (fitField != null) {
            fitField.setData(mode);
        }

        var callback = onLightModeChangeCallback;
        if (callback != null && callback.stillAlive() && callback.get() has :onLightModeChange) {
            callback.get().onLightModeChange(lightType, mode);
        }

        return true;
    }

    (:settings)
    private function getDefaultLightSettings(light) {
        if (light == null) {
            return null;
        }

        var modes = getLightModes(light);
        var data = new [2 * modes.size() + 1];
        var dataIndex = 1;
        data[0] = light.type == 0 /* LIGHT_TYPE_HEADLIGHT */ ? "Headlight" : "Taillight";
        for (var i = 0; i < modes.size(); i++) {
            var mode = modes[i];
            data[dataIndex] = mode == 0 ? "Off" : mode.toString();
            data[dataIndex + 1] = mode;
            dataIndex += 2;
        }

        return data;
    }

    (:noLightButtons)
    private function setupLightButtons(configuration) {
        setupHighMemoryConfiguration(configuration);
    }

    (:settings)
    private function setupLightButtons(configuration) {
        headlightSettings = configuration[9];
        taillightSettings = configuration[10];
        setupHighMemoryConfiguration(configuration);
    }

    private function setupHighMemoryConfiguration(configuration) {
        _individualNetwork = configuration[11];
        if (_individualNetwork != null /* Is enabled */ || _lightNetwork instanceof AntLightNetwork.IndividualLightNetwork) {
            recreateLightNetwork();
        }

        var forceSmartMode = configuration[12];
        if (forceSmartMode != null) {
            headlightData[3] = forceSmartMode[0] == 1;
            taillightData[3] = forceSmartMode[1] == 1;
        }
    }

    (:lightButtons)
    protected function getLightProperty(id, lightType, defaultValue) {
        var key = id + lightType;
        var value = Application.Storage.getValue(key);
        if (value != null && defaultValue == null) {
            Application.Storage.deleteValue(key);
        }

        if (value == null && defaultValue != null) {
            // First application startup
            value = defaultValue;
            Application.Storage.setValue(key, value);
        }

        return value;
    }

    (:noLightButtons)
    protected function getLightProperty(id, lightType, defaultValue) {
        var key = id + lightType;
        var value = Application.Storage.getValue(key);
        if (value != null) {
            Application.Storage.deleteValue(key);
        }

        return value != null ? value : defaultValue;
    }

    (:colorScreen)
    private function setTextColor(dc, color) {
        dc.setColor(color, -1 /* COLOR_TRANSPARENT */);
    }

    (:monochromeScreen)
    private function setTextColor(dc, color) {
        dc.setColor(0x000000, -1 /* COLOR_TRANSPARENT */);
    }

    private function setNetworkMode(lightData, networkMode) {
        lightData[5] = networkMode != null && networkMode < $.networkModes.size()
            ? $.networkModes[networkMode]
            : null;

        //System.println("setNetworkMode=" + networkMode + " light=" + lightData[0].type + " timer=" + System.getTimer());
        if (lightData[0].type == 0 /* LIGHT_TYPE_HEADLIGHT */) {
            _lightNetwork.restoreHeadlightsNetworkModeControl();
        } else {
            _lightNetwork.restoreTaillightsNetworkModeControl();
        }
    }

    // <GlobalFilters>#<HeadlightModes>:<HeadlightSerialNumber>#<HeadlightFilters>#<TaillightModes>:<TaillightSerialNumber>#<TaillightFilters>
    private function parseConfiguration() {
        var currentConfig = getPropertyValue("CC");
        var configKey = currentConfig != null && currentConfig > 1
            ? "LC" + currentConfig
            : "LC";
        var value = getPropertyValue(configKey);
        if (value == null || value.length() == 0) {
            return new [16];
        }

        var filterResult = [0 /* next index */, 0 /* operator type */];
        var chars = value.toCharArray();
        return [
            parseFilters(chars, 0, false, filterResult),       // Global filter
            parseLightInfo(chars, 0, filterResult),            // Headlight light modes
            parseLightInfo(chars, 1, filterResult),            // Headlight serial number
            parseLightInfo(chars, 2, filterResult),            // Headlight icon color
            parseFilters(chars, null, true, filterResult),     // Headlight filters
            parseLightInfo(chars, 0, filterResult),            // Taillight light modes
            parseLightInfo(chars, 1, filterResult),            // Taillight serial number
            parseLightInfo(chars, 2, filterResult),            // Taillight icon color
            parseFilters(chars, null, true, filterResult),     // Taillight filters
            parseLightButtons(chars, null, filterResult),      // Headlight panel/settings buttons
            parseLightButtons(chars, null, filterResult),      // Taillight panel/settings buttons
            parseIndividualNetwork(chars, null, filterResult), // Individual network settings
            parseForceSmartMode(chars, null, filterResult),    // Force smart mode
            null,
        ];
    }

    private function parseIndividualNetwork(chars, i, filterResult) {
        var enabled = parse(1 /* NUMBER */, chars, i, filterResult);
        if (enabled == null) { // Old configuration
            filterResult[0] = filterResult[0] - 1; // Avoid parseForceSmartMode from parsing the next value
            return null;
        } else if (enabled != 1) { // 0::
            filterResult[0] = filterResult[0] + 2;
            return null;
        }

        return [
            parse(1 /* NUMBER */, chars, null, filterResult), // Headlight device number
            parse(1 /* NUMBER */, chars, null, filterResult)  // Taillight device number
        ];
    }

    private function parseForceSmartMode(chars, i, filterResult) {
        var headlightForceSmartMode = parse(1 /* NUMBER */, chars, i, filterResult);
        if (headlightForceSmartMode == null) {
            filterResult[0] = filterResult[0] - 1; // Avoid parseLightsTapBehavior from parsing the next value
            return null;
        }

        return [
            headlightForceSmartMode, // Headlight force smart mode
            parse(1 /* NUMBER */, chars, null, filterResult)  // Taillight force smart mode
        ];
    }

    (:noLightButtons)
    private function parseLightButtons(chars, i, filterResult) {
        filterResult[0] = filterResult[0] + 1;
        return null;
    }

    // <TotalButtons>:<LightName>|[<Button>| ...]
    // <Button> := <ModeTitle>:<LightMode>
    // Example: 6:Ion Pro RT|Off:0|High:1|Medium:2|Low:5|Night Flash:62|Day Flash:63
    (:settings)
    private function parseLightButtons(chars, i, filterResult) {
        var totalButtons = parse(1 /* NUMBER */, chars, i, filterResult);
        if (totalButtons == null || totalButtons > 10) {
            return null;
        }

        // Check whether the configuration string is valid
        i = filterResult[0];
        if (i >= chars.size() || chars[i] != ':') {
            throw new Lang.Exception();
        }

        var data = new [1 + (2 * totalButtons)];
        data[0] = parse(0 /* STRING */, chars, null, filterResult);
        i = filterResult[0];
        var dataIndex = 1;

        for (var j = 0; j < totalButtons; j++) {
            data[dataIndex] = parse(0 /* STRING */, chars, null, filterResult);
            data[dataIndex + 1] = parse(1 /* NUMBER */, chars, null, filterResult);
            dataIndex += 2;
        }

        return data;
    }

    private function parseFilters(chars, i, lightMode, filterResult) {
        filterResult[0] = i == null ? filterResult[0] + 1 : i;
        return null;
    }

    // <LightModes>(:<LightSerialNumber>)*(:<LightIconColor>)*
    private function parseLightInfo(chars, dataType, resultIndex) {
        var index = resultIndex[0];
        if (dataType > 0 && (index >= chars.size() || chars[index] == '#')) {
            return null;
        }

        var left = parse(1 /* NUMBER */, chars, null, resultIndex);
        if (left == null || dataType == 2 /* Icon color */) {
            return left;
        }

        var serial = dataType == 1;
        var result = (left.toLong() << (serial ? 31 : 32)) | parse(1 /* NUMBER */, chars, null, resultIndex); // TODO: Change this to 31 when making a major version change
        return serial
            ? result.toNumber()
            : result;
    }

    private function parse(type, chars, index, resultIndex) {
        index = index == null ? resultIndex[0] + 1 : index;
        var stringValue = null;
        var i;
        var isFloat = false;
        for (i = index; i < chars.size(); i++) {
            var char = chars[i];
            if (stringValue == null && char == ' ') {
                continue; // Trim leading spaces
            }

            if (char == '.') {
                isFloat = true;
            }

            if (char == ':' || char == '|' || char == '!' || (type == 1 /* NUMBER */ && (char == '/' || char > 57 /* 9 */ || char < 45 /* - */))) {
                break;
            }

            stringValue = stringValue == null ? char.toString() : stringValue + char;
        }

        resultIndex[0] = i;
        return stringValue == null || type == 0 ? stringValue
            : isFloat ? stringValue.toFloat()
            : stringValue.toNumber();
    }

    private function degToRad(angleDeg) {
        return 3.141593 * angleDeg / 180.0;
    }
}