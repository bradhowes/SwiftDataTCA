import Dependencies
import Foundation
import SwiftData

struct Database {
  var fetchMovies: @Sendable (FetchDescriptor<Movie>) -> [Movie]
  var fetchActors: @Sendable (FetchDescriptor<Actor>) -> [Actor]
  var add: @Sendable () -> Void
  var delete: @Sendable (Movie) -> Void
  var save: @Sendable () -> Void
}

extension Database: DependencyKey {
  static let liveValue = Self(
    fetchMovies: { descriptor in
      @Dependency(\.modelContextProvider.context) var context
      return (try? context.fetch(descriptor)) ?? []
    },
    fetchActors: { descriptor in
      @Dependency(\.modelContextProvider.context) var context
      return (try? context.fetch(descriptor)) ?? []
    },
    add: {
      @Dependency(\.modelContextProvider.context) var context
      SchemaV4.makeMock(context: context)
    },
    delete: { model in
      @Dependency(\.modelContextProvider.context) var context
      context.delete(model)
    },
    save: {
      @Dependency(\.modelContextProvider.context) var context
      try? context.save()
    }
  )
}

extension Database: TestDependencyKey {
  public static let testValue = Self(
    fetchMovies: unimplemented("\(Self.self).fetchDescriptor"),
    fetchActors: unimplemented("\(Self.self).fetchDescriptor"),
    add: unimplemented("\(Self.self).add"),
    delete: unimplemented("\(Self.self).delete"),
    save: unimplemented("\(Self.self).save")
  )
}

extension DependencyValues {
  var database: Database {
    get { self[Database.self] }
    set { self[Database.self] = newValue }
  }
}
