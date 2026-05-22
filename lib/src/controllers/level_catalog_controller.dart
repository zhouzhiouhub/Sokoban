import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../levels/custom_level_import_source.dart';
import '../levels/custom_level_store.dart';
import '../levels/level_catalog.dart';

final builtInLevelCatalogProvider = FutureProvider<List<LevelCatalogItem>>((
  ref,
) {
  return loadBuiltInLevelCatalog();
});

final customLevelStoreProvider = Provider<CustomLevelStore>((ref) {
  return CustomLevelStore();
});

final levelCatalogControllerProvider =
    AsyncNotifierProvider<LevelCatalogController, LevelCatalogState>(
      LevelCatalogController.new,
    );

class LevelCatalogState {
  const LevelCatalogState({
    this.customLevelCatalog = const [],
    this.isImporting = false,
  });

  final List<LevelCatalogItem> customLevelCatalog;
  final bool isImporting;

  LevelCatalogState copyWith({
    List<LevelCatalogItem>? customLevelCatalog,
    bool? isImporting,
  }) {
    return LevelCatalogState(
      customLevelCatalog: customLevelCatalog ?? this.customLevelCatalog,
      isImporting: isImporting ?? this.isImporting,
    );
  }
}

class LevelCatalogController extends AsyncNotifier<LevelCatalogState> {
  final CustomLevelImportSourceReader _importSourceReader =
      const CustomLevelImportSourceReader();

  @override
  Future<LevelCatalogState> build() async {
    final customLevelStore = ref.watch(customLevelStoreProvider);
    final customLevelCatalog = await customLevelStore.loadCatalogItems();

    return LevelCatalogState(
      customLevelCatalog: List<LevelCatalogItem>.unmodifiable(
        customLevelCatalog,
      ),
    );
  }

  Future<LevelCatalogItem> importLevel(String input) async {
    final previousState = state.hasValue
        ? state.requireValue
        : const LevelCatalogState();
    state = AsyncData(previousState.copyWith(isImporting: true));

    try {
      final source = await _importSourceReader.read(input);
      final catalogItem = await ref
          .read(customLevelStoreProvider)
          .importLevelJson(source);
      final nextCustomCatalog = List<LevelCatalogItem>.unmodifiable([
        ...previousState.customLevelCatalog,
        catalogItem,
      ]);

      state = AsyncData(
        previousState.copyWith(
          customLevelCatalog: nextCustomCatalog,
          isImporting: false,
        ),
      );

      return catalogItem;
    } catch (error, stackTrace) {
      state = AsyncData(previousState.copyWith(isImporting: false));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
