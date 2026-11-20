/// Lightweight, zero-overhead Vietnamese (default) & English localization.
class AppStrings {
  final String locale;
  const AppStrings(this.locale);

  bool get isVi => locale == 'vi';

  // Navigation
  String get navHome => isVi ? 'Trang chủ' : 'Home';
  String get navCalendar => isVi ? 'Lịch' : 'Calendar';
  String get navTemplates => isVi ? 'Mẫu & Nhật ký' : 'Templates';
  String get navSettings => isVi ? 'Cài đặt' : 'Settings';

  // Dashboard
  String get greeting => isVi ? 'Nhịp thời gian của bạn' : 'Your Time Flow';
  String get nextUp => isVi ? 'SẮP DIỄN RA' : 'NEXT UPCOMING';
  String get noUpcoming => isVi ? 'Chưa có lịch hẹn sắp tới' : 'No upcoming reminders';
  String get noUpcomingSub => isVi
      ? 'Nhấn + để tạo nhắc nhở theo ngày chính xác hoặc báo thức mạnh mẽ.'
      : 'Tap + to schedule an exact-date reminder or strong alarm.';
  String get filterAll => isVi ? 'Tất cả' : 'All';
  String get filterToday => isVi ? 'Hôm nay' : 'Today';
  String get filterUpcoming => isVi ? 'Sắp tới' : 'Upcoming';
  String get filterImportant => isVi ? 'Quan trọng' : 'Important';
  String get remainingPrefix => isVi ? 'Còn' : 'In';
  String get overdue => isVi ? 'Đã quá giờ' : 'Overdue';
  String get dueNow => isVi ? 'Đang đến giờ!' : 'Due now!';
  String get swipeComplete => isVi ? 'Hoàn thành' : 'Complete';
  String get swipeSnooze => isVi ? 'Báo lại 10p' : 'Snooze 10m';
  String get completedSnack => isVi ? 'Đã đánh dấu hoàn thành' : 'Marked as completed';
  String get snoozedSnack => isVi ? 'Đã báo lại sau' : 'Snoozed for';
  String get minutesShort => isVi ? 'phút' : 'min';
  String get hoursShort => isVi ? 'giờ' : 'hr';
  String get daysShort => isVi ? 'ngày' : 'd';

