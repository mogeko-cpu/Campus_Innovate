class MockSession {
  static String currentUserId = 'user_1';
  static String currentUserName = 'Leonel Triana';

  static void changeUser({
    required String id,
    required String name,
  }) {
    currentUserId = id;
    currentUserName = name;
  }
}