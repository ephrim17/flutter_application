import 'package:flutter/material.dart';

enum SocialPlatform {
  facebook,
  instagram,
  youtube,
  twitter,
  whatsapp,
  telegram,
  tiktok,
  email,
  others;

  String get storedValue => name;

  String get label {
    switch (this) {
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.youtube:
        return 'YouTube';
      case SocialPlatform.twitter:
        return 'Twitter / X';
      case SocialPlatform.whatsapp:
        return 'WhatsApp';
      case SocialPlatform.telegram:
        return 'Telegram';
      case SocialPlatform.tiktok:
        return 'TikTok';
      case SocialPlatform.email:
        return 'Email';
      case SocialPlatform.others:
        return 'Others';
    }
  }

  IconData get icon {
    switch (this) {
      case SocialPlatform.facebook:
        return Icons.facebook;
      case SocialPlatform.instagram:
        return Icons.camera_alt_rounded;
      case SocialPlatform.youtube:
        return Icons.smart_display_rounded;
      case SocialPlatform.twitter:
        return Icons.alternate_email_rounded;
      case SocialPlatform.whatsapp:
        return Icons.chat_rounded;
      case SocialPlatform.telegram:
        return Icons.send_rounded;
      case SocialPlatform.tiktok:
        return Icons.music_note_rounded;
      case SocialPlatform.email:
        return Icons.email_rounded;
      case SocialPlatform.others:
        return Icons.link_rounded;
    }
  }

  static SocialPlatform fromStored(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'facebook':
      case 'fb':
        return SocialPlatform.facebook;
      case 'instagram':
      case 'insta':
      case 'ig':
        return SocialPlatform.instagram;
      case 'youtube':
      case 'yt':
        return SocialPlatform.youtube;
      case 'twitter':
      case 'x':
        return SocialPlatform.twitter;
      case 'whatsapp':
      case 'wa':
        return SocialPlatform.whatsapp;
      case 'telegram':
        return SocialPlatform.telegram;
      case 'tiktok':
        return SocialPlatform.tiktok;
      case 'email':
      case 'mail':
        return SocialPlatform.email;
      default:
        return SocialPlatform.others;
    }
  }
}

class SocialIconModel {
  final String id;
  final String icon;
  final String url;
  final int order;
  final bool isActive;

  SocialIconModel({
    required this.id,
    required this.icon,
    required this.url,
    required this.order,
    required this.isActive,
  });

  factory SocialIconModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return SocialIconModel(
      id: id,
      icon: data['icon'] ?? '',
      url: data['url'] ?? '',
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'icon': icon,
      'url': url,
      'order': order,
      'isActive': isActive,
    };
  }
}
