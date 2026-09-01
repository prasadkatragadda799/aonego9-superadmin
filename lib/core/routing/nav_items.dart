import 'package:flutter/material.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String route;
  final String? section;
  const NavItem(this.label, this.icon, this.route, {this.section});
}

/// Full Super Admin navigation — every manageable area of the platform.
const adminNav = <NavItem>[
  NavItem('Dashboard', Icons.dashboard_outlined, '/dashboard', section: 'Overview'),
  NavItem('Analytics', Icons.insights_outlined, '/analytics', section: 'Overview'),

  NavItem('Vendors', Icons.storefront_outlined, '/vendors', section: 'Marketplace'),
  NavItem('Talent & Users', Icons.people_outline, '/users', section: 'Marketplace'),
  NavItem('Bookings', Icons.event_note_outlined, '/bookings', section: 'Marketplace'),
  NavItem('Payments', Icons.payments_outlined, '/payments', section: 'Marketplace'),
  NavItem('Subscriptions', Icons.workspace_premium_outlined, '/subscriptions', section: 'Marketplace'),

  NavItem('Reviews', Icons.star_outline, '/reviews', section: 'Moderation'),
  NavItem('Leads & Applications', Icons.inbox_outlined, '/leads', section: 'Moderation'),
  NavItem('Support', Icons.support_agent_outlined, '/support', section: 'Moderation'),

  NavItem('Events & Poster', Icons.celebration_outlined, '/events', section: 'Platform'),
  NavItem('Workshops & Webinars', Icons.school_outlined, '/sessions', section: 'Platform'),
  NavItem('Newsletter', Icons.auto_stories_outlined, '/newsletter', section: 'Platform'),
  NavItem('Ads & Promotions', Icons.campaign_outlined, '/ads', section: 'Platform'),
  NavItem('Partners & Team', Icons.handshake_outlined, '/directory', section: 'Platform'),
  NavItem('Social Accounts', Icons.share_outlined, '/social', section: 'Platform'),
  NavItem('CMS & Content', Icons.web_outlined, '/cms', section: 'Platform'),
  NavItem('Settings', Icons.settings_outlined, '/settings', section: 'Platform'),
];
