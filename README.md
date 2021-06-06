# Clockify Report CLI Tool

Clockify reporting CLI tool written in Swift.

## Before you start
Provide your Clockify API key in a `config.json` file.  
We recommend to copy the `example-config.json` file and rename it as config.json, then adjust the parameters there.  
You can get your Clockify API key from Clockify settings.  
Once provided, run `./report.swift --workspaces` to get your workspace ID and store the ID of the one you want to use as default in config.json file.  
When done, you can run `./report.swift --projects` to see available projects and also store the ID of the default one in the config file.  
Alternatively, run `./report.swift --workspace=<id> --projects` with the ID of the workspace you want to use as the default one, then save both in the config file.  

Both workspace and project in `config.json` are optional, but then you'll need to specify them as an argument every time when you're reporting.  

## Usage:  
`./report.swift <command> [parameters]`

## Available commands:  
* Help: `-h, help, -help, --help`
* Query available workspaces: `-w, --workspaces`
* Query available projects: `-p, --projects`
* Report time: `-r, --report`

## Time reporting
Report time using `-r` or `--report` command.

### Examples:  
`./report.swift -r 9-18 "Remote work"`  
  Report "Remote work" today from 9 AM to 6 PM. Workspace and project must be already specified in config.json file.  

`./report.swift -r 9:30-18:40 03.06 Meetings`  
  Report "Meetings" from 9:30 AM to 6:40 PM on 03.06 this year. Workspace and project must be already specified in config.json file.  

`./report.swift --workspace=myWorkspace --project=myProject -r 10-18:20 "Busy as hell"`  
  Report "Busy as hell" today from 10:00 AM to 6:20 PM in "myWorkspace" workspace & in project named "myProject"

### Parameters:
  You can provide the following parameters:  
  
  `Time` (required)  
    Must be provided immediately after the command. Minutes are optional. The time must be in 24h format.  
  `Date` (optional) (default: today)  
    Specify date of the report (can include year but its not neccessary. Provide in your system's current locale format).  
  `Message` (required)  
    Must be provided as the last parameter. Does not need quotes if it does not contain spaces.  
  
  You should provide them in the order as written above just after the report command, just as in the examples.

## Configuration parameters:
  `-wid, --workspace-id`  
    Specify workspace ID in key=value format.  
  `-wname, --workspace, --workspace-name`  
    Specify workspace name in key=value format.  
  `-pid, --project-id`  
    Specify project ID in key=value format.  
  `-pname, --project, --project-name`  
    Specify project name in key=value format.  
