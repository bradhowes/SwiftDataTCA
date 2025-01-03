import ComposableArchitecture
import Dependencies
import SwiftData
import SwiftUI

struct MovieActorsView: View {
  @Bindable var store: StoreOf<MovieActorsFeature>

  var body: some View {
    ActorsListView(store: store)
      .navigationTitle(store.movie.name)
      .toolbar(.hidden, for: .tabBar)
      .toolbar {
        ToolbarItemGroup(placement: .automatic) {
          Utils.pickerView(title: "actor ordering", binding: $store.nameSort.sending(\.nameSortChanged).animation())
          favoriteButton
        }
      }
      .labelsHidden()
      .onAppear { store.send(.refresh) }
  }

  private var favoriteButton: some View {
    Button {
      store.send(.favoriteTapped)
    } label: {
      if store.movie.favorite {
        Image(systemName: "star.fill")
          .accessibilityLabel("unfavorite movie")
          .foregroundStyle(Utils.favoriteColor)
          .transition(.confetti(color: Utils.favoriteColor, size: 3, enabled: store.animateButton))
      } else {
        Image(systemName: "star")
          .accessibilityLabel("favorite movie")
      }
    }
  }
}

private struct ActorsListView: View {
  @Bindable var store: StoreOf<MovieActorsFeature>
  @Dependency(\.viewLinkType) var viewLinkType

  var body: some View {
    List(store.actors, id: \.id) { actor in
      if viewLinkType == .navLink {
        NavigationLink(state: RootFeature.showActorMovies(actor)) {
          Utils.ActorView(name: actor.name, movieTitles: Utils.movieTitlesList(for: actor), showChevron: false)
        }
      } else {
        Button {
          store.send(.detailButtonTapped(actor))
        } label: {
          Utils.ActorView(name: actor.name, movieTitles: Utils.movieTitlesList(for: actor), showChevron: true)
        }
      }
    }
  }
}

extension MovieActorsView {
  static var preview: some View {
    @Dependency(\.modelContextProvider) var context
    let movies = (try? context.fetch(ActiveSchema.movieFetchDescriptor(titleSort: .forward))) ?? []
    let movie = movies[0].valueType
    return NavigationView {
      MovieActorsView(store: Store(initialState: .init(movie: movie)) { MovieActorsFeature() })
        .modelContext(context)
    }.navigationViewStyle(.stack)
  }
}

#Preview {
  MovieActorsView.preview
}
