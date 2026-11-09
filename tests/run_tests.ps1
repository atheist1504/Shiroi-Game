# Runs Godot test scripts headless and reports real PASS/FAIL counts.
# Output is redirected to files because the Windows Godot build does not print
# to the calling console. Real save files are backed up and restored because
# some tests write to regular save slots.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
#   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1 -Filter step21
# Set SHIROI_GODOT to use another Godot executable.
param(
	[string]$Filter = "test_",
	[int]$TimeoutSeconds = 120
)

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godot = $env:SHIROI_GODOT
if ([string]::IsNullOrEmpty($godot)) {
	$godot = "D:\Godot\Godot_v4.7.2-stable_win64.exe"
	if (-not (Test-Path -LiteralPath $godot)) {
		$godot = Join-Path ([Environment]::GetFolderPath("Desktop")) "Godot_v4.7.2-stable_win64.exe"
	}
}
if (-not (Test-Path -LiteralPath $godot)) {
	Write-Error "Godot not found: $godot. Set the SHIROI_GODOT environment variable."
	exit 2
}

$stamp = Get-Date -Format "yyyyMMddHHmmss"
$workDir = Join-Path $env:TEMP "shiroi_tests_$stamp"
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$savesDir = Join-Path $env:APPDATA "Godot\app_userdata\Shiroi-The Lost Heir\saves"
$backupDir = Join-Path $workDir "saves_backup"
$hasSaves = Test-Path -LiteralPath $savesDir
if ($hasSaves) {
	Copy-Item -LiteralPath $savesDir -Destination $backupDir -Recurse -Force
}

$failedTests = 0
try {
	$tests = Get-ChildItem -Path (Join-Path $projectDir "tests") -Filter "test_*.gd" |
		Where-Object { $_.Name -like "*$Filter*" } | Sort-Object Name
	foreach ($test in $tests) {
		# Outdated: expects save schema 1 and a quest id that no longer exists.
		if ($test.Name -eq "test_step16.gd") {
			"{0,-10} {1,-26} outdated, needs rewriting" -f "SKIPPED", $test.Name
			continue
		}
		$out = Join-Path $workDir ($test.BaseName + ".out")
		$err = Join-Path $workDir ($test.BaseName + ".err")
		$arguments = @("--headless", "--path", "`"$projectDir`"", "--script", "res://tests/$($test.Name)")
		$process = Start-Process -FilePath $godot -ArgumentList $arguments -PassThru -WindowStyle Hidden `
			-RedirectStandardOutput $out -RedirectStandardError $err
		$null = $process.Handle
		$timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
		if ($timedOut) {
			$process.Kill()
			$process.WaitForExit()
		}
		$lines = @(Get-Content -LiteralPath $out -Encoding UTF8) + @(Get-Content -LiteralPath $err -Encoding UTF8)
		$passes = @($lines | Where-Object { $_ -match "^\s*(->\s*)?\[?PASS\b" }).Count
		$fails = @($lines | Where-Object { $_ -match "^\s*(->\s*)?\[?FAIL\b" })
		$errors = @($lines | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|Failed to load script" })
		$status = "OK"
		if ($timedOut) { $status = "TIMEOUT" }
		elseif ($process.ExitCode -ne 0 -or $fails.Count -gt 0 -or $errors.Count -gt 0) { $status = "FAILED" }
		elseif ($passes -eq 0) { $status = "NO_RESULT" }
		if ($status -ne "OK") { $failedTests += 1 }
		"{0,-10} {1,-26} pass={2} fail={3} script_errors={4} exit={5}" -f $status, $test.Name, $passes, $fails.Count, $errors.Count, $process.ExitCode
		$fails | ForEach-Object { "    $($_.Trim())" }
		$errors | Select-Object -First 5 | ForEach-Object { "    $($_.Trim())" }
	}
}
finally {
	if ($hasSaves -and (Test-Path -LiteralPath $backupDir)) {
		Get-ChildItem -LiteralPath $savesDir -File | Where-Object {
			-not (Test-Path -LiteralPath (Join-Path $backupDir $_.Name))
		} | Remove-Item -Force
		Copy-Item -Path (Join-Path $backupDir "*") -Destination $savesDir -Recurse -Force
	}
	"Logs: $workDir"
}
exit ([Math]::Min($failedTests, 1))
