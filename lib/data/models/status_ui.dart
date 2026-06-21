import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../models/models.dart';

/// Maps domain enums to display label + colour, keeping screens DRY.
class StatusUi {
  static (String, Color) approval(ApprovalStatus s) => switch (s) {
        ApprovalStatus.pending => ('Pending', AppColors.warning),
        ApprovalStatus.approved => ('Approved', AppColors.success),
        ApprovalStatus.rejected => ('Rejected', AppColors.danger),
        ApprovalStatus.suspended => ('Suspended', AppColors.textMuted),
      };

  static (String, Color) booking(BookingStatus s) => switch (s) {
        BookingStatus.requested => ('Requested', AppColors.info),
        BookingStatus.confirmed => ('Confirmed', AppColors.success),
        BookingStatus.inProgress => ('In Progress', AppColors.gold),
        BookingStatus.completed => ('Completed', AppColors.success),
        BookingStatus.cancelled => ('Cancelled', AppColors.textMuted),
        BookingStatus.disputed => ('Disputed', AppColors.danger),
      };

  static (String, Color) payment(PaymentStatus s) => switch (s) {
        PaymentStatus.pending => ('Pending', AppColors.warning),
        PaymentStatus.paid => ('Paid', AppColors.success),
        PaymentStatus.refunded => ('Refunded', AppColors.danger),
        PaymentStatus.failed => ('Failed', AppColors.danger),
        PaymentStatus.payout => ('Payout', AppColors.info),
      };

  static String role(UserRole r) => switch (r) {
        UserRole.model => 'Model',
        UserRole.photographer => 'Photographer',
        UserRole.videographer => 'Videographer',
        UserRole.venue => 'Venue',
        UserRole.eventService => 'Event Service',
        UserRole.client => 'Client',
      };

  static (String, Color) event(EventStatus s) => switch (s) {
        EventStatus.draft => ('Draft', AppColors.textMuted),
        EventStatus.upcoming => ('Upcoming', AppColors.info),
        EventStatus.live => ('Live', AppColors.success),
        EventStatus.ended => ('Ended', AppColors.textMuted),
      };

  static Color priority(String p) => switch (p) {
        'high' => AppColors.danger,
        'medium' => AppColors.warning,
        _ => AppColors.info,
      };
}
