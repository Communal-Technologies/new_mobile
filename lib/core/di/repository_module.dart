import 'package:communal_mobile/data/local/kyc_progress_storage.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/data/repositories/community_repository.dart';
import 'package:communal_mobile/data/repositories/community_settings_repository.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/data/repositories/notifications_repository.dart';
import 'package:communal_mobile/data/repositories/obligation_categories_repository.dart';
import 'package:communal_mobile/data/repositories/profile_repository.dart';
import 'package:communal_mobile/data/repositories/kyc_repository.dart';
import 'package:communal_mobile/data/repositories/locations_repository.dart';
import 'package:communal_mobile/data/repositories/regions_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
abstract class RepositoryModule {
  @lazySingleton
  AuthRepository provideAuthRepository(DioClient dioClient) =>
      AuthRepository(dioClient);

  @lazySingleton
  RegionsRepository provideRegionsRepository(DioClient dioClient) =>
      RegionsRepository(dioClient);

  @lazySingleton
  LocationsRepository provideLocationsRepository(DioClient dioClient) =>
      LocationsRepository(dioClient);

  @lazySingleton
  KycRepository provideKycRepository(DioClient dioClient) =>
      KycRepository(dioClient);

  @lazySingleton
  CommunitySettingsRepository provideCommunitySettingsRepository(
    DioClient dioClient,
  ) => CommunitySettingsRepository(dioClient);

  @lazySingleton
  CommunityRepository provideCommunityRepository(DioClient dioClient) =>
      CommunityRepository(dioClient);

  @lazySingleton
  NotificationsRepository provideNotificationsRepository(DioClient dioClient) =>
      NotificationsRepository(dioClient);

  @lazySingleton
  ProfileRepository provideProfileRepository(DioClient dioClient) =>
      ProfileRepository(dioClient);

  @lazySingleton
  AccountActionsRepository provideAccountActionsRepository(DioClient dioClient) =>
      AccountActionsRepository(dioClient);

  @lazySingleton
  ObligationCategoriesRepository provideObligationCategoriesRepository(
    DioClient dioClient,
  ) => ObligationCategoriesRepository(dioClient);

  @lazySingleton
  TransferRepository provideTransferRepository(DioClient dioClient) =>
      TransferRepository(dioClient);

  @lazySingleton
  KycProgressStorage provideKycProgressStorage(SharedPreferences prefs) =>
      KycProgressStorage(prefs);
}
