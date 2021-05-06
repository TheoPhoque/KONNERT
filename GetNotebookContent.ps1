function Get-NotebookContent {
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification="Test doesn't understand -begin script blocks. ")]
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
    [cmdletbinding(DefaultParameterSetName="MarkdownAndCode")]
    param(
        [Parameter(ValueFromPipelineByPropertyName,Position=0)]
        [alias('FullName','NoteBookFullName')]
        $Path,
        [parameter(ParameterSetName='JustCode')]
        [alias('NoMarkdown')]
        [Switch]$JustCode,
        [parameter(ParameterSetName='JustMarkdown')]
        [alias('NoCode')]
        [Switch]$JustMarkdown,
        [Switch]$PassThru,
        [Switch]$IncludeOutput
    )

    process {
      #allow Path to contain more than one item, if any are wild cards call the function recursively.
      foreach ($p in $Path) {
        if ([System.Uri]::IsWellFormedUriString($p, [System.UriKind]::Absolute)) {
            $r = Invoke-RestMethod $p
        }
        elseif (Test-Path $p -ErrorAction SilentlyContinue) {
            if ((Resolve-Path $p).count -gt 1) {
                [void]$PSBoundParameters.Remove('Path')
                Get-ChildItem $p | Get-NotebookContent @PSBoundParameters
                continue
            }
            else {
                $r = Get-Content  $p | ConvertFrom-Json
            }
        }
        if($PassThru) {
            return $r
        }
        elseif ($JustCode)     { $cellType = 'code'     }
        elseif ($JustMarkdown) { $cellType = 'markdown' }
        else                   { $cellType = '.'        }

        $r.cells | Where-Object { $_.cell_type -match $cellType } | ForEach-Object {
            $cell = [Ordered]@{
                NoteBookName = Split-Path -Leaf $p
                Type         = $_.'cell_type'
                Source       = -join $_.source
            }
            if ($_.metadata.dotnet_interactive.language) {$cell['Language'] = $_.metadata.dotnet_interactive.language}
            if ($IncludeOutput) {
                # There may be one or many outputs. For each output
                # either a single string if has a .text field containing a string or array of strings
                # or a hash table if it has a .data field containing .mime-type = "Content"
                $cell['Output'] = foreach ($o in $_.outputs) {
                    if     ($o.text -join "") {$o.text -join "    `r`n" }
                    elseif ($o.data)          {
                        $o.data.psobject.properties | foreach-object -Begin {$hash=@{}} -Process {$hash[$_.name] =$_.value} -end {$hash}
                    }
                }
                #merge the text generated by .NET Interactive in VS code - every output will be a hash table with a text/plain entry. Others do the same with Text/HTML
                if (    $cell.Output.where({$_ -is    [hashtable]}) -and -not                #if some are hashtables and none are not hashtables
                        $cell.Output.where({$_ -isnot [hashtable]}) ){
                    if ($cell.Output.where({     $_.containskey('text/html')}) -and -not     #if some have text/html and none don't.
                        $cell.Output.where({-not $_.containskey('text/html')}) ) {
                        $cell['HtmlOutput'] =    $cell.output.'text/html'  -join "<br />`n"  #Add an HTML Output field
                    }
                    if ($cell.Output.where({     $_.containskey('text/plain')}) -and -not    #if some have text/plain and none don't.
                        $cell.Output.where({-not $_.containskey('text/plain')}) ) {
                        $cell.Output =  -join  $cell.output.'text/plain'            #Merge plain text into the output field
                    }
                }
            }
            [PSCustomObject]$cell
        }
      }
    }
}
