using Toybox.WatchUi;
using Toybox.Application.Properties as Properties;

(:touchScreen) const colorValues = [16711680, 11141120, 16733440, 16755200, 65280, 43520, 43775, 255, 11141375, 16711935];
(:touchScreen) const colorNames = [:Red, :DarkRed, :Orange, :Yellow, :Green, :DarkGreen, :Blue, :DarkBlue, :Purple, :Pink];

(:touchScreen) const backgroundValues = [0, 16777215, 1];
(:touchScreen) const backgroundNames = [:Black, :White, :Auto];

(:touchScreen) const configurationValues = [1, 2, 3];
(:touchScreen) const configurationNames = [:Primary, :Secondary, :Tertiary];
(:touchScreen) const configurationNameValues = ["CN1", "CN2", "CN3"];

(:touchScreen) const settingValues = ["AC", "BC", "CC"];

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
            // Current configuration
            var configurationIndex = configurationValues.indexOf((Properties.getValue("CC")));
            Menu2.addItem(new WatchUi.MenuItem(Rez.Strings[:CC], (configurationIndex < 0 ? null : Properties.getValue(configurationNameValues[configurationIndex])), 2, null));
        }

        function onSelect(index, menuItem) {
            var key = settingValues[index];
            var menu = index == 0 ? new PrimaryColorMenu(_view.get(), key, menuItem)
                : index == 1 ? new BackgroundColorMenu(_view.get(), key, menuItem)
                : new CurrentConfigurationMenu(_view.get(), key, menuItem);
            WatchUi.pushView(menu, new MenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    class PrimaryColorMenu extends SettingMenu {

        private var _view;

        function initialize(view, key, menuItem) {
            SettingMenu.initialize(Rez.Strings[:AC], key, menuItem, colorValues, colorNames, null);
            _view = view.weak();
        }

        protected function updateValue(value) {
            _view.get().updateActivityColor(value);
        }
    }

    class BackgroundColorMenu extends SettingMenu {

        private var _view;

        function initialize(view, key, menuItem) {
            SettingMenu.initialize(Rez.Strings[:BC], key, menuItem, backgroundValues, backgroundNames, null);
            _view = view.weak();
        }

        protected function updateValue(value) {
            _view.get().updateBackgroundColor(value);
        }
    }

    class CurrentConfigurationMenu extends SettingMenu {

        private var _view;

        function initialize(view, key, menuItem) {
            SettingMenu.initialize(Rez.Strings[:CC], key, menuItem, configurationValues, configurationNames, configurationNameValues);
            _view = view.weak();
        }

        protected function updateValue(value) {
            Application.getApp().onSettingsChanged();
        }
    }

    class SettingMenu extends WatchUi.Menu2 {

        private var _menuItem;
        private var _key;
        private var _values;
        private var _names;
        private var _nameKeys;

        function initialize(title, key, menuItem, values, names, nameKeys) {
            Menu2.initialize(null);
            Menu2.setTitle(title);
            _key = key;
            _menuItem = menuItem.weak();
            _values = values;
            _names = names;
            _nameKeys = nameKeys;
            for (var i = 0; i < values.size(); i++) {
                var value = values[i];
                var name = nameKeys != null ? Properties.getValue(nameKeys[i]) : null;
                name = name == null ? Rez.Strings[names[i]] : name;
                Menu2.addItem(new WatchUi.MenuItem(name, null, value, null));
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
                var name = _nameKeys != null ? Properties.getValue(_nameKeys[index]) : null;
                name = name == null ? Rez.Strings[_names[index]] : name;
                _menuItem.get().setSubLabel(name);
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