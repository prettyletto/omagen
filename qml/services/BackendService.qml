import QtQuick
import Quickshell.Io

Item {
    id: root

    property string executable: ""

    signal sessionBegan(
        string sessionId,
        string originalTheme,
        string backgroundKind,
        string backgroundPath
    )
    signal sessionBeginFailed(string message)
    signal sessionCancelled(string sessionId)
    signal sessionCancelFailed(string message)
    signal sessionResumeChecked(var result)
    signal sessionResumeCheckFailed(string message)
    signal backendReady()
    signal backendUnavailable(string message)
    signal sessionRecovered()
    signal sessionRecoverFailed(string message)
    signal generationCompleted(string generationId)
    signal generationFailed(string message)
    signal generationDescribed(string generationId, var variants)
    signal generationDescribeFailed(string message)
    signal previewApplied(string sessionId, string generationId, string variant, string themeName)
    signal previewApplyFailed(string message)
    signal themeApplied(string sessionId, string generationId, string variant, string themeName)
    signal themeApplyFailed(string message)
    signal demoOpened(string sessionId, string workspace, bool reused)
    signal demoOpenFailed(string message)
    signal demoClosed(string sessionId, bool closed)
    signal demoCloseFailed(string message)

    function beginSession() {
        sessionBeginProcess.exec([root.executable, "session", "begin"]);
    }

    function cancelSession(sessionId) {
        sessionCancelProcess.exec([
            root.executable,
            "session",
            "cancel",
            sessionId
        ]);
    }
    function checkResumeSession() { resumeProcess.exec([root.executable, "session", "resume"]); }
    function checkBackend() { pingProcess.exec([root.executable, "ping"]); }
    function recoverSession() { recoverProcess.exec([root.executable, "session", "recover"]); }

    function generateTheme(sessionId, imagePath) { generationProcess.exec([root.executable, "generate", sessionId, imagePath]); }
    function describeGeneration(sessionId, generationId) { generationDescribeProcess.exec([root.executable, "generation", "describe", sessionId, generationId]); }
    function applyPreview(sessionId, generationId, variant) { previewProcess.exec([root.executable, "preview", "apply", sessionId, generationId, variant]); }
    function applyTheme(sessionId, generationId, variant, name) { applyProcess.exec([root.executable, "apply", sessionId, generationId, variant, name]); }
    function openDemo(sessionId) { demoOpenProcess.exec([root.executable, "demo", "open", sessionId]); }
    function closeDemo(sessionId) { demoCloseProcess.exec([root.executable, "demo", "close", sessionId]); }

    Process {
        id: pingProcess
        stdout: StdioCollector { id: pingStdout; waitForEnd: true }
        stderr: StdioCollector { id: pingStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                const message = pingStderr.text.trim();
                root.backendUnavailable(
                    message !== "" ? message : "Omagen backend is unavailable"
                );
                return;
            }
            root.backendReady();
        }
    }

    Process {
        id: resumeProcess
        stdout: StdioCollector { id: resumeStdout; waitForEnd: true }
        stderr: StdioCollector { id: resumeStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.sessionResumeCheckFailed(resumeStderr.text.trim() || "Failed to inspect previous session"); return }
            try { root.sessionResumeChecked(JSON.parse(resumeStdout.text)) } catch (error) { root.sessionResumeCheckFailed("Backend returned invalid resume data") }
        }
    }

    Process {
        id: recoverProcess
        stdout: StdioCollector { id: recoverStdout; waitForEnd: true }
        stderr: StdioCollector { id: recoverStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.sessionRecoverFailed(recoverStderr.text.trim() || "Failed to restore previous session"); return }
            root.sessionRecovered()
        }
    }

    Process {
        id: sessionBeginProcess

        stdout: StdioCollector {
            id: sessionBeginStdout
            waitForEnd: true
        }

        stderr: StdioCollector {
            id: sessionBeginStderr
            waitForEnd: true
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                const message = sessionBeginStderr.text.trim();
                root.sessionBeginFailed(
                    message !== "" ? message : "Failed to begin session"
                );
                return;
            }

            try {
                const result = JSON.parse(sessionBeginStdout.text);
                const background = result.original_background || {};
                const sessionId = result.session_id || "";
                const originalTheme = result.original_theme || "";
                const backgroundKind = background.kind || "";
                const backgroundPath = background.path || "";

                if (
                    sessionId === "" ||
                    originalTheme === "" ||
                    backgroundKind === "" ||
                    backgroundPath === ""
                ) {
                    root.sessionBeginFailed(
                        "Backend returned incomplete session data"
                    );
                    return;
                }

                root.sessionBegan(
                    sessionId,
                    originalTheme,
                    backgroundKind,
                    backgroundPath
                );
            } catch (error) {
                root.sessionBeginFailed("Backend returned invalid JSON");
            }
        }
    }

    Process {
        id: sessionCancelProcess

        stdout: StdioCollector {
            id: sessionCancelStdout
            waitForEnd: true
        }

        stderr: StdioCollector {
            id: sessionCancelStderr
            waitForEnd: true
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                const message = sessionCancelStderr.text.trim();
                root.sessionCancelFailed(
                    message !== "" ? message : "Failed to cancel session"
                );
                return;
            }

            try {
                const result = JSON.parse(sessionCancelStdout.text);
                if (result.ok !== true || !result.session_id) {
                    root.sessionCancelFailed(
                        "Backend returned invalid cancellation result"
                    );
                    return;
                }
                root.sessionCancelled(result.session_id);
            } catch (error) {
                root.sessionCancelFailed(
                    "Backend returned invalid cancellation JSON"
                );
            }
        }
    }

    Process {
        id: generationProcess
        stdout: StdioCollector { id: generationStdout; waitForEnd: true }
        stderr: StdioCollector { id: generationStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.generationFailed(generationStderr.text.trim() || "Theme generation failed"); return }
            try { const result=JSON.parse(generationStdout.text); if (!result.generation_id) { root.generationFailed("Backend returned no generation id"); return } root.generationCompleted(result.generation_id) } catch (error) { root.generationFailed("Backend returned invalid generation JSON") }
        }
    }

    Process {
        id: generationDescribeProcess
        stdout: StdioCollector { id: generationDescribeStdout; waitForEnd: true }
        stderr: StdioCollector { id: generationDescribeStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.generationDescribeFailed(generationDescribeStderr.text.trim() || "Failed to load generated palettes"); return }
            try { const result=JSON.parse(generationDescribeStdout.text); if (!result.generation_id || (result.variants||[]).length !== 6) { root.generationDescribeFailed("Backend returned incomplete generation data"); return } root.generationDescribed(result.generation_id, result.variants) } catch (error) { root.generationDescribeFailed("Backend returned invalid generation description") }
        }
    }

    Process {
        id: previewProcess
        stdout: StdioCollector { id: previewStdout; waitForEnd: true }
        stderr: StdioCollector { id: previewStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.previewApplyFailed(previewStderr.text.trim() || "Failed to apply preview"); return }
            try { const result=JSON.parse(previewStdout.text); if (!result.session_id || !result.generation_id || !result.variant) { root.previewApplyFailed("Backend returned incomplete preview data"); return } root.previewApplied(result.session_id,result.generation_id,result.variant,result.theme_name||"") } catch (error) { root.previewApplyFailed("Backend returned invalid preview JSON") }
        }
    }

    Process {
        id: applyProcess
        stdout: StdioCollector { id: applyStdout; waitForEnd: true }
        stderr: StdioCollector { id: applyStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.themeApplyFailed(applyStderr.text.trim() || "Failed to apply theme"); return }
            try { const result = JSON.parse(applyStdout.text); if (!result.session_id || !result.generation_id || !result.variant || !result.theme_name) { root.themeApplyFailed("Backend returned incomplete apply data"); return } root.themeApplied(result.session_id, result.generation_id, result.variant, result.theme_name) } catch (error) { root.themeApplyFailed("Backend returned invalid apply JSON") }
        }
    }

    Process {
        id: demoOpenProcess
        stdout: StdioCollector { id: demoOpenStdout; waitForEnd: true }
        stderr: StdioCollector { id: demoOpenStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.demoOpenFailed(demoOpenStderr.text.trim() || "Failed to open demo workspace"); return }
            try {
                const result = JSON.parse(demoOpenStdout.text)
                if (result.ok !== true || !result.session_id || !result.workspace) { root.demoOpenFailed("Backend returned incomplete demo data"); return }
                root.demoOpened(result.session_id, result.workspace, result.reused === true)
            } catch (error) { root.demoOpenFailed("Backend returned invalid demo JSON") }
        }
    }

    Process {
        id: demoCloseProcess
        stdout: StdioCollector { id: demoCloseStdout; waitForEnd: true }
        stderr: StdioCollector { id: demoCloseStderr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) { root.demoCloseFailed(demoCloseStderr.text.trim() || "Failed to close demo workspace"); return }
            try {
                const result = JSON.parse(demoCloseStdout.text)
                if (result.ok !== true || !result.session_id) { root.demoCloseFailed("Backend returned incomplete demo cleanup data"); return }
                root.demoClosed(result.session_id, result.closed === true)
            } catch (error) { root.demoCloseFailed("Backend returned invalid demo cleanup JSON") }
        }
    }
}
