# clockifyReportTool

Clockify reporting CLI tool written in Swift.

# Usage:  
              ./report.swift <command> [parameters]
            
            IMPORTANT: Provide your Clockify API key in a "config.json" file!
            See example-config.json for an example.
            
# Available commands:  
              * Help: -h, help, -help, --help
              * Query available workspaces: -w, --workspaces
              * Query available projects: NOT YET AVAILABLE
              * Report time: -r, --report
            
## Description:  
                   Report time. Workspace is taken either from the argument or from contents of a "workspace" file in the same directory. If none is provided, default hardcoded workspace is used.
                
## Example:  
                  ./report.swift -r 9-18 "Remote work"
                      Report "Remote work" today from 9 AM to 6 PM
                  ./report.swift -r 9:30-18:40 03.06 Meetings
                      Report "Meetings" from 9:30 AM to 6:40 PM on 03.06 this year
                  ./report.swift --workspace=myWorkspace --project=myProject -r 10-18:20 "Busy as hell"
                      Report "Busy as hell" today from 10:00 AM to 18:20 PM in "myWorkspace" workspace & in project named "myProject"
            
## Parameters:  
                  <time> (required)
                      Must be provided immediately after the command. Minutes are optional. The time must be in 24h format
                  <project> (required)
                      Must be provided as the last parameter. Does not need quotes if it does not contain spaces.
                  [date] (optional) (default: today)
                      Specify date of the report
            
# Configuration parameters:
                [\(getArgNames(for: .workspaceID))]
                    Specify workspace ID in key=value format.
                [\(getArgNames(for: .workspaceName))]
                    Specify workspace name in key=value format.
                [\(getArgNames(for: .projectID))]
                    Specify project ID in key=value format.
                [\(getArgNames(for: .projectName))]
                    Specify project name in key=value format.
