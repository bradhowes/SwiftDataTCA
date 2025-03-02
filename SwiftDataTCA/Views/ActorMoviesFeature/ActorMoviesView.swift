import ComposableArchitecture
import Dependencies
import SwiftData
import SwiftUI

struct ActorMoviesView: View {
  @Bindable var store: StoreOf<ActorMoviesFeature>

  var body: some View {
    MoviesListView(store: store)
      .navigationTitle(store.actor.name)
      .toolbar(.hidden, for: .tabBar)
      .toolbar {
        ToolbarItemGroup(placement: .automatic) {
          Utils.pickerView(title: "movie ordering", binding: $store.titleSort.sending(\.titleSortChanged).animation())
        }
      }
      .labelsHidden()
  }
}

private struct MoviesListView: View {
  var store: StoreOf<ActorMoviesFeature>
  @Dependency(\.viewLinkType) var viewLinkType

  var body: some View {
    List(store.movies, id: \.id) { movie in
      withSwipeActions(movie: movie) {
        if viewLinkType == .button {
          Button {
            _ = store.send(.detailButtonTapped(movie))
          } label: {
            Utils.MovieView(
              name: movie.name,
              favorite: movie.favorite,
              actorNames: Utils.actorNamesList(for: movie),
              showChevron: true
            )
          }
        } else {
          NavigationLink(state: RootFeature.showMovieActors(movie)) {
            Utils.MovieView(
              name: movie.name,
              favorite: movie.favorite,
              actorNames: Utils.actorNamesList(for: movie),
              showChevron: false
            )
          }
        }
      }
    }.onAppear {
      store.send(.refresh)
    }
  }
}

extension MoviesListView {

  func withSwipeActions<T>(movie: Movie, @ViewBuilder content: () -> T) -> some View where T: View {
    content()
      .swipeActions {
        Utils.favoriteSwipeAction(movie) {
          store.send(.favoriteSwiped(movie), animation: .bouncy)
        }
      }
  }
}

extension ActorMoviesView {
  static var preview: some View {
    @Dependency(\.modelContextProvider) var context
    let actorModel = ActiveSchema.fetchOrMakeActor(context, name: "Marlon Brando")
    let movies = actorModel.sortedMovies(order: .forward)
    movies[0].favorite = true
    return NavigationView {
      ActorMoviesView(store: Store(initialState: .init(actor: actorModel.valueType)) {
        ActorMoviesFeature()
      })
      .modelContext(context)
    }
  }
}

#Preview {
  ActorMoviesView.preview
}
