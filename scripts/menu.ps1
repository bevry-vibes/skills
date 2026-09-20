#!/usr/bin/env pwsh
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

Read-MultiChoice is the full-height multi-choice menu: rows scroll inside the console window, each option shows a caller-styled label with optional dim detail lines underneath, locked rows cannot be selected, and the footer carries a live summary of the current selection. Options without an Actions field behave as checkboxes - [x] / [ ] , space toggles the row. Options with an Actions array render a hybrid radio line beneath the label and detail: ○ unchecked, ● checked, at most one action set per row, none required - space sets an action and clears its siblings, space again unsets it, and left/right (or h/l) move between a row's actions. On confirm it returns one array: checkbox rows yield the option object itself, action rows yield a wrapper carrying Index, Option, and the chosen Action string. An empty array means "confirmed nothing"; $null means cancelled (Esc or q) or aborted (Ctrl+C).

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
# Show an interactive full-height arrow-key multi-choice menu and return the chosen rows.
#
# .PARAMETER Options
# One object per row. Read the fields through these names:
#   Label  - the row headline, a single-line string the caller has already styled (the menu adds the checkbox, the focus arrow, and reverse emphasis to nothing - keep the styling inside the label).
#   Detail - optional array of single-line strings, shown dim beneath the label; extra lines beyond MaxDetailLines collapse into a "+N more" line.
#   Locked - optional boolean; a locked row renders dim with a [locked] prefix and cannot be selected.
#   Actions - optional array of action names; the row renders a hybrid radio line beneath the label and detail instead of the checkbox: ○ / ● glyphs, at most one action set per row (setting one clears the siblings), none required. space sets/unsets the focused action, left/right or h/l move between the row's actions.
# Absent Detail, Locked, and Actions fields are tolerated.
#
# .PARAMETER Title
# Headline printed above the rows.
#
# .PARAMETER FooterSummary
# Scriptblock that takes the current selection array and returns the second footer line as a string. The default summary reports the selection count.
#
# .PARAMETER Initial
# 0-based index of the initially focused row (clamped into the selectable rows).
#
# .PARAMETER MaxDetailLines
# Most detail lines shown per row before the rest collapse into "+N more".
#
# .OUTPUTS
# One array over the whole selection: a checkbox row that is ticked yields the option object itself; an action row with a set radio yields a wrapper object with Index (the row's 0-based index), Option (the option object), and Action (the chosen action name). An empty array means "confirmed nothing". $null means cancelled (Esc or q) or aborted (Ctrl+C).
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
	# the action group of a row: empty for legacy checkbox rows. both returns
	# carry the comma guard - & unrolls a single-element (or empty) array return
	# into a scalar (or $null), and 'install'[0] is 'i'.
	$getActions = {
		param($Opt)
		if ($Opt.PSObject.Properties['Actions'] -and $Opt.Actions) { return , @($Opt.Actions) }
		return , @()
	}
	$focusIndex = @(for ($i = 0; $i -lt $Options.Count; $i++) { if (-not (& $isLocked $Options[$i])) { $i } })
	if ($focusIndex.Count -eq 0) { return , @() }
	$chosen = [System.Collections.Generic.HashSet[int]]::new()
	$radioChoices = [System.Collections.Generic.Dictionary[int, int]]::new()
	$cursor = [Math]::Min([Math]::Max($Initial, 0), $focusIndex.Count - 1)
	$actionCursor = 0
	$top = 0
	$esc = [char]27
	$reset = $PSStyle.Reset
	$dim = $PSStyle.Dim
	$green = $PSStyle.Foreground.Green
	$bold = $PSStyle.Bold
	$previousTreatControlC = [Console]::TreatControlCAsInput

	# the current selection as the caller sees it: action rows with a set radio
	# contribute @{ Index; Option; Action } wrappers, ticked checkbox rows the
	# option objects themselves
	$buildSelection = {
		$selection = @()
		foreach ($i in $focusIndex) {
			$actions = & $getActions $Options[$i]
			if ($actions.Count -gt 0) {
				if ($radioChoices.ContainsKey($i)) {
					$selection += [pscustomobject]@{ Index = $i; Option = $Options[$i]; Action = [string]$actions[$radioChoices[$i]] }
				}
			} elseif ($chosen.Contains($i)) {
				$selection += $Options[$i]
			}
		}
		return , @($selection)
	}
	# the focused row's checked radio (clamped), or its first action — scriptblock
	# assignments stay local, so this returns the value instead of setting it
	$actionCursorFor = {
		$row = $focusIndex[$cursor]
		if ($radioChoices.ContainsKey($row)) { return $radioChoices[$row] }
		return 0
	}

	$lineCount = {
		# headline + detail preview lines (+ an overflow line) + the radio line per entry
		param($Opt)
		if (& $isLocked $Opt) { return 1 }
		$details = @($Opt.PSObject.Properties['Detail'] ? $Opt.Detail : @())
		$detailLines = [Math]::Min($details.Count, $MaxDetailLines)
		$more = ($details.Count -gt $MaxDetailLines) ? 1 : 0
		$radioLines = ((& $getActions $Opt).Count -gt 0) ? 1 : 0
		return 1 + $detailLines + $more + $radioLines
	}

	$headerLines = 2   # blank + title, written once below
	Write-Host ''
	Write-Host "$bold$Title$reset"

	$anyActions = @($Options | Where-Object { (& $getActions $_).Count -gt 0 }).Count -gt 0
	$controls = if ($anyActions) {
		'up/down or j/k move · left/right or h/l switch action · space set/unset · a all · n none · enter confirm · q or esc cancel'
	} else {
		'up/down or j/k move · space toggle · a all · n none · enter confirm · q or esc cancel'
	}

	$shown = @()
	$previousDrawn = 0
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
			$chosenOptions = & $buildSelection
			$footer = @(
				"$dim$controls$reset"
				"$bold$(& $FooterSummary -Chosen $chosenOptions)$reset"
			)

			$out = @()
			foreach ($i in $shown) {
				$opt = $Options[$i]
				if (& $isLocked $opt) {
					$out += "$dim  [locked] $($opt.Label)$reset"
					continue
				}
				$arrow = ($focusIndex[$cursor] -eq $i) ? "$bold>$reset " : '  '
				$actions = & $getActions $opt
				if ($actions.Count -gt 0) {
					$out += "$arrow  $($opt.Label)"
				} else {
					$box = $chosen.Contains($i) ? "$green[x]$reset" : '[ ]'
					$out += "$arrow$box $($opt.Label)"
				}
				$details = @($opt.PSObject.Properties['Detail'] ? $opt.Detail : @())
				$take = [Math]::Min($details.Count, $MaxDetailLines)
				for ($p = 0; $p -lt $take -and $out.Count -lt $budget; $p++) {
					$out += "$dim      $($details[$p])$reset"
				}
				if ($details.Count -gt $MaxDetailLines -and $out.Count -lt $budget) {
					$out += "$dim      … +$($details.Count - $MaxDetailLines) more$reset"
				}
				if ($actions.Count -gt 0 -and $out.Count -lt $budget) {
					$groups = @()
					for ($a = 0; $a -lt $actions.Count; $a++) {
						$isChosen = $radioChoices.ContainsKey($i) -and $radioChoices[$i] -eq $a
						$isFocusedAction = ($focusIndex[$cursor] -eq $i -and $a -eq $actionCursor)
						$glyph = $isChosen ? "$green●$reset" : "$dim○$reset"
						$text = $isFocusedAction ? "$bold$($actions[$a])$reset" : $actions[$a]
						$groups += "$glyph $text"
					}
					$out += "      " + ($groups -join '    ')
				}
			}

			$drawn = $out.Count + $footer.Count
			# return to the previous frame's first line - by ITS line count, not
			# this frame's: scrolling swaps rows of different heights (a locked
			# row is one line, an action row several), so the counts diverge and
			# a wrong cursor-up leaves the redraw misaligned
			if ($previousDrawn -gt 0) { [Console]::Write("$esc[$($previousDrawn)A") }
			foreach ($line in $out + $footer) { [Console]::Write("$esc[2K$line`r`n") }
			if ($previousDrawn -gt $drawn) {
				# the frame shrank: erase the surplus lines the taller previous
				# frame left below this one, then step back up so the cursor
				# stays one line below the last drawn line (the next redraw's
				# cursor-up base)
				$surplus = $previousDrawn - $drawn
				for ($s = 0; $s -lt $surplus; $s++) { [Console]::Write("$esc[2K`r`n") }
				[Console]::Write("$esc[$($surplus)A")
			}
			$previousDrawn = $drawn

			$key = [Console]::ReadKey($true)
			if ($key.Key -eq [ConsoleKey]::Enter) { break }
			if ($key.Key -eq [ConsoleKey]::Escape) { return $null }
			if ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)) { return $null }
			if ($key.Key -eq [ConsoleKey]::UpArrow) {
				$cursor = ($cursor - 1 + $focusIndex.Count) % $focusIndex.Count
				$actionCursor = [Math]::Min((& $actionCursorFor), [Math]::Max((& $getActions $Options[$focusIndex[$cursor]]).Count - 1, 0))
			} elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
				$cursor = ($cursor + 1) % $focusIndex.Count
				$actionCursor = [Math]::Min((& $actionCursorFor), [Math]::Max((& $getActions $Options[$focusIndex[$cursor]]).Count - 1, 0))
			} elseif ($key.Key -eq [ConsoleKey]::Home) {
				$cursor = 0
				$actionCursor = [Math]::Min((& $actionCursorFor), [Math]::Max((& $getActions $Options[$focusIndex[$cursor]]).Count - 1, 0))
			} elseif ($key.Key -eq [ConsoleKey]::End) {
				$cursor = $focusIndex.Count - 1
				$actionCursor = [Math]::Min((& $actionCursorFor), [Math]::Max((& $getActions $Options[$focusIndex[$cursor]]).Count - 1, 0))
			} elseif ($key.Key -eq [ConsoleKey]::LeftArrow) {
				$actions = & $getActions $Options[$focusIndex[$cursor]]
				if ($actions.Count -gt 1) { $actionCursor = ($actionCursor - 1 + $actions.Count) % $actions.Count }
			} elseif ($key.Key -eq [ConsoleKey]::RightArrow) {
				$actions = & $getActions $Options[$focusIndex[$cursor]]
				if ($actions.Count -gt 1) { $actionCursor = ($actionCursor + 1) % $actions.Count }
			} elseif ($key.Key -eq [ConsoleKey]::Spacebar) {
				$i = $focusIndex[$cursor]
				$actions = & $getActions $Options[$i]
				if ($actions.Count -gt 0) {
					# hybrid radio: setting one action clears the siblings; setting it again unsets
					if ($radioChoices.ContainsKey($i) -and $radioChoices[$i] -eq $actionCursor) {
						[void]$radioChoices.Remove($i)
					} else {
						$radioChoices[$i] = $actionCursor
					}
				} elseif ($chosen.Contains($i)) {
					[void]$chosen.Remove($i)
				} else {
					[void]$chosen.Add($i)
				}
			} else {
				$c = [char]$key.KeyChar
				if ($c -eq 'j') {
					$cursor = ($cursor + 1) % $focusIndex.Count
					$actionCursor = [Math]::Min((& $actionCursorFor), [Math]::Max((& $getActions $Options[$focusIndex[$cursor]]).Count - 1, 0))
				} elseif ($c -eq 'k') {
					$cursor = ($cursor - 1 + $focusIndex.Count) % $focusIndex.Count
					$actionCursor = [Math]::Min((& $actionCursorFor), [Math]::Max((& $getActions $Options[$focusIndex[$cursor]]).Count - 1, 0))
				} elseif ($c -eq 'h') {
					$actions = & $getActions $Options[$focusIndex[$cursor]]
					if ($actions.Count -gt 1) { $actionCursor = ($actionCursor - 1 + $actions.Count) % $actions.Count }
				} elseif ($c -eq 'l') {
					$actions = & $getActions $Options[$focusIndex[$cursor]]
					if ($actions.Count -gt 1) { $actionCursor = ($actionCursor + 1) % $actions.Count }
				} elseif ($c -eq 'a' -or $c -eq 'A') {
					foreach ($i in $focusIndex) {
						$actions = & $getActions $Options[$i]
						if ($actions.Count -gt 0) { $radioChoices[$i] = 0 } else { [void]$chosen.Add($i) }
					}
				} elseif ($c -eq 'n' -or $c -eq 'N') {
					$chosen.Clear()
					$radioChoices.Clear()
				} elseif ($c -eq 'q' -or $c -eq 'Q') {
					return $null
				}
			}
		}
	} finally {
		[Console]::TreatControlCAsInput = $previousTreatControlC
		# best-effort: some terminals reject the restore once the picker is over
		try { [Console]::CursorVisible = $true } catch { Write-Host '' }
	}
	# the comma prevents PowerShell unrolling an empty selection into $null
	$results = & $buildSelection
	return , @($results)
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
	Write-Host 'Demo multi-choice menu (rows with actions take left/right + space; checkbox rows take space; Enter confirms):'
	$options = @(
		[pscustomobject]@{ Label = "$($PSStyle.Foreground.Green)alpha$reset$($PSStyle.Dim)  not installed$reset"; Detail = @('~/.config/alpha', '~/.local/share/alpha'); Actions = @('install') }
		[pscustomobject]@{ Label = "$($PSStyle.Foreground.Yellow)beta$reset$($PSStyle.Dim)  installed$reset"; Detail = @('~/.config/beta', '~/.local/share/beta'); Actions = @('upgrade', 'uninstall') }
		[pscustomobject]@{ Label = "$($PSStyle.Foreground.Magenta)gamma$reset$($PSStyle.Dim)  legacy checkbox row$reset"; Detail = @('~/.config/gamma') }
		[pscustomobject]@{ Label = "$($PSStyle.Dim)delta  locked by policy$reset"; Detail = @(); Locked = $true }
	)
	$picked = Read-MultiChoice -Options $options -Title 'Select things' -FooterSummary { param($Chosen) "$($Chosen.Count) selected" }
	if ($null -eq $picked) {
		Write-Host 'Read-MultiChoice returned: cancelled'
	} else {
		Write-Host "Read-MultiChoice returned: $($picked.Count) item(s)"
		foreach ($item in $picked) {
			if ($item.PSObject.Properties['Action']) {
				Write-Host "  radio:     $($item.Option.Label -replace '\x1b\[[0-9;]*m') -> $($item.Action)"
			} else {
				Write-Host "  checkbox:  $($item.Label -replace '\x1b\[[0-9;]*m')"
			}
		}
	}
}
