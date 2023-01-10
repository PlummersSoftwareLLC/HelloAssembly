# Directory contents

This directory contains a number of PowerShell scripts to automate some of the recurring tasks related to processing changes to the assembly programs in this repository.

## Script summaries

| Name | Description |
|-|-|
| [build-all.ps1](build-all.ps1) | Builds both plain MASM32 and Crinkler versions of the assembly programs in the [Lasse](Lasse) and [TinyOriginal](TinyOriginal) directories. |
| [build-check.ps1](build-check.ps1) | Builds both plain MASM32 and Crinkler versions of the assembly programs in the [Lasse](Lasse) and [TinyOriginal](TinyOriginal) directories. It then runs each of the generated executables to check if they work. If all do, it updates the "current sizes" section in the [repository README](../README.md) using the [respective template](../templates/README.md.template). |
| [update-readme-sizes.ps1](update-readme-sizes.ps1) | Updates the "current sizes" section in the [repository README](../README.md) using the [respective template](../templates/README.md.template). |

## Notes

- The scripts assume that both MASM32 11.0 and version 10.0.20348.0 of the Windows SDK are installed in their default directories.
- The scripts need to be executed from the repo's main directory, like `.\tools\<script name>`.
