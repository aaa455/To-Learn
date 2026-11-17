import SwiftUI

struct FolderDetailView: View {
    let folder: TodoFolder
    @ObservedObject var todoManager: TodoManager
    @State private var showingAddTask = false
    @State private var showingAddSubfolder = false

    var tasksInFolder: [TodoTask] {
        todoManager.tasks.filter { $0.folderId == folder.id }
    }

    var subfoldersInFolder: [TodoFolder] {
        todoManager.folders.filter { $0.parentId == folder.id }
    }

    var body: some View {
        List {
            // 子文件夹
            if !subfoldersInFolder.isEmpty {
                Section(header: Text("子文件夹")) {
                    ForEach(subfoldersInFolder) { subfolder in
                        NavigationLink(destination: FolderDetailView(folder: subfolder, todoManager: todoManager)) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                Text(subfolder.name)
                            }
                        }
                    }
                }
            }

            // 任务列表
            Section(header: Text("任务")) {
                if tasksInFolder.isEmpty {
                    Text("暂无任务")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(tasksInFolder) { task in
                        NavigationLink(destination: TaskDetailView(task: task, todoManager: todoManager)) {
                            TaskRowView(task: task, todoManager: todoManager)
                        }
                    }
                }
            }

            // 操作
            Section {
                Button(action: { showingAddTask = true }) {
                    Label("添加任务", systemImage: "plus.circle")
                }

                Button(action: { showingAddSubfolder = true }) {
                    Label("添加子文件夹", systemImage: "folder.badge.plus")
                }
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(todoManager: todoManager, isPresented: $showingAddTask)
        }
        .sheet(isPresented: $showingAddSubfolder) {
            AddSubfolderSheet(parentId: folder.id, todoManager: todoManager, isPresented: $showingAddSubfolder)
        }
    }
}

struct AddSubfolderSheet: View {
    let parentId: UUID
    @ObservedObject var todoManager: TodoManager
    @Binding var isPresented: Bool
    @State private var name = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("文件夹名称")) {
                    TextField("例如：紧急", text: $name)
                }
            }
            .navigationTitle("添加子文件夹")
            .navigationBarItems(
                leading: Button("取消") { isPresented = false },
                trailing: Button("保存") {
                    todoManager.addFolder(name: name, parentId: parentId)
                    isPresented = false
                }
                .disabled(name.isEmpty)
            )
        }
    }
}
