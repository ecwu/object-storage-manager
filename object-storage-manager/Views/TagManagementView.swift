//
//  TagManagementView.swift
//  object-storage-manager
//
//  Created by Zhenghao Wu on 2025/11/30.
//

import SwiftUI

/// A reusable view for managing tags
struct TagManagementView: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    @FocusState private var isInputFocused: Bool
    
    let placeholder: String
    let suggestedTags: [String]
    
    init(tags: Binding<[String]>, placeholder: String = "Add tag...", suggestedTags: [String] = []) {
        self._tags = tags
        self.placeholder = placeholder
        self.suggestedTags = suggestedTags
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
            
            // Display existing tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(tag: tag, onDelete: {
                            withAnimation {
                                tags.removeAll { $0 == tag }
                            }
                        })
                    }
                }
            }
            
            // Input for new tags
            HStack(spacing: 8) {
                TextField(placeholder, text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        addTag()
                    }
                
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("Add tag")
            }
            
            // Suggested tags
            if !suggestedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(suggestedTags.filter { !tags.contains($0) }, id: \.self) { tag in
                            Button(action: {
                                withAnimation {
                                    if !tags.contains(tag) {
                                        tags.append(tag)
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.caption)
                                    Image(systemName: "plus.circle")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmedTag.isEmpty, !tags.contains(trimmedTag) else { return }
        
        withAnimation {
            tags.append(trimmedTag)
        }
        newTag = ""
    }
}

/// A chip view for displaying a single tag with delete button
struct TagChip: View {
    let tag: String
    let onDelete: () -> Void
    let showDelete: Bool
    
    init(tag: String, onDelete: @escaping () -> Void = {}, showDelete: Bool = true) {
        self.tag = tag
        self.onDelete = onDelete
        self.showDelete = showDelete
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .foregroundColor(.white)
            
            if showDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Remove tag")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor)
        .cornerRadius(4)
    }
}

/// A flow layout for wrapping tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(
                width: maxWidth,
                height: currentY + lineHeight
            )
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var tags = ["Production", "Important", "Backend"]
        
        var body: some View {
            TagManagementView(
                tags: $tags,
                suggestedTags: ["Development", "Testing", "Archive", "Media"]
            )
            .padding()
            .frame(width: 400)
        }
    }
    
    return PreviewWrapper()
}
