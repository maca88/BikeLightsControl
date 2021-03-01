using Toybox.WatchUi;
using Toybox.AntPlus;
using Toybox.Graphics;
using Toybox.Application.Properties as Properties;

(:glance)
class BikeLightsGlanceView extends WatchUi.GlanceView {

    // Fonts
    private var _lightsFont;
    private var _batteryFont;

    private var _lightNetwork;
    private var _lightNetworkListener;
    private var _networkState;
    private var _initializedLights = 0;

    // Pre-calculated positions
    private var _batteryY;
    private var _lightY;
    private var _offsetX;
    private var _fgColor = 0xFFFFFF /* COLOR_WHITE */;
    private var _batteryWidth = 49;

    private var _primaryLightData = new [3];
    private var _secondaryLightData = new [3];

    function initialize() {
        GlanceView.initialize();
        _lightsFont = getFont(:lightsFont);
        _batteryFont = getFont(:batteryFont);
        _lightNetworkListener = new BikeLightNetworkListener(self);

        setupNetwork();
        parseConfiguration();
    }

    // <GlobalFilters>#<HeadlightModes>#<HeadlightFilters>#<TaillightModes>#<TaillightFilters>
    private function parseConfiguration() {
        var value = Properties.getValue("LC");
        var indexResult = [0 /* next index */];
        var headlightModes = parseLightModes(value, indexResult);
        indexResult[0]++;
        value = value.substring(indexResult[0], value.length() - 1);
        var taillightModes = parseLightModes(value, indexResult);

        _primaryLightData[2] = headlightModes != null ? headlightModes : taillightModes;
        _secondaryLightData[2] = headlightModes != null ? taillightModes : null;
    }

    private function parseLightModes(value, indexResult) {
        if (value == null || value.length() == 0) {
            return null;
        }

        var index = value.find("#");
        if (index == null) {
            return null;
        }

        indexResult[0] = index + 1;
        var chars = value.toCharArray();
        return parseLong(chars, indexResult[0], indexResult);
    }

    function onLayout(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var padding = 3;
        _offsetX = -25;
        _batteryY = height - 19 - padding;
        _lightY = _batteryY - padding - 32 /* Lights font size */;
    }

    function onUpdate(dc) {
        // NOTE: Use only for testing purposes when using TestLightNetwork
        //if (_lightNetwork != null && _lightNetwork has :update) {
        //    _lightNetwork.update();
        //}

        var width = dc.getWidth();
        var height = dc.getHeight();
        setTextColor(dc, _fgColor);

        if (_initializedLights == 0) {
            dc.drawText(width / 2, height / 2, 2, "No network", 1 /* TEXT_JUSTIFY_CENTER */ | 4 /* TEXT_JUSTIFY_VCENTER */);
            return;
        }

        draw(dc, width, height, _fgColor, 0x000000 /* COLOR_BLACK */);
    }

    function onNetworkStateUpdate(networkState) {
        if (_initializedLights > 0 && networkState != 2 /* LIGHT_NETWORK_STATE_FORMED */) {
            releaseLights();
            WatchUi.requestUpdate();
            return;
        }

        var lights = _lightNetwork.getBikeLights();
        if (_initializedLights > 0 || networkState != 2 /* LIGHT_NETWORK_STATE_FORMED */ || lights == null) {
            return;
        }

        var totalLights = lights.size();
        for (var i = 0; i < totalLights; i++) {
            var light = lights[i];
            if (light == null) {
                return;
            }

            var lightType = light.type;
            if (lightType != 0 && lightType != 2) {
                return;
            }

            var lightData = lightType == 0 /* LIGHT_TYPE_HEADLIGHT */ || totalLights == 1
                ? _primaryLightData
                : _secondaryLightData;
            if (lightData[0] != null) {
                return;
            }

            lightData[0] = light;
            updateLightTextAndMode(lightData, light.mode);
        }

        _initializedLights = totalLights;
        WatchUi.requestUpdate();
    }

    function updateLight(light, mode) {
        var lightType = light.type;
        if (_initializedLights == 0 || (lightType != 0 /* LIGHT_TYPE_HEADLIGHT */ && lightType != 2 /* LIGHT_TYPE_TAILLIGHT */)) {
            return;
        }

        var lightData = _initializedLights == 1 || lightType == 0 /* LIGHT_TYPE_HEADLIGHT */
            ? _primaryLightData
            : _secondaryLightData;
        lightData[0] = light;

        WatchUi.requestUpdate();
    }

