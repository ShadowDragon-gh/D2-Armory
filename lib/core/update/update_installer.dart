import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../errors/failures.dart';

/// Performs the Windows self-update swap.
///
/// A running `.exe` holds locks on its own files, so it cannot overwrite them.
/// This spawns a detached batch helper that waits for the app process to exit,
/// unpacks the downloaded zip into a staging folder, copies it over the install
/// directory, relaunches the app, and cleans up after itself. The main app then
/// exits so its locks release and the helper can proceed.
///
/// Windows-only. Guard calls with [isSupported].
class UpdateInstaller {
  UpdateInstaller({Logger? logger}) : _log = logger ?? Logger();

  final Logger _log;

  static bool get isSupported => Platform.isWindows;

  /// Directory the running executable lives in (the folder the zip replaces).
  Directory get installDir => File(Platform.resolvedExecutable).parent;

  /// Write the helper script, launch it detached, and return. The caller must
  /// exit the app promptly afterwards so file locks release. Throws
  /// [UpdateFailure] if the helper cannot be written or started.
  Future<void> installAndRelaunch(String zipPath) async {
    if (!isSupported) {
      throw const UpdateFailure('Self-update is only supported on Windows.');
    }

    final exePath = Platform.resolvedExecutable;
    final install = installDir.path;
    final appPid = pid;

    final tempDir = await getTemporaryDirectory();
    final sep = Platform.pathSeparator;
    final stageDir = '${tempDir.path}${sep}d2armory_update_stage';
    final scriptPath = '${tempDir.path}${sep}d2armory_update.bat';
    final logPath = '${tempDir.path}${sep}d2armory_update.log';

    final script = _buildScript(
      appPid: appPid,
      zipPath: zipPath,
      stageDir: stageDir,
      installDir: install,
      exePath: exePath,
      logPath: logPath,
    );

    try {
      await File(scriptPath).writeAsString(script);
    } catch (e) {
      throw UpdateFailure('Could not write the updater helper.', cause: e);
    }

    _log.i('Launching update helper for pid $appPid -> $install');
    try {
      // Detached so it outlives this process, and launched through PowerShell's
      // Start-Process -WindowStyle Hidden so the batch runs in a hidden console
      // rather than a visible/minimized one. A plain 'cmd /c start /min' leaves
      // a stray console window on screen for the batch's lifetime.
      await Process.start(
        'powershell.exe',
        [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-Command',
          "Start-Process -FilePath '$scriptPath' -WindowStyle Hidden",
        ],
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      throw UpdateFailure('Could not start the updater helper.', cause: e);
    }
  }

  /// The batch helper. It is intentionally defensive: every failure aborts the
  /// swap *before* touching the install folder, and it always relaunches the
  /// app so the user is never left with a closed, un-updated install.
  String _buildScript({
    required int appPid,
    required String zipPath,
    required String stageDir,
    required String installDir,
    required String exePath,
    required String logPath,
  }) {
    // robocopy exit codes >= 8 indicate failure (0-7 are success/informational).
    return '''
@echo off
setlocal
set "LOG=$logPath"
echo [%date% %time%] update helper started for pid $appPid > "%LOG%"

rem --- 1. Wait for the app (pid $appPid) to fully exit so files unlock ---
set /a TRIES=0
:waitloop
tasklist /fi "PID eq $appPid" 2>nul | find "$appPid" >nul
if errorlevel 1 goto exited
set /a TRIES+=1
if %TRIES% GEQ 60 (
  echo [ERROR] app pid $appPid did not exit within 60s, aborting >> "%LOG%"
  goto relaunch
)
timeout /t 1 /nobreak >nul
goto waitloop
:exited
echo [%time%] app exited, staging update >> "%LOG%"

rem --- 2. Extract the zip into a clean staging folder ---
if exist "$stageDir" rmdir /s /q "$stageDir"
powershell -NoProfile -Command "Expand-Archive -LiteralPath '$zipPath' -DestinationPath '$stageDir' -Force" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo [ERROR] extract failed, aborting without touching install >> "%LOG%"
  goto relaunch
)

rem --- 3. Copy staged files over the install dir (copy, do not purge) ---
robocopy "$stageDir" "$installDir" /E /R:3 /W:1 >> "%LOG%" 2>&1
if %ERRORLEVEL% GEQ 8 (
  echo [ERROR] robocopy failed with %ERRORLEVEL% >> "%LOG%"
) else (
  echo [%time%] files updated >> "%LOG%"
)

:relaunch
echo [%time%] relaunching app >> "%LOG%"
rem This batch runs in a hidden console (launched via PowerShell Start-Process
rem -WindowStyle Hidden), so there is no visible console for the GUI app to
rem attach to via AttachConsole(ATTACH_PARENT_PROCESS). Launch it directly with
rem 'start' so it detaches from this batch and outlives it.
start "" "$exePath"

rem --- 4. Clean up staging + downloaded zip (best effort) ---
if exist "$stageDir" rmdir /s /q "$stageDir"
if exist "$zipPath" del /q "$zipPath"

rem Delete this script last.
(goto) 2>nul & del "%~f0"
''';
  }
}
