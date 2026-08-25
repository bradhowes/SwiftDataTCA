import Foundation
import SwiftData

enum StageV3 {
  static var stage: MigrationStage {
    .custom(
      fromVersion: SchemaV2.self,
      toVersion: SchemaV3.self,
      willMigrate: nil
    ) { try addSortableTitles(context: $0) }
  }
}

private func addSortableTitles(context: ModelContext) throws {
  let movies = try context.fetch(FetchDescriptor<SchemaV3._Movie>())
  for movie in movies {
    movie.sortableTitle = Support.sortableTitle(movie.title)
  }
  try context.save()
}
