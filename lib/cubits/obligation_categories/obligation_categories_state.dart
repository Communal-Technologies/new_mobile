part of 'obligation_categories_cubit.dart';

abstract class ObligationCategoriesState {}

class ObligationCategoriesInitial extends ObligationCategoriesState {}

class ObligationCategoriesLoaded extends ObligationCategoriesState {
  final List<ObligationCategory> categories;
  ObligationCategoriesLoaded(this.categories);
}
