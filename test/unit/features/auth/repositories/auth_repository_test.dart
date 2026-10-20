import 'package:campus_innovate/core/roble/roble_exception.dart';
import 'package:campus_innovate/features/auth/data/datasources/remote/i_authentication_source.dart';
import 'package:campus_innovate/features/auth/data/repositories/auth_repository.dart';
import 'package:campus_innovate/features/auth/domain/models/authentication_user.dart';
import 'package:flutter_test/flutter_test.dart';

/// The repository is a straight pass-through; what matters is that every call
/// reaches the matching source method with its arguments, the answer comes
/// back unchanged, and a ROBLE error is not swallowed on the way.
void main() {
  late _RecordingSource source;
  late AuthRepository repository;

  const user = AuthenticationUser(
    email: 'leonel@uninorte.edu.co',
    name: 'Leonel',
    password: 'Campus2026!',
  );

  setUp(() {
    source = _RecordingSource();
    repository = AuthRepository(source);
  });

  test('login entrega el usuario a la fuente y devuelve su respuesta',
      () async {
    source.answer = true;
    expect(await repository.login(user), isTrue);

    source.answer = false;
    expect(await repository.login(user), isFalse);

    expect(source.calls, ['login', 'login']);
    expect(source.lastUser, same(user));
  });

  test('signUp entrega el usuario a la fuente', () async {
    expect(await repository.signUp(user), isTrue);

    expect(source.calls, ['signUp']);
    expect(source.lastUser?.password, 'Campus2026!');
  });

  test('restoreSession, logOut y completeGoogleSignIn pasan la respuesta',
      () async {
    source.answer = false;

    expect(await repository.restoreSession(), isFalse);
    expect(await repository.logOut(), isFalse);
    expect(await repository.completeGoogleSignIn(), isFalse);
    expect(
      source.calls,
      ['restoreSession', 'logOut', 'completeGoogleSignIn'],
    );
  });

  test('validateToken usa verifyToken de la fuente', () async {
    expect(await repository.validateToken(), isTrue);
    expect(source.calls, ['verifyToken']);
  });

  test('validate pasa el correo y el código', () async {
    await repository.validate('a@b.co', '123456');

    expect(source.calls, ['validate']);
    expect(source.lastArgs, ['a@b.co', '123456']);
  });

  test('forgotPassword pasa el correo', () async {
    await repository.forgotPassword('a@b.co');

    expect(source.calls, ['forgotPassword']);
    expect(source.lastArgs, ['a@b.co']);
  });

  test('startGoogleSignIn delega en la fuente', () async {
    await repository.startGoogleSignIn();

    expect(source.calls, ['startGoogleSignIn']);
  });

  test('getLoggedUser devuelve el usuario de la fuente, o null', () async {
    expect(await repository.getLoggedUser(), isNull);

    source.logged = const AuthenticationUser(email: 'a@b.co', name: 'Ana');
    expect((await repository.getLoggedUser())?.name, 'Ana');
  });

  test('un error de ROBLE llega intacto a quien llama', () async {
    source.failure = const RobleRateLimitException('Espera', retryAfter: 60);

    await expectLater(
      repository.login(user),
      throwsA(
        isA<RobleRateLimitException>()
            .having((e) => e.retryAfter, 'retryAfter', 60),
      ),
    );
  });
}

class _RecordingSource implements IAuthenticationSource {
  final List<String> calls = [];
  List<Object?> lastArgs = const [];
  AuthenticationUser? lastUser;
  AuthenticationUser? logged;
  bool answer = true;
  Object? failure;

  Future<bool> _record(String name, [List<Object?> args = const []]) async {
    calls.add(name);
    lastArgs = args;
    if (failure != null) throw failure!;
    return answer;
  }

  @override
  Future<bool> login(AuthenticationUser user) {
    lastUser = user;
    return _record('login');
  }

  @override
  Future<bool> signUp(AuthenticationUser user) {
    lastUser = user;
    return _record('signUp');
  }

  @override
  Future<bool> restoreSession() => _record('restoreSession');

  @override
  Future<AuthenticationUser?> getLoggedUser() async => logged;

  @override
  Future<void> startGoogleSignIn() => _record('startGoogleSignIn');

  @override
  Future<bool> completeGoogleSignIn() => _record('completeGoogleSignIn');

  @override
  Future<bool> logOut() => _record('logOut');

  @override
  Future<bool> validate(String email, String validationCode) =>
      _record('validate', [email, validationCode]);

  @override
  Future<bool> refreshToken() => _record('refreshToken');

  @override
  Future<bool> forgotPassword(String email) =>
      _record('forgotPassword', [email]);

  @override
  Future<bool> resetPassword(
    String email,
    String newPassword,
    String validationCode,
  ) =>
      _record('resetPassword', [email, newPassword, validationCode]);

  @override
  Future<bool> verifyToken() => _record('verifyToken');
}
