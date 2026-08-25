import Dependencies
import Foundation
import SwiftData

enum StageV4 {
  static var stage: MigrationStage {
    .custom(
      fromVersion: SchemaV3.self,
      toVersion: SchemaV4.self,
      willMigrate: { try exportV3(context: $0) },
      didMigrate: { try importV4(context: $0) }
    )
  }
}

private let migrationFile = FileManager.default.temporaryDirectory.appendingPathComponent("migrationV4.json")

/**
 Create a JSON representation of the known movies, save to disk, and then remove all movies.

 - parameter context: the V3 context to use
 */
private func exportV3(context: ModelContext) throws {
  try? FileManager.default.removeItem(at: migrationFile)

  let movies = try context.fetch(FetchDescriptor<SchemaV3._Movie>())
  let data = try JSONEncoder().encode(movies)
  try data.write(to: migrationFile, options: .atomic)

  for movie in movies {
    context.delete(movie)
  }

  try context.save()
}

/**
 Read a JSON representation of the movies to add, create movies and actors.

 - parameter context: the V4 context to use
 */
private func importV4(context: ModelContext) throws {
  @Dependency(\.uuid) var uuid
  let movies = try JSONDecoder().decode([MovieImport].self, from: Data(contentsOf: migrationFile))
  try? FileManager.default.removeItem(at: migrationFile)
  for old in movies {
    let movie = SchemaV4._Movie(id: old.id, title: old.title, favorite: old.favorite)
    context.insert(movie)
    let actors = old.cast.map { SchemaV4.fetchOrMakeActor(context, name: $0) }
    movie.actors = actors
    for actor in actors {
      actor.movies.append(movie)
    }
  }
  try context.save()
}

extension SchemaV3._Movie: Encodable {
  enum CodingKeysV3: CodingKey {
    case id, title, cast, favorite
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeysV3.self)
    try container.encode(self.id, forKey: .id)
    try container.encode(self.title, forKey: .title)
    try container.encode(self.cast, forKey: .cast)
    try container.encode(self.favorite, forKey: .favorite)
  }
}

private struct MovieImport: Decodable {
  let id: UUID
  let title: String
  let cast: [String]
  let favorite: Bool

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: SchemaV3._Movie.CodingKeysV3.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.title = try container.decode(String.self, forKey: .title)
    self.cast = try container.decode(Array<String>.self, forKey: .cast)
    self.favorite = try container.decode(Bool.self, forKey: .favorite)
  }
}
