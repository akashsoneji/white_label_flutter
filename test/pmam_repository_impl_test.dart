import 'package:crm_app/screens/pmam/data/datasources/pmam_remote_data_source.dart';
import 'package:crm_app/screens/pmam/data/repositories/pmam_repository_impl.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements PmamRemoteDataSource {}

void main() {
  group('PmamRepositoryImpl', () {
    late _MockRemote remote;
    late PmamRepositoryImpl repo;

    setUp(() {
      remote = _MockRemote();
      repo = PmamRepositoryImpl(remote);
    });

    test('getManagerStatus delegates to remote', () async {
      final expected = ApiResponse(success: true, data: {'data': {}});
      when(() => remote.getManagerStatus()).thenAnswer((_) async => expected);

      final result = await repo.getManagerStatus();

      expect(result, same(expected));
      verify(() => remote.getManagerStatus()).called(1);
      verifyNoMoreInteractions(remote);
    });

    test('applyAsManager delegates to remote', () async {
      final expected = ApiResponse(success: true, data: {'data': {}});
      when(() => remote.applyAsManager()).thenAnswer((_) async => expected);

      final result = await repo.applyAsManager();

      expect(result, same(expected));
      verify(() => remote.applyAsManager()).called(1);
      verifyNoMoreInteractions(remote);
    });
  });
}

