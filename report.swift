#!/usr/bin/swift

import Foundation

let appSemaphore = DispatchSemaphore(value: 0)
func finishApp() { appSemaphore.signal() }

struct Config: Decodable {
    let apiKey: String
    let workspaceID: String?
    let projectID: String?
}

final class App {
    static var config: Config = {
        guard let configJson = try? Data(contentsOf: URL(fileURLWithPath: "config.json")),
              let config = try? decoder.decode(Config.self, from: configJson) else {
            exit(code: .apiKeyMissing)
        }
        
        return config
    }()
}

let session = URLSession.shared
let baseURL = URL(string: "https://api.clockify.me/api/v1")!
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

enum ExitCode {
    case unconfirmedReport
    
    case apiKeyMissing
    case workspaceRequestFailure(Error)
    case workspaceNotFound(name: String)
    case workspaceNotSpecified
    case projectRequestFailure(Error)
    case projectNotFound(name: String)
    case projectNotSpecified
    case addEntryRequestFailed(Error)
    
    var code: Int32 {
        switch self {
        case .unconfirmedReport: return 0
            
        case .apiKeyMissing: return 1
        case .workspaceRequestFailure: return 2
        case .workspaceNotFound: return 3
        case .workspaceNotSpecified: return 4
        case .projectRequestFailure: return 5
        case .projectNotFound: return 6
        case .projectNotSpecified: return 7
        case .addEntryRequestFailed: return 8
        }
    }
    
    var message: String? {
        switch self {
        case .unconfirmedReport:
            return "Did not confirm, discarding."
            
        case .apiKeyMissing:
            return "No apiKey found in config.json file. Make sure your Clockify API Key is specified in a config.json file (you need to create one first if it doesnt exist yet). See attached example-config.json file to learn about the JSON structure and available config fields."
        case .workspaceRequestFailure(let error):
            return "An error occurred: \(error). Aborting."
        case .workspaceNotFound(let name):
            return "Workspace named '\(name)' not found. Use --workspaces to see available workspaces. Aborting."
        case .workspaceNotSpecified:
            return "Workspace not specified. Aborting."
        case .projectRequestFailure(let error):
            return "An error occurred: \(error). Aborting."
        case .projectNotFound(let name):
            return "Project named '\(name)' not found. Use --projects to see available projects (if workspace the project is in is not specified explicitly, it will use the default one). Aborting."
        case .projectNotSpecified:
            return "Project not specified. Aborting."
        case .addEntryRequestFailed(let error):
            return "An error occurred: \(error). Aborting."
        }
    }
}

func exit(code: ExitCode) -> Never {
    code.message.flatMap { print($0) }
    Foundation.exit(code.code)
}

let baseHeaders: [String: String] = ["X-Api-Key": App.config.apiKey,
                                     "Content-Type": "application/json"]

let arguments: [Argument] = {
    guard CommandLine.arguments.count > 1 else { return [] }
    print(CommandLine.arguments[1...])
    return CommandLine.arguments[1...]
        .compactMap { Argument($0) }
}()

enum Endpoint {
    case getWorkspaces
    case getProjects(workspaceID: String)
    case addEntry(workspaceID: String)
    
    var path: String {
        switch self {
        case .getWorkspaces:
            return "/workspaces"
        case .getProjects(let workspaceID):
            return "/workspaces/\(workspaceID)/projects"
        case .addEntry(let workspaceID):
            return "/workspaces/\(workspaceID)/time-entries"
        }
    }
}

enum HTTPMethod: String {
    case post = "POST"
    case get = "GET"
}

protocol CommandAction {
    func perform()
}

struct Argument {
    enum Key: CaseIterable {
        case workspaceName
        case workspaceID
        
        case projectName
        case projectID
        
        var matchingNames: Set<String> {
            switch self {
            case .workspaceName: return ["-wname", "--workspace", "--workspace-name"]
            case .workspaceID: return ["-wid", "--workspaceid", "--workspace-id"]
            case .projectName: return ["-pname", "--project", "--project-name"]
            case .projectID: return ["-pid", "--projectid", "--project-id"]
            }
        }
    }
    
    let key: Key
    let value: String
}

extension Argument {
    init?(_ string: String) {
        var components = string.components(separatedBy: "=")
        
        let keyString = components.removeFirst()
        let value = components.joined(separator: "=")
        
        guard let key = Key.allCases.first(where: { $0.matchingNames.contains(keyString) }) else {
            return nil
        }
        
        self = Argument(key: key, value: value)
    }
}

