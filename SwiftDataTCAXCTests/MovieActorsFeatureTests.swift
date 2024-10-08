import ComposableArchitecture
import Dependencies
import Foundation
import SnapshotTesting
import SwiftData
import XCTest

@testable import SwiftDataTCA


final class MovieActorsFeatureTests: XCTestCase {

  var store: TestStoreOf<MovieActorsFeature>!
  var context: ModelContext { store.dependencies.modelContextProvider }

  override func setUpWithError() throws {
    // isRecording = true
    store = try withDependencies {
      $0.modelContextProvider = try makeTestContext(mockCount: 3)
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Dependency(\.modelContextProvider) var context
      let movies = try context.fetch(FetchDescriptor<MovieModel>())
      return TestStore(initialState: MovieActorsFeature.State(movie: movies[0].valueType)) {
        MovieActorsFeature()
      }
    }
  }

  override func tearDownWithError() throws {
    context.container.deleteAllData()
  }

  @MainActor
  func testDetailButtonTapped() async throws {
    await store.send(.detailButtonTapped(store.state.actors[0]))
  }

  @MainActor
  func testFavoriteTapped() async throws {
    XCTAssertTrue(store.state.movie.favorite)
    await store.send(.favoriteTapped) {
      $0.movie = $0.movie.toggleFavorite()
    }
    XCTAssertFalse(store.state.movie.favorite)
    await store.send(.favoriteTapped) {
      $0.movie = $0.movie.toggleFavorite()
      $0.animateButton = true
    }
    XCTAssertTrue(store.state.movie.favorite)
  }

  @MainActor
  func testNameSortChanged() async throws {
    XCTAssertEqual(store.state.movie.name, "The Score")
    XCTAssertEqual(store.state.actors.count, 5)

    await store.send(.nameSortChanged(.reverse)) {
      $0.nameSort = .reverse
      $0.actors = IdentifiedArrayOf<Actor>(uncheckedUniqueElements: $0.actors.elements.reversed())
    }

    await store.send(.nameSortChanged(.forward)) {
      $0.nameSort = .forward
      $0.actors = IdentifiedArrayOf<Actor>(uncheckedUniqueElements: $0.actors.elements.reversed())
    }

    store.exhaustivity = .off
    await store.send(.nameSortChanged(.none)) {
      $0.nameSort = nil
    }

    let names = Set(store.state.actors.map(\.name))
    XCTAssertEqual(names.count, 5)

    XCTAssertTrue(names.contains(store.state.actors[0].name))
    XCTAssertTrue(names.contains(store.state.actors[1].name))
    XCTAssertTrue(names.contains(store.state.actors[2].name))
    XCTAssertTrue(names.contains(store.state.actors[3].name))
    XCTAssertTrue(names.contains(store.state.actors[4].name))
  }

  @MainActor
  func testRefresh() async throws {
    await store.send(.refresh)
  }

  @MainActor
  func testPreviewRenderWithButtons() throws {
    try withDependencies {
      $0.modelContextProvider = ModelContextKey.previewValue
      $0.viewLinkType = LinkKind.button
    } operation: {
      try withSnapshotTesting(record: .failed) {
        let view = MovieActorsView.preview
        try assertSnapshot(matching: view)
      }
    }
  }

  @MainActor
  func SKIP_testPreviewRenderWithLinks() throws {
    try withDependencies {
      $0.modelContextProvider = ModelContextKey.previewValue
      $0.viewLinkType = LinkKind.navLink
    } operation: {
      try withSnapshotTesting(record: .failed) {
        let view = MovieActorsView.preview
        try assertSnapshot(matching: view)
      }
    }
  }
}
