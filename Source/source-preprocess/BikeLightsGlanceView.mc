using Toybox.WatchUi;
using Toybox.AntPlus;
using Toybox.Graphics;
using Toybox.Application.Properties as Properties;

(:glance :hasGlance :staticGlance /* #include TARGET */)
class BikeLightsGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(0xFFFFFF /* COLOR_WHITE */, -1 /* COLOR_TRANSPARENT */);
        dc.drawText(width / 2, height / 2, 2, "Bike Lights", 1 /* TEXT_JUSTIFY_CENTER */ | 4 /* TEXT_JUSTIFY_VCENTER */);
    }

    function onSettingsChanged() {
    }

    function release(final) {
    }
}

(:glance :hasGlance :liveGlance /* #include TARGET */)
class BikeLightsGlanceView extends WatchUi.GlanceView {

    // Fonts
    private var _lightsFont;
    private var _batteryFont;

    private var _lightNetwork;
    private var _lightNetworkListener;
    private var _networkState;
    private var _initializedLights = 0;
    private var _individualNetwork;
    private var _errorCode;
    private var _invertLights;

    // Pre-calculated positions
    private var _batteryY;
    private var _lightY;
    private var _offsetX;

    // Light data:
    // 0. BikeLight instance
    // 1. Light text (S])
    // 2. Light modes
    // 3. Serial number
    // 4. Icon color
    private var _headlightData = new [5];
    private var _taillightData = new [5];

    function initialize() {
        GlanceView.initialize();
        _lightsFont = getFont(:lightsFont);
        _batteryFont = getFont(:batteryFont);
        _lightNetworkListener = new BikeLightNetworkListener(self);

        onSettingsChanged();
    }

    function onLayout(dc) {
        var height = dc.getHeight();
        var padding = 3;
        _offsetX = -25;
        var batteryHeight = /* #if highResolution */26/* #else */18/* #endif */;
        var lightHeight = /* #if highResolution */49/* #else */32/* #endif */;
        var totalHeight = batteryHeight + lightHeight + padding;
        var offsetY = (height - totalHeight) / 2;
        _batteryY = height - offsetY - batteryHeight;
        _lightY = _batteryY - padding - lightHeight;
    }

    function onShow() {
        recreateLightNetwork();
    }

    function onHide() {
        release(false);
    }

    function onUpdate(dc) {
        // Needed for TestLightNetwork and IndividualLightNetwork
        if (_lightNetwork != null && _lightNetwork has :update) {
            _errorCode = _lightNetwork.update();
        }

        var deviceSettings = System.getDeviceSettings();
        var bgColor = deviceSettings has :isNightModeEnabled && !deviceSettings.isNightModeEnabled
            ? 0xFFFFFF /* COLOR_WHITE */
            : 0x000000 /* COLOR_BLACK */;
        var fgColor = bgColor == 0x000000 /* COLOR_BLACK */
            ? 0xFFFFFF /* COLOR_WHITE */
            : 0x000000 /* COLOR_BLACK */;
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(fgColor, bgColor);
        dc.clear();
        if (_initializedLights == 0) {
            var text = _individualNetwork ? "Bike Lights" : "No network";
            dc.drawText(width / 2, height / 2, 2, text, 1 /* TEXT_JUSTIFY_CENTER */ | 4 /* TEXT_JUSTIFY_VCENTER */);
            return;
        }

        draw(dc, width, height, fgColor, bgColor);
    }

    function onNetworkStateUpdate(networkState) {
        // Seems like this method can be called after the view was released
        if (_lightNetwork == null) {
            return;
        }

        //System.println("onNetworkStateUpdate=" + networkState);
        if (_initializedLights > 0 && networkState != 2 /* LIGHT_NETWORK_STATE_FORMED */) {
            // Set the mode to disconnected in order to be recorded in case lights recording is enabled
            updateLightTextAndMode(_headlightData, -1);
            updateLightTextAndMode(_taillightData, -1);
            releaseLights();
            WatchUi.requestUpdate();
            return;
        }

        if (_initializedLights > 0 || networkState != 2 /* LIGHT_NETWORK_STATE_FORMED */) {
            return;
        }

        initializeLights();
    }

