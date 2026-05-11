import 'package:crm_app/screens/pmam/data/repositories/pmam_repository.dart';
import 'package:crm_app/screens/pmam/data/usecases/get_manager_status.dart';
import 'package:crm_app/core/network/api_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PmamRepository {}

void main() {
  group('GetManagerStatus', () {
    test('calls repository.getManagerStatus', () async {
      final repo = _MockRepo();
      final usecase = GetManagerStatus(repo);

      final expected = ApiResponse(success: true, data: {'data': {}});
      when(() => repo.getManagerStatus()).thenAnswer((_) async => expected);

      final result = await usecase();

      expect(result, same(expected));
      verify(() => repo.getManagerStatus()).called(1);
      verifyNoMoreInteractions(repo);
    });
  });
}

