import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glint_capture/glint_capture.dart';

void main() {
  group('GLINTConfig', () {
    test('parse reads app_name, tagline, and locales from yaml', () {
      final config = GLINTConfig.parse(
        '''
app_name: MyApp
tagline: Edit photos like a pro
locales: ["en-US", "es-ES"]
store: play
devices:
  - name: pixel9
    width: 412
    height: 915
    device_pixel_ratio: 2.625
    platform: android
''',
      );
      expect(config.appName, 'MyApp');
      expect(config.tagline, 'Edit photos like a pro');
      expect(config.locales, ['en-US', 'es-ES']);
      expect(config.store, 'play/phone');
    });

    test('app_name/tagline/locales default when absent', () {
      final config = GLINTConfig.parse('store: ios\n');
      expect(config.appName, isNull);
      expect(config.tagline, isNull);
      expect(config.locales, isEmpty);
      expect(config.store, 'ios/iphone');
    });
  });

  group('GLINTDevice', () {
    test('playStoreDefaults are curated Android phones', () {
      expect(GLINTDevices.playStoreDefaults, hasLength(2));
      expect(GLINTDevices.playStoreDefaults.first.name, 'pixel9');
    });

    test('premium is the full curated set of six', () {
      expect(GLINTDevices.premium, hasLength(6));
      expect(GLINTDevices.allDefaults, GLINTDevices.premium);
    });
  });

  group('GLINTSession', () {
    test('toJson matches Glint schema', () {
      final session = GLINTSession(
        screens: ['android/pixel9/home.png', 'android/pixel9/profile.png'],
        store: 'play/phone',
      );

      final json = session.toJson();
      expect(json['screens'], hasLength(2));
      expect(json['store'], 'play/phone');
      expect(json['version'], '1.0');
      expect(json['exportedAt'], isNotNull);
    });

    test('fromDirectory picks primary device for Web frames', () async {
      final dir = await Directory.systemTemp.createTemp('glint_session_');
      addTearDown(() => dir.delete(recursive: true));

      final pixel = Directory('${dir.path}/android/pixel9');
      final galaxy = Directory('${dir.path}/android/galaxy_s24');
      await pixel.create(recursive: true);
      await galaxy.create(recursive: true);
      await File('${pixel.path}/home.png').writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
      await File('${pixel.path}/profile.png').writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
      await File('${galaxy.path}/home.png').writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      final session = GLINTSession.fromDirectory(
        outputDir: dir.path,
        store: 'play/phone',
      );

      expect(session.screens, [
        'android/pixel9/home.png',
        'android/pixel9/profile.png',
      ]);

      final written = await session.write(dir.path);
      expect(await written.exists(), isTrue);
      final contents = await written.readAsString();
      expect(contents, contains('"version": "1.0"'));
      expect(contents, contains('android/pixel9/home.png'));
      expect(contents, isNot(contains('galaxy_s24')));
    });
  });

  group('expandRules', () {
    test('expands screen rules unchanged', () {
      final rules = [
        GLINTRule.screen(name: 'home', builder: (context) => const SizedBox()),
      ];
      expect(expandRules(rules), hasLength(1));
    });

    test('expands template rules with builders', () {
      final rules = [
        GLINTRule.template(
          name: 'onboarding_flow',
          screens: ['welcome', 'signup'],
          builders: {
            'welcome': (context) => const SizedBox(),
            'signup': (context) => const SizedBox(),
          },
        ),
      ];
      expect(expandRules(rules), hasLength(2));
    });
  });

  group('GLINTTemplates', () {
    test('resolve returns known templates', () {
      expect(GLINTTemplates.resolve('onboarding_flow'), hasLength(5));
      expect(GLINTTemplates.resolve('feature_highlights'), hasLength(5));
    });

    test('unknown template throws', () {
      expect(
        () => GLINTTemplates.resolve('not_a_real_template'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('GLINTSession store keys', () {
    test('preserves canonical store ids in JSON', () {
      final session = GLINTSession(
        screens: ['android/pixel9/home.png'],
        store: 'play/phone',
      );
      expect(session.toJson()['store'], 'play/phone');
    });
  });

  group('GLINTSession app / tagline / locales', () {
    test('omits app/tagline/locales when not provided', () {
      final json = GLINTSession(
        screens: ['android/pixel9/home.png'],
        store: 'play/phone',
      ).toJson();

      expect(json.containsKey('app'), isFalse);
      expect(json.containsKey('tagline'), isFalse);
      expect(json.containsKey('locales'), isFalse);
    });

    test('writes app/tagline/locales when provided', () {
      final json = GLINTSession(
        screens: ['android/pixel9/home.png'],
        store: 'play/phone',
        app: 'MyApp',
        tagline: 'Edit photos like a pro',
        locales: ['en-US', 'es-ES'],
      ).toJson();

      expect(json['app'], 'MyApp');
      expect(json['tagline'], 'Edit photos like a pro');
      expect(json['locales'], ['en-US', 'es-ES']);
    });

    test('fromDirectory threads app/tagline/locales through', () async {
      final dir = await Directory.systemTemp.createTemp('glint_session_meta_');
      addTearDown(() => dir.delete(recursive: true));
      final pixel = Directory('${dir.path}/android/pixel9');
      await pixel.create(recursive: true);
      await File('${pixel.path}/home.png').writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      final session = GLINTSession.fromDirectory(
        outputDir: dir.path,
        store: 'play/phone',
        app: 'MyApp',
        tagline: 'A tagline',
        locales: ['en-US'],
      );

      final written = await session.write(dir.path);
      final contents = await written.readAsString();
      expect(contents, contains('"app": "MyApp"'));
      expect(contents, contains('"tagline": "A tagline"'));
      expect(contents, contains('"locales"'));
    });
  });
}