    function onSettingsChanged() {
        _invertLights = Properties.getValue("IL");
        var currentConfig = Properties.getValue("CC");
        var configKey = currentConfig != null && currentConfig > 1
            ? "LC" + currentConfig
            : "LC";
        var configuration = parseConfiguration(Properties.getValue(configKey));
        var hlData = _headlightData;
        var tlData = _taillightData;

        // configuration[0];  // Headlight modes
        // configuration[1];  // Headlight serial number
        // configuration[2];  // Headlight color
        // configuration[3];  // Taillight modes
        // configuration[4];  // Taillight serial number
        // configuration[5];  // Taillight color
        for (var i = 0; i < 6; i++) {
            var lightData = i < 3 ? hlData : tlData;
            lightData[2 + (i % 3)] = configuration[i];
        }

        _individualNetwork = configuration[6];
        if (_individualNetwork != null) {
            release(false);
            return;
        }

        initializeLights();
    }

    function updateLight(light, mode) {
        var lightType = light.type;
        if (_initializedLights == 0 || (lightType != 0 /* LIGHT_TYPE_HEADLIGHT */ && lightType != 2 /* LIGHT_TYPE_TAILLIGHT */)) {
            return;
        }

        var lightData = getLightData(lightType);
        var oldLight = lightData[0];
        if (oldLight == null || oldLight.identifier != light.identifier) {
            return;
        }

        lightData[0] = light;
        WatchUi.requestUpdate();
    }

    function release(final) {
        releaseLights();
        if (_lightNetwork != null && _lightNetwork has :release) {
            _lightNetwork.release();
        }

        _lightNetwork = null; // Release light network
    }

    private function draw(dc, width, height, fgColor, bgColor) {
        if (_initializedLights == 1) {
            drawLight(getLightData(null), 2, dc, width, fgColor, bgColor);
            return;
        }

        drawLight(_headlightData, 1, dc, width, fgColor, bgColor);
        drawLight(_taillightData, 3, dc, width, fgColor, bgColor);
    }

    private function drawLight(lightData, position, dc, width, fgColor, bgColor) {
        var justification = lightData[0].type;
        if (_invertLights) {
            justification = justification == 0 ? 2 : 0;
            position = position == 1 ? 3
              : position == 3 ? 1
              : position;
        }

        var direction = justification == 0 ? 1 : -1;
        var lightX = Math.round(width * 0.25f * position) + _offsetX;
        lightX += _initializedLights == 2 ? (direction * ((width / 4) - /* #if highResolution */36/* #else */25/* #endif */)) : 0;
        var batteryStatus = getLightBatteryStatus(lightData);
        var lightXOffset = justification == 0 ? -4 : 2;

        var iconColor = lightData[4];
        if (iconColor != null && iconColor != 1 /* Black/White */) {
            dc.setColor(iconColor, -1 /* COLOR_TRANSPARENT */);
        } else {
            dc.setColor(fgColor, bgColor);
        }

        dc.drawText(lightX + (direction * (/* #if highResolution */68/* #else */49/* #endif */ /* _batteryWidth *// 2)) + lightXOffset, _lightY, _lightsFont, lightData[1], justification);
        drawBattery(dc, fgColor, lightX, _batteryY, batteryStatus);
    }

    private function drawBattery(dc, fgColor, x, y, batteryStatus) {
        // Draw the battery shell
        dc.setColor(fgColor, -1 /* COLOR_TRANSPARENT */);
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
        dc.setColor(color, -1 /* COLOR_TRANSPARENT */);
        dc.drawText(x, y, _batteryFont, batteryStatus.toString(), 1 /* TEXT_JUSTIFY_CENTER */);
    }

    private function initializeLights() {
        releaseLights();
        var lightNetwork = _lightNetwork;
        var lights = lightNetwork != null ? lightNetwork.getBikeLights() : null;
        if (lights == null) {
            return;
        }

        var initializedLights = 0;
        var hasSerialNumber = _headlightData[3] != null || _taillightData[3] != null;
        for (var i = 0; i < lights.size(); i++) {
            var light = lights[i];
            var lightType = light != null ? light.type : 7;
            if (lightType != 0 && lightType != 2) {
                break;
            }

            var lightData = getLightData(lightType);
            var serial = lightData[3];
            if ((hasSerialNumber && lightData[2] /* Light modes */ == null) ||
                (hasSerialNumber && serial != null && serial != lightNetwork.getProductInfo(light.identifier).serial)) {
                continue;
            }

            if (lightData[0] != null) {
                continue;
            }

            lightData[0] = light;
            updateLightTextAndMode(lightData, light.mode);
            initializedLights++;
        }

        _initializedLights = initializedLights;
        WatchUi.requestUpdate();
    }

