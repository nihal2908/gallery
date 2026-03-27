import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class PdfManagerPage extends StatefulWidget {
  const PdfManagerPage({super.key});

  @override
  State<PdfManagerPage> createState() => _PdfManagerPageState();
}

class _PdfManagerPageState extends State<PdfManagerPage> {
  List<File> allFiles = [];
  List<File> filteredFiles = [];

  Set<String> selected = {};
  bool isSelectionMode = false;

  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    loadPdfs();
  }

  // ✅ Load + Sort (latest first)
  Future<void> loadPdfs() async {
    final dir = await getDownloadsDirectory();
    if (dir == null) return;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.pdf'))
        .toList();

    // 🔥 Sort by latest modified (closest to creation)
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {
      allFiles = files;
      applyFilter();
    });
  }

  // ✅ Search filter
  void applyFilter() {
    filteredFiles = allFiles.where((file) {
      final name = file.path.split('/').last.toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();
  }

  void onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
      applyFilter();
    });
  }

  // ✅ Selection
  void toggleSelection(String path) {
    setState(() {
      if (selected.contains(path)) {
        selected.remove(path);
      } else {
        selected.add(path);
      }
      isSelectionMode = selected.isNotEmpty;
    });
  }

  void clearSelection() {
    setState(() {
      selected.clear();
      isSelectionMode = false;
    });
  }

  // ✅ Delete
  Future<void> deleteSelected() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete selected PDFs ?'),
          content: Text('This action can not be undone.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                for (final path in selected) {
                  final file = File(path);
                  if (await file.exists()) {
                    await file.delete();
                  }
                }
                clearSelection();
                await loadPdfs();
                Navigator.pop(context);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ✅ Share
  Future<void> shareSelected() async {
    final files = selected.map((e) => XFile(e)).toList();
    if (files.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(files: files));
    }
  }

  // ✅ Open
  Future<void> openFile(File file) async {
    await OpenFilex.open(file.path);
  }

  // ✅ Rename dialog
  Future<void> renameFile(File file) async {
    final controller = TextEditingController(
      text: file.path.split('/').last.replaceAll('.pdf', ''),
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename PDF"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter new name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text("Rename"),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty) return;

    final dir = file.parent.path;
    final newPath = "$dir/$newName.pdf";

    try {
      await file.rename(newPath);
      await loadPdfs();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Rename failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, _) => clearSelection(),
      child: Scaffold(
        appBar: AppBar(
          title: isSelectionMode
              ? Text("${selected.length} selected")
              : const Text("Generated PDFs"),
          leading: isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: clearSelection,
                )
              : null,
          actions: isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: shareSelected,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: deleteSelected,
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: loadPdfs,
                  ),
                ],
        ),

        body: Column(
          children: [
            // 🔍 Search bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: "Search PDFs...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            Expanded(
              child: filteredFiles.isEmpty
                  ? const Center(child: Text("No PDFs found"))
                  : ListView.builder(
                      itemCount: filteredFiles.length,
                      itemBuilder: (context, index) {
                        final file = filteredFiles[index];
                        final isSelected = selected.contains(file.path);

                        return ListTile(
                          leading: Icon(
                            Icons.picture_as_pdf,
                            color: isSelected ? Colors.blue : Colors.red,
                          ),
                          title: Text(
                            file.path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            "${(file.lengthSync() / 1024).toStringAsFixed(1)} KB",
                          ),
                          trailing: isSelectionMode
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => toggleSelection(file.path),
                                )
                              : PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'open') {
                                      openFile(file);
                                    } else if (value == 'rename') {
                                      renameFile(file);
                                    } else if (value == 'delete') {
                                      selected = {file.path};
                                      await deleteSelected();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'open',
                                      child: Text("Open"),
                                    ),
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Text("Rename"),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text("Delete"),
                                    ),
                                  ],
                                ),
                          onTap: () {
                            if (isSelectionMode) {
                              toggleSelection(file.path);
                            } else {
                              openFile(file);
                            }
                          },
                          onLongPress: () {
                            toggleSelection(file.path);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