  // Create / Edit Reminder
  String get newReminder => isVi ? 'Tạo nhắc nhở mới' : 'New Reminder';
  String get editReminder => isVi ? 'Chỉnh sửa nhắc nhở' : 'Edit Reminder';
  String get titleLabel => isVi ? 'Tiêu đề nhắc nhở' : 'Reminder title';
  String get titleHint => isVi ? 'VD: Đóng tiền điện, Họp dự án...' : 'e.g. Pay utility bill, Project sync...';
  String get notesLabel => isVi ? 'Ghi chú chi tiết' : 'Detailed notes';
  String get notesHint => isVi ? 'Thêm chi tiết, địa điểm, liên kết...' : 'Add details, location, links...';
  String get selectDate => isVi ? 'Chọn ngày chính xác' : 'Select Exact Date(s)';
  String get multiDateMode => isVi ? 'Chọn nhiều ngày' : 'Multi-Date Batch';
  String get multiDateHint => isVi
      ? 'Chạm nhiều ngày trên lịch để tạo hàng loạt nhắc nhở liên kết.'
      : 'Tap multiple dates to create linked batch reminders at once.';
  String get selectedDatesCount => isVi ? 'ngày đã chọn' : 'dates selected';
  String get selectTime => isVi ? 'Chọn giờ chính xác' : 'Exact Time';
  String get recurrenceLabel => isVi ? 'Lặp lại' : 'Recurrence';
  String get recOnce => isVi ? 'Một lần' : 'One-time';
  String get recWeekly => isVi ? 'Ngày trong tuần' : 'Weekly days';
  String get recMonthly => isVi ? 'Hàng tháng' : 'Monthly';
  String get recYearly => isVi ? 'Hàng năm / Sinh nhật' : 'Yearly / Birthday';
  String get recCustom => isVi ? 'Chu kỳ tùy chỉnh' : 'Custom interval';
  String get lastDayOfMonth => isVi ? 'Ngày cuối cùng của tháng' : 'Last day of month';
  String get birthYearLabel => isVi ? 'Năm gốc (tính tuổi / năm kỷ niệm)' : 'Origin year (age / anniversary counter)';
  String get everyLabel => isVi ? 'Mỗi' : 'Every';
  String get unitDays => isVi ? 'ngày' : 'days';
  String get unitHours => isVi ? 'giờ' : 'hours';
  String get preReminderLabel => isVi ? 'Nhắc trước' : 'Pre-Reminders';
  String get customPreMin => isVi ? 'Tùy chỉnh (phút)' : 'Custom (min)';
  String get categoryLabel => isVi ? 'Danh mục & Thẻ màu' : 'Category & Tag';
  String get addCustomTag => isVi ? '+ Thẻ mới' : '+ New Tag';
  String get importantFlag => isVi ? 'Đánh dấu quan trọng' : 'Mark as Important';
  String get snoozeConfig => isVi ? 'Cấu hình báo lại (Snooze)' : 'Snooze Configuration';
  String get maxSnooze => isVi ? 'Số lần báo lại tối đa' : 'Max snooze count';
  String get dismissChallengeLabel => isVi ? 'Thử thách tắt báo thức' : 'Dismiss Challenge';
  String get challengeSlide => isVi ? 'Trượt để tắt' : 'Slide to Dismiss';
  String get challengeHold => isVi ? 'Giữ 3 giây' : 'Hold 3 Seconds';
  String get challengeMath => isVi ? 'Giải phép tính nhanh' : 'Solve Quick Math';
  String get soundLabel => isVi ? 'Âm thanh báo thức' : 'Alarm Ringtone';
  String get ringtonePickerTitle => isVi ? 'Chọn nhạc chuông báo thức' : 'Select Alarm Ringtone';
  String get addRingtoneFromDevice => isVi ? '+ Thêm nhạc chuông từ máy' : '+ Add Ringtone from Device';
  String get myRingtones => isVi ? 'Nhạc chuông của tôi' : 'My Ringtones';
  String get builtInRingtones => isVi ? 'Nhạc chuông có sẵn' : 'Built-in Ringtones';
  String get systemDefaultRingtone => isVi ? 'Mặc định hệ thống' : 'System Default';
  String get defaultAlarmRingtone => isVi ? 'Nhạc chuông báo thức mặc định' : 'Default Alarm Ringtone';
  String get ringtoneImported => isVi ? 'Đã thêm nhạc chuông mới!' : 'Custom ringtone added!';
  String get ringtoneDeleted => isVi ? 'Đã xóa nhạc chuông' : 'Ringtone removed';
  String get tapToPreview => isVi ? 'Chạm để nghe thử & chọn' : 'Tap to preview & select';
  String get checklistLabel => isVi ? 'Danh sách công việc con' : 'Sub-task Checklist';
  String get addSubtaskHint => isVi ? 'Thêm đầu việc con...' : 'Add a sub-task...';
  String get save => isVi ? 'Lưu lịch hẹn' : 'Save Reminder';
  String get delete => isVi ? 'Xóa' : 'Delete';
  String get cancel => isVi ? 'Hủy' : 'Cancel';
  String get pastDateError => isVi
      ? 'Vui lòng chọn thời điểm trong tương lai.'
      : 'Please select a future date and time.';
  String get titleRequiredError => isVi
      ? 'Vui lòng nhập tiêu đề nhắc nhở.'
      : 'Please enter a reminder title.';

  // Calendar Screen
  String get calendarTitle => isVi ? 'Lịch nhắc nhở' : 'Schedule Calendar';
  String get monthView => isVi ? 'Tháng' : 'Month';
  String get weekView => isVi ? 'Tuần' : 'Week';
  String get noRemindersOnDay => isVi
      ? 'Không có lịch nhắc nào trong ngày này.'
      : 'No reminders scheduled for this date.';

