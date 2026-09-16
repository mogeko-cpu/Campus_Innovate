import 'i_session_service.dart';

/// Fixed session used while authentication is not wired to the app shell.
class MockSessionService implements ISessionService {
  @override
  final String currentUserId;

  @override
  final String currentUserName;

  const MockSessionService({
    this.currentUserId = 'user_1',
    this.currentUserName = 'Leonel Triana',
  });
}
