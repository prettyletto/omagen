import QtQuick
import Quickshell.Io

Item {
    id: root

    property string executable: ""

    signal loaded(string harmony, real primaryText, real brightText, real secondaryText, real uiElement, real selectionText, real ansi, real brightAnsi)
    signal loadFailed(string message)
    signal saved(string harmony, real primaryText, real brightText, real secondaryText, real uiElement, real selectionText, real ansi, real brightAnsi)
    signal saveFailed(string message)
    signal resetCompleted(string harmony, real primaryText, real brightText, real secondaryText, real uiElement, real selectionText, real ansi, real brightAnsi)
    signal resetFailed(string message)

    function get() {
        getProcess.exec([root.executable, "settings", "get"]);
    }

    function save(harmony, primaryText, brightText, secondaryText, uiElement, selectionText, ansi, brightAnsi) {
        const value = JSON.stringify({
            color_theory: { harmony: harmony },
            contrast: {
                primary_text: Number(primaryText),
                bright_text: Number(brightText),
                secondary_text: Number(secondaryText),
                ui_element: Number(uiElement),
                selection_text: Number(selectionText),
                ansi: Number(ansi),
                bright_ansi: Number(brightAnsi)
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
        if (!colorTheory.harmony || contrast.primary_text === undefined || contrast.bright_text === undefined || contrast.secondary_text === undefined || contrast.ui_element === undefined || contrast.selection_text === undefined || contrast.ansi === undefined || contrast.bright_ansi === undefined) {
            throw new Error("incomplete settings");
        }
        return [colorTheory.harmony, contrast.primary_text, contrast.bright_text, contrast.secondary_text, contrast.ui_element, contrast.selection_text, contrast.ansi, contrast.bright_ansi];
    }

    Process {
        id: getProcess
        stdout: BoundedOutputParser { id: getStdout }
        stderr: BoundedOutputParser { id: getStderr }
        onStarted: {
            getStdout.reset();
            getStderr.reset();
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.loadFailed(getStderr.text.trim() || "Failed to load settings");
                return;
            }
            try {
                root.loaded.apply(root, root.parseSettings(getStdout.text));
            } catch (error) {
                root.loadFailed("Backend returned invalid settings JSON");
            }
        }
    }

    Process {
        id: saveProcess
        stdout: BoundedOutputParser { id: saveStdout }
        stderr: BoundedOutputParser { id: saveStderr }
        onStarted: {
            saveStdout.reset();
            saveStderr.reset();
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.saveFailed(saveStderr.text.trim() || "Failed to save settings");
                return;
            }
            try {
                root.saved.apply(root, root.parseSettings(saveStdout.text));
            } catch (error) {
                root.saveFailed("Backend returned invalid settings JSON");
            }
        }
    }

    Process {
        id: resetProcess
        stdout: BoundedOutputParser { id: resetStdout }
        stderr: BoundedOutputParser { id: resetStderr }
        onStarted: {
            resetStdout.reset();
            resetStderr.reset();
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.resetFailed(resetStderr.text.trim() || "Failed to reset settings");
                return;
            }
            try {
                root.resetCompleted.apply(root, root.parseSettings(resetStdout.text));
            } catch (error) {
                root.resetFailed("Backend returned invalid settings JSON");
            }
        }
    }
}
