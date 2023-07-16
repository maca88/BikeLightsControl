using Toybox;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Application.Properties as Properties;

(:settings)
module AppSettings {

    const colorValues = [16711680, 11141120, 16733440, 16755200, 65280, 43520, 43775, 255, 11141375, 16711935];
    const colorNames = [:Red, :DarkRed, :Orange, :Yellow, :Green, :DarkGreen, :Blue, :DarkBlue, :Purple, :Pink];
    const configurationNames = [:Primary, :Secondary, :Tertiary];
    const configurationNameValues = ["CN1", "CN2", "CN3"];
    const configurationValues = [1, 2, 3];
    const settingValues = ["IL", "AC", "CC"];
    class BaseMenu extends WatchUi.Menu2 {
        protected var viewRef;

        public function initialize(view) {
            Menu2.initialize(null);
            viewRef = view != null ? view.weak() : null;
        }

        public function close() {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }

        public function openSubMenu(menu) {
            WatchUi.pushView(menu, new MenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    class Menu extends BaseMenu {

        public function initialize(view) {
            BaseMenu.initialize(view);

            Menu2.setTitle("Settings");
            // Invert lights
            Menu2.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.IL, null, 0, Properties.getValue("IL"), null));
            // Activity color
            var colorIndex = colorValues.indexOf(Properties.getValue("AC"));
            Menu2.addItem(new WatchUi.MenuItem(Rez.Strings.AC, (colorIndex < 0 ? null : Rez.Strings[colorNames[colorIndex]]), 1, null));
            // Current configuration
            var configurationIndex = configurationValues.indexOf((Properties.getValue("CC")));
            Menu2.addItem(new WatchUi.MenuItem(Rez.Strings.CC, (configurationIndex < 0 ? null : Properties.getValue(configurationNameValues[configurationIndex])), 2, null));
        }

        public function onSelect(index, menuItem) {
            var key = index < settingValues.size() ? settingValues[index] : null;
            if (index == 0) {
                var newValue = !Properties.getValue(key); // Toggle invert lights
                menuItem.setEnabled(newValue);
                Properties.setValue(key, newValue);
                Application.getApp().onSettingsChanged();
            } else {
                openSubMenu(index == 1
                    ? new ListMenu("Color", key, menuItem, colorValues, colorNames, null)
                    : new ListMenu("Configuration", key, menuItem, configurationValues, configurationNames, configurationNameValues));
            }
        }
    }

    class ListMenu extends BaseMenu {

        private var _menuItem;
        private var _key;
        private var _values;
        private var _names;
        private var _nameKeys;

        public function initialize(title, key, menuItem, values, names, nameKeys) {
            BaseMenu.initialize(null);
            Menu2.setTitle(title);
            _key = key;
            _menuItem = menuItem.weak();
            _values = values;
            _names = names;
            _nameKeys = nameKeys;
            for (var i = 0; i < values.size(); i++) {
                var value = values[i];
                var name = nameKeys != null ? Properties.getValue(nameKeys[i]) : null;
                if (name == null) {
                    name = names[i];
                    name = name instanceof String ? name : Rez.Strings[name];
                }

                Menu.addItem(new WatchUi.MenuItem(name, null, value, null));
            }
        }

        public function onSelect(newValue, menuItem) {
            var oldValue = Properties.getValue(_key);
            if (oldValue == newValue) {
                close();
                return;
            }

            // Set new value
            Properties.setValue(_key, newValue);
            Application.getApp().onSettingsChanged();
            // Set parent sub label
            var index = _values.indexOf(newValue);
            if (_menuItem.stillAlive() && index >= 0) {
                var name = _nameKeys != null ? Properties.getValue(_nameKeys[index]) : null;
                if (name == null) {
                    name = _names[index];
                    name = name instanceof String ? name : Rez.Strings[name];
                }

                _menuItem.get().setSubLabel(name);
            }

            close();
        }
    }
}