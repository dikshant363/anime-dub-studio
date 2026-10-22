import Foundation
import SwiftUI
import AnimeDubCore

public struct StudioContentView: View {
    @StateObject private var viewModel = StudioViewModel()

    public init() {}

    public var body: some View {
        Group {
            switch viewModel.currentScreen {
            case .home, .createDub:
                ProjectHomeView(viewModel: viewModel)
            case .processing:
                LiveProcessingView(viewModel: viewModel)
            case .editor(let projId, let epId):
                DubbingEditorView(viewModel: viewModel, projectId: projId, episodeId: epId)
            case .exportReport(let projId, let epId):
                ExportQualitySheet(viewModel: viewModel, projectId: projId, episodeId: epId)
            }
        }
        .frame(minWidth: 1024, minHeight: 700)
    }
}
