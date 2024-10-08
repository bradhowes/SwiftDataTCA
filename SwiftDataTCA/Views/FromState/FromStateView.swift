import ComposableArchitecture
import Dependencies
import SwiftData
import SwiftUI

struct FromStateView: View {
  @Bindable var store: StoreOf<FromStateFeature>

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      MovieListView(store: store)
        .navigationTitle("FromState")
        .searchable(
          text: $store.searchText.sending(\.searchTextChanged),
          isPresented: $store.isSearchFieldPresented.sending(\.searchButtonTapped),
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
        .onAppear {
          store.send(.onAppear)
        }
    } destination: { store in
      switch store.case {
      case let .showMovieActors(store): MovieActorsView(store: store)
      case let .showActorMovies(store): ActorMoviesView(store: store)
      }
    }
  }
}

private struct MovieListView: View {
  var store: StoreOf<FromStateFeature>

  var body: some View {
    ScrollViewReader { proxy in
      List(store.movies, id: \.id) { movie in
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
  var store: StoreOf<FromStateFeature>
  let movie: Movie
  let actorNames: String
  @Dependency(\.viewLinkType) var viewLinkType

  init(store: StoreOf<FromStateFeature>, movie: Movie) {
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
      detailButton
        .fadeIn(enabled: store.highlight == movie, duration: 1.25) {
          store.send(.clearHighlight)
        }
    }
  }

  private var detailButton: some View {
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

extension FromStateView {
  static var previewWithLinks: some View {
    @Dependency(\.modelContextProvider) var context
    let store = Store(initialState: .init()) { FromStateFeature() }
    return FromStateView(store: store)
      .modelContext(context)
  }

  static var previewWithButtons: some View {
    @Dependency(\.modelContextProvider) var context
    let store = Store(initialState: .init()) { FromStateFeature() }
    return FromStateView(store: store)
      .modelContext(context)
  }
}

#Preview {
  FromStateView.previewWithLinks
}

#Preview {
  FromStateView.previewWithButtons
}
