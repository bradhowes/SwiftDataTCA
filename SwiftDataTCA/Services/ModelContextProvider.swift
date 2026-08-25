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
public struct ModelContextProvider {
  /// The context to use for SwiftData operations
  public let context: ModelContext
}

extension DependencyValues {
  public var modelContextProvider: ModelContext {
    get { self[ModelContextKey.self] }
    set { self[ModelContextKey.self] = newValue }
  }
}

public enum ModelContextKey: DependencyKey {
  public static var liveValue: ModelContext { liveContext() }
}

extension ModelContextKey: TestDependencyKey {
  public static var previewValue: ModelContext { previewContext() }
  public static var testValue: ModelContext {
    unimplemented("ModelContextProvider testValue", placeholder: ModelContextKey.testValue)
  }
}

/// Create a ModelContainer to be used in a live environment.
func makeLiveContainer(dbFile: URL) -> ModelContainer {
  let schema = Schema(versionedSchema: ActiveSchema.self)
  let config = ModelConfiguration(schema: schema, url: dbFile, cloudKitDatabase: .none)
  // swiftlint:disable force_try
  return try! ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: config)
  // swiftlint:enable force_try
}

private let liveContainer: ModelContainer = makeLiveContainer(
  dbFile: URL.applicationSupportDirectory.appending(path: "Models.sqlite")
)

internal func makeTestContext(mockCount: Int = 0) throws -> ModelContext {
  try makeMockContext(mockCount: mockCount)
}

internal func makeMockContext(mockCount: Int) throws -> ModelContext {
  let context = try ModelContext(makeInMemoryContainer())
  try Support.generateMocks(context: context, count: mockCount)
  return context
}

internal func makeInMemoryContainer() throws -> ModelContainer {
  let schema = Schema(versionedSchema: ActiveSchema.self)
  let config = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: true,
    groupContainer: .none,
    cloudKitDatabase: .none
  )
  return try ModelContainer(for: schema, migrationPlan: nil, configurations: config)
}

@MainActor internal let liveContext: (() -> ModelContext) = {
  if ProcessInfo.processInfo.arguments.contains("UITEST") {
    return makeContext(mockCount: 2)
  }
  return liveContainer.mainContext
}

@MainActor private let previewContext: (() -> ModelContext) = {
  makeContext(mockCount: 32)
}

@MainActor private func makeContext(mockCount: Int) -> ModelContext {
  // swiftlint:disable force_try
  try! makeMockContext(mockCount: mockCount)
  // swiftlint:enable force_try
}

#if hasFeature(RetroactiveAttribute)
extension KeyPath: @unchecked @retroactive Sendable {}
#else
extension KeyPath: @unchecked Sendable {}
extension ModelContext: @unchecked Sendable {}
#endif
