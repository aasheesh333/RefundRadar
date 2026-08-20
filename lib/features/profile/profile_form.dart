import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/core/providers/user_profile_provider.dart';
import 'package:refund_radar/core/theme/app_theme_colors.dart';
import 'package:refund_radar/core/theme/app_tokens.dart';
import 'package:refund_radar/data/models/user_profile.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/shared/widgets/form_field_box.dart';

/// Reusable editable complainant-details form. Shown
/// (a) as its own onboarding step (/onboard/profile),
/// (b) as an edit sheet from Settings, and
/// (c) inline (collapsed) inside dispute-create.
///
/// Values are pre-filled from the persisted one-time profile; on save they
/// are written back via [saveUserProfile] so every grievance email is
/// pre-addressed without further typing.
class ProfileForm extends StatefulWidget {
  final UserProfile initial;
  final ValueChanged<UserProfile>? onChanged;
  final bool nameRequired;
  const ProfileForm({
    super.key,
    required this.initial,
    this.onChanged,
    this.nameRequired = false,
  });

  @override
  State<ProfileForm> createState() => ProfileFormState();
}

class ProfileFormState extends State<ProfileForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _placeCtrl;
  late final TextEditingController _accountCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _mobileCtrl = TextEditingController(text: widget.initial.mobile);
    _emailCtrl = TextEditingController(text: widget.initial.email);
    _addressCtrl = TextEditingController(text: widget.initial.address);
    _placeCtrl = TextEditingController(text: widget.initial.place);
    _accountCtrl = TextEditingController(text: widget.initial.accountNo);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _placeCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  UserProfile get current => UserProfile(
        name: _nameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        place: _placeCtrl.text.trim(),
        accountNo: _accountCtrl.text.trim(),
      );

  bool get isValid {
    if (widget.nameRequired && current.name.isEmpty) return false;
    final email = current.email;
    if (email.isNotEmpty && !email.contains('@')) return false;
    return true;
  }

  void _notify() {
    widget.onChanged?.call(current);
  }

  Widget _field(
    AppThemeColors tc,
    String label,
    TextEditingController ctrl, {
    String? helper,
    TextInputType? keyboard,
    int? maxLen,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FormFieldBox(
        label: label,
        helper: helper,
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          maxLength: maxLen,
          inputFormatters: formatters,
          maxLines: label.contains('ADDRESS') ? 2 : 1,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: tc.textPrimary,
          ),
          cursorColor: tc.ctaBackground,
          decoration: const InputDecoration(
            isCollapsed: true,
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            counterText: '',
          ),
          onChanged: (_) => _notify(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(tc, l10n?.profileName ?? 'FULL NAME', _nameCtrl),
        _field(
          tc,
          l10n?.profileMobile ?? 'MOBILE NUMBER',
          _mobileCtrl,
          keyboard: TextInputType.phone,
          maxLen: 10,
          formatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        _field(
          tc,
          l10n?.profileEmail ?? 'EMAIL ADDRESS',
          _emailCtrl,
          helper: l10n?.profileEmailHint ?? 'bank will reply here',
          keyboard: TextInputType.emailAddress,
        ),
        _field(
          tc,
          l10n?.profileAccount ?? 'BANK ACCOUNT (OPTIONAL)',
          _accountCtrl,
          helper: l10n?.profileAccountHint ?? 'a/c no.',
          keyboard: TextInputType.number,
          maxLen: 18,
          formatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        _field(
          tc,
          l10n?.profilePlace ?? 'CITY / PLACE (OPTIONAL)',
          _placeCtrl,
        ),
        _field(
          tc,
          l10n?.profileAddress ?? 'ADDRESS (OPTIONAL)',
          _addressCtrl,
        ),
      ],
    );
  }
}

/// Opens the profile editor as a bottom sheet. Returns the saved profile,
/// or `null` when the user dismisses without saving.
Future<UserProfile?> showProfileEditSheet(
  BuildContext context,
  WidgetRef ref, {
  String? title,
  String? saveLabel,
  bool nameRequired = false,
}) {
  final tc = AppThemeColors.of(context);
  final initial = ref.read(userProfileProvider);
  final formKey = GlobalKey<ProfileFormState>();
  var draft = initial;

  return showModalBottomSheet<UserProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tc.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (c, setSheetState) {
        final stc = AppThemeColors.of(c);
        final sl10n = AppLocalizations.of(c);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(c).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: stc.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    title ?? sl10n?.profileEditTitle ?? 'Your details',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: stc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sl10n?.profileEditSubtitle ??
                        'One-time setup. Auto-filled in every complaint email so nothing needs manual editing.',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: stc.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  ProfileForm(
                    key: formKey,
                    initial: initial,
                    nameRequired: nameRequired,
                    onChanged: (p) => draft = p,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: stc.ctaBackground,
                        foregroundColor: stc.ctaForeground,
                        disabledBackgroundColor:
                            stc.ctaBackground.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      onPressed: formKey.currentState?.isValid ?? !nameRequired
                          ? () async {
                              final state = formKey.currentState;
                              final profile = state?.current ?? draft;
                              if (nameRequired && profile.name.isEmpty) {
                                return;
                              }
                              await saveUserProfile(ref, profile);
                              if (c.mounted) Navigator.pop(c, profile);
                            }
                          : null,
                      child: Text(
                        saveLabel ?? sl10n?.commonSave ?? 'Save',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