extension CommandAction {
    func getWorkspaceID(completion: @escaping (String) -> Void) {
        if let id = arguments.first(where: { $0.key == .workspaceID })?.value {
            print("Using provided workspace ID: \(id)")
            completion(id)
        } else if let name = arguments.first(where: { $0.key == .workspaceName })?.value {
            Networking.get(.getWorkspaces, responseType: [Responses.GetWorkspaces].self, description: "Querying available workspaces...") { result in
                switch result {
                case .success(let workspaces):
                    if let id = workspaces.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.id {
                        print("Found workspace \(name) with ID \(id)")
                        completion(id)
                    } else {
                        exit(code: .workspaceNotFound(name: name))
                    }
                case .failure(let error):
                    exit(code: .workspaceRequestFailure(error))
                }
            }
        } else if let defaultWorkspaceID = App.config.workspaceID {
            print("Using workspace ID from config file: \(defaultWorkspaceID)")
            completion(defaultWorkspaceID)
        } else {
            exit(code: .workspaceNotSpecified)
        }
    }
    
    func getProjectID(inWorkspaceWithID id: String, completion: @escaping (String) -> Void) {
        if let id = arguments.first(where: { $0.key == .projectID })?.value {
            print("Using provided project ID: \(id)")
            completion(id)
        } else if let name = arguments.first(where: { $0.key == .projectName })?.value {
            Networking.get(.getProjects(workspaceID: id), responseType: [Responses.GetProjects].self, description: "Querying available projects...") { result in
                switch result {
                case .success(let projects):
                    if let id = projects.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.id {
                        print("Found project \(name) with ID \(id)")
                        completion(id)
                    } else {
                        exit(code: .projectNotFound(name: name))
                    }
                case .failure(let error):
                    exit(code: .projectRequestFailure(error))
                }
            }
        } else if let defaultProjectID = App.config.projectID {
            print("Using project ID from config file: \(defaultProjectID)")
            completion(defaultProjectID)
        } else {
            exit(code: .projectNotSpecified)
        }
    }
}

final class CommandHandler {
    enum Command: CaseIterable {
        case workspaces
        case projects
        case report
        case help
        
        var matchingArgs: Set<String> {
            switch self {
            case .workspaces: return ["-w", "--workspaces"]
            case .projects: return ["-p", "--projects"]
            case .report: return ["-r", "--report"]
            case .help: return ["-h", "help", "-help", "--help"]
            }
        }
        
        func getAction(arguments: [String]) -> CommandAction {
            switch self {
            case .workspaces: return GetWorkspacesAction()
            case .projects: return GetProjectsAction()
            case .report: return ReportAction(arguments: arguments)
            case .help: return HelpAction()
            }
        }
    }
    
    static func getAction() -> CommandAction {
        let args = CommandLine.arguments
        
        guard args.count > 1 else {
            return HelpAction()
        }
        
        let params = Array(args[1...])
        
        let paramIndex: Int? = params
            .firstIndex { param in
                Command.allCases.contains { command in
                    command.matchingArgs.contains(param)
                }
            }
        
        guard let paramIndex = paramIndex else {
            return HelpAction()
        }
        
        let param = params[paramIndex]
        
        let command = Command.allCases.first { command in
            command.matchingArgs.contains(param)
        }
        
        let action = command?.getAction(arguments: Array(params[paramIndex...])) ?? HelpAction()
        
        return action
    }
}

final class GetWorkspacesAction: CommandAction {
    func perform() {
        Networking.get(.getWorkspaces, responseType: [Responses.GetWorkspaces].self, description: "Querying available workspaces...") { result in
            switch result {
            case .success(let workspaces):
                print("Available workspaces: \(workspaces)")
            case .failure(let error):
                print("An error occurred: \(error)")
            }
            
            finishApp()
        }
    }
}

final class GetProjectsAction: CommandAction {
    func perform() {
        getWorkspaceID { workspaceID in
            self.perform(inWorkspaceID: workspaceID)
        }
    }
    
    private func perform(inWorkspaceID workspaceID: String) {
        Networking.get(.getProjects(workspaceID: workspaceID), responseType: [Responses.GetProjects].self, description: "Querying available projects...") { result in
            switch result {
            case .success(let projects):
                print("Available projects: \(projects)")
            case .failure(let error):
                print("An error occurred: \(error)")
            }
            
            finishApp()
        }
    }
}

