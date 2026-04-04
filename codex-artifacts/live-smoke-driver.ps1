param(
  [string]$Action,
  [string]$Name,
  [string]$Keys = '',
  [int]$DelayMs = 1200,
  [int]$X = 0,
  [int]$Y = 0
)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
}
"@
$artifactDir = 'D:\Games\MegaMan64Recompiled\codex-artifacts\live-smoke'
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$proc = Get-Process -Name 'MegaMan64Recompiled' -ErrorAction Stop | Sort-Object StartTime -Descending | Select-Object -First 1
$wshell = New-Object -ComObject WScript.Shell
$proc.Refresh()
if ($proc.MainWindowHandle -eq 0) { throw 'Main window handle not available.' }
[Win32]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null
Start-Sleep -Milliseconds 150
[Win32]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
$null = $wshell.AppActivate($proc.Id)
Start-Sleep -Milliseconds 300
$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
if ($Action -eq 'send') {
  [System.Windows.Forms.SendKeys]::SendWait($Keys)
  Start-Sleep -Milliseconds $DelayMs
} elseif ($Action -eq 'click') {
  $screenX = $rect.Left + $X
  $screenY = $rect.Top + $Y
  [Win32]::SetCursorPos($screenX, $screenY) | Out-Null
  Start-Sleep -Milliseconds 150
  [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 80
  [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds $DelayMs
}
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
$bmp = New-Object System.Drawing.Bitmap $width, $height
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
$path = Join-Path $artifactDir $Name
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bmp.Dispose()
Write-Output $path
