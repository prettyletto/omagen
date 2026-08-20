import QtQuick
import Quickshell.Io

Item {
    id: root

    property string executable: ""

    signal loaded(string harmony, real primaryText, real brightText, real secondaryText, real uiElement, real selectionText)
    signal loadFailed(string message)
    signal saved(string harmony, real primaryText, real brightText, real secondaryText, real uiElement, real selectionText)
    signal saveFailed(string message)
    signal resetCompleted(string harmony, real primaryText, real brightText, real secondaryText, real uiElement, real selectionText)
    signal resetFailed(string message)

    function get() {
        getProcess.exec([root.executable, "settings", "get"]);
    }

    function save(harmony, primaryText, brightText, secondaryText, uiElement, selectionText) {
        const value = JSON.stringify({
            schema_version: 1,
            color_theory: { harmony: harmony },
            contrast: {
                primary_text: Number(primaryText),
                bright_text: Number(brightText),
                secondary_text: Number(secondaryText),
                ui_element: Number(uiElement),
                selection_text: Number(selectionText)
            }
        });
        saveProcess.exec([root.executable, "settings", "set", value]);
    }

    function reset() {
        resetProcess.exec([root.executable, "settings", "reset"]);
    }

    function parseSettings(text) {
        const result = JSON.parse(text);
        const colorTheory = result.color_theory || {};
        const contrast = result.contrast || {};
        if (
            !colorTheory.harmony ||
            contrast.primary_text === undefined ||
            contrast.bright_text === undefined ||
            contrast.secondary_text === undefined ||
            contrast.ui_element === undefined ||
            contrast.selection_text === undefined
        ) {
            throw new Error("incomplete settings");
        }
        return [
            colorTheory.harmony,
            contrast.primary_text,
            contrast.bright_text,
            contrast.secondary_text,
            contrast.ui_element,
            contrast.selection_text
        ];
    }

    Process {
        id: getProcess
        stdout: StdioCollector { id: getStdout; waitForEnd: true }
        stderr: StdioCollector { id: getStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.loadFailed(getStderr.text.trim() || "Failed to load settings");
                return;
            }
            try {
                const values = root.parseSettings(getStdout.text);
                root.loaded.apply(root, values);
            } catch (error) {
                root.loadFailed("Backend returned invalid settings JSON");
            }
        }
    }

    Process {
        id: saveProcess
        stdout: StdioCollector { id: saveStdout; waitForEnd: true }
        stderr: StdioCollector { id: saveStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.saveFailed(saveStderr.text.trim() || "Failed to save settings");
                return;
            }
            try {
                const values = root.parseSettings(saveStdout.text);
                root.saved.apply(root, values);
            } catch (error) {
                root.saveFailed("Backend returned invalid settings JSON");
            }
        }
    }

    Process {
        id: resetProcess
        stdout: StdioCollector { id: resetStdout; waitForEnd: true }
        stderr: StdioCollector { id: resetStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.resetFailed(resetStderr.text.trim() || "Failed to reset settings");
                return;
            }
            try {
                const values = root.parseSettings(resetStdout.text);
                root.resetCompleted.apply(root, values);
            } catch (error) {
                root.resetFailed("Backend returned invalid settings JSON");
            }
        }
    }
}