final class HelpAction: CommandAction {
    func perform() {
        func getArgNames(for key: Argument.Key) -> String {
            key.matchingNames.joined(separator: ", ")
        }
        
        print("""
            Usage:
              ./report.swift <command> [parameters]
            
            IMPORTANT: Provide your Clockify API key in a "config.json" file!
            See example-config.json for an example.
            
            Available commands:
              * Help: -h, help, -help, --help
              * Query available workspaces: -w, --workspaces
              * Query available projects: -p, --projects
              * Report time: -r, --report
            
                Description:
                   Report time using `-r` or `--report` command.
                
                Example:
                  ./report.swift -r 9-18 "Remote work"
                      Report "Remote work" today from 9 AM to 6 PM. Workspace and project must be already specified in config.json file.
                  ./report.swift -r 9:30-18:40 03.06 Meetings
                      Report "Meetings" from 9:30 AM to 6:40 PM on 03.06 this year. Workspace and project must be already specified in config.json file.
                  ./report.swift --workspace=myWorkspace --project=myProject -r 10-18:20 "Busy as hell"
                      Report "Busy as hell" today from 10:00 AM to 6:20 PM in "myWorkspace" workspace & in project named "myProject"
            
                Parameters:
                  <time> (required)
                      Must be provided immediately after the command. Minutes are optional. The time must be in 24h format
                  [date] (optional) (default: today)
                      Specify date of the report
                  <message> (required)
                      Must be provided as the last parameter. Does not need quotes if it does not contain spaces.
            
            Configuration parameters:
                [\(getArgNames(for: .workspaceID))]
                    Specify workspace ID in key=value format.
                [\(getArgNames(for: .workspaceName))]
                    Specify workspace name in key=value format.
                [\(getArgNames(for: .projectID))]
                    Specify project ID in key=value format.
                [\(getArgNames(for: .projectName))]
                    Specify project name in key=value format.
            """)
        
        finishApp()
    }
}

struct TimeRange: CustomStringConvertible {
    let dateFrom: Date
    let dateTo: Date
    
    var description: String {
        return "<Range from \(dateFrom) to \(dateTo)>"
    }
    
    private static var currentDateComps: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: Date())
    }
    
    init?(from arguments: [String]) {
        guard arguments.count >= 3 else { return nil }
        
        // [0] is command name
        let timeString = arguments[1]
        let dateString = arguments[2]
        
        let rangeStrings = timeString.components(separatedBy: "-")
        guard rangeStrings.count == 2 else { return nil }
        
        let timeFromString = rangeStrings[0]
        let timeToString = rangeStrings[1]
        
        let dateComps = Self.parseDate(dateString)
        
        guard let timeFrom = Self.parseTime(timeFromString),
              let timeTo = Self.parseTime(timeToString) else {
            return nil
        }
        
        let fromComps = DateComponents(year: dateComps.year, month: dateComps.month, day: dateComps.day, hour: timeFrom.hour, minute: timeFrom.minute, second: 0, nanosecond: 0)
        let toComps = DateComponents(year: dateComps.year, month: dateComps.month, day: dateComps.day, hour: timeTo.hour, minute: timeTo.minute, second: 0, nanosecond: 0)
        
        guard let dateFrom = Calendar.current.date(from: fromComps),
              let dateTo = Calendar.current.date(from: toComps) else { return nil }
        
        self.dateFrom = dateFrom
        self.dateTo = dateTo
    }
    
    private static func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let df = DateFormatter()
        let format = DateFormatter.dateFormat(fromTemplate: "HHmm", options: 0, locale: .current)
        df.dateFormat = format
        
        if let date = df.date(from: timeString) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            return (hour: comps.hour!, minute: comps.minute!)
        } else {
            let format = DateFormatter.dateFormat(fromTemplate: "HH", options: 0, locale: .current)
            df.dateFormat = format
            
            if let date = df.date(from: timeString) {
                let comps = Calendar.current.dateComponents([.hour], from: date)
                return (hour: comps.hour!, minute: 0)
            } else {
                return nil
            }
        }
    }
    
    private static func parseDate(_ dateString: String) -> (year: Int, month: Int, day: Int) {
        let df = DateFormatter()
        let format = DateFormatter.dateFormat(fromTemplate: "ddMM", options: 0, locale: .current)
        df.dateFormat = format
        
        if let simpleDate = df.date(from: dateString) {
            let comps = Calendar.current.dateComponents([.month, .day], from: simpleDate)
            return (year: currentDateComps.year!, month: comps.month!, day: comps.day!)
        } else {
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMyyyy", options: 0, locale: .current)
            df.dateFormat = format
            
            if let fullDate = df.date(from: dateString) {
                let comps = Calendar.current.dateComponents([.year, .month, .day], from: fullDate)
                return (year: comps.year!, month: comps.month!, day: comps.day!)
            } else {
                return (year: currentDateComps.year!, month: currentDateComps.month!, day: currentDateComps.day!)
            }
        }
    }
}

