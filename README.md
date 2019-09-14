# azure-pipeline-templates
A collection of (hopefully) useful templates for Azure DevOps Pipelines.  For documentation for each template, see below.

To use these templates in your Azure DevOps build pipeline, refer to the following:

* [Azure DevOps: Pipelines using templates in other repositories](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=azure-devops#using-other-repositories)
* [GitHub: Creating a Personal Access Token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line)
* [Azure DevOps: Service Connections for GitHub](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml#sep-github)



## delphi-build.yml
A Powershell script based template for building Delphi projects.  This template currently only supports **Win32** and **Win64** builds.  _It is untested with FMX projects_.

### Pre-Requisites

As well as the configuration required in your GitHub account and Azure DevOps project in order to be able to references this template, the following are also required.

#### A Self-Hosted Azure DevOps Build Agent
Delphi compilers are not supported by the hosted build agents provided by Microsoft for Azure DevOps builds.  You will need to configure your own, self-hosted build machine with an agent installed.

This is really straightforward to accomplish and a guide (of sorts) to this is [available on my blog](http://www.deltics.co.nz/blog/posts/2659).

#### Delphi Compilers
A build agent running this build job is assumed to have Delphi command-line compiler support with available Delphi versions in locations on the build agent hard-drive as follows:

  - `c:\dcc\<version>\bin` for compiler binaries (dcc32.exe and dcc64.exe etc)
  - `c:\dcc\<version>\lib` for compiler libraries

The `<version>` component of the path **must** correspond to the values passed to the **delphiVersion** parameter supported by the template.  See the **Usage** information for that parameter below for the requireded values.  For example, for **Delphi 7**:

    c:\dcc\7\bin
    c:\dcc\7\lib

Later versions of Delphi may have multiple subfolders under the `lib` folder.  Whilst currently only **Windows** target platforms are supported it is recommended that you copy _all_ of these folders if you intend supporting other target platforms in the future (as and when supported by this template).  Unless you cannot afford the disk space - these do take up a fair chunk!

For example, for **Delphi 10.3 Rio**:

    c:\dcc\10.3\bin
    c:\dcc\10.3\lib\android
    c:\dcc\10.3\lib\iosDevice32
    c:\dcc\10.3\lib\iosDevice64
    c:\dcc\10.3\lib\iossimulator
    c:\dcc\10.3\lib\linux64
    c:\dcc\10.3\lib\osx32
    c:\dcc\10.3\lib\win32
    c:\dcc\10.3\lib\win32c
    c:\dcc\10.3\lib\win64

These folders may be 'donated' from a full Delphi installation of the corresponding Delphi version.  _Please abide by the terms of your Delphi license agreement_.

_**NOTE:** Neither `bin` nor any of the `lib` folders should be included on the build machine `PATH`._

#### IDE FixPack Compilers
Depending on the Delphi version involved these are named either `dccNNspeed.exe` or `fastdccNN.exe`.  If installed, these should be placed in the corresponding `c:\dcc\<version>\bin` folder alongside the standard Delphi compiler.

An explanation of the benefits of these compilers as well as the compilers themselves may be found on [Andreas Hausladen's blog and downloads site](https://www.idefixpack.de/blog/ide-tools/ide-fix-pack/).

### Template Parameters

  |Parameter|Usage|
  |:--------|:----|
  |**delphiVersion**|Specifies the version of Delphi to be used for the build.  This is a **required** parameter and must have one of the following values: `7, 2005, 2006, 2007, 2009, 2010, xe, xe2, xe3, xe4, xe5, xe6, xe7, xe8, 10, 10.1, 10.2, 10.3`
  |**project**|Identifies the path and filename of the project to be compiled.  This is a **required** parameter and must identify a _dpr_ file (_without_ the `dpr` extension)|
  |**appType**|Identifies whether to build a console application or a Gui application.  If specified it must have the value `CONSOLE` or `GUI`.  If not specified `CONSOLE` is assumed.|
  |**platform**|Identifies the target platform for the build.  If specified it must have the value `x86` (for Win32 builds) or `x64` (for Win64).  If not specified `x86` is assumed.  Whatever value is specified is ignored for Delphi versions earlier than XE2 (only Win32 builds are supported up to Delphi XE).|
  |**searchPath**|An **optional** path to be added to `-I`, `-R` and `-U` search paths for the compiler.  That is, `include`, `resource` and `unit` search paths, respectively.|
  |**unitScopes**|An **optional** set of scope namespace prefixes for use with XE2 and later.  If not specified then `System;System.Win;Vcl;WinApi` is assumed.|
  |**fixPack**|An **optional** parameter that determines whether the build will attempt to use the relevant IDE FixPack compiler for the Delphi version.  If any value other than `true` is specified then the standard Delphi compiler will be used.  If not specified then `true` is assumed.  Whether `true` is specified or assumed, FixPack compilers will only be used if present on the build maachine, otherwise the standard compiler will be used instead.|
  |**verbose**|An **optional** parameter that determines whether Delphi compiler output is complete or limited to only hints, warnings and errors.  For verbose output, specify `true`.  Any other value is equivalent to `false`.  If not specified then `false` is assumed.|
  |**preBuild: []**|An **optional** parameter that defines an additional step (or steps) to be performed _before_ the Delphi build step itself.  _If any specified preBuild step(s) fail then the Delphi build step will not be performed_.|
  |**preBuildInline: []**|An **optional** parameter that defines additional Powershell script statements to be performed by the build step immediately before executing the compiler.  _Errors occuring during execution of these script statements may cause the Delphi build step to fail even if the Delphi compilation is successful._|
  |**postBuild: []**|An **optional** parameter that defines an additional step (or steps) to be performed _after_ the Delphi build step itself.  _If any specified preBuild step(s) fail then the Delphi build step will not be performed_.|
  |**postBuildInline: []**|An **optional** parameter that defines additional Powershell script statements to be performed by the build step _immediately after_ executing the compiler, but only if the compilation was successful.  _Errors occuring during execution of these script statements may cause the Delphi build step to fail even if the Delphi compilation was successful._|
  
### Job Behaviour
1. Any `preBuild` steps are executed before the main build step itself.

2. The main build step uses the specified Delphi version and platform to determine the compiler for use in the build and the required `lib` path to be added (as a minimum) to the search paths.  If required, IDE FixPack compilers are located and specified for use in preference over the standard compilers.

3. The working directory is set to the folder containing the specified project, where subfolders are then created to hold compiler output (`.bin`) and test results (`.results`).  _The build step itself makes no use of the `.results` folder and its use in any consuming build pipeline is entirely optional_.

4. A compiler configuration file is created with settings for search paths (`-I`, `-R`, `-U`), application target (`-D` = `CONSOLE` or `GUI`) and output directories for exe and dcu files (`.bin`).

5. After executing any `preBuildInline` statements the compiler is then invoked.  If the expected `exe` file is found in the `.bin` folder, the compilation is deemed successful, otherwise failure is reported.  If successful, any `postBuildInline` statements are executed.

6. Finally, any `postBuild` steps are executed.  If no [step conditions](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/conditions?view=azure-devops&tabs=yaml) are specified on those to determine otherwise, `postBuild` steps are only executed if the main build step and any `preBuild` steps were successful.


### Roadmap
_**NOTE:** There is no timeline in mind for any of these features.  Development of this template is driven primarily by my own needs, however contributions or suggestions from others are encouraged and gratefully received._

1. Support for additional compiler configuration settings via parameters.
2. Validation of support for FMX builds.
3. Support for platforms other than Windows.
4. For building with MS Build (as an alternative to reliance on compiler configuration files).
5. Built-in support for **duget** steps.
