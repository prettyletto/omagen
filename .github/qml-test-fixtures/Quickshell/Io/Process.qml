import QtQml

QtObject {
    property bool running: false
    property QtObject stdout: null
    property QtObject stderr: null

    signal started()
    signal exited(int exitCode, int exitStatus)

    function exec(args) {
        running = true
        started()
    }
}
