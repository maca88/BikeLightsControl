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

    class BaseMenu extends WatchUi.Menu {
        protected var context;
        protected var viewRef;
        protected var subMenu;
        public var closed = false;

        function initialize(view, context) {
            Menu.initialize();
            viewRef = view.weak();
            self.context = context;
        }

        function isContextValid() {
            var view = viewRef.get();
            return context[0] == view.headlightSettings &&
                context[1] == view.taillightSettings &&
                view.getLightData(null)[0] != null; // The network was disconnected
        }

        function close() {
            if (closed) {
                return;
            }

            if (subMenu != null) {
                subMenu.close();
                subMenu = null;
            }

            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            closed = true;
        }

        function openSubMenu(menu) {
            subMenu = menu;
            WatchUi.pushView(menu, new MenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    class LightsMenu extends BaseMenu {

        function initialize(view, context) {
            BaseMenu.initialize(view, context);
            setTitle("Lights");
            addItem(view.headlightSettings[0], :Headlight);
            addItem(view.taillightSettings[0], :Taillight);
        }

        function onSelect(menuItem) {
            var lightType = menuItem == :Headlight ? 0 : 2;
            openSubMenu(new LightMenu(lightType, viewRef.get(), context));
            return true;
        }
    }

    class LightMenu extends BaseMenu {

        private var _lightType;

        function initialize(lightType, view, context) {
            BaseMenu.initialize(view, context);
            setTitle(lightType == 0 /* LIGHT_TYPE_HEADLIGHT */ ? view.headlightSettings[0] : view.taillightSettings[0]);
            addItem("Control mode", :ControlMode);
            addItem("Light modes", :LightModes);
            _lightType = lightType;
        }

        function onSelect(menuItem) {
            var view = viewRef.get();
            var menu = menuItem == :ControlMode ? new LightControlModeMenu(_lightType, view, context) : new LightModesMenu(_lightType, view, context);
            openSubMenu(menu);
            return true;
        }
    }

    class LightControlModeMenu extends BaseMenu {

        private var _lightType;

        function initialize(lightType, view, context) {
            BaseMenu.initialize(view, context);
            setTitle("Control mode");
            _lightType = lightType;
            for (var i = 0; i < controlModeNames.size(); i++) {
                if (i == 0 && view has :updateUi) {
                    continue; // Do not show smart mode for the widget
                }

                addItem(controlModeNames[i], controlModeSymbols[i]);
            }
        }

        function onSelect(menuItem) {
            var view = viewRef.get();
            var lightData = view.getLightData(_lightType);
            var oldControlMode = lightData[4];
            var controlMode = controlModeSymbols.indexOf(menuItem);
            if (controlMode < 0 || oldControlMode == controlMode) {
                return false;
            }

            var newMode = controlMode == 2 /* MANUAL */ ? lightData[2] : null;
            view.setLightAndControlMode(lightData, _lightType, newMode, controlMode);
            return false;
        }
    }

    class LightModesMenu extends BaseMenu {

        private var _lightType;

        function initialize(lightType, view, context) {
            BaseMenu.initialize(view, context);
            setTitle("Light modes");
            _lightType = lightType;
            var lightSettings = lightType == 0 /* LIGHT_TYPE_HEADLIGHT */ ? view.headlightSettings : view.taillightSettings;
            for (var i = 1; i < lightSettings.size(); i += 2) {
                var mode = lightSettings[i + 1];
                var symbol = lightModes[mode > 9 ? mode - 49 : mode];
                addItem(lightSettings[i], symbol);
            }
        }

        function onSelect(menuItem) {
            var view = viewRef.get();
            var lightData = view.getLightData(_lightType);
            var mode = lightModes.indexOf(menuItem);
            if (mode > 9) {
                mode += 49;
            }

            // Set light mode
            var newControlMode = lightData[4] != 2 /* MANUAL */ ? 2 : null;
            view.setLightAndControlMode(lightData, _lightType, mode, newControlMode);
            return false;
        }
    }

    class MenuDelegate extends WatchUi.MenuInputDelegate {

        private var _menu;

        function initialize(menu) {
            MenuInputDelegate.initialize();
            _menu = menu.weak();
        }

        function onMenuItem(menuItem) {
            if (!_menu.stillAlive()) {
                return;
            }

            var menu = _menu.get();
            // In case the settings were changed or the menu will not open a submenu, the menu will be closed
            if (!menu.isContextValid() || !menu.onSelect(menuItem)) {
                menu.closed = true;
            }
        }
    }
}