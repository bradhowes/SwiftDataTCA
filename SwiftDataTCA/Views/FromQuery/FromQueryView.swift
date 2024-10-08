import ComposableArchitecture
import Dependencies
import SwiftData
import SwiftUI

struct FromQueryView: View {
  @Bindable var store: StoreOf<FromQueryFeature>

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      MovieListView(store: store)
        .navigationTitle("FromQuery")
        .searchable(
          text: $store.searchText.sending(\.searchTextChanged),
          isPresented: $store.isSearchFieldPresented.sending(\.searchButtonTapped),
          placement: .automatic,
          prompt: "Title"
        )
        .toolbar {
          if !store.isSearchFieldPresented {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
              Button("add", systemImage: "plus") { store.send(.addButtonTapped) }
              Utils.pickerView(title: "movie ordering", binding: $store.titleSort.sending(\.titleSortChanged).animation())
            }
          }
        }
        .labelsHidden()
    } destination: { store in
      switch store.case {
      case let .showMovieActors(store): MovieActorsView(store: store)
      case let .showActorMovies(store): ActorMoviesView(store: store)
      }
    }
  }
}

private struct MovieListView: View {
  var store: StoreOf<FromQueryFeature>
  @Query var moviesQuery: [MovieModel]
  var movies: [Movie] { moviesQuery.map(\.valueType) }

  init(store: StoreOf<FromQueryFeature>) {
    self.store = store
    self._moviesQuery = Query(self.store.fetchDescriptor, animation: .default)
  }

  var body: some View {
    ScrollViewReader { proxy in
      List(movies, id: \.id) { movie in
        MovieListRow(store: store, movie: movie)
          .swipeActions(allowsFullSwipe: false) {
            Utils.deleteSwipeAction(movie) {
              store.send(.deleteSwiped(movie), animation: .snappy)
            }
            Utils.favoriteSwipeAction(movie) {
              store.send(.favoriteSwiped(movie), animation: .bouncy)
            }
          }
      }
      .onChange(of: store.scrollTo) { _, movie in
        if let movie {
          withAnimation {
            proxy.scrollTo(movie.id)
          }
          store.send(.clearScrollTo)
        }
      }
    }
  }
}

private struct MovieListRow: View {
  var store: StoreOf<FromQueryFeature>
  let movie: Movie
  let actorNames: String
  @Dependency(\.viewLinkType) var viewLinkType

  init(store: StoreOf<FromQueryFeature>, movie: Movie) {
    self.store = store
    self.movie = movie
    // Fetch the actor names while we know that the Movie is valid.
    self.actorNames = Utils.actorNamesList(for: movie)
  }

  var body: some View {
    if viewLinkType == .navLink {
      RootFeature.link(movie)
        .fadeIn(enabled: store.highlight == movie, duration: 1.25) {
          store.send(.clearHighlight)
        }
    } else {
      detailButton(movie)
        .fadeIn(enabled: store.highlight == movie, duration: 1.25) {
          store.send(.clearHighlight)
        }
    }
  }

  private func detailButton(_ movie: Movie) -> some View {
    Button {
      _ = store.send(.detailButtonTapped(movie))
    } label: {
      Utils.MovieView(
        name: movie.name,
        favorite: movie.favorite,
        actorNames: actorNames,
        showChevron: true
      )
    }
  }
}

extension FromQueryView {
  static var previewWithLinks: some View {
    @Dependency(\.modelContextProvider) var context
    return FromQueryView(store: Store(initialState: .init()) { FromQueryFeature() })
      .modelContext(context)
  }

  static var previewWithButtons: some View {
    @Dependency(\.modelContextProvider) var context
    return FromQueryView(store: Store(initialState: .init()) { FromQueryFeature() })
      .modelContext(context)
  }
}

#Preview {
  FromQueryView.previewWithLinks
}

#Preview {
  FromQueryView.previewWithButtons
}
