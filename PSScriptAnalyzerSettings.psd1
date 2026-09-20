# PSScriptAnalyzer settings for this repository.
# PSAvoidUsingWriteHost is excluded repo-wide: scripts/menu.ps1 is an interactive host-UI
# tool - styled console output via Write-Host is the intended mechanism.
# PSReviewUnusedParameter is excluded repo-wide: the menu params are consumed by the
# key-handling loop, which the rule cannot always see.
# PSUseBOMForUnicodeEncodedFile is excluded repo-wide: this repo writes UTF-8 without BOM
# everywhere (bevry-vibes powershell.md byte-write convention); pwsh 7 reads that fine.
# Lint with:  Invoke-ScriptAnalyzer -Path . -Settings ./PSScriptAnalyzerSettings.psd1
@{
    ExcludeRules = @('PSAvoidUsingWriteHost', 'PSReviewUnusedParameter', 'PSUseBOMForUnicodeEncodedFile')
}
