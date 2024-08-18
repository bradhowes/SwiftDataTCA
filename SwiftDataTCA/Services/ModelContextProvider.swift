import Dependencies
import Foundation
import SwiftData

typealias ActiveSchema = SchemaV6
typealias ActorModel = ActiveSchema.ActorModel
typealias MovieModel = ActiveSchema.MovieModel

typealias Actor = ActiveSchema.Actor
typealias Movie = ActiveSchema.Movie

/**
 Wrapper around a `ModelContext` value that can be used for a dependency.
 */
struct ModelContextProvider {
  /// The context to use for SwiftData operations
  let context: ModelContext
  /// The container associated with the context
  var container: ModelContainer { context.container }
}

extension DependencyValues {
  var modelContextProvider: ModelContextProvider {
    get { self[ModelContextProvider.self] }
    set { self[ModelContextProvider.self] = newValue }
  }
}

extension ModelContextProvider: DependencyKey {
  public static let liveValue = Self(context: liveContext())
}

extension ModelContextProvider: TestDependencyKey {
  public static var previewValue: ModelContextProvider { .init(context: previewContext()) }
  public static var testValue: ModelContextProvider { .init(context: testContext()) }
}

/// Create a ModelContainer to be used in a live environment.
func makeLiveContainer(dbFile: URL) -> ModelContainer {
  do {
    let schema = Schema(versionedSchema: ActiveSchema.self)
    let config = ModelConfiguration(schema: schema, url: dbFile)
    return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: config)
  } catch {
    fatalError("Failed to create live container.")
  }
}

/// Create a ModelContainer to be used in a live environment.
private let liveContainer: ModelContainer = makeLiveContainer(
  dbFile: URL.applicationSupportDirectory.appending(path: "Modelv5.sqlite")
)

/// Create a ModelContainer to be used in test and preview environments.
private func makeInMemoryContainer() -> ModelContainer {
  do {
    let schema = Schema(versionedSchema: ActiveSchema.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
    return try ModelContainer(for: schema, migrationPlan: nil, configurations: config)
  } catch {
    fatalError("Failed to create in-memory container.")
  }
}

private let previewContainer: ModelContainer = makeInMemoryContainer()

@MainActor private let liveContext: (() -> ModelContext) = { liveContainer.mainContext }
@MainActor private let previewContext: (() -> ModelContext) = { previewContainer.mainContext }
@MainActor private let testContext: (() -> ModelContext) = { ModelContext(makeInMemoryContainer()) }

#if hasFeature(RetroactiveAttribute)
extension KeyPath: @unchecked @retroactive Sendable {}
extension ModelContext: @unchecked @retroactive Sendable {}
#else
extension KeyPath: @unchecked Sendable {}
extension ModelContext: @unchecked Sendable {}
#endif
