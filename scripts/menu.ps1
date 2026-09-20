#Requires -Version 7.6

<#
.SYNOPSIS
The shared arrow-key console menu for bevry-vibes PowerShell tools (PowerShell 7.6+, ANSI styling via $PSStyle).

.DESCRIPTION
Dot-source this file, then call Read-MenuChoice or Read-MultiChoice:

    . $menuPath
    $index = Read-MenuChoice -Rows @('Alpha', 'Beta', 'Quit') -Initial 0
    $picked = Read-MultiChoice -Options $options -Title 'Select things'

Read-MenuChoice is the single-choice menu. The user moves with the Up/Down arrow keys (wrap-around) or j/k, jumps with Home/End, confirms with Enter, jumps to a row with the digit keys, backs out with Esc, and aborts with Ctrl+C. It returns the 0-based index of the chosen row, -1 for Esc ("back"), or -2 for Ctrl+C ("abort").

Read-MultiChoice is the full-height multi-choice menu: rows scroll inside the console window, each option shows a caller-styled label with optional dim detail lines underneath, locked rows cannot be selected, and the footer carries a live summary of the current selection. It returns the chosen option objects (an empty array means "confirmed nothing"), or $null when cancelled or aborted.

Resolve this file through a sibling checkout of bevry-vibes/skills, a cache, or a download - see the "shared console menu" section of bevry-vibes/skills powershell.md for the canonical bootstrap.

Running this file directly (pwsh menu.ps1) shows a demo of both menus.

Limitations: rows and labels must be single-line; the row count must fit within the console buffer height (Read-MultiChoice scrolls, Read-MenuChoice does not); an interactive console is required (both functions throw if input is redirected).

License: Reciprocal Public License 1.5 <http://spdx.org/licenses/RPL-1.5.html>
https://github.com/bevry-vibes/skills
#>


# ---------------------------------------------------------------------------
# Show an interactive arrow-key single-choice menu and return the chosen row.
#
# .PARAMETER Rows
# Pre-styled single-line strings, one per option. Any ANSI styling (colors, tags such as "[already the case]") is embedded by the caller; the highlighted row is shown in reverse video with a "> " prefix.
#
# .PARAMETER Initial
# 0-based index of the initially highlighted row (clamped into range).
#
# .OUTPUTS
# System.Int32 - the 0-based index of the chosen row, -1 for Esc ("back one level"), or -2 for Ctrl+C ("abort").
#
# The menu redraws in place (relative ANSI cursor-up + erase-to-end-of-line), so it updates itself without scrolling. Ctrl+C is captured as an ordinary key (TreatControlCAsInput) rather than tearing down the pipeline mid-redraw, and both that setting and cursor visibility are restored in "finally" whatever happens. The CursorVisible getter throws on some terminals (macOS), so it is only set, never read.
# ---------------------------------------------------------------------------
function Read-MenuChoice {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyCollection()]
		[string[]]$Rows,
		[int]$Initial = 0
	)

	if ($Rows.Count -eq 0) { throw 'Read-MenuChoice requires at least one row' }
	if ([Console]::IsInputRedirected) { throw 'Read-MenuChoice requires an interactive console' }

	$selected = [Math]::Min([Math]::Max($Initial, 0), $Rows.Count - 1)
	$esc = [char]27
	$highlight = $PSStyle.Reverse
	$reset = $PSStyle.Reset
	$previousTreatControlC = [Console]::TreatControlCAsInput
	# The CursorVisible getter throws on macOS, so read nothing - only set and restore.
	[Console]::TreatControlCAsInput = $true
	[Console]::CursorVisible = $false

	try {
		$firstDraw = $true
		while ($true) {
			if (-not $firstDraw) { [Console]::Write("$esc[$($Rows.Count)A") }
			$firstDraw = $false
			for ($i = 0; $i -lt $Rows.Count; $i++) {
				$line = ($i -eq $selected) ? "> $highlight$($Rows[$i])$reset" : "  $($Rows[$i])"
				[Console]::Write("$line$esc[K`r`n")
			}

			$key = [Console]::ReadKey($true)
			if ($key.Key -eq [ConsoleKey]::Enter) { return $selected }
			if ($key.Key -eq [ConsoleKey]::Escape) { return -1 }
			if ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)) { return -2 }
			if ($key.Key -eq [ConsoleKey]::UpArrow -or ([char]$key.KeyChar -eq 'k')) {
				$selected = ($selected - 1 + $Rows.Count) % $Rows.Count
			} elseif ($key.Key -eq [ConsoleKey]::DownArrow -or ([char]$key.KeyChar -eq 'j')) {
				$selected = ($selected + 1) % $Rows.Count
			} elseif ($key.Key -eq [ConsoleKey]::Home) {
				$selected = 0
			} elseif ($key.Key -eq [ConsoleKey]::End) {
				$selected = $Rows.Count - 1
			} elseif ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
				$digit = [int]::Parse($key.KeyChar.ToString())
				if ($digit -le $Rows.Count) { return ($digit - 1) }
			}
		}
	} finally {
		[Console]::TreatControlCAsInput = $previousTreatControlC
		try { [Console]::CursorVisible = $true } catch { Write-Host '' }
	}
}


