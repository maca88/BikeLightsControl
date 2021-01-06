using Toybox.WatchUi;

(:settings)
module LegacySettings {
    const controlModeNames = [
        "Smart (S)",
        "Network (N)",
        "Manual (M)"
    ];
    
    const controlModeSymbols = [
        :Smart,
        :Network,
        :Manual
    ];

    const lightModes = [
        :Off,
        :Steady100,
        :Steady80,
        :Steady60,
        :Steady40,
        :Steady20,
        :SlowFlash,
        :FastFlash,
        :RandomFlash,
        :Auto,
        :Custom5,
        :Custom4,
        :Custom3,
        :Custom2,
        :Custom1
    ];

    function getLightData(lightType, view) {
        return view.headlightData[0].type == lightType ? view.headlightData : view.taillightData;
    }

    class LightsMenu extends WatchUi.Menu {

        private var _view;

        function initialize(view) {
            Menu.initialize();
            Menu.setTitle("Lights");
            Menu.addItem(view.headlightSettings[0], :Headlight);
            Menu.addItem(view.taillightSettings[0], :Taillight);
            _view = view.weak();
        }

        function onSelect(menuItem) {
            var lightType = menuItem == :Headlight ? 0 : 2;
            var menu = new LightMenu(lightType, _view.get());
            WatchUi.pushView(menu, new MenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    class LightMenu extends WatchUi.Menu {

        private var _view;
        private var _lightType;

        function initialize(lightType, view) {
            Menu.initialize();
            Menu.setTitle(lightType == 0 /* LIGHT_TYPE_HEADLIGHT */ ? view.headlightSettings[0] : view.taillightSettings[0]);
            Menu.addItem("Control mode", :ControlMode);
            Menu.addItem("Light modes", :LightModes);
            _lightType = lightType;
            _view = view.weak();
        }

        function onSelect(menuItem) {
            var view = _view.get();
            var menu = menuItem == :ControlMode ? new LightControlModeMenu(_lightType, view) : new LightModesMenu(_lightType, view);
            WatchUi.pushView(menu, new MenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    class LightControlModeMenu extends WatchUi.Menu {

        private var _view;
        private var _lightType;

        function initialize(lightType, view) {
            Menu.initialize();
            Menu.setTitle("Control mode");
            _lightType = lightType;
            _view = view.weak();
            var lightData = getLightData(lightType, view);
            for (var i = 0; i < controlModeNames.size(); i++) {
                if (i == 0 && view has :updateUi) {
                    continue; // Do not show smart mode for the widget
                }

                Menu.addItem(controlModeNames[i], controlModeSymbols[i]);
            }
        }

        function onSelect(menuItem) {
            var lightData = getLightData(_lightType, _view.get());
            var oldControlMode = lightData[4];
            var controlMode = controlModeSymbols.indexOf(menuItem);
            if (controlMode < 0 || oldControlMode == controlMode) {
                return;
            }

            var newMode = controlMode == 2 /* MANUAL */ ? lightData[2] : null;
            _view.get().setLightAndControlMode(lightData, _lightType, newMode, controlMode);
        }
    }

    class LightModesMenu extends WatchUi.Menu {

        private var _view;
        private var _lightType;

        function initialize(lightType, view) {
            Menu.initialize();
            Menu.setTitle("Light modes");
            _lightType = lightType;
            _view = view.weak();
            var lightData = getLightData(lightType, view);
            var lightSettings = lightType == 0 /* LIGHT_TYPE_HEADLIGHT */ ? view.headlightSettings : view.taillightSettings;
            for (var i = 1; i < lightSettings.size(); i += 2) {
                var mode = lightSettings[i + 1];
                var symbol = lightModes[mode > 9 ? mode - 49 : mode];
                Menu.addItem(lightSettings[i], symbol);
            }
        }

        function onSelect(menuItem) {
            var lightData = getLightData(_lightType, _view.get());
            var mode = lightModes.indexOf(menuItem);
            if (mode > 9) {
                mode += 49;
            }

            // Set light mode
            var newControlMode = lightData[4] != 2 /* MANUAL */ ? 2 : null;
            _view.get().setLightAndControlMode(lightData, _lightType, mode, newControlMode);
        }
    }

    class MenuDelegate extends WatchUi.MenuInputDelegate {

        private var _menu;

        function initialize(menu) {
            MenuInputDelegate.initialize();
            _menu = menu.weak();
        }
    
        function onMenuItem(menuItem) {
            if (_menu.stillAlive()) {
                _menu.get().onSelect(menuItem);
            }
        }
    }
}