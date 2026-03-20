import SwiftUI
import AppKit
import NpdfKit

struct SignaturePanelView: View {
    @ObservedObject var viewModel: SignaturePanelViewModel
    @ObservedObject var toolSettings: ToolSettings
    var onSignatureSelected: (NSImage) -> Void
    var onNewSignature: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Signatures")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if viewModel.signatures.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "signature")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No saved signatures")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(viewModel.signatures) { sig in
                            SignatureThumbnailView(
                                model: sig,
                                store: viewModel.store,
                                onTap: { image in
                                    npdfLog("[SIGNATURE] selected '\(sig.name)' from panel", .signature)
                                    toolSettings.currentTool = .signature
                                    onSignatureSelected(image)
                                },
                                onDelete: {
                                    npdfLog("[SIGNATURE] deleted '\(sig.name)' from panel", .signature)
                                    try? viewModel.store.delete(sig.id)
                                    viewModel.reload()
                                }
                            )
                        }
                    }
                    .padding(8)
                }
            }

            Divider()

            Button(action: onNewSignature) {
                Label("New Signature", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(8)
        }
    }
}

struct SignatureThumbnailView: View {
    let model: SignatureModel
    let store: SignatureStore
    let onTap: (NSImage) -> Void
    let onDelete: () -> Void

    @State private var image: NSImage?
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isHovered ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isHovered ? 2 : 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)

            Group {
                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    ProgressView().padding()
                }
            }

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.gray)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.opacity)
            }
        }
        .frame(height: 70)
        .contentShape(Rectangle())
        .onTapGesture { if let img = image { onTap(img) } }
        .onHover { isHovered = $0 }
        .onAppear { image = store.loadImage(for: model) }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
