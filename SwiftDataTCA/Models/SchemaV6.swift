import Dependencies
import Foundation
import IdentifiedCollections
import SwiftData

/// Schema v6 - rename models and operate with structs in views
enum SchemaV6: VersionedSchema {
  static var versionIdentifier: Schema.Version { .init(6, 0, 0) }

  static var models: [any PersistentModel.Type] {
    [
      ActorModel.self,
      MovieModel.self
    ]
  }

  @Model
  final class ActorModel {
    var name: String
    var movies: [MovieModel]

    init(name: String) {
      self.name = name
      self.movies = []
    }

    var valueType: Actor { .init(modelId: persistentModelID, name: name) }

    func sortedMovies(order: SortOrder?) -> [MovieModel] {
      switch order {
      case .forward: return movies.sorted { $0.sortableTitle.localizedCompare($1.sortableTitle) == .orderedAscending }
      case .reverse: return movies.sorted { $0.sortableTitle.localizedCompare($1.sortableTitle) == .orderedDescending }
      case nil: return movies
      }
    }
  }

  @Model
  final class MovieModel {
    var title: String
    var favorite: Bool = false
    var sortableTitle: String = ""
    @Relationship(inverse: \ActorModel.movies) var actors: [ActorModel]

    init(title: String, favorite: Bool = false) {
      self.title = title
      self.favorite = favorite
      self.sortableTitle = Support.sortableTitle(title)
      self.actors = []
    }

    var valueType: Movie { .init(modelId: persistentModelID, name: title, favorite: favorite) }

    func sortedActors(order: SortOrder?) -> [ActorModel] {
      switch order {
      case .forward: return actors.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
      case .reverse: return actors.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
      case nil: return actors
      }
    }
  }

  struct Actor {
    let modelId: PersistentIdentifier
    let name: String

    func movies(ordering: SortOrder?) -> IdentifiedArrayOf<Movie> {
      @Dependency(\.modelContextProvider) var context
      return .init(uncheckedUniqueElements: backingObject().sortedMovies(order: ordering).map(\.valueType))
    }

    @discardableResult
    private func backingObject() -> ActorModel {
      @Dependency(\.modelContextProvider) var context
      guard let actor = context.model(for: self.modelId) as? ActorModel else {
        fatalError("Faied to resolve \(self.name) using \(self.modelId)")
      }
      return actor
    }
  }

  struct Movie {
    let modelId: PersistentIdentifier
    let name: String
    let favorite: Bool

    func toggleFavorite() -> Movie {
      backingObject { $0.favorite.toggle() }
      return .init(modelId: modelId, name: name, favorite: !favorite)
    }

    /**
     Obtain an order collection of the actors for the movie.

     NOTE: this must only be called when Movie is valid. In particular do not lazy fetch the actors to build a view
     which might need an update after deleting the Movie it is based on.

     - parameter ordering how to order the Actor instances by their names
     - returns IndentifiedArray of Actor values
     */
    func actors(ordering: SortOrder?) -> IdentifiedArrayOf<Actor> {
      .init(uncheckedUniqueElements: backingObject().sortedActors(order: ordering).map(\.valueType))
    }

    /**
     Obtain the MovieModel instance for this struct.

     NOTE: this is risky if called when the Movie has been deleted.

     - parameter performing an optional block to execute with the MovieModel instance
     - returns MovieModel instance
     */
    @discardableResult
    func backingObject(performing: ((MovieModel) -> Void)? = nil) -> MovieModel {
      @Dependency(\.modelContextProvider) var context
      guard let movie = context.model(for: self.modelId) as? MovieModel else {
        fatalError("Faied to resolve \(self.name) usiing \(self.modelId)")
      }
      if let performing {
        performing(movie)
        try? context.save()
      }
      return movie
    }
  }
}

extension SchemaV6.Actor: Identifiable {
  public var id: PersistentIdentifier { modelId }
}

extension SchemaV6.Actor: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

extension SchemaV6.Movie: Identifiable {
  public var id: PersistentIdentifier { modelId }
}

extension SchemaV6.Movie: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.favorite == rhs.favorite }
}

extension SchemaV6 {

  @discardableResult
  static func makeMock(context: ModelContext, entry: (title: String, cast: [String])) -> MovieModel {
    let movie = MovieModel(title: entry.0)
    context.insert(movie)

    let actors = entry.cast.map { fetchOrMakeActor(context, name: $0) }
    movie.actors = actors
    for actor in actors {
      actor.movies.append(movie)
    }

    try? context.save()

    return movie
  }

  static func fetchOrMakeActor(_ context: ModelContext, name: String) -> ActorModel {
    let predicate = #Predicate<ActorModel> { $0.name == name }
    let fetchDescriptor = FetchDescriptor<ActorModel>(predicate: predicate)

    let actors = try? context.fetch(fetchDescriptor)
    if let actors, !actors.isEmpty {
      return actors[0]
    }

    let actor = ActorModel(name: name)
    context.insert(actor)
    try? context.save()

    return actor
  }

  @inlinable
  static func searchPredicate(_ search: String) -> Predicate<MovieModel>? {
    search.isEmpty ? nil : #Predicate<MovieModel> { $0.title.localizedStandardContains(search) }
  }

  /**
   Obtain a `FetchDescriptor` that will return an ordered (optional) and possibly filtered set of known `_Movie`
   entities. Ordering is done on the `_Movie.title` attribute when `titleSort` is not nil. Otherwise, ordering
   is undetermined.

   - parameter titleSort: the direction of the ordering -- alphabetical or reveresed alphabetical
   - parameter search: if not empty, only return `_Movie` entities whose `title` contains the search string
   - returns: new `FetchDescriptor`
   */
  static func movieFetchDescriptor(
    titleSort: SortOrder? = .forward,
    search: String = ""
  ) -> FetchDescriptor<MovieModel> {
    let sortBy: [ SortDescriptor<MovieModel>] = Support.sortBy(.sortBy(\.sortableTitle, order: titleSort))
    var fetchDescriptor = FetchDescriptor(predicate: searchPredicate(search), sortBy: sortBy)
    fetchDescriptor.relationshipKeyPathsForPrefetching = [\.actors]
    return fetchDescriptor
  }

  static func deleteMovie(_ context: ModelContext, movie: MovieModel) throws {
    let actors = movie.actors
    movie.actors = []
    for actor in actors {
      actor.movies = actor.movies.filter { $0 != movie }
      if actor.movies.isEmpty {
        context.delete(actor)
      }
    }

    context.delete(movie)

    try context.save()
  }
}
