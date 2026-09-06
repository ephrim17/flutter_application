import 'package:flutter_application/church_app/models/footer_support_models/social_icon_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SocialPlatform.fromStored', () {
    test('matches known platforms case-insensitively', () {
      expect(SocialPlatform.fromStored('Facebook'), SocialPlatform.facebook);
      expect(SocialPlatform.fromStored('facebook'), SocialPlatform.facebook);
      expect(SocialPlatform.fromStored('INSTAGRAM'), SocialPlatform.instagram);
      expect(SocialPlatform.fromStored('insta'), SocialPlatform.instagram);
      expect(SocialPlatform.fromStored('Youtube'), SocialPlatform.youtube);
      expect(SocialPlatform.fromStored('yt'), SocialPlatform.youtube);
      expect(SocialPlatform.fromStored('X'), SocialPlatform.twitter);
      expect(SocialPlatform.fromStored('whatsapp'), SocialPlatform.whatsapp);
      expect(SocialPlatform.fromStored('Email'), SocialPlatform.email);
    });

    test('falls back to others for unrecognized or empty values', () {
      expect(SocialPlatform.fromStored('Snapchat'), SocialPlatform.others);
      expect(SocialPlatform.fromStored(''), SocialPlatform.others);
      expect(SocialPlatform.fromStored(null), SocialPlatform.others);
    });

    test('storedValue round-trips through fromStored', () {
      for (final platform in SocialPlatform.values) {
        expect(SocialPlatform.fromStored(platform.storedValue), platform);
      }
    });
  });
}
