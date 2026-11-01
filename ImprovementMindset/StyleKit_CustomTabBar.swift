import SwiftUI

// StyleKit — CustomTabBar.swift
// A MODULAR, themed, animated tab bar — the reference pattern for the app's
// "modular tab system + stylized animations." It's data-driven (pass in items),
// reusable, and shows the motion vocabulary: spring selection, an animated
// gold "circle" that slides under the active tab, and a pulse on the icon.
//
// This is a working example. To adopt it app-wide, see the notes at the bottom
// and DESIGN_WORKFLOW.md. Extend it (don't rebuild from scratch) for new styles.

/// One tab's definition — modular: the bar renders whatever list you give it.
struct TabBarItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let symbol: String
}

struct CustomTabBar: View {
    let items: [TabBarItem]
    @Binding var selection: Int
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tab(item)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(
            Theme.Palette.nightDeep
                .overlay(Rectangle().fill(Theme.Palette.goldDim.opacity(0.4)).frame(height: 1),
                         alignment: .top))
    }

    private func tab(_ item: TabBarItem) -> some View {
        let isSelected = selection == item.id
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selection = item.id
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Animated gold circle that slides to the active tab.
                    if isSelected {
                        SwiftUI.Circle()
                            .fill(Theme.malachiteGold)
                            .frame(width: 44, height: 44)
                            .matchedGeometryEffect(id: "activeCircle", in: ns)
                            .shadow(color: Theme.Palette.gold.opacity(0.5), radius: 6)
                    }
                    Image(systemName: item.symbol)
                        .font(.system(size: isSelected ? 20 : 18, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.Palette.night : Theme.Palette.boneDim)
                        .scaleEffect(isSelected ? 1.0 : 0.9)
                }
                .frame(height: 46)

                Text(item.title)
                    .font(Theme.display(11, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.Palette.goldBright : Theme.Palette.boneDim)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Example host showing the bar driving content

struct CustomTabBarDemo: View {
    @State private var selection = 0
    private let items = [
        TabBarItem(id: 0, title: "Home", symbol: "crown.fill"),
        TabBarItem(id: 1, title: "Daily", symbol: "sun.max.fill"),
        TabBarItem(id: 2, title: "Circles", symbol: "circle.circle.fill"),
        TabBarItem(id: 3, title: "Goals", symbol: "trophy.fill")
    ]

    var body: some View {
        ZStack {
            Theme.nightBackground.ignoresSafeArea()
            VStack {
                Spacer()
                Text(items[selection].title)
                    .font(Theme.display(34, weight: .bold))
                    .foregroundStyle(Theme.Palette.goldBright)
                    .transition(.opacity.combined(with: .scale))
                    .id(selection)
                Spacer()
                CustomTabBar(items: items, selection: $selection)
            }
        }
    }
}

//  ADOPTING THIS APP-WIDE (optional, when ready):
//  The app currently uses the native TabView in ImprovementMindsetApp.swift. To
//  switch to this bar, replace the TabView with a ZStack: your selected screen on
//  top, and `CustomTabBar(items:selection:)` pinned to the bottom, driving which
//  screen shows via a switch on `selection`. Keep Home/Daily/Calendar/Settings as
//  the four items (other sections stay on the Home dashboard). Do this only when
//  you want the custom look — the native bar works fine as-is.

#Preview("Custom Tab Bar") {
    CustomTabBarDemo()
}
