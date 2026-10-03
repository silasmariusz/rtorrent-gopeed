// Rtorrent16's local patch: Gopeed's BitTorrent settings greyed out while the add-on's shim hands torrents
// and magnets to rtorrent16. The shim says so in GET /api/v1/config as extra.rt16.rtorrent.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopeed/api/model/downloader_config.dart';
import 'package:gopeed/app/application/app_runtime_controller.dart';
import 'package:gopeed/core/capabilities/app_capabilities.dart';
import 'package:gopeed/core/capabilities/capability_rpc.dart';
import 'package:gopeed/core/capabilities/gopeed_capability.dart';
import 'package:gopeed/core/common/api_server_state.dart';
import 'package:gopeed/core/common/start_config.dart';
import 'package:gopeed/features/settings/application/settings_controller.dart';
import 'package:gopeed/shared/theme/app_component_themes.dart';
import 'package:gopeed/shared/theme/app_theme.dart';
import 'package:gopeed/shared/widgets/rt16_bt_lock.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

// GET /api/v1/config through the shim with the bridge on, from the real Gopeed 2.0.0-beta.3+rt16 binary and
// the shim of 2026-10-03 (paths shortened).
const _shimAnswer =
    '{"code":0,"data":{"api":null,"archive":{"autoExtract":false,"deleteAfterExtract":false},'
    '"autoDeleteMissingFileTasks":false,"autoStartTasks":false,"autoTorrent":{"deleteAfterDownload":false,"enable":false},'
    '"downloadDir":"/share/Download/gopeed","extra":{"analyticsEnabled":false,"bt":{"autoUpdateTrackers":true,'
    '"customTrackers":[],"subscribeTrackers":[],"trackerSubscribeUrls":[]},"rt16":{"rtorrent":true}},"maxRunning":5,'
    '"protocolConfig":{"bt":{"listenPort":0,"seedKeep":false,"seedRatio":1,"seedTime":7200,"trackers":[]},'
    '"ed2k":{"listenPort":0,"nodesDat":"https://upd.emule-security.org/nodes.dat","serverAddr":"45.82.80.155:5687",'
    '"serverMet":"ed2k://|serverlist|http://upd.emule-security.org/server.met|/","udpPort":0},"ftp":{"connections":4},'
    '"hls":{"maxRetries":5,"prefetchContentLength":true,"segmentConnections":8,"timeoutSeconds":30},'
    '"http":{"adaptive":false,"connections":16,"useServerCtime":false,"userAgent":"Mozilla/5.0"}},'
    '"proxy":{"enable":false,"host":"","pwd":"","scheme":"","system":false,"usr":""},'
    '"script":{"enable":true,"paths":["/share/CACHEDEV1_DATA/.qpkg/Rtorrent16-Gopeed/bin/rt16-gopeed"]},'
    '"webhook":{"enable":false,"urls":null}},"msg":""}';

DownloaderConfig _parse(Map<String, dynamic> data) => DownloaderConfig.fromJson(data);

