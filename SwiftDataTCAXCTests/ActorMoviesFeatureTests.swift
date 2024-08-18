import ComposableArchitecture
import Dependencies
import Foundation
import SnapshotTesting
import SwiftData
import SwiftUI
import XCTest

@testable import SwiftDataTCA

final class ActorMoviesFeatureTests: XCTestCase {
  var context: ModelContext!
  var actor: ActorModel!

  override func setUpWithError() throws {
    let schema = Schema(versionedSchema: ActiveSchema.self)
    let config = ModelConfiguration("ActiveSchema", schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    context = ModelContext(container)
    ActiveSchema.makeMock(context: context, entry: ("This is a Movie", ["Actor 1", "Actor 2"]))
    ActiveSchema.makeMock(context: context, entry: ("Another Movie", ["Actor 1", "Actor 2", "Actor 3"]))
    try! context.save()
    let actors = try! context.fetch(FetchDescriptor<ActorModel>(sortBy: [.init(\.name, order: .forward)]))
    actor = actors[0]
  }

  override func tearDownWithError() throws {
  }

  @MainActor
  func testFavoriteSwiped() async throws {
    let store = TestStore(initialState: ActorMoviesFeature.State(actor: actor)) {
      ActorMoviesFeature()
    }

    XCTAssertFalse(actor.movies[0].favorite)
    await store.send(.favoriteSwiped(actor.movies[0]))
    XCTAssertTrue(actor.movies[0].favorite)
    await store.send(.favoriteSwiped(actor.movies[0]))
    XCTAssertFalse(actor.movies[0].favorite)
  }

  @MainActor
  func testMovieSelected() async throws {
    let store = TestStore(initialState: ActorMoviesFeature.State(actor: actor)) {
      ActorMoviesFeature()
    }

    XCTAssertEqual(actor.name, "Actor 1")
    XCTAssertEqual(actor.movies.count, 2)
    await store.send(.movieSelected(actor.movies[1])) // No state change for this
  }

  @MainActor
  func testTitleSortChanged() async throws {
    let store = TestStore(initialState: ActorMoviesFeature.State(actor: actor, titleSort: .forward)) {
      ActorMoviesFeature()
    }

    XCTAssertEqual(actor.name, "Actor 1")
    XCTAssertEqual(actor.movies.count, 2)

    await store.send(.titleSortChanged(.reverse)) {
      $0.titleSort = .reverse
      XCTAssertEqual($0.movies[0].title, "This is a Movie")
      XCTAssertEqual($0.movies[1].title, "Another Movie")
    }

    await store.send(.titleSortChanged(.forward)) {
      $0.titleSort = .forward
      XCTAssertEqual($0.movies[0].title, "Another Movie")
      XCTAssertEqual($0.movies[1].title, "This is a Movie")
    }

    await store.send(.titleSortChanged(.none)) {
      $0.titleSort = nil
      XCTAssertTrue($0.movies[0].title == "Another Movie" || $0.movies[0].title == "This is a Movie")
      XCTAssertTrue($0.movies[1].title == "Another Movie" || $0.movies[1].title == "This is a Movie")
    }
  }

  @MainActor
  func testPreviewRender() throws {
    let view = ActorMoviesView.preview
    try assertSnapshot(matching: view)
  }
}

private struct TestApp: App {
  var body: some Scene {
    WindowGroup {
    }
  }
}

#if hasFeature(RetroactiveAttribute)
extension ActorMoviesFeature.State: @retroactive Equatable {
  public static func == (lhs: ActorMoviesFeature.State, rhs: ActorMoviesFeature.State) -> Bool {
    lhs.actor == rhs.actor &&
    lhs.titleSort == rhs.titleSort
  }
}
#else
extension ActorMoviesFeature.State: Equatable {
  public static func == (lhs: ActorMoviesFeature.State, rhs: ActorMoviesFeature.State) -> Bool {
    lhs.actor == rhs.actor &&
    lhs.titleSort == rhs.titleSort
  }
}
#endif