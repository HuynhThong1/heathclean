import Foundation

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

@MainActor
final class CheckRunner {
    private var total = 0
    private var failed = 0

    func check(_ name: String, _ body: () throws -> Void) {
        total += 1
        record(name: name) { try body() }
    }

    func checkAsync(_ name: String, _ body: () async throws -> Void) async {
        total += 1
        do {
            try await body()
            print("  ok  \(name)")
        } catch {
            failed += 1
            report(name: name, error: error)
        }
    }

    func finish() -> Never {
        print("")
        print("\(total) checks, \(failed) failed")
        exit(failed == 0 ? 0 : 1)
    }

    private func record(name: String, _ body: () throws -> Void) {
        do {
            try body()
            print("  ok  \(name)")
        } catch {
            failed += 1
            report(name: name, error: error)
        }
    }

    private func report(name: String, error: any Error) {
        print("FAIL  \(name)")
        print("      \(error)")
    }
}

/// Floating point comparison. Kept under a separate name so a `Double` can
/// never fall into the exact-equality `expect` by accident.
func expectClose(
    _ actual: Double,
    _ expected: Double,
    _ label: String = "value",
    tolerance: Double = 0.01
) throws {
    guard abs(actual - expected) <= tolerance else {
        throw CheckFailure(description: "\(label): expected \(expected), got \(actual)")
    }
}

func expect<T: Equatable>(_ actual: T, _ expected: T, _ label: String = "value") throws {
    guard actual == expected else {
        throw CheckFailure(description: "\(label): expected \(expected), got \(actual)")
    }
}

@MainActor
func expectThrows<E: Error & Equatable>(
    _ expected: E,
    _ body: () async throws -> Void
) async throws {
    do {
        try await body()
    } catch let error as E where error == expected {
        return
    } catch {
        throw CheckFailure(description: "expected \(expected), got \(error)")
    }
    throw CheckFailure(description: "expected \(expected), nothing was thrown")
}