Map<String, dynamic> _data() => (jsonDecode(_shimAnswer) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

void main() {
  group('extra.rt16 in the configuration', () {
    test('the shim\'s real answer parses, flag and all, and keeps maxRunning', () {
      final config = _parse(_data());
      expect(config.extra.rt16Rtorrent, isTrue);
      expect(config.maxRunning, 5);
      expect(config.extra.analyticsEnabled, isFalse);
    });

    test('without the key (bridge off) it parses to false and does not throw', () {
      final data = _data();
      (data['extra'] as Map<String, dynamic>).remove('rt16');
      final config = _parse(data);
      expect(config.extra.rt16Rtorrent, isFalse);
      expect(config.maxRunning, 5);
    });

    test('anything but rtorrent:true reads as false, and other unknown keys in extra are ignored', () {
      for (final odd in <Object?>[
        null,
        true,
        'yes',
        <String, dynamic>{},
        {'rtorrent': 'true'},
        {'rtorrent': 1},
      ]) {
        final data = _data();
        (data['extra'] as Map<String, dynamic>)
          ..['rt16'] = odd
          ..['somethingNew'] = {'a': 1};
        expect(_parse(data).extra.rt16Rtorrent, isFalse, reason: 'rt16 = $odd');
      }
    });

    test('a copy through toJson keeps the flag, and false writes no key at all', () {
      final on = _parse(_data());
      final json = on.toJson();
      expect((json['extra'] as Map<String, dynamic>)['rt16'], {'rtorrent': true});
      expect(
        DownloaderConfig.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>).extra.rt16Rtorrent,
        isTrue,
      );
      final off = DownloaderConfig();
      expect((off.toJson()['extra'] as Map<String, dynamic>).containsKey('rt16'), isFalse);
    });
  });

  group('Rt16BtLock', () {
    Future<List<bool>> pumpLock(WidgetTester tester, {required bool locked}) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        shad.ShadcnApp(
          theme: AppTheme.dark(),
          materialTheme: AppTheme.materialDark(),
          home: AppComponentThemes(
            child: Rt16BtLock(
              key: const ValueKey('lock'),
              locked: locked,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Listen port'),
                  shad.Switch(key: const ValueKey('bt-switch'), value: false, onChanged: changes.add),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return changes;
    }

    testWidgets('locked: the label is shown, the section stays visible and greyed, and takes no input', (tester) async {
      final changes = await pumpLock(tester, locked: true);
      expect(find.text('Rtorrent16 enabled'), findsOneWidget);
      expect(find.text('Listen port'), findsOneWidget);
      expect(find.byKey(const ValueKey('bt-switch')), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.byKey(const ValueKey('bt-switch')), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, lessThan(1));
      expect(
        find.ancestor(of: find.byKey(const ValueKey('bt-switch')), matching: find.byType(ExcludeFocus)),
        findsWidgets,
      );
      await tester.tap(find.byKey(const ValueKey('bt-switch')), warnIfMissed: false);
      await tester.pump();
      expect(changes, isEmpty);
    });

    testWidgets('unlocked: no label, and the section works as before', (tester) async {
      final changes = await pumpLock(tester, locked: false);
      expect(find.text('Rtorrent16 enabled'), findsNothing);
      expect(find.byType(Opacity), findsNothing);
      await tester.tap(find.byKey(const ValueKey('bt-switch')));
      await tester.pump();
      expect(changes, [true]);
    });
  });

  test('a settings save takes the flag from the server\'s answer of now', () async {
    var rtorrent = true;
    DownloaderConfig? saved;
    final registry = CapabilityRegistry(createAppCapabilityCodecs())
      ..bind(GopeedMethods.getConfig, (_) => DownloaderConfig()..extra.rt16Rtorrent = rtorrent)
      ..bind(GopeedMethods.putConfig, (config) {
        saved = DownloaderConfig.fromJson(config.toJson());
        return const RpcUnit();
      });
    final container = ProviderContainer(
      overrides: [
        appCapabilitiesProvider.overrideWithValue(AppCapabilities(LocalCapabilityInvoker(registry))),
        appRuntimeControllerProvider.overrideWith(_TestRuntimeController.new),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(settingsControllerProvider.notifier);
    expect((await container.read(settingsControllerProvider.future)).config.extra.rt16Rtorrent, isTrue);
    rtorrent = false;
    await controller.save(DownloaderConfig(downloadDir: 'E:/New')..extra.rt16Rtorrent = true);
    expect(saved?.downloadDir, 'E:/New');
    expect(container.read(settingsControllerProvider).value?.config.extra.rt16Rtorrent, isFalse);
  });
}

class _TestRuntimeController extends AppRuntimeController {
  @override
  Future<AppRuntimeState> build() async => AppRuntimeState(
    startConfig: StartConfig(),
    apiServerState: const ApiServerState(
      enabled: false,
      mcpEnabled: false,
      running: false,
      network: '',
      address: '',
      runningPort: 0,
      pendingApply: false,
      lastError: '',
    ),
    downloaderConfig: DownloaderConfig(),
  );
}
