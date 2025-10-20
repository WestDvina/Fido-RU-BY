#
# Fido-RU/BY v1.67.1 - ISO Downloader, for Microsoft Windows and UEFI Shell
#
# Original script: Copyright © 2019-2025 Pete Batard <pete@akeo.ie>
# RU/BY adaptation and modifications: Copyright © 2025 WestDvina <westdvina.org@gmail>
#
# Command line support: Copyright © 2021 flx5
# ConvertTo-ImageSource: Copyright © 2016 Chris Carter
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# NB: You must have a BOM on your .ps1 if you want Powershell to actually
# realise it should use Unicode for the UI rather than ISO-8859-1.

#region Parameters
param(
	[string]$AppTitle = "Fido-RU/BY - ISO Downloader",
	[string]$LocData,
	[string]$Locale = "en-US",
	[string]$Icon,
	[string]$PipeName,
	[string]$Win,
	[string]$Rel,
	[string]$Ed,
	[string]$Lang,
	[string]$Arch,
	[switch]$GetUrl = $false,
	[string]$PlatformArch,
	[switch]$Verbose = $false,
	[switch]$Debug = $false,
	[switch]$BypassGeo = $true
)
#endregion

try {
	[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$Cmd = $false
if ($Win -or $Rel -or $Ed -or $Lang -or $Arch -or $GetUrl) {
	$Cmd = $true
}

function Get-Platform-Version()
{
	$version = 0.0
	$platform = [string][System.Environment]::OSVersion.Platform
	if ($platform.StartsWith("Win")) {
		$version = [System.Environment]::OSVersion.Version.Major * 1.0 + [System.Environment]::OSVersion.Version.Minor * 0.1
	}
	return $version
}

$winver = Get-Platform-Version

if ($winver -lt 10.0) {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
}

#region Assembly Types
$Drawing_Assembly = "System.Drawing"
if ($host.version -ge "7.0") {
	$Drawing_Assembly += ".Common"
}

$Signature = @{
	Namespace            = "WinAPI"
	Name                 = "Utils"
	Language             = "CSharp"
	UsingNamespace       = "System.Runtime", "System.IO", "System.Text", "System.Drawing", "System.Globalization"
	ReferencedAssemblies = $Drawing_Assembly
	ErrorAction          = "Stop"
	WarningAction        = "Ignore"
	IgnoreWarnings       = $true
	MemberDefinition     = @"
		[DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = true, BestFitMapping = false, ThrowOnUnmappableChar = true)]
		internal static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);

		[DllImport("user32.dll")]
		public static extern bool ShowWindow(IntPtr handle, int state);
		public static Icon ExtractIcon(string file, int number, bool largeIcon) {
			IntPtr large, small;
			ExtractIconEx(file, number, out large, out small, 1);
			try {
				return Icon.FromHandle(largeIcon ? large : small);
			} catch {
				return null;
			}
		}
"@
}

if (!$Cmd) {
	Write-Host Пожалуйста, подождите...
	if (!("WinAPI.Utils" -as [type])) {
		Add-Type @Signature
	}
	Add-Type -AssemblyName PresentationFramework
	[WinAPI.Utils]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0) | Out-Null
}
#endregion

#region Data
$WindowsVersions = @(
	@(
		@("Windows 11", "windows11"),
		@(
			"25H2 (Build 26200.6584 - 2025.10)",
			@("Windows 11 Home/Pro/Edu", @(3262, 3265)),
			@("Windows 11 Home China ", @(3263, 3266)),
			@("Windows 11 Pro China ", @(3264, 3267))
		),
		@(
			"24H2 (Build 26100.1742 - 2024.10)",
			@("Windows 11 Home/Pro/Edu", @(3113, 3131)),
			@("Windows 11 Home China ", @(3115, 3132)),
			@("Windows 11 Pro China ", @(3114, 3133))
		)
	),
	@(
		@("Windows 10", "Windows10ISO"),
		@(
			"22H2 v1 (Build 19045.2965 - 2023.05)",
			@("Windows 10 Home/Pro/Edu", 2618),
			@("Windows 10 Home China ", 2378)
		)
	),
	# === [VDS] Windows 11 LTSC 2024 ===
	@(
		@("Windows 11 Enterprise LTSC 2024", "win11_ltsc_2024_ru_vds"),
		@(
			"24H2 Build 26100.1742 (x64 ru-RU)",
			@("Только x64 (Русский)", 0)
		)
	),
	# === [VDS] Windows 10 LTSC 2021 x64 ===
	@(
		@("Windows 10 Enterprise LTSC 2021 x64", "win10_ltsc_2021_x64_ru_vds"),
		@(
			"21H2 Build 19044.1288 (x64 ru-RU)",
			@("Только x64 (Русский)", 0)
		)
	),
	# === [VDS] Windows 10 LTSC 2021 x86 ===
	@(
		@("Windows 10 Enterprise LTSC 2021 x86", "win10_ltsc_2021_x86_ru_vds"),
		@(
			"21H2 Build 19044.1288 (x86 ru-RU)",
			@("Только x86 (Русский)", 0)
		)
	),
	@(
		@("UEFI Shell 2.2", "UEFI_SHELL 2.2"),
		@(
			"25H1 (edk2-stable202505)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"24H2 (edk2-stable202411)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"24H1 (edk2-stable202405)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"23H2 (edk2-stable202311)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"23H1 (edk2-stable202305)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"22H2 (edk2-stable202211)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"22H1 (edk2-stable202205)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"21H2 (edk2-stable202108)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"21H1 (edk2-stable202105)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"20H2 (edk2-stable202011)",
			@("Release", 0),
			@("Debug", 1)
		)
	),
	@(
		@("UEFI Shell 2.0", "UEFI_SHELL 2.0"),
		@(
			"4.632 [20100426]",
			@("Release", 0)
		)
	)
)

