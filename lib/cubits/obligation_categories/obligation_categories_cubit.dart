import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/data/models/obligation_category.dart';
import 'package:communal_mobile/data/repositories/obligation_categories_repository.dart';

part 'obligation_categories_state.dart';

class ObligationCategoriesCubit extends Cubit<ObligationCategoriesState> {
  final ObligationCategoriesRepository _repository;

  ObligationCategoriesCubit(this._repository) : super(ObligationCategoriesInitial());

  List<ObligationCategory> get categories {
    final s = state;
    if (s is ObligationCategoriesLoaded) return s.categories;
    return ObligationCategory.defaults;
  }

  Future<void> load(String cooperativeId) async {
    try {
      final cats = await _repository.fetchForCooperative(cooperativeId);
      // Always include Fine (1526) which is not in the API response.
      final hasFine = cats.any((c) => c.code == '1526');
      final all = hasFine ? cats : [...cats, ObligationCategory.defaults.last];
      all.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      emit(ObligationCategoriesLoaded(all));
    } catch (_) {
      // Non-fatal: keep defaults so the UI still works offline.
      emit(ObligationCategoriesLoaded(ObligationCategory.defaults));
    }
  }
}