    private function draw(dc, width, height, fgColor, bgColor) {
        if (_initializedLights == 1) {
            drawLight(_primaryLightData, 2, dc, width, fgColor, bgColor);
            return;
        }

        drawLight(_primaryLightData, 1, dc, width, fgColor, bgColor);
        drawLight(_secondaryLightData, 3, dc, width, fgColor, bgColor);
    }

    private function drawLight(lightData, position, dc, width, fgColor, bgColor) {
        var justification = lightData[0].type;
        var direction = justification == 0 ? 1 : -1;
        var lightX = Math.round(width * 0.25f * position) + _offsetX;
        lightX += _initializedLights == 2 ? (direction * ((width / 4) - 25)) : 0;
        var batteryStatus = getLightBatteryStatus(lightData);
        var lightXOffset = justification == 0 ? -4 : 2;

        dc.setColor(fgColor, bgColor);
        dc.drawText(lightX + (direction * (_batteryWidth / 2)) + lightXOffset, _lightY, _lightsFont, lightData[1], justification);
        drawBattery(dc, fgColor, lightX, _batteryY, batteryStatus);
    }

    private function drawBattery(dc, fgColor, x, y, batteryStatus) {
        // Draw the battery shell
        setTextColor(dc, fgColor);
        dc.drawText(x, y, _batteryFont, "B", 1 /* TEXT_JUSTIFY_CENTER */);

        // Do not draw the indicator in case the light is not connected anymore or an invalid status is given
        // The only way to detect whether the light is still connected is to check whether the its battery status is not null
        if (batteryStatus > 5) {
            return;
        }

        // Draw the battery indicator
        var color = batteryStatus == 5 /* BATT_STATUS_CRITICAL */ ? 0xFF0000 /* COLOR_RED */
            : batteryStatus > 2 /* BATT_STATUS_GOOD */ ? 0xFF5500 /* COLOR_ORANGE */
            : 0x00AA00; /* COLOR_DK_GREEN */
        setTextColor(dc, color);
        dc.drawText(x, y, _batteryFont, batteryStatus.toString(), 1 /* TEXT_JUSTIFY_CENTER */);
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
        lightData[1] = getLightText(lightData[0].type, mode, lightData[2]);
    }

    private function releaseLights() {
        _initializedLights = 0;
        _primaryLightData[0] = null;
        _secondaryLightData[0] = null;
    }

    private function setTextColor(dc, color) {
        dc.setColor(color, -1 /* COLOR_TRANSPARENT */);
    }

    private function getLightText(lightType, mode, lightModes) {
        var lightModeCharacter = null;
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

        return lightType == 0 /* LIGHT_TYPE_HEADLIGHT */
            ? lightModeCharacter == null ? ">" : lightModeCharacter + ">"
            : lightModeCharacter == null ? "<" : "<" + lightModeCharacter;
    }

    (:testNetwork)
    private function setupNetwork() {
        _lightNetwork = new TestNetwork.TestLightNetwork(_lightNetworkListener);
    }

    (:deviceNetwork)
    private function setupNetwork() {
        _lightNetwork = new AntPlus.LightNetwork(_lightNetworkListener);
    }

    private function getFont(key) {
        return WatchUi.loadResource(Rez.Fonts[key]);
    }

    private function parseLong(chars, index, resultIndex) {
        var left = parse(1 /* NUMBER */, chars, index, resultIndex);
        if (left == null) {
            return null;
        }

        var right = parse(1 /* NUMBER */, chars, resultIndex[0] + 1, resultIndex);
        return (left.toLong() << 32) | right;
    }

    private function parse(type, chars, index, resultIndex) {
        var stringValue = null;
        var i;
        var isFloat = false;
        for (i = index; i < chars.size(); i++) {
            var char = chars[i];
            if (char == '.') {
                isFloat = true;
            }

            if (char == ':' || char == '|' || (type == 1 /* NUMBER */ && (char == '/' || char > 57 /* 9 */ || char < 45 /* - */))) {
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