  // Templates & History
  String get quickTemplates => isVi ? 'Mẫu tạo nhanh' : 'Quick Templates';
  String get historyLog => isVi ? 'Nhật ký hoạt động' : 'Activity History';
  String get clearHistory => isVi ? 'Xóa nhật ký' : 'Clear Log';
  String get noHistory => isVi
      ? 'Chưa có lịch sử hoàn thành, báo lại hay bỏ lỡ.'
      : 'No completed, snoozed, or missed history yet.';
  String get statusCompleted => isVi ? 'Hoàn thành' : 'Completed';
  String get statusSnoozed => isVi ? 'Báo lại' : 'Snoozed';
  String get statusMissed => isVi ? 'Bỏ lỡ' : 'Missed';
  String get statusDismissed => isVi ? 'Đã tắt' : 'Dismissed';

  // Full-Screen Alarm
  String get alarmRinging => isVi ? 'BÁO THỨC ĐANG REO' : 'ALARM ACTIVE';
  String get slideToDismiss => isVi ? 'Trượt sang phải để tắt' : 'Slide right to dismiss';
  String get holdToDismiss => isVi ? 'Nhấn giữ 3 giây để tắt' : 'Hold for 3 seconds to dismiss';
  String get solveToDismiss => isVi ? 'Giải phép tính để tắt báo thức' : 'Solve to dismiss alarm';
  String get snoozeNow => isVi ? 'Báo lại' : 'Snooze';
  String get snoozeLimitReached => isVi ? 'Đã hết lượt báo lại' : 'Max snoozes reached';
  String get wrongAnswer => isVi ? 'Chưa đúng, thử lại nhé!' : 'Incorrect, try again!';
  String get confirmAnswer => isVi ? 'Xác nhận' : 'Confirm';

  // Settings & System Reliability
  String get settingsTitle => isVi ? 'Cài đặt & Hệ thống' : 'Settings & System';
  String get reliabilityTitle => isVi
      ? 'Trạng thái hệ thống & Quyền báo thức'
      : 'Alarm Reliability & Permissions';
  String get reliabilitySubtitle => isVi
      ? 'Đảm bảo báo thức hoạt động chuẩn xác khi tắt màn hình hoặc khởi động lại.'
      : 'Ensure alarms fire reliably on lock screen, Doze mode, and after reboot.';
  String get permNotifications => isVi ? 'Quyền thông báo' : 'Notification Permission';
  String get permExactAlarm => isVi ? 'Quyền báo thức chính xác' : 'Exact Alarm Permission';
  String get permFullScreen => isVi ? 'Hiển thị toàn màn hình / Khóa màn hình' : 'Full-Screen Intent / Lock Screen';
  String get permBattery => isVi ? 'Bỏ qua tối ưu hóa pin (OEM Guard)' : 'Battery Optimization Exemption';
  String get statusReady => isVi ? 'Sẵn sàng' : 'Ready';
  String get statusActionNeeded => isVi ? 'Cần cấp quyền' : 'Fix now';
  String get oemGuardHint => isVi
      ? 'Trên các máy MIUI / ColorOS / OneUI, hãy tắt giới hạn pin nền để hệ điều hành không đóng ứng dụng.'
      : 'On MIUI / ColorOS / OneUI devices, disable background battery restrictions so alarms are never killed.';
  String get appearanceSection => isVi ? 'Giao diện & Ngôn ngữ' : 'Appearance & Language';
  String get themeDarkAurora => isVi ? 'Frosted Dark Aurora' : 'Frosted Dark Aurora';
  String get themeCrystalLight => isVi ? 'Crystal Light' : 'Crystal Light';
  String get languageLabel => isVi ? 'Ngôn ngữ' : 'Language';
  String get backupSection => isVi ? 'Sao lưu & Khôi phục (.json)' : 'Backup & Restore (.json)';
  String get exportJson => isVi ? 'Xuất bản sao lưu JSON' : 'Export JSON Backup';
  String get importJson => isVi ? 'Khôi phục từ tệp JSON' : 'Import from JSON';
  String get testAlarm => isVi ? 'Thử màn hình báo thức ngay' : 'Preview Full-Screen Alarm';
  String get rescheduleAll => isVi ? 'Đồng bộ lại tất cả báo thức' : 'Resync All Scheduled Alarms';
  String get resyncDone => isVi ? 'Đã đồng bộ lại toàn bộ báo thức!' : 'All active alarms resynchronized!';

  List<String> get weekdayShort => isVi
      ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
}
