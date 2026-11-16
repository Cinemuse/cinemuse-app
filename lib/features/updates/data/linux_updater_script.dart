/// The script that swaps the app files after the app has closed.
///
/// It runs as the current user, never as admin, like the Windows one: the app
/// lives in a folder the user can write to, so no password is ever needed.
///
/// The paths arrive as arguments, not inside the text, so no folder name can
/// break out of the script. Arguments, in order: the process to wait for (the
/// running app), the extracted update, the folder the app runs from, the app
/// to restart, the folder to delete at the end (the script is inside it), and
/// the log file.
///
/// Built line by line: a multi-line string would take the line endings of this
/// source file, and `sh` can't run a script with Windows line endings.
const linuxUpdaterScript =
    'app_pid=\$1\n'
    'source_dir=\$2\n'
    'app_dir=\$3\n'
    'exe_path=\$4\n'
    'work_dir=\$5\n'
    'log_file=\$6\n'
    '\n'
    'while kill -0 "\$app_pid" 2>/dev/null; do\n'
    '  sleep 1\n'
    'done\n'
    '\n'
    'if ! cp -Rf "\$source_dir/." "\$app_dir/" > "\$log_file" 2>&1; then\n'
    '  exit 1\n'
    'fi\n'
    '\n'
    '# The unpacked copy has lost its "can be run" mark.\n'
    'chmod +x "\$exe_path"\n'
    'rm -rf "\$work_dir"\n'
    'exec "\$exe_path"\n';