# ---------------------------------------------------------------------------
# Show an interactive full-height arrow-key multi-choice menu and return the chosen options.
#
# .PARAMETER Options
# One object per row. Read the fields through these names:
#   Label  - the row headline, a single-line string the caller has already styled (the menu adds the checkbox, the focus arrow, and reverse emphasis to nothing - keep the styling inside the label).
#   Detail - optional array of single-line strings, shown dim beneath the label; extra lines beyond MaxDetailLines collapse into a "+N more" line.
#   Locked - optional boolean; a locked row renders dim with a [locked] prefix and cannot be selected.
# Absent Detail and Locked fields are tolerated.
#
# .PARAMETER Title
# Headline printed above the rows.
#
# .PARAMETER FooterSummary
# Scriptblock that takes the currently chosen Options array and returns the second footer line as a string. The default summary reports the chosen count.
#
# .PARAMETER Initial
# 0-based index of the initially focused row (clamped into the selectable rows).
#
# .PARAMETER MaxDetailLines
# Most detail lines shown per row before the rest collapse into "+N more".
#
# .OUTPUTS
# The chosen option objects as one array - an empty array means "confirmed nothing". $null means cancelled (Esc or q) or aborted (Ctrl+C).
#
# The visible rows fill the console window and scroll to keep the focused row inside it. Ctrl+C is captured as an ordinary key (TreatControlCAsInput), and that setting and cursor visibility are restored in "finally" whatever happens. The CursorVisible getter throws on some terminals (macOS), so it is only set, never read.
# ---------------------------------------------------------------------------
function Read-MultiChoice {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyCollection()]
		[pscustomobject[]]$Options,
		[string]$Title = 'Select',
		[scriptblock]$FooterSummary = { param($Chosen) "$($Chosen.Count) selected" },
		[int]$Initial = 0,
		[int]$MaxDetailLines = 4
	)

	if ($Options.Count -eq 0) { return , @() }
	if ([Console]::IsInputRedirected) { throw 'Read-MultiChoice requires an interactive console' }

	$isLocked = {
		param($Opt)
		return ($Opt.PSObject.Properties['Locked'] -and $Opt.Locked)
	}
	$focusIndex = @(for ($i = 0; $i -lt $Options.Count; $i++) { if (-not (& $isLocked $Options[$i])) { $i } })
	if ($focusIndex.Count -eq 0) { return , @() }
	$chosen = [System.Collections.Generic.HashSet[int]]::new()
	$cursor = [Math]::Min([Math]::Max($Initial, 0), $focusIndex.Count - 1)
	$top = 0
	$esc = [char]27
	$reset = $PSStyle.Reset
	$dim = $PSStyle.Dim
	$green = $PSStyle.Foreground.Green
	$bold = $PSStyle.Bold
	$previousTreatControlC = [Console]::TreatControlCAsInput

	$lineCount = {
		# headline + detail preview lines (+ an overflow line) per entry
		param($Opt)
		if (& $isLocked $Opt) { return 1 }
		$details = @($Opt.PSObject.Properties['Detail'] ? $Opt.Detail : @())
		$detailLines = [Math]::Min($details.Count, $MaxDetailLines)
		$more = ($details.Count -gt $MaxDetailLines) ? 1 : 0
		return 1 + $detailLines + $more
	}

	$headerLines = 2   # blank + title, written once below
	Write-Host ''
	Write-Host "$bold$Title$reset"

	$shown = @()
	$firstDraw = $true
	try {
		[Console]::TreatControlCAsInput = $true
		# The CursorVisible getter throws on macOS, so read nothing - only set and restore.
		[Console]::CursorVisible = $false
		while ($true) {
			# fill the window: header + footer + a one-line breathing margin
			$budget = [Math]::Max([Console]::WindowHeight - $headerLines - 3, 3)
			if ($focusIndex[$cursor] -lt $top) { $top = $focusIndex[$cursor] }

			foreach ($attempt in @($top, $focusIndex[$cursor])) {
				$shown = @()
				$lines = 0
				for ($i = $attempt; $i -lt $Options.Count; $i++) {
					$count = & $lineCount $Options[$i]
					if ($lines + $count -gt $budget -and $shown.Count -gt 0) { break }
					$shown += $i
					$lines += [Math]::Min($count, $budget - $lines)
				}
				if ($shown -contains $focusIndex[$cursor]) { $top = $attempt; break }
				# the focused entry fell outside the window - restart from it
			}

			# footer: controls + the caller's live summary over the current selection
			$chosenOptions = @($focusIndex | Where-Object { $chosen.Contains($_) } | ForEach-Object { $Options[$_] })
			$footer = @(
				"$dim up/down or j/k move · space toggle · a all · n none · enter confirm · q or esc cancel$reset"
				"$bold$(& $FooterSummary -Chosen $chosenOptions)$reset"
			)

			$out = @()
			foreach ($i in $shown) {
				$opt = $Options[$i]
				if (& $isLocked $opt) {
					$out += "$dim  [locked] $($opt.Label)$reset"
					continue
				}
				$box = $chosen.Contains($i) ? "$green[x]$reset" : '[ ]'
				$arrow = ($focusIndex[$cursor] -eq $i) ? "$bold>$reset " : '  '
				$out += "$arrow$box $($opt.Label)"
				$details = @($opt.PSObject.Properties['Detail'] ? $opt.Detail : @())
				$take = [Math]::Min($details.Count, $MaxDetailLines)
				for ($p = 0; $p -lt $take -and $out.Count -lt $budget; $p++) {
					$out += "$dim      $($details[$p])$reset"
				}
				if ($details.Count -gt $MaxDetailLines -and $out.Count -lt $budget) {
					$out += "$dim      … +$($details.Count - $MaxDetailLines) more$reset"
				}
			}

			$lastDrawn = $out.Count + $footer.Count
			if (-not $firstDraw) { [Console]::Write("$esc[$($lastDrawn)A") }
			$firstDraw = $false
			foreach ($line in $out + $footer) { [Console]::Write("$esc[2K$line`r`n") }

			$key = [Console]::ReadKey($true)
			if ($key.Key -eq [ConsoleKey]::Enter) { break }
			if ($key.Key -eq [ConsoleKey]::Escape) { return $null }
			if ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)) { return $null }
			if ($key.Key -eq [ConsoleKey]::UpArrow) {
				$cursor = ($cursor - 1 + $focusIndex.Count) % $focusIndex.Count
			} elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
				$cursor = ($cursor + 1) % $focusIndex.Count
			} elseif ($key.Key -eq [ConsoleKey]::Home) {
				$cursor = 0
			} elseif ($key.Key -eq [ConsoleKey]::End) {
				$cursor = $focusIndex.Count - 1
			} elseif ($key.Key -eq [ConsoleKey]::Spacebar) {
				$i = $focusIndex[$cursor]
				if ($chosen.Contains($i)) { [void]$chosen.Remove($i) } else { [void]$chosen.Add($i) }
			} else {
				$c = [char]$key.KeyChar
				if ($c -eq 'j') { $cursor = ($cursor + 1) % $focusIndex.Count }
				elseif ($c -eq 'k') { $cursor = ($cursor - 1 + $focusIndex.Count) % $focusIndex.Count }
				elseif ($c -eq 'a' -or $c -eq 'A') { foreach ($i in $focusIndex) { [void]$chosen.Add($i) } }
				elseif ($c -eq 'n' -or $c -eq 'N') { $chosen.Clear() }
				elseif ($c -eq 'q' -or $c -eq 'Q') { return $null }
			}
		}
	} finally {
		[Console]::TreatControlCAsInput = $previousTreatControlC
		# best-effort: some terminals reject the restore once the picker is over
		try { [Console]::CursorVisible = $true } catch { Write-Host '' }
	}
	# the comma prevents PowerShell unrolling an empty selection into $null
	$returnOptions = @($focusIndex | Where-Object { $chosen.Contains($_) } | ForEach-Object { $Options[$_] })
	return , $returnOptions
}


