import 'package:fintrack/features/admin/permission_defs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permission catalogue has unique numeric ids and modules', () {
    final ids = kPermissionDefs.map((p) => p.id).toSet();
    expect(ids.length, kPermissionDefs.length);
    expect(kPermissionModules, kPermissionModules.toSet().toList());
  });

  test('folders match modules 1:1, "all" owns every definition', () {
    final all = kPermissionFolders.firstWhere((f) => f.id == kAllFoldersId);
    expect(all.modules, isEmpty);
    final coveredModules = <String>{
      for (final f in kPermissionFolders) ...f.modules,
    };
    expect(coveredModules, kPermissionModules.toSet());

    // Every definition belongs to at least one non-"all" folder.
    // (Dashboard/Downloads/Subscriber Reports edge ids included by modules.)
    for (final p in kPermissionDefs) {
      expect(
        kPermissionFolders.any((f) => f.id != kAllFoldersId && f.modules.contains(p.module)),
        isTrue,
        reason: '${p.id} (${p.module}) is not covered by any folder',
      );
    }
  });

  test('child ids are derived {parent}:{key} and never collide', () {
    final children = kPermissionChildDefs;
    final ids = children.map((c) => c.id).toSet();
    expect(ids.length, children.length);
    for (final c in children) {
      expect(c.id, contains(':'));
      expect(c.parentId, isNotEmpty);
      expect(c.key, isNotEmpty);
      final parentFound = kPermissionDefs.any((p) => p.id == c.parentId);
      expect(parentFound, isTrue, reason: 'orphan child ${c.id}');
    }
    // No overlap with the top-level numeric ids.
    final parentIds = kPermissionDefs.map((p) => p.id).toSet();
    expect(ids.intersection(parentIds), isEmpty);
  });

  test('children grouped by parent; every parent with children is listed', () {
    final byParent = childrenByParent();
    for (final p in kPermissionDefs) {
      final children = byParent[p.id];
      if (children != null) {
        expect(children, isNotEmpty);
        for (final c in children) {
          expect(c.parentId, p.id);
        }
      }
    }
  });

  test('allPermissionIds = parents + children', () {
    final all = allPermissionIds.toSet();
    expect(all.length, kPermissionDefs.length + kPermissionChildDefs.length);
    expect(all.containsAll(kPermissionDefs.map((p) => p.id)), isTrue);
  });
}