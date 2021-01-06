using Toybox.WatchUi;
using Toybox.Application.Properties as Properties;

(:touchScreen) const colorValues = [16711680, 11141120, 16733440, 16755200, 65280, 43520, 43775, 255, 11141375, 16711935];
(:touchScreen) const colorNames = [:Red, :DarkRed, :Orange, :Yellow, :Green, :DarkGreen, :Blue, :DarkBlue, :Purple, :Pink];

(:touchScreen) const backgroundValues = [0, 16777215, 1];
(:touchScreen) const backgroundNames = [:Black, :White, :Auto];

(:touchScreen) const settingValues = ["AC", "BC"];

(:touchScreen)
module Configuration {

    class ConfigurationMenu extends WatchUi.Menu2 {

        private var _view;

        function initialize(view, primaryColor, background) {
            Menu2.initialize(null);
            _view = view.weak();
            Menu2.setTitle("Configuration");
            var colorIndex = colorValues.indexOf(primaryColor);
            var backgroundIndex = backgroundValues.indexOf(background);
            Menu2.addItem(new WatchUi.MenuItem(Rez.Strings[:AC], colorIndex < 0 ? null : Rez.Strings[colorNames[colorIndex]], 0, null));
            Menu2.addItem(new WatchUi.MenuItem(Rez.Strings[:BC], backgroundIndex < 0 ? null : Rez.Strings[backgroundNames[backgroundIndex]], 1, null));
        }

        function onSelect(index, menuItem) {
            var key = settingValues[index];
            var menu = index == 0 ? new PrimaryColorMenu(_view.get(), key, menuItem) : new BackgroundColorMenu(_view.get(), key, menuItem);
            WatchUi.pushView(menu, new MenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    class PrimaryColorMenu extends SettingMenu {

        private var _view;

        function initialize(view, key, menuItem) {
            SettingMenu.initialize(Rez.Strings[:AC], key, menuItem, colorValues, colorNames);
            _view = view.weak();
        }

        protected function updateValue(value) {
            _view.get().updateActivityColor(value);
        }
    }

    class BackgroundColorMenu extends SettingMenu {

        private var _view;

        function initialize(view, key, menuItem) {
            SettingMenu.initialize(Rez.Strings[:BC], key, menuItem, backgroundValues, backgroundNames);
            _view = view.weak();
        }

        protected function updateValue(value) {
            _view.get().updateBackgroundColor(value);
        }
    }

    class SettingMenu extends WatchUi.Menu2 {

        private var _menuItem;
        private var _key;
        private var _values;
        private var _names;

        function initialize(title, key, menuItem, values, names) {
            Menu2.initialize(null);
            Menu2.setTitle(title);
            _key = key;
            _menuItem = menuItem.weak();
            _values = values;
            _names = names;
            var currentValue = Properties.getValue(key);
            for (var i = 0; i < values.size(); i++) {
                var value = values[i];
                var name = names[i];
                Menu2.addItem(new WatchUi.MenuItem(Rez.Strings[name], null, value, null));
            }
        }

        function onSelect(value, menuItem) {
            var oldValue = Properties.getValue(_key);
            if (oldValue == value) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                return;
            }

            // Set new value
            Properties.setValue(_key, value);
            updateValue(value);
            // Set parent sub label
            var index = _values.indexOf(value);
            if (_menuItem.stillAlive() && index >= 0) {
                _menuItem.get().setSubLabel(Rez.Strings[_names[index]]);
            }

            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }

        protected function updateValue(value) {
        }
    }

    class MenuDelegate extends WatchUi.Menu2InputDelegate {

        private var _menu;

        function initialize(menu) {
            Menu2InputDelegate.initialize();
            _menu = menu.weak();
        }

        function onSelect(menuItem) {
            if (_menu.stillAlive()) {
                _menu.get().onSelect(menuItem.getId(), menuItem);
            }
        }

        function onBack() {
            _menu = null;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return false;
        }
    }
}