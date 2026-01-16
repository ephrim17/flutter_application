import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';

class FooterSectionWidget implements HomeSection {
  @override
  String get id => 'footer';

  @override
  int get order => 100; // always last

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      //const SliverToBoxAdapter(child: SizedBox(height: 48)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color.fromARGB(255, 234, 213, 213)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _contactRow(),
                const SizedBox(height: 32),
                _socialRow(),
                const SizedBox(height: 32),
                const Text(
                  '© Church',
                  style: TextStyle(color: Color.fromARGB(255, 1, 0, 0)),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// 🔹 Top contact icons row
  Widget _contactRow() {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 40,
      runSpacing: 24,
      children: const [
        _FooterItem(
          icon: Icons.email,
          title: 'Email',
          subtitle: 'info@rockcitycorpus.com',
        ),
        _FooterItem(
          icon: Icons.phone,
          title: 'Office Phone',
          subtitle: '(361) 353-4421',
        ),
        _FooterItem(
          icon: Icons.location_on,
          title: 'Find Us',
          subtitle:
              '10309 South Padre Island Drive,\nCorpus Christi, TX',
        ),
        // _FooterItem(
        //   icon: Icons.credit_card,
        //   title: 'Give',
        //   subtitle: 'Give Online',
        // ),
      ],
    );
  }

  /// 🔹 Social icons row
  Widget _socialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.facebook, color: Color.fromARGB(255, 1, 0, 0)),
        SizedBox(width: 16),
        Icon(Icons.play_arrow, color: Color.fromARGB(255, 1, 0, 0))
      ],
    );
  }

  /// 🔹 Bottom navigation links
  Widget _linksWrap() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: const [
        _FooterLink('Home'),
        _FooterLink('Members Only'),
        _FooterLink('Pastoral Care'),
        _FooterLink('Firestorm School of Ministry'),
        _FooterLink('Salt & Light Co-Op'),
        _FooterLink('Little Wonders'),
        _FooterLink('Plan A Visit'),
      ],
    );
  }
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Color.fromARGB(255, 1, 0, 0)),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color.fromARGB(255, 1, 0, 0),
            fontWeight: FontWeight.w600,
          ),
        ),
        // const SizedBox(height: 4),
        // Text(
        //   subtitle,
        //   textAlign: TextAlign.center,
        //   style: const TextStyle(color: Colors.white70),
        // ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
      ),
    );
  }
}