# ========================= ИЗМЕНЕНИЕ №1 =========================
# Обновлен список языков на русский, чтобы соответствовать странице ru-ru
$LanguageMapping = @{
	"en-us" = "Английский (Соединенные Штаты)";
	"en-gb" = "Английский (Соединенное Королевство)";
	"zh-cn" = "Китайский (упрощенное письмо)";
	"zh-tw" = "Китайский (традиционное письмо)";
	"fr-fr" = "Французский";
	"de-de" = "Немецкий";
	"it-it" = "Итальянский";
	"ja-jp" = "Японский";
	"ko-kr" = "Корейский";
	"pt-br" = "Португальский (Бразилия)";
	"es-es" = "Испанский"
}
#endregion

#region Functions
function Select-Language([string]$LangName)
{
	[string]$SysLocale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
	if (($SysLocale.StartsWith("ar") -and $LangName -like "*Arabic*") -or `
		($SysLocale -eq "pt-BR" -and $LangName -like "*Brazil*") -or `
		($SysLocale.StartsWith("ar") -and $LangName -like "*Bulgar*") -or `
		($SysLocale -eq "zh-CN" -and $LangName -like "*Chinese*" -and $LangName -like "*simp*") -or `
		($SysLocale -eq "zh-TW" -and $LangName -like "*Chinese*" -and $LangName -like "*trad*") -or `
		($SysLocale.StartsWith("hr") -and $LangName -like "*Croat*") -or `
		($SysLocale.StartsWith("cz") -and $LangName -like "*Czech*") -or `
		($SysLocale.StartsWith("da") -and $LangName -like "*Danish*") -or `
		($SysLocale.StartsWith("nl") -and $LangName -like "*Dutch*") -or `
		($SysLocale -eq "en-US" -and $LangName -eq "English") -or `
		($SysLocale.StartsWith("en") -and $LangName -like "*English*" -and ($LangName -like "*inter*" -or $LangName -like "*ingdom*")) -or `
		($SysLocale.StartsWith("et") -and $LangName -like "*Eston*") -or `
		($SysLocale.StartsWith("fi") -and $LangName -like "*Finn*") -or `
		($SysLocale -eq "fr-CA" -and $LangName -like "*French*" -and $LangName -like "*Canad*") -or `
		($SysLocale.StartsWith("fr") -and $LangName -eq "French") -or `
		($SysLocale.StartsWith("de") -and $LangName -like "*German*") -or `
		($SysLocale.StartsWith("el") -and $LangName -like "*Greek*") -or `
		($SysLocale.StartsWith("he") -and $LangName -like "*Hebrew*") -or `
		($SysLocale.StartsWith("hu") -and $LangName -like "*Hungar*") -or `
		($SysLocale.StartsWith("id") -and $LangName -like "*Indones*") -or `
		($SysLocale.StartsWith("it") -and $LangName -like "*Italia*") -or `
		($SysLocale.StartsWith("ja") -and $LangName -like "*Japan*") -or `
		($SysLocale.StartsWith("ko") -and $LangName -like "*Korea*") -or `
		($SysLocale.StartsWith("lv") -and $LangName -like "*Latvia*") -or `
		($SysLocale.StartsWith("lt") -and $LangName -like "*Lithuania*") -or `
		($SysLocale.StartsWith("ms") -and $LangName -like "*Malay*") -or `
		($SysLocale.StartsWith("nb") -and $LangName -like "*Norw*") -or `
		($SysLocale.StartsWith("fa") -and $LangName -like "*Persia*") -or `
		($SysLocale.StartsWith("pl") -and $LangName -like "*Polish*") -or `
		($SysLocale -eq "pt-PT" -and $LangName -eq "Portuguese") -or `
		($SysLocale.StartsWith("ro") -and $LangName -like "*Romania*") -or `
		($SysLocale.StartsWith("ru") -and $LangName -like "*Russia*") -or `
		($SysLocale.StartsWith("sr") -and $LangName -like "*Serbia*") -or `
		($SysLocale.StartsWith("sk") -and $LangName -like "*Slovak*") -or `
		($SysLocale.StartsWith("sl") -and $LangName -like "*Slovenia*") -or `
		($SysLocale -eq "es-ES" -and $LangName -eq "Spanish") -or `
		($SysLocale.StartsWith("es") -and $Locale -ne "es-ES" -and $LangName -like "*Spanish*") -or `
		($SysLocale.StartsWith("sv") -and $LangName -like "*Swed*") -or `
		($SysLocale.StartsWith("th") -and $LangName -like "*Thai*") -or `
		($SysLocale.StartsWith("tr") -and $LangName -like "*Turk*") -or `
		($SysLocale.StartsWith("uk") -and $LangName -like "*Ukrain*") -or `
		($SysLocale.StartsWith("vi") -and $LangName -like "*Vietnam*")) {
		return $true
	}
	return $false
}

function Add-Entry([int]$pos, [string]$Name, [array]$Items, [string]$DisplayName)
{
	$Title = New-Object System.Windows.Controls.TextBlock
	$Title.FontSize = $WindowsVersionTitle.FontSize
	$Title.Height = $WindowsVersionTitle.Height;
	$Title.Width = $WindowsVersionTitle.Width;
	$Title.HorizontalAlignment = "Left"
	$Title.VerticalAlignment = "Top"
	$Margin = $WindowsVersionTitle.Margin
	$Margin.Top += $pos * $dh
	$Title.Margin = $Margin
	$Title.Text = Get-Translation($Name)
	$XMLGrid.Children.Insert(2 * $Stage + 2, $Title)

	$Combo = New-Object System.Windows.Controls.ComboBox
	$Combo.FontSize = $WindowsVersion.FontSize
	$Combo.Height = $WindowsVersion.Height;
	$Combo.Width = $WindowsVersion.Width;
	$Combo.HorizontalAlignment = "Left"
	$Combo.VerticalAlignment = "Top"
	$Margin = $WindowsVersion.Margin
	$Margin.Top += $pos * $script:dh
	$Combo.Margin = $Margin
	$Combo.SelectedIndex = 0
	if ($Items) {
		$Combo.ItemsSource = $Items
		if ($DisplayName) {
			$Combo.DisplayMemberPath = $DisplayName
		} else {
			$Combo.DisplayMemberPath = $Name
		}
	}
	$XMLGrid.Children.Insert(2 * $Stage + 3, $Combo)

	$XMLForm.Height += $dh;
	$Margin = $Continue.Margin
	$Margin.Top += $dh
	$Continue.Margin = $Margin
	$Margin = $Back.Margin
	$Margin.Top += $dh
	$Back.Margin = $Margin

	return $Combo
}

function Refresh-Control([object]$Control)
{
	$Control.Dispatcher.Invoke("Render", [Windows.Input.InputEventHandler] { $Continue.UpdateLayout() }, $null, $null) | Out-Null
}

function Send-Message([string]$PipeName, [string]$Message)
{
	[System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
	$Pipe = New-Object -TypeName System.IO.Pipes.NamedPipeClientStream -ArgumentList ".", $PipeName, ([System.IO.Pipes.PipeDirection]::Out), ([System.IO.Pipes.PipeOptions]::None), ([System.Security.Principal.TokenImpersonationLevel]::Impersonation)
	try {
		$Pipe.Connect(1000)
	} catch {
		Write-Host $_.Exception.Message
	}
	$bRequest = $Encoding.GetBytes($Message)
	$cbRequest = $bRequest.Length;
	$Pipe.Write($bRequest, 0, $cbRequest);
	$Pipe.Dispose()
}

function ConvertTo-ImageSource
{
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[System.Drawing.Icon]$Icon
	)

	Process {
		foreach ($i in $Icon) {
			[System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
				$i.Handle,
				(New-Object System.Windows.Int32Rect -Args 0,0,$i.Width, $i.Height),
				[System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions()
			)
		}
	}
}

function Get-Translation([string]$Text)
{
	if (!($English -contains $Text)) {
		Write-Host "Ошибка: '$Text' не является переводимой строкой"
		return "(Без перевода)"
	}
	if ($Localized) {
		if ($Localized.Length -ne $English.Length) {
			Write-Host "Ошибка: '$Text' не является переводимой строкой"
		}
		for ($i = 0; $i -lt $English.Length; $i++) {
			if ($English[$i] -eq $Text) {
				if ($Localized[$i]) {
					return $Localized[$i]
				} else {
					return $Text
				}
			}
		}
	}
	return $Text
}

function Get-Arch
{
	$Arch = Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty Architecture
	switch($Arch) {
	0  { return "x86" }
	1  { return "MIPS" }
	2  { return "Alpha" }
	3  { return "PowerPC" }
	5  { return "ARM32" }
	6  { return "IA64" }
	9  { return "x64" }
	12 { return "ARM64" }
	default { return "Unknown"}
	}
}

function Get-Arch-From-Type([int]$Type)
{
	switch($Type) {
	0 { return "x86" }
	1 { return "x64" }
	2 { return "ARM64" }
	default { return "Unknown"}
	}
}

function Error([string]$ErrorMessage)
{
	Write-Host Ошибка: $ErrorMessage
	if (!$Cmd) {
		$XMLForm.Title = $(Get-Translation("Error")) + ": " + $ErrorMessage
		Refresh-Control($XMLForm)
		$XMLGrid.Children[2 * $script:Stage + 1].IsEnabled = $true
		$UserInput = [System.Windows.MessageBox]::Show($XMLForm.Title,  $(Get-Translation("Error")), "OK", "Error")
		$script:Stage--
	} else {
		$script:ExitCode = 2
	}
}

#region Form
[xml]$XAML = @"
<Window xmlns = "http://schemas.microsoft.com/winfx/2006/xaml/presentation" Height = "162" Width = "384" ResizeMode = "NoResize">
	<Grid Name = "XMLGrid">
		<Button Name = "Continue" FontSize = "16" Height = "26" Width = "160" HorizontalAlignment = "Left" VerticalAlignment = "Top" Margin = "14,78,0,0"/>
		<Button Name = "Back" FontSize = "16" Height = "26" Width = "160" HorizontalAlignment = "Left" VerticalAlignment = "Top" Margin = "194,78,0,0"/>
		<TextBlock Name = "WindowsVersionTitle" FontSize = "16" Width="340" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="16,8,0,0"/>
		<ComboBox Name = "WindowsVersion" FontSize = "14" Height = "24" Width = "340" HorizontalAlignment = "Left" VerticalAlignment="Top" Margin = "14,34,0,0" SelectedIndex = "0"/>
		<CheckBox Name = "Check" FontSize = "14" Width = "340" HorizontalAlignment = "Left" VerticalAlignment="Top" Margin = "14,0,0,0" Visibility="Collapsed" />
	</Grid>
</Window>
"@
#endregion

#region Globals
$ErrorActionPreference = "Stop"
$DefaultTimeout = 30
$dh = 58
$Stage = 0
$SelectedIndex = 0
$ltrm = ""
if ($Cmd) {
	$ltrm = ""
}
$MaxStage = 4
$SessionId = @($null) * 2
$ExitCode = 100
$Locale = $Locale
$OrgId = "y6jn8c31"
$ProfileId = "606624d44113"
$Verbosity = 1
if ($Debug) {
	$Verbosity = 5
} elseif ($Verbose) {
	$Verbosity = 2
} elseif ($Cmd -and $GetUrl) {
	$Verbosity = 0
}
if (!$PlatformArch) {
	$PlatformArch = Get-Arch
}
#endregion

$EnglishMessages = "en-US|Version|Release|Edition|Language|Architecture|Download|Continue|Back|Close|Cancel|Error|Please wait...|" +
	"Download using a browser|Download of Windows ISOs is unavailable due to Microsoft having altered their website to prevent it.|" +
	"PowerShell 3.0 or later is required to run this script.|Do you want to go online and download it?|" +
	"This feature is not available on this platform."
[string[]]$English = $EnglishMessages.Split('|')
[string[]]$Localized = $null
if ($LocData -and !$LocData.StartsWith("en-US")) {
	$Localized = $LocData.Split('|')
	if ($Localized.Length -lt $English.Length) {
		while ($Localized.Length -ne $English.Length) {
			$Localized += $English[$Localized.Length]
		}
	} elseif ($Localized.Length -gt $English.Length) {
		$Localized = $LocData.Split('|')[0..($English.Length - 1)]
	}
	$Locale = $Localized[0]
}
$QueryLocale = $Locale

function Size-To-Human-Readable([uint64]$size)
{
	$suffix = "bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"
	$i = 0
	while ($size -gt 1kb) {
		$size = $size / 1kb
		$i++
	}
	"{0:N1} {1}" -f $size, $suffix[$i]
}

function Check-Locale
{
	try {
		$url = "https://www.microsoft.com/" + $QueryLocale + "/software-download/"
		if ($Verbosity -ge 2) {
			Write-Host Запрашивается $url
		}
		Invoke-WebRequest -UseBasicParsing -TimeoutSec $DefaultTimeout -MaximumRedirection 0 $url | Out-Null
	} catch {
		if ($_.Exception.Status -eq "Timeout" -or $_.Exception.GetType().Name -eq "TaskCanceledException") {
			Write-Host Операция превысила время ожидания
		}
		$script:QueryLocale = "en-US"
	}
}

function Get-Code-715-123130-Message
{
	try {
		$url = "https://www.microsoft.com/" + $QueryLocale + "/software-download/windows11"
		if ($Verbosity -ge 2) {
			Write-Host Запрашивается $url
		}
		$r = Invoke-WebRequest -UseBasicParsing -TimeoutSec $DefaultTimeout -MaximumRedirection 0 $url
		$r = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
		$r = $r -replace "`n" -replace "`r"
		$pattern = '.*<input id="msg-01" type="hidden" value="(.*?)"/>.*'
		$msg = [regex]::Match($r, $pattern).Groups[1].Value
		$msg = $msg -replace "&lt;", "<" -replace "<[^>]+>" -replace "\s+", " "
		if (($msg -eq $null) -or !($msg -match "715-123130")) {
			throw
		}
	} catch {
		$msg  = "Ваш IP-адрес заблокирован Microsoft за слишком большое количество запросов на скачивание ISO или "
		$msg += "за принадлежность к региону, где действуют санкции. Попробуйте снова позже.`r`n"
		$msg += "Если вы считаете блокировку ошибочной, обратитесь в Microsoft, указав код ошибки 715-123130 и ID сессии "
	}
	return $msg
}

function Get-Windows-Releases([int]$SelectedVersion)
{
	$i = 0
	$releases = @()
	foreach ($version in $WindowsVersions[$SelectedVersion]) {
		if (($i -ne 0) -and ($version -is [array])) {
			$releases += @(New-Object PsObject -Property @{ Release = $ltrm + $version[0].Replace(")", ")" + $ltrm); Index = $i })
		}
		$i++
	}
	return $releases
}

function Get-Windows-Editions([int]$SelectedVersion, [int]$SelectedRelease)
{
	$editions = @()
	foreach ($release in $WindowsVersions[$SelectedVersion][$SelectedRelease])
	{
		if ($release -is [array]) {
			if (!($release[0].Contains("China")) -or ($Locale.StartsWith("zh"))) {
				$editions += @(New-Object PsObject -Property @{ Edition = $release[0]; Id = $release[1] })
			}
		}
	}
	return $editions
}

function Get-Windows-Languages([int]$SelectedVersion, [object]$SelectedEdition)
{
	$langs = @()
	if ($WindowsVersions[$SelectedVersion][0][1].StartsWith("UEFI_SHELL")) {
		$langs += @(New-Object PsObject -Property @{ DisplayName = "English (US)"; Name = "en-us"; Data = @($null) })
	} elseif ($WindowsVersions[$SelectedVersion][0][1] -match "_ru_vds$") { # Обработка наших жестких ссылок
		# Для жестких ссылок VDS всегда возвращаем только русский язык
		$langs += @(New-Object PsObject -Property @{ DisplayName = "Русский (Россия)"; Name = "ru-ru"; Data = @(@{SkuId = "vds"}) })
	} else {
		$languages = [ordered]@{}
		$SessionIndex = 0
		foreach ($EditionId in $SelectedEdition) {
			if (!$BypassGeo) {
				$SessionId[$SessionIndex] = [guid]::NewGuid()
				$url = "https://vlscppe.microsoft.com/tags"
				$url += "?org_id=" + $OrgId
				$url += "&session_id=" + $SessionId[$SessionIndex]
				if ($Verbosity -ge 2) {
					Write-Host Запрашивается $url
				}
				try {
					Invoke-WebRequest -UseBasicParsing -TimeoutSec $DefaultTimeout -MaximumRedirection 0 $url | Out-Null
				} catch {
					Error($_.Exception.Message)
					return @()
				}
				$url = "https://www.microsoft.com/software-download-connector/api/getskuinformationbyproductedition"
				$url += "?profile=" + $ProfileId
				$url += "&productEditionId=" + $EditionId
				$url += "&SKU=undefined"
				$url += "&friendlyFileName=undefined"
				$url += "&Locale=" + $QueryLocale
				$url += "&sessionID=" + $SessionId[$SessionIndex]
				if ($Verbosity -ge 2) {
					Write-Host Запрашивается $url
				}
			} else {
				$url = "https://api.gravesoft.dev/msdl/skuinfo?product_id=" + $EditionId
				if ($Verbosity -ge 2) {
					Write-Host "Запрашивается $url (через прокси Gravesoft)"
				}
			}
			try {
				$r = Invoke-RestMethod -UseBasicParsing -TimeoutSec $DefaultTimeout -SessionVariable "Session" $url
				if ($r -eq $null) {
					throw "Не удалось получить список языков с сервера"
				}
				if ($Verbosity -ge 5) {
					Write-Host "=============================================================================="
					Write-Host ($r | ConvertTo-Json)
					Write-Host "=============================================================================="
				}
				if (!$BypassGeo -and $r.Errors) {
					throw $r.Errors[0].Value
				}
				foreach ($Sku in $r.Skus) {
					$LanguageKey = If ($BypassGeo) { $Sku.Language } Else { $Sku.LocalizedLanguage }
					$DisplayName = If ($BypassGeo) { $Sku.LocalizedLanguage } Else { $Sku.LocalizedLanguage }
					if (!$languages.Contains($LanguageKey)) {
						$languages[$LanguageKey] = @{ DisplayName = $DisplayName; Data = @() }
					}
					$dataEntry = @{ SkuId = $Sku.Id }
					if (!$BypassGeo) {
						$dataEntry.SessionIndex = $SessionIndex
					} else {
						# Убедиться, что ProductId всегда передается для Gravesoft
						$dataEntry.ProductId = $EditionId
					}
					$languages[$LanguageKey].Data += $dataEntry
				}
				if ($languages.Length -eq 0) {
					throw "Не удалось разобрать список языков"
				}
			} catch {
				Error($_.Exception.Message)
				return @()
			}
			$SessionIndex++
		}
		$i = 0
		$script:SelectedIndex = 0
		foreach($language in $languages.Keys) {
			$langs += @(New-Object PsObject -Property @{ DisplayName = $languages[$language].DisplayName; Name = $language; Data = $languages[$language].Data })
			if (Select-Language($language)) {
				$script:SelectedIndex = $i
			}
			$i++
		}
	}
	return $langs
}

function Get-Windows-Download-Links([int]$SelectedVersion, [int]$SelectedRelease, [object]$SelectedEdition, [PSCustomObject]$SelectedLanguage)
{
	$links = @()
	if ($WindowsVersions[$SelectedVersion][0][1].StartsWith("UEFI_SHELL")) {
		$tag = $WindowsVersions[$SelectedVersion][$SelectedRelease][0].Split(' ')[0]
		$shell_version = $WindowsVersions[$SelectedVersion][0][1].Split(' ')[1]
		$url = "https://github.com/pbatard/UEFI-Shell/releases/download/" + $tag
		$link = $url + "/UEFI-Shell-" + $shell_version + "-" + $tag
		if ($SelectedEdition -eq 0) {
			$link += "-RELEASE.iso"
		} else {
			$link += "-DEBUG.iso"
		}
		try {
			$url += "/Version.xml"
			$xml = New-Object System.Xml.XmlDocument
			if ($Verbosity -ge 2) {
				Write-Host Запрашивается $url
			}
			$xml.Load($url)
			$sep = ""
			$archs = ""
			foreach($arch in $xml.release.supported_archs.arch) {
				$archs += $sep + $arch
				$sep = ", "
			}
			$links += @(New-Object PsObject -Property @{ Arch = $archs; Url = $link })
		} catch {
			Error($_.Exception.Message)
			return @()
		}
	} elseif ($WindowsVersions[$SelectedVersion][0][1] -eq "win11_ltsc_2024_ru_vds") {
		# Win 11 LTSC x64 24H2 b.26100.1742
		$link = "https://s3.twcstorage.ru/35761667-winiso/win/ru-ru_windows_11_enterprise_ltsc_2024_x64_dvd_f9af5773.iso"
		$links += @(New-Object PsObject -Property @{ Arch = "x64"; Url = $link })
	} elseif ($WindowsVersions[$SelectedVersion][0][1] -eq "win10_ltsc_2021_x64_ru_vds") {
		# Win 10 LTSC 2021 21H2 b.19044.1288 x64
		$link = "https://s3.twcstorage.ru/35761667-winiso/win/ru-ru_windows_10_enterprise_ltsc_2021_x64_dvd_5044a1e7.iso"
		$links += @(New-Object PsObject -Property @{ Arch = "x64"; Url = $link })
	} elseif ($WindowsVersions[$SelectedVersion][0][1] -eq "win10_ltsc_2021_x86_ru_vds") {
		# Win 10 LTSC 2021 21H2 b.19044.1288 x86
		$link = "https://s3.twcstorage.ru/35761667-winiso/win/ru-ru_windows_10_enterprise_ltsc_2021_x86_dvd_cdf355eb.iso"
		$links += @(New-Object PsObject -Property @{ Arch = "x86"; Url = $link })
	} else {
		foreach ($Entry in $SelectedLanguage.Data) {
			if (!$BypassGeo) {
				$url = "https://www.microsoft.com/software-download-connector/api/GetProductDownloadLinksBySku"
				$url += "?profile=" + $ProfileId
				$url += "&productEditionId=undefined"
				$url += "&SKU=" + $Entry.SkuId
				$url += "&friendlyFileName=undefined"
				$url += "&Locale=" + $QueryLocale
				$url += "&sessionID=" + $SessionId[$Entry.SessionIndex]
				if ($Verbosity -ge 2) {
					Write-Host Запрашивается $url
				}
				$ref = "https://www.microsoft.com/software-download/windows11"
			} else {
				# Для Gravesoft API ProductId и SkuId должны быть определены
				if (-not $Entry.ProductId -or -not $Entry.SkuId) {
					throw "Ошибка: Не удалось получить ProductId или SkuId для запроса Gravesoft API."
				}
				$url = "https://api.gravesoft.dev/msdl/proxy?product_id=" + $Entry.ProductId + "&sku_id=" + $Entry.SkuId
				if ($Verbosity -ge 2) {
					Write-Host "Запрашивается $url (через прокси Gravesoft)"
				}
			}
			try {
				if (!$BypassGeo) {
					$r = Invoke-RestMethod -Headers @{ "Referer" = $ref } -UseBasicParsing -TimeoutSec $DefaultTimeout -SessionVariable "Session" $url
				} else {
					$r = Invoke-RestMethod -UseBasicParsing -TimeoutSec $DefaultTimeout -SessionVariable "Session" $url # <<< ИЗМЕНЕНИЕ ЗДЕСЬ
				}
				if ($r -eq $null) {
					throw "Не удалось получить архитектуры с сервера"
				}
				if ($Verbosity -ge 5) {
					Write-Host "=============================================================================="
					Write-Host ($r | ConvertTo-Json)
					Write-Host "=============================================================================="
				}
				if (!$BypassGeo) {
					if ($r.Errors) {
						if ($r.Errors[0].Type -eq 9) {
							$msg = Get-Code-715-123130-Message
							throw $msg + $SessionId[$Entry.SessionIndex] + "."
						} else {
							throw $r.Errors[0].Value
						}
					}
				} else {
					if ($r.ValidationContainer.Errors.Count -gt 0) {
						throw $r.ValidationContainer.Errors[0].Value
					}
				}
				foreach ($ProductDownloadOption in $r.ProductDownloadOptions) {
					$links += @(New-Object PsObject -Property @{ Arch = (Get-Arch-From-Type $ProductDownloadOption.DownloadType); Url = $ProductDownloadOption.Uri })
				}
				if ($links.Length -eq 0) {
					throw "Не удалось получить ссылки на скачивание ISO"
				}
			} catch {
				Error($_.Exception.Message)
				return @()
			}
		}
	}
	$i = 0
	$script:SelectedIndex = 0
	foreach($link in $links) {
		if ($link.Arch -eq $PlatformArch) {
			$script:SelectedIndex = $i
		}
		$i++
	}
	return $links
}

function Process-Download-Link([string]$Url)
{
	try {
		if ($PipeName -and !$Check.IsChecked) {
			Send-Message -PipeName $PipeName -Message $Url
		} else {
			if ($Cmd) {
				$pattern = '.*\/(.*\.iso).*'
				$File = [regex]::Match($Url, $pattern).Groups[1].Value
				if (-not $File) {
					$File = "Windows_10_Enterprise.iso"
				}
				$str_size = (Invoke-WebRequest -UseBasicParsing -TimeoutSec $DefaultTimeout -Uri $Url -Method Head).Headers.'Content-Length'
				$tmp_size = [uint64]::Parse($str_size)
				$Size = Size-To-Human-Readable $tmp_size
				Write-Host "Скачивается '$File' ($Size)..."
				Start-BitsTransfer -Source $Url -Destination $File
			} else {
				Write-Host Ссылка для скачивания: $Url
				Start-Process -FilePath $Url
			}
		}
	} catch {
		Error($_.Exception.Message)
		return 404
	}
	return 0
}

if ($Cmd) {
	$winVersionId = $null
	$winReleaseId = $null
	$winEditionId = $null
	$winLanguageId = $null
	$winLanguageName = $null
	$winLink = $null

	if ($winver -le 6.1) {
		Error(Get-Translation("Эта функция недоступна на данной платформе."))
		exit 403
	}

	$i = 0
	$Selected = ""
	if ($Win -eq "List") {
		Write-Host "Пожалуйста, выберите версию Windows (-Win):"
	}
	foreach($version in $WindowsVersions) {
		if ($Win -eq "List") {
			Write-Host " -" $version[0][0]
		} elseif ($version[0][0] -match $Win) {
			$Selected += $version[0][0]
			$winVersionId = $i
			break;
		}
		$i++
	}
	if ($winVersionId -eq $null) {
		if ($Win -ne "List") {
			Write-Host "Указана неверная версия Windows."
			Write-Host "Используйте '-Win List' для списка доступных версий Windows."
		}
		exit 1
	}

	$releases = Get-Windows-Releases $winVersionId
	if ($Rel -eq "List") {
		Write-Host "Пожалуйста, выберите релиз Windows (-Rel) для ${Selected} (или используйте 'Latest' для самого свежего):"
	}
	foreach ($release in $releases) {
		if ($Rel -eq "List") {
			Write-Host " -" $release.Release
		} elseif (!$Rel -or $release.Release.StartsWith($Rel) -or $Rel -eq "Latest") {
			if (!$Rel -and $Verbosity -ge 1) {
				Write-Host "Релиз не указан (-Rel). Используется по умолчанию '$($release.Release)'."
			}
			$Selected += " " + $release.Release
			$winReleaseId = $release.Index
			break;
		}
	}
	if ($winReleaseId -eq $null) {
		if ($Rel -ne "List") {
			Write-Host "Указан неверный релиз Windows."
			Write-Host "Используйте '-Rel List' для списка доступных релизов $Selected или '-Rel Latest' для самого свежего."
		}
		exit 1
	}

	$editions = Get-Windows-Editions $winVersionId $winReleaseId
	if ($Ed -eq "List") {
		Write-Host "Пожалуйста, выберите редакцию Windows (-Ed) для ${Selected}:"
	}
	foreach($edition in $editions) {
		if ($Ed -eq "List") {
			Write-Host " -" $edition.Edition
		} elseif (!$Ed -or $edition.Edition -match $Ed) {
			if (!$Ed -and $Verbosity -ge 1) {
				Write-Host "Редакция не указана (-Ed). Используется по умолчанию '$($edition.Edition)'."
			}
			$Selected += "," + $edition.Edition -replace "Windows [0-9\.]*"
			$winEditionId = $edition.Id
			break;
		}
	}
	if ($winEditionId -eq $null) {
		if ($Ed -ne "List") {
			Write-Host "Указана неверная редакция Windows."
			Write-Host "Используйте '-Ed List' для списка доступных редакций или уберите параметр -Ed для значения по умолчанию."
		}
		exit 1
	}

	$languages = Get-Windows-Languages $winVersionId $winEditionId
	if (!$languages) {
		exit 3
	}
	if ($Lang -eq "List") {
		Write-Host "Пожалуйста, выберите язык (-Lang) для ${Selected}:"
	} elseif ($Lang) {
		$Lang = $Lang.replace('(', '\(')
		$Lang = $Lang.replace(')', '\)')
	}
	$i = 0
	$winLanguage = $null
	foreach ($language in $languages) {
		if ($Lang -eq "List") {
			Write-Host " -" $language.Name
		} elseif ((!$Lang -and $script:SelectedIndex -eq $i) -or ($Lang -and $language.Name -match $Lang)) {
			if (!$Lang -and $Verbosity -ge 1) {
				Write-Host "Язык не указан (-Lang). Используется по умолчанию '$($language.Name)'."
			}
			$Selected += ", " + $language.Name
			$winLanguage = $language
			break;
		}
		$i++
	}
	if ($winLanguage -eq $null) {
		if ($Lang -ne "List") {
			Write-Host "Указан неверный язык Windows."
			Write-Host "Используйте '-Lang List' для списка доступных языков или уберите параметр для системного языка по умолчанию."
		}
		exit 1
	}

	$links = Get-Windows-Download-Links $winVersionId $winReleaseId $winEditionId $winLanguage
	if (!$links) {
		exit 3
	}
	if ($Arch -eq "List") {
		Write-Host "Пожалуйста, выберите архитектуру (-Arch) для ${Selected}:"
	}
	$i = 0
	foreach ($link in $links) {
		if ($Arch -eq "List") {
			Write-Host " -" $link.Arch
		} elseif ((!$Arch -and $script:SelectedIndex -eq $i) -or ($Arch -and $link.Arch -match $Arch)) {
			if (!$Arch -and $Verbosity -ge 1) {
				Write-Host "Архитектура не указана (-Arch). Используется по умолчанию '$($link.Arch)'."
			}
			$Selected += ", [" + $link.Arch + "]"
			$winLink = $link
			break;
		}
		$i++
	}
	if ($winLink -eq $null) {
		if ($Arch -ne "List") {
			Write-Host "Указана неверная архитектура Windows."
			Write-Host "Используйте '-Arch List' для списка доступных архитектур или уберите параметр для системной архитектуры по умолчанию."
		}
		exit 1
	}

	if ($GetUrl) {
		return $winLink.Url
		$ExitCode = 0
	} else {
		Write-Host "Выбрано: $Selected"
		$ExitCode = Process-Download-Link $winLink.Url
	}

	exit $ExitCode
}

$XMLForm = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $XAML))
$XAML.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $XMLForm.FindName($_.Name) -Scope Script }
$XMLForm.Title = $AppTitle
if ($Icon) {
	$XMLForm.Icon = $Icon
} else {
	$XMLForm.Icon = [WinAPI.Utils]::ExtractIcon("imageres.dll", -5205, $true) | ConvertTo-ImageSource
}
if ($Locale.StartsWith("ar") -or $Locale.StartsWith("fa") -or $Locale.StartsWith("he")) {
	$XMLForm.FlowDirection = "RightToLeft"
}
$WindowsVersionTitle.Text = Get-Translation("Version")
$Continue.Content = Get-Translation("Continue")
$Back.Content = Get-Translation("Close")

if ($winver -le 6.1) {
	Error(Get-Translation("Эта функция недоступна на данной платформе."))
	exit 403
}

$i = 0
$versions = @()
foreach($version in $WindowsVersions) {
	$versions += @(New-Object PsObject -Property @{ Version = $version[0][0]; PageType = $version[0][1]; Index = $i })
	$i++
}
$WindowsVersion.ItemsSource = $versions
$WindowsVersion.DisplayMemberPath = "Version"

$Continue.add_click({
	$script:Stage++
	$XMLGrid.Children[2 * $Stage + 1].IsEnabled = $false
	$Continue.IsEnabled = $false
	$Back.IsEnabled = $false
	Refresh-Control($Continue)
	Refresh-Control($Back)

	switch ($Stage) {
		1 {
			$XMLForm.Title = Get-Translation($English[12])
			Refresh-Control($XMLForm)
			if ($WindowsVersion.SelectedValue.Version.StartsWith("Windows")) {
				Check-Locale
			}
			$releases = Get-Windows-Releases $WindowsVersion.SelectedValue.Index
			$script:WindowsRelease = Add-Entry $Stage "Release" $releases
			$Back.Content = Get-Translation($English[8])
			$XMLForm.Title = $AppTitle
		}
		2 {
			$editions = Get-Windows-Editions $WindowsVersion.SelectedValue.Index $WindowsRelease.SelectedValue.Index
			$script:ProductEdition = Add-Entry $Stage "Edition" $editions
		}
		3 {
			$XMLForm.Title = Get-Translation($English[12])
			Refresh-Control($XMLForm)
			$languages = Get-Windows-Languages $WindowsVersion.SelectedValue.Index $ProductEdition.SelectedValue.Id
			if ($languages.Length -eq 0) {
				$script:Stage--
				$XMLGrid.Children[2 * ($Stage + 1) + 1].IsEnabled = $true
				Error("Не удалось получить список языков")
				break
			}
			$script:Language = Add-Entry $Stage "Language" $languages "DisplayName"
			$Language.SelectedIndex = $script:SelectedIndex
			$XMLForm.Title = $AppTitle
		}
		4 {
			$XMLForm.Title = Get-Translation($English[12])
			Refresh-Control($XMLForm)
			$links = Get-Windows-Download-Links $WindowsVersion.SelectedValue.Index $WindowsRelease.SelectedValue.Index $ProductEdition.SelectedValue.Id $Language.SelectedValue
			if ($links.Length -eq 0) {
				$script:Stage--
				$XMLGrid.Children[2 * ($Stage + 1) + 1].IsEnabled = $true
				Error("Не удалось получить ссылки на скачивание ISO")
				break
			}
			$script:Architecture = Add-Entry $Stage "Architecture" $links "Arch"
			if ($PipeName) {
				$XMLForm.Height += $dh / 2;
				$Margin = $Continue.Margin
				$top = $Margin.Top
				$Margin.Top += $dh / 2
				$Continue.Margin = $Margin
				$Margin = $Back.Margin
				$Margin.Top += $dh / 2
				$Back.Margin = $Margin
				$Margin = $Check.Margin
				$Margin.Top = $top - 2
				$Check.Margin = $Margin
				$Check.Content = Get-Translation($English[13])
				$Check.Visibility = "Visible"
			}
			$Architecture.SelectedIndex = $script:SelectedIndex
			$Continue.Content = Get-Translation("Download")
			$XMLForm.Title = $AppTitle
		}
		5 {
			$script:ExitCode = Process-Download-Link $Architecture.SelectedValue.Url
			$XMLForm.Close()
		}
	}
	$Continue.IsEnabled = $true
	if ($Stage -ge 0) {
		$Back.IsEnabled = $true
	}
})

$Back.add_click({
	if ($Stage -eq 0) {
		$XMLForm.Close()
	} else {
		$XMLGrid.Children.RemoveAt(2 * $Stage + 3)
		$XMLGrid.Children.RemoveAt(2 * $Stage + 2)
		$XMLGrid.Children[2 * $Stage + 1].IsEnabled = $true
		$dh2 = $dh
		if ($Stage -eq 4 -and $PipeName) {
			$Check.Visibility = "Collapsed"
			$dh2 += $dh / 2
		}
		$XMLForm.Height -= $dh2;
		$Margin = $Continue.Margin
		$Margin.Top -= $dh2
		$Continue.Margin = $Margin
		$Margin = $Back.Margin
		$Margin.Top -= $dh2
		$Back.Margin = $Margin
		$script:Stage = $Stage - 1
		$XMLForm.Title = $AppTitle
		if ($Stage -eq 0) {
			$Back.Content = Get-Translation("Close")
		} else {
			$Continue.Content = Get-Translation("Continue")
			Refresh-Control($Continue)
		}
	}
})

$XMLForm.Add_Loaded({$XMLForm.Activate()})
$XMLForm.ShowDialog() | Out-Null

exit $ExitCode