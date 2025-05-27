import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SoundButton: Identifiable, Codable {
    let id = UUID()
    var title: String
    var soundURL: URL?
}

class SoundButtonViewModel: ObservableObject {
    @Published var buttons: [SoundButton] = []
    var audioPlayer: AVAudioPlayer?

    func playSound(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \\(error.localizedDescription)")
        }
    }

    func addButton(title: String, soundURL: URL?) {
        let newButton = SoundButton(title: title, soundURL: soundURL)
        buttons.append(newButton)
    }
}

struct SoundBoard: Identifiable, Codable {
    let id = UUID()
    var name: String
    var buttons: [SoundButton]
}

class SoundBoardViewModel: ObservableObject {
    @Published var boards: [SoundBoard] = [] {
        didSet {
            saveBoards()
        }
    }
    @Published var selectedBoardIndex: Int = 0 {
        didSet {
            saveSelectedBoardIndex()
        }
    }
    var audioPlayer: AVAudioPlayer?

    private let boardsKey = "soundBoards"
    private let selectedBoardIndexKey = "selectedBoardIndex"

    init() {
        loadBoards()
        loadSelectedBoardIndex()
    }

    func playSound(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \\(error.localizedDescription)")
        }
    }

    func addButton(to boardIndex: Int, title: String, soundURL: URL?) {
        guard boards.indices.contains(boardIndex) else { return }
        let newButton = SoundButton(title: title, soundURL: soundURL)
        boards[boardIndex].buttons.append(newButton)
        saveBoards()
    }

    func addBoard(name: String) {
        let newBoard = SoundBoard(name: name, buttons: [])
        boards.append(newBoard)
        saveBoards()
    }

    func deleteBoard(at index: Int) {
        guard boards.indices.contains(index) else { return }
        boards.remove(at: index)
        if selectedBoardIndex >= boards.count {
            selectedBoardIndex = max(boards.count - 1, 0)
        }
        saveBoards()
    }

    private func saveBoards() {
        do {
            let data = try JSONEncoder().encode(boards)
            UserDefaults.standard.set(data, forKey: boardsKey)
        } catch {
            print("Failed to save boards: \\(error.localizedDescription)")
        }
    }

    private func loadBoards() {
        guard let data = UserDefaults.standard.data(forKey: boardsKey) else { return }
        do {
            boards = try JSONDecoder().decode([SoundBoard].self, from: data)
        } catch {
            print("Failed to load boards: \\(error.localizedDescription)")
        }
    }

    private func saveSelectedBoardIndex() {
        UserDefaults.standard.set(selectedBoardIndex, forKey: selectedBoardIndexKey)
    }

    private func loadSelectedBoardIndex() {
        selectedBoardIndex = UserDefaults.standard.integer(forKey: selectedBoardIndexKey)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = SoundBoardViewModel()
    @State private var showingDocumentPicker = false
    @State private var newButtonTitle = ""
    @State private var selectedSoundURL: URL?
    @State private var selectedButtonColor: Color = .black
    @State private var newBoardName = ""
    @State private var showEditOptions = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Picker("Select Board", selection: $viewModel.selectedBoardIndex) {
                        ForEach(viewModel.boards.indices, id: \.self) { index in
                            Text(viewModel.boards[index].name).tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()

                    Button(action: {
                        viewModel.deleteBoard(at: viewModel.selectedBoardIndex)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding(.trailing)
                    }
                    .disabled(viewModel.boards.isEmpty)
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                        if viewModel.boards.indices.contains(viewModel.selectedBoardIndex) {
                            ForEach(viewModel.boards[viewModel.selectedBoardIndex].buttons) { button in
                                Button(action: {
                                    if let url = button.soundURL {
                                        viewModel.playSound(url: url)
                                    }
                                }) {
                                    Text(button.title)
                                        .foregroundColor(.white)
                                        .frame(width: 100, height: 50)
                                        .background(selectedButtonColor)
                                        .cornerRadius(8)
                                }
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 1.0)
                                        .onEnded { _ in
                                            if let index = viewModel.boards[viewModel.selectedBoardIndex].buttons.firstIndex(where: { $0.id == button.id }) {
                                                viewModel.boards[viewModel.selectedBoardIndex].buttons.remove(at: index)
                                            }
                                        }
                                )
                            }
                        }
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                }

                Divider()

                if showEditOptions {
                    VStack(spacing: 10) {
                        TextField("Button Title", text: $newButtonTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        TextField("New Board Name", text: $newBoardName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        ColorPicker("Select Button Color", selection: $selectedButtonColor)
                            .padding(.horizontal)

                        Button("Select Sound from iCloud") {
                            showingDocumentPicker = true
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)

                        HStack {
                            Button("Add Button") {
                                viewModel.addButton(to: viewModel.selectedBoardIndex, title: newButtonTitle.isEmpty ? "Sound Button" : newButtonTitle, soundURL: selectedSoundURL)
                                newButtonTitle = ""
                                selectedSoundURL = nil
                            }
                            .disabled(selectedSoundURL == nil)
                            .padding()
                            .background(selectedSoundURL == nil ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)

                            Button("Add Board") {
                                if !newBoardName.isEmpty {
                                    viewModel.addBoard(name: newBoardName)
                                    newBoardName = ""
                                }
                            }
                            .padding()
                            .background(newBoardName.isEmpty ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }

                        Button("Stop Sound") {
                            viewModel.audioPlayer?.stop()
                        }
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                }

                Button(showEditOptions ? "Hide Edit Options" : "Show Edit Options") {
                    showEditOptions.toggle()
                }
                .padding()
            }
            .navigationTitle("Sound Button App")
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(selectedURL: $selectedSoundURL)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.selectedURL = url
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.selectedURL = nil
        }
    }
}

@main
struct iOSSoundButtonApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
