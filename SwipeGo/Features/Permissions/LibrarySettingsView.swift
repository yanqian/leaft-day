import SwiftUI

/// The same live snapshot drives Home and Settings; this surface never requests
/// extra access or downloads original photos merely to decorate the page.
struct LibrarySettingsView: View {
    let snapshot: LibrarySnapshot
    let request: () -> Void
    let manage: () -> Void
    let openSettings: () -> Void
    let done: () -> Void
    @State private var expanded = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var backgroundAsset: PhotoAssetSnapshot? { snapshot.permission.canRead ? snapshot.assets.first { $0.kind == .photo } : nil }
    private var permissionTitle: String {
        switch snapshot.permission {
        case .full: "已允许访问"
        case .limited: "所选照片"
        case .notDetermined: "尚未授权"
        case .denied: "未允许访问"
        case .restricted: "访问受限"
        case .unknown: "状态待确认"
        }
    }
    var body: some View {
        ZStack {
            PhotoColorBackdrop(asset: backgroundAsset)
            VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("设置").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button(action: done) {
                            Image(systemName: "xmark").frame(width: 44, height: 44).contentShape(Circle())
                        }.buttonStyle(.plain).accessibilityLabel("关闭设置").photoGlass(radius: 24)
                    }.padding(.bottom, 8)
                    VStack(alignment: .leading, spacing: 14) {
                        Group {
                            if typeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 10) { permissionHeading; status }
                            } else { HStack { permissionHeading; Spacer(); status } }
                        }
                        if snapshot.permission.canRead {
                            Text(snapshot.assets.isEmpty ? snapshot.emptyMessage : "可回顾 \(snapshot.assets.count) 项")
                                .font(.title2.bold()).accessibilityIdentifier("library.count")
                            Text("照片与视频").font(.subheadline)
                        }
                        Text(snapshot.permission.guidance).font(.footnote).accessibilityIdentifier("permission.guidance")
                        if snapshot.permission == .limited {
                            Button("管理所选照片", action: manage).buttonStyle(PhotoGlassButtonStyle()).frame(minHeight: 44)
                        } else if snapshot.permission == .denied {
                            Button("打开设置", action: openSettings).buttonStyle(PhotoGlassButtonStyle()).frame(minHeight: 44)
                        } else if snapshot.permission == .notDetermined {
                            Button("允许访问照片", action: request).buttonStyle(PhotoGlassButtonStyle()).frame(minHeight: 44).accessibilityIdentifier("permission.request")
                        }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).photoGlass()
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            expanded.toggle()
                        } label: {
                            HStack {
                                Label("图库说明", systemImage: "info.circle")
                                Spacer()
                                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("settings.explanation")
                            .accessibilityValue(expanded ? "已展开" : "已收起")
                        if expanded {
                            Text("仅在你授权的范围内回顾。上滑只是加入待删，原片在集中复核并确认后才会删除。共享照片图库暂不支持。")
                                .font(.callout).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("settings.details")
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 10).photoGlass()
                    Text("仅支持个人图库").font(.footnote).padding(.horizontal, 8)
                }.padding(24).frame(maxWidth: 600)
            }.clipped().accessibilityIdentifier("settings.scroll")
            Group {
                Button(action: done) { Text("完成").font(.headline).frame(minWidth: 160, minHeight: 52).contentShape(Capsule()) }
                    .buttonStyle(.plain).photoGlass(radius: 30).padding(.horizontal, 24).padding(.vertical, 14)
            }
            }
        }.photoPage()

    }
    private var permissionHeading: some View {
        Text("照片访问").font(.headline).fixedSize(horizontal: false, vertical: true).padding(.vertical, 3).layoutPriority(1)
    }
    private var status: some View {
        Label(permissionTitle, systemImage: snapshot.permission.canRead ? "checkmark.circle.fill" : "lock.circle")
            .font(.caption).fixedSize(horizontal: false, vertical: true)
    }
}
