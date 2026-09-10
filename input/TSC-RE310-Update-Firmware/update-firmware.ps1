# Nap firmware RE310 qua USB.
#
# Cach dung: cam may in bang cap USB, bat nguon, roi chay:
#   powershell -ExecutionPolicy Bypass -File update-firmware.ps1
#
# Script tu tim may in, in nhan xac nhan, hoi truoc khi nap.
# KHONG tat may / rut cap trong luc nap.

$ErrorActionPreference = 'Stop'
$fwPath = Join-Path $PSScriptRoot 'RE310_EZC_B0.99.025.NEW'

# ---- Winspool RAW writer: gui thang byte xuong may in, khong qua driver ----
$src = @'
using System;
using System.Runtime.InteropServices;
public class FwSend {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public class DOCINFO { public string pDocName; public string pOutputFile; public string pDataType; }
  [DllImport("winspool.drv", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool OpenPrinter(string p, out IntPtr h, IntPtr d);
  [DllImport("winspool.drv", SetLastError=true)] public static extern bool ClosePrinter(IntPtr h);
  [DllImport("winspool.drv", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool StartDocPrinter(IntPtr h, int l, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFO di);
  [DllImport("winspool.drv", SetLastError=true)] public static extern bool EndDocPrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)] public static extern bool StartPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)] public static extern bool EndPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)] public static extern bool WritePrinter(IntPtr h, byte[] b, int n, out int w);
  public static string Send(string printer, byte[] data) {
    IntPtr h;
    if (!OpenPrinter(printer, out h, IntPtr.Zero)) return "LOI: khong mo duoc may in (" + Marshal.GetLastWin32Error() + ")";
    var di = new DOCINFO { pDocName = "FW", pDataType = "RAW" };
    if (!StartDocPrinter(h, 1, di)) { ClosePrinter(h); return "LOI: StartDoc (" + Marshal.GetLastWin32Error() + ")"; }
    StartPagePrinter(h);
    int w; bool ok = WritePrinter(h, data, data.Length, out w);
    EndPagePrinter(h); EndDocPrinter(h); ClosePrinter(h);
    if (!ok) return "LOI: ghi that bai (" + Marshal.GetLastWin32Error() + ")";
    if (w != data.Length) return "LOI: chi gui duoc " + w + "/" + data.Length + " byte";
    return "OK";
  }
}
'@
if (-not ('FwSend' -as [type])) { Add-Type -TypeDefinition $src -Language CSharp }

if (-not (Test-Path $fwPath)) { Write-Host "Khong tim thay $fwPath" -ForegroundColor Red; exit 1 }

# ---- Tim may in ----
# Chi lay cong USB that. USB002 tro len thuong la "Virtual printer port", khong noi toi may nao.
$printers = @(Get-Printer | Where-Object { $_.Name -match 'RE310' } | ForEach-Object {
  $port = Get-PrinterPort -Name $_.PortName -ErrorAction SilentlyContinue
  [pscustomobject]@{ Name = $_.Name; Port = $_.PortName; Desc = $port.Description }
} | Where-Object { $_.Desc -notmatch 'Virtual' })

if ($printers.Count -eq 0) {
  Write-Host "Khong tim thay may in RE310 nao dang cam USB." -ForegroundColor Red
  Write-Host "Kiem tra: cap USB co truyen du lieu khong, may da bat nguon chua."
  exit 1
}

$target = $printers[0]
if ($printers.Count -gt 1) {
  Write-Host "Co nhieu may in:"
  for ($i = 0; $i -lt $printers.Count; $i++) { Write-Host "  [$i] $($printers[$i].Name) - $($printers[$i].Port)" }
  $pick = Read-Host "Chon so"
  $target = $printers[[int]$pick]
}

# Xoa job ton dong tren MOI queue RE310, khong rieng queue dich.
# Mot job ket o queue khac van chiem cong USB, khien lenh gui sang queue dung
# duoc Windows nhan vao hang doi ma may in khong bao gio thay - trieu chung la
# "gui thanh cong nhung khong ra giay".
$stale = 0
Get-Printer | Where-Object { $_.Name -match 'RE310' } | ForEach-Object {
  $jobs = @(Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue)
  $stale += $jobs.Count
  $jobs | Remove-PrintJob -ErrorAction SilentlyContinue
}
if ($stale -gt 0) { Write-Host "Da xoa $stale lenh in ton dong." -ForegroundColor DarkGray }

Write-Host ""
Write-Host "May in: $($target.Name) tren $($target.Port)" -ForegroundColor Cyan

# ---- In nhan xac nhan dung may ----
# Gui firmware nham vao may khac la hong may do, nen phai nhin thay giay truoc khi nap.
$label = "SIZE 72 mm,30 mm`r`nGAP 0 mm,0 mm`r`nCLS`r`nTEXT 30,30,`"3`",0,1,1,`"UPDATE FIRMWARE?`"`r`nPRINT 1,1`r`n`r`n"
[FwSend]::Send($target.Name, [System.Text.Encoding]::ASCII.GetBytes($label)) | Out-Null
Write-Host "Da gui nhan thu. May in co ra chu 'UPDATE FIRMWARE?' khong?" -ForegroundColor Yellow
$ok = Read-Host "Go 'y' de nap firmware, phim khac de huy"
if ($ok -ne 'y') { Write-Host "Da huy."; exit 0 }

# ---- Nap ----
$bytes = [System.IO.File]::ReadAllBytes($fwPath)
Write-Host ""
Write-Host "Dang nap $($bytes.Length) byte. KHONG tat may, KHONG rut cap." -ForegroundColor Yellow
$result = [FwSend]::Send($target.Name, $bytes)

if ($result -ne 'OK') { Write-Host $result -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "Da gui xong firmware." -ForegroundColor Green
Write-Host ""
Write-Host "Tiep theo:"
Write-Host "  1. Cho may ghi flash va tu khoi dong lai (1-2 phut, den nhay)."
Write-Host "  2. In self-test: giu nut Feed khi bat nguon, tha sau lan nhay thu hai."
Write-Host "  3. Kiem tra dong FIRMWARE phai la B0.99.025 EZC"
