import SwiftUI

/// Onboarding affiché au premier lancement : présente la philosophie open source
/// et les fonctions clés de MaxiTerm.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let message: String
        let tint: Color
    }

    private let pages: [Page] = [
        Page(
            symbol: "terminal.fill",
            title: "Bienvenue dans MaxiTerm",
            message: "Le client SSH, SFTP et remote pour iPhone et iPad — entièrement open source.",
            tint: .green
        ),
        Page(
            symbol: "lock.open.fill",
            title: "100% gratuit, sans paywall",
            message: "Toutes les fonctions incluses, pour toujours. Zéro abonnement, zéro pub, zéro tracking.",
            tint: .blue
        ),
        Page(
            symbol: "checkmark.shield.fill",
            title: "Sécurisé et auditable",
            message: "Couche SSH 100% Apple, clés dans le trousseau iCloud, validation TOFU des clés hôtes. "
                + "Sources publiques et vérifiables.",
            tint: .indigo
        ),
        Page(
            symbol: "server.rack",
            title: "Prêt à commencer",
            message: "Ajoutez un serveur SSH, ouvrez un terminal en onglets, parcourez vos fichiers en SFTP.",
            tint: .teal
        ),
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    pageView(item).tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: advance) {
                Text(page == pages.count - 1 ? "Commencer" : "Continuer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func pageView(_ item: Page) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: item.symbol)
                .font(.system(size: 88, weight: .semibold))
                .foregroundStyle(item.tint)
            Text(item.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(item.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation { page += 1 }
        } else {
            onFinish()
        }
    }
}
