import 'dart:async';
import 'dart:convert';

import 'package:cpms_mobile/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PageClient extends ApiClient {
  _PageClient(String user, String tenant) {
    final jwtPayload = base64Url.encode(utf8.encode(jsonEncode({'sub': user})));
    setAuthToken('header.$jwtPayload.signature');
    setActiveTenantId(tenant);
  }

  var server = Completer<dynamic>();

  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) =>
      server.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const endpoint = '/purchase-orders';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a reopened page gets saved content while its network read is pending',
    () async {
      final initial = _PageClient('packer', 'one');
      await initial.storePage(endpoint, ['saved order']);

      final reopened = _PageClient('packer', 'one');
      final cached = Completer<void>();
      final visible = <Object?>[];
      final read = reopened.loadPage(
        endpoint,
        onData: (data) {
          visible.add(data);
          if (!cached.isCompleted) cached.complete();
        },
      );
      await cached.future;
      expect(visible, [
        ['saved order'],
      ]);
      reopened.server.complete(['current order']);
      await read;
      expect(visible, [
        ['saved order'],
        ['current order'],
      ]);

      final offline = _PageClient('packer', 'one');
      final result = <Object?>[];
      final offlineRead = offline.loadPage(endpoint, onData: result.add);
      offline.server.future.ignore();
      offline.server.completeError(ApiException('Offline'));
      await offlineRead;
      expect(result, [
        ['current order'],
      ]);
    },
  );

  test(
    'cached order data only appears for the matching account and tenant',
    () async {
      await _PageClient('packer', 'one').storePage(endpoint, ['private']);
      for (final client in [
        _PageClient('another-user', 'one'),
        _PageClient('packer', 'another-tenant'),
      ]) {
        final visible = <Object?>[];
        final read = client.loadPage(endpoint, onData: visible.add);
        client.server.complete([]);
        await read;
        expect(visible, [[]]);
      }
    },
  );

  test(
    'scheduled sync replaces cached records after connectivity returns',
    () async {
      final client = _PageClient('packer', 'one');
      await client.storePage(endpoint, ['offline order']);
      final shown = Completer<void>();
      final visible = <Object?>[];
      final load = client.loadPage(
        endpoint,
        refreshGroup: 'orders',
        onData: (data) {
          visible.add(data);
          if (!shown.isCompleted) shown.complete();
        },
      );
      await shown.future;
      client.server.completeError(ApiException('Offline'));
      await load;
      expect(visible, [
        ['offline order'],
      ]);

      client.server = Completer<dynamic>()..complete(['online order']);
      await client.refreshLoadedPages();
      expect(visible, [
        ['offline order'],
        ['online order'],
      ]);
      await client.refreshLoadedPages();
      expect(visible, hasLength(2));
    },
  );

  test('permission errors evict saved content', () async {
    final client = _PageClient('packer', 'one');
    await client.storePage(endpoint, ['old order']);
    final cached = Completer<void>();
    final read = client.loadPage(endpoint, onData: (_) => cached.complete());
    final fails = expectLater(read, throwsA(isA<ApiException>()));
    await cached.future;
    client.server.completeError(
      ApiException('Access revoked', statusCode: 403),
    );
    await fails;
    final reopened = _PageClient('packer', 'one');
    final visible = <Object?>[];
    final next = reopened.loadPage(endpoint, onData: visible.add);
    reopened.server.complete([]);
    await next;
    expect(visible, [[]]);
  });
}
