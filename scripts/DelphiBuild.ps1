function DelphiBuild
{
    param([string]$delphiVersion,
          [string]$project,
          [string]$appType,
          [string]$platform,
          [string]$searchPath,
          [string]$unitScopes,
          [string]$fixPack,
          [string]$verbose,
          [string]$preDcc,
          [string]$postDcc)

    # Turn platform (x86/x64) into 'bits' (32/64) which will be useful in substitutions later

    $bits = if($platform -eq 'x64') {'64'} else {'32'}

    # Turn human meaningful Delphi version into the internal product version, which will
    #  make some version levelling comparisons a bit easier

    if     ($delphiVersion -eq '7')    { $delphi = 150 }
    elseif ($delphiVersion -eq '8')    { $delphi = 160 }
    elseif ($delphiVersion -eq '2005') { $delphi = 170 }
    elseif ($delphiVersion -eq '2006') { $delphi = 180 }
    elseif ($delphiVersion -eq '2007') { $delphi = 185 }
    elseif ($delphiVersion -eq '2009') { $delphi = 200 }
    elseif ($delphiVersion -eq '2010') { $delphi = 210 }
    elseif ($delphiVersion -eq 'xe')   { $delphi = 220 }
    elseif ($delphiVersion -eq 'xe2')  { $delphi = 230 }
    elseif ($delphiVersion -eq 'xe3')  { $delphi = 240 }
    elseif ($delphiVersion -eq 'xe4')  { $delphi = 250 }
    elseif ($delphiVersion -eq 'xe5')  { $delphi = 260 }
    elseif ($delphiVersion -eq 'xe6')  { $delphi = 270 }
    elseif ($delphiVersion -eq 'xe7')  { $delphi = 280 }
    elseif ($delphiVersion -eq 'xe8')  { $delphi = 290 }
    elseif ($delphiVersion -eq '10')   { $delphi = 300 }
    elseif ($delphiVersion -eq '10.1') { $delphi = 310 }
    elseif ($delphiVersion -eq '10.2') { $delphi = 320 }
    elseif ($delphiVersion -eq '10.3') { $delphi = 330 }
    else {
        Write-Host "##vso[task.logissue type=error]Unknown Delphi version '$(delphiVersion)' is not supported by this template"
    }

    # Some specific versions that are needed for comparisons later
    
    $delphiXE = 220

    # Setup references to the dpr, exe, compiler cfg, libs etc

    $dpr = $(Split-Path -Leaf $project) + '.dpr'
    $exe = '.bin\' + $(Split-Path -Leaf $project) + '.exe'

    $delphiRoot = 'c:\dcc\' + $delphiVersion
    $delphiBin  = $delphiRoot + '\bin'
    $delphiLib  = $delphiRoot + '\lib'

    # Assume that we will use the standard Delphi compiler but then
    #  check for the presence of an appropriate IDE FixPack compiler
    #  (unless the fixPack parameter is anything other than 'true').
    #
    # If an IDE FixPack compiler is found, use that instead.

    $dcc = $delphiBin + '\dcc' + $bits + '.exe'
    $cfg = 'dcc' + $bits + '.cfg'

    if($fixPack -eq 'true') {
        Write-Host 'Checking for IDE FixPack compilers'

        $dccSpeed = $delphiBin + '\dcc' + $bits + 'speed.exe'
        $fastDcc  = $delphiBin + '\fastdcc' + $bits + '.exe'

        if     (Test-Path -Path $dccSpeed) { $dcc = $dccSpeed }
        elseif (Test-Path -Path $fastDcc)  { $dcc = $fastDcc }
    }
    Write-Host $('Compiling with      : ' + $dcc)

    # Modify the Delphi Lib path according to the specified Delphi version
    #  and insert into the searchPath

    if     ($delphi -eq $delphiXE) { $delphiLib = $delphiLib + '\win32\release' }
    elseif ($delphi -gt $delphiXE) { $delphiLib = $delphiLib + '\win' + $bits + '\release' }

    $searchPath = $delphiLib + ';' + $searchPath

    Write-Host $('Delphi library path : ' + $delphiLib)
    Write-Host $('Using search path   : ' + $searchPath)
    Write-Host $('To build            : ' + $exe)
        
    # Construct compiler options for the dccNN.cfg file then create that file

    $prevLocation = Get-Location
    Set-Location (Split-Path -Path $project)
    try
    {
        if (-Not(Test-Path -Path .bin))     { New-Item .bin     -ItemType directory | Out-Null }
        if (-Not(Test-Path -Path .results)) { New-Item .results -ItemType directory | Out-Null }

        $optD = '-D' + $appType
        $optE = '-E.bin'
        $optI = '-I' + $searchPath
        $optN = '-N.bin'
        $optR = '-R' + $searchPath
        $optU = '-U' + $searchPath

        if($delphi -gt $delphiXE) { $optNS='-NS' + $unitScopes }
            
        Write-Host $('Creating compiler configuration : ' + $cfg)

        if (Test-Path -Path $cfg) { Remove-Item $cfg | Out-Null }
        New-Item $cfg -ItemType file | Out-Null

        Add-Content $cfg $optD
        Add-Content $cfg $optE
        Add-Content $cfg $optI
        Add-Content $cfg $optN
        Add-Content $cfg $optR
        Add-Content $cfg $optU
        if ($delphi -gt $delphiXE) { Add-Content $cfg $optNS }

        # Remove any previous build and invoke any preBuildInline script

        if (Test-Path -Path $exe) { Remove-Item $exe | Out-Null }

        # NOTE: What follows is a temporary fix to accommodate the current
        #        state of duget.
        #
        # We rename the dcc<bits>.cfg to <project>.cfg.  If a duget restore
        #  is performed in the preBuildInline script, it will update <project>.cfg
        #  which we then rename back to dcc<bits>.cfg.
        #
        # Yes, I need to figure out a proper way to handle this.

        $temp = $(Split-Path -Leaf $project) + '.cfg'

        Write-Host $('Renaming ' + $cfg + ' as ' + $temp)

        Rename-Item $cfg $temp

        # Instead of: ${{ parameters.preBuildInline }}
        Invoke-Expression $preDcc

        Write-Host $('Renaming ' + $temp + ' back to ' + $cfg)

        Rename-Item $temp $cfg

        type $cfg

        # Invoke the compiler to build the project

        $cmd = $dcc + ' ' + $dpr
        if ($appType -eq 'CONSOLE') { $cmd = $cmd + ' -CC' }

        Write-Host $('Compiling with ' + $cmd)
        if ($verbose -eq 'true') { Invoke-Expression $cmd }
        else                     { Invoke-Expression $cmd | Select-String -Pattern 'Fatal: ','Error: ','Hint: ','Warning: ' }

        # Clean-up: remove the cfg file (to ensure it doesn't interfere with future builds)

        if (Test-Path -Path $cfg) { Remove-Item $cfg | Out-Null }
        
        # Report success or failure, as appropriate

        if (Test-Path -Path $exe) {
            Write-Host $('Build succeeded! :)  [' + $exe + ']')

            # Instead of: ${{ parameters.postBuildInline }}
            Invoke-Expression $postDcc
        } else {
            Write-Host '##vso[task.logissue type=error]Build failed.  :('
            exit 1
        }
    }
    finally
    {
        Set-Location $prevLocation
    }
}  