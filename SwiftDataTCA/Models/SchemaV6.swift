import Foundation
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
    let name: String
    var movies: [MovieModel]

    init(name: String) {
      self.name = name
      self.movies = []
    }

    var asStruct: Actor {
      .init(
        modelId: self.persistentModelID,
        name: self.name,
        movies: self.movies
          .sorted { $0.sortableTitle.localizedCompare($1.sortableTitle) == .orderedAscending }
          .map { .init(name: $0.title, modelId: $0.persistentModelID ) }
      )
    }
  }

  @Model
  final class MovieModel {
    let title: String
    var favorite: Bool = false
    var sortableTitle: String = ""
    @Relationship(inverse: \ActorModel.movies) var actors: [ActorModel]

    init(title: String, favorite: Bool = false) {
      self.title = title
      self.favorite = favorite
      self.sortableTitle = Support.sortableTitle(title)
      self.actors = []
    }

    var asStruct: Movie {
      .init(
        modelId: self.persistentModelID,
        title: self.title,
        favorite: self.favorite,
        sortableTitle: self.sortableTitle,
        actors: self.actors
          .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
          .map { .init(name: $0.name, modelId: $0.persistentModelID) }
      )
    }
  }

  struct NamedPersistentIdentifier {
    let name: String
    let modelId: PersistentIdentifier

    func resolve<T: PersistentModel>(in context: ModelContext) -> T {
      if let value = context.model(for: modelId) as? T {
        return value
      }
      fatalError("Failed to resolve model \(name) : \(modelId)")
    }
  }

  struct Actor {
    let modelId: PersistentIdentifier
    let name: String
    let movies: [NamedPersistentIdentifier]
  }

  struct Movie {
    let modelId: PersistentIdentifier
    let title: String
    let favorite: Bool
    let sortableTitle: String
    let actors: [NamedPersistentIdentifier]
  }

  @discardableResult
  static func makeMock(context: ModelContext, entry: (title: String, cast: [String])) -> MovieModel {
    let movie = MovieModel(title: entry.0)
    context.insert(movie)

    let actors = entry.cast.map { fetchOrMakeActor(context, name: $0) }
    movie.actors = actors
    for actor in actors {
      actor.movies.append(movie)
    }

    return movie
  }

  static func fetchOrMakeActor(_ context: ModelContext, name: String) -> ActorModel {
    let predicate = #Predicate<ActorModel> { $0.name == name }
    let fetchDescriptor = FetchDescriptor<ActorModel>(predicate: predicate)
    if let actors = (try? context.fetch(fetchDescriptor)), !actors.isEmpty {
      return actors[0]
    }

    let actor = ActorModel(name: name)
    context.insert(actor)

    return actor
  }

  static func searchPredicate(_ searchString: String) -> Predicate<MovieModel>? {
    searchString.isEmpty ? nil : #Predicate<MovieModel> { $0.title.localizedStandardContains(searchString) }
  }

  /**
   Obtain a `FetchDescriptor` that will return an ordered (optional) and possibly filtered set of known `_Movie`
   entities. Ordering is done on the `_Movie.title` attribute when `titleSort` is not nil. Otherwise, ordering
   is undetermined.

   - parameter titleSort: the direction of the ordering -- alphabetical or reveresed alphabetical
   - parameter searchString: if not empty, only return `_Movie` entities whose `title` contains the search string
   - returns: new `FetchDescriptor`
   */
  static func movieFetchDescriptor(titleSort: SortOrder?, searchString: String) -> FetchDescriptor<MovieModel> {
    let sortBy: [SortDescriptor<MovieModel>] = Support.sortBy(.sortBy(\.sortableTitle, order: titleSort))
    var fetchDescriptor = FetchDescriptor(predicate: searchPredicate(searchString), sortBy: sortBy)
    fetchDescriptor.relationshipKeyPathsForPrefetching = [\.actors]
    return fetchDescriptor
  }
}

extension SchemaV6.MovieModel: Sendable {}
extension SchemaV6.ActorModel: Sendable {}