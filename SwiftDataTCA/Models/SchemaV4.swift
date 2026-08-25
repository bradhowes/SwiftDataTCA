import Dependencies
import Foundation
import SwiftData

/// Schema v4 has a new `_Actor` model that holds the unique name of an actor. It also establishes a many-to-many
/// relationship between `_Movie` entities and `_Actor` entities.
enum SchemaV4: VersionedSchema {
  static var versionIdentifier: Schema.Version { .init(4, 0, 0) }

  static var models: [any PersistentModel.Type] {
    [
      _Actor.self,
      _Movie.self
    ]
  }

  @Model
  final class _Actor {
    var id: UUID
    var name: String
    var movies: [_Movie]

    init(id: UUID, name: String) {
      self.id = id
      self.name = name
      self.movies = []
    }
  }

  @Model
  final class _Movie {
    var id: UUID
    var title: String
    var favorite: Bool = false
    var sortableTitle: String = ""
    @Relationship(inverse: \_Actor.movies) var actors: [_Actor]

    init(id: UUID, title: String, favorite: Bool = false) {
      self.id = id
      self.title = title
      self.favorite = favorite
      self.sortableTitle = Support.sortableTitle(title)
      self.actors = []
    }
  }
}

extension SchemaV4 {

  static func makeMock(context: ModelContext, entry: (title: String, cast: [String])) {
    @Dependency(\.uuid) var uuid
    let movie = _Movie(id: uuid(), title: entry.title)
    context.insert(movie)

    let actors = entry.cast.map { fetchOrMakeActor(context, name: $0) }
    movie.actors = actors
    for actor in actors {
      actor.movies.append(movie)
    }
  }

  static func fetchOrMakeActor(_ context: ModelContext, name: String) -> _Actor {
    @Dependency(\.uuid) var uuid
    let predicate = #Predicate<_Actor> { $0.name == name }
    let fetchDescriptor = FetchDescriptor<_Actor>(predicate: predicate)
    if let actors = (try? context.fetch(fetchDescriptor)), !actors.isEmpty {
      return actors[0]
    }

    let actor = _Actor(id: uuid(), name: name)
    context.insert(actor)

    return actor
  }

  static func searchPredicate(_ search: String) -> Predicate<_Movie>? {
    search.isEmpty ? nil : #Predicate<_Movie> { $0.title.localizedStandardContains(search) }
  }

  /**
   Obtain a `FetchDescriptor` that will return an ordered (optional) and possibly filtered set of known `_Movie`
   entities. Ordering is done on the `_Movie.title` attribute when `titleSort` is not nil. Otherwise, ordering
   is undetermined.

   - parameter titleSort: the direction of the ordering -- alphabetical or reveresed alphabetical
   - parameter searchString: if not empty, only return `_Movie` entities whose `title` contains the search string
   - returns: new `FetchDescriptor`
   */
  static func movieFetchDescriptor(titleSort: SortOrder?, search: String) -> FetchDescriptor<_Movie> {
    let sortBy: [SortDescriptor<_Movie>] = Support.sortBy(.sortBy(\.sortableTitle, order: titleSort))
    var fetchDescriptor = FetchDescriptor(predicate: searchPredicate(search), sortBy: sortBy)
    fetchDescriptor.relationshipKeyPathsForPrefetching = [\.actors]

    return fetchDescriptor
  }
}
