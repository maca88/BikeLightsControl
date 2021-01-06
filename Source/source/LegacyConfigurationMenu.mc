using Toybox.WatchUi;
using Toybox.Application.Properties as Properties;

(:touchScreen)
module LegacyConfiguration {

    class ConfigurationMenu extends WatchUi.Menu {

        private var _view;

        function initialize(view, primaryColor, background) {
            Menu.initialize();
            _view = view.weak();
            Menu.setTitle("Configuration");
            Menu.addItem(Rez.Strings[:AC], :AC);
            Menu.addItem(Rez.Strings[:BC], :BC);
        }

        function onSelect(menuItem) {
            var menu = menuItem == :AC ? new PrimaryColorMenu(_view.get(), menuItem) : new BackgroundColorMenu(_view.get(), menuItem);
            WatchUi.pushView(menu, new MenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    class PrimaryColorMenu extends SettingMenu {

        private var _view;

        function initialize(view, key) {
            SettingMenu.initialize(Rez.Strings[key], "AC", colorValues, colorNames);
            _view = view.weak();
        }

        protected function updateValue(value) {
            _view.get().updateActivityColor(value);
        }
    }

    class BackgroundColorMenu extends SettingMenu {

        private var _view;

        function initialize(view, key) {
            SettingMenu.initialize(Rez.Strings[key], "BC", backgroundValues, backgroundNames);
            _view = view.weak();
        }

        protected function updateValue(value) {
            _view.get().updateBackgroundColor(value);
        }
    }

    class SettingMenu extends WatchUi.Menu {

        private var _menuItem;
        private var _key;
        private var _values;
        private var _names;

        function initialize(title, key, values, names) {
            Menu.initialize();
            Menu.setTitle(title);
            _key = key;
            _values = values;
            _names = names;
            var currentValue = Properties.getValue(key);
            for (var i = 0; i < values.size(); i++) {
                var value = values[i];
                var name = names[i];
                Menu.addItem(Rez.Strings[name], name);
            }
        }

        function onSelect(menuItem) {
            var oldValue = Properties.getValue(_key);
            var value = _values[_names.indexOf(menuItem)];
            if (oldValue == value) {
                return;
            }

            // Set new value
            Properties.setValue(_key, value);
            updateValue(value);
        }

        protected function updateValue(value) {
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