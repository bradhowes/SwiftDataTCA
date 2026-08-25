import Foundation
import SwiftData

enum StageV5 {
  static var stage: MigrationStage {
    .custom(
      fromVersion: SchemaV4.self,
      toVersion: SchemaV5.self,
      willMigrate: { try exportV4(context: $0) },
      didMigrate: { try importV5(context: $0) }
    )
  }
}

private let migrationFile = FileManager.default.temporaryDirectory.appendingPathComponent("migrationV5.json")

/**
 Create a JSON representation of the known movies, save to disk, and then remove all movies and actors.

 - parameter context: the V4 context to use
 */
private func exportV4(context: ModelContext) throws {
  try? FileManager.default.removeItem(at: migrationFile)

  let movies = try context.fetch(FetchDescriptor<SchemaV4._Movie>())
  let data = try JSONEncoder().encode(movies)
  try data.write(to: migrationFile, options: .atomic)

  for movie in movies {
    context.delete(movie)
  }

  let actors = try context.fetch(FetchDescriptor<SchemaV4._Actor>())
  for actor in actors {
    context.delete(actor)
  }

  try context.save()
}

/**
 Read a JSON representation of the movies to add, create movies and actors.

 - parameter context: the V5 context to use
 */
private func importV5(context: ModelContext) throws {
  let movies = try JSONDecoder().decode([MovieImport].self, from: Data(contentsOf: migrationFile))
  try? FileManager.default.removeItem(at: migrationFile)
  for old in movies {
    let movie = SchemaV5._Movie(title: old.title, favorite: old.favorite)
    context.insert(movie)
    let actors = old.actors.map { SchemaV5.fetchOrMakeActor(context, name: $0) }
    movie.actors = actors
    for actor in actors {
      actor.movies.append(movie)
    }
  }
  try context.save()
}

extension SchemaV4._Movie: Encodable {

  /// Movies are encoded into a JSON object containg the movie title, a list of actor names, and a boolean indicating
  /// the favorite state.
  enum CodingKeysV4: CodingKey {
    case title, actors, favorite
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeysV4.self)
    try container.encode(self.title, forKey: .title)
    try container.encode(self.actors.map(\.name), forKey: .actors)
    try container.encode(self.favorite, forKey: .favorite)
  }
}

private struct MovieImport: Decodable {
  let title: String
  let actors: [String]
  let favorite: Bool

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: SchemaV4._Movie.CodingKeysV4.self)
    self.title = try container.decode(String.self, forKey: .title)
    self.actors = try container.decode(Array<String>.self, forKey: .actors)
    self.favorite = try container.decode(Bool.self, forKey: .favorite)
  }
}
