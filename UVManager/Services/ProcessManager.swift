import Foundation
import Combine

class ProcessManager: ObservableObject {
    @Published var isRunning = false
    @Published var output = ""
    @Published var error = ""
    
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var cancellables = Set<AnyCancellable>()
    
    func run(_ command: String, arguments: [String], streamOutput: Bool = false) async throws -> (output: String, error: String) {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                self.isRunning = true
                self.output = ""
                self.error = ""
            }
            
            let process = Process()
            self.process = process
            
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            self.outputPipe = outputPipe
            self.errorPipe = errorPipe
            
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            if streamOutput {
                outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    if !data.isEmpty, let string = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            self?.output += string
                        }
                    }
                }
                
                errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    if !data.isEmpty, let string = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            // UV outputs progress to stderr, so we'll treat it as normal output
                            self?.output += string
                        }
                    }
                }
            }
            
            process.terminationHandler = { [weak self] _ in
                if streamOutput {
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                }
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let outputString = String(data: outputData, encoding: .utf8) ?? ""
                let errorString = String(data: errorData, encoding: .utf8) ?? ""
                
                Task { @MainActor in
                    if streamOutput {
                        // Append any remaining output
                        if !outputString.isEmpty {
                            self?.output += outputString
                        }
                        if !errorString.isEmpty {
                            self?.output += errorString  // UV uses stderr for progress
                        }
                    } else {
                        self?.output = outputString + errorString
                    }
                    self?.isRunning = false
                }
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: (outputString, errorString))
                } else {
                    continuation.resume(throwing: ProcessError.nonZeroExit(code: process.terminationStatus, error: errorString))
                }
            }
            
            do {
                try process.run()
            } catch {
                Task { @MainActor in
                    self.isRunning = false
                }
                continuation.resume(throwing: error)
            }
        }
    }
    
    func cancel() {
        process?.terminate()
    }
}

enum ProcessError: LocalizedError {
    case nonZeroExit(code: Int32, error: String)
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let code, let error):
            return "Process exited with code \(code): \(error)"
        case .notFound:
            return "Command not found"
        }
    }
}