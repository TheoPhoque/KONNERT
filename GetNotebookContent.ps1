function Get-NotebookContent {
    <#
        .SYNOPSIS
        Get-NotebookContents reads the contents of a Jupyter Notebooks

        .Example
        Get-NotebookContent .\samplenotebook\Chapter01code.ipynb

NoteBookName        Type     Source
------------        ----     ------
Chapter01code.ipynb markdown ## Code for chapter 1 PowerShell in Action third edition
Chapter01code.ipynb markdown ## Introduction
Chapter01code.ipynb code     'Hello world.'
Chapter01code.ipynb code     Get-ChildItem -Path $env:windir\*.log | Select-String -List error | Format-Table Path,L...
Chapter01code.ipynb code     ([xml] [System.Net.WebClient]::new().DownloadString('http://blogs.msdn.com/powershell/r...
Chapter01code.ipynb markdown ## 1.2 PowerShell example code
Chapter01code.ipynb code     Get-ChildItem -Path C:\somefile.txt

        .Example
        Get-Notebook .\samplenotebook\*sharp*|Get-NotebookContent

NoteBookName Type Source
------------ ---- ------
csharp.ipynb code {Console.Write("hello world")}
fsharp.ipynb code {printfn "hello world"}

    #>
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('NoteBookFullName')]
        $FullName,
        [Switch]$JustCode,
        [Switch]$JustMarkdown,
        [Switch]$PassThru
    )

    Process {

        if ([System.Uri]::IsWellFormedUriString($FullName, [System.UriKind]::Absolute)) {
            $r = Invoke-RestMethod $FullName 
        }
        elseif (Test-Path $FullName -ErrorAction SilentlyContinue) {
            $r = Get-Content $FullName | ConvertFrom-Json
        }

        if ($PassThru) {
            return $r
        }

        if ($JustCode) { $cellType = "code" }
        if ($JustMarkdown) { $cellType = "markdown" }
        if ($JustCode -and $JustMarkdown) { $cellType = $null }

        $r.cells | Where-Object { $_.cell_type -match $cellType } | ForEach-Object {
            $IsParameterCell = $false
            if ($_.metadata.tags) {
                if ($null -ne ($_.metadata.tags -eq 'parameters')) {
                    $IsParameterCell = $true
                }
            }

            [PSCustomObject][Ordered]@{
                NoteBookName    = Split-Path -Leaf $FullName
                Type            = $_.'cell_type'
                IsParameterCell = $IsParameterCell
                Source          = -join $_.source
            }
        }
    }
}
