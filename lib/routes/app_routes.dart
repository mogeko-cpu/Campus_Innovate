abstract class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';

  static const home = '/home';

  static const listings = '/listings';
  static const createListing = '/listings/create';
  static const listingDetail = '/listings/detail/:id';
  static const joinRequest = '/listings/join/:id';
  static const editListing = '/listings/edit/:id';

  /// A project's task board.
  static const listingTasks = '/listings/tasks/:id';

  /// What a project's team shares: uploads and links.
  static const listingFiles = '/listings/files/:id';

  /// Projects ordered by how the campus valued them.
  static const ranking = '/ranking';

  static const groups = '/groups';
  static const createGroup = '/groups/create';
  static const groupDetail = '/groups/detail/:id';
  static const inviteMembers = '/groups/invite/:id';
  static const groupChat = '/groups/chat/:id';

  static const profile = '/profile';

  static const notifications = '/notifications';

  /// Ids in the path are the `_id` UUIDs of the rows.
  static String detailOf(String id) => '/listings/detail/$id';

  static String joinOf(String id) => '/listings/join/$id';

  static String editOf(String id) => '/listings/edit/$id';

  static String tasksOf(String id) => '/listings/tasks/$id';

  static String filesOf(String id) => '/listings/files/$id';

  static String groupOf(String id) => '/groups/detail/$id';

  static String inviteOf(String id) => '/groups/invite/$id';

  static String chatOf(String id) => '/groups/chat/$id';
}
