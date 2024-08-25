import ComposableArchitecture
import Foundation
import SwiftData
import SwiftUI

@Reducer
struct FromStateFeature {
  typealias Path = RootFeature.Path

  @ObservableState
  struct State: Equatable {
    var path = StackState<Path.State>()
    var movies: [Movie] = []
    var titleSort: SortOrder? = .forward
    var isSearchFieldPresented = false
    var searchString: String = ""
    var fetchDescriptor: FetchDescriptor<MovieModel> {
      ActiveSchema.movieFetchDescriptor(titleSort: self.titleSort, searchString: searchString)
    }
  }

  enum Action: Sendable {
    case addButtonTapped
    case deleteSwiped(Movie)
    case favoriteSwiped(Movie)
    case onAppear
    case path(StackActionOf<Path>)
    case searchButtonTapped(Bool)
    case searchStringChanged(String)
    case titleSortChanged(SortOrder?)
    case toggleFavoriteState(Movie)
    // Reducer-only action to refresh the array of movies when another action changed what would be returned by the
    // `fetchDescriptor`.
    case _fetchMovies
  }

  @Dependency(\.database) var db

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped: return addRandomMovie(state: &state)
      case .deleteSwiped(let movie): return deleteMovie(movie)
      case .favoriteSwiped(let movie): return Utils.beginFavoriteChange(.toggleFavoriteState(movie))
      case .onAppear: return fetchChanges(state: &state)
      case .path(let pathAction): return monitorPathChange(pathAction, state: &state)
      case .searchButtonTapped(let enabled): return setSearchMode(enabled, state: &state)
      case .searchStringChanged(let query): return search(query, state: &state)
      case .titleSortChanged(let newSort): return setTitleSort(newSort, state: &state)
      case .toggleFavoriteState(let movie): return Utils.toggleFavoriteState(movie, movies: &state.movies)
      case ._fetchMovies: return fetchChanges(state: &state)
      }
    }
    .forEach(\.path, action: \.path)
  }
}

extension FromStateFeature {

  private var runSendFetchMovies: Effect<Action> {
    .run { @MainActor send in
      send(._fetchMovies, animation: .default)
    }
  }

  private func addRandomMovie(state: inout State) -> Effect<Action> {
    _ = db.add()
    return runSendFetchMovies
  }

  private func deleteMovie(_ movie: Movie) -> Effect<Action> {
    db.delete(movie.backingObject())
    return runSendFetchMovies
  }

  private func fetchChanges(state: inout State) -> Effect<Action> {
    @Dependency(\.database) var db
    state.movies = db.fetchMovies(state.fetchDescriptor).map { $0.valueType }
    return .none
  }

  private func monitorPathChange(_ pathAction: StackActionOf<Path>, state: inout State) -> Effect<Action> {
    switch pathAction {
    case .popFrom:
      if state.path.count == 1 {
        return fetchChanges(state: &state)
      }

    default:
      break
    }
    return .none
  }

  private func setSearchMode(_ enabled: Bool, state: inout State) -> Effect<Action> {
    state.isSearchFieldPresented = enabled
    return .none
  }

  private func search(_ query: String, state: inout State) -> Effect<Action> {
    if query != state.searchString {
      state.searchString = query
      return runSendFetchMovies
    }
    return .none
  }

  private func setTitleSort(_ sort: SortOrder?, state: inout State) -> Effect<Action> {
    state.titleSort = sort
    return runSendFetchMovies
  }
}

#Preview {
  FromStateView.preview
}
