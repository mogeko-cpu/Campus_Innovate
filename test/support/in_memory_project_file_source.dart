import 'package:campus_innovate/features/listings/data/datasources/i_project_file_source.dart';
import 'package:campus_innovate/features/listings/domain/models/project_file.dart';

/// [IProjectFileSource] in memory, empty: every project starts with nothing
/// shared.
class InMemoryProjectFileSource implements IProjectFileSource {
  final List<ProjectFile> _files = [];

  var _nextId = 1;

  /// Everything stored, for the assertions about what a flow left behind.
  List<ProjectFile> get all => List.unmodifiable(_files);

  @override
  Future<List<ProjectFile>> getFiles(String listingId) async => _files
      .where((file) => file.listingId == listingId)
      .toList()
      .reversed
      .toList();

  @override
  Future<ProjectFile?> getFileById(String id) async {
    final index = _files.indexWhere((file) => file.id == id);

    return index == -1 ? null : _files[index];
  }

  @override
  Future<ProjectFile> createFile(ProjectFile file) async {
    final stored = file.copyWith(id: 'file_${_nextId++}');
    _files.add(stored);

    return stored;
  }

  @override
  Future<void> deleteFile(String fileId) async =>
      _files.removeWhere((file) => file.id == fileId);

  @override
  Future<void> deleteFilesOf(String listingId) async =>
      _files.removeWhere((file) => file.listingId == listingId);
}