    private function getLightBatteryStatus(lightData) {
        var status = _lightNetwork.getBatteryStatus(lightData[0].identifier);
        if (status == null) { /* Disconnected */
            updateLightTextAndMode(lightData, -1);
            return 6;
        }

        return status.batteryStatus;
    }

    private function updateLightTextAndMode(lightData, mode) {
        var light = lightData[0];
        if (light == null) {
            return;
        }

        var lightType = light.type;
        var lightModes = lightData[2];
        var lightModeCharacter = "";
        if (mode < 0) {
            lightModeCharacter = "X";
        } else if (mode > 0) {
            var index = lightModes == null
                ? -1
                : ((lightModes >> (4 * ((mode > 9 ? mode - 49 : mode) - 1))) & 0x0F).toNumber() - 1;
            lightModeCharacter = index < 0 || index >= $.lightModeCharacters.size()
                ? "?" /* Unknown */
                : $.lightModeCharacters[index];
        }

        lightData[1] = lightType == (_invertLights ? 2 /* LIGHT_TYPE_TAILLIGHT */ : 0 /* LIGHT_TYPE_HEADLIGHT */) ? lightModeCharacter + ")" : "(" + lightModeCharacter;
    }

    private function releaseLights() {
        _initializedLights = 0;
        _headlightData[0] = null;
        _taillightData[0] = null;
    }

    private function getLightData(lightType) {
        return lightType == null
            ? _headlightData[0] != null ? _headlightData : _taillightData
            : lightType == 0 ? _headlightData : _taillightData;
    }

    private function getFont(key) {
        return WatchUi.loadResource(Rez.Fonts[key]);
    }

    // <GlobalFilters>#<HeadlightModes>#<HeadlightFilters>#<TaillightModes>#<TaillightFilters>
    private function parseConfiguration(value) {
        if (value == null || value.length() == 0) {
            return new [7];
        }

        var indexResult = [0 /* next index */];
        var chars = value.toCharArray();
        return [
            parseLightInfo(chars, 0, indexResult), // Headlight light modes
            parseLightInfo(chars, 1, indexResult), // Headlight serial number
            parseLightInfo(chars, 2, indexResult), // Headlight icon color
            parseLightInfo(chars, 0, indexResult), // Taillight light modes
            parseLightInfo(chars, 1, indexResult), // Taillight serial number
            parseLightInfo(chars, 2, indexResult), // Taillight icon color
            parseIndividualNetwork(chars, indexResult[0], indexResult),
        ];
    }

    private function recreateLightNetwork() {
        release(false);
        _lightNetwork = _individualNetwork != null
            ? null
            : new /* #include ANT_NETWORK */(_lightNetworkListener);
    }

    private function parseLightInfo(chars, dataType, indexResult) {
        var index = indexResult[0];
        if (index < 0 || (dataType == 0 && chars[index] != '#')) {
            indexResult[0] = -1;
            return null;
        }

        var value = null;
        if (dataType == 0 || chars[index] != '#') {
            value = parse(1 /* NUMBER */, chars, null, indexResult);
        }

        if (dataType == 2 /* Icon color */) {
            indexResult[0] = indexResult[0] + 1; // Skip filters
        }

        if (value == null || dataType == 2  /* Icon color */) {
            return value;
        }

        var serial = dataType == 1;
        var result = (value.toLong() << (serial ? 31 : 32)) | parse(1 /* NUMBER */, chars, null, indexResult); // TODO: Change this to 31 when making a major version change
        return serial
            ? result.toNumber()
            : result;
    }

    private function parseIndividualNetwork(chars, i, indexResult) {
        if (i < 0 || chars[i] != '#') {
            indexResult[0] = -1;
            return null;
        }

        var toSkip = 3;
        while (toSkip > 0 && i < chars.size()) {
            if (chars[i] == '#') {
                toSkip--;
            }

            i++;
        }

        if (toSkip > 0) {
            return null;
        }

        if (parse(1 /* NUMBER */, chars, i, indexResult) != 1) {
            return null;
        }

        return [
            parse(1 /* NUMBER */, chars, indexResult[0] + 1, indexResult), // Headlight device number
            parse(1 /* NUMBER */, chars, indexResult[0] + 1, indexResult)  // Taillight device number
        ];
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
}