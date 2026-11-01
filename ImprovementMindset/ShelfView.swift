import SwiftUI
import SwiftData
import PhotosUI

struct ShelfView: View {
    let shelf: ShelfKind
    let navTitle: String
    var body: some View {
        NavigationStack { ShelfContent(shelf: shelf, navTitle: navTitle) }
    }
}

struct ShelfContent: View {
    let shelf: ShelfKind
    let navTitle: String

    @Environment(\.modelContext) private var context
    @Query private var allItems: [ShelfItem]
    @State private var showingAdd = false
    @State private var sealingItem: ShelfItem?

    private var items: [ShelfItem] {
        allItems
            .filter { $0.shelfRaw == shelf.rawValue }
            .sorted { $0.finishedDate > $1.finishedDate }
    }

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 20)]

    var body: some View {
            ScrollView {
                if items.isEmpty {
                    ContentUnavailableView(
                        shelf == .library ? "No books yet" : "Nothing made yet",
                        systemImage: "camera",
                        description: Text("Tap + to add one with a photo."))
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 28) {
                        ForEach(items) { item in
                            ShelfCard(item: item) { sealingItem = item }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        context.delete(item); try? context.save()
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(navTitle)
            .nightBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddShelfItemView(shelf: shelf)
            }
            .sheet(item: $sealingItem) { item in
                SealPickerView(item: item)
                    .presentationDetents([.height(280)])
            }
    }
}

struct SealPickerView: View {
    @Bindable var item: ShelfItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(item.shelf == .library ? "Mark this book" : "Mark this creation")
                .font(Theme.display(22, weight: .bold))
                .foregroundStyle(Theme.Palette.bone)
                .padding(.top)

            HStack(spacing: 28) {
                if item.shelf == .creations {
                    sealOption(.red, "Made it", "hammer.fill")
                } else {
                    sealOption(.black, "Read", "book.fill")
                    sealOption(.white, "Listened", "headphones")
                }
            }

            if item.seal != .none {
                Button("Remove seal") {
                    item.seal = .none; try? context.save(); dismiss()
                }
                .foregroundStyle(.red)
            }
            Spacer()
        }
        .padding()
        .nightBackground()
    }

    private func sealOption(_ seal: SealKind, _ label: String, _ symbol: String) -> some View {
        Button {
            item.seal = seal
            try? context.save()
            dismiss()
        } label: {
            VStack(spacing: 8) {
                WaxSeal(tone: WaxSeal.Tone(seal: seal) ?? .red, size: 60, symbol: symbol)
                    .overlay(alignment: .topTrailing) {
                        if item.seal == seal {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green).background(.white, in: SwiftUI.Circle())
                        }
                    }
                Text(label).font(.caption).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ShelfCard: View {
    let item: ShelfItem
    var onTapSeal: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let data = item.imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .aspectRatio(2.0/3.0, contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.3))
                            .aspectRatio(2.0/3.0, contentMode: .fit)
                    }
                }
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.black.opacity(0.15), lineWidth: 0.5))

                if let tone = WaxSeal.Tone(seal: item.seal) {
                    WaxSeal(tone: tone, size: 34,
                            symbol: item.shelf == .library ? "book.fill" : "hammer.fill")
                        .offset(x: 8, y: 8)
                }
            }
            .onTapGesture { onTapSeal() }

            ZStack {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: 0x3A2A1A), Color(hex: 0x241810)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 110, height: 8)
                Rectangle()
                    .fill(Theme.Palette.goldDim.opacity(0.7))
                    .frame(width: 110, height: 1)
                    .offset(y: -3.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))

            Text(item.title)
                .font(Theme.display(15, weight: .medium))
                .foregroundStyle(Theme.Palette.bone)
                .lineLimit(2).multilineTextAlignment(.center)
            Text(item.finishedDate, format: .dateTime.month().day().year())
                .font(.caption2).foregroundStyle(Theme.Palette.boneDim)
        }
        .frame(width: 110)
    }
}

struct AddShelfItemView: View {
    let shelf: ShelfKind

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var finishedDate = Date()
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let data = imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        showCamera = true
                    } label: { Label("Take Photo", systemImage: "camera") }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo")
                    }
                }

                Section(shelf == .library ? "Book title" : "What is it?") {
                    TextField(shelf == .library ? "Title" : "Name", text: $title)
                }

                Section(shelf == .library ? "Date finished" : "Date completed") {
                    DatePicker("Date", selection: $finishedDate,
                               displayedComponents: .date)
                }
            }
            .navigationTitle(shelf == .library ? "Add Book" : "Add Creation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }.disabled(title.isEmpty)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(imageData: $imageData)
                    .ignoresSafeArea()
            }
        }
    }

    private func save() {
        let item = ShelfItem(title: title, shelf: shelf,
                             imageData: imageData, finishedDate: finishedDate)
        context.insert(item)
        try? context.save()
        dismiss()
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