# --- Demo when run directly (skipped when dot-sourced). ---
if ($MyInvocation.InvocationName -ne '.') {
	$reset = $PSStyle.Reset
	Write-Host 'Demo single-choice menu (up/down + Enter, digits jump, Esc = back, Ctrl+C = quit):'
	$index = Read-MenuChoice -Rows @(
		"$($PSStyle.Foreground.Green)Alpha$reset",
		"$($PSStyle.Foreground.Yellow)Beta$reset",
		"$($PSStyle.Foreground.Magenta)Gamma$reset",
		"$($PSStyle.Dim)Quit$reset"
	)
	Write-Host "Read-MenuChoice returned: $index"

	Write-Host ''
	Write-Host 'Demo multi-choice menu (space toggles, a/n all/none, Enter confirms, q or Esc cancels):'
	$options = @(
		[pscustomobject]@{ Label = "$($PSStyle.Foreground.Green)alpha$reset$($PSStyle.Dim)  free$reset"; Detail = @('~/.config/alpha', '~/.local/share/alpha') }
		[pscustomobject]@{ Label = "$($PSStyle.Foreground.Yellow)beta$reset$($PSStyle.Dim)  paid$reset"; Detail = @('~/.config/beta', '~/.local/share/beta', '~/.cache/beta', '~/logs/beta', '~/state/beta') }
		[pscustomobject]@{ Label = 'gamma  locked by policy'; Detail = @(); Locked = $true }
	)
	$picked = Read-MultiChoice -Options $options -Title 'Select things' -FooterSummary { param($Chosen) "$($Chosen.Count) selected" }
	if ($null -eq $picked) {
		Write-Host 'Read-MultiChoice returned: cancelled'
	} else {
		Write-Host "Read-MultiChoice returned: $($picked.Count) option(s) - $($picked.Label -join ', ')"
	}
}