final class ReportAction: CommandAction {
    let arguments: [String]
    
    init(arguments: [String]) {
        self.arguments = arguments
    }
    
    func perform() {
        guard let timeRange = TimeRange(from: arguments),
              let message = arguments.last else {
            print("Invalid time or message. Type --help for usage description.")
            return
        }
        
        getWorkspaceID { workspaceID in
            self.getProjectID(inWorkspaceWithID: workspaceID) { projectID in
                self.perform(withWorkspaceID: workspaceID,
                             projectID: projectID,
                             timeRange: timeRange,
                             message: message)
            }
        }
    }
    
    private func perform(withWorkspaceID id: String, projectID: String, timeRange: TimeRange, message: String) {
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        
        let timeFromString = fmt.string(from: timeRange.dateFrom)
        let timeToString = fmt.string(from: timeRange.dateTo)
        
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        
        // dateFrom == dateTo so whatever
        let dateString = fmt.string(from: timeRange.dateFrom)
        
        print("""
              Summary:
                - From: \(timeFromString)
                - To: \(timeToString)
                - Date: \(dateString)
                - Message: \(message)
              """)
        print("Type 'y' to report.")
        let confirm = readLine()
        
        guard confirm?.caseInsensitiveCompare("y") == .orderedSame else {
            exit(code: .unconfirmedReport)
        }
        
        let data = Requests.AddTimeEntry(start: timeRange.dateFrom,
                                         end: timeRange.dateTo,
                                         description: message,
                                         projectId: projectID)
        
        Networking.post(.addEntry(workspaceID: id), data: data, description: "Sending report...") { error in
            if let error = error {
                exit(code: .addEntryRequestFailed(error))
            }
            
            print("Time reported successfully! Finishing.")
            finishApp()
        }
    }
}

enum Requests {
    struct AddTimeEntry: Codable {
        let start: Date
        let end: Date
        let description: String
        let projectId: String
    }
}

enum Responses {
    struct GetWorkspaces: Decodable, CustomStringConvertible {
        let id: String
        let name: String
        
        var description: String {
            return "[Workspace \(id)] \(name)"
        }
    }
    
    struct GetProjects: Decodable, CustomStringConvertible {
        let id: String
        let name: String
        
        var description: String {
            return "[Project \(id)] \(name)"
        }
    }
}

final class Networking {
    
    static func post<T: Encodable>(_ endpoint: Endpoint, headers: [String: String] = [:], data: T, description: String? = nil, completion: @escaping (Error?) -> Void) {
        
        let body: Data
        do {
            body = try encoder.encode(data)
        } catch {
            completion(error)
            return
        }
        
//        if let string = String(data: body, encoding: .utf8) {
//            print("Sending JSON: \(string)")
//        }
        
        sendRequest(endpoint, method: .post, headers: headers, body: body, description: description) { result in
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    static func get<T: Decodable>(_ endpoint: Endpoint, headers: [String: String] = [:], responseType: T.Type, description: String? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        sendRequest(endpoint, method: .get, headers: headers, description: description) { result in
            switch result {
            case .success(let data):
                if let data = data {
                    do {
                        let result = try decoder.decode(T.self, from: data)
                        completion(.success(result))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    let err = NSError(domain: "report", code: 1, userInfo: [NSLocalizedDescriptionKey: "Data missing in response"])
                    completion(.failure(err as Error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    static func get(_ endpoint: Endpoint, headers: [String: String] = [:], description: String? = nil, completion: ((Error?) -> Void)? = nil) {
        sendRequest(endpoint, method: .get, headers: headers, description: description) { result in
            switch result {
            case .success:
                completion?(nil)
            case .failure(let error):
                completion?(error)
            }
        }
    }
    
    private static func sendRequest(_ endpoint: Endpoint, method: HTTPMethod = .get, headers: [String: String] = [:], body: Data? = nil, description: String? = nil, completion: @escaping (Result<Data?, Error>) -> Void) {
        
        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        baseHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
            } else if let resp = response as? HTTPURLResponse, 200...299 ~= resp.statusCode {
                completion(.success(data))
            } else if let data = data, let apiErrorString = String(data: data, encoding: .utf8) {
                print("API error: \(apiErrorString)")
            } else {
                print("Unknown API error")
            }
        }
        
        task.resume()
        
        if let description = description {
            print(description)
        }
    }
}

DispatchQueue.global(qos: .userInitiated).async {
    let action = CommandHandler.getAction()
    action.perform()
}

appSemaphore.wait()
