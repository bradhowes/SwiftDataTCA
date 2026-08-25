import Dependencies
import Foundation
import SwiftData

enum SchemaV3: VersionedSchema {
  static var versionIdentifier: Schema.Version { .init(3, 0, 0) }

  static var models: [any PersistentModel.Type] {
    [_Movie.self]
  }

  @Model
  final class _Movie {
    var id: UUID
    var title: String
    var cast: [String]
    var favorite: Bool = false
    var sortableTitle: String = ""

    init(id: UUID, title: String, cast: [String], favorite: Bool = false) {
      self.id = id
      self.title = title
      self.cast = cast
      self.favorite = favorite
      self.sortableTitle = Support.sortableTitle(title)
    }
  }
}

extension SchemaV3 {

  static func makeMock(context: ModelContext, entry: (title: String, cast: [String])) {
    @Dependency(\.uuid) var uuid
    let movie = _Movie(id: uuid(), title: entry.title, cast: entry.cast)
    context.insert(movie)
  }

  static func searchPredicate(_ search: String) -> Predicate<_Movie>? {
    search.isEmpty ? nil : #Predicate<_Movie> { $0.title.localizedStandardContains(search) }
  }

  /**
   Obtain a `FetchDescriptor` that will return an ordered (optional) and possibly filtered set of known `_Movie`
   entities. Ordering is done on the `_Movie.title` and `_Movie.id` attributes when `titleSort` and/or `uuidSort`
   is not nil. Otherwise, ordering is undetermined.

   - parameter titleSort: the direction of the `title` ordering -- alphabetical or reveresed alphabetical
   - parameter uuidSort: the direction of the `id` ordering -- alphabetical or reveresed alphabetical
   - parameter searchString: if not empty, only return `_Movie` entities whose `title` contains the search string
   - returns: new `FetchDescriptor`
   */
  static func movieFetchDescriptor(
    titleSort: SortOrder?,
    uuidSort: SortOrder?,
    search: String
  ) -> FetchDescriptor<_Movie> {
    let sortBy: [SortDescriptor<_Movie>] = Support.sortBy(
      .sortBy(\.sortableTitle, order: titleSort),
      .sortBy(\.id, order: uuidSort)
    )
    return FetchDescriptor(predicate: searchPredicate(search), sortBy: sortBy)
  }
}
