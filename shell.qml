//@ pragma UseQApplication
//@ pragma ShellId ambxst
//@ pragma DataDir $BASE/ambxst
//@ pragma StateDir $BASE/ambxst

import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules/tools"
import qs.config
import qs.modules.bar
import qs.modules.bar.workspaces
import qs.modules.components
import qs.modules.corners
import qs.modules.desktop
import qs.modules.dock
import qs.modules.frame
import qs.modules.globals
import qs.modules.lockscreen
import qs.modules.notch
import qs.modules.notifications
import qs.modules.services
import qs.modules.shell
import qs.modules.shell.osd
import qs.modules.widgets.dashboard.wallpapers
import qs.modules.widgets.displayselect
import qs.modules.widgets.overview
import qs.modules.widgets.presets

ShellRoot {
    id: root

    ContextMenu {
        id: contextMenu

        screen: Quickshell.screens[0]
        Component.onCompleted: Visibilities.setContextMenu(contextMenu)
    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: wallpaperLoader

            required property ShellScreen modelData

            active: true

            sourceComponent: Wallpaper {
                screen: wallpaperLoader.modelData
            }

        }

    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: desktopLoader

            required property ShellScreen modelData

            active: Config.desktop.enabled && SuspendManager.wakeReady

            sourceComponent: Desktop {
                screen: desktopLoader.modelData
            }

        }

    }

    // Visual panel & reservations
    Variants {
        model: Quickshell.screens

        Item {
            id: screenShellContainer

            required property ShellScreen modelData

            // Panel components (Bar, Notch, Dock, Frame, Corners)
            UnifiedShellPanel {
                id: unifiedPanel

                targetScreen: screenShellContainer.modelData
            }

            Loader {
                active: Config.theme.enableCorners && Config.roundness > 0

                sourceComponent: ScreenCorners {
                    screen: screenShellContainer.modelData
                }

            }

            // Exclusive zone reservations
            ReservationWindows {
                screen: screenShellContainer.modelData
                // Bar status for reservations
                barEnabled: {
                    const list = (Config.bar && Config.bar.screenList !== undefined ? Config.bar.screenList : []);
                    return (!list || list.length === 0 || list.indexOf(screen.name) !== -1);
                }
                barPosition: unifiedPanel.barPosition
                barPinned: unifiedPanel.pinned
                barSize: (unifiedPanel.barPosition === "left" || unifiedPanel.barPosition === "right") ? unifiedPanel.barTargetWidth : unifiedPanel.barTargetHeight
                barOuterMargin: unifiedPanel.barOuterMargin
                // Dock status for reservations
                dockEnabled: {
                    if (!((Config.dock && Config.dock.enabled !== undefined ? Config.dock.enabled : false)) || (Config.dock && Config.dock.theme !== undefined ? Config.dock.theme : "default") === "integrated")
                        return false;

                    const list = (Config.dock && Config.dock.screenList !== undefined ? Config.dock.screenList : []);
                    if (!list || list.length === 0)
                        return true;

                    return list.indexOf(screenShellContainer.modelData.name) !== -1;
                }
                dockPosition: unifiedPanel.dockPosition
                dockPinned: unifiedPanel.dockPinned
                dockHeight: unifiedPanel.dockHeight
                containBar: unifiedPanel.containBar
                frameEnabled: (Config.bar && Config.bar.frameEnabled !== undefined ? Config.bar.frameEnabled : false)
                frameThickness: (Config.bar && Config.bar.frameThickness !== undefined ? Config.bar.frameThickness : 6)
                // Sidebar status for reservations
                sidebarEnabled: GlobalStates.assistantVisible && screenShellContainer.modelData.name === GlobalStates.assistantScreenName
                sidebarPinned: GlobalStates.assistantPinned
                sidebarWidth: GlobalStates.assistantWidth
                sidebarPosition: GlobalStates.assistantPosition
            }

        }

    }

    // Overview popup
    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = (Config.bar && Config.bar.screenList !== undefined ? Config.bar.screenList : []);
            if (!list || list.length === 0)
                return screens;

            return screens.filter((screen) => {
                return list.indexOf(screen.name) !== -1;
            });
        }

        Loader {
            id: overviewLoader

            required property ShellScreen modelData

            active: ((Config.overview && Config.overview.enabled !== undefined ? Config.overview.enabled : true)) && SuspendManager.wakeReady && (Visibilities.getForScreen(modelData.name) ? Visibilities.getForScreen(modelData.name).overview : false)

            sourceComponent: OverviewPopup {
                screen: overviewLoader.modelData
            }

        }

    }

    // Presets popup
    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = (Config.bar && Config.bar.screenList !== undefined ? Config.bar.screenList : []);
            if (!list || list.length === 0)
                return screens;

            return screens.filter((screen) => {
                return list.indexOf(screen.name) !== -1;
            });
        }

        Loader {
            id: presetsLoader

            required property ShellScreen modelData

            active: SuspendManager.wakeReady && (Visibilities.getForScreen(modelData.name) ? Visibilities.getForScreen(modelData.name).presets : false)

            sourceComponent: PresetsPopup {
                screen: presetsLoader.modelData
            }

        }

    }

    // Display Select popup
    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = (Config.bar && Config.bar.screenList !== undefined ? Config.bar.screenList : []);
            if (!list || list.length === 0)
                return screens;

            return screens.filter((screen) => {
                return list.indexOf(screen.name) !== -1;
            });
        }

        Loader {
            id: displaySelectLoader

            required property ShellScreen modelData

            active: SuspendManager.wakeReady && (Visibilities.getForScreen(modelData.name) ? Visibilities.getForScreen(modelData.name).displaySelect : false)

            sourceComponent: DisplaySelectPopup {
                screen: displaySelectLoader.modelData
            }

        }

    }

    // Secure WlSessionLock lockscreen
    WlSessionLock {
        id: sessionLock

        locked: GlobalStates.lockscreenVisible

        // Surface auto-created per screen
        LockScreen {
        }

    }

    CompositorConfig {
        id: compositorConfig
    }

    // Screenshot tool
    Variants {
        model: Quickshell.screens

        Loader {
            id: screenshotLoader

            required property ShellScreen modelData

            active: GlobalStates.screenshotToolVisible

            sourceComponent: ScreenshotTool {
                targetScreen: screenshotLoader.modelData
            }

        }

    }

    // Screenshot preview overlay
    Variants {
        model: Quickshell.screens

        Loader {
            id: screenshotOverlayLoader

            required property ShellScreen modelData

            active: SuspendManager.wakeReady

            sourceComponent: ScreenshotOverlay {
                targetScreen: screenshotOverlayLoader.modelData
            }

        }

    }

    // Screen recording tool
    Loader {
        id: screenRecordLoader

        active: SuspendManager.wakeReady && GlobalStates.screenRecordToolVisible
        source: "modules/tools/ScreenrecordTool.qml"
        onLoaded: {
            if (GlobalStates.screenRecordToolVisible && item)
                item.open();

        }

        Connections {
            function onScreenRecordToolVisibleChanged() {
                if (screenRecordLoader.status === Loader.Ready) {
                    if (GlobalStates.screenRecordToolVisible)
                        screenRecordLoader.item.open();
                    else
                        screenRecordLoader.item.close();
                }
            }

            target: GlobalStates
        }

        Connections {
            function onVisibleChanged() {
                if (!screenRecordLoader.item.visible && GlobalStates.screenRecordToolVisible)
                    GlobalStates.screenRecordToolVisible = false;

            }

            target: screenRecordLoader.item
            ignoreUnknownSignals: true
        }

    }

    // Mirror tool
    Loader {
        id: mirrorLoader

        active: SuspendManager.wakeReady && GlobalStates.mirrorWindowVisible
        source: "modules/tools/MirrorWindow.qml"
    }

    // Settings
    Loader {
        id: settingsWindowLoader

        active: SuspendManager.wakeReady && GlobalStates.settingsWindowVisible
        source: "modules/widgets/config/SettingsWindow.qml"
    }

    // On-screen display
    Variants {
        model: Quickshell.screens

        Loader {
            id: osdLoader

            required property ShellScreen modelData

            active: SuspendManager.wakeReady

            sourceComponent: OSD {
                targetScreen: osdLoader.modelData
            }

        }

    }

    // Init clipboard service
    Connections {
        // Service initialized and ready

        function onListCompleted() {
        }

        target: ClipboardService
    }

    // Force service init at startup but defer it slightly so it doesn't block the UI
    QtObject {
        id: serviceInitializer

        Component.onCompleted: {
            // Critical services — init immediately (next tick)
            Qt.callLater(() => {
                let _ = CaffeineService.inhibit;
                _ = IdleService.lockCmd; // Force init
                _ = GlobalShortcuts.appId; // Force init (IPC pipe listener)
                _ = PrinterService.printers; // Force init
                _ = CalendarService.isAuthenticated; // Force init
                _ = DisplayService.toString(); // Force init
            });
        }
    }

    // Non-critical services — defer 2s after startup
    Timer {
        interval: 2000
        running: true
        onTriggered: {
            let _ = NightLightService.active;
            _ = GameModeService.toggled;
            _ = BingWallpaperService.toString();
            _ = LocationService.active;
        }
    }

}